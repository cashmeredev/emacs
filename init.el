;; -*- lexical-binding: t; -*-

;; Bootstrap straight.el (bestehender Code beibehalten)
(setq straight-check-for-modifications nil)
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name
        "straight/repos/straight.el/bootstrap.el"
        (or (bound-and-true-p straight-base-dir)
            user-emacs-directory)))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; Configure straight.el
(straight-use-package '(project :type built-in))
(straight-use-package '(xref :type built-in))
(straight-use-package 'use-package)

(setq straight-use-package-by-default t)

;; WICHTIG: Org vor org-babel-load-file laden
(straight-use-package 'org)

;; Jetzt kann die literate config sicher geladen werden
(org-babel-load-file (expand-file-name "config.org" user-emacs-directory))
