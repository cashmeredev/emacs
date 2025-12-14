;;; config.el --- Emacs-Kick --- A feature rich Emacs config for (neo)vi(m)mers -*- lexical-binding: t; -*-
;; (setenv "LSP_USE_PLISTS" "true")
;; (setq debug-on-error '(wrong-type-argument))
;; (setq gc-cons-threshold #x40000000)
;; (setq gc-cons-threshold 50000000)
;; (setenv "LSP_USE_PLISTS" "true")
;; (setq lsp-use-plists t)
(setq display-graphic-p t)
(setq-default mode-line-format nil)
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
  :custom                                         ;; Set custom variables to configure Emacs behavior.
  (setq modify-coding-system-alist 'file "" 'utf-8)
  (column-number-mode t)                          ;; Display the column number in the mode line.
  (auto-save-default nil)                         ;; Disable automatic saving of buffers.
  (create-lockfiles nil)                          ;; Prevent the creation of lock files when editing.
  (delete-by-moving-to-trash t)                   ;; Move deleted files to the trash instead of permanently deleting them.
  (delete-selection-mode 1)                       ;; Enable replacing selected text with typed text.
  (display-line-numbers-type 'relative)           ;; Use relative line numbering in programming modes.
  (global-auto-revert-non-file-buffers t)         ;; Automatically refresh non-file buffers.
  (history-length 25)                             ;; Set the length of the command history.
  (inhibit-startup-message t)                     ;; Disable the startup message when Emacs launches.
  (initial-scratch-message "")                    ;; Clear the initial message in the *scratch* buffer.
  (ispell-dictionary "en_US")                     ;; Set the default dictionary for spell checking.
  (make-backup-files nil)                         ;; Disable creation of backup files.
  ;; (pixel-scroll-precision-mode t)                 ;; Enable precise pixel scrolling.
  (pixel-scroll-precision-use-momentum nil)       ;; Disable momentum scrolling for pixel precision.
  (ring-bell-function 'ignore)                    ;; Disable the audible bell.
  (split-width-threshold 300)                     ;; Prevent automatic window splitting if the window width exceeds 300 pixels.
  (switch-to-buffer-obey-display-actions t)       ;; Make buffer switching respect display actions.
  (tab-always-indent 'complete)                   ;; Make the TAB key complete text instead of just indenting.
  (tab-width 4)                                   ;; Set the tab width to 4 spaces.
  (treesit-font-lock-level 4)                     ;; Use advanced font locking for Treesit mode.
  (truncate-lines t)                              ;; Enable line truncation to avoid wrapping long lines.
  (use-dialog-box nil)                            ;; Disable dialog boxes in favor of minibuffer prompts.
  (use-short-answers t)                           ;; Use short answers in prompts for quicker responses (y instead of yes)
  (warning-minimum-level :emergency)              ;; Set the minimum level of warnings to display.

  :hook ;; Add hooks to enable specific features in certain modes.
  (prog-mode . display-line-numbers-mode)
  (org-mode . display-line-numbers-mode)

  :config
  (add-to-list 'custom-theme-load-path user-emacs-directory)
  ;; (load-theme 'rose-pine t)

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
  ;; (set-face-attribute 'default nil :family "Maple Mono NF"  :height 150)
  ;; (when (eq system-type 'darwin)       ;; Check if the system is macOS.
  ;; (setq mac-command-modifier 'meta)  ;; Set the Command key to act as the Meta key.
  ;; (set-face-attribute 'default nil :family "Fragment Mono" :height 130))

  ;; Save manual customizations to a separate file instead of cluttering `init.el'.
  ;; You can M-x customize, M-x customize-group, or M-x customize-themes, etc.
  ;; The saves you do manually using the Emacs interface would overwrite this file.
  ;; The following makes sure those customizations are in a separate file.
  (setq custom-file (locate-user-emacs-file "custom-vars.el")) ;; Specify the custom file path.
  (load custom-file 'noerror 'nomessage)                       ;; Load the custom file quietly, ignoring errors.

  ;; Makes Emacs vertical divisor the symbol │ instead of |.
  (set-display-table-slot standard-display-table 'vertical-border (make-glyph-code ?│))

  :init                        ;; Initialization settings that apply before the package is loaded.
  (tool-bar-mode -1)

  (menu-bar-mode -1)
  (scroll-bar-mode -1)
  (add-to-list 'default-frame-alist '(vertical-scroll-bars . nil))
  (add-to-list 'default-frame-alist '(horizontal-scroll-bars . nil))
  (set-frame-parameter (selected-frame) 'alpha-background 80)
  (add-to-list 'default-frame-alist '(alpha-background . 80))
  (global-hl-line-mode -1)     ;; Disable highlight of the current line
  (global-auto-revert-mode 1)  ;; Enable global auto-revert mode to keep buffers up to date with their corresponding files.
  (indent-tabs-mode -1)        ;; Disable the use of tabs for indentation (use spaces instead).
  (recentf-mode 1)             ;; Enable tracking of recently opened files.
  (savehist-mode 1)            ;; Enable saving of command history.
  (save-place-mode 1)          ;; Enable saving the place in files for easier return.
  (winner-mode 1)              ;; Enable winner mode to easily undo window configuration changes.
  (xterm-mouse-mode 1)         ;; Enable mouse support in terminal mode.
  (file-name-shadow-mode 1)    ;; Enable shadowing of filenames for clarity.

  ;;oding system for files to UTF-8.
  (modify-coding-system-alist 'file "" 'utf-8)

  ;; Add a hook to run code after Emacs has fully initialized.
  (add-hook 'after-init-hook
			(lambda ()
			  (message "Emacs has fully loaded. This code runs after startup.")

			  ;; Insert a welcome message in the *scratch* buffer displaying loading time and activated packages.
			  (with-current-buffer (get-buffer-create "*scratch*")
				(insert (format
						 "  ;;    Welcome to Emacs!
  ;;
  ;;    Loading time : %s
  ;;    Packages     : %s
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
  :config
  (require 'mailcap)
  
  ;; WICHTIG: Zwingt Emacs, Ihre Definitionen VOR den System-Einstellungen zu nutzen
  (setq mailcap-prefer-mailcap-viewers nil)

  ;; Kitty als Viewer für Bildformate hinzufügen
  ;; mailcap-add fügt den Eintrag ganz oben in die Liste ein
  (mailcap-add "image/png" "kitty --hold kitty +kitten icat %s")
  (mailcap-add "image/jpeg" "kitty --hold kitty +kitten icat %s")
  (mailcap-add "image/jpg" "kitty --hold kitty +kitten icat %s")
  (mailcap-add "image/gif" "kitty --hold kitty +kitten icat %s")

  ;; Tastenkombination 'E' für explizites Öffnen via Mailcap
  (define-key dired-mode-map (kbd "E") 
    (lambda () 
      (interactive) 
      (mailcap-view-file (dired-get-filename))))  (when (eq system-type 'darwin)
    (let ((gls (executable-find "gls")))
      (when gls
        (setq insert-directory-program gls)))))

(setq mailcap-user-mime-data
      '(("image/png" (viewer . "kitty --hold kitty +kitten icat %s"))
        ("image/jpeg" (viewer . "kitty --hold kitty +kitten icat %s"))))

(use-package erc
  :straight nil
  :defer t ;; Load ERC when needed rather than at startup. (Load it with `M-x erc RET')
  :custom
  (erc-join-buffer 'window)                                        ;; Open a new window for joining channels.
  (erc-hide-list '("JOIN" "PART" "QUIT"))                          ;; Hide messages for joins, parts, and quits to reduce clutter.
  (erc-timestamp-format "[%H:%M]")                                 ;; Format for timestamps in messages.
  (erc-autojoin-channels-alist '((".*\\.libera\\.chat" "#emacs"))));; Automatically join the #emacs channel on Libera.Chat.

;; (use-package welcome-dashboard
;;   :straight (
;;   :host github
;;   :repo "konrad1977/welcome-dashboard"
;;   :files ("welcome-dashboard.el")
;;   :ensure t
;;   :after nerd-icons
;;   )
;;   :demand
;;   :init
;;   (setq welcome-dashboard-use-nerd-icons t
;;         welcome-dashboard-longitude 6.0440
;;         welcome-dashboard-latitude 53.0825
;;         welcome-dashboard-path-max-length 75
;;         welcome-dashboard-show-file-path t 
;;         welcome-dashboard-use-fahrenheit nil
;;         welcome-dashboard-min-left-padding 10
;;         welcome-dashboard-image-file "~/path/yourimage.png"
;;         welcome-dashboard-image-width 200
;;         welcome-dashboard-max-number-of-todos 5
;;         welcome-dashboard-image-height 169
;;         welcome-dashboard-title (concat "Welcome " user-full-name))
;;   :config
;; (welcome-dashboard-create-welcome-hook)

;; (setq initial-buffer-choice 
;;       (lambda () (get-buffer-create "*welcome*"))))

(use-package grid
  :straight (grid :type git 
                  :host github 
                  :repo "ichernyshovvv/grid.el"))

(use-package enlight
  :custom
  (enlight-content
   (concat
    (propertize "MENU" 'face 'highlight)
    "\n"
    (enlight-menu
     '(("Org Mode"
		("Org-Agenda (current day)" (org-agenda nil "a") "a"))
       ("Downloads"
		("Transmission" transmission "t")
		("Downloads folder" (dired "~/Downloads") "a"))
       ("Other"
		("Projects" project-switch-project "p")))))))

(setopt initial-buffer-choice #'enlight)

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
  :defer t
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
         :models '("deepseek/deepseek-v3.2:online"
                   "minimax/minimax-m2:online")))

  (setq gptel-backend my/openrouter-backend)
  (setq gptel-log-level 'debug)
  (setq gptel-include-reasoning nil)
  (setq gptel-default-mode 'markdown-mode)
  (setq gptel-backends (list my/openrouter-backend)))

(use-package eldoc
  :straight nil
  :ensure t
  :config
  (setq eldoc-idle-delay 0)                  ;; Automatically fetch doc help
  (setq eldoc-echo-area-use-multiline-p nil) ;; We use the "K" floating help instead
                                             ;; set to t if you want docs on the echo area
  (setq eldoc-echo-area-display-truncation-message nil)
  :init
  (global-eldoc-mode))

(use-package eldoc-box
  :ensure t
  :config
  :defer t)

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

;; (use-package flyover
;;   :ensure t
;;   :hook (flycheck-mode-hook . flyover-mode))

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

(use-package org-workbench
  :straight (:host github :repo "yibie/org-workbench")
  :after  denote
  :config
  (org-workbench-setup))

(use-package org-appear
  :commands (org-appear-mode)
  :hook     (org-mode . org-appear-mode)
  :config
  (setq org-hide-emphasis-markers t)  ;; Must be activated for org-appear to work
  (setq org-appear-autoemphasis   t   ;; Show bold, italics, verbatim, etc.
        org-appear-autolinks      t   ;; Show links
        org-appear-autosubmarkers t)) ;; Show sub- and superscripts

(setq org-agenda-inhibit-startup t
      org-agenda-use-tag-inheritance nil
      org-agenda-dim-blocked-tasks nil
      org-startup-indented nil
      org-startup-folded 'overview)

(use-package org-modern
  :ensure t)

(with-eval-after-load 'org (global-org-modern-mode))

(setq org-modern-star 'fold)
(setq org-modern-fold-stars '(("◉" . "○")))
(setq org-modern-star 'replace)
(setq org-modern-replace-stars "◉○◉○◉")

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
    ;;  (nushell . t)
     (shell . t)
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
    (insert (format "* %s\nDEADLINE: <%s>\n\n" context deadline))
    (current-buffer)))

(defun my/org-capture-denote-scheduled ()
  (let* ((context (read-string "Scheduled task: "))
         (schedule (org-read-date t nil nil "Schedule: "))
         (file-name (denote nil '("task"))))
    (find-file file-name)
    (goto-char (point-min))
    (forward-line 4)
    (insert (format "* %s\nSCHEDULED: <%s>\n\n" context schedule))
    (current-buffer)))

(defun my/org-capture-denote-task ()
  (let* ((context (read-string "Task: "))
         (todo-state (completing-read "TODO state: "
                                      '("ACTIVE" "NEXT" "TODO" "WAIT" "PLAN" "FUN")))
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

(setq org-agenda-span 'day)

(use-package org-super-agenda
  :after org-agenda
  :init
  :config
  (org-super-agenda-mode))

(use-package org-ql
  :ensure t
  :after org-super-agenda
  :config
  (setq org-agenda-custom-commands
        '(("t" "Task Overview"
           ((alltodo "" ((org-agenda-overriding-header "")
                         (org-super-agenda-groups
                          '((:discard (:todo "FUN"))  
                            (:log t)
                            (:name "ACTIVE"
                                   :todo "ACTIVE")
                            (:name "NEXT"
                                   :todo "NEXT")
                            (:name "TODO"
                                   :todo "TODO")
                            (:name "WAIT"
                                   :todo "WAIT")))))))
          ("w" "Weekly Overview"
           ((org-ql-block '(and (or (deadline auto)
                                    (scheduled :to 7))
                                (not (done))
                                (not (habit)))
                          ((org-ql-block-header "Weekly Tasks")
                           (org-super-agenda-groups
                            '((:name "Deadlines"
                                     :deadline t
                                     :order 1)
                              (:name "Schedule"
                                     :scheduled t
                                     :order 2)
                              (:discard (:anything t))))))
            (org-ql-block '(and (ts-active :from today :to 7 :with-time t)
                                (not (done))
                                (not (habit)))
                          ((org-ql-block-header "Appointments")
                           (org-super-agenda-groups
                            '((:name "This Week"
                                     :anything t
                                     :order 1)))))
            (org-ql-block '(and (habit)
                                (not (done)))
                          ((org-ql-block-header "Habits")
                           (org-super-agenda-groups
                            '((:name "Daily Habits"
                                     :habit t
                                     :order 1)
                              (:discard (:anything t)))))))))))

(setq org-todo-keywords
      '((sequence "WAIT(w@/!)" "HABIT(h)" "TODO(t)" "NEXT(n)" "|" "DONE(d!)")
        (sequence "BACKLOG(b)" "PLAN(p)" "READY(r)" "ACTIVE(a)" "REVIEW(v)"
                  "FUN(f)" "|" "COMPLETED(c)" "CANC(k@)")))

(use-package ox-typst
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
  :after org
  )

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
  (setq denote-menu-title-column-width 40
        denote-menu-show-file-type nil))

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

;; (use-package corfu-terminal
;;   :ensure t
;;   :after corfu
;;   :init
;;   (corfu-terminal-mode +1))

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
  (setq markdown-command "multimarkdown"))

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
              (eglot-inlay-hints-mode -1)))
  
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

;; (use-package company
;;   :straight t
;;   :hook (after-init . global-company-mode)
;;   :bind (:map company-active-map
;;               ("C-n" . company-select-next)
;;               ("C-p" . company-select-previous)
;;               ("C-j" . company-select-next-or-abort)
;;               ("C-k" . company-select-previous-or-abort)
;;               ("M-j" . company-select-next)
;;               ("M-k" . company-select-previous)
;;               ("<tab>" . company-complete-selection)
;;               ("TAB" . company-complete-selection))
;;   :config
;;   (setq company-minimum-prefix-length 1)
;;   (setq company-idle-delay 0.1)
;;   (setq company-show-numbers t)
;;   (setq company-tooltip-align-annotations t)
;;   (setq company-require-match nil)
;;   (setq company-backends '((company-capf :with company-yasnippet)
;;                            company-files
;;                            company-dabbrev-code
;;                            ))
;;   (setq company-dabbrev-code-everywhere t)
;;   (setq company-dabbrev-code-ignore-case t))

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
                 '(python-mode . ("pyright-langserver" "--stdio")))))

(use-package python-black
  :ensure t
  :demand t
  :after python)

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

(use-package nushell-mode
  :ensure nil
  :straight nil
  :mode "\\.nu\\'")

(use-package nushell-ts-babel
  :straight (nushell-ts-babel :type git :host github :repo "herbertjones/nushell-ts-babel")
  :after org
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages
           '((nushell . t)))))

(use-package go-mode
  :ensure t
  :mode "\\.go\\'"
  :hook (go-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(go-mode . ("gopls" :initializationOptions 
                              (:staticcheck t
                               :matcher "CaseSensitive"
                               :usePlaceholders t)))))
  
  (defun go-mode-setup ()
    (add-hook 'before-save-hook #'eglot-format-buffer -10 t)
    (add-hook 'before-save-hook 
              (lambda ()
                (when (eglot-managed-p)
                  (eglot-code-action-organize-imports nil t)))
              nil t))
  
  (add-hook 'go-mode-hook #'go-mode-setup))

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

(use-package vterm
  :ensure t
  :defer t)

(use-package multi-vterm
  :ensure t
  :defer t)

(use-package olivetti
  :hook (text-mode . olivetti-mode)
  :custom
  (olivetti-body-width 0.67)  ; 67% of window width
  (olivetti-minimum-body-width 72)  ; Minimum width in characters
  (olivetti-style 'fancy)  ; Keep margins visible
  (olivetti-margin-width 0)  ; No side margins
  (olivetti-fringe t)  ; Keep fringes visible
  (olivetti-shrink t)  ; Actually shrink text width
  (olivetti-safe t))  ; Don't interfere with other modes

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

  (evil-define-avy-motion evil-avy-goto-char-timer inclusive))

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

(use-package pulsar
  :defer t
  :ensure t
  :hook
  (after-init . pulsar-global-mode)
  :init
  (setq pulsar-pulse-on-window-change nil)
  :config
  (setq pulsar-pulse t)
  (setq pulsar-delay 0.025)
  (setq pulsar-iterations 10)
  (setq pulsar-face 'evil-ex-lazy-highlight)

  (add-hook 'org-agenda-mode-hook
            (lambda () (pulsar-mode -1)))

  (setq pulsar-pulse-functions
        '(evil-scroll-down
          flymake-goto-next-error
          flymake-goto-prev-error
          evil-yank
          evil-yank-line
          evil-delete
          evil-delete-line
          evil-jump-item
          diff-hl-next-hunk
          diff-hl-previous-hunk
          recenter-top-bottom
          move-to-window-line-top-bottom
          reposition-window
          bookmark-jump
          other-window
          delete-window
          delete-other-windows
          forward-page
          backward-page
          scroll-up-command
          scroll-down-command
          windmove-right
          windmove-left
          windmove-up
          windmove-down
          tab-new
          tab-close
          tab-next)))

(use-package evil-org
  :ensure t
  :straight t
  :after org
  :hook (org-mode . (lambda () evil-org-mode))
  :config
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys))

(use-package nerd-icons
  :if ek-use-nerd-fonts                   ;; Load the package only if the user has configured to use nerd fonts.
  :ensure t                               ;; Ensure the package is installed.
  :straight t
  :defer t)                               ;; Load the package only when needed to improve startup time.

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

;; (require 'battery)
;; (require 'nerd-icons)

;; ;; 2. Define battery faces (uncomment your original faces)
;; (defface my-battery-charging
;;   '((t :inherit success))
;;   "Face for charging battery.")

;; (defface my-battery-full
;;   '((t :inherit success))
;;   "Face for full battery.")

;; (defface my-battery-normal
;;   '((t :inherit mode-line))
;;   "Face for normal buffer indicator.")

;; (defface my-buffer-read-only
;;   '((t :inherit error))
;;   "Face for read-only buffer indicator.")

;; (defface my-buffer-remote
;;   '((t :inherit font-lock-comment-face))
;;   "Face for remote buffer indicator.")

;; ;; Evil state faces
;; (defface my-evil-normal-state
;;   '((t :inherit success))
;;   "Face for evil normal state.")

;; (defface my-evil-insert-state
;;   '((t :inherit font-lock-keyword-face))
;;   "Face for evil insert state.")

;; (defface my-evil-visual-state
;;   '((t :inherit warning))
;;   "Face for evil visual state.")

;; (defface my-evil-motion-state
;;   '((t :inherit font-lock-doc-face :slant normal))
;;   "Face for evil motion state.")

;; (defface my-evil-emacs-state
;;   '((t :inherit font-lock-builtin-face))
;;   "Face for evil emacs state.")

;; ;; 3. Battery functionality (simplified version)
;; (defvar my-battery-string nil)
;; (defun my-header-line-right ()
;;   "Formatiert den rechten Teil der Header-Line und richtet ihn korrekt aus."
;;   (let* ((rhs (concat (my-mu4e-segment)
;;                       (when (my-should-show-battery)
;;                         my-battery-string)
;;                       (when (bound-and-true-p display-time-mode)
;;                         (concat " " display-time-string " ")))) ;; Extra Leerzeichen als Abstand zum Rand
;;          ;; Breite in Pixeln berechnen (benötigt Emacs 29+ oder lib)
;;          (width (if (fboundp 'string-pixel-width)
;;                     (string-pixel-width rhs)
;;                   ;; Fallback für ältere Emacs-Versionen (ungenauer)
;;                   (* (string-width rhs) (frame-char-width)))))
;;     ;; Spacer erstellen: "Rechts minus Breite des Textes"
;;     (concat (propertize " " 'display `(space :align-to (- right (,width))))
;;             rhs)))

;; (defun my-update-battery ()
;;   "Update battery display."
;;   (setq my-battery-string
;;         (when (bound-and-true-p display-battery-mode)
;;           (let* ((data (and battery-status-function
;;                             (functionp battery-status-function)
;;                             (funcall battery-status-function)))
;;                  (status (cdr (assoc ?L data)))
;;                  (charging? (or (string-equal "AC" status)
;;                                 (string-equal "on-line" status)))
;;                  (percentage (car (read-from-string (or (cdr (assq ?p data)) "ERR"))))
;;                  (valid? (and (numberp percentage)
;;                               (>= percentage 0)
;;                               (<= percentage 100)))
;;                  (face (if valid?
;;                            (cond (charging? 'my-battery-charging)
;;                                  ((< percentage 20) 'error)
;;                                  ((< percentage 30) 'warning)
;;                                  (t 'success))
;;                          'error))
;;                  (icon (if valid?
;;                            (cond
;;                             ((>= percentage 90)
;;                              (nerd-icons-mdicon "nf-md-battery" :face face))
;;                             ((>= percentage 60)
;;                              (nerd-icons-mdicon "nf-md-battery_70" :face face))
;;                             ((>= percentage 30)
;;                              (nerd-icons-mdicon "nf-md-battery_50" :face face))
;;                             (t
;;                              (nerd-icons-mdicon "nf-md-battery_20" :face face)))
;;                          (nerd-icons-mdicon "nf-md-battery_alert" :face face)))
;;                  (text (if valid? (format " %d%%" percentage) " N/A")))
;;             (concat (propertize icon 'help-echo "Battery status")
;;                     (propertize text 'face face 'help-echo "Battery status"))))))

;; (defun my-override-battery ()
;;   "Override default battery display."
;;   (when (bound-and-true-p display-battery-mode)
;;     (advice-add #'battery-update :after #'my-update-battery)
;;     (setq global-mode-string (delq 'battery-mode-line-string global-mode-string))
;;     (my-update-battery)))

;; ;; 4. Buffer state icons
;; (defvar my-buffer-state-icon nil)
;; (defvar my-buffer-file-icon nil)

;; (defun my-update-buffer-file-icon (&rest _)
;;   "Update file icon in header-line. Handles optional arguments from advice."
;;   (setq my-buffer-file-icon
;;         (when (require 'nerd-icons nil t)
;;           (let ((icon (nerd-icons-icon-for-buffer)))
;;             (propertize
;;              (if (or (null icon) (string-empty-p icon))
;;                  (nerd-icons-faicon "nf-fa-file_o")
;;                icon)
;;              'help-echo "File type")))))


;; (defun my-update-buffer-state-icon ()
;;   "Update buffer state indicator."
;;   (setq my-buffer-state-icon
;;         (concat
;;          (cond (buffer-read-only
;;                 (propertize (nerd-icons-mdicon "nf-md-lock" :face 'my-buffer-read-only)
;;                             'help-echo "Read-only buffer"))
;;                ((and buffer-file-name (buffer-modified-p))
;;                 (propertize (nerd-icons-mdicon "nf-md-content_save_edit" :face 'warning)
;;                             'help-echo "Buffer modified"))
;;                (t "")))))

;; (defun my-update-buffer-file-name ()
;;   "Update buffer file name with proper faces."
;;   (let* ((file-name (or (and buffer-file-name 
;;                              (file-name-nondirectory buffer-file-name))
;;                         (buffer-name)))
;;          (face (cond ((and buffer-file-name (buffer-modified-p))
;;                       'warning)
;;                      (buffer-read-only
;;                       'error)
;;                      (t 'mode-line-buffer-id))))
;;     (propertize file-name 'face face)))

;; ;; 5. Evil state indicator
;; (defvar my-evil-state-string nil)

;; (defun my-update-evil-state ()
;;   "Update evil state indicator."
;;   (setq my-evil-state-string
;;         (when (bound-and-true-p evil-local-mode)
;;           (let ((state (cond
;;                         ((evil-normal-state-p)
;;                          (cons (nerd-icons-mdicon "nf-md-alpha_n_circle" :face 'my-evil-normal-state)
;;                                "N"))
;;                         ((evil-insert-state-p)
;;                          (cons (nerd-icons-mdicon "nf-md-alpha_i_circle" :face 'my-evil-insert-state)
;;                                "I"))
;;                         ((evil-visual-state-p)
;;                          (cons (nerd-icons-mdicon "nf-md-alpha_v_circle" :face 'my-evil-visual-state)
;;                                "V"))
;;                         ((evil-motion-state-p)
;;                          (cons (nerd-icons-mdicon "nf-md-alpha_m_circle" :face 'my-evil-motion-state)
;;                                "M"))
;;                         ((evil-emacs-state-p)
;;                          (cons (nerd-icons-mdicon "nf-md-alpha_e_circle" :face 'my-evil-emacs-state)
;;                                "E"))
;;                         (t
;;                          (cons (nerd-icons-mdicon "nf-md-alpha_u_circle" :face 'mode-line)
;;                                "O")))))
;;             (when state
;;               (concat (car state) " " (cdr state)))))))

;; ;; 6. Battery toggle
;; (defvar my-show-battery t
;;   "Whether to show battery in header-line.")

;; (defun my-should-show-battery ()
;;   "Determine if battery should be shown."
;;   (and my-show-battery
;;        (bound-and-true-p display-battery-mode)
;;        my-battery-string))

;; ;; 7. mu4e integration (simplified - check if mu4e exists)
;; (defvar my-mu4e-unread-count 0)

;; (defun my-update-mu4e-count ()
;;   "Update mu4e unread count."
;;   (setq my-mu4e-unread-count
;;         (when (and (featurep 'mu4e-alert)
;;                    (bound-and-true-p mu4e-alert-mode-line))
;;           (or (when (functionp 'mu4e-alert-mode-line)
;;                 (mu4e-alert-mode-line))
;;               0))))

;; (defun my-mu4e-segment ()
;;   "Create mu4e notification segment."
;;   (when (and (featurep 'mu4e-alert)
;;              (numberp my-mu4e-unread-count)
;;              (> my-mu4e-unread-count 0))
;;     (let* ((icon (nerd-icons-mdicon "nf-md-email" :face 'warning))
;;            (count (if (> my-mu4e-unread-count 99)
;;                       "99+"
;;                     (number-to-string my-mu4e-unread-count)))
;;            (text (propertize count 'face '(:inherit warning :weight bold))))
;;       (concat " " icon " " text " "))))

;; ;; 8. Fixed header-line-format
;; (setq-default header-line-format
;;               '("%e"
;;                 (:propertize " " display (raise +0.4))
;;                 (:propertize " " display (raise -0.4))

;;                 ;; --- Linker Teil (wie gehabt) ---
;;                 (:eval (when my-evil-state-string
;;                          (list my-evil-state-string "  ")))
;;                 (:eval (when my-buffer-file-icon
;;                          (list my-buffer-file-icon " ")))
;;                 (:eval (my-update-buffer-file-name))
;;                 (:eval (when my-buffer-state-icon
;;                          (list " " my-buffer-state-icon)))
;;                 (:eval (when vc-mode
;;                          (list "   "
;;                                (propertize (truncate-string-to-width
;;                                             (substring vc-mode 5) 50)
;;                                            'face 'font-lock-comment-face))))
;;                 (:propertize "  %4l:%c" face mode-line-buffer-id)

;;                 ;; --- Rechter Teil (neu: berechnet und ausgerichtet) ---
;;                 (:eval (my-header-line-right))))



;; ;; 9. Force mode-line to be hidden
;; (setq-default mode-line-format nil)

;; ;; 10. Setup hooks
;; (add-hook 'find-file-hook #'my-update-buffer-file-icon)
;; (add-hook 'after-change-major-mode-hook #'my-update-buffer-file-icon)
;; (add-hook 'after-save-hook #'my-update-buffer-state-icon)
;; (add-hook 'buffer-list-update-hook #'my-update-buffer-state-icon)
;; (advice-add #'rename-buffer :after #'my-update-buffer-file-icon)
;; (advice-add #'set-visited-file-name :after #'my-update-buffer-file-icon)

;; (add-hook 'evil-normal-state-entry-hook #'my-update-evil-state)
;; (add-hook 'evil-insert-state-entry-hook #'my-update-evil-state)
;; (add-hook 'evil-visual-state-entry-hook #'my-update-evil-state)
;; (add-hook 'evil-motion-state-entry-hook #'my-update-evil-state)
;; (add-hook 'evil-emacs-state-entry-hook #'my-update-evil-state)
;; (add-hook 'evil-local-mode-hook #'my-update-evil-state)

;; (add-hook 'display-battery-mode-hook #'my-override-battery)

;; ;; 11. Enable time and battery
;; (display-time-mode 1)
;; (display-battery-mode 1)

;; ;; 12. Helper functions
;; (defun my-toggle-battery-display ()
;;   "Toggle battery display in header-line."
;;   (interactive)
;;   (setq my-show-battery (not my-show-battery))
;;   (force-mode-line-update)
;;   (message "Battery display %s" (if my-show-battery "enabled" "disabled")))

;; (defun my-header-line-refresh ()
;;   "Force refresh header-line."
;;   (interactive)
;;   (force-mode-line-update))

;; ;; 13. Initialize everything
;; (my-update-buffer-file-icon)
;; (my-update-buffer-state-icon)
;; (my-update-evil-state)
;; (my-update-battery)



;; (use-package hide-mode-line
;;   :straight t
;;   :defer t
;;   :bind (:map custom-bindings-map ("C-c h m" . hide-mode-line-mode)))

(use-package awesome-tray
  :straight (:host github :repo "manateelazycat/awesome-tray")
  :custom
  ;; Position at the top
  (awesome-tray-position 'top)
  
  ;; Basic Visual Settings
  (awesome-tray-hide-mode-line t)
  (awesome-tray-separator " │ ")
  (awesome-tray-ellipsis "…")
  
  ;; Module Customizations
  (awesome-tray-date-format "%I:%M %p")  ; 12-hour format with AM/PM
  (awesome-tray-git-format " ᚴ %s")
  (awesome-tray-git-show-status t)
  (awesome-tray-location-format "%l:%c")
  (awesome-tray-evil-show-mode t)
  (awesome-tray-evil-show-macro t)
  (awesome-tray-evil-show-cursor-count t)
  (awesome-tray-file-path-full-dirname-levels 2)
  (awesome-tray-file-path-shorten-start-length 1)
  (awesome-tray-input-method-default-style "EN")
  (awesome-tray-input-method-local-style "中")
  (awesome-tray-input-method-local-methods '("rime" "pinyin"))
  
  ;; Performance settings
  (awesome-tray-refresh-idle-delay 0.5)
  (awesome-tray-refresh-timer t)
  (awesome-tray-update-interval 1)
  
  :config
  ;; Start with essential modules for performance
  (setq awesome-tray-active-modules
        '(
          "buffer-name"
          "mode-name"
          "date"
          "location"
          "evil"
          "input-method"
          ))
  
  ;; Enable awesome-tray
  (awesome-tray-mode 1)
)

;; (use-package doom-modeline
;;   :ensure t
;;   :hook (after-init . doom-modeline-mode)
;;   :custom
;;   (doom-modeline-time t)
;;   (doom-modeline-time-icon nil)
;;   (doom-modeline-buffer-file-name-style 'buffer-name)
;;   (doom-modeline-height 40)
;;   (doom-modeline-buffer-encoding nil)
;;   (doom-modeline-env-version t)
;;   (doom-modeline-env-setup-rust nil)
;;   :config
;;   (setq display-time-24hr-format nil)
;;   (display-time-mode 1)
;;   (set-face-attribute 'mode-line nil :height 180)
;;   (set-face-attribute 'mode-line-inactive nil :height 180)
;;   (add-hook
;;    'doom-modeline-mode-hook
;;    (lambda ()
;;      (setq-default header-line-format
;;                    (default-value 'mode-line-format))
;;      (setq-default mode-line-format nil))))

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
(setq-default cursor-type 'bar)

(defvar cashmere/font-height 140)

(set-face-attribute 'default nil :family "JetBrainsMono Nerd Font" :weight 'bold :height cashmere/font-height)
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

(use-package modus-catppuccin
  :straight (:type git
             :repo "https://gitlab.com/magus/modus-catppuccin"
             :branch "main")
  :config
  (load-theme 'catppuccin-frappe :no-confirm))

;; (use-package modus-themes
;;   :ensure nil
;;   :defer t
;;   :custom
;;   (modus-themes-italic-constructs t)
;;   (modus-themes-bold-constructs t)
;;   (modus-themes-mixed-fonts nil)
;;   (modus-themes-prompts '(bold intense))
;;   (modus-themes-common-palette-overrides
;;    `((accent-0 "#1e66f5")
;;      (accent-1 "#04a5e5")
;;      (bg-active bg-main)
;;      (bg-added "#d3f0d0")
;;      (bg-added-refine "#b8e6b3")
;;      (bg-changed "#dde5f5")
;;      (bg-changed-refine "#c4d4f0")
;;      (bg-completion "#ccd0da")
;;      (bg-completion-match-0 "#eff1f5")
;;      (bg-completion-match-1 "#eff1f5")
;;      (bg-completion-match-2 "#eff1f5")
;;      (bg-completion-match-3 "#eff1f5")
;;      (bg-hl-line "#e6e9ef")
;;      (bg-hover-secondary "#9ca0b0")
;;      (bg-line-number-active unspecified)
;;      (bg-line-number-inactive "#eff1f5")
;;      (bg-main "#eff1f5")
;;      (bg-mark-delete "#f5d9e0")
;;      (bg-mark-select "#dde5f5")
;;      (bg-mode-line-active "#e6e9ef")
;;      (bg-mode-line-inactive "#e6e9ef")
;;      (bg-prominent-err "#f5d9e0")
;;      (bg-prompt unspecified)
;;      (bg-prose-block-contents "#dce0e8")
;;      (bg-prose-block-delimiter bg-prose-block-contents)
;;      (bg-region "#9ca0b0")
;;      (bg-removed "#f5d9e0")
;;      (bg-removed-refine "#f0c9d1")
;;      (bg-tab-bar      "#eff1f5")
;;      (bg-tab-current  bg-main)
;;      (bg-tab-other    "#eff1f5")
;;      (border-mode-line-active nil)
;;      (border-mode-line-inactive nil)
;;      (builtin "#1e66f5")
;;      (comment "#7c7f93")
;;      (constant  "#d20f39")
;;      (cursor  "#dc8a78")
;;      (date-weekday "#1e66f5")
;;      (date-weekend "#fe640b")
;;      (docstring "#5c5f77")
;;      (err     "#d20f39")
;;      (fg-active fg-main)
;;      (fg-completion "#4c4f69")
;;      (fg-completion-match-0 "#1e66f5")
;;      (fg-completion-match-1 "#d20f39")
;;      (fg-completion-match-2 "#40a02b")
;;      (fg-completion-match-3 "#fe640b")
;;      (fg-heading-0 "#d20f39")
;;      (fg-heading-1 "#fe640b")
;;      (fg-heading-2 "#df8e1d")
;;      (fg-heading-3 "#40a02b")
;;      (fg-heading-4 "#04a5e5")
;;      (fg-line-number-active "#7287fd")
;;      (fg-line-number-inactive "#9ca0b0")
;;      (fg-link  "#1e66f5")
;;      (fg-main "#4c4f69")
;;      (fg-mark-delete "#d20f39")
;;      (fg-mark-select "#1e66f5")
;;      (fg-mode-line-active "#4c4f69")
;;      (fg-mode-line-inactive "#9ca0b0")
;;      (fg-prominent-err "#d20f39")
;;      (fg-prompt "#8839ef")
;;      (fg-prose-block-delimiter "#7c7f93")
;;      (fg-prose-verbatim "#40a02b")
;;      (fg-region "#4c4f69")
;;      (fnname    "#1e66f5")
;;      (fringe "#eff1f5")
;;      (identifier "#8839ef")
;;      (info    "#179299")
;;      (keyword   "#8839ef")
;;      (keyword "#8839ef")
;;      (name "#1e66f5")
;;      (number "#fe640b")
;;      (property "#1e66f5")
;;      (string "#40a02b")
;;      (type      "#df8e1d")
;;      (variable  "#fe640b")
;;      (warning "#df8e1d")))
;;   :config
;;   (modus-themes-with-colors
;;     (custom-set-faces
;;      `(change-log-acknowledgment ((,c :foreground "#7287fd")))
;;      `(change-log-date ((,c :foreground "#40a02b")))
;;      `(change-log-name ((,c :foreground "#fe640b")))
;;      `(diff-context ((,c :foreground "#1e66f5")))
;;      `(diff-file-header ((,c :foreground "#ea76cb")))
;;      `(diff-header ((,c :foreground "#1e66f5")))
;;      `(diff-hunk-header ((,c :foreground "#fe640b")))
;;      `(gnus-button ((,c :foreground "#1e66f5")))
;;      `(gnus-group-mail-3 ((,c :foreground "#1e66f5")))
;;      `(gnus-group-mail-3-empty ((,c :foreground "#1e66f5")))
;;      `(gnus-header-content ((,c :foreground "#04a5e5")))
;;      `(gnus-header-from ((,c :foreground "#8839ef")))
;;      `(gnus-header-name ((,c :foreground "#40a02b")))
;;      `(gnus-header-subject ((,c :foreground "#1e66f5")))
;;      `(log-view-message ((,c :foreground "#7287fd")))
;;      `(match ((,c :background "#c4d4f0" :foreground "#4c4f69")))
;;      `(modus-themes-search-current ((,c :background "#d20f39" :foreground "#eff1f5")))
;;      `(modus-themes-search-lazy ((,c :background "#c4d4f0" :foreground "#4c4f69")))
;;      `(newsticker-extra-face ((,c :foreground "#7c7f93" :height 0.8 :slant italic)))
;;      `(newsticker-feed-face ((,c :foreground "#d20f39" :height 1.2 :weight bold)))
;;      `(newsticker-treeview-face ((,c :foreground "#4c4f69")))
;;      `(newsticker-treeview-selection-face ((,c :background "#c4d4f0" :foreground "#4c4f69")))
;;      `(tab-bar ((,c :background "#eff1f5" :foreground "#4c4f69")))
;;      `(tab-bar-tab ((,c :background "#eff1f5" :underline t)))
;;      `(tab-bar-tab-group-current ((,c :background "#eff1f5" :foreground "#4c4f69" :underline t)))
;;      `(tab-bar-tab-group-inactive ((,c :background "#eff1f5" :foreground "#7c7f93")))
;;      `(tab-bar-tab-inactive ((,c :background "#eff1f5" :foreground "#5c5f77")))
;;      `(vc-dir-file ((,c :foreground "#1e66f5")))
;;      `(vc-dir-header-value ((,c :foreground "#7287fd")))))
;;   :init
;;   (load-theme 'modus-operandi t))

;; (use-package kanagawa-themes
;;   :ensure t
;;   :config
;;   (load-theme 'kanagawa-wave t))

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

(use-package zoxide
  :ensure t)

(use-package dired-rsync 
  :ensure t)

(use-package dired-rsync-transient
  :ensure t
  :after (dired-rsync transient))

(setq-default olivetti-body-width 130)
(define-globalized-minor-mode my/global-olivetti-mode olivetti-mode
  (lambda () (olivetti-mode 1)))
(my/centered-cursor)
(my/global-olivetti-mode)

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
 '(zoom-size '(0.618 . 0.618)))

(use-package pdf-tools
  :straight (:type built-in)
  :magic ("%PDF" . pdf-view-mode)
  :config
  (pdf-loader-install)
  :hook (pdf-view-mode . (lambda () (display-line-numbers-mode -1))))

(defun ek/lsp-describe-and-jump ()
  (interactive)
  (lspce-help-at-point)
  (let ((help-buffer "*lsp-help*"))
    (when (get-buffer help-buffer)
      (switch-to-buffer-other-window help-buffer))))


(defun my/eldoc-and-jump ()
  "Zeige Eldoc-Dokumentation manuell an."
  (interactive)
  (if (>= emacs-major-version 31)
      (eldoc-box-help-at-point)
    (progn
      (eldoc-doc-buffer)
      (when-let ((eldoc-win (get-buffer-window "*eldoc*")))
        (select-window eldoc-win)))))

(evil-define-key 'normal 'global (kbd "K") #'my/eldoc-and-jump)

;; (defun my/setup-eldoc-hover-keys ()
;;   (when (string-match-p "\\*eldoc\\*" (buffer-name))
;;     (evil-normalize-keymaps)
;;     (evil-local-set-key 'normal (kbd "q") 'quit-window)))

;; (add-hook 'buffer-list-update-hook #'my/setup-eldoc-hover-keys)

;; (evil-define-key 'normal 'global (kbd "K") #'my/eldoc-and-jump)

(defun my/format-buffer ()
  (interactive)
  (cond
   ((eq major-mode 'rust-mode) (eglot-format-buffer))
   ((eq major-mode 'nix-mode) (eglot-format-buffer))  
   ((or (eq major-mode 'python-mode) 
        (eq major-mode 'python-ts-mode)) (eglot-format-buffer))
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
  "dg" '(denote-grep t :wk "Search")
  "dn" '(denote t :wk "Create a new note")
  "dr" '(denote-rename-file t :wk "Rename Note")

  "f" '(:ignore t :wk "files")
  "fd" '(dired :wk "dired")
  "fD" '(dired-jump :wk "dired jump")
  "fr" '(consult-recent-file :wk "recent files")
  "ff" '(find-file :wk "find file")
  "fs" '(save-buffer :wk "save file")

  "b" '(:ignore t :wk "buffers")
  "bb" '(consult-buffer :wk "switch buffer")
  "bi" '(ibuffer :wk "ibuffer")
  "bd" '(kill-current-buffer :wk "kill buffer")
  "bk" '(kill-current-buffer :wk "kill buffer")
  "bs" '(save-buffer :wk "save buffer")

  "p" '(:ignore t :wk "project")
  "pp" '(projectile-switch-project :wk "switch project")
  "pf" '(projectile-find-file :wk "find file")
  "ps" '(consult-ripgrep :wk "search")
  "pb" '(consult-projectile-buffer :wk "buffers") 
  "pk" '(projectile-kill-buffers :wk "kill buffers") 
  ;; "pd" '(projectile-dired :wk "root dir")
  "pd" '(projectile-remove-known-project :wk "delete project")
  "pr" '(projectile-recentf :wk "recent files")
  "pa" '(projectile-add-known-project :wk "add project")
  ;; "pc" '(projectile-compile-project :wk "compile")
  ;; "pt" '(projectile-test-project :wk "test")
  "pi" '(projectile-invalidate-cache :wk "invalidate cache")

  "g" '(:ignore t :wk "git/goto")
  "gc" '(magit-clone :wk "clone")
  "gg" '(magit-status :wk "status")
  "gl" '(magit-log-current :wk "log")
  "gd" '(xref-find-definitions :wk "go to definition") 
  "gD" '((lambda () (interactive) 
           (let ((current-prefix-arg 4))
             (call-interactively #'xref-find-definitions)))
         :wk "definition other window")
  "gi" '(eglot-find-implementation :wk "go to implementation")
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

(general-def '(normal visual) 'override
  "s" (lambda ()
        (interactive)
        (if (derived-mode-p 'magit-mode)
            (call-interactively 'magit-stage)
          (when (my/avy-enabled-p)
            (let ((scroll-margin 0)
                  (maximum-scroll-margin 0))
              (call-interactively 'evil-avy-goto-char-2))))))


(general-def 'normal 'override
  "]d" 'flymake-goto-next-error
  "[d" 'flymake-goto-prev-error
  "]c" 'diff-hl-next-hunk
  "[c" 'diff-hl-previous-hunk
  "]b" 'switch-to-next-buffer
  "[b" 'switch-to-prev-buffer
  "]t" 'tab-next
  "[t" 'tab-previous
  "P" 'consult-yank-from-kill-ring
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

(my-local-leader
  :keymaps 'org-mode-map
  "h" '(consult-org-heading :wk "search headings")
  "n" '(my-toggle-org-tree-indirect-buffer :wk "toggle narrow"))

(my-leader
  :keymaps 'org-mode-map
  "c" '(:wk "Clock" :ignore)

  "cs" '(org-schedule :wk "Schedule")
  "cd" '(org-deadline :wk "Deadline")

  "l" '(:wk "Link" :ignore)
  "lc" '(org-cliplink :wk "Cliplink")
  "li" '(org-download-clipboard :wk "Image")
  "ll" '(org-insert-link :wk "Link various things")

  "t" '(org-todo :wk "TODO")

  "RET" '(org-open-at-point))

(with-eval-after-load 'denote-menu
  (general-def 'normal denote-menu-mode-map
    "r" 'denote-menu-filter
    "c" 'denote-menu-clear-filters
    "e" 'denote-menu-export-to-dired
    "o" 'denote-menu-filter-out-keyword))

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
  "t" '(multi-vterm :wk "terminal")
  "c" '(my/centered-cursor :wk "center cursor")
  "d" '(dirvish :wk "dired")
  "z" '(zoom-mode :wk "zoom/golden ratio")
  "m" '(mu4e :wk "mail")
  "p" '(pass :wk "pass")
  "o" '(my/global-olivetti-mode :wk "center buffer")
  "g" '(gptel :wk "gptel"))

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

(use-package lispy
  :ensure t
  :hook ((emacs-lisp-mode . lispy-mode)
         (clojure-mode . lispy-mode)
         (scheme-mode . lispy-mode)
         (lisp-mode . lispy-mode)))

(use-package lispyville
  :ensure t
  :hook (lispy-mode . lispyville-mode)
  :config
  (lispyville-set-key-theme '(operators c-w additional)))

;; (profiler-start 'cpu)
;; (org-agenda nil "c")
;; (profiler-report)
;; (profiler-stop)

(provide 'init)
