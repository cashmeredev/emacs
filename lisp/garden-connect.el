;;; garden-connect.el --- unlinked-reference connector -*- lexical-binding: t; -*-

(require 'garden-core)
(require 'garden-icons)
(require 'garden-fleet)
(require 'vui)
(require 'vui-components)

(declare-function evil-define-key* "evil-core" (state keymap key def &rest bindings))
(declare-function evil-set-initial-state "evil-core" (mode state))

(defcustom garden-connect-min-title-length 3 "Minimum title length for a note to be scanned for mentions." :type 'integer :group 'garden)
(defcustom garden-connect-max-results 80 "Maximum number of unlinked references shown at once." :type 'integer :group 'garden)
(defcustom garden-connect-max-line 1500 "Maximum line length in characters before a line is skipped." :type 'integer :group 'garden)

(defvar-local garden--ref-target nil
  "Cons of (ID . TITLE) of the note shown in the connect buffer.")

(defvar-local garden-connect--dispatch nil
  "Async component actions exposed to `garden-connect-mode' commands.")

(defun garden--long-line-p ()
  "Whether the current line exceeds `garden-connect-max-line'."
  (> (- (line-end-position) (line-beginning-position)) garden-connect-max-line))

(defun garden--in-link-p (pos)
  "Whether POS is inside an Org bracket link."
  (save-excursion
    (goto-char pos)
    (let ((bol (line-beginning-position)) (depth 0))
      (goto-char bol)
      (while (< (point) pos)
        (cond ((looking-at "\\[\\[") (setq depth (1+ depth)) (forward-char 2))
              ((looking-at "\\]\\]") (when (> depth 0) (setq depth (1- depth))) (forward-char 2))
              (t (forward-char 1))))
      (> depth 0))))

(defun garden--in-block-p (pos)
  "Whether POS is inside an Org src or example block."
  (save-excursion
    (save-match-data
      (goto-char pos)
      (let ((case-fold-search t))
        (and (re-search-backward "^[ \t]*#\\+\\(begin\\|end\\)_\\(src\\|example\\)\\>" nil t)
             (string-equal (downcase (match-string 1)) "begin"))))))

(defun garden--denote-link-text (id matched)
  "Return a denote link to ID with MATCHED as the description."
  (format "[[denote:%s][%s]]" id matched))

(defun garden--note-list ()
  "Return all garden notes as a list."
  (let (acc) (maphash (lambda (_ n) (push n acc)) (garden-notes)) acc))

(defun garden-unlinked-references-for (id title)
  "Find notes that mention TITLE without linking to the note ID.
Return a list of plists with the first mention found per note."
  (let ((re (concat "\\_<" (regexp-quote title) "\\_>"))
        (case-fold-search t)
        (results '()))
    (dolist (note (garden--note-list))
      (unless (or (equal (garden-note-id note) id)
                  (member id (garden-note-links note)))
        (with-temp-buffer
          (insert-file-contents (garden-note-file note))
          (goto-char (point-min))
          (catch 'found
            (while (re-search-forward re nil t)
              (let ((mb (match-beginning 0)))
                (if (garden--long-line-p)
                    (goto-char (line-end-position))
                  (save-excursion
                    (goto-char mb)
                    (beginning-of-line)
                    (when (and (not (looking-at-p "[ \t]*\\(#\\+\\|:[A-Za-z]\\)"))
                               (not (garden--in-link-p mb))
                               (not (garden--in-block-p mb)))
                      (push (list :id (garden-note-id note)
                                  :title (garden-note-title note)
                                  :file (garden-note-file note)
                                  :beg mb
                                  :line (line-number-at-pos mb)
                                  :context (string-trim (buffer-substring
                                                         (line-beginning-position)
                                                         (line-end-position))))
                            results)
                      (throw 'found t))))))))))
    (nreverse results)))

(defun garden-linkify (file beg id title)
  "Replace the mention of TITLE at BEG in FILE with a link to ID.
Save FILE afterwards."
  (with-current-buffer (find-file-noselect file)
    (save-excursion
      (goto-char beg)
      (let ((case-fold-search t)
            (re (concat "\\_<" (regexp-quote title) "\\_>")))
        (when (looking-at re)
          (let ((matched (match-string 0)))
            (unless (save-match-data (or (garden--in-link-p beg) (garden--in-block-p beg)))
              (replace-match (garden--denote-link-text id matched) t t))))))
    (save-buffer)))

(defun garden--read-note ()
  "Prompt for a garden note and return its id."
  (let* ((table (let (acc)
                  (maphash (lambda (_id n) (push (cons (garden-note-title n) n) acc)) (garden-notes))
                  acc))
         (annotate (lambda (title)
                     (when-let* ((note (cdr (assoc title table))))
                       (garden-note-annotation note))))
         (choice (completing-read "Find unlinked references to: "
                                  (garden-completion-table (mapcar #'car table) annotate) nil t)))
    (garden-note-id (cdr (assoc choice table)))))

(defun garden--current-note-id ()
  "Return the note id of the current buffer's file, or nil."
  (and (buffer-file-name)
       (let ((id (garden--file-id (buffer-file-name))))
         (and id (garden-note id) id))))

(defun garden-connect--window-width ()
  "Return the body width of the window displaying the connect buffer."
  (if-let* ((window (get-buffer-window (current-buffer) t)))
      (window-body-width window)
    (window-width)))

(defun garden-connect--scan (id title)
  "Return the capped unlinked-reference scan for ID and TITLE."
  (seq-take (garden-unlinked-references-for id title)
            garden-connect-max-results))

(defun garden--ref-card (ref id title on-linked)
  "Render REF as a narrow card for target ID and TITLE.
Call ON-LINKED after successfully adding its link."
  (let ((file (plist-get ref :file))
        (line (plist-get ref :line))
        (beg (plist-get ref :beg)))
    (vui-vstack :spacing 0
      (vui-flex :width 'window :justify :space-between
        (vui-flex-item :grow 1
          (lambda (width)
            (vui-button (plist-get ref :title)
                        :key file :no-decoration t :max-width width
                        :face '(:inherit bold)
                        :on-click (lambda ()
                                    (find-file file)
                                    (goto-char (point-min))
                                    (forward-line (1- line))))))
        (vui-muted (format "line %d" line))
        (vui-button (concat (garden-icon 'link) " link")
          :on-click (lambda ()
                      (garden-linkify file beg id title)
                      (garden-refresh)
                      (garden-fleet--refresh)
                      (funcall on-linked))))
      (vui-box (vui-text (plist-get ref :context) :face 'shadow)
               :width (max 12 (- (garden-connect--window-width) 2))
               :padding-left 2))))

(defun garden-connect--table (refs id title on-linked width)
  "Render REFS as a sticky review table for ID and TITLE at WIDTH."
  (let ((context-width (max 22 (- width 34))))
    (vui-table
     :sticky-header t
     :columns `((:header "Note" :width 20 :grow t :truncate t)
                (:header "Line" :width 6 :align :right)
                (:header "Mention" :width ,context-width :grow t :truncate t)
                (:header "" :width 7))
     :rows
     (mapcar
      (lambda (ref)
        (let ((file (plist-get ref :file))
              (line (plist-get ref :line))
              (beg (plist-get ref :beg)))
          (list
           (vui-button (plist-get ref :title)
                       :key file :no-decoration t :help-echo file
                       :on-click (lambda ()
                                   (find-file file)
                                   (goto-char (point-min))
                                   (forward-line (1- line))))
           (vui-text (number-to-string line) :face 'shadow)
           (vui-text (plist-get ref :context) :face 'shadow)
           (vui-button "link" :face 'success
                       :on-click (lambda ()
                                   (garden-linkify file beg id title)
                                   (garden-refresh)
                                   (garden-fleet--refresh)
                                   (funcall on-linked))))))
      refs))))

(defun garden--linkify-note (file id title)
  "Link the first valid mention of TITLE in FILE to ID.
Return the number of replacements made."
  (let ((re (concat "\\_<" (regexp-quote title) "\\_>"))
        (case-fold-search t)
        (n 0))
    (with-current-buffer (find-file-noselect file)
      (save-excursion
        (goto-char (point-min))
        (catch 'done
          (while (re-search-forward re nil t)
            (let ((mb (match-beginning 0))
                  (matched (match-string 0)))
              (cond
               ((garden--long-line-p) (goto-char (line-end-position)))
               ((save-match-data
                  (save-excursion
                    (goto-char mb)
                    (or (progn (beginning-of-line)
                               (looking-at-p "[ \t]*\\(#\\+\\|:[A-Za-z]\\)"))
                        (garden--in-link-p mb)
                        (garden--in-block-p mb)))))
               (t (replace-match (garden--denote-link-text id matched) t t)
                  (setq n 1)
                  (throw 'done t)))))))
      (when (> n 0) (save-buffer)))
    n))

(defun garden-connect-all (&optional id title)
  "Link every note that mentions the target note, after confirming.
When called interactively, ID and TITLE default to the note shown in
the current connect buffer."
  (interactive)
  (let* ((id (or id (car garden--ref-target)))
         (title (or title (cdr garden--ref-target)))
         (refs (garden-unlinked-references-for id title))
         (files (delete-dups (mapcar (lambda (r) (plist-get r :file)) refs)))
         (n 0))
    (when (and refs
               (yes-or-no-p (format "Connect all %d note(s) that mention “%s”? " (length refs) title)))
      (dolist (f files) (setq n (+ n (garden--linkify-note f id title))))
      (garden-refresh)
      (message "garden: connected %d note(s) to %s" n title))))

(vui-defcomponent garden-references (id title)
  :state ((refs (garden-connect--scan id title))
          (busy nil)
          (status nil))
  :render
  (let* ((width (garden-connect--window-width))
         (rescan (vui-async-callback ()
                   (vui-batch
                    (vui-set-state :busy t)
                    (vui-set-state :status nil))
                   (garden-refresh)
                   (vui-batch
                    (vui-set-state :refs (garden-connect--scan id title))
                    (vui-set-state :busy nil))))
         (linked (vui-async-callback ()
                   (vui-set-state :refs (garden-connect--scan id title)))))
    (setq garden-connect--dispatch (list :refresh rescan))
    (vui-vstack
     :spacing 1 :indent 2
     (vui-flex
      :width 'window :justify :space-between
      (vui-heading-2 (format "%s connect" (garden-icon 'link)))
      (vui-text (format "%d / %d max" (length refs) garden-connect-max-results)
                :face 'shadow))
     (vui-text title :face '(:inherit outline-2 :weight bold))
     (vui-muted "Review first mentions one by one; bulk linking always asks for confirmation.")
     (vui-hstack
      :spacing 2
      (when refs
        (vui-button (concat (garden-icon 'link) " link all")
                    :face 'warning
                    :on-click (lambda ()
                                (garden-connect-all id title)
                                (funcall rescan))))
      (vui-button (concat (garden-icon 'refresh) " rescan")
                  :on-click rescan)
      (vui-button (concat (garden-icon 'star) " another note")
                  :on-click #'garden-connect-pick))
     (cond
      (busy (vui-warning "Scanning the garden…"))
      ((null refs)
       (vui-vstack
        :spacing 1
        (vui-box (vui-text (garden-icon 'sparkle)
                           :face '(:inherit success :height 2.0))
                 :width width :align :center)
        (vui-box (vui-success "All linked up") :width width :align :center)
        (vui-box (vui-muted "Every mention already points back to this note")
                 :width width :align :center)))
      ((>= width 88)
       (garden-connect--table refs id title linked width))
      (t
       (vui-list refs
                 (lambda (ref) (garden--ref-card ref id title linked))
                 (lambda (ref) (plist-get ref :file))
                 :spacing 1)))
     (when status (vui-text (car status) :face (cdr status)))
     (vui-flex :width 'window :justify :space-between
               (vui-muted "j/k move · TAB/S-TAB elements · RET/l activate")
               (vui-muted "g rescan · ? help · h/q close")))))

(defun garden-connect-refresh ()
  "Rescan the current connect target."
  (interactive)
  (if-let* ((fn (plist-get garden-connect--dispatch :refresh)))
      (funcall fn)
    (user-error "Connect view is not ready")))

(defun garden-connect-help ()
  "Show keyboard help for the connect review screen."
  (interactive)
  (message "Garden Connect: j/k move, TAB/S-TAB elements, RET/l activate, g rescan, h/q close"))

(defvar garden-connect-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map vui-mode-map)
    (keymap-set map "j" #'next-line)
    (keymap-set map "k" #'previous-line)
    (keymap-set map "TAB" #'vui-forward)
    (keymap-set map "<backtab>" #'vui-backward)
    (keymap-set map "RET" #'vui-activate)
    (keymap-set map "l" #'vui-activate)
    (keymap-set map "g" #'garden-connect-refresh)
    (keymap-set map "?" #'garden-connect-help)
    (keymap-set map "h" #'vui-quit)
    (keymap-set map "q" #'vui-quit)
    map))

(define-derived-mode garden-connect-mode vui-mode "Garden-Connect"
  "Review unlinked Garden references."
  (hl-line-mode 1))

(with-eval-after-load 'evil
  (evil-set-initial-state 'garden-connect-mode 'normal)
  (evil-define-key* '(normal motion) garden-connect-mode-map
    (kbd "j") #'next-line (kbd "k") #'previous-line
    (kbd "RET") #'vui-activate (kbd "l") #'vui-activate
    (kbd "g") #'garden-connect-refresh (kbd "?") #'garden-connect-help
    (kbd "h") #'vui-quit (kbd "q") #'vui-quit))

(defun garden--connect-show (id)
  "Open the connect buffer for the note with ID."
  (let ((note (garden-note id)))
    (unless note (user-error "Not a garden note"))
    (let ((title (garden-note-title note)))
      (let ((buffer (get-buffer-create "*garden connect*")))
        (with-current-buffer buffer
          (garden-connect-mode)
          (setq-local garden--ref-target (cons id title))
          (vui-mount (vui-component 'garden-references :id id :title title) buffer)
          (vui-rerender-on-resize))
        (switch-to-buffer buffer)))))

;;;###autoload
(defun garden-connect ()
  "Show unlinked references to the current note, or prompt for one."
  (interactive)
  (garden-build)
  (garden--connect-show (or (garden--current-note-id) (garden--read-note))))

;;;###autoload
(defun garden-connect-pick ()
  "Prompt for a note and show its unlinked references."
  (interactive)
  (garden-build)
  (garden--connect-show (garden--read-note)))

(provide 'garden-connect)
;;; garden-connect.el ends here
