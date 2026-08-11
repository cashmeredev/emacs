;;; my-mode-line.el --- Custom mode-line on top of mode-line-maker -*- lexical-binding: t; -*-

(require 'mode-line-maker)

(defface my/mode-line-helix-normal
  '((t (:background "#89b4fa" :foreground "#1e1e2e" :weight bold)))
  "Face for the helix normal state indicator.")

(defface my/mode-line-helix-insert
  '((t (:background "#a6e3a1" :foreground "#1e1e2e" :weight bold)))
  "Face for the helix insert state indicator.")

(defface my/mode-line-irc-face
  '((t (:foreground "#94e2d5" :weight bold)))
  "Face for the IRC activity indicator.")

(defface my/mode-line-mu4e-face
  '((t (:foreground "#f9e2af" :weight bold)))
  "Face for the unread mail indicator.")

(defface my/mode-line-time-face
  '((t (:foreground "#89dceb")))
  "Face for the time segment.")

(defface my/mode-line-state-saved-face
  '((t (:foreground "#a6e3a1")))
  "Face for the saved buffer state icon.")

(defface my/mode-line-state-modified-face
  '((t (:foreground "#fab387" :weight bold)))
  "Face for the modified buffer state icon.")

(defface my/mode-line-state-read-only-face
  '((t (:foreground "#f38ba8")))
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
  (and (bound-and-true-p ek-use-nerd-fonts)
       (require 'nerd-icons nil t)))

(defun my/mode-line-buffer-icon ()
  "Nerd icon for the current buffer, or nil."
  (when (my/mode-line--nerd-icons-p)
    (or (and buffer-file-name
             (ignore-errors (nerd-icons-icon-for-file buffer-file-name)))
        (ignore-errors (nerd-icons-icon-for-mode major-mode)))))

(defun my/mode-line-helix-state ()
  "Colored single-letter indicator for the current helix state."
  (when (and (boundp 'helix--current-state) helix--current-state)
    (let* ((tag (upcase (substring (symbol-name helix--current-state) 0 1)))
           (face (intern-soft (format "my/mode-line-helix-%s" helix--current-state))))
      (propertize (format " %s " tag) 'face (or face 'my/mode-line-helix-normal)))))

(defun my/mode-line-buffer-state ()
  "Buffer state icon: lock (read-only), pencil-alert (modified), save (saved)."
  (cond
   (buffer-read-only
    (if (my/mode-line--nerd-icons-p)
        (propertize (nerd-icons-mdicon "nf-md-lock")
                    'face 'my/mode-line-state-read-only-face)
      "%%"))
   ((buffer-modified-p)
    (if (my/mode-line--nerd-icons-p)
        (propertize (nerd-icons-mdicon "nf-md-content_save_alert")
                    'face 'my/mode-line-state-modified-face)
      "**"))
   (t
    (if (my/mode-line--nerd-icons-p)
        (propertize (nerd-icons-mdicon "nf-md-content_save")
                    'face 'my/mode-line-state-saved-face)
      "--"))))

(defun my/mode-line-irc ()
  "IRC activity indicator: icon plus number of buffers with unread activity."
  (when (bound-and-true-p erc-modified-channels-alist)
    (let ((icon (and (my/mode-line--nerd-icons-p)
                     (nerd-icons-mdicon "nf-md-message_badge_outline"))))
      (propertize (format "%s %d" (or icon "irc")
                          (length erc-modified-channels-alist))
                  'face 'my/mode-line-irc-face))))

(defun my/mode-line-mu4e ()
  "Unread mail indicator from mu4e-alert, or nil when mu4e is not in use."
  (when (bound-and-true-p mu4e-alert-mode-line)
    (let ((icon (and (my/mode-line--nerd-icons-p)
                     (nerd-icons-mdicon "nf-md-email_alert_outline"))))
      (propertize (format "%s %s" (or icon "mail")
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

(defun my/mode-line-install ()
  "Install the custom mode-line built with mode-line-maker.
The mode-line lives at the top of the window via `header-line-format';
the bottom mode-line is hidden."
  (setq global-mode-string (delq 'display-time-string global-mode-string))
  (setq-default mode-line-format nil)
  (setq-default header-line-format
                (mode-line-maker
                 '((:eval (my/mode-line-helix-state)) " "
                   (:eval (my/mode-line-buffer-state)) mode-line-remote " "
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
