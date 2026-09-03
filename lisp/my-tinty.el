;;; my-tinty.el --- Follow Tinty changes in this Emacs -*- lexical-binding: t; -*-

(require 'filenotify)

(defgroup my/tinty nil
  "Automatic Tinty theme updates."
  :group 'faces)

(defcustom my/tinty-theme-file
  (expand-file-name "themes/tinty-theme.el" user-emacs-directory)
  "Shared theme source to watch in every Emacs process."
  :type 'file
  :group 'my/tinty)

(defcustom my/tinty-reload-delay 0.15
  "Seconds to combine filesystem events before loading the theme."
  :type 'number
  :group 'my/tinty)

(defvar my/tinty-auto-reload-mode nil)
(defvar my/tinty--watch nil)
(defvar my/tinty--timer nil)
(defvar my/tinty--loaded-content nil)

(defun my/tinty--reload ()
  "Reload only changed theme content, without success messages."
  (setq my/tinty--timer nil)
  (when (and my/tinty-auto-reload-mode (file-readable-p my/tinty-theme-file))
    (condition-case err
        (let* ((content (with-temp-buffer
                          (insert-file-contents-literally my/tinty-theme-file)
                          (secure-hash 'sha256 (current-buffer))))
               (inhibit-message t)
               (message-log-max nil))
          (unless (equal content my/tinty--loaded-content)
            (load my/tinty-theme-file nil 'nomessage 'nosuffix)
            (enable-theme 'tinty)
            (setq my/tinty--loaded-content content)))
      (error
       (let ((inhibit-message t))
         (message "Tinty theme: %s" (error-message-string err)))))))

(defun my/tinty--watch-start ()
  "Watch the theme directory, retrying if it is temporarily unavailable."
  (setq my/tinty--timer nil)
  (when my/tinty-auto-reload-mode
    (condition-case nil
        (unless (and my/tinty--watch (file-notify-valid-p my/tinty--watch))
          (setq my/tinty--watch
                (file-notify-add-watch
                 (file-name-directory (expand-file-name my/tinty-theme-file))
                 '(change attribute-change) #'my/tinty--changed))
          (my/tinty--reload))
      (file-notify-error
       (setq my/tinty--timer (run-at-time 2 nil #'my/tinty--watch-start))))))

(defun my/tinty--changed (event)
  "React only to events for the theme file or a stopped directory watch."
  (when (and my/tinty-auto-reload-mode (equal (car event) my/tinty--watch))
    (cond
     ((eq (cadr event) 'stopped)
      (setq my/tinty--watch nil)
      (when (timerp my/tinty--timer) (cancel-timer my/tinty--timer))
      (setq my/tinty--timer (run-at-time 2 nil #'my/tinty--watch-start)))
     ((member (expand-file-name my/tinty-theme-file) (cddr event))
      (when (timerp my/tinty--timer) (cancel-timer my/tinty--timer))
      (setq my/tinty--timer
            (run-at-time my/tinty-reload-delay nil #'my/tinty--reload))))))

;;;###autoload
(define-minor-mode my/tinty-auto-reload-mode
  "Keep this Emacs's theme synchronized with Tinty, independently of config reloads."
  :global t
  :group 'my/tinty
  (if my/tinty-auto-reload-mode
      (unless (and my/tinty--watch (file-notify-valid-p my/tinty--watch))
        (when (timerp my/tinty--timer) (cancel-timer my/tinty--timer))
        (my/tinty--watch-start))
    (when (timerp my/tinty--timer) (cancel-timer my/tinty--timer))
    (let ((watch my/tinty--watch))
      (setq my/tinty--timer nil my/tinty--watch nil my/tinty--loaded-content nil)
      (when watch (file-notify-rm-watch watch)))))

(provide 'my-tinty)
;;; my-tinty.el ends here
