;;; garden-preview.el --- side-window note preview -*- lexical-binding: t; -*-

;;; Commentary:

;; Shows garden notes in a read-only side window on the right.  Two
;; entry points: `garden-preview-show' for one-off peeks (wired to
;; per-row eye buttons), and `garden-preview-mode', a buffer-local
;; minor mode for the VUI dashboards that previews the note under
;; point as you move around.  Buffers opened purely for previewing
;; are killed again by `garden-preview-quit'.

;;; Code:

(require 'garden-core)
(require 'cl-lib)

(declare-function vui-element-at "vui")
(declare-function vui-element-get "vui")

(defcustom garden-preview-width 45
  "Width of the preview side window in columns."
  :type 'integer :group 'garden)

(defvar garden-preview--opened nil
  "Buffers the preview opened itself and may kill on quit.")

(defvar-local garden-preview--owned nil
  "Non-nil when this buffer was created by `garden-preview-show'.")

(defvar garden-preview--last nil
  "File shown in the preview window most recently.")

(defun garden-preview-show (file)
  "Display FILE read-only in a side window on the right.
Focus returns to the window that was selected before the call."
  (interactive "fPreview note: ")
  (let* ((existing (find-buffer-visiting file))
         (buf (or existing (find-file-noselect file)))
         (origin (selected-window)))
    (if existing
        (progn
          (with-current-buffer buf (setq garden-preview--owned nil))
          (setq garden-preview--opened (delq buf garden-preview--opened)))
      (with-current-buffer buf
        (setq garden-preview--owned t)
        (cl-pushnew buf garden-preview--opened)))
    (setq garden-preview--last file)
    (with-current-buffer buf (setq buffer-read-only t))
    (or (with-selected-window (window-main-window)
          (display-buffer-in-side-window
           buf
           `((side . right) (slot . 0) (window-width . ,garden-preview-width)
             (window-parameters . ((no-delete-other-windows . t))))))
        (display-buffer buf '((display-buffer-reuse-window display-buffer-use-some-window)
                              (inhibit-same-window . t))))
    (select-window origin)))

(defun garden-preview-quit ()
  "Close the preview window and kill buffers opened for previewing.
Only buffers that the preview itself created are killed."
  (interactive)
  (when-let* ((buf (and garden-preview--last (find-buffer-visiting garden-preview--last)))
              (win (get-buffer-window buf)))
    (when (window-parameter win 'window-side)
      (delete-window win)))
  (dolist (buf garden-preview--opened)
    (when (and (buffer-live-p buf)
               (buffer-local-value 'garden-preview--owned buf)
               (not (buffer-modified-p buf))
               (not (get-buffer-window buf 'visible)))
      (kill-buffer buf)))
  (setq garden-preview--opened nil
        garden-preview--last nil))

(defun garden-preview--file-at-line ()
  "Return the note file referenced by a VUI element on the current line, if any.
Works with both `button.el' text buttons (vui 1.3+) and widget fields."
  (save-excursion
    (let ((end (line-end-position))
          (file nil))
      (beginning-of-line)
      (while (and (not file) (< (point) end))
        (let* ((elt (vui-element-at (point)))
               (echo (and elt (vui-element-get elt 'help-echo))))
          (when (and (stringp echo)
                     (string-suffix-p ".org" echo)
                     (file-exists-p echo))
            (setq file echo)))
        (forward-char 1))
      file)))

(defun garden-preview--post-command ()
  "Preview the note under point when it changed."
  (when-let* ((file (garden-preview--file-at-line)))
    (unless (equal file garden-preview--last)
      (garden-preview-show file))))

;;;###autoload
(define-minor-mode garden-preview-mode
  "Preview the note under point in a right side window.
Buffer-local; meant for the garden VUI dashboards."
  :lighter " peek"
  (if garden-preview-mode
      (progn
        (add-hook 'post-command-hook #'garden-preview--post-command nil t)
        (garden-preview--post-command))
    (remove-hook 'post-command-hook #'garden-preview--post-command t)
    (garden-preview-quit)))

(provide 'garden-preview)
;;; garden-preview.el ends here
