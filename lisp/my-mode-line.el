;;; my-mode-line.el --- Custom mode-line on top of mode-line-maker -*- lexical-binding: t; -*-

(require 'mode-line-maker)

(defface my/mode-line-evil-normal
  '((t (:inherit font-lock-keyword-face :weight bold)))
  "Face for the evil normal state indicator.")

(defface my/mode-line-evil-insert
  '((t (:inherit success :weight bold)))
  "Face for the evil insert state indicator.")

(defface my/mode-line-evil-visual
  '((t (:inherit warning :weight bold)))
  "Face for the evil visual state indicator.")

(defface my/mode-line-evil-replace
  '((t (:inherit error :weight bold)))
  "Face for the evil replace state indicator.")

(defface my/mode-line-evil-motion
  '((t (:inherit font-lock-constant-face :weight bold)))
  "Face for the evil motion state indicator.")

(defface my/mode-line-evil-emacs
  '((t (:inherit font-lock-builtin-face :weight bold)))
  "Face for the evil Emacs state indicator.")

(defface my/mode-line-buffer-icon-face
  '((t (:inherit mode-line-buffer-id)))
  "Face for the current buffer's file or mode icon.")

(defface my/mode-line-irc-face
  '((t (:inherit font-lock-builtin-face :weight bold)))
  "Face for the IRC activity indicator.")

(defface my/mode-line-mu4e-face
  '((t (:inherit warning :weight bold)))
  "Face for the unread mail indicator.")

(defface my/mode-line-time-face
  '((t (:inherit font-lock-constant-face)))
  "Face for the time segment.")

(defface my/mode-line-state-saved-face
  '((t (:inherit success)))
  "Face for the saved buffer state icon.")

(defface my/mode-line-state-modified-face
  '((t (:inherit warning :weight bold)))
  "Face for the modified buffer state icon.")

(defface my/mode-line-state-read-only-face
  '((t (:inherit error)))
  "Face for the read-only buffer state icon.")

(defvar-local my/mode-line--buffer-title nil)

(defun my/mode-line--update-title-cache ()
  "Update the cached #+title for the current buffer."
  (setq-local my/mode-line--buffer-title
              (and (derived-mode-p 'org-mode)
                   (cadar (org-collect-keywords '("TITLE"))))))

(defun my/mode-line--buffer-title ()
  "Return the cached #+title, computing it if necessary."
  (unless (local-variable-p 'my/mode-line--buffer-title)
    (my/mode-line--update-title-cache))
  my/mode-line--buffer-title)

(defun my/mode-line--invalidate-title-cache ()
  "Invalidate the cached title so it gets recomputed on next update."
  (kill-local-variable 'my/mode-line--buffer-title))

(defun my/mode-line-buffer-name ()
  "Buffer name for the mode line.
Uses the Org #+title if present, otherwise the file path relative to
the project root, falling back to the plain buffer name."
  (or (my/mode-line--buffer-title)
      (if-let* ((file buffer-file-name)
                (project (project-current))
                (root (project-root project)))
          (file-relative-name file root)
        (buffer-name))))

(defun my/mode-line--nerd-icons-p ()
  "Return non-nil when Nerd Icons are enabled and available."
  (and (bound-and-true-p ek-use-nerd-fonts)
       (require 'nerd-icons nil t)))

(defun my/mode-line--icon (name face &optional fallback)
  "Render Nerd icon NAME with FACE, or FALLBACK when unavailable."
  (if (my/mode-line--nerd-icons-p)
      (propertize (nerd-icons-mdicon name) 'face face)
    (propertize (or fallback "") 'face face)))

(defun my/mode-line-buffer-icon ()
  "Nerd icon for the current buffer, or nil."
  (when (my/mode-line--nerd-icons-p)
    (or (and buffer-file-name
             (ignore-errors
               (nerd-icons-icon-for-file
                buffer-file-name :face 'my/mode-line-buffer-icon-face)))
        (ignore-errors
          (nerd-icons-icon-for-mode
           major-mode :face 'my/mode-line-buffer-icon-face)))))

(defconst my/mode-line--evil-states
  '((normal  "N" my/mode-line-evil-normal)
    (insert  "I" my/mode-line-evil-insert)
    (visual  "V" my/mode-line-evil-visual)
    (replace "R" my/mode-line-evil-replace)
    (motion  "M" my/mode-line-evil-motion)
    (emacs   "E" my/mode-line-evil-emacs))
  "Display labels and theme-derived faces for Evil states.")

(defun my/mode-line-evil-state ()
  "Compact, theme-aware indicator for the current Evil state."
  (when (bound-and-true-p evil-state)
    (let* ((entry (assq evil-state my/mode-line--evil-states))
           (tag (or (nth 1 entry)
                    (upcase (substring (symbol-name evil-state) 0 1))))
           (face (or (nth 2 entry) 'my/mode-line-evil-normal)))
      (propertize (format " %s " tag) 'face face))))

(defun my/mode-line-buffer-state ()
  "Render a clean lock, edit, or saved indicator for the current buffer."
  (cond
   (buffer-read-only
    (my/mode-line--icon "nf-md-lock"
                        'my/mode-line-state-read-only-face "RO"))
   ((buffer-modified-p)
    (my/mode-line--icon "nf-md-pencil"
                        'my/mode-line-state-modified-face "*"))
   (t
    (my/mode-line--icon "nf-md-check"
                        'my/mode-line-state-saved-face "="))))

(defun my/mode-line-remote ()
  "Show a remote indicator only for an actual remote directory.
Unlike the built-in `mode-line-remote', local buffers render nothing instead
of a literal dash."
  (when (file-remote-p default-directory)
    (my/mode-line--icon "nf-md-cloud_outline"
                        'font-lock-constant-face "@")))

(defun my/mode-line-irc ()
  "IRC activity indicator: icon plus number of buffers with unread activity."
  (when (bound-and-true-p erc-modified-channels-alist)
    (let ((icon (my/mode-line--icon "nf-md-forum_outline"
                                    'my/mode-line-irc-face "irc")))
      (propertize (format "%s %d" icon
                          (length erc-modified-channels-alist))
                  'face 'my/mode-line-irc-face))))

(defun my/mode-line-mu4e ()
  "Unread mail indicator from mu4e-alert, or nil when mu4e is not in use."
  (when (bound-and-true-p mu4e-alert-mode-line)
    (let ((icon (my/mode-line--icon "nf-md-email_outline"
                                    'my/mode-line-mu4e-face "mail")))
      (propertize (format "%s %s" icon
                          (string-trim mu4e-alert-mode-line))
                  'face 'my/mode-line-mu4e-face))))

(defvar my/mode-line--clock-icons
  ["nf-md-clock_time_twelve" "nf-md-clock_time_one" "nf-md-clock_time_two"
   "nf-md-clock_time_three" "nf-md-clock_time_four" "nf-md-clock_time_five"
   "nf-md-clock_time_six" "nf-md-clock_time_seven" "nf-md-clock_time_eight"
   "nf-md-clock_time_nine" "nf-md-clock_time_ten" "nf-md-clock_time_eleven"]
  "Nerd icon clock faces indexed by hour modulo 12.")

(defun my/mode-line-time ()
  "Time with a live clock icon showing the current hour."
  (when (bound-and-true-p display-time-string)
    (let* ((hour (% (string-to-number (format-time-string "%I")) 12))
           (icon (and (my/mode-line--nerd-icons-p)
                      (nerd-icons-mdicon (aref my/mode-line--clock-icons hour))))
           (time (string-trim display-time-string)))
      (propertize (if icon (concat icon " " time) time)
                  'face 'my/mode-line-time-face))))

(defun my/mode-line-sync-theme (&optional _theme)
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

(defun my/mode-line-install ()
  "Install the custom mode-line built with mode-line-maker.
The mode-line lives at the top of the window via `header-line-format';
the bottom mode-line is hidden."
  (setq global-mode-string (delq 'display-time-string global-mode-string))
  (my/mode-line-sync-theme)
  (add-hook 'enable-theme-functions #'my/mode-line-sync-theme)
  (setq-default mode-line-format nil)
  (setq-default header-line-format
                (mode-line-maker
                 '((:eval (my/mode-line-evil-state)) " "
                   (:eval (my/mode-line-buffer-state))
                   (:eval (my/mode-line-remote)) " "
                   (:eval (my/mode-line-buffer-icon)) " "
                   (:eval (propertize (my/mode-line-buffer-name)
                                      'face 'mode-line-buffer-id
                                      'mouse-face 'mode-line-highlight
                                      'help-echo (concat (or buffer-file-truename (buffer-name))
                                                         "\nmouse-1: Previous buffer\nmouse-3: Next buffer")
                                      'local-map mode-line-buffer-identification-keymap)) " "
                   mode-line-position)
                 '("" (:eval (my/mode-line-irc)) " "
                   (:eval (my/mode-line-mu4e)) " "
                   mode-line-process " "
                   (:eval (my/mode-line-time)) " "
                   mode-name " ")))
  (add-hook 'before-save-hook #'my/mode-line--invalidate-title-cache))

(provide 'my-mode-line)
;;; my-mode-line.el ends here
