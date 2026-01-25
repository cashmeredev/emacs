;;; config.el --- Emacs-Kick --- A feature rich Emacs config for (neo)vi(m)mers -*- lexical-binding: t; -*-
;; (setenv "LSP_USE_PLISTS" "true")
;; (setq debug-on-error '(wrong-type-argument))
;; (setq gc-cons-threshold #x40000000)
;; (setq gc-cons-threshold 50000000)
;; (setenv "LSP_USE_PLISTS" "true")
;; (setq lsp-use-plists t)
(setq pgtk-wait-for-event-timeout 0.001)
(setq package-enable-at-startup nil)
(setq-default mode-line-format t)
(setq default-frame-alist '((undecorated . t)))
(setq gc-cons-threshold 100000000)

(add-hook 'emacs-startup-hook
          (lambda () (setq gc-cons-threshold (* 50 1024 1024))))
(setq create-lockfiles nil)
(setq make-backup-files nil)

(setq backup-directory-alist
      `(("." . ,(expand-file-name "backup" user-emacs-directory))))
(setq tramp-backup-directory-alist backup-directory-alist)

(setq backup-by-copying-when-linked t)
(setq backup-by-copying             t) ; Backup by copying rather renaming
(setq delete-old-versions           t) ; Delete excess backup versions silently
(setq version-control               t) ; Use version numbers for backup files
(setq kept-new-versions             5)
(setq kept-old-versions             5)

(defvar yy/cache-2 nil)

(defun yy/load-cache ()
  (setq yy/cache-2
        (condition-case e
            (car (read-from-string
                  (with-temp-buffer
                    (insert-file-contents
                     (file-name-concat user-emacs-directory "ycache.eld"))
                    (buffer-substring (point-min) (point-max)))))
          (error nil))))
            ;;(make-hash-table :test #'equal))))
(yy/load-cache)

(defun yy/load-path-filter (path file suffixes)
  (if-let* ((ls (with-memoization (alist-get file yy/cache-2 nil nil #'equal)
                  (let ((res (load-path-filter-cache-directory-files path file suffixes)))
                    (if (eq res path) nil res)))))
      ls path))

(defun yy/write-cache ()
  (interactive)
  (when yy/cache-2
    (with-temp-file (file-name-concat user-emacs-directory "ycache.eld")
      (pp yy/cache-2 (current-buffer)))))

(yy/load-cache)

(setq load-path-filter-function #'yy/load-path-filter)

(use-package emacs
  :straight nil
  :ensure nil
  :custom ;; Set custom variables to configure Emacs behavior.
  (setq modify-coding-system-alist 'file "" 'utf-8)
  
  (column-number-mode t) ;; Display the column number in the mode line.
  (auto-save-default nil) ;; Disable automatic saving of buffers.
  (create-lockfiles nil) ;; Prevent the creation of lock files when editing.
  (delete-by-moving-to-trash t) ;; Move deleted files to the trash instead of permanently deleting them.
  (delete-selection-mode 1) ;; Enable replacing selected text with typed text.
  (display-line-numbers-type 'relative) ;; Use relative line numbering in programming modes.
  (global-auto-revert-non-file-buffers t) ;; Automatically refresh non-file buffers.
  (history-length 25) ;; Set the length of the command history.
  (inhibit-startup-message t) ;; Disable the startup message when Emacs launches.
  (initial-scratch-message "") ;; Clear the initial message in the *scratch* buffer.
  (ispell-dictionary "en_US") ;; Set the default dictionary for spell checking.
  (make-backup-files nil) ;; Disable creation of backup files.
  ;; (pixel-scroll-precision-mode t) ;; Enable precise pixel scrolling.
  (pixel-scroll-precision-use-momentum nil) ;; Disable momentum scrolling for pixel precision.
  (ring-bell-function 'ignore) ;; Disable the audible bell.
  (split-width-threshold 300) ;; Prevent automatic window splitting if the window width exceeds 300 pixels.
  (switch-to-buffer-obey-display-actions t) ;; Make buffer switching respect display actions.
  (tab-always-indent 'complete) ;; Make the TAB key complete text instead of just indenting.
  (tab-width 4) ;; Set the tab width to 4 spaces.
  (treesit-font-lock-level 4) ;; Use advanced font locking for Treesit mode.
  (truncate-lines t) ;; Enable line truncation to avoid wrapping long lines.
  (use-dialog-box nil) ;; Disable dialog boxes in favor of minibuffer prompts.
  (use-short-answers t) ;; Use short answers in prompts for quicker responses (y instead of yes)
  (warning-minimum-level :emergency) ;; Set the minimum level of warnings to display.

  :hook ;; Add hooks to enable specific features in certain modes.
  (prog-mode . display-line-numbers-mode)
  (org-mode . display-line-numbers-mode)

  :config
  (add-to-list 'custom-theme-load-path user-emacs-directory)
  
  (setq custom-safe-themes t)
  ;; By default emacs gives you access to a lot of *special* buffers, while navigating with [b and ]b,
  ;; this might be confusing for newcomers. This settings make sure ]b and [b will always load a
  ;; file buffer. To see all buffers use <leader> SPC, <leader> b l, or <leader> b i.
  (defun skip-these-buffers (_window buffer _bury-or-kill)
	"Function for `switch-to-prev-buffer-skip'."
	(string-match "\\*[^*]+\\*" (buffer-name buffer)))
  (setq switch-to-prev-buffer-skip 'skip-these-buffers)

  (setq switch-to-prev-buffer-skip-regexp
		'("\\*[^*]+\\*" "^magit" "^\\*magit"))

  ;; Configure font settings based on the operating system.
  ;; Ok, this kickstart is meant to be used on the terminal, not on GUI.
  ;; But without this, I fear you could start Graphical Emacs and be sad :(
  ;; (set-face-attribute 'default nil :family "Maple Mono NF" :height 150)
  ;; (when (eq system-type 'darwin) ;; Check if the system is macOS.
  ;; (setq mac-command-modifier 'meta) ;; Set the Command key to act as the Meta key.
  ;; (set-face-attribute 'default nil :family "Fragment Mono" :height 130))

  ;; Save manual customizations to a separate file instead of cluttering `init.el'.
  ;; You can M-x customize, M-x customize-group, or M-x customize-themes, etc.
  ;; The saves you do manually using the Emacs interface would overwrite this file.
  ;; The following makes sure those customizations are in a separate file.
  (setq custom-file (locate-user-emacs-file "custom-vars.el")) ;; Specify the custom file path.
  (load custom-file 'noerror 'nomessage) ;; Load the custom file quietly, ignoring errors.

  ;; Makes Emacs vertical divisor the symbol │ instead of |.
  (set-display-table-slot standard-display-table 'vertical-border (make-glyph-code ?│))

  :init ;; Initialization settings that apply before the package is loaded.
  (tool-bar-mode -1)

  (menu-bar-mode -1)
  (scroll-bar-mode -1)
  (add-to-list 'default-frame-alist '(vertical-scroll-bars . nil))
  (add-to-list 'default-frame-alist '(horizontal-scroll-bars . nil))
  (set-frame-parameter (selected-frame) 'alpha-background 80)
  (add-to-list 'default-frame-alist '(alpha-background . 80))
  (global-hl-line-mode -1) ;; Disable highlight of the current line
  (global-auto-revert-mode 1) ;; Enable global auto-revert mode to keep buffers up to date with their corresponding files.
  (indent-tabs-mode -1) ;; Disable the use of tabs for indentation (use spaces instead).
  (recentf-mode 1) ;; Enable tracking of recently opened files.
  (savehist-mode 1) ;; Enable saving of command history.
  (save-place-mode 1) ;; Enable saving the place in files for easier return.
  (winner-mode 1) ;; Enable winner mode to easily undo window configuration changes.
  (xterm-mouse-mode 1) ;; Enable mouse support in terminal mode.
  (file-name-shadow-mode 1) ;; Enable shadowing of filenames for clarity.

  ;;oding system for files to UTF-8.
  (modify-coding-system-alist 'file "" 'utf-8)

  ;; Add a hook to run code after Emacs has fully initialized.
  (add-hook 'after-init-hook
			(lambda ()
			  (message "Emacs has fully loaded. This code runs after startup.")

			  ;; Insert a welcome message in the *scratch* buffer displaying loading time and activated packages.
			  (with-current-buffer (get-buffer-create "*scratch*")
				(insert (format
						 " ;; Welcome to Emacs!
;;
;; Loading time : %s
;; Packages : %s
"
						 (emacs-init-time)
						 (length (hash-table-keys straight--recipe-cache))))))))


(defcustom ek-use-nerd-fonts t
  "Configuration for using Nerd Fonts Symbols."
  :type 'boolean
  :group 'appearance)

;; (setq wl-copy-process nil)
;; (defun wl-copy (text)
;;   (setq wl-copy-process (make-process :name "wl-copy"
;;                                       :buffer nil
;;                                       :command '("wl-copy" "-f" "-n")
;;                                       :connection-type 'pipe
;;                                       :noquery t))
;;   (process-send-string wl-copy-process text)
;;   (process-send-eof wl-copy-process))
;; (defun wl-paste ()
;;   (if (and wl-copy-process (process-live-p wl-copy-process))
;;       nil ; should return nil if we're the current paste owner
;;       (shell-command-to-string "wl-paste -n | tr -d \r")))
;; (setq interprogram-cut-function 'wl-copy)
;; (setq interprogram-paste-function 'wl-paste)

(use-package window
  :straight nil
  :ensure nil
  :custom
  (display-buffer-alist
   '(
     ("\\*\\(Backtrace\\|Warnings\\|Compile-Log\\|[Hh]elp\\|Messages\\|Bookmark List\\|Occur\\)\\*"
      (display-buffer-in-side-window)
      (window-height . 0.25)
      (side . bottom)
      (slot . 0))

	 ("\\*\\(eldoc\\)\\*"
	  (display-buffer-in-side-window)
	  (window-height . 0.25)
	  (side . bottom)
      (slot . 1)
      (window-parameters . ((no-delete-other-windows . t)))
      (body-function . (lambda (window)
                        (select-window window))))

	 ("\\*\\(Flymake diagnostics\\|xref\\|ivy\\|Swiper\\|Completions\\)"
	  (display-buffer-in-side-window)
	  (window-height . 0.25)
	  (side . bottom)
	  (slot . 1)))))

(use-package dired
  :straight nil
  :ensure nil
  :custom
  (dired-listing-switches "-lah --group-directories-first")
  (dired-dwim-target t)
  (dired-guess-shell-alist-user
   '(;; ("\\.\\(png\\|jpe?g\\|tiff\\)" "feh" "xdg-open" "open")
     ("\\.\\(mp[34]\\|m4a\\|ogg\\|flac\\|webm\\|mkv\\)" "mpv" "xdg-open" "open")
     (".*" "open" "xdg-open")))
  (dired-kill-when-opening-new-dired-buffer t)
  (dired-create-destination-dirs 'always)
  :config
  (setq dired-async-mode t)
  
  (require 'mailcap)
  
  (setq mailcap-prefer-mailcap-viewers nil)

  (mailcap-add "image/png" "kitty --hold kitty +kitten icat %s")
  (mailcap-add "image/jpeg" "kitty --hold kitty +kitten icat %s")
  (mailcap-add "image/jpg" "kitty --hold kitty +kitten icat %s")
  (mailcap-add "image/gif" "kitty --hold kitty +kitten icat %s")

  (define-key dired-mode-map (kbd "E") 
    (lambda () 
      (interactive) 
      (mailcap-view-file (dired-get-filename))))
      
  (when (eq system-type 'darwin)
    (let ((gls (executable-find "gls")))
      (when gls
        (setq insert-directory-program gls)))))

(use-package async :ensure t)

(use-package erc
  :straight nil
  :defer t ;; Load ERC when needed rather than at startup. (Load it with `M-x erc RET')
  :custom
  (erc-join-buffer 'window)                                        ;; Open a new window for joining channels.
  (erc-hide-list '("JOIN" "PART" "QUIT"))                          ;; Hide messages for joins, parts, and quits to reduce clutter.
  (erc-timestamp-format "[%H:%M]")                                 ;; Format for timestamps in messages.
  ;; (erc-autojoin-channels-alist '((".*\\.libera\\.chat" "#emacs")))
  );; Automatically join the #emacs channel on Libera.Chat.
(defun run-erc ()
  (interactive)
  (erc-tls :server "irc.cashmere.rs"
           :port 6697
           :nick "cashmere"
           :user "cashmere/libera.chat"
           :password (password-store-get 'soju)
		   :id 'libera))

;; (use-package lambda-themes
;;   :ensure t
;;   :straight (:type git :host github :repo "lambda-emacs/lambda-themes") 
;;   :custom
;;   (lambda-themes-set-italic-comments t)
;;   (lambda-themes-set-italic-keywords t)
;;   (lambda-themes-set-variable-pitch t) 
;;   (lambda-themes-set-theme 'light)
;;   :config
;;   (load-theme 'lambda-light))

(use-package dashboard
  :ensure t
  :config
  (setq dashboard-banner-logo-title "Jesus said 'i will rebuild this temple in 3 days.' I could make a compiler in 3 days.")
  (setq dashboard-startup-banner "/home/cashmere/.emacs.d/image.jpg")
  (setq dashboard-image-banner-max-width 256)
  (setq dashboard-image-banner-max-height 256)
  (setq dashboard-bookmarks-show-base t)
  (setq dashboard-bookmarks-item-format "%s")
  (setq dashboard-projects-backend 'projectile)
  (setq dashboard-items '((bookmarks . 5)
						  (projects . 5)
                          (recents . 5)))
  (setq dashboard-projects-switch-function
        (lambda (proj)
          (projectile-switch-project-by-name proj)))
  (setq dashboard-center-content t)
  (setq dashboard-set-file-icons t)
  (setq dashboard-set-heading-icons t)
  (setq dashboard-icon-type 'nerd-icons)
  (setq dashboard-footer-messages '("Emacs. The world greatest operating system"))
  (dashboard-setup-startup-hook)
  
  (setq initial-buffer-choice
        (lambda ()
          (get-buffer-create dashboard-buffer-name)))
  
  (add-hook 'dashboard-mode-hook
            (lambda ()
              (setq mode-line-format nil))))

(defvar my/centered-cursor-enabled nil)

(defun my/centered-cursor ()
  (interactive)
  (if my/centered-cursor-enabled
      (progn
        (setq scroll-preserve-screen-position nil
              scroll-conservatively 0
              maximum-scroll-margin 0.0
              scroll-margin 0)
        (setq my/centered-cursor-enabled nil)
        (message "centered-cursor off"))
    (progn
      (setq scroll-preserve-screen-position t
            scroll-conservatively 0
            maximum-scroll-margin 0.5
            scroll-margin 99999)
      (setq my/centered-cursor-enabled t)
      (message "centered-cursor on"))))

(use-package cursory
  :ensure t
  :demand t
  :if (display-graphic-p)
  :config
  (setq cursory-presets
        '((box
           :cursor-color success ; will typically be green
           :blink-cursor-interval 1.2)
          (box-no-blink
           :inherit box
           :blink-cursor-mode -1)
          (bar
           :cursor-type (bar . 2)
           :cursor-color error ; will typically be red
           :blink-cursor-interval 0.8)
          (bar-no-other-window
           :inherit bar
           :cursor-in-non-selected-windows nil)
          (bar-no-blink
           :inherit bar
           :blink-cursor-mode -1)
          (underscore
           :cursor-color warning ; will typically be yellow
           :cursor-type (hbar . 3)
           :blink-cursor-interval 0.3
           :blink-cursor-blinks 50)
          (underscore-no-other-window
           :inherit underscore
           :cursor-in-non-selected-windows nil)
          (underscore-thick
           :inherit underscore
           :cursor-type (hbar . 8)
           :cursor-in-non-selected-windows (hbar . 3))
          (t ; the default values
           :cursor-color unspecified ; use the theme's original
           :cursor-type box
           :cursor-in-non-selected-windows hollow
           :blink-cursor-mode 1
           :blink-cursor-blinks 10
           :blink-cursor-interval 0.2
           :blink-cursor-delay 0.2)))

  ;; I am using the default value of `cursory-latest-state-file'.

  ;; Set last preset or fall back to desired style from
  ;; `cursory-presets'.  Alternatively, use the function
  ;; `cursory-set-last-or-fallback' (can be added to the
  ;; `after-init-hook'.
  (cursory-set-preset (or (cursory-restore-latest-preset) 'box))

  ;; Persist configurations between Emacs sessions.  Also apply the
  ;; :cursor-color again when swithcing to another theme.
  (cursory-mode 1)
  :bind
  ;; We have to use the "point" mnemonic, because C-c c is often the
  ;; suggested binding for `org-capture' and is the one I use as well.
  ("C-c p" . cursory-set-preset))

(use-package clipetty
  :ensure t
  :hook (after-init . global-clipetty-mode))

(use-package isearch
  :straight nil
  :ensure nil                                  ;; This is built-in, no need to fetch it.
  :config
  (setq isearch-lazy-count t)                  ;; Enable lazy counting to show current match information.
  (setq lazy-count-prefix-format "(%s/%s) ")   ;; Format for displaying current match count.
  (setq lazy-count-suffix-format nil)          ;; Disable suffix formatting for match count.
  (setq search-whitespace-regexp ".*?")        ;; Allow searching across whitespace.
  :bind (("C-s" . isearch-forward)             ;; Bind C-s to forward isearch.
                 ("C-r" . isearch-backward)))          ;; Bind C-r to backward isearch.

(use-package vc
  :straight nil
  :ensure nil                        ;; This is built-in, no need to fetch it.
  :defer t
  :bind
  (("C-x v d" . vc-dir)              ;; Open VC directory for version control status.
   ("C-x v =" . vc-diff)             ;; Show differences for the current file.
   ("C-x v D" . vc-root-diff)        ;; Show differences for the entire repository.
   ("C-x v v" . vc-next-action))     ;; Perform the next version control action.
  :config
  ;; Better colors for <leader> g b  (blame file)
  (setq vc-annotate-color-map
        '((20 . "#f5e0dc")
          (40 . "#f2cdcd")
          (60 . "#f5c2e7")
          (80 . "#cba6f7")
          (100 . "#f38ba8")
          (120 . "#eba0ac")
          (140 . "#fab387")
          (160 . "#f9e2af")
          (180 . "#a6e3a1")
          (200 . "#94e2d5")
          (220 . "#89dceb")
          (240 . "#74c7ec")
          (260 . "#89b4fa")
          (280 . "#b4befe"))))

(use-package ibuffer
  :ensure nil
  :straight nil
  :config
  (setq ibuffer-expert t)
  (setq ibuffer-display-summary nil)
  (setq ibuffer-use-other-window nil)
  (setq ibuffer-show-empty-filter-groups nil)
  (setq ibuffer-default-sorting-mode 'filename/process)
  (setq ibuffer-title-face 'font-lock-doc-face)
  (setq ibuffer-use-header-line t)
  (setq ibuffer-default-shrink-to-minimum-size nil)
  (setq ibuffer-formats
        '((mark modified read-only locked " "
                (name 30 30 :left :elide)
                " "
                (size 9 -1 :right)
                " "
                (mode 16 16 :left :elide)
                " " filename-and-process)
          (mark " "
                (name 16 -1)
                " " filename)))
  (setq ibuffer-saved-filter-groups
        '(("Main"
           ("Directories" (mode . dired-mode))
           ("Rust" (or
                   (mode . rust-mode)
                   (mode . rust-ts-mode)))
           ("Python" (or
                      (mode . python-ts-mode)
                      (mode . c-mode)
                      (mode . python-mode)))
           ("Nix" (or
                     (mode . nix-mode)
                     (mode . nix-ts-mode)))
           ("Scripts" (or
                       (mode . shell-script-mode)
                       (mode . shell-mode)
                       (mode . sh-mode)
                       (mode . lua-mode)
                       (mode . bat-mode)))
           ("Config" (or
                      (mode . conf-mode)
                      (mode . conf-toml-mode)
                      (mode . toml-ts-mode)
                      (mode . conf-windows-mode)
                      (name . "^\\.clangd$")
                      (name . "^\\.gitignore$")
                      (name . "^Doxyfile$")
                      (name . "^config\\.toml$")
                      (mode . yaml-mode)))
           ("Web" (or
                   (mode . mhtml-mode)
                   (mode . html-mode)
                   (mode . web-mode)
                   (mode . nxml-mode)))
           ("CSS" (or
                   (mode . css-mode)
                   (mode . sass-mode)))
           ("JS" (or
                  (mode . js-mode)
                  (mode . rjsx-mode)))
           ("Markup" (or
                   (mode . markdown-mode)
                   (mode . adoc-mode)))
           ("Org" (mode . org-mode))
           ("Terminal" (mode . vterm-mode))
           ("LaTeX" (name . "\.tex$"))
           ("Magit" (or
                     (mode . magit-blame-mode)
                     (mode . magit-cherry-mode)
                     (mode . magit-diff-mode)
                     (mode . magit-log-mode)
                     (mode . magit-process-mode)
                     (mode . magit-status-mode)))
           ("Elfeed" (or
                    (mode . elfeed-search-mode)
                    (mode . elfeed-show-mode)))
           ("Fundamental" (or
                           (mode . fundamental-mode)
                           (mode . text-mode)))
           ("Emacs" (or
                     (mode . emacs-lisp-mode)
                     (name . "^\\*Help\\*$")
                     (name . "^\\*Custom.*")
                     (name . "^\\*Org Agenda\\*$")
                     (name . "^\\*info\\*$")
                     (name . "^\\*scratch\\*$")
                     (name . "^\\*Backtrace\\*$")
                     (name . "^\\*Messages\\*$"))))))
  :hook
  (ibuffer-mode . (lambda ()
                    (ibuffer-switch-to-saved-filter-groups "Main"))))

(use-package nerd-icons-ibuffer
  :ensure t
  :hook (ibuffer-mode . nerd-icons-ibuffer-mode))

(use-package smerge-mode
  :straight nil
  :ensure nil                                  ;; This is built-in, no need to fetch it.
  :defer t
  :bind (:map smerge-mode-map
                          ("C-c ^ u" . smerge-keep-upper)  ;; Keep the changes from the upper version.
                          ("C-c ^ l" . smerge-keep-lower)  ;; Keep the changes from the lower version.
                          ("C-c ^ n" . smerge-next)        ;; Move to the next conflict.
                          ("C-c ^ p" . smerge-previous)))  ;; Move to the previous conflict.

(use-package gptel
  :ensure t
  :config
  (defun my/openrouter-key ()
    (string-trim
     (shell-command-to-string "pass code/openrouter")))

  (setq my/openrouter-backend
        (gptel-make-openai
         "OpenRouter"
         :host "openrouter.ai"
         :endpoint "/api/v1/chat/completions"
         :stream t
         :key #'my/openrouter-key
         :models '("google/gemini-3-flash-preview:online"
				   "deepseek/deepseek-v3.2:online"
                   "minimax/minimax-m2.1:online"
				   )))

  (setq gptel-backend my/openrouter-backend)
  (setq gptel-log-level 'debug)
  (setq gptel-include-reasoning nil)
  (setq gptel-default-mode 'markdown-mode)
  (setq gptel-backends (list my/openrouter-backend)))

(use-package eldoc
  :straight nil
  :ensure t
  :config
  (setq eldoc-idle-delay 0)
  (setq eldoc-echo-area-use-multiline-p nil)
  (setq eldoc-echo-area-display-truncation-message nil)
  :init
  (global-eldoc-mode))

(use-package eldoc-box
  :ensure t
  :defer t
  :config
  (setq eldoc-box-max-pixel-width 800)
  (setq eldoc-box-max-pixel-height 600))

;; (use-package eldoc-box
;;   :ensure t
;;   :config
;;   ;; (setq eldoc-box-at-point-position-function #'eldoc-box--default-at-point-position-function)
;;   (setq eldoc-box-help-at-point-mode t))

(use-package flymake
  :straight nil
  :ensure nil          ;; This is built-in, no need to fetch it.
  :defer t
  ;; :hook (prog-mode . flymake-mode)
  :custom
  (flymake-margin-indicators-string
   '((error "!»" compilation-error) (warning "»" compilation-warning)
         (note "»" compilation-info))))

(setq trusted-content
      '("~/.emacs.d/config.el"
        "~/.emacs.d/init.el"))

(use-package flycheck
  :ensure t
  :config
  (add-hook 'after-init-hook #'global-flycheck-mode))

(use-package flycheck-rust
  :ensure t
  :config
  (setq flycheck-rust-check-tests nil)
  (add-hook 'flycheck-mode-hook #'flycheck-rust-setup))

(use-package flycheck-python-ruff
  :straight (:host github :repo "v4n6/flycheck-python-ruff")
  :ensure t
  :hook ((python-mode python-ts-mode) . flycheck-python-ruff-setup))

;; (use-package flyover
;;   :ensure t
;;   :hook (flycheck-mode-hook . flyover-mode))

(use-package flycheck-eglot
  :ensure t
  :after (flycheck eglot)
  :config
  (global-flycheck-eglot-mode 1))

(use-package xref
  :straight nil
  :ensure nil)

(use-package project
  :straight nil
  :ensure nil)

(setq org-directory "~/org/")
(use-package org
  :straight nil
  :ensure nil     
  :config
  (require 'org-tempo)

  (custom-set-faces
   '(org-document-title ((t (:height 1.6))))
   '(outline-1          ((t (:height 1.25))))
   '(outline-2          ((t (:height 1.2))))
   '(outline-3          ((t (:height 1.2))))
   '(outline-4          ((t (:height 1.2))))
   '(outline-5          ((t (:height 1.2))))
   '(outline-6          ((t (:height 1.2))))
   '(outline-7          ((t (:height 1.2))))
   '(outline-8          ((t (:height 1.2))))
   '(outline-9          ((t (:height 1.2)))))

  (setq org-startup-folded 'nil)
  (setq org-adapt-indentation t
		;; org-time-stamp-rounding-minutes '(5 5)	
		org-return-follows-link t
        org-hide-leading-stars t
        org-pretty-entities t
        org-startup-truncated t
        org-ellipsis "  ")
  (setq org-src-fontify-natively t
        org-src-tab-acts-natively t
        org-edit-src-content-indentation 0)
  (setq org-log-done                       t
        org-auto-align-tags                t
        org-tags-column                    -80
        org-fold-catch-invisible-edits     'show-and-error
        org-special-ctrl-a/e               t
        org-insert-heading-respect-content t)

  (add-hook 'org-mode-hook 'variable-pitch-mode)
  (add-hook 'org-mode-hook 'org-indent-mode)
  (add-hook 'org-mode-hook 'visual-line-mode)
  (add-hook 'org-mode-hook (lambda () (electric-indent-local-mode -1)))


  (add-to-list 'font-lock-extra-managed-props 'display)
  (font-lock-add-keywords 'org-mode
                          `(("^.*?\( \)\(:[[:alnum:]_@#%:]+:\)$"
                             (1 `(face nil
                                       display (space :align-to (- right ,(org-string-width (match-string 2)) 3)))
                                prepend))) t))

(defun my-org-read-date-always-with-time (orig-fun &optional org-with-time to-time from-string prompt default-time default-input inactive)
  (cl-letf (((symbol-function 'org-read-date--get-current-time)
             (lambda () (or default-time (current-time)))))
    (let* ((default-input (or default-input 
                              (format-time-string "%H:%M" (or default-time (current-time))))))
      (funcall orig-fun t to-time from-string prompt default-time default-input inactive))))

(advice-add 'org-read-date :around #'my-org-read-date-always-with-time)

(use-package org-appear
  :commands (org-appear-mode)
  :hook     (org-mode . org-appear-mode)
  :config
  (setq org-hide-emphasis-markers t)  ;; Must be activated for org-appear to work
  (setq org-appear-autoemphasis   t   ;; Show bold, italics, verbatim, etc.
        org-appear-autolinks      t   ;; Show links
        org-appear-autosubmarkers t)) ;; Show sub- and superscripts



(use-package org-modern
  :ensure t
  :config
  (setq org-modern-hide-stars t)
  (setq org-modern-star 'fold)
  (setq org-modern-fold-stars '(("◉" . "○")))
  (setq org-modern-star 'replace)
  (setq org-modern-replace-stars "◉○◉○◉")
  
  (setq org-modern-todo-faces
    '(("TODO" :background "#3a3a3a" :foreground "#e0e0e0" :weight normal)
      ("NEXT" :background "#ff9800" :foreground "#1a1a1a" :weight normal)
      ("ACTIVE" :background "#e91e63" :foreground "#ffffff" :weight bold)
      ("WAIT" :background "#2196f3" :foreground "#ffffff" :weight bold)
      ("DONE" :background "#4caf50" :foreground "#ffffff" :weight bold)
      ("CANCELLED" :background "#757575" :foreground "#e0e0e0" :weight normal))))

(with-eval-after-load 'org (global-org-modern-mode))

(use-package org-fancy-priorities
  :ensure t
  :hook
  (org-mode . org-fancy-priorities-mode)
  :config
  (setq org-fancy-priorities-list '("⚡" "⬆" "⬇" "☕")))

(setq org-priority-faces
  '((?A . (:background "#e91e63" :foreground "#ffffff" :weight bold))
    (?B . (:background "#ff9800" :foreground "#1a1a1a" :weight bold))
    (?C . (:background "#2196f3" :foreground "#ffffff" :weight bold))
    (?D . (:background "#795548" :foreground "#ffffff" :weight bold))))

;; (setq org-agenda-start-on-weekday nil
;;       org-agenda-block-separator  nil
;;       org-agenda-remove-tags      t)

;;   (setq org-agenda-skip-scheduled-if-done t
;;         org-agenda-skip-deadline-if-done t
;;         org-agenda-include-deadlines t
;;         org-agenda-block-separator nil
;;         org-agenda-compact-blocks t
;;         org-agenda-start-day nil
;;         org-agenda-span 1
;;         org-agenda-start-on-weekday nil
;;         org-agenda-hide-tags-regexp "task"
;;         org-agenda-prefix-format
;;         '((agenda . " %i %?-12t% s")
;;           (todo . " %i ")
;;           (tags . " %i ")
;;           (search . " %i ")))

(with-eval-after-load 'org
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t)
     (shell . t)
	 (python . t)
     (dot . t)
	 (C . t)
	 (makefile . t))))

(defun my/paste-md-to-org ()
  "Yank Markdown text as Org.

This command will convert Markdown text in the top of the `kill-ring'
and convert it to Org using the pandoc utility."
  (interactive)
  (save-excursion
    (with-temp-buffer
      (yank)
      (shell-command-on-region
       (point-min) (point-max)
       "pandoc -f markdown -t org --wrap=preserve" t t)
      (kill-region (point-min) (point-max)))
    (yank)))

(use-package org-noter
  :ensure t
  :defer t)

(use-package nov
  :ensure t
  :mode ("\\.epub\\'" . nov-mode))

(use-package org-generate
  :ensure t
  :defer t)

(use-package yequake
  :custom
  (yequake-frames
   '(("org-capture"
      (buffer-fns . (yequake-org-capture))
      (width . 0.75)
      (height . 0.5)
      (frame-parameters . ((name . "org-capture")
                           (undecorated . t)
                           (skip-taskbar . t)
                           (sticky . t))))
     ("emacs-everywhere"
      (buffer-fns . (emacs-everywhere))
      (width . 0.75)
      (height . 0.5)
      (frame-parameters . ((name . "emacs-everywhere")
                           (undecorated . t)
                           (skip-taskbar . t)
                           (sticky . t)))))))

(defun my/org-capture-denote-deadline ()
  (let* ((context (read-string "Task with deadline: "))
         (deadline (org-read-date t nil nil "Deadline: "))
         (file-name (denote nil '("task"))))
    (find-file file-name)
    (goto-char (point-min))
    (forward-line 4)
    (insert (format "\n* %s\nDEADLINE: <%s>\n\n" context deadline))
    (current-buffer)))

(defun my/org-capture-denote-scheduled ()
  (let* ((context (read-string "Scheduled task: "))
         (schedule (org-read-date t nil nil "Schedule: "))
         (file-name (denote nil '("task"))))
    (find-file file-name)
    (goto-char (point-min))
    (forward-line 4)
    (insert (format "\n* %s\nSCHEDULED: <%s>\n\n" context schedule))
    (current-buffer)))

(defun my/org-capture-denote-task ()
  (let* ((context (read-string "Task: "))
         (todo-state (completing-read "TODO state: "
                                      '("ACTIVE" "NEXT" "TODO" "WAIT" "PLAN")))
         (file-name (denote nil '("task"))))
    (find-file file-name)
    (goto-char (point-min))
    (forward-line 4)
    (insert (format "\n* %s %s\n\n" todo-state context))
    (point)))

(with-eval-after-load 'org
  (setq org-capture-templates
        '(("t" "Task" plain
           (function my/org-capture-denote-task)
           "" :immediate-finish t :jump-to-captured t)
          ("d" "Deadline" plain
           (function my/org-capture-denote-deadline)
           "" :immediate-finish t :jump-to-captured t)
          ("s" "Scheduled" plain
           (function my/org-capture-denote-scheduled)
           "" :immediate-finish t :jump-to-captured t))))

(use-package org-super-agenda
  :after org-agenda
  :init
  :config
  (org-super-agenda-mode))

(use-package org-ql
  :ensure t
  :after org-super-agenda)

(setq org-agenda-custom-commands
  '(
    ("d" "Daily Dashboard"
     (
       (org-ql-block '(and (scheduled :to today)
                           (not (done)))
         ((org-ql-block-header "Today's Schedule")
          (org-super-agenda-groups
           '(
             (:name "Morning Block (Before 12:00)"
              :time-grid t
              :order 1)
             (:name "Afternoon Block (12:00-17:00)"
              :time-grid t
              :order 2)
             (:name "Evening Block (After 17:00)"
              :time-grid t
              :order 3)
             (:discard (:anything t))))))

       (org-ql-block '(and (or (tags "self")
                              (tags "university"))
                           (not (scheduled))
                           (not (tags "project"))
                           (not (done)))
         ((org-ql-block-header "Unscheduled Today")
          (org-super-agenda-groups
           '(
             (:name "ACTIVE"
              :todo "ACTIVE"
              :order 1)
             (:name "NEXT"
              :todo "NEXT"
              :order 2)
             (:name "TODO"
              :todo "TODO"
              :order 3)
             (:name "WAIT"
              :todo "WAIT"
              :order 4)
             (:discard (:anything t))))))

       (org-ql-block '(and (tags "project")
                           (not (done)))
         ((org-ql-block-header "Project Tasks")
          (org-super-agenda-groups
           '(
             (:name "ACTIVE"
              :todo "ACTIVE"
              :order 1)
             (:name "NEXT"
              :todo "NEXT"
              :order 2)
             (:name "TODO"
              :todo "TODO"
              :order 3)
             (:discard (:anything t)))))))
     ((org-agenda-span 'day)))

    ("p" "Project Overview"
     ((org-ql-block '(and (tags "project")
                          (not (done)))
        ((org-ql-block-header "All Project Tasks")
         (org-super-agenda-groups
          '(
            (:name "ACTIVE"
             :todo "ACTIVE"
             :order 1)
            (:name "NEXT"
             :todo "NEXT"
             :order 2)
            (:name "TODO"
             :todo "TODO"
             :order 3)
            (:name "WAIT"
             :todo "WAIT"
             :order 4)
            (:discard (:anything t)))))))
     ((org-agenda-span 'day)))

    ("e" "Evaluation Mode - Failed Tasks"
     ((org-ql-block '(and (scheduled :to yesterday)
                          (not (done))
                          (not (habit)))
        ((org-ql-block-header "Overdue Tasks")
         (org-super-agenda-groups
          '(
            (:name "ACTIVE"
             :todo "ACTIVE"
             :order 1)
            (:name "NEXT"
             :todo "NEXT"
             :order 2)
            (:name "TODO"
             :todo "TODO"
             :order 3)
            (:discard (:anything t))))))

      (org-ql-block '(and (scheduled :from -7 :to -1)
                          (not (done))
                          (not (habit)))
        ((org-ql-block-header "This Week's Unfinished")
         (org-super-agenda-groups
          '(
            (:name "By Day"
             :scheduled t
             :order 1)
            (:discard (:anything t)))))))
     ((org-agenda-span 'week)))

    ("w" "Weekly Overview"
     ((org-ql-block '(and (or (deadline auto)
                             (scheduled :to 7))
                          (or (tags "self")
                              (tags "university"))
                          (not (tags "project"))
                          (not (done))
                          (not (habit)))
        ((org-ql-block-header "Upcoming Deadlines & Scheduled")
         (org-super-agenda-groups
          '(
            (:name "Deadlines"
             :deadline t
             :order 1)
            (:name "Scheduled"
             :scheduled t
             :order 2)
            (:discard (:anything t))))))

      (org-ql-block '(and (ts-active :from today :to 7 :with-time t)
                          (or (tags "self")
                              (tags "university"))
                          (not (tags "project"))
                          (not (done)))
        ((org-ql-block-header "Appointments This Week")
         (org-super-agenda-groups
          '(
            (:name "By Time"
             :anything t
             :order 1)))))

      (org-ql-block '(and (habit)
                          (or (tags "self")
                              (tags "university"))
                          (not (tags "project")))
        ((org-ql-block-header "Habits")
         (org-super-agenda-groups
          '(
            (:name "Daily Habits"
             :habit t
             :order 1)
            (:discard (:anything t)))))))
     ((org-agenda-span 'week)))

    ("s" "Self & University Tasks"
     ((org-ql-block '(and (or (tags "self")
                             (tags "university"))
                          (not (tags "project"))
                          (not (done)))
        ((org-ql-block-header "All Self & University Tasks")
         (org-super-agenda-groups
          '(
            (:name "ACTIVE"
             :todo "ACTIVE"
             :order 1)
            (:name "NEXT"
             :todo "NEXT"
             :order 2)
            (:name "TODO"
             :todo "TODO"
             :order 3)
            (:name "WAIT"
             :todo "WAIT"
             :order 4)
            (:discard (:anything t))))))))

    ("c" "Complexity Matrix"
     ((org-ql-block '(and (property "COMPLEXITY" "high")
                          (property "EFFORT")
                          (not (done)))
        ((org-ql-block-header "High Complexity Tasks")
         (org-super-agenda-groups
          '(
            (:name "ACTIVE"
             :todo "ACTIVE"
             :order 1)
            (:name "NEXT"
             :todo "NEXT"
             :order 2)
            (:discard (:anything t))))))

      (org-ql-block '(and (property "COMPLEXITY" "low")
                          (property "EFFORT")
                          (not (done)))
        ((org-ql-block-header "Quick Wins - Low Complexity")
         (org-super-agenda-groups
          '(
            (:name "Tasks"
             :not (:todo "WAIT")
             :order 1)
            (:discard (:anything t))))))))))

(setq org-agenda-remove-tags t)

;; (setq split-width-threshold 0)
;; (setq split-height-threshold nil)

(setq org-priority-faces
  '((?A . (:foreground "#ff6b6b" :weight bold))
    (?B . (:foreground "#ffd93d" :weight bold))
    (?C . (:foreground "#6bcf7f" :weight bold))))

(setq org-columns-default-format
  "%40ITEM(Task) %10TODO(State) %10EFFORT(Effort) %10COMPLEXITY(Complexity) %PRIORITY")

(setq org-global-properties
  '(("EFFORT_ALL" . "0:15 0:30 1:00 2:00 3:00 5:00 8:00")
    ("COMPLEXITY_ALL" . "low medium high")
    ("PRIORITY_ALL" . "A B C")))

(setq org-agenda-time-grid
  '((daily today require-timed)
    (800 1000 1200 1400 1600 1800 2000)
    "......" "________________"))

(setq org-agenda-current-time-string
  "--- NOW ---------------")

(setq org-todo-keywords
  '((sequence "TODO(t)" "NEXT(n)" "ACTIVE(a)" "WAIT(w)" "|" "DONE(d)" "CANCELLED(c)")))

(setq org-todo-keyword-faces
  '(("TODO" . (:inherit (warning org-todo)))
    ("NEXT" . (:inherit (font-lock-type-face org-todo)))
    ("ACTIVE" . (:inherit (bold org-todo)))
    ("WAIT" . (:inherit (shadow org-todo)))
    ("DONE" . (:inherit (success org-todo)))
    ("CANCELLED" . (:inherit (shadow org-done)))))

(defun my/update-org-modern-faces ()
  (setq org-modern-todo-faces
    `(("TODO" :background ,(face-attribute 'warning :foreground)
               :foreground ,(face-attribute 'default :background))
      ("ACTIVE" :background ,(face-attribute 'error :foreground)
                 :foreground ,(face-attribute 'default :background))
      ("DONE" :background ,(face-attribute 'success :foreground)
               :foreground ,(face-attribute 'default :background))
      ("CANCELLED" :background ,(face-attribute 'shadow :foreground)
                    :foreground ,(face-attribute 'default :background)))))

(add-hook 'after-load-theme-hook #'my/update-org-modern-faces)
(my/update-org-modern-faces)

(defun org-set-effort-from-complexity ()
  (interactive)
  (let* ((complexity (org-entry-get (point) "COMPLEXITY"))
         (effort (org-entry-get (point) "EFFORT")))
    (unless effort
      (cond
       ((string= complexity "low") (org-set-property "EFFORT" "0:30"))
       ((string= complexity "medium") (org-set-property "EFFORT" "2:00"))
       ((string= complexity "high") (org-set-property "EFFORT" "5:00"))))))

(define-key org-mode-map (kbd "C-c e") 'org-set-effort-from-complexity)

(defun my/org-agenda-remove-tags ()
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward " +:[[:alnum:]_@#%:]+: *$" nil t)
      (replace-match ""))))

(add-hook 'org-agenda-finalize-hook #'my/org-agenda-remove-tags)

(use-package org-contrib
  :ensure t)

(require 'ox-extra)
(ox-extras-activate '(ignore-headlines))

(use-package ox-typst
  :ensure t
  :straight (:host github :repo "jmpunkt/ox-typst")
  :after org)

(use-package org-cliplink
  :ensure t
  :defer t)

(use-package org-download
  :ensure t
  :hook (org-mode . org-download-enable)
  :config
  (setq-default org-download-image-dir "~/org/attachments/")
  (setq org-download-method 'directory)
  (setq org-download-timestamp "%Y%m%d-%H%M%S_")
  (setq org-download-heading-lvl nil))

;; (setq org-publish-project-alist
;;       '(("wiki"
;;          :author "cashmere"
;;          :email "cashmere@cashmere.rs"
;;          :preserve-breaks t
;;          :preserve-indent t
;;          :with-title t
;;          :base-directory "/home/cashmere/wiki/"
;;          :base-extension "org"
;;          :publishing-directory "/home/cashmere/wiki/html/"
;;          :recursive t
;;          :publishing-function org-html-publish-to-html
;;          :with-toc nil
;;          :section-numbers nil
;;          :html-head "<link rel=\"stylesheet\" href=\"/style.css\" type=\"text/css\"/>"
;;          :preparation-function (lambda (_)
;;                                   (require 'denote-org)
;;                                   (dolist (file (directory-files-recursively 
;;                                                 "/home/cashmere/wiki/" "\\.org$"))
;;                                     (with-current-buffer (find-file-noselect file)
;;                                       (ignore-errors
;;                                         (denote-org-extras-convert-links-to-file-type))
;;                                       (save-buffer)))))))

(setq org-publish-project-alist
      '(("wiki"
         :base-directory "~/wiki"
         :publishing-directory "~/blog/content/wiki"
         :publishing-function denote-publish-to-md
         :recursive nil
         :exclude-tags ("noexport" "draft")
         :section-numbers nil
         :with-creator nil
         :with-toc nil)))

(setq org-export-with-broken-links t)

(use-package ox-pandoc
  :ensure t
  :after org)

(use-package denote
  :ensure t
  :hook (dired-mode . denote-dired-mode)
  :config
  (setq denote-rename-buffer-format "%t"
        denote-buffer-name-prefix ""
        denote-directory (expand-file-name "~/org/"))
  (denote-rename-buffer-mode 1))

(use-package denote-agenda
  :ensure t
  :after org
  :config
  (setq denote-agenda-include-regexp "task")
  (denote-agenda-insinuate))

(use-package denote-journal
  :ensure t
  :config
  (setopt denote-journal-title-format 'day-date-month-year))

(defcustom my/denote-task-filename-component-regexp
  "\\(?:[-_.]\\|:\\)task\\(?:[-_.]\\|:\\|$\\)"
  "Regexp matching a filename component that denotes the 'task' tag.
Works on the base filename (without extension), e.g. matches \"-task\", \":task:\", \"_task_\"."
  :type 'string)

(defun my/denote--make-unique-filename (dir base ext)
  "Return a unique filepath in DIR for BASE+EXT by adding -1, -2... if needed."
  (let* ((extstr (if (and ext (not (string-empty-p ext))) (concat "." ext) ""))
         (candidate (expand-file-name (concat base extstr) dir))
         (count 1))
    (while (file-exists-p candidate)
      (setq candidate (expand-file-name (format "%s-%d%s" base count extstr) dir))
      (setq count (1+ count)))
    candidate))

(defun my/denote-remove-task-filetag-and-silent-rename ()
  "If current headline became DONE in a Denote note, remove :task: filetag and remove 'task' from filename silently.
- Only acts if there are no other non-DONE TODOs in the same file.
- Does not call Denote's interactive rename command (no buffers opened)."
  (when (and (derived-mode-p 'org-mode)
             (string= (org-get-todo-state) "DONE")
             (buffer-file-name)
             ;; detect Denote note by presence of #+identifier:
             (save-excursion
               (goto-char (point-min))
               (re-search-forward "^#\\+identifier:" nil t)))
    ;; only proceed if no other active TODOs remain in the file
    (let ((has-other
           (catch 'has
             (org-map-entries
              (lambda ()
                (let ((s (org-get-todo-state)))
                  (when (and s (not (string= s "DONE")))
                    (throw 'has t))))
              nil 'file)
             nil)))
      (unless has-other
        ;; 1) Remove :task: from #+filetags:
        (save-excursion
          (goto-char (point-min))
          (when (re-search-forward "^#\\+filetags:\\s-*\\(.*\\)$" nil t)
            (let* ((tags (match-string 1))
                   (clean (replace-regexp-in-string ":task:" "" tags))
                   (clean (replace-regexp-in-string "::+" ":" clean))
                   (clean (replace-regexp-in-string "^:\\|:$" "" clean)))
              (if (string-empty-p clean)
                  (delete-region (line-beginning-position) (1+ (line-end-position)))
                (beginning-of-line)
                (kill-line)
                (insert (concat "#+filetags: :" clean ":"))))))
        ;; 2) Compute new filename (silent, non-interactive)
        (let* ((file (buffer-file-name))
               (dir  (file-name-directory file))
               (name (file-name-nondirectory file))
               (ext  (file-name-extension name)) ;; "org"
               (base (file-name-sans-extension name))
               ;; remove the task component from the base
               (new-base (replace-regexp-in-string my/denote-task-filename-component-regexp
                                                   ""
                                                   base)))
          (when (and new-base (not (string= new-base base)))
            ;; cleanup repeated separators: convert multiple '-'/'_'/'..' to single '-'
            (setq new-base (replace-regexp-in-string "[-_.:]+"
                                                     "-"
                                                     new-base))
            ;; strip leading/trailing separators
            (setq new-base (replace-regexp-in-string "\\`[-_.:-]+" "" new-base))
            (setq new-base (replace-regexp-in-string "[-_.:-]+\\'" "" new-base))
            ;; ensure unique filename to avoid overwrite without prompt
            (let ((target (my/denote--make-unique-filename dir new-base ext)))
              (condition-case err
                  (progn
                    (rename-file file target 1) ;; 1 = ok to overwrite, but we avoid collisions by uniqueness
                    ;; update current buffer to visit the new filename silently
                    (set-visited-file-name target t t)
                    ;; save changes (filetags update + new filename)
                    (save-buffer)
                    (message "Denote: removed 'task' component from filename -> %s" (file-name-nondirectory target)))
                (error
                 (message "Denote rename failed: %s" (error-message-string err)))))))))))

(add-hook 'org-after-todo-state-change-hook #'my/denote-remove-task-filetag-and-silent-rename)

(use-package denote-menu
  :ensure t
  :defer t
  :config
  (setq denote-menu-title-column-width 60))

(use-package denote-org
    :ensure t)

(use-package consult-denote
  :straight (:host github :repo "protesilaos/consult-denote")
  :ensure t
  :defer t)

(defun my/convert-all-denote-links-in-directory (directory)
  "Converts all denote: links to file: links in a specific directory."
  (interactive "DDirectory: ")
  (let ((org-files (directory-files directory t "\\.org$")))
    (dolist (file org-files)
      (with-current-buffer (find-file-noselect file)
        (save-excursion
          (goto-char (point-min))
          (while (re-search-forward "\\[\\[denote:\\([0-9T]+\\)\\]\\(?:\\[\\([^]]*\\)\\]\\)?\\]" nil t)
            (let* ((id (match-string 1))
                   (description (match-string 2))
                   (target-file (seq-find 
                                (lambda (f) 
                                  (string-match-p (regexp-quote id) (file-name-nondirectory f)))
                                org-files)))
              (when target-file
                (let* ((target-filename (file-name-nondirectory target-file))
                       (new-link (if description
                                     (format "[[file:./%s][%s]]" target-filename description)
                                   (format "[[file:./%s]]" target-filename))))
                  (replace-match new-link t t))))))
        (save-buffer)
        (kill-buffer)))))

(use-package ox-json
  :ensure t
  )

(use-package denote-explore
  :ensure t
  )

(use-package denote-publish
  :ensure t
  :straight ( denote-publish :type git :host nil :repo "https://github.com/vedang/denote-publish")) 

(setq denote-publish-default-base-dir "~/wiki")
(setq denote-publish-default-output-dir "~/blog/wiki")

(setq denote-publish-link-class "internal-link")

(setq denote-publish-front-matter-fields
      '(title subtitle identifier date last_updated_at
              aliases tags category skip_archive has_code
              og_image og_description og_video_id))

(use-package tmr
  :ensure t
  :straight (:host github :repo "protesilaos/tmr")
  :config
  (setq tmr-sound-file "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
        tmr-notification-urgency 'normal
        tmr-description-list 'tmr-description-history)
  
  (define-key global-map (kbd "C-c t") #'tmr-prefix-map))

(with-eval-after-load 'tmr-tabulated-mode
  (general-def 'normal tmr-tabulated-mode-hook
    "y" 'tmr-clone
    "c" 'tmr-cancel
    "d" 'tmr-remove
    "D" 'tmr-remove-finished
	"n" 'tmr
	"N" 'tmr-with-details
	"e" 'tmr-edit-description
	"r" 'tmr-reschedule))

(use-package which-key
  :ensure t
  :defer t
  :hook
  (after-init . which-key-mode)
  :custom
  (which-key-idle-delay 0.3))

(use-package vertico
  :ensure t
  :straight t
  :hook
  (after-init . vertico-mode)
  :custom
  (vertico-count 10)
  (vertico-resize nil)
  (vertico-cycle nil)
  :bind (:map vertico-map
                          ("C-j" . vertico-next)
                          ("C-k" . vertico-previous))
  :config
  (advice-add #'vertico--format-candidate :around
                          (lambda (orig cand prefix suffix index _start)
                                (setq cand (funcall orig cand prefix suffix index _start))
                                (concat
                                 (if (= vertico--index index)
                                         (propertize "» " 'face '(:foreground "#80adf0" :weight bold))
                                   "  ")
                                 cand))))

;; (use-package vertico-posframe
;;   :init
;;   (setq vertico-posframe-parameters   '((left-fringe  . 12)    ;; Fringes
;;                                         (right-fringe . 12)
;; 										(accept-focus . t)))
;;                                         ;; (undecorated  . nil) ;; Rounded frame
										 
;;   :config
;;   (vertico-posframe-mode 1)
;;   (setq vertico-posframe-width        96                       ;; Narrow frame
;;         vertico-posframe-height       vertico-count            ;; Default height
;;         ;; Don't create posframe for these commands
;;         vertico-multiform-commands    '((consult-line    (:not posframe))
;;                                         (consult-ripgrep (:not posframe)))))

(use-package corfu
  :ensure t
  :custom
  (corfu-cycle t)
  (corfu-auto t)
  (corfu-auto-delay 0.2)
  (corfu-auto-prefix 2)
  :init
  (global-corfu-mode)
  (corfu-history-mode)
  (corfu-popupinfo-mode))

(defun my/suppress-corfu-terminal-warning (orig-fun type message &rest args)
  (unless (and (eq type 'corfu)
               (string-match-p "corfu-terminal.*not needed" message))
    (apply orig-fun type message args)))

(advice-add 'display-warning :around #'my/suppress-corfu-terminal-warning)

(use-package corfu-terminal
  :ensure t
  :after corfu
  :init
  (corfu-terminal-mode +1))

(use-package cape
  :ensure t
  ;; Bind prefix keymap providing all Cape commands under a mnemonic key.
  ;; Press C-c p ? to for help.
  ;; Alternatively bind Cape commands individually.
  ;; :bind (("C-c p d" . cape-dabbrev)
  ;;        ("C-c p h" . cape-history)
  ;;        ("C-c p f" . cape-file)
  ;;        ...)
  :init
  ;; Add to the global default value of `completion-at-point-functions' which is
  ;; used by `completion-at-point'.  The order of the functions matters, the
  ;; first function returning a result wins.  Note that the list of buffer-local
  ;; completion functions takes precedence over the global list.
  (add-hook 'completion-at-point-functions #'cape-file)
  ;; (add-hook 'completion-at-point-functions #'cape-history)
  ;; ...
)

(use-package consult
  :ensure t
  :straight t
  :defer t
  :init
  (advice-add #'register-preview :override #'consult-register-window)

  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)

  :config
  (setq consult-buffer-filter
        '("\\` "
          "\\`\\*Messages\\*\\'"
          "\\`\\*Warnings\\*\\'"
          "\\`\\*Compile-Log\\*\\'"
          "\\`\\*Backtrace\\*\\'"
          "\\`\\*Help\\*\\'"
          "\\`\\*scratch\\*\\'"
          "\\`\\*Completions\\*\\'"
          "\\`\\*Flymake"
          "\\`\\*lsp-help\\*\\'"
          "\\`\\*eldoc"
          "\\`\\*straight-process\\*\\'"
          "\\`\\*Native-compile-Log\\*\\'"
          "\\`\\*Async-native-compile-log\\*\\'")))

(use-package markdown-mode
  :defer t
  :ensure t
  :mode ("README\\.md\\'" . gfm-mode)            
  :init 
  (setq markdown-command "multimarkdown")
  :config
  (setq markdown-header-scaling t)
  (setq markdown-hide-markup t)
  (setq markdown-fontify-code-blocks-natively t)
  
  (custom-set-faces
   '(markdown-header-face-1 ((t (:inherit markdown-header-face :height 1.8 :foreground "#A3BE8C" :weight extra-bold))))
   '(markdown-header-face-2 ((t (:inherit markdown-header-face :height 1.4 :foreground "#EBCB8B" :weight extra-bold))))
   '(markdown-header-face-3 ((t (:inherit markdown-header-face :height 1.2 :foreground "#D08770" :weight extra-bold))))
   '(markdown-header-face-4 ((t (:inherit markdown-header-face :height 1.15 :foreground "#BF616A" :weight extra-bold))))
   '(markdown-header-face-5 ((t (:inherit markdown-header-face :height 1.11 :foreground "#b48ead" :weight extra-bold))))
   '(markdown-header-face-6 ((t (:inherit markdown-header-face :height 1.06 :foreground "#5e81ac" :weight extra-bold))))
   '(markdown-header-delimiter-face ((t (:foreground "#616161" :height 0.9))))))

;; (use-package treesit-auto
;;   :ensure t
;;   :straight t
;;   :defer t
;;   :custom
;;   (treesit-auto-install 'prompt)
;;   :init
;;   (delete 'org treesit-auto-langs)
;;   :config
;;   (treesit-auto-add-to-auto-mode-alist 'all)
;;   (global-treesit-auto-mode t))

(use-package embark
  :ensure t
  :straight t
  :defer t)

(use-package embark-consult
  :ensure t
  :straight t
  :hook
  (embark-collect-mode . consult-preview-at-point-mode)) ;; Enable preview in Embark collect mode.

(use-package orderless
    :ensure t
    :straight t
    :defer t                                    ;; Load Orderless on demand.
    :after vertico                              ;; Ensure Vertico is loaded before Orderless.
    :init
    (setq completion-styles '(orderless basic)  ;; Set the completion styles.
completion-category-defaults nil      ;; Clear default category settings.
completion-category-overrides '((file (styles partial-completion))))) ;; Customize file completion styles.

(use-package marginalia
  :ensure t
  :straight t
  :hook
  (after-init . marginalia-mode))

(use-package eglot
  :straight nil
  :ensure nil
  :config
  (setq eglot-autoshutdown t)
  (setq eglot-sync-connect 1)
  (setq eglot-send-changes-idle-time 0.1)
  (setq eglot-sync-connect nil)
  (setq eglot-connect-timeout nil)
  (setq eglot-events-buffer-size 0)
  (setq eglot-report-progress nil)
  
  (add-hook 'eglot-managed-mode-hook 
            (lambda () 
              (eglot-inlay-hints-mode -1)
              (eglot-semantic-tokens-mode 1)))
  
  (setq eglot-ignored-server-capabilities 
        '(:inlayhintprovider :documenthighlightprovider)))



;; (use-package eglot-booster
;;   :ensure t
;;   :straight ( eglot-booster :type git :host nil :repo "https://github.com/jdtsmith/eglot-booster")
;;   :after eglot
;;   :config	(eglot-booster-mode))

(use-package typst-ts-mode
  :ensure t
  :mode "\\.typ\\'"
  :hook (typst-ts-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 typst-ts-mode . ,(eglot-alternatives '("tinymist" "lsp")))))

(use-package yasnippet
  :ensure t
  :config
  (yas-global-mode 1))

(use-package yasnippet-snippets
  :ensure t
  :after yasnippet)

(use-package nix-mode
  :ensure t
  :mode "\\.nix\\'"
  :hook (nix-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(nix-mode . ("nixd")))))

(use-package envrc
  :ensure t
  :config
  (envrc-global-mode))

(use-package python-mode
  :ensure t
  :mode "\\.py\\'"
  :hook (python-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(python-mode . ("rass" "python")))))

(use-package python-black
  :ensure t
  :demand t
  :after python)

;; (use-package python-mode
;;   :ensure t
;;   :mode "\\.py\\'"
;;   :hook (python-mode . eglot-ensure)
;;   :config
;;   (with-eval-after-load 'eglot
;;     (setq eglot-server-programs
;;           (assoc-delete-all 'python-mode eglot-server-programs))
;;     (setq eglot-server-programs
;;           (assoc-delete-all 'python-ts-mode eglot-server-programs))
;;     (add-to-list 'eglot-server-programs
;;                  '(python-mode . ("ty" "lsp")))))

(use-package pyvenv
  :ensure t
  :config
  (setq pyvenv-mode-line-indicator '(pyvenv-virtual-env-name 
                                      (" [venv:" pyvenv-virtual-env-name "] ")))
  (add-hook 'python-mode-hook 
            (lambda ()
              (pyvenv-mode 1))))

(use-package ruff-format
  :ensure t
  :hook (python-mode . ruff-format-on-save-mode))

;; (use-package elm-mode
;;   :ensure t
;;   :mode  "\\.elm\\'"
;;   :hook (elm-mode . eglot-ensure)
;;   :config
;;   (with-eval-after-load 'eglot-server-programs
;; 	'(elm-mode . ("elm-language-server"))))

(use-package rust-mode
  :ensure t
  :mode "\\.rs\\'"
  :hook (rust-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '((rust-ts-mode rust-mode) .
                   ("rust-analyzer" :initializationOptions 
                    (:check (:command "clippy")))))))

;; (use-package rustic
;;   :ensure t
;;   :config
;;   (setq rustic-format-on-save nil)
;;   (setq rustic-lsp-client nil)
;;   :custom
;;   (rustic-cargo-use-last-stored-arguments t))

(use-package js
  :ensure t
  :mode ("\\.js\\'" . js-mode)
  :config
  (setq js-indent-level 2))

(use-package mint-mode
  :straight (mint-mode
             :type git
             :host github
             :repo "creatorrr/emacs-mint-mode")
  :mode "\\.mint\\'"
  :hook (mint-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(mint-mode . ("mint" "tool" "ls")))))

;; (use-package nushell-mode
;;   :ensure nil
;;   :straight nil
;;   :mode "\\.nu\\'")

;; (use-package nushell-ts-babel
;;   :straight (nushell-ts-babel :type git :host github :repo "herbertjones/nushell-ts-babel")
;;   :after org
;;   :config
;;   (org-babel-do-load-languages
;;    'org-babel-load-languages
;;    (append org-babel-load-languages
;;            '((nushell . t)))))

;; (use-package go-mode
;;   :ensure t
;;   :mode "\\.go\\'"
;;   :hook (go-mode . eglot-ensure)
;;   :config
;;   (with-eval-after-load 'eglot
;;     (add-to-list 'eglot-server-programs
;;                  '(go-mode . ("gopls" :initializationOptions 
;;                               (:staticcheck t
;;                                :matcher "CaseSensitive"
;;                                :usePlaceholders t)))))
  
;;   (defun go-mode-setup ()
;;     (add-hook 'before-save-hook #'eglot-format-buffer -10 t)
;;     (add-hook 'before-save-hook 
;;               (lambda ()
;;                 (when (eglot-managed-p)
;;                   (eglot-code-action-organize-imports nil t)))
;;               nil t))
  
;;   (add-hook 'go-mode-hook #'go-mode-setup))

(use-package json-mode
  :ensure t
  :mode "\\.json\\'"
  :hook (json-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(json-mode . ("vscode-json-language-server" "--stdio")))))

(use-package yaml-mode
  :ensure t
  :mode "\\.ya?ml\\'"
  :hook (yaml-mode . eglot-ensure))

(use-package sh-mode
  :straight nil
  :ensure nil
  :hook (bash-ts-mode . eglot-ensure)
        (sh-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '((sh-mode bash-ts-mode) . ("bash-language-server" "start"))))
  
  (defun sh-mode-setup ()
    (add-hook 'before-save-hook #'eglot-format-buffer -10 t))
  
  (add-hook 'sh-mode-hook #'sh-mode-setup)
  (add-hook 'bash-ts-mode-hook #'sh-mode-setup))

(use-package jinja2-mode
  :ensure t
  :defer t)

(use-package protobuf-mode
  :ensure t
  :mode ("\\.proto\\'" . protobuf-mode))

(use-package janet-mode
  :mode ("\\.js\\'" . js-mode)
  :ensure t
  :config
  (with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(janet-mode . ("janet-lsp")))))

(use-package vterm
  :ensure t
  :config
  (setq vterm-timer-delay 0.001))

(use-package multi-vterm
  :ensure t
  :defer t)

(use-package olivetti
  :custom
  (olivetti-style 'fancy)  ; Keep margins visible
  (olivetti-margin-width 10)  ; No side margins
  ;; (olivetti-shrink t)
  (olivetti-safe t)
)

(defun my-org-sidecar-left ()
  "Org-Datei interaktiv als Sidecar links (25%)."
  (interactive)
  (let ((file (read-file-name "Org-Sidecar: " nil nil t)))
    (display-buffer-in-side-window
     (find-file-noselect file)
     '((side . left)
       (window-width . 0.25)
       (slot . 0)))))

(global-set-key (kbd "C-c o s") #'my-org-sidecar-left)

;; (use-package visual-fill-column
;;   :hook ((text-mode . visual-line-mode)        ;; Soft-Wrapping aktivieren
;;          (text-mode . visual-fill-column-mode)) ;; Das Zentrieren aktivieren
;;   :custom
;;   (visual-fill-column-width 110)      ;; Maximale Breite des Textes (statt 0.67 relativ)
;;   (visual-fill-column-center-text t) ;; Text zentrieren!
;;   (visual-fill-column-enable-sensible-window-split t))

;; (use-package diff-hl
;;   :defer t
;;   :straight t
;;   :ensure t
;;   :hook
;;   (find-file . (lambda ()
;;                  (global-diff-hl-mode)           ;; Enable Diff-HL mode for all files.
;;                  (diff-hl-flydiff-mode)          ;; Automatically refresh diffs.
;;                  (diff-hl-margin-mode)))         ;; Show diff indicators in the margin.
;;   :custom
;;   (diff-hl-side 'left)                           ;; Set the side for diff indicators.
;;   (diff-hl-margin-symbols-alist '((insert . "┃") ;; Customize symbols for each change type.
;;                                   (delete . "-")
;;                                   (change . "┃")
;;                                   (unknown . "┆")
;;                                   (ignored . "i"))))

(use-package diff-hl
  :defer t
  :straight t
  :ensure t
  :hook
  (find-file . (lambda ()
                 (global-diff-hl-mode)           ;; Enable Diff-HL mode for all files.
                 (diff-hl-flydiff-mode)          ;; Automatically refresh diffs.
                 (diff-hl-margin-mode)))         ;; Show diff indicators in the margin.
  :custom
  (diff-hl-side 'left)                           ;; Set the side for diff indicators.
  (diff-hl-margin-symbols-alist '((insert . "┃") ;; Customize symbols for each change type.
                                  (delete . "-")
                                  (change . "┃")
                                  (unknown . "┆")
                                  (ignored . "i"))))

(use-package hl-todo
  :ensure t
  :straight (:host github :repo "tarsius/hl-todo")
  :config
  (global-hl-todo-mode) 
  (setq hl-todo-keyword-faces
        '(("TODO"   . "#FF0000")
          ("FIXME"  . "#FF0000")
          ("DEBUG"  . "#A020F0")
          ("GOTCHA" . "#FF4500")
          ("STUB"   . "#1E90FF"))))

(use-package magit
  :ensure t
  :straight t
  :config
  (if ek-use-nerd-fonts
	  (setopt magit-format-file-function #'magit-format-file-nerd-icons))
  :custom
  (magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

(defun my/magit-kill-buffers ()
  (interactive)
  (let ((buffers (magit-mode-get-buffers)))
	(magit-restore-window-configuration)
	(mapc #'kill-buffer buffers)))

(setq switch-to-prev-buffer-skip
      (lambda (window buffer bury-or-kill)
        (string-match-p "\\*magit" (buffer-name buffer))))

(use-package conventional-commit
  :ensure t
  :straight (:host github :repo "akirak/conventional-commit.el")
  :after git-commit
  :hook
  (git-commit-mode . conventional-commit-setup))

(use-package hl-todo
  :ensure t
  :straight (:host github :repo "tarsius/hl-todo")
  :config
  (global-hl-todo-mode) 
  (setq hl-todo-keyword-faces
        '(("TODO"   . "#FF0000")
          ("FIXME"  . "#FF0000")
          ("DEBUG"  . "#A020F0")
          ("GOTCHA" . "#FF4500")
          ("STUB"   . "#1E90FF"))))

(use-package magit
  :ensure t
  :straight t
  :config
  (if ek-use-nerd-fonts
	  (setopt magit-format-file-function #'magit-format-file-nerd-icons))
  :custom
  (magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

(defun my/magit-kill-buffers ()
  (interactive)
  (let ((buffers (magit-mode-get-buffers)))
	(magit-restore-window-configuration)
	(mapc #'kill-buffer buffers)))

(setq switch-to-prev-buffer-skip
      (lambda (window buffer bury-or-kill)
        (string-match-p "\\*magit" (buffer-name buffer))))

(use-package conventional-commit
  :ensure t
  :straight (:host github :repo "akirak/conventional-commit.el")
  :after git-commit
  :hook
  (git-commit-mode . conventional-commit-setup))

(use-package indent-guide
  :defer t
  :straight t
  :ensure t
  :hook
  (prog-mode . indent-guide-mode)  ;; Activate indent-guide in programming modes.
  :config
  (setq indent-guide-char "│"))    ;; Set the character used for the indent guide.

(use-package general
  :straight t
  :ensure t
  :demand t
  :config
  (general-evil-setup)

  (general-create-definer my-leader
    :states '(normal visual)
    :keymaps 'override
    :prefix "SPC")

  (general-create-definer my-local-leader
    :states '(normal visual)
    :keymaps 'override
    :prefix ","))

(use-package evil
  :ensure t
  :init
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  (setq evil-want-C-u-delete t)
  (setq evil-want-C-u-scroll t)
  (setq evil-undo-system 'undo-tree)
  (setq evil-split-window-below t)
  (setq evil-vsplit-window-right t)
  :config
  (evil-mode 1)
  (define-key evil-normal-state-map "u" 'undo-tree-undo)
  (define-key evil-normal-state-map (kbd "C-r") 'undo-tree-redo)
  (evil-set-initial-state 'help-mode 'emacs)
  (evil-set-initial-state 'messages-buffer-mode 'normal)
  (evil-set-initial-state 'dired-mode 'normal)
  (evil-set-initial-state 'ibuffer-mode 'normal))

(modify-syntax-entry ?_ "w")

;; (defun my/eldoc-and-jump ()
;;   (interactive)
;;   (if (display-graphic-p)
;;       (call-interactively 'eldoc-box-help-at-point)
;;     (progn
;;       (eldoc-doc-buffer)
;;       (when-let ((eldoc-win (get-buffer-window "*eldoc*")))
;;         (select-window eldoc-win)))))

(defun my/eldoc-and-jump ()
  (interactive)
      (call-interactively 'eldoc-box-help-at-point))

;; (define-key evil-normal-state-map (kbd "K") #'my/eldoc-and-jump)

;; (setq select-enable-clipboard nil)
;; (setq select-enable-primary nil)

;; (evil-define-operator my/evil-yank-to-clipboard (beg end type register yank-handler)
;;   :move-point nil
;;   :repeat nil
;;   (interactive "<R><x><y>")
;;   (let ((select-enable-clipboard t))
;;     (evil-yank beg end type register yank-handler)))

;; (defun my/evil-paste-from-clipboard ()
;;   (interactive)
;;   (let ((select-enable-clipboard t))
;;     (evil-paste-before 1 ?+)))

;; (general-def '(normal visual) 'override
;;   :prefix "SPC"
;;   "yy" 'my/evil-yank-to-clipboard
;;   "yp" 'my/evil-paste-from-clipboard)

(use-package smartparens
  :ensure t
  :init
  (smartparens-global-mode 1)  
  :config
  (require 'smartparens-config))
(use-package evil-smartparens
  :ensure t
  :after evil-collection
  :hook (smartparens-global-mode . evil-smartparens-mode))

(use-package evil-collection
  :after evil
  :ensure t
  :config
  (evil-collection-init))

(use-package evil-surround
  :ensure t
  :straight t
  :after evil-collection
  :config
  (global-evil-surround-mode 1))

(use-package evil-matchit
  :ensure t
  :straight t
  :after evil-collection
  :config
  (global-evil-matchit-mode 1))

(use-package evil-textobj-anyblock
  :ensure t
  :after evil
  :config
  (define-key evil-inner-text-objects-map "b" 'evil-textobj-anyblock-inner-block)
  (define-key evil-outer-text-objects-map "b" 'evil-textobj-anyblock-a-block)
  
  (setq evil-textobj-anyblock-blocks
        '(("(" . ")")
          ("{" . "}")
          ("\\[" . "\\]")
          ("<" . ">"))))

(evil-define-text-object my-evil-textobj-anyblock-inner-quote
  (count &optional beg end type)
  "Select the closest outer quote."
  (let ((evil-textobj-anyblock-blocks
         '(("'" . "'")
           ("\"" . "\"")
           ("`" . "'")
           ("“" . "”"))))
    (evil-textobj-anyblock--make-textobj beg end type count nil)))

(evil-define-text-object my-evil-textobj-anyblock-a-quote
  (count &optional beg end type)
  "Select the closest outer quote."
  (let ((evil-textobj-anyblock-blocks
         '(("'" . "'")
           ("\"" . "\"")
           ("`" . "'")
           ("“" . "”"))))
    (evil-textobj-anyblock--make-textobj beg end type count t)))

(define-key evil-inner-text-objects-map "q" 'my-evil-textobj-anyblock-inner-quote)
(define-key evil-outer-text-objects-map "q" 'my-evil-textobj-anyblock-a-quote)

;; Paket für echte Multiple Cursors
(use-package evil-mc
  :ensure t
  :after evil
  :config
  (global-evil-mc-mode 1)
  
  ;; Hilfsfunktion: Prüfen, ob wir im Visual-Block-Mode sind
  ;; Diese Funktion fängt den Fehler ab, falls Variablen nicht existieren.
  (defun my/evil-visual-block-p ()
    (and (bound-and-true-p evil-visual-selection)
         (eq evil-visual-selection 'block)))

  ;; Funktion für Insert am Anfang (I)
  (defun my/evil-mc-visual-block-insert ()
    "Erstellt Cursor am Anfang des Blocks und wechselt in Insert-Mode."
    (interactive)
    (if (my/evil-visual-block-p)
        (progn
          (evil-mc-make-cursor-in-visual-selection-beg)
          (evil-insert 1))
      ;; Fallback: normales Verhalten, falls kein Block-Mode
      (call-interactively 'evil-insert)))

  ;; Funktion für Append am Ende (A)
  (defun my/evil-mc-visual-block-append ()
    "Erstellt Cursor am Ende des Blocks und wechselt in Insert-Mode."
    (interactive)
    (if (my/evil-visual-block-p)
        (progn
          (evil-mc-make-cursor-in-visual-selection-end)
          (evil-append 1))
      ;; Fallback: normales Verhalten
      (call-interactively 'evil-append)))

  ;; Tastenbelegung im Visual Mode überschreiben
  (define-key evil-visual-state-map (kbd "I") 'my/evil-mc-visual-block-insert)
  (define-key evil-visual-state-map (kbd "A") 'my/evil-mc-visual-block-append))

(use-package avy
  :ensure t
  :straight t
  :after evil
  :general
  ;; (general-nmap "s" 'avy-goto-char-timer)
  ;; (general-omap "s" 'evil-avy-goto-char-timer)
  :config
  (setq avy-all-windows t
        avy-all-windows-alt t
        avy-background t
        avy-case-fold-search t
        avy-timeout-seconds 0.3
        avy-style 'at-full
        avy-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l))

  (evil-define-avy-motion emacs-flash-jump inclusive))

(use-package flash-emacs
  :ensure t
  :straight (:host github :repo "JiaweiChenC/flash-emacs"))

;; ZenScriptor/avy-flash
(use-package avy-flash
  :ensure t
  :straight (:host github :repo "ZenScriptor/avy-flash"))

(use-package undo-tree
  :defer t
  :ensure t
  :straight t
  :hook (after-init . global-undo-tree-mode)
  :init
  (setq undo-tree-visualizer-timestamps t
        undo-tree-visualizer-diff t
        undo-tree-auto-save-history t
        undo-tree-history-directory-alist '(("." . "~/.emacs.d/undo-tree-history/"))
        undo-limit 800000
        undo-strong-limit 12000000
        undo-outer-limit 120000000)
  :config
  (setq undo-tree-mode-lighter ""))

(use-package rainbow-delimiters
  :defer t
  :straight t
  :ensure t
  :hook
  (prog-mode . rainbow-delimiters-mode))

(use-package dotenv-mode
  :defer t
  :straight t
  :ensure t
  :config)

(use-package envrc
  :hook (after-init . envrc-global-mode))

(add-hook 'org-agenda-mode-hook
          (lambda ()
            (add-hook 'auto-save-hook 'org-save-all-org-buffers nil t)
            (auto-save-mode)))
(use-package org-agenda
  :ensure nil
  :straight nil
  :config
  (setq org-agenda-window-setup 'current-window
   org-agenda-inhibit-startup t
		org-agenda-use-tag-inheritance nil
		org-agenda-dim-blocked-tasks nil
		org-startup-indented nil
		org-startup-folded 'overview
		org-agenda-prefix-format
		'((agenda . " %i %?-12t% s")
		  (todo . " %i ")
		  (tags . " %i ")
		  (search . " %i "))))

(use-package evil-org
  :ensure t
  :after org
  :hook (org-mode . evil-org-mode)
  :config
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys))

(use-package nerd-icons
  :if ek-use-nerd-fonts                   ;; Load the package only if the user has configured to use nerd fonts.
  :ensure t)                               ;; Ensure the package is installed.
;; Load the package only when needed to improve startup time.

(use-package nerd-icons-dired
  :if ek-use-nerd-fonts                   ;; Load the package only if the user has configured to use nerd fonts.
  :ensure t                               ;; Ensure the package is installed.
  :straight t
  :defer t                                ;; Load the package only when needed to improve startup time.
  :hook
  (dired-mode . nerd-icons-dired-mode))

(use-package nerd-icons-completion
  :if ek-use-nerd-fonts                   ;; Load the package only if the user has configured to use nerd fonts.
  :ensure t                               ;; Ensure the package is installed.
  :straight t
  :after (:all nerd-icons marginalia)     ;; Load after `nerd-icons' and `marginalia' to ensure proper integration.
  :config
  (nerd-icons-completion-mode)            ;; Activate nerd icons for completion interfaces.
  (add-hook 'marginalia-mode-hook #'nerd-icons-completion-marginalia-setup)) ;; Setup icons in the marginalia mode for enhanced completion display.

(defun ek/first-install ()
  "dired"
  (interactive)                                      ;; Allow this function to be called interactively.
  (switch-to-buffer "*Messages*")                    ;; Switch to the *Messages* buffer to display installation messages.
  (message ">>> All required packages installed.")
  (message ">>> Configuring Emacs-Kick...")
  (message ">>> Configuring Tree Sitter parsers...")
  (require 'treesit-auto)
  (treesit-auto-install-all)                         ;; Install all available Tree Sitter grammars.
  (message ">>> Configuring Nerd Fonts...")
  (require 'nerd-icons)
  (nerd-icons-install-fonts)                         ;; Install all available nerd-fonts
  (message ">>> Emacs-Kick installed! Press any key to close the installer and open Emacs normally. First boot will compile some extra stuff :)")
  (read-key)                                         ;; Wait for the user to press any key.
  (kill-emacs))                                      ;; Close Emacs after installation is complete.

(use-package hide-mode-line
  :ensure t)

;; (use-package awesome-tray
;;   :straight (:host github :repo "manateelazycat/awesome-tray")
;;   :custom
;;   ;; Position at the top
;;   ;; (setq awesome-tray-position 'right)
  
;;   ;; Basic Visual Settings
;;   ;; (awesome-tray-hide-mode-line t)
;;   (awesome-tray-separator " │ ")
;;   (awesome-tray-ellipsis "…")
  
;;   ;; Module Customizations
;;   (awesome-tray-date-format "%I:%M %p")  ; 12-hour format with AM/PM
;;   (awesome-tray-git-format " ᚴ %s")
;;   (awesome-tray-git-show-status t)
;;   (awesome-tray-location-format "%l:%c")
;;   (awesome-tray-evil-show-mode t)
;;   (awesome-tray-evil-show-macro t)
;;   (awesome-tray-evil-show-cursor-count t)
;;   (awesome-tray-file-path-full-dirname-levels 2)
;;   (awesome-tray-file-path-shorten-start-length 1)
;;   (awesome-tray-input-method-default-style "EN")
;;   (awesome-tray-input-method-local-style "中")
;;   (awesome-tray-input-method-local-methods '("rime" "pinyin"))
  
;;   ;; Performance settings
;;   (awesome-tray-refresh-idle-delay 0.5)
;;   (awesome-tray-refresh-timer t)
;;   (awesome-tray-update-interval 1)
  
;;   :config
;;   ;; Start with essential modules for performance
;;   (setq awesome-tray-active-modules
;;         '(
;;           "buffer-name"
;;           "mode-name"
;;           "date"
;;           "location"
;;           "evil"
;;           "input-method"
;;           ))
  
;;   ;; Enable awesome-tray
;;   (awesome-tray-mode 1)
;; )

;; (setq display-time-mode 1)
;; (use-package lambda-line
;;   :straight (:type git :host github :repo "lambda-emacs/lambda-line") 
;;   :custom
;;   (lambda-line-lsp-indicator nil)
;;   (lambda-line-icon-time t) ;; requires ClockFace font (see below)
;;   (lambda-line-clockface-update-fontset "ClockFaceRect") ;; set clock icon
;;   (lambda-line-position 'top) ;; Set position of status-line 
;;   (lambda-line-abbrev nil) ;; abbreviate major modes
;;   (lambda-line-hspace "  ")  ;; add some cushion
;;   (lambda-line-prefix t) ;; use a prefix symbol
;;   (lambda-line-prefix-padding nil) ;; no extra space for prefix 
;;   (lambda-line-status-invert nil)  ;; no invert colors
;;   (lambda-line-gui-ro-symbol  " ⨂") ;; symbols
;;   (lambda-line-gui-mod-symbol " ⬤") 
;;   (lambda-line-gui-rw-symbol  " ◯") 
;;   (lambda-line-vc-symbol nil)
;;   (lambda-line-space-top -.50)  ;; padding on top and bottom of line
;;   (lambda-line-space-bottom -.50)
;;   (lambda-line-symbol-position 0.1) ;; adjust the vertical placement of symbol
;;   :config
;;   ;; activate lambda-line 
;;   (lambda-line-mode) 
;;   ;; set divider line in footer
;;   (when (eq lambda-line-position 'top)
;;     (setq-default mode-line-format (list "%_"))
;;     (setq mode-line-format (list "%_"))))

;; (use-package doom-modeline
;;   :ensure t
;;   :hook (after-init . doom-modeline-mode)
;;   :custom
;;   (doom-modeline-time t)
;;   (doom-modeline-time-icon t)
;;   (doom-modeline-buffer-file-name-style 'buffer-name)
;;   (doom-modeline-height 24)
;;   (doom-modeline-buffer-encoding nil)
;;   (doom-modeline-env-version t)
;;   (doom-modeline-env-setup-rust nil)
;;   :config
;;   (setq display-time-24hr-format nil)
;;   (display-time-mode 1))
;;   ;; (set-face-attribute 'mode-line nil :height 180)
;;   ;; (set-face-attribute 'mode-line-inactive nil :height 180))

(setq mode-line-misc-info
      (assq-delete-all 'eglot--managed-mode 
                       (copy-sequence mode-line-misc-info)))

(use-package maple-modeline
  :ensure t
  :straight (:host github :repo "honmaple/emacs-maple-modeline")
  :hook (after-init . maple-modeline-mode)
  :config
  (setq maple-modeline-separator 'nil)
  (setq maple-modeline-height 25)
  (setq maple-modeline-icon t)
  
  (defun maple-modeline-to-header-line ()
    (setq-default tab-line-format mode-line-format)
    (setq-default mode-line-format nil))

  (add-hook 'maple-modeline-mode-hook #'maple-modeline-to-header-line)

  (maple-modeline-define-segment my-modeline-time
    :format (propertize (downcase (format-time-string " %I:%M %p "))
                        'face 'bold))

  (maple-modeline-define my-custom-style
    :left ((evil :left (bar :left ""))
           macro
           buffer-info
           flycheck
           version-control
           remote-host
           region)
    :right (narrow
            python
            my-modeline-time
            process
            count
            position))

  (setq maple-modeline-style 'my-custom-style)

  :custom-face
  (header-line ((t (:inherit mode-line :box nil))))
  (mode-line ((t (:box nil))))
  (mode-line-inactive ((t (:box nil)))))

;; (use-package punch-line
;;   :ensure t
;;   :straight (:host github :repo "konrad1977/punch-line")
;;   :config
;;   (setq punch-line-left-separator "  "
;;         punch-line-right-separator "  "
;; 		punch-show-git-info nil
;; 		punch-show-buffer-position t
;;         punch-line-music-max-length 80
;; 		punch-line-modal-divider-style 'block
;; 		punch-line-section-backgrounds 'auto
;; 		punch-show-weather-info t
;; 		punch-weather-longitude "10.41"
;; 		punch-weather-latitude "53.25"
;; 		punch-cpu-usage t
;; 		punch-show-processes-info t)
;;   (punch-line-mode 1)
;;   (setq-default header-line-format mode-line-format)
;;   (setq-default mode-line-format nil))

(use-package adaptive-wrap
  :ensure t
  :hook ((text-mode . adaptive-wrap-prefix-mode))
  :config
  (add-hook 'org-mode-hook 
			(lambda () 
			  (when (bound-and-true-p adaptive-wrap-prefix-mode)
				(adaptive-wrap-prefix-mode -1)))))

(setq package-gnupghome-dir "~/.gnupg")

(blink-cursor-mode 0)
(setq-default cursor-type 'box)

(defvar cashmere/font-height 180)

(set-face-attribute 'default nil :family "MonoLisa Nerd Font" :weight 'medium :height cashmere/font-height)
(set-face-attribute 'fixed-pitch nil :family "RobotoMono Nerd Font" :weight 'regular)
(set-face-attribute 'variable-pitch nil :family "Poppins" :weight 'regular :height 1.1)

(use-package mixed-pitch
  :ensure t
  :defer t
  :hook ((org-mode   . mixed-pitch-mode)
         (LaTeX-mode . mixed-pitch-mode)))

;; (use-package catppuccin-theme
;;   :ensure t
;;   :straight t
;;   :config
;;   (setq catppuccin-flavor 'mocha)

;;   (load-theme 'catppuccin :no-confirm)

;;   (custom-set-faces
;;    `(diff-hl-change ((t (:background unspecified :foreground ,(catppuccin-get-color 'blue))))))

;;   (custom-set-faces
;;    `(diff-hl-delete ((t (:background unspecified :foreground ,(catppuccin-get-color 'red))))))

;;   (custom-set-faces
;;    `(diff-hl-insert ((t (:background unspecified :foreground ,(catppuccin-get-color 'green)))))))

;; (use-package modus-catppuccin
;;   :ensure t
;;   :straight (:type git
;;              :repo "https://gitlab.com/magus/modus-catppuccin"
;;              :branch "main")
;;   :custom
;;   (catppuccin-mocha-palette-overrides
;;    '((base "#232136")
;;      (mantle "#2d2a45")
;;      (crust "#373354")
;;      (surface0 "#373354")
;;      (surface1 "#47407d")
;;      (surface2 "#6e6a86")
;;      (overlay0 "#6e6a86")
;;      (overlay1 "#6e6a86")
;;      (overlay2 "#6e6a86")
;;      (subtext0 "#e0def4")
;;      (subtext1 "#cdcbe0")
;;      (text "#e2e0f7")
;;      (rosewater "#eb98c3")
;;      (flamingo "#ea9a97")
;;      (pink "#eb98c3")
;;      (mauve "#c4a7e7")
;;      (red "#eb6f92")
;;      (maroon "#eb6f92")
;;      (peach "#ea9a97")
;;      (yellow "#f6c177")
;;      (green "#a3be8c")
;;      (teal "#9ccfd8")
;;      (sky "#9ccfd8")
;;      (sapphire "#9ccfd8")
;;      (blue "#569fba")
;;      (lavender "#c4a7e7")))
;;   (catppuccin-latte-palette-overrides
;;    '((base "#f6f2ee")
;;      (mantle "#e4dcd4")
;;      (crust "#dbd1dd")
;;      (surface0 "#d3c7bb")
;;      (surface1 "#c4b8ac")
;;      (surface2 "#b5a99d")
;;      (overlay0 "#9ca0b0")
;;      (overlay1 "#8c8fa1")
;;      (overlay2 "#7c7f93")
;;      (subtext0 "#6c6f85")
;;      (subtext1 "#5c5f77")
;;      (text "#3d2b5a")
;;      (rosewater "#955f61")
;;      (flamingo "#a5222f")
;;      (pink "#a440b5")
;;      (mauve "#6e33ce")
;;      (red "#a5222f")
;;      (maroon "#824d5b")
;;      (peach "#955f61")
;;      (yellow "#ac5402")
;;      (green "#396847")
;;      (teal "#287980")
;;      (sky "#2d8a93")
;;      (sapphire "#2d8a93")
;;      (blue "#2848a9")
;;      (lavender "#6e33ce")))
;;   :config
;;   (load-theme 'catppuccin-latte :no-confirm))

;; (use-package modus-themes
;;   :ensure t
;;   :demand t
;;   :custom
;;   ;; Optional: Schriften schöner machen
;;   (modus-themes-italic-constructs t)
;;   (modus-themes-bold-constructs t)
;;   (modus-themes-prompts '(bold intense))
  
;;   ;; Hier injizieren wir DUSKFOX Farben in Modus Vivendi
;;   (modus-themes-common-palette-overrides
;;    '(
;;      ;; --- Basis Farben (Duskfox) ---
;;      (bg-main     "#232136")
;;      (fg-main     "#e0def4")
;;      (bg-dim      "#2d2a45") ; Etwas heller als Main
;;      (fg-dim      "#9090c0") ; Abgedunkelter Text
;;      (bg-active   "#393552") ; Aktive Zeile/Elemente

;;      ;; --- Akzente (Duskfox) ---
;;      (red         "#eb6f92")
;;      (green       "#a3be8c")
;;      (yellow      "#f6c177")
;;      (blue        "#569fba")
;;      (magenta     "#c4a7e7")
;;      (cyan        "#9ccfd8")
     
;;      ;; --- Fein-Tuning (Mappings) ---
;;      ;; Damit es nicht "arsch" aussieht, mappen wir wichtige Elemente neu:
     
;;      (border        "#47407d")
;;      (cursor        magenta)
     
;;      ;; Modeline (Statusleiste)
;;      (bg-mode-line-active   "#47407d")
;;      (fg-mode-line-active   "#e0def4")
;;      (bg-mode-line-inactive "#232136")
;;      (fg-mode-line-inactive "#6e6a86")

;;      ;; Syntax Highlighting Anpassungen
;;      (keyword       magenta)   ; Keywords in Duskfox-Pink/Lila
;;      (builtin       blue)      ; Builtins in Blau
;;      (type          cyan)      ; Typen in Cyan
;;      (string        green)     ; Strings in Grün
;;      (constant      red)       ; Konstanten in Rot
;;      (fnname        blue)      ; Funktionsnamen
;;      (variable      cyan)      ; Variablen

;;      ;; UI Elemente
;;      (bg-region     "#393552") ; Selection Background
;;      (fg-region     unspecified)
;;      (bg-paren-match "#47407d")
;;      (bg-hl-line    "#2d2a45")
     
;;      ;; Line Numbers
;;      (bg-line-number-inactive "#232136")
;;      (fg-line-number-inactive "#6e6a86")
;;      (bg-line-number-active   "#2d2a45")
;;      (fg-line-number-active   "#e0def4")
;;      ))
;;   :config
;;   ;; Lade das Basis-Theme (vivendi = dunkel)
;;   (load-theme 'modus-vivendi :no-confirm))

;; (use-package ef-themes
;;   :ensure t
;;   :demand t
;;   :init
;;   (ef-themes-take-over-modus-themes-mode 1)
  
;;   :custom
;;   (modus-themes-italic-constructs t)
;;   (modus-themes-bold-constructs t)
;;   (modus-themes-prompts '(bold intense))
  
;;   (ef-light-palette-overrides
;;    '(
;;      (bg-main     "#efefef")
;;      (fg-main     "#313145")
;;      (bg-dim      "#bebed2")
;;      (fg-dim      "#7c7c98")
;;      (bg-alt      "#9e9eaf")
;;      (fg-alt      "#505063")
;;      (bg-active   "#22223a")
;;      (bg-inactive "#efefef")

;;      (red         "#f43979")
;;      (red-warmer  "#ff669b")
;;      (red-cooler  "#d22a8b")
;;      (red-faint   "#f43979")
     
;;      (green       "#0073a8")
;;      (green-warmer "#0073a8")
;;      (green-cooler "#0073a8")
;;      (green-faint  "#0073a8")
     
;;      (yellow      "#ff669b")
;;      (yellow-warmer "#f43979")
;;      (yellow-cooler "#d22a8b")
;;      (yellow-faint  "#ff669b")
     
;;      (blue        "#2155d6")
;;      (blue-warmer "#0073a8")
;;      (blue-cooler "#2155d6")
;;      (blue-faint  "#2155d6")
     
;;      (magenta     "#6916b6")
;;      (magenta-warmer "#8d17a5")
;;      (magenta-cooler "#471397")
;;      (magenta-faint  "#6916b6")
     
;;      (cyan        "#0073a8")
;;      (cyan-warmer "#2155d6")
;;      (cyan-cooler "#2155d6")
;;      (cyan-faint  "#0073a8")

;;      (bg-red-intense "#ff669b")
;;      (bg-green-intense "#0073a8")
;;      (bg-yellow-intense "#f43979")
;;      (bg-blue-intense "#2155d6")
;;      (bg-magenta-intense "#8d17a5")
;;      (bg-cyan-intense "#0073a8")

;;      (bg-red-subtle "#bebed2")
;;      (bg-green-subtle "#bebed2")
;;      (bg-yellow-subtle "#bebed2")
;;      (bg-blue-subtle "#bebed2")
;;      (bg-magenta-subtle "#bebed2")
;;      (bg-cyan-subtle "#bebed2")

;;      (bg-added "#bebed2")
;;      (bg-added-faint "#efefef")
;;      (bg-added-refine "#9e9eaf")
;;      (fg-added "#0073a8")
     
;;      (bg-changed "#bebed2")
;;      (bg-changed-faint "#efefef")
;;      (bg-changed-refine "#9e9eaf")
;;      (fg-changed "#f43979")
     
;;      (bg-removed "#bebed2")
;;      (bg-removed-faint "#efefef")
;;      (bg-removed-refine "#9e9eaf")
;;      (fg-removed "#d22a8b")

;;      (bg-mode-line "#9e9eaf")
;;      (fg-mode-line "#313145")
;;      (bg-mode-line-active "#9e9eaf")
;;      (fg-mode-line-active "#313145")
;;      (bg-mode-line-inactive "#efefef")
;;      (fg-mode-line-inactive "#7c7c98")

;;      (border        "#7c7c98")
;;      (cursor        "#471397")
     
;;      (bg-region     "#bebed2")
;;      (fg-region     unspecified)
;;      (bg-paren-match "#9e9eaf")
;;      (bg-hl-line    "#bebed2")
     
;;      (bg-line-number-inactive "#efefef")
;;      (fg-line-number-inactive "#7c7c98")
;;      (bg-line-number-active   "#bebed2")
;;      (fg-line-number-active   "#313145")

;;      (builtin       blue)
;;      (comment       yellow-faint)
;;      (constant      red)
;;      (fnname        blue)
;;      (keyword       magenta)
;;      (string        green)
;;      (type          cyan)
;;      (variable      blue-warmer)

;;      (err red-warmer)
;;      (warning yellow-warmer)
;;      (info green)
     
;;      (link blue-warmer)
;;      (link-alt magenta)
;;      (name magenta-cooler)
;;      (keybind blue-cooler)
;;      (identifier magenta-faint)
;;      (prompt green-cooler)

;;      (date-common cyan-cooler)
;;      (date-deadline red)
;;      (date-event fg-alt)
;;      (date-holiday magenta-warmer)
;;      (date-scheduled yellow)
;;      (date-weekday cyan)
;;      (date-weekend red-faint)

;;      (mail-cite-0 blue-warmer)
;;      (mail-cite-1 magenta)
;;      (mail-cite-2 cyan-cooler)
;;      (mail-cite-3 yellow-cooler)
;;      (mail-recipient magenta-cooler)
;;      (mail-subject blue-cooler)

;;      (prose-code magenta-warmer)
;;      (prose-done green)
;;      (prose-macro green-cooler)
;;      (prose-tag green-faint)
;;      (prose-todo red-warmer)
;;      (prose-verbatim blue-warmer)
;;      ))
  
;;   :config
;;   (load-theme 'ef-light :no-confirm))

;; (use-package kanagawa-themes
;;   :ensure t
;;   :config
;;   (setq kanagawa-themes-org-height nil)
;;   (setq kanagawa-themes-org-highlight t)
;;   (load-theme 'kanagawa-lotus t))

;; (use-package base16-theme
;;   :ensure t
;;   :demand t
;;   :config
;;   (setq base16-distinct-fringe-background t)
;;   (setq base16-highlight-mode-line t)
  
;;   (deftheme base24-duskfox)
;;   (setq base24-duskfox-colors
;;         (list :base00 "#232136"
;;               :base01 "#2d2a45"
;;               :base02 "#373354"
;;               :base03 "#47407d"
;;               :base04 "#6e6a86"
;;               :base05 "#e0def4"
;;               :base06 "#cdcbe0"
;;               :base07 "#e2e0f7"
;;               :base08 "#eb6f92"
;;               :base09 "#ea9a97"
;;               :base0A "#f6c177"
;;               :base0B "#a3be8c"
;;               :base0C "#9ccfd8"
;;               :base0D "#569fba"
;;               :base0E "#c4a7e7"
;;               :base0F "#eb98c3"
;;               :base10 "#47407d"
;;               :base11 "#eb6f92"
;;               :base12 "#a3be8c"
;;               :base13 "#f6c177"
;;               :base14 "#569fba"
;;               :base15 "#c4a7e7"
;;               :base16 "#9ccfd8"
;;               :base17 "#e0def4"))
  
;;   (base16-theme-define 'base24-duskfox base24-duskfox-colors)
  
;;   (deftheme base24-nightfox)
;;   (setq base24-nightfox-colors
;;         (list :base00 "#192330"
;;               :base01 "#212e3f"
;;               :base02 "#29394f"
;;               :base03 "#575860"
;;               :base04 "#71839b"
;;               :base05 "#cdcecf"
;;               :base06 "#aeafb0"
;;               :base07 "#e4e4e5"
;;               :base08 "#c94f6d"
;;               :base09 "#f4a261"
;;               :base0A "#dbc074"
;;               :base0B "#81b29a"
;;               :base0C "#63cdcf"
;;               :base0D "#719cd6"
;;               :base0E "#9d79d6"
;;               :base0F "#d67ad2"
;;               :base10 "#575860"
;;               :base11 "#c94f6d"
;;               :base12 "#81b29a"
;;               :base13 "#dbc074"
;;               :base14 "#719cd6"
;;               :base15 "#9d79d6"
;;               :base16 "#63cdcf"
;;               :base17 "#cdcecf"))
  
;;   (base16-theme-define 'base24-nightfox base24-nightfox-colors)
;;   (enable-theme 'base24-nightfox))

(use-package dirvish
  :straight t
  :init
  (dirvish-override-dired-mode)

  :custom
  (dirvish-quick-access-entries
   '(("h" "~/" "Home")
     ("d" "~/Downloads/" "Downloads")
     ("p" "~/projects/" "Projects")))

  (dirvish-reuse-session 'open)
  (dirvish-attributes '(file-size))
  (dirvish-mode-line-format
   '(:left (sort file-time symlink) :right (omit yank index)))

  (dirvish-hide-details '(dirvish dirvish-side))
  (dirvish-hide-cursor '(dirvish dirvish-side))

  (dired-listing-switches
   "-l --almost-all --human-readable --group-directories-first --no-group")

  :config
  (setq dired-dwim-target t)
  (setq delete-by-moving-to-trash t)
  (setq dired-mouse-drag-files t))

(use-package tramp-hlo
    :ensure t
	:straight (:host github :repo "jsadusk/tramp-hlo")
    :config
    (tramp-hlo-setup))

(add-to-list 'load-path "/home/cashmere/.emacs.d/tramp-rpc/lisp")
(require 'tramp-rpc)

(use-package zoxide
  :ensure t)

(use-package dired-rsync 
  :ensure t)

(use-package dired-rsync-transient
  :ensure t
  :after (dired-rsync transient))

(setq-default olivetti-body-width 100)
(define-globalized-minor-mode my/global-olivetti-mode olivetti-mode
 (lambda () (olivetti-mode 1)))
(my/centered-cursor)
;; (my/global-olivetti-mode)

(use-package org-modern-indent
  :straight (:host github :repo "jdtsmith/org-modern-indent")
  :hook (org-mode . org-modern-indent-mode))

(setq ibuffer-never-show-predicates
      '(;; System buffers
        ;; "^\\*Messages\\*$"
        "^\\*scratch\\*$"
        "^\\*Completions\\*$"
        "^\\*Help\\*$"
        "^\\*Apropos\\*$"
        "^\\*info\\*$"
        "^\\*Async-native-compile-log\\*$"

        ;; LSP Buffers
        "^\\*lsp-log\\*$"
        "^\\*clojure-lsp\\*$"
        "^\\*clojure-lsp::stderr\\*$"
        "^\\*ts-ls\\*$"
        "^\\*ts-ls::stderr\\*$"))

(use-package projectile
  :ensure t
  :demand t
  :config
  (projectile-mode +1)
  (setq projectile-completion-system 'default
        projectile-enable-caching t
        projectile-indexing-method 'alien
        projectile-sort-order 'recentf
        projectile-require-project-root nil
        projectile-globally-ignored-buffers '("\\*magit.*")))

(use-package consult-projectile
  :ensure t
  :straight t
  :after (consult projectile)
  :defer t
  :config
  (setq consult-project-function #'projectile-project-root))

(use-package hidepw
  :ensure t
  :custom
  (hidepw-hide-first-line t)
  :hook (pass-view-mode . hidepw-mode))

(use-package pass
  :ensure t
  :defer t
  :mode ("\\.gpg\\'" . pass-mode)
  :config
  (add-to-list 'display-buffer-alist
               '("\\*Pass.*\\*"
                 (display-buffer-full-frame))))

(use-package auth-source
  :straight nil
  :ensure nil                                  ;; This is built-in, no need to fetch it.
  :defer t
  :config
  ;; Enable password-store integration for secure API key retrieval.
  (when (require 'auth-source-pass nil t)
    (auth-source-pass-enable)
    ;; Add password-store explicitly to auth-sources for compatibility.
    (add-to-list 'auth-sources 'password-store)
    ;; Optional: Cache expires after 5 minutes for security.
    (setq auth-source-cache-expiry 300)))

(use-package zoom
  :ensure t)
(custom-set-variables
 '(zoom-size '(0.382 . 0.618)))

(use-package golden-ratio
  :ensure t
  :config
  ;; (setq golden-ratio-auto-scale t)
  ;; (golden-ratio-mode 1)
)

(use-package pdf-tools
  :straight (:type built-in)
  :magic ("%PDF" . pdf-view-mode)
  :config
  (pdf-loader-install)
  :hook (pdf-view-mode . (lambda () (display-line-numbers-mode -1))))

(defun my/format-buffer ()
  (interactive)
  (cond
   ((eq major-mode 'rust-mode) (eglot-format-buffer))
   ((eq major-mode 'nix-mode) (eglot-format-buffer))  
   ((or (eq major-mode 'python-mode) 
        (eq major-mode 'python-ts-mode)) (ruff-format-buffer))
   ((eq major-mode 'c-mode) (eglot-format-buffer))
   ((bound-and-func-p eglot--managed-mode) (eglot-format-buffer))
   (t (message "No formatter for %s" major-mode))))

(my-leader
  "SPC" '((lambda () 
            (interactive)
            (if (projectile-project-p)
                (consult-projectile-find-file)
              (projectile-switch-project)))
          :wk "find file/switch project")
  "sp" '(consult-projectile :wk "search project")
  "ss" '(consult-line :wk "search project")
  "/" '(consult-ripgrep :wk "search project")
  "." '(find-file :wk "find file")
  "," '(consult-buffer :wk "switch buffer")
  ":" (lambda () (interactive) (execute-extended-command nil))

  "d" '(:ignore t :wk "denote")
  "dd" '(denote-menu-list-notes t :wk "List all notes")
  "dg" '(consult-denote-grep t :wk "Search")
  "dn" '(denote t :wk "Create a new note")
  "dr" '(denote-rename-file t :wk "Rename Note")
  "dtl" '(tmr-list-timers :wk "list timer")
  "dtt" '(tmr :wk "set timer")

  "f" '(:ignore t :wk "files")
  "fd" '(dired :wk "dired")
  "fD" '(dired-jump :wk "dired jump")
  "fr" '(consult-recent-file :wk "recent files")
  "ff" '(find-file :wk "find file")
  "fs" '(save-buffer :wk "save file")

  "b" '(:ignore t :wk "buffer/bookmarks")
  "bb" '(consult-bookmark :wk "display current bookmarks")
  "bi" '(ibuffer :wk "ibuffer")
  "bd" '(bookmark-delete :wk "delete bookmark")
  "bk" '(kill-current-buffer :wk "kill buffer")
  "bs" '(bookmark-set :wk "save bookmark")

  "p" '(:ignore t :wk "project")
  "pp" '(projectile-switch-project :wk "switch project")
  "pf" '(projectile-find-file :wk "find file")
  "ps" '(consult-ripgrep :wk "search")
  "pb" '(consult-projectile-buffer :wk "buffers") 
  "pk" '(projectile-kill-buffers :wk "kill buffers") 
  "pd" '(projectile-remove-known-project :wk "delete project")
  "pr" '(projectile-recentf :wk "recent files")
  "pa" '(projectile-add-known-project :wk "add project")
  "pi" '(projectile-invalidate-cache :wk "invalidate cache")

  "g" '(:ignore t :wk "git")
  "gc" '(magit-clone :wk "clone")
  "gg" '(magit-status :wk "status")
  "gl" '(magit-log-current :wk "log")
  "gi" '(magit-init :wk "init")
  "gd" '(xref-find-definitions :wk "go to definition") 
  "gD" '((lambda () (interactive) 
           (let ((current-prefix-arg 4))
             (call-interactively #'xref-find-definitions)))
         :wk "definition other window")
  "gI" '((lambda () (interactive) 
           (let ((current-prefix-arg 4))
             (call-interactively #'eglot-find-implementation)))
         :wk "implementation other window")
  "gt" '(eglot-find-typeDefinition :wk "go to type definition")
  "gr" '(xref-find-references :wk "find references")
  "gs" '(magit-file-stage :wk "stage file")
  "gb" '(vc-annotate :wk "blame")

  "o" '(:ignore t :wk "open")

  "h" '(:ignore t :wk "help")
  "hm" '(describe-mode :wk "mode")
  "hf" '(describe-function :wk "function")
  "hv" '(describe-variable :wk "variable")
  "hk" '(describe-key :wk "key")
  "ht" '(consult-theme :wk "load theme")

  "w w" '(evil-window-next :wk "Close window")
  "w c" '(evil-window-delete :wk "Close window")
  "w n" '(evil-window-new :wk "New window")
  "w s" '(evil-window-split :wk "Horizontal split window")
  "w v" '(evil-window-vsplit :wk "Vertical split window")
  "w h" '(evil-window-left :wk "Window left")
  "w j" '(evil-window-down :wk "Window down")
  "w k" '(evil-window-up :wk "Window up")
  "w l" '(evil-window-right :wk "Window right")
  "w w" '(evil-window-next :wk "Goto next window")
  "w H" '(buf-move-left :wk "Buffer move left")
  "w J" '(buf-move-down :wk "Buffer move down")
  "w K" '(buf-move-up :wk "Buffer move up")
  "w L" '(buf-move-right :wk "Buffer move right")

  "c" '(:ignore t :wk "code")
  "ca" '(eglot-code-actions :wk "code actions")
  "cr" '(eglot-rename :wk "lsp rename")
  "cf" '(eglot-format :wk "format buffer")
  "cs" '(yas-insert-snippet :wk "snippets")
  "cl" '(flycheck-list-errors :wk "list errors")

  "q" '(:ignore t :wk "quit")
  "qq" '(save-buffers-kill-terminal :wk "quit emacs")
  "qr" '(restart-emacs :wk "restart")

  "x" '(org-capture :wk "capture")

  "a" '(embark-act :wk "embark")
  "u" '(undo-tree-visualize :wk "undo tree")
  "P" '(consult-yank-from-kill-ring :wk "paste history"))

(defun my/avy-enabled-p ()
(and (not (derived-mode-p 'magit-mode 'dired-mode 'ibuffer-mode))
(not (eq major-mode 'dirvish-mode))))

(defun my/s-key-dispatch ()
  (interactive)
  (if (derived-mode-p 'magit-mode)
      (call-interactively 'magit-stage)
    (when (my/avy-enabled-p)
      (let ((scroll-margin 0)
            (maximum-scroll-margin 0))
        (call-interactively 'flash-emacs-jump)))))

(general-def '(normal visual) 'override
  "s" 'my/s-key-dispatch)


(general-def 'normal 'override
  "K" 'my/eldoc-and-jump
  "'d" 'flycheck-next-error
  ";d" 'flycheck-previous-error
  "]c" 'diff-hl-next-hunk
  "[c" 'diff-hl-previous-hunk
  "'b" 'switch-to-next-buffer
  ";b" 'switch-to-prev-buffer
  "]t" 'tab-next
  "[t" 'tab-previous
  "P" 'consult-yank-from-kill-ring
  ;; "?" 'casual-avy-tmenu
  "gcc" (lambda ()
          (interactive)
          (unless (use-region-p)
            (comment-or-uncomment-region
             (line-beginning-position)
             (line-end-position)))))

(general-def 'visual 'override
  "gc" (lambda ()
         (interactive)
         (when (use-region-p)
           (comment-or-uncomment-region
            (region-beginning)
            (region-end)))))

(my-leader
  :keymaps 'org-mode-map
  "m" '(:ignore :wk "org")

  "mt" '(org-todo :wk "TODO")
  "ma" '(org-add-note :wk "add note")
  "mC" '(org-capture :wk "capture")

  "mc" '(:wk "set" :ignore)
  "mcd" '(org-deadline :wk "deadline")
  "mcs" '(org-schedule :wk "schedule")
  "mce" '(org-set-effort :wk "effort")
  "mcr" '(org-clock-report :wk "clock report")
  "m," '(org-priority :wk "priority")
  "mI" '(org-clock-in :wk "clock in")
  "mO" '(org-clock-out :wk "clock out")
  "l" '(:ignore :wk "link")
  "lc" '(org-cliplink :wk "cliplink")
  "li" '(org-download-clipboard :wk "image")
  "ll" '(org-insert-link :wk "link various things"))

(evil-define-key 'normal org-mode-map (kbd "RET") 'org-open-at-point)

;; jinja2-mode-map
(my-leader
  :keymaps 'jinja2-mode-map
  "m" '(:wk "insert" :ignore)
  "mv" '(jinja2-insert-var :wk "var")
  "mt" '(jinja2-insert-tag :wk "tag")
  "mc" '(jinja2-insert-comment :wk "comment")
  
  "mf" '(fill-paragraph :wk "fill paragraph"))

(my-leader
  :keymaps '(rust-mode-map rust-ts-mode-map)
  "m" '(:wk "rust mode" :ignore)
  "mr" '(rust-run :wk "run")
  "mc" '(rust-clippy :wk "clippy")
  "mC" '(rust-check :wk "check"))

(with-eval-after-load 'denote-menu
  (general-def 'normal denote-menu-mode-map
    "r" 'denote-menu-filter
    "c" 'denote-menu-clear-filters
    "e" 'denote-menu-export-to-dired
    "o" 'denote-menu-filter-out-keyword))

(with-eval-after-load 'tmr
  (general-def 'normal tmr-tabulated-mode-map
    "y" 'tmr-clone
    "c" 'tmr-cancel
    "d" 'tmr-remove
    "D" 'tmr-remove-finished
    "n" 'tmr
    "N" 'tmr-with-details
    "e" 'tmr-edit-description
    "r" 'tmr-reschedule))

(general-def 'normal dirvish-mode-map
  "?" 'dirvish-dispatch
  "q" 'dirvish-quit
  "b" 'dirvish-quick-access
  "f" 'dirvish-file-info-menu
  "p" 'dirvish-yank
  "S" 'dirvish-quicksort
  "F" 'dirvish-layout-toggle
  "z" 'zoxide-travel
  "gh" 'dirvish-subtree-up
  "gl" 'dirvish-subtree-toggle
  "h" 'dired-up-directory
  "l" 'dired-find-file
  "TAB" 'dirvish-subtree-toggle
  "[h" 'dirvish-history-go-backward
  "]h" 'dirvish-history-go-forward)

(general-def '(normal visual) dirvish-mode-map
  :prefix "y"
  "l" 'dirvish-copy-file-true-path
  "n" 'dirvish-copy-file-name
  "p" 'dirvish-copy-file-path
  "y" 'dired-do-copy)

(general-def 'normal dirvish-mode-map
  :prefix "s"
  "s" 'dirvish-symlink
  "S" 'dirvish-relative-symlink
  "h" 'dirvish-hardlink)

(my-local-leader
  "a" '(org-agenda :wk "org agenda")
  "c" '(my/centered-cursor :wk "center cursor")
  "d" '(dashboard-open :wk "dashboard")
  "f" '(dirvish :wk "file manager")
  "t" '(multi-vterm :wk "terminal")
  "z" '(golden-ratio-mode :wk "zoom/golden ratio")
  "m" '(mu4e :wk "mail")
  "p" '(pass :wk "pass")
  "o" '(my/global-olivetti-mode :wk "center buffer")
  "i" '(projectile-ibuffer :wk "ibuffer project")

  "g" '(:wk "gptel" :ignore)

  "gg" '(gptel :wk "open gptel")
  "ga" '(gptel-add :wk "add buffer to gptel")
  "gf" '(gptel-add-file :wk "add file to gptel")
  "gA" '(gptel-abort :wk "abort response")
  "gr" '(gptel-rewrite :wk "rewrite section")
  "gm" '(gptel-menu :wk "open gptel menu"))

;; (my-leader
;;   :keymaps 'override
;;   "m" '(:ignore t :wk "music/emms")
;;   "mm" '(emms-browser :wk "browser")
;;   "mp" '(emms-playlist-mode-go :wk "playlist")
;;   "ma" '(emms-add-directory-tree :wk "add directory")
;;   "mf" '(emms-play-file :wk "play file")
;;   "md" '(emms-play-directory :wk "play directory")
;;   "ms" '(emms-start :wk "start/play")
;;   "mS" '(emms-stop :wk "stop")
;;   "mn" '(emms-next :wk "next track")
;;   "mN" '(emms-previous :wk "previous track")
;;   "mP" '(emms-pause :wk "pause")
;;   "mr" '(emms-random :wk "random track")
;;   "mc" '(emms-playlist-clear :wk "clear playlist")
;;   "mC" '(emms-cache-set-from-mpd-all :wk "sync mpd cache")
;;   "mu" '(emms-player-mpd-update-all :wk "update mpd db")
;;   "mw" '(emms-playlist-save :wk "save playlist")
;;   "ml" '(emms-playlist-load :wk "load playlist"))

(global-set-key (kbd "C-=") 'text-scale-increase)
(global-set-key (kbd "C--") 'text-scale-decrease)

;; (defun my/evil-delete-to-blackhole (orig-fn beg end &optional type register &rest args)
;;   (apply orig-fn beg end type ?_ args))

;; (advice-add 'evil-delete :around 'my/evil-delete-to-blackhole)

;; (my-leader
;;   "y" '(my/yank-to-clipboard :wk "clipboard" :ignore t)
;;   "yy" '(my/yank-to-clipboard :wk "yank to clipboard")
;;   "yp" '(my/paste-from-clipboard :wk "paste from clipboard"))

;; (defun my/yank-to-clipboard ()
;;   (interactive)
;;   (if (region-active-p)
;;       (let ((select-enable-clipboard t))
;;         (kill-ring-save (region-beginning) (region-end))
;;         (message "Yanked to clipboard"))
;;     (message "No region active")))

;; (defun my/paste-from-clipboard ()
;;   (interactive)
;;   (let ((select-enable-clipboard t))
;;     (yank)))

;; (defun my/delete-to-clipboard ()
;;   (interactive)
;;   (if (region-active-p)
;;       (let ((select-enable-clipboard t))
;;         (kill-region (region-beginning) (region-end))
;;         (message "Deleted to clipboard"))
;;     (message "No region active")))

(use-package elfeed
  :ensure t
  :defer t
  :custom
  (elfeed-db-directory "~/.emacs.d/elfeed")
  :config
  (setq elfeed-search-filter "@2-weeks-ago +unread"
        elfeed-search-title-max-width 110)
  
  (add-hook 'elfeed-search-mode-hook #'elfeed-update)
  
  (setq elfeed-search-sort-function
        (lambda (a b)
          (let* ((a-date (elfeed-entry-date a))
                 (b-date (elfeed-entry-date b))
                 (a-feed (elfeed-feed-title (elfeed-entry-feed a)))
                 (b-feed (elfeed-feed-title (elfeed-entry-feed b)))
                 (a-title (elfeed-entry-title a))
                 (b-title (elfeed-entry-title b)))
            (cond
             ((> a-date b-date) t)
             ((< a-date b-date) nil)
             ((string< a-feed b-feed) t)
             ((string> a-feed b-feed) nil)
             (t (string< a-title b-title)))))))

(use-package elfeed-org
  :ensure t
  :after elfeed
  :custom
  (rmh-elfeed-org-files (list "~/org/rss.org"))
  :config
  (elfeed-org))

(defun elfeed-export-from-index-to-csv (output-file)
  (interactive "FExport CSV nach: ")
  (require 'elfeed)
  (require 'elfeed-db)
  
  (elfeed-db-load)
  
  (let ((entries (hash-table-values elfeed-db-entries)))
    (with-temp-file output-file
      (insert "id,title,link,date,feed,tags\n")
      (dolist (entry entries)
        (insert (format "\"%s\",\"%s\",\"%s\",%s,\"%s\",\"%s\"\n"
                        (elfeed-entry-id entry)
                        (replace-regexp-in-string "\"" "\"\"" (elfeed-entry-title entry))
                        (elfeed-entry-link entry)
                        (elfeed-entry-date entry)
                        (elfeed-feed-title (elfeed-entry-feed entry))
                        (mapconcat #'symbol-name (elfeed-entry-tags entry) " "))))
      (message "Export abgeschlossen: %d Einträge" (length entries)))))

(setq browse-url-browser-function 'browse-url-generic
      browse-url-generic-program "qutebrowser")

(use-package mu4e
  :straight nil
  :ensure nil
  :config
  
  (setq mu4e-mu-binary (executable-find "mu"))
  (setq mu4e-maildir "~/Mails")
  (setq mu4e-get-mail-command (concat (executable-find "mbsync") " -a"))
  (setq mu4e-update-interval 300)
  (setq mu4e-attachment-dir "~/Downloads")
  (setq mu4e-change-filenames-when-moving t)
  
  (setq mu4e-user-mail-address-list 
        '("cashmeresamurai@autistici.org"
          "cashmere@cashmere.rs"))
  
  (setq mu4e-contexts
        `(,(make-mu4e-context
            :name "autistici"
            :match-func
            (lambda (msg)
              (when msg
                (string-prefix-p "/autistici" (mu4e-message-field msg :maildir))))
            :vars '((user-mail-address . "cashmeresamurai@autistici.org")
                    (user-full-name . "cashmere")
                    (mu4e-drafts-folder . "/autistici/Drafts")
                    (mu4e-sent-folder . "/autistici/Sent")
                    (mu4e-trash-folder . "/autistici/Trash")
                    (mu4e-refile-folder . "/autistici/Archive")))
          
          ,(make-mu4e-context
            :name "cashmere"
            :match-func
            (lambda (msg)
              (when msg
                (string-prefix-p "/cashmere/cashmere" (mu4e-message-field msg :maildir))))
            :vars '((user-mail-address . "cashmere@cashmere.rs")
                    (user-full-name . "cashmere")
                    (mu4e-drafts-folder . "/cashmere/cashmere/Drafts")
                    (mu4e-sent-folder . "/cashmere/cashmere/Sent")
                    (mu4e-trash-folder . "/cashmere/cashmere/Trash")
                    (mu4e-refile-folder . "/cashmere/cashmere/Archive")))))
  
  (setq mu4e-context-policy 'pick-first)
  (setq mu4e-compose-context-policy 'ask)
  
  (setq sendmail-program (executable-find "msmtp"))
  (setq send-mail-function 'sendmail-send-it)
  (setq message-send-mail-function 'sendmail-send-it)
  (setq message-sendmail-envelope-from 'header)
  (setq message-kill-buffer-on-exit t)
  
  (defun mu4e-set-msmtp-account ()
    (if (message-mail-p)
        (save-excursion
          (let* ((from (save-restriction
                         (message-narrow-to-headers)
                         (message-fetch-field "from")))
                 (account
                  (cond
                   ((string-match "cashmeresamurai@autistici.org" from) "autistici")
                   ((string-match "cashmere@cashmere.rs" from) "cashmere/cashmere"))))
            (setq message-sendmail-extra-arguments (list '"-a" account))))))
  
  (add-hook 'message-send-mail-hook 'mu4e-set-msmtp-account))

(use-package emacs-everywhere
  :ensure t)

(use-package burly
  :ensure t)

;; (profiler-start 'cpu)
;; (org-agenda nil "c")
;; (profiler-report)
;; (profiler-stop)

(provide 'init)
