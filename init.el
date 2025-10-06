;; -*- lexical-binding: t; -*-

;; Bootstrap package management
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; Make sure org is available for loading the literate config
(unless (package-installed-p 'org)
  (package-refresh-contents)
  (package-install 'org))

;; Load the literate configuration from init.org
(org-babel-load-file (expand-file-name "config.org" user-emacs-directory))


(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("bbddadeeac41a4bfd89d5862c0bc452b8c9c5ff41ca9bbb8caabba87a3006a3b"
	 default)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
