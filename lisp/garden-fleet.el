;;; garden-fleet.el --- import & process fleeting notes -*- lexical-binding: t; -*-

(require 'garden-core)
(require 'garden-icons)
(require 'garden-preview)
(require 'vui)
(require 'vui-components)

(declare-function evil-define-key* "evil-core" (state keymap key def &rest bindings))
(declare-function evil-set-initial-state "evil-core" (mode state))

(defvar denote-directory)
(defvar denote-rename-confirmations)
(defvar denote-save-buffers)
(defvar denote-kill-buffers)
(declare-function denote-rename-file "denote")
(declare-function garden "garden-dashboard")

(defcustom garden-fleet-source-directory (expand-file-name "~/org/")
  "Directory scanned for fleeting notes to import."
  :type 'directory :group 'garden)

(defcustom garden-fleet-tags '("fleet" "capture")
  "Tags marking a note as fleeting."
  :type '(repeat string) :group 'garden)

(defcustom garden-fleet-data-file (expand-file-name ".garden/fleet.eld" garden-directory)
  "File persisting the manual ordering of staged fleet notes."
  :type 'file :group 'garden)

(defvar garden-fleet--order nil
  "List of staged note ids in their manual order.")

(defvar-local garden-fleet--dispatch nil
  "Async actions exposed by the mounted Fleet component.")

(defun garden-fleet--refresh ()
  "Re-render every live garden VUI buffer."
  (dolist (name '("*garden-fleet*" "*garden*" "*garden connect*"))
    (when-let* ((buf (get-buffer name))
                (root (buffer-local-value 'vui--root-instance buf)))
      (vui-rerender root))))

(defun garden-fleet--load-order ()
  "Load the staged-note order from `garden-fleet-data-file'."
  (setq garden-fleet--order
        (when (file-exists-p garden-fleet-data-file)
          (with-temp-buffer
            (insert-file-contents garden-fleet-data-file)
            (ignore-errors (read (current-buffer)))))))

(defun garden-fleet--save-order ()
  "Persist the staged-note order to `garden-fleet-data-file'."
  (make-directory (file-name-directory garden-fleet-data-file) t)
  (with-temp-file garden-fleet-data-file (prin1 garden-fleet--order (current-buffer))))

(defun garden-fleet--file-tags (file)
  "Return all tags encoded in FILE's name, provenance included."
  (let ((base (file-name-nondirectory file)))
    (when (string-match "__\\([a-zA-Z0-9_-]+\\)\\.org\\'" base)
      (split-string (match-string 1 base) "_" t))))

(defun garden-fleet--fleet-p (tags)
  "Return non-nil when TAGS marks a fleeting note."
  (seq-intersection tags garden-fleet-tags))

(defun garden-fleet--source-files ()
  "Return the Denote-named org files in `garden-fleet-source-directory'."
  (directory-files garden-fleet-source-directory t "\\`[0-9]\\{8\\}T[0-9]\\{6\\}.*\\.org\\'"))

(defun garden-fleet-candidates ()
  "Return fleeting files in the inbox not yet imported."
  (seq-filter (lambda (f)
                (and (garden-fleet--fleet-p (garden-fleet--file-tags f))
                     (not (garden-note (garden--file-id f)))))
              (garden-fleet--source-files)))

(defun garden-fleet-staged ()
  "Return imported fleet notes, manual order first, newest after."
  (let (acc)
    (maphash (lambda (_id note)
               (when (garden-fleet--fleet-p (garden-fleet--file-tags (garden-note-file note)))
                 (push note acc)))
             (garden-notes))
    (let ((by-id (make-hash-table :test 'equal)))
      (dolist (note acc) (puthash (garden-note-id note) note by-id))
      (let ((ordered (seq-keep (lambda (id) (gethash id by-id)) garden-fleet--order))
            (rest (seq-remove (lambda (note) (member (garden-note-id note) garden-fleet--order)) acc)))
        (append ordered (seq-sort-by #'garden-note-id #'string> rest))))))

(defun garden-fleet-import (file)
  "Move FILE from the inbox into the garden and stage it."
  (garden-fleet--load-order)
  (let* ((id (garden--file-id file))
         (dest (expand-file-name (file-name-nondirectory file) garden-directory)))
    (cond
     ((file-exists-p dest)
      (message "garden: %s already in the garden — skipped" (file-name-nondirectory file)))
     (t
      (rename-file file dest)
      (setq garden-fleet--order (append garden-fleet--order (list id)))
      (garden-fleet--save-order)
      (garden-build)
      (message "garden: imported %s" (file-name-nondirectory dest))))))

(defun garden-fleet-import-all ()
  "Import every fleeting note from the inbox after confirmation."
  (interactive)
  (let ((files (garden-fleet-candidates)))
    (when (and files
               (yes-or-no-p (format "Import all %d fleet/capture note(s) into the garden? " (length files))))
      (dolist (f files) (garden-fleet-import f))
      (garden-build))))

(defun garden-fleet--rename (file keywords)
  "Rename FILE via denote so its name carries exactly KEYWORDS."
  (require 'denote)
  (let ((denote-directory (file-name-as-directory (expand-file-name garden-directory)))
        (denote-rename-confirmations nil)
        (denote-save-buffers t)
        (denote-kill-buffers t))
    (denote-rename-file file 'keep-current keywords 'keep-current 'keep-current 'keep-current)))

(defun garden-fleet-classify (id)
  "Prompt for topic tags to add to the note with ID.
Suggested tags are listed first and marked in the completion UI."
  (let* ((note (garden-note id))
         (file (garden-note-file note))
         (current (garden-fleet--file-tags file))
         (suggested (garden-suggest-tags file))
         (choices (seq-difference (mapcar #'car (garden-keywords-sorted)) current))
         (choices (append suggested (seq-difference choices suggested)))
         (annotate (lambda (k)
                     (concat
                      (propertize (format "  %d notes" (gethash k (garden-keyword-counts) 0))
                                  'face 'completions-annotations)
                      (or (when (member k suggested)
                            (propertize (format "  %s suggested" (garden-icon 'sparkle))
                                        'face 'completions-annotations))
                          ""))))
         (prompt (if suggested
                     (format "Topic tag(s) for “%s” (%s maybe: %s): "
                             (garden-note-title note) (garden-icon 'sparkle)
                             (string-join suggested ", "))
                   (format "Topic tag(s) for “%s”: " (garden-note-title note))))
         (added (completing-read-multiple prompt (garden-completion-table choices annotate))))
    (when added
      (garden-fleet--rename file (delete-dups (append current added)))
      (garden-build))))

(defun garden-fleet-tag (id tag)
  "Add the single TAG to the note with ID without prompting."
  (let* ((note (garden-note id))
         (file (garden-note-file note))
         (current (garden-fleet--file-tags file)))
    (garden-fleet--rename file (delete-dups (append current (list tag))))
    (garden-build)
    (message "garden: tagged “%s” with %s" (garden-note-title note) tag)))

(defun garden-fleet-delete (id)
  "Trash the staged note with ID and drop it from the order."
  (garden-fleet--load-order)
  (when (garden-delete-note id)
    (setq garden-fleet--order (delete id garden-fleet--order))
    (garden-fleet--save-order)))

(defun garden-fleet-return (id)
  "Send the staged note with ID back to the ~/org inbox.
Moves its file to `garden-fleet-source-directory', drops it from
the manual order, and rebuilds the index."
  (garden-fleet--load-order)
  (let* ((note (garden-note id))
         (file (garden-note-file note))
         (dest (expand-file-name (file-name-nondirectory file) garden-fleet-source-directory)))
    (make-directory garden-fleet-source-directory t)
    (if (file-exists-p dest)
        (message "garden: %s already in ~/org — left in place" (file-name-nondirectory file))
      (when-let* ((buf (find-buffer-visiting file)))
        (kill-buffer buf))
      (rename-file file dest)
      (setq garden-fleet--order (delete id garden-fleet--order))
      (garden-fleet--save-order)
      (garden-build)
      (message "garden: returned “%s” to ~/org" (garden-note-title note)))))

(defun garden-fleet-discard (file)
  "Trash the inbox candidate FILE after confirmation."
  (when (yes-or-no-p (format "Move “%s” to the trash? " (garden--file-title file)))
    (let ((delete-by-moving-to-trash t))
      (delete-file file t))
    (message "garden: discarded %s" (file-name-nondirectory file))))

(defun garden-fleet-graduate (id)
  "Remove the fleeting tags from the note with ID after confirmation."
  (garden-fleet--load-order)
  (let* ((note (garden-note id))
         (file (garden-note-file note))
         (keywords (seq-remove (lambda (k) (member k garden-fleet-tags))
                               (garden-fleet--file-tags file))))
    (when (yes-or-no-p (format "Graduate “%s” out of fleet? " (garden-note-title note)))
      (garden-fleet--rename file keywords)
      (setq garden-fleet--order (delete id garden-fleet--order))
      (garden-fleet--save-order)
      (garden-build)
      (message "garden: graduated %s" (garden-note-title note)))))

(defun garden-fleet-move (id delta)
  "Move the staged note with ID by DELTA positions in the order."
  (garden-fleet--load-order)
  (let* ((ids (mapcar #'garden-note-id (garden-fleet-staged)))
         (pos (seq-position ids id))
         (new (and pos (+ pos delta))))
    (when (and pos new (>= new 0) (< new (length ids)))
      (let ((other (nth new ids)))
        (setq garden-fleet--order
              (mapcar (lambda (x) (cond ((equal x id) other) ((equal x other) id) (t x))) ids))
        (garden-fleet--save-order)))))

(defun garden-fleet--topic-tags (file)
  "Return FILE's topic keywords, with provenance and status dropped."
  (seq-difference (garden--file-keywords file) garden-fleet-tags))

(defun garden-fleet--icon-action (icon help on-click &optional face label)
  "Render a quiet ICON button with HELP tooltip running ON-CLICK."
  (vui-button (if label (format "%s %s" (garden-icon icon) label)
                (garden-icon icon))
    :no-decoration (null label) :help-echo help :face face :on-click on-click))

(defun garden-fleet--candidate-row (file width)
  "Render an inbox card for FILE using WIDTH."
  (let ((tags-str (string-join (garden-fleet--topic-tags file) " "))
        (actions (vui-hstack :spacing 1
                   (garden-fleet--icon-action 'import "import into the garden"
                     (lambda () (unwind-protect (garden-fleet-import file) (garden-fleet--refresh)))
                     'success "import")
                   (garden-fleet--icon-action 'preview "peek in the side window"
                     (lambda () (garden-preview-show file)) 'link)
                   (garden-fleet--icon-action 'delete "move to the trash"
                     (lambda () (unwind-protect (garden-fleet-discard file) (garden-fleet--refresh)))
                     'error))))
    (vui-vstack
     :spacing 0 :face 'fringe
     (vui-flex
      :width width :justify :space-between
      (vui-flex-item
       :grow 1
       (lambda (available)
         (vui-button (garden--file-title file)
                     :key file :no-decoration t :help-echo file
                     :max-width available :face '(:inherit bold)
                     :on-click (lambda () (find-file file)))))
      (vui-muted "inbox"))
     (vui-box (vui-text (if (string-empty-p tags-str)
                            "no topic tags"
                          (format "#%s" (string-replace " " "  #" tags-str)))
                        :face 'shadow)
              :width width :padding-left 2)
     actions)))

(defun garden-fleet--chips (id tags)
  "Return a dot-separated list of one-click chips tagging note ID."
  (let (out)
    (dolist (tag tags)
      (when out (push (vui-muted "·") out))
      (push (vui-button tag
              :no-decoration t
              :help-echo (format "click to tag with “%s” right away" tag)
              :on-click (lambda () (unwind-protect (garden-fleet-tag id tag) (garden-fleet--refresh))))
            out))
    (nreverse out)))

(defun garden-fleet--suggestion-chips (id file)
  "Render one-click suggested-tag chips for the note ID in FILE.
The chips line up beneath the title column of the staged row above."
  (let ((suggested (garden-suggest-tags file)))
    (when suggested
      (apply #'vui-hstack :spacing 1
             (vui-muted "maybe →")
             (garden-fleet--chips id suggested)))))

(defun garden-fleet--staged-row (note width)
  "Render a staged card for NOTE using WIDTH."
  (let* ((id (garden-note-id note))
         (file (garden-note-file note))
         (tags-str (string-join (garden-fleet--topic-tags file) " "))
         (queue (vui-hstack :spacing 1
                  (garden-fleet--icon-action 'up "move up the queue"
                    (lambda () (unwind-protect (garden-fleet-move id -1) (garden-fleet--refresh))))
                  (garden-fleet--icon-action 'down "move down the queue"
                    (lambda () (unwind-protect (garden-fleet-move id 1) (garden-fleet--refresh))))))
         (actions (vui-hstack :spacing 1
                    (garden-fleet--icon-action 'classify "add topic tags"
                      (lambda () (unwind-protect (garden-fleet-classify id) (garden-fleet--refresh)))
                      'link "classify")
                    (garden-fleet--icon-action 'graduate "graduate out of fleet"
                      (lambda () (unwind-protect (garden-fleet-graduate id) (garden-fleet--refresh)))
                      'success "graduate")
                    (garden-fleet--icon-action 'preview "peek in the side window"
                      (lambda () (garden-preview-show file)) 'link)
                    (garden-fleet--icon-action 'return "send back to the ~/org inbox"
                      (lambda () (unwind-protect (garden-fleet-return id) (garden-fleet--refresh)))
                      'warning))))
    (vui-vstack :spacing 0 :face 'fringe
      (vui-flex :width width :justify :space-between
        queue
        (vui-flex-item :grow 1
          (lambda (w)
            (vui-button (garden-note-title note)
                        :key id :no-decoration t :help-echo file
                        :max-width w :face '(:inherit bold)
                        :on-click (lambda () (find-file file)))))
        (vui-muted "staged"))
      (vui-box (vui-text (if (string-empty-p tags-str)
                             "no topic tags"
                           (format "#%s" (string-replace " " "  #" tags-str)))
                         :face 'shadow)
               :width width :padding-left 2)
      (garden-fleet--suggestion-chips id file)
      actions)))

(defun garden-fleet--header ()
  "Render the fleet dashboard banner."
  (let ((icon (garden-icon 'fleet))
        (wave (garden-icon 'leaf)))
    (vui-vstack
     (vui-text (format "~  %s  ~  %s  ~  %s  ~" wave icon wave) :face 'garden-meta)
     (vui-heading-1 (format "%s  fleeting notes" icon))
     (vui-muted "import from ~/org, then order · classify · redo them"))))

(defun garden-fleet--window-width ()
  "Return the live Fleet window body width."
  (if-let* ((window (get-buffer-window (current-buffer) t)))
      (window-body-width window)
    (window-width)))

(defun garden-fleet--panel (title empty items renderer width)
  "Render a Fleet panel with TITLE, EMPTY message and ITEMS.
RENDERER receives each item and WIDTH."
  (vui-vstack
   :spacing 1
   (vui-flex :width width :justify :space-between
             (vui-heading-2 title)
             (vui-text (number-to-string (length items)) :face 'shadow))
   (if (null items)
       (vui-box (vui-text empty :face 'shadow) :width width :align :center)
     (vui-list items
               (lambda (item) (funcall renderer item width))
               (lambda (item)
                 (if (stringp item) item (garden-note-id item)))
               :spacing 1))))

(defun garden-fleet--view ()
  "Render the fleet dashboard: inbox candidates and staged notes."
  (let* ((candidates (garden-fleet-candidates))
         (staged (garden-fleet-staged))
         (width (garden-fleet--window-width))
         (wide (>= width 100))
         (panel-width (if wide (max 42 (/ (- width 6) 2)) (max 28 (- width 4))))
         (refresh (vui-with-async-context
                    (garden-refresh)
                    (garden-fleet--refresh))))
    (setq garden-fleet--dispatch (list :refresh refresh))
    (vui-vstack :spacing 1 :indent 2
      (garden-fleet--header)
      (vui-flex :width 'window :justify :space-between
       (vui-hstack :spacing 2
        (vui-button (concat (garden-icon 'refresh) " rescan")
          :on-click refresh)
        (vui-button (concat (garden-icon 'import) " import all")
          :on-click (lambda () (unwind-protect (garden-fleet-import-all) (garden-fleet--refresh))))
        (vui-button (concat (garden-icon 'preview) " preview")
          :on-click (lambda () (garden-preview-mode 'toggle) (garden-fleet--refresh)))
        (vui-button (concat (garden-icon 'star) " garden")
          :on-click (lambda () (garden))))
       (vui-muted (format "%d inbox · %d staged" (length candidates) (length staged))))
      (if wide
          (vui-hstack
           :spacing 4
           (garden-fleet--panel
            (concat (garden-icon 'inbox) " inbox")
            "Inbox empty — nothing to import"
            candidates #'garden-fleet--candidate-row panel-width)
           (garden-fleet--panel
            (concat (garden-icon 'tools) " staged")
            "Nothing staged — import a note first"
            staged #'garden-fleet--staged-row panel-width))
        (vui-vstack
         :spacing 1
         (garden-fleet--panel
          (concat (garden-icon 'inbox) " inbox")
          "Inbox empty — nothing to import"
          candidates #'garden-fleet--candidate-row panel-width)
         (garden-fleet--panel
          (concat (garden-icon 'tools) " staged")
          "Nothing staged — import a note first"
          staged #'garden-fleet--staged-row panel-width)))
      (vui-flex :width 'window :justify :space-between
                (vui-muted "j/k move · TAB/S-TAB elements · RET/l activate")
                (vui-muted "g rescan · ? help · h garden · q close")))))

(vui-defcomponent garden-fleet-dashboard ()
  :render (garden-fleet--view))

(defun garden-fleet-refresh ()
  "Rescan and refresh the Fleet dashboard."
  (interactive)
  (if-let* ((fn (plist-get garden-fleet--dispatch :refresh)))
      (funcall fn)
    (user-error "Fleet dashboard is not ready")))

(defun garden-fleet-back ()
  "Return to a live Garden dashboard, or close Fleet."
  (interactive)
  (if-let* ((buffer (get-buffer "*garden*")))
      (switch-to-buffer buffer)
    (vui-quit)))

(defun garden-fleet-help ()
  "Show Fleet keyboard help."
  (interactive)
  (message "Garden Fleet: j/k move, TAB/S-TAB elements, RET/l activate, g rescan, h garden, q close"))

(defvar garden-fleet-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map vui-mode-map)
    (keymap-set map "j" #'next-line)
    (keymap-set map "k" #'previous-line)
    (keymap-set map "TAB" #'vui-forward)
    (keymap-set map "<backtab>" #'vui-backward)
    (keymap-set map "RET" #'vui-activate)
    (keymap-set map "l" #'vui-activate)
    (keymap-set map "g" #'garden-fleet-refresh)
    (keymap-set map "?" #'garden-fleet-help)
    (keymap-set map "h" #'garden-fleet-back)
    (keymap-set map "q" #'vui-quit)
    map))

(define-derived-mode garden-fleet-mode vui-mode "Garden-Fleet"
  "Manage the Garden fleeting-note queues."
  (hl-line-mode 1))

(with-eval-after-load 'evil
  (evil-set-initial-state 'garden-fleet-mode 'normal)
  (evil-define-key* '(normal motion) garden-fleet-mode-map
    (kbd "j") #'next-line (kbd "k") #'previous-line
    (kbd "RET") #'vui-activate (kbd "l") #'vui-activate
    (kbd "g") #'garden-fleet-refresh (kbd "?") #'garden-fleet-help
    (kbd "h") #'garden-fleet-back (kbd "q") #'vui-quit))

;;;###autoload
(defun garden-fleet ()
  "Open the fleet dashboard for importing and classifying fleeting notes."
  (interactive)
  (garden-build)
  (garden-fleet--load-order)
  (let ((buffer (get-buffer-create "*garden-fleet*")))
    (with-current-buffer buffer
      (garden-fleet-mode)
      (vui-mount (vui-component 'garden-fleet-dashboard) buffer)
      (vui-rerender-on-resize))
    (switch-to-buffer buffer)))

(provide 'garden-fleet)
;;; garden-fleet.el ends here
