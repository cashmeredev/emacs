;;; my-header-line.el --- Custom header line built with mode-line-maker -*- lexical-binding: t; -*-

(require 'mode-line-maker)

(defface my/header-line-evil-normal
  '((t (:inherit font-lock-keyword-face :weight bold)))
  "Face for the evil normal state indicator.")

(defface my/header-line-evil-insert
  '((t (:inherit success :weight bold)))
  "Face for the evil insert state indicator.")

(defface my/header-line-evil-visual
  '((t (:inherit warning :weight bold)))
  "Face for the evil visual state indicator.")

(defface my/header-line-evil-replace
  '((t (:inherit error :weight bold)))
  "Face for the evil replace state indicator.")

(defface my/header-line-evil-motion
  '((t (:inherit font-lock-constant-face :weight bold)))
  "Face for the evil motion state indicator.")

(defface my/header-line-evil-emacs
  '((t (:inherit font-lock-builtin-face :weight bold)))
  "Face for the evil Emacs state indicator.")

(defface my/header-line-buffer-icon-face
  '((t (:inherit mode-line-buffer-id)))
  "Face for the current buffer's file or mode icon.")

(defface my/header-line-irc-face
  '((t (:inherit font-lock-builtin-face :weight bold)))
  "Face for the IRC activity indicator.")

(defface my/header-line-clatter-face
  '((t (:inherit font-lock-builtin-face :weight bold)))
  "Face for the Clatter joined-channel indicator.")

(defface my/header-line-mu4e-face
  '((t (:inherit warning :weight bold)))
  "Face for the unread mail indicator.")

(defface my/header-line-time-face
  '((t (:inherit font-lock-constant-face)))
  "Face for the time segment.")

(defface my/header-line-state-saved-face
  '((t (:inherit success)))
  "Face for the saved buffer state icon.")

(defface my/header-line-state-modified-face
  '((t (:inherit warning :weight bold)))
  "Face for the modified buffer state icon.")

(defface my/header-line-state-read-only-face
  '((t (:inherit error)))
  "Face for the read-only buffer state icon.")

(defvar-local my/header-line--buffer-title nil)

(defconst my/header-line--missing (make-symbol "missing")
  "Sentinel used when checking membership in package hash tables.")

(defvar my/header-line--format nil
  "The installed global header-line format.")

(defun my/header-line--update-title-cache ()
  "Update the cached #+title for the current buffer."
  (setq-local my/header-line--buffer-title
              (and (derived-mode-p 'org-mode)
                   (cadar (org-collect-keywords '("TITLE"))))))

(defun my/header-line--buffer-title ()
  "Return the cached #+title, computing it if necessary."
  (unless (local-variable-p 'my/header-line--buffer-title)
    (my/header-line--update-title-cache))
  my/header-line--buffer-title)

(defun my/header-line--invalidate-title-cache ()
  "Invalidate the cached title so it gets recomputed on next update."
  (kill-local-variable 'my/header-line--buffer-title))

(defun my/header-line-buffer-name ()
  "Buffer name for the header line.
Uses the Org #+title if present, otherwise the file path relative to
the project root, falling back to the plain buffer name."
  (or (my/header-line--buffer-title)
      (if-let* ((file buffer-file-name)
                (project (project-current))
                (root (project-root project)))
          (file-relative-name file root)
        (buffer-name))))

(defun my/header-line--nerd-icons-p ()
  "Return non-nil when Nerd Icons are enabled and available."
  (and (bound-and-true-p ek-use-nerd-fonts)
       (require 'nerd-icons nil t)))

(defun my/header-line--icon (name face &optional fallback)
  "Render Nerd icon NAME with FACE, or FALLBACK when unavailable."
  (if (my/header-line--nerd-icons-p)
      (propertize (nerd-icons-mdicon name) 'face face)
    (propertize (or fallback "") 'face face)))

(defun my/header-line-buffer-icon ()
  "Nerd icon for the current buffer, or nil."
  (when (my/header-line--nerd-icons-p)
    (or (and buffer-file-name
             (ignore-errors
               (nerd-icons-icon-for-file
                buffer-file-name :face 'my/header-line-buffer-icon-face)))
        (ignore-errors
          (nerd-icons-icon-for-mode
           major-mode :face 'my/header-line-buffer-icon-face)))))

(defconst my/header-line--evil-states
  '((normal  "N" my/header-line-evil-normal)
    (insert  "I" my/header-line-evil-insert)
    (visual  "V" my/header-line-evil-visual)
    (replace "R" my/header-line-evil-replace)
    (motion  "M" my/header-line-evil-motion)
    (emacs   "E" my/header-line-evil-emacs))
  "Display labels and theme-derived faces for Evil states.")

(defun my/header-line-evil-state ()
  "Compact, theme-aware indicator for the current Evil state."
  (when (bound-and-true-p evil-state)
    (let* ((entry (assq evil-state my/header-line--evil-states))
           (tag (or (nth 1 entry)
                    (upcase (substring (symbol-name evil-state) 0 1))))
           (face (or (nth 2 entry) 'my/header-line-evil-normal)))
      (propertize (format " %s " tag) 'face face))))

(defun my/header-line-buffer-state ()
  "Render a clean lock, edit, or saved indicator for the current buffer."
  (cond
   (buffer-read-only
    (my/header-line--icon "nf-md-lock"
                        'my/header-line-state-read-only-face "RO"))
   ((buffer-modified-p)
    (my/header-line--icon "nf-md-pencil"
                        'my/header-line-state-modified-face "*"))
   (t
    (my/header-line--icon "nf-md-check"
                        'my/header-line-state-saved-face "="))))

(defun my/header-line-remote ()
  "Show a remote indicator only for an actual remote directory.
Unlike the built-in `mode-line-remote', local buffers render nothing instead
of a literal dash."
  (when (file-remote-p default-directory)
    (my/header-line--icon "nf-md-cloud_outline"
                        'font-lock-constant-face "@")))

(defun my/header-line-irc ()
  "IRC activity indicator: icon plus number of buffers with unread activity."
  (when (bound-and-true-p erc-modified-channels-alist)
    (let ((icon (my/header-line--icon "nf-md-forum_outline"
                                    'my/header-line-irc-face "irc")))
      (propertize (format "%s %d" icon
                          (length erc-modified-channels-alist))
                  'face 'my/header-line-irc-face))))

(defun my/header-line-clatter ()
  "Clatter indicator showing the number of joined channels."
  (when (featurep 'clatter)
    (let ((count 0))
      (dolist (buffer (clatter-all-buffers))
        (when (with-current-buffer buffer
                (and (eq clatter--buffer-type 'channel)
                     (hash-table-p clatter--nick-list)
                     (when-let* ((connection
                                  (clatter-get-connection clatter--network))
                                 ((eq (clatter-connection-state connection)
                                      :connected))
                                 (nick (clatter-connection-nick connection)))
                       (not (eq (gethash (downcase nick) clatter--nick-list
                                         my/header-line--missing)
                                my/header-line--missing)))))
          (setq count (1+ count))))
      (when (> count 0)
        (let ((icon (my/header-line--icon "nf-md-forum_outline"
                                        'my/header-line-clatter-face "irc")))
          (propertize (format "%s %d" icon count)
                      'face 'my/header-line-clatter-face))))))

(defun my/header-line-mu4e-formatter (mail-count)
  "Format MAIL-COUNT for the custom header line without an extra icon."
  (unless (zerop mail-count)
    (number-to-string mail-count)))

(defun my/header-line-mu4e ()
  "Unread mail indicator from mu4e-alert, or nil when mu4e is not in use."
  (when (bound-and-true-p mu4e-alert-mode-line)
    (let ((icon (my/header-line--icon "nf-md-email_outline"
                                    'my/header-line-mu4e-face "mail")))
      (propertize (format "%s %s" icon
                          (string-trim mu4e-alert-mode-line))
                  'face 'my/header-line-mu4e-face))))

(defvar my/header-line--clock-icons
  ["nf-md-clock_time_twelve" "nf-md-clock_time_one" "nf-md-clock_time_two"
   "nf-md-clock_time_three" "nf-md-clock_time_four" "nf-md-clock_time_five"
   "nf-md-clock_time_six" "nf-md-clock_time_seven" "nf-md-clock_time_eight"
   "nf-md-clock_time_nine" "nf-md-clock_time_ten" "nf-md-clock_time_eleven"]
  "Nerd icon clock faces indexed by hour modulo 12.")

(defun my/header-line-time ()
  "Time with a live clock icon showing the current hour."
  (when (bound-and-true-p display-time-string)
    (let* ((hour (% (string-to-number (format-time-string "%I")) 12))
           (icon (and (my/header-line--nerd-icons-p)
                      (nerd-icons-mdicon (aref my/header-line--clock-icons hour))))
           (time (string-trim display-time-string)))
      (propertize (if icon (concat icon " " time) time)
                  'face 'my/header-line-time-face))))

(defun my/header-line-sync-theme (&optional _theme)
  "Make helper padding inherit the live header-line theme face.
Optional THEME is ignored so this function also fits
`enable-theme-functions'."
  (set-face-attribute 'mode-line-maker-padding-face nil
                      :inherit 'header-line
                      :foreground 'unspecified
                      :background 'unspecified
                      :box nil
                      :overline nil
                      :underline nil
                      :inverse-video nil
                      :strike-through nil))

(define-minor-mode my/global-header-line-mode
  "Show the custom header line globally.

When disabled, local informational headers, such as Elfeed's column
headings, remain visible."
  :global t
  :init-value t
  :group 'mode-line
  (setq-default header-line-format
                (and my/global-header-line-mode my/header-line--format))
  (force-mode-line-update t))

(defun my/toggle-header-line ()
  "Toggle the custom header line globally."
  (interactive)
  (my/global-header-line-mode (if my/global-header-line-mode -1 1)))

(defun my/header-line-install ()
  "Install the custom header line built with mode-line-maker."
  (setq global-mode-string (delq 'display-time-string global-mode-string))
  (my/header-line-sync-theme)
  (add-hook 'enable-theme-functions #'my/header-line-sync-theme)
  (setq my/header-line--format
        (mode-line-maker
         '((:eval (my/header-line-evil-state)) " "
           (:eval (my/header-line-buffer-state))
           (:eval (my/header-line-remote)) " "
           (:eval (my/header-line-buffer-icon)) " "
           (:eval (propertize (my/header-line-buffer-name)
                              'face 'mode-line-buffer-id
                              'mouse-face 'mode-line-highlight
                              'help-echo (concat (or buffer-file-truename (buffer-name))
                                                 "\nmouse-1: Previous buffer\nmouse-3: Next buffer")
                              'local-map mode-line-buffer-identification-keymap)) " "
           mode-line-position)
         '("" (:eval (my/header-line-irc)) " "
           (:eval (my/header-line-clatter)) " "
           (:eval (my/header-line-mu4e)) " "
           mode-line-process " "
           (:eval (my/header-line-time)) " "
           mode-name " ")))
  ;; The header line is visible on every startup, regardless of its previous
  ;; interactive state in a long-running session.
  (my/global-header-line-mode 1)
  (add-hook 'before-save-hook #'my/header-line--invalidate-title-cache))

(provide 'my-header-line)
;;; my-header-line.el ends here
