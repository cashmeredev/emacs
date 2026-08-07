;;; -*- lexical-binding: t -*-
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("d43860349c9f7a5b96a090ecf5f698ff23a8eb49cd1e5c8a83bb2068f24ea563"
     default))
 '(helm-minibuffer-history-key "M-p")
 '(package-selected-packages
   '(adaptive-wrap async corfu-terminal cursory edit-indirect flycheck
                   gptel marginalia markdown-mode mu4e nov
                   nushell-ts-mode offlineimap org-modern pdf-tools
                   ultra-scroll))
 '(safe-local-variable-values
   '((eval let ((host (car (split-string (system-name) "\\."))))
           (setq-local eglot-workspace-configuration
                       `(:nixd
                         (:nixpkgs
                          (:expr
                           ,(format
                             "(import ./.).nixosConfigurations.%s.pkgs"
                             host))
                          :formatting (:command ["nixfmt"]) :options
                          (:nixos
                           (:expr
                            ,(format
                              "(import ./.).nixosConfigurations.%s.options"
                              host))
                           :home-manager
                           (:expr
                            ,(format
                              "(import ./.).nixosConfigurations.%s.options.home-manager.users.type.getSubOptions []"
                              host)))))))
     (eglot-server-programs
      ((python-ts-mode python-mode) "rass" "--" "ty" "server" "--"
       "ruff" "server"))
     (eglot-server-programs (nix-mode "devenv" "lsp"))
     (magit-todos-mode)
     (eval progn
           (add-to-list 'auto-mode-alist '("\\.html\\'" . jinja2-mode))
           (add-to-list 'auto-mode-alist '("\\.j2\\'" . jinja2-mode)))))
 '(sync-ui-repos
   '(("~/org" . auto) ("~/.claude/skills" . auto) ("~/pass" . auto)
     ("~/nix" . ask) ("~/.emacs.d" . auto) ("~/garden/" . ask)))
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
