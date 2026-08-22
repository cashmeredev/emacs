;;; denote-capf.el --- completion-at-point for denote -*- lexical-binding: t; -*-

;;; Commentary:

;; `denote-capf' provides `completion-at-point' functions for Denote
;; note titles and keywords.  Enable it in Org buffers with:
;;
;;   (add-hook 'org-mode-hook #'denote-capf-setup)
;;
;; Or call `M-x denote-capf-setup' manually.  Use `M-x
;; denote-capf-teardown' to disable it in the current buffer, and
;; `M-x denote-capf-refresh' to rebuild the cache.

;;; Code:

(require 'denote)
(require 'subr-x)
(require 'seq)
(require 'thingatpt)

(declare-function org-in-src-block-p "org")
(defvar corfu-auto)

(defgroup denote-capf nil
  "Completion-at-point functions for Denote links and keywords."
  :group 'denote)

(defcustom denote-capf-min-prefix 3
  "Minimum length of the word at point before offering note completions."
  :type 'integer :group 'denote-capf)

(defcustom denote-capf-include-encrypted nil
  "When non-nil, include encrypted notes in the completion candidates."
  :type 'boolean :group 'denote-capf)
(defcustom denote-capf-directories nil
  "Directories whose org files get denote completion-at-point.
When nil, `denote-capf-setup' enables completion in every org
buffer.  When set, only files living under one of these
directories are touched, leaving every other org buffer alone."
  :type '(repeat directory) :group 'denote-capf)

(defvar denote-capf--titles nil)
(defvar denote-capf--title->id nil)
(defvar denote-capf--timer nil)

(defun denote-capf--build ()
  "Build the list of denote note titles and their identifier mapping."
  (let ((titles '())
        (table (make-hash-table :test 'equal)))
    (dolist (file (denote-directory-files nil nil t (unless denote-capf-include-encrypted "\\.\\(gpg\\|age\\)\\'")))
      (let ((id (denote-retrieve-filename-identifier file))
            (title (denote-retrieve-title-or-filename file 'org)))
        (when (and id title (not (string-empty-p title)))
          (unless (gethash title table) (push title titles))
          (puthash title id table))))
    (setq denote-capf--titles (nreverse titles)
          denote-capf--title->id table)))

(defun denote-capf--ensure ()
  "Build the completion cache if it is not already populated."
  (unless denote-capf--title->id (denote-capf--build)))

(defun denote-capf--schedule ()
  "Schedule a rebuild of the completion cache during idle time."
  (when (timerp denote-capf--timer) (cancel-timer denote-capf--timer))
  (setq denote-capf--timer (run-with-idle-timer 0.5 nil #'denote-capf--build)))

(defun denote-capf-refresh ()
  "Rebuild the denote completion cache.
When called interactively, show how many notes were cached."
  (interactive)
  (denote-capf--build)
  (when (called-interactively-p 'any)
    (message "Denote completion cache refreshed (%d notes)"
             (length denote-capf--titles))))

(defun denote-capf--invalidate ()
  "Clear the completion cache and schedule a rebuild."
  (setq denote-capf--title->id nil denote-capf--titles nil)
  (denote-capf--schedule))

(add-hook 'denote-after-new-note-hook #'denote-capf--invalidate)
(add-hook 'denote-after-rename-file-hook #'denote-capf--invalidate)

(defun denote-capf--in-link-p ()
  "Return non-nil when point is inside an Org link."
  (save-excursion
    (let ((pos (point)) (bol (line-beginning-position)) (depth 0))
      (goto-char bol)
      (while (< (point) pos)
        (cond ((looking-at "\\[\\[") (setq depth (1+ depth)) (forward-char 2))
              ((looking-at "\\]\\]") (when (> depth 0) (setq depth (1- depth))) (forward-char 2))
              (t (forward-char 1))))
      (> depth 0))))

(defun denote-capf--link-exit (str status)
  "Exit function for `denote-capf-link'.
Replace the completed title with a denote link when STATUS is one
of finished, exact or sole."
  (when (memq status '(finished exact sole))
    (when-let* ((id (gethash str denote-capf--title->id)))
      (delete-region (- (point) (length str)) (point))
      (insert (format "[[denote:%s][%s]]" id str)))))

(defun denote-capf-link ()
  "Completion-at-point function for denote note links."
  (when (and (derived-mode-p 'org-mode)
             (not (org-in-src-block-p))
             (not (save-excursion (beginning-of-line) (looking-at-p "[ \t]*#\\+")))
             (not (denote-capf--in-link-p)))
    (when-let* ((bounds (bounds-of-thing-at-point 'word)))
      (when (>= (- (cdr bounds) (car bounds)) denote-capf-min-prefix)
        (denote-capf--ensure)
        (list (car bounds) (cdr bounds) denote-capf--titles
              :exclusive 'no
              :company-kind (lambda (_) 'reference)
              :annotation-function (lambda (_) " ✦ note")
              :exit-function #'denote-capf--link-exit)))))

(defun denote-capf-keywords ()
  "Completion-at-point function for denote keywords on #+filetags lines."
  (when (and (derived-mode-p 'org-mode)
             (save-excursion (beginning-of-line)
                             (looking-at-p "[ \t]*#\\+filetags:")))
    (let ((end (point))
          (start (save-excursion (skip-chars-backward "A-Za-z0-9_-") (point))))
      (when (< start end)
        (list start end (denote-keywords)
              :exclusive 'no
              :company-kind (lambda (_) 'keyword)
              :annotation-function (lambda (_) " ✦ keyword"))))))

(defun denote-capf--enabled-here-p ()
  "Return non-nil when denote completion should run in this buffer.
Honors `denote-capf-directories'."
  (or (null denote-capf-directories)
      (and buffer-file-name
           (seq-some (lambda (dir) (file-in-directory-p buffer-file-name dir))
                     denote-capf-directories))))

(defun denote-capf--add-capfs ()
  "Add denote capfs to `completion-at-point-functions' locally.
Does nothing if they are already present."
  (unless (memq #'denote-capf-keywords completion-at-point-functions)
    (add-hook 'completion-at-point-functions #'denote-capf-keywords nil t))
  (unless (memq #'denote-capf-link completion-at-point-functions)
    (add-hook 'completion-at-point-functions #'denote-capf-link nil t)))

;;;###autoload
(defun denote-capf-setup ()
  "Set up denote completion-at-point in the current buffer.
When called interactively, print a status message.  The setup is
only performed when `denote-capf--enabled-here-p' returns non-nil."
  (interactive)
  (if (denote-capf--enabled-here-p)
      (progn
        (setq-local corfu-auto nil)
        (denote-capf--add-capfs)
        (unless denote-capf--title->id (denote-capf--schedule))
        (when (called-interactively-p 'any)
          (message "Denote completion-at-point enabled in this buffer")))
    (when (called-interactively-p 'any)
      (message "Denote completion-at-point is not enabled here"))))

;;;###autoload
(defun denote-capf-teardown ()
  "Remove denote completion-at-point from the current buffer.
When called interactively, print a status message."
  (interactive)
  (remove-hook 'completion-at-point-functions #'denote-capf-keywords t)
  (remove-hook 'completion-at-point-functions #'denote-capf-link t)
  (when (called-interactively-p 'any)
    (message "Denote completion-at-point disabled in this buffer")))

(provide 'denote-capf)
;;; denote-capf.el ends here
