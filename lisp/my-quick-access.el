;;; my-quick-access.el --- Workspace bookmarks and recent buffers -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'subr-x)
(require 'seq)
(require 'bookmark)
(require 'persp-mode)

(defgroup my/quick-access nil
  "Quick access to workspace bookmarks and buffers."
  :group 'convenience)

(defcustom my/quick-access-recent-count 5
  "Maximum number of recently visited buffers shown in the popup."
  :type 'natnum :group 'my/quick-access)

(defface my/quick-access-title
  '((t (:inherit mode-line-buffer-id :weight normal)))
  "Theme accent for popup titles and selection keys."
  :group 'my/quick-access)

(defcustom my/quick-access-selection-keys '("f" "j" "d" "k" "g" "h")
  "Distinct single-letter keys for recent buffers and ambiguous initials; use at least two."
  :type '(repeat string) :group 'my/quick-access)

(defcustom my/quick-access-max-height 0.48
  "Maximum popup height as a fraction of the frame height."
  :type '(float :tag "Frame height fraction") :group 'my/quick-access)

(defcustom my/quick-access-page-size 6
  "Maximum entries per page; small frames show fewer to keep the footer visible."
  :type 'natnum :group 'my/quick-access)
(defconst my/quick-access--buffer-name " *Workspace Quick Access*")
(defvar my/quick-access--history (make-hash-table :test #'eq :weakness 'key))
(defvar my/quick-access--hidden (make-hash-table :test #'eq :weakness 'key)
  "Buffers hidden from quick access per workspace during this session.")
(defvar my/quick-access--last-visit nil)
(defvar my/quick-access--active nil)

(defun my/quick-access--eligible-p (buffer)
  "Whether BUFFER is a live, user-visible buffer."
  (and (buffer-live-p buffer)
       (not (minibufferp buffer))
       (not (string-prefix-p " " (buffer-name buffer)))))

(defun my/quick-access--track ()
  "Remember visits independently for each workspace."
  (when (and (bound-and-true-p persp-mode)
             (not my/quick-access--active)
             (not (active-minibuffer-window)))
    (let* ((persp (get-current-persp))
           (buffer (window-buffer (selected-window)))
           (visit (cons persp buffer)))
      (unless (and (eq persp (car my/quick-access--last-visit))
                   (eq buffer (cdr my/quick-access--last-visit)))
        (setq my/quick-access--last-visit visit)
        (when (and (my/quick-access--eligible-p buffer)
                   (memq buffer (safe-persp-buffers persp)))
          (puthash persp
                   (cons buffer
                         (cl-remove-if
                          (lambda (old) (or (eq old buffer)
                                            (not (buffer-live-p old))))
                          (gethash persp my/quick-access--history)))
                   my/quick-access--history))))))

(defun my/quick-access--buffers (persp current)
  "Return live buffers of PERSP in visit order, excluding CURRENT.
The frame's buffer order seeds history for buffers not visited since loading."
  (let ((members (safe-persp-buffers persp))
        (hidden (cl-remove-if-not #'buffer-live-p
                                  (gethash persp my/quick-access--hidden))))
    (puthash persp hidden my/quick-access--hidden)
    (cl-remove-if-not
     (lambda (buffer)
       (and (not (eq buffer current))
            (not (memq buffer hidden))
            (my/quick-access--eligible-p buffer)
            (memq buffer members)))
     (delete-dups (append (gethash persp my/quick-access--history)
                         (buffer-list (selected-frame)))))))

(defun my/quick-access--scope-record (args)
  "Tag stored bookmark ARGS before the bookmark library saves them.
Existing assignments are retained when a shared bookmark is updated."
  (if (not (bound-and-true-p persp-mode)) args
    (pcase-let ((`(,name ,record ,no-overwrite) args))
      (bookmark-maybe-load-default-file)
      (let* ((old (and (not no-overwrite) (assoc name bookmark-alist)))
             (scopes (delete-dups
                      (cons (safe-persp-name (get-current-persp))
                            (append (alist-get 'my/quick-access-workspaces record)
                                    (and old (bookmark-prop-get
                                              old 'my/quick-access-workspaces)))))))
        (list name
              (cons (cons 'my/quick-access-workspaces scopes)
                    (assq-delete-all 'my/quick-access-workspaces
                                     (copy-tree record)))
              no-overwrite)))))

(defun my/quick-access--renamed (original new-name &rest args)
  "Keep bookmark assignments when ORIGINAL renames a workspace to NEW-NAME."
  (bookmark-maybe-load-default-file)
  (let ((old-name (apply original new-name args)) changed)
    (when old-name
      (dolist (record bookmark-alist)
        (let ((scopes (bookmark-prop-get record 'my/quick-access-workspaces)))
          (when (member old-name scopes)
            (bookmark-prop-set
             record 'my/quick-access-workspaces
             (delete-dups (cons new-name (remove old-name scopes))))
            (setq changed t))))
      (when changed
        (cl-incf bookmark-alist-modification-count)
        (bookmark-save)))
    old-name))

(defun my/quick-access--bookmarks (workspace)
  "Return bookmark records explicitly assigned to WORKSPACE."
  (bookmark-maybe-load-default-file)
  (cl-remove-if-not
   (lambda (record)
     (member workspace (bookmark-prop-get record 'my/quick-access-workspaces)))
   (copy-sequence bookmark-alist)))

(defun my/quick-access--add-bookmark (workspace)
  "Assign an existing bookmark to WORKSPACE without moving or copying it."
  (bookmark-maybe-load-default-file)
  (unless bookmark-alist (user-error "No existing bookmarks; use C-s to save one"))
  (let* ((name (completing-read "Add bookmark to workspace: "
                                (bookmark-all-names) nil t))
         (record (bookmark-get-bookmark name))
         (scopes (bookmark-prop-get record 'my/quick-access-workspaces)))
    (unless (member workspace scopes)
      (bookmark-prop-set record 'my/quick-access-workspaces (cons workspace scopes))
      (cl-incf bookmark-alist-modification-count)
      (bookmark-save))))

(defun my/quick-access--remove (item persp workspace)
  "Remove ITEM from quick access in PERSP, named WORKSPACE.
Buffers remain live and workspace members; bookmarks retain other assignments."
  (if (bufferp item)
      (when (buffer-live-p item)
        (puthash persp
                 (cons item (delq item (cl-remove-if-not
                                        #'buffer-live-p
                                        (gethash persp my/quick-access--hidden))))
                 my/quick-access--hidden))
    (let ((scopes (bookmark-prop-get item 'my/quick-access-workspaces)))
      (when (member workspace scopes)
        (bookmark-prop-set item 'my/quick-access-workspaces (remove workspace scopes))
        (cl-incf bookmark-alist-modification-count)
        (bookmark-save)))))

(defun my/quick-access-restore-buffers ()
  "Restore all buffers hidden from quick access in the current workspace."
  (interactive)
  (remhash (get-current-persp) my/quick-access--hidden)
  (message "Hidden buffers restored for %s" (safe-persp-name (get-current-persp))))

(defun my/quick-access--label (item)
  "Return the display name of bookmark or buffer ITEM."
  (if (bufferp item) (buffer-name item) (car item)))

(defun my/quick-access--detail (item)
  "Return a compact target description without accessing the filesystem."
  (let ((file (if (bufferp item)
                  (buffer-local-value 'buffer-file-name item)
                (bookmark-get-filename item))))
    (if (and (stringp file) (not (equal file "")))
        (abbreviate-file-name file)
      (if (bufferp item)
          (with-current-buffer item
            (abbreviate-file-name default-directory))
        (or (bookmark-prop-get item 'buffer-name) "")))))

(defun my/quick-access--initial (item)
  "Return ITEM's first letter, ignoring punctuation and leading stars."
  (let ((name (my/quick-access--label item)))
    (if (string-match "[[:alnum:]]" name)
        (downcase (match-string 0 name))
      "?")))

(defun my/quick-access--codes (count)
  "Return COUNT prefix-free labels made from comfortable letter keys."
  (unless (and (>= (length my/quick-access-selection-keys) 2)
               (cl-every (lambda (key) (and (stringp key) (string-match-p "\\`[a-z]\\'" key))) my/quick-access-selection-keys)
               (= (length my/quick-access-selection-keys) (length (delete-dups (copy-sequence my/quick-access-selection-keys)))))
    (user-error "Selection keys must contain at least two distinct lowercase letters"))
  (let ((codes (copy-sequence my/quick-access-selection-keys)))
    (while (< (length codes) count)
      (let* ((shortest (apply #'min (mapcar #'length codes)))
             (index (cl-position shortest codes :key #'length :from-end t))
             (prefix (nth index codes)))
        (setq codes
              (append (cl-subseq codes 0 index)
                      (mapcar (lambda (key) (concat prefix key)) my/quick-access-selection-keys)
                      (nthcdr (1+ index) codes)))))
    (cl-subseq codes 0 count)))

(defun my/quick-access--entries (items home prefix)
  "Label ITEMS using HOME keys or initials; filter HOME labels by PREFIX."
  (let ((codes (and home (my/quick-access--codes (length items)))))
    (cl-loop for item in items for index from 0
             for code = (if home (nth index codes) (my/quick-access--initial item))
             when (or (not home) (string-prefix-p prefix code))
             collect (cons code item))))

(defun my/quick-access--clean-text (text)
  "Keep TEXT on one display line and remove embedded text properties."
  (replace-regexp-in-string "[\n\r\t]" " " (substring-no-properties text)))

(defun my/quick-access--render (buffer window workspace source entries page size prefix group &optional removing)
  "Draw ENTRIES in BUFFER and WINDOW, indicating REMOVING when active."
  (let* ((pages (max 1 (ceiling (length entries) size)))
         (page (min page (1- pages)))
         (visible (seq-subseq entries (min (* page size) (length entries))
                             (min (* (1+ page) size) (length entries)))))
    (with-current-buffer buffer
      (let ((inhibit-read-only t)
            (width (max 20 (- (window-body-width window) 4))))
        (erase-buffer)
        (insert "  " (propertize
                        (if removing
                            (if (eq source 'bookmarks) "Remove bookmark" "Hide recent buffer")
                          (if (eq source 'bookmarks) "Bookmarks" "Recent buffers"))
                        'face 'my/quick-access-title)
                "  " (propertize (my/quick-access--clean-text workspace) 'face 'shadow))
        (when group (insert (format "  / %s%s" group prefix)))
        (when (> pages 1) (insert (propertize (format "  (%d/%d)" (1+ page) pages)
                                            'face 'shadow)))
        (insert "\n\n")
        (if (null entries)
            (insert "  " (propertize
                           (if (eq source 'bookmarks)
                               "No bookmarks yet. C-s: save current location; C-i: add existing."
                             "No other recent buffers in this workspace.")
                           'face 'shadow) "\n")
          (dolist (entry visible)
            (let* ((item (cdr entry))
                   (key (substring (car entry) (length prefix)))
                   (start (point)))
              (insert "  " (propertize (format "%-3s" key) 'face 'my/quick-access-title)
                      (truncate-string-to-width
                       (my/quick-access--clean-text (my/quick-access--label item))
                       (- width 3) nil nil "…") "\n"
                      "     " (propertize
                               (truncate-string-to-width
                                (my/quick-access--clean-text (my/quick-access--detail item))
                                (- width 3) nil nil "…")
                               'face 'shadow) "\n")
              (add-text-properties start (point)
                                   `(my/quick-access-item ,item mouse-face highlight)))))
        (insert "\n  " (propertize
                         (concat (if (eq source 'bookmarks) "SPC Recent buffers" "SPC Bookmarks")
                                 (if removing "   C-d Cancel removal" "   C-d Remove")
                                 "   C-f Search   Esc Close") 'face 'shadow)
                "\n  " (propertize
                           (concat "C-s Save bookmark   C-i Add existing"
                                   (when group "   Backspace Back")
                                   (when (> pages 1) "   C-j/C-k Page"))
                           'face 'shadow) "\n")
        (goto-char (point-min))))
    (set-window-start window 1)
    (fit-window-to-buffer window (max 6 (floor (* my/quick-access-max-height (frame-height)))) 5)
    page))

(defun my/quick-access--search (items &optional prompt)
  "Read an ITEM through the user's existing completion interface."
  (unless items (user-error "No entries in this workspace"))
  (let* ((table (cl-loop for item in items for index from 1
                         collect (cons (format "%s  —  %s  <%d>"
                                               (my/quick-access--label item)
                                               (my/quick-access--detail item) index)
                                       item)))
         (choice (completing-read (or prompt "Open: ") table nil t)))
    (cdr (assoc choice table))))

;;;###autoload
(defun my/quick-access ()
  "Open workspace bookmarks; SPC toggles recent buffers.

Select bookmarks by initial and resolve collisions with `my/quick-access-selection-keys'; recent buffers use those keys directly. C-f searches the current source, including all eligible workspace buffers from the recent view. C-s saves the original location; C-i assigns an existing bookmark.

C-d toggles removal: select an entry to unassign its bookmark or hide its buffer in this workspace. The popup stays open after removal. Hidden buffers stay hidden for this session; `my/quick-access-restore-buffers' restores them. Escape or C-g closes the popup and restores the original window."
  (interactive)
  (when (or my/quick-access--active (active-minibuffer-window))
    (user-error "Finish the current selection first"))
  (let* ((persp (get-current-persp))
         (workspace (safe-persp-name persp))
         (origin (selected-window))
         (current (current-buffer))
         (buffers (my/quick-access--buffers persp current))
         (bookmarks (my/quick-access--bookmarks workspace))
         (my/quick-access--active t)
         (source 'bookmarks) group (prefix "") (page 0) removing
         (size (max 1 (min my/quick-access-page-size (/ (- (floor (* my/quick-access-max-height (frame-height))) 7) 2))))
         popup window selected
         (pick (lambda (item)
                 (when item
                   (if removing
                       (progn
                         (my/quick-access--remove item persp workspace)
                         (if (bufferp item)
                             (setq buffers (delq item buffers))
                           (setq bookmarks (delq item bookmarks)))
                         (setq removing nil group nil prefix "" page 0))
                     (throw 'my/quick-access-done item))))))
    (unwind-protect
        (progn
          (let ((persp-add-buffer-on-after-change-major-mode nil))
            (setq popup (generate-new-buffer my/quick-access--buffer-name))
            (with-current-buffer popup
              (special-mode)
              (setq-local header-line-format nil mode-line-format nil
                          display-line-numbers nil cursor-type nil
                          truncate-lines t show-trailing-whitespace nil)))
          (setq window
                (display-buffer-in-side-window
                 popup `((side . bottom) (slot . 10)
                         (window-height . ,my/quick-access-max-height)
                         (window-parameters . ((no-other-window . t)
                                               (no-delete-other-windows . t))))))
          (unless (window-live-p window) (user-error "Cannot display quick access"))
          (setq selected
                (catch 'my/quick-access-done
                  (while (and (window-live-p window) (window-live-p origin))
                    (let* ((items (if (eq source 'bookmarks)
                                      (if group
                                          (cl-remove-if-not
                                           (lambda (item) (equal group (my/quick-access--initial item)))
                                           bookmarks)
                                        bookmarks)
                                    (seq-take buffers my/quick-access-recent-count)))
                           (home (or group (eq source 'buffers)))
                           (entries (my/quick-access--entries items home prefix)))
                      (setq page (my/quick-access--render
                                  popup window workspace source entries page size prefix group removing))
                      (let ((event (read-key)))
                        (cond
                         ((memq event '(27 escape ?\C-g)) (throw 'my/quick-access-done nil))
                         ((eq event ?\C-d) (setq removing (not removing)))
                         ((eq event ?\s)
                          (setq source (if (eq source 'bookmarks) 'buffers 'bookmarks)
                                group nil prefix "" page 0 removing nil))
                         ((eq event ?\M-b)
                          (setq source 'bookmarks group nil prefix "" page 0 removing nil))
                         ((memq event '(backspace 127))
                          (if (string-empty-p prefix) (setq group nil)
                            (setq prefix (substring prefix 0 -1)))
                          (setq page 0))
                         ((memq event '(?\C-j ?\C-k))
                          (setq page (mod (+ page (if (eq event ?\C-j) 1 -1))
                                          (max 1 (ceiling (length entries) size)))))
                         ((memq event '(?\C-f ?/))
                          (condition-case err
                              (funcall pick
                                       (my/quick-access--search
                                        (if (eq source 'bookmarks) bookmarks buffers)
                                        (when removing "Remove from quick access: ")))
                            (quit nil) (user-error (message "%s" (cadr err)))))
                         ((memq event '(?\C-s ?\C-i tab))
                          (condition-case err
                              (progn
                                (with-selected-window origin
                                  (if (eq event ?\C-s)
                                      (call-interactively #'bookmark-set)
                                    (my/quick-access--add-bookmark workspace)))
                                (setq bookmarks (my/quick-access--bookmarks workspace)
                                      source 'bookmarks group nil prefix "" page 0 removing nil))
                            (quit nil) (user-error (message "%s" (cadr err)))))
                         ((and (consp event) (eq (car event) 'mouse-1))
                          (let ((pos (event-start event)))
                            (when (eq (posn-window pos) window)
                              (when-let* ((point (posn-point pos))
                                          ((integerp point))
                                          (item (get-text-property point 'my/quick-access-item popup)))
                                (funcall pick item)))))
                         ((and (characterp event) (>= event 32))
                          (let* ((key (downcase (char-to-string event)))
                                 (code (concat prefix key))
                                 (matches (cl-remove-if-not
                                           (lambda (entry)
                                             (if home (string-prefix-p code (car entry))
                                               (equal key (car entry)))) entries)))
                            (cond
                             ((and home (assoc code matches))
                              (funcall pick (cdr (assoc code matches))))
                             ((and (not home) (= 1 (length matches)))
                              (funcall pick (cdar matches)))
                             (matches
                              (if home (setq prefix code) (setq group key))
                              (setq page 0))))))))))))
      (when (and (window-live-p window) (eq (window-buffer window) popup))
        (delete-window window))
      (when (buffer-live-p popup) (kill-buffer popup))
      (when (window-live-p origin) (select-window origin)))
    (when selected
      (if (bufferp selected)
          (if (buffer-live-p selected) (switch-to-buffer selected)
            (user-error "That buffer has been closed"))
        (bookmark-jump selected))
      (when (bound-and-true-p persp-mode)
        (persp-add-buffer (current-buffer) persp nil nil)))))

(define-minor-mode my/quick-access-mode
  "Track workspace buffer visits and assign newly saved bookmarks to their workspace."
  :global t :group 'my/quick-access
  (if my/quick-access-mode
      (progn
        (add-hook 'post-command-hook #'my/quick-access--track)
        (advice-add 'bookmark-store :filter-args #'my/quick-access--scope-record)
        (advice-add 'persp-rename :around #'my/quick-access--renamed))
    (remove-hook 'post-command-hook #'my/quick-access--track)
    (advice-remove 'bookmark-store #'my/quick-access--scope-record)
    (advice-remove 'persp-rename #'my/quick-access--renamed)))

(provide 'my-quick-access)
;;; my-quick-access.el ends here
