;; -*- lexical-binding: t; -*-

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

(straight-use-package '(project :type built-in))
(straight-use-package '(xref :type built-in))
(straight-use-package '(eglot :type built-in))
(straight-use-package '(flymake :type built-in))
(straight-use-package '(jsonrpc :type built-in))
(straight-use-package '(eldoc :type built-in))
(straight-use-package '(external-completion :type built-in))
(straight-use-package '(seq :type built-in))
(straight-use-package 'use-package)

(setq straight-use-package-by-default t)

(straight-use-package 'org)

(org-babel-load-file (expand-file-name "config.org" user-emacs-directory))
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("d43860349c9f7a5b96a090ecf5f698ff23a8eb49cd1e5c8a83bb2068f24ea563"
	 default))
 '(zoom-size '(0.382 . 0.618)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(org-document-title ((t (:height 1.6))))
 '(outline-1 ((t (:height 1.25))))
 '(outline-2 ((t (:height 1.2))))
 '(outline-3 ((t (:height 1.2))))
 '(outline-4 ((t (:height 1.2))))
 '(outline-5 ((t (:height 1.2))))
 '(outline-6 ((t (:height 1.2))))
 '(outline-7 ((t (:height 1.2))))
 '(outline-8 ((t (:height 1.2))))
 '(outline-9 ((t (:height 1.2)))))
