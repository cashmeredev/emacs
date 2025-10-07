;;; config.el --- Emacs-Kick --- A feature rich Emacs config for (neo)vi(m)mers -*- lexical-binding: t; -*-
;; (setenv "LSP_USE_PLISTS" "true")
(setq gc-cons-threshold #x40000000)

(setq read-process-output-max (* 1024 1024 4))

(setq package-enable-at-startup nil) 
(when (boundp 'pgtk-wait-for-event-timeout)
  (setq pgtk-wait-for-event-timeout 0.001))

(setq which-func-update-delay 1.0)
(setq gnutls-algorithm-priority "NORMAL:-VERS-TLS1.3")
(set-language-environment    "UTF-8")
(setq locale-coding-system   'utf-8)
(prefer-coding-system        'utf-8)
(set-default-coding-systems  'utf-8)
(set-terminal-coding-system  'utf-8)
(set-keyboard-coding-system  'utf-8)
(set-selection-coding-system 'utf-8)

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

(add-to-list 'default-frame-alist '(alpha-background . 90))

;; (add-to-list 'default-frame-alist '(internal-border-width . 16))

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
(straight-use-package 'use-package)

(setq straight-use-package-by-default t)

;;; EMACS
;;  This is biggest one. Keep going, plugins (oops, I mean packages) will be shorter :)
(use-package emacs
  :ensure nil
  :custom                                         ;; Set custom variables to configure Emacs behavior.
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
  (org-mode . (lambda () (display-line-numbers-mode -1)))


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


  ;; Configure font settings based on the operating system.
  ;; Ok, this kickstart is meant to be used on the terminal, not on GUI.
  ;; But without this, I fear you could start Graphical Emacs and be sad :(
  (set-face-attribute 'default nil :family "Fragment Mono"  :height 160)
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
  (tool-bar-mode -1)           ;; Disable the tool bar for a cleaner interface.
  (menu-bar-mode -1)           ;; Disable the menu bar for a more streamlined look.

  (when scroll-bar-mode
    (scroll-bar-mode -1))      ;; Disable the scroll bar if it is active.

  (global-hl-line-mode -1)     ;; Disable highlight of the current line
  (global-auto-revert-mode 1)  ;; Enable global auto-revert mode to keep buffers up to date with their corresponding files.
  (indent-tabs-mode -1)        ;; Disable the use of tabs for indentation (use spaces instead).
  (recentf-mode 1)             ;; Enable tracking of recently opened files.
  (savehist-mode 1)            ;; Enable saving of command history.
  (save-place-mode 1)          ;; Enable saving the place in files for easier return.
  (winner-mode 1)              ;; Enable winner mode to easily undo window configuration changes.
  (xterm-mouse-mode 1)         ;; Enable mouse support in terminal mode.
  (file-name-shadow-mode 1)    ;; Enable shadowing of filenames for clarity.

  ;; Set the default coding system for files to UTF-8.
  (modify-coding-system-alist 'file "" 'utf-8)

  ;; Add a hook to run code after Emacs has fully initialized.
  (add-hook 'after-init-hook
			(lambda ()
			  (message "Emacs has fully loaded. This code runs after startup.")

			  ;; Insert a welcome message in the *scratch* buffer displaying loading time and activated packages.
			  (with-current-buffer (get-buffer-create "*scratch*")
				(insert (format
						 ";;    Welcome to Emacs!
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

;;; WINDOW
;; This section configures window management in Emacs, enhancing the way buffers
;; are displayed for a more efficient workflow. The `window' use-package helps
;; streamline how various buffers are shown, especially those related to help,
;; diagnostics, and completion.
;;
;; Note: I have left some commented-out code below that may facilitate your
;; Emacs journey later on. These configurations can be useful for displaying
;; other types of buffers in side windows, allowing for a more organized workspace.
(use-package window
:straight nil
    :ensure nil       ;; This is built-in, no need to fetch it.
    :custom
    (display-buffer-alist
    '(
	;; ("\\*.*e?shell\\*"
	;;  (display-buffer-in-side-window)
	;;  (window-height . 0.25)
	;;  (side . bottom)
	;;  (slot . -1))

	("\\*\\(Backtrace\\|Warnings\\|Compile-Log\\|[Hh]elp\\|Messages\\|Bookmark List\\|Ibuffer\\|Occur\\|eldoc.*\\)\\*"
	(display-buffer-in-side-window)
	(window-height . 0.25)
	(side . bottom)
	(slot . 0))

	;; Example configuration for the LSP help buffer,
	;; keeps it always on bottom using 25% of the available space:
	("\\*\\(lsp-help\\)\\*"
	(display-buffer-in-side-window)
	(window-height . 0.25)
	(side . bottom)
	(slot . 0))

	;; Configuration for displaying various diagnostic buffers on
	;; bottom 25%:
	("\\*\\(Flymake diagnostics\\|xref\\|ivy\\|Swiper\\|Completions\\)"
	(display-buffer-in-side-window)
	(window-height . 0.25)
	(side . bottom)
	(slot . 1))
	)))

(use-package dired
:straight nil
    :ensure nil                                                ;; This is built-in, no need to fetch it.
    :custom
    (dired-listing-switches "-lah --group-directories-first")  ;; Display files in a human-readable format and group directories first.
    (dired-dwim-target t)                                      ;; Enable "do what I mean" for target directories.
    (dired-guess-shell-alist-user
    '(("\\.\\(png\\|jpe?g\\|tiff\\)" "feh" "xdg-open" "open") ;; Open image files with `feh' or the default viewer.
	("\\.\\(mp[34]\\|m4a\\|ogg\\|flac\\|webm\\|mkv\\)" "mpv" "xdg-open" "open") ;; Open audio and video files with `mpv'.
	(".*" "open" "xdg-open")))                              ;; Default opening command for other files.
    (dired-kill-when-opening-new-dired-buffer t)               ;; Close the previous buffer when opening a new `dired' instance.
    :config
    (when (eq system-type 'darwin)
    (let ((gls (executable-find "gls")))                     ;; Use GNU ls on macOS if available.
	(when gls
	(setq insert-directory-program gls)))))

(use-package erc
:straight nil
    :defer t ;; Load ERC when needed rather than at startup. (Load it with `M-x erc RET')
    :custom
    (erc-join-buffer 'window)                                        ;; Open a new window for joining channels.
    (erc-hide-list '("JOIN" "PART" "QUIT"))                          ;; Hide messages for joins, parts, and quits to reduce clutter.
    (erc-timestamp-format "[%H:%M]")                                 ;; Format for timestamps in messages.
    (erc-autojoin-channels-alist '((".*\\.libera\\.chat" "#emacs"))));; Automatically join the #emacs channel on Libera.Chat.

(setq scroll-preserve-screen-position t
      scroll-conservatively 0
      maximum-scroll-margin 0.5
      scroll-margin 99999)

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



(use-package smerge-mode
:straight nil
    :ensure nil                                  ;; This is built-in, no need to fetch it.
    :defer t
    :bind (:map smerge-mode-map
		("C-c ^ u" . smerge-keep-upper)  ;; Keep the changes from the upper version.
		("C-c ^ l" . smerge-keep-lower)  ;; Keep the changes from the lower version.
		("C-c ^ n" . smerge-next)        ;; Move to the next conflict.
		("C-c ^ p" . smerge-previous)))  ;; Move to the previous conflict.

(use-package eldoc
:straight nil
    :ensure nil                                ;; This is built-in, no need to fetch it.
    :config
    (setq eldoc-idle-delay 0)                  ;; Automatically fetch doc help
    (setq eldoc-echo-area-use-multiline-p nil) ;; We use the "K" floating help instead
						;; set to t if you want docs on the echo area
    (setq eldoc-echo-area-display-truncation-message nil)
    :init
    (global-eldoc-mode))

;; (use-package flymake
;;   :straight nil
;;     ;; :ensure nil          ;; This is built-in, no need to fetch it.
;;     ;; :defer t
;;     ;; :hook (prog-mode . flymake-mode)
;;     :custom
;;     (flymake-margin-indicators-string
;;     '((error "!»" compilation-error) (warning "»" compilation-warning)
;; 	(note "»" compilation-info))))

(use-package org
    :straight nil
    :ensure nil     
    :defer t
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
  (org-indent-mode -1)
  (setq org-startup-folded 'content)
  (setq org-adapt-indentation t
        org-hide-leading-stars t
        org-pretty-entities t
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

;; (my-local-leader
;;   )
   
  (add-hook 'org-mode-hook 'variable-pitch-mode)
  (add-to-list 'font-lock-extra-managed-props 'display)
  (font-lock-add-keywords 'org-mode
                          `(("^.*?\( \)\(:[[:alnum:]_@#%:]+:\)$"
                             (1 `(face nil
                                       display (space :align-to (- right ,(org-string-width (match-string 2)) 3)))
                                prepend))) t)
  (setq org-blank-before-new-entry '((heading . nil)
                                     (plain-list-item . nil))))

(use-package org-appear
  :commands (org-appear-mode)
  :hook     (org-mode . org-appear-mode)
  :config 
  (setq org-hide-emphasis-markers t)  ;; Must be activated for org-appear to work
  (setq org-appear-autoemphasis   t   ;; Show bold, italics, verbatim, etc.
        org-appear-autolinks      t   ;; Show links
        org-appear-autosubmarkers t)) ;; Show sub- and superscripts

(use-package which-key
  :straight nil
  :ensure nil
  :defer t
  :hook
  (after-init . which-key-mode)
  :custom
  (which-key-idle-delay 0.3))

(use-package gcmh
  :config
  (gcmh-mode 1))

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

(use-package vertico-posframe
  :init
  (setq vertico-posframe-parameters   '((left-fringe  . 12)    ;; Fringes
                                        (right-fringe . 12)
                                        (undecorated  . nil))) ;; Rounded frame
  :config
  (vertico-posframe-mode 1)
  (setq vertico-posframe-width        96                       ;; Narrow frame
        vertico-posframe-height       vertico-count            ;; Default height
        ;; Don't create posframe for these commands
        vertico-multiform-commands    '((consult-line    (:not posframe))
                                        (consult-ripgrep (:not posframe)))))

;;; CONSULT
;; Consult provides powerful completion and narrowing commands for Emacs.
;; It integrates well with other completion frameworks like Vertico, enabling
;; features like previews and enhanced register management. It's useful for
;; navigating buffers, files, and xrefs with ease.
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

;;; MARKDOWN-MODE
;; Markdown Mode provides support for editing Markdown files in Emacs,
;; enabling features like syntax highlighting, previews, and more.
;; It’s particularly useful for README files, as it can be set
;; to use GitHub Flavored Markdown for enhanced compatibility.
(use-package markdown-mode
  :defer t
  :straight t
  :ensure t
  :mode ("README\\.md\\'" . gfm-mode)            ;; Use gfm-mode for README.md files.
  :init (setq markdown-command "multimarkdown")) ;; Set the Markdown processing command.

(use-package corfu
  :ensure t
  :straight t
  :defer t
  :custom
  (corfu-auto t)                        ;; Only completes when hitting TAB
  (corfu-auto-delay 0.08)                ;; Delay before popup (enable if corfu-auto is t)
  (corfu-auto-prefix 1)                  ;; Trigger completion after typing 1 character
  (corfu-quit-no-match t)                ;; Quit popup if no match
  (corfu-scroll-margin 5)                ;; Margin when scrolling completions
  (corfu-max-width 50)                   ;; Maximum width of completion popup
  (corfu-min-width 50)                   ;; Minimum width of completion popup
  (corfu-popupinfo-delay 0.12)            ;; Delay before showing documentation popup
  :config
  (if ek-use-nerd-fonts
    (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))
  :init
  (global-corfu-mode)
  (corfu-popupinfo-mode t))

(use-package treesit-auto
  :ensure t
  :straight t
  :after emacs
  :custom
  (treesit-auto-install 'prompt)
  :config
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode t))

;;; EMBARK
;; Embark provides a powerful contextual action menu for Emacs, allowing
;; you to perform various operations on completion candidates and other items.
;; It extends the capabilities of completion frameworks by offering direct
;; actions on the candidates.
;; Just `<leader> .' over any text, explore it :)
(use-package embark
  :ensure t
  :straight t
  :defer t)


;;; NERD-ICONS-CORFU
;; Provides Nerd Icons to be used with CORFU.
(use-package nerd-icons-corfu
  :if ek-use-nerd-fonts
  :ensure t
  :straight t
  :defer t
  :after (:all corfu))

;;; EMBARK-CONSULT
;; Embark-Consult provides a bridge between Embark and Consult, ensuring
;; that Consult commands, like previews, are available when using Embark.
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

;; Marginalia enhances the completion experience in Emacs by adding
;; additional context to the completion candidates. This includes
;; helpful annotations such as documentation and other relevant
;; information, making it easier to choose the right option.
(use-package marginalia
  :ensure t
  :straight t
  :hook
  (after-init . marginalia-mode))

(use-package nerd-icons-corfu
    :if ek-use-nerd-fonts
    :ensure t
    :straight t
    :defer t
    :after (:all corfu))

;; (use-package lsp-mode
;;   :defer t
;;   :init (setq lsp-use-plists t)
;;   :hook ((rust-mode             . lsp)
;;          (nix-mode              . lsp)
;;          (lsp-mode              . lsp-enable-which-key-integration)
;;          (typescript-mode       . lsp)
;;          (tsx-ts-mode           . lsp)
;;          (typescript-ts-mode    . lsp)
;;          (web-mode              . lsp))
;;   :bind (:map lsp-mode-map
;;               ("M-<return>" . lsp-execute-code-action)
;;               ("C-M-."      . lsp-find-references)
;;               ("C-c r"      . lsp-rename))
;;   :config
;;   ;; (setq lsp-diagnostics-provider :flycheck
;;   ;;       lsp-completion-provider  :none)       ;; I use corfu
;;   ;; Disable visual features
;;   (setq lsp-headerline-breadcrumb-enable nil  ;; No breadcrumbs
;;         lsp-lens-enable                  nil  ;; No lenses
;; 
;;         ;; Enable code actions in the mode line
;;         lsp-modeline-code-actions-enable t
;;         lsp-modeline-code-action-fallback-icon "✦"
;; 
;;         ;; Limit raising of the echo area to show docs
;;         lsp-signature-doc-lines 3)
;;   (setq lsp-file-watch-threshold  1500)
;;   (setq lsp-format-buffer-on-save nil)
;; 
;;   (with-eval-after-load 'lsp-modeline
;;     (set-face-attribute 'lsp-modeline-code-actions-preferred-face nil
;;                         :inherit font-lock-comment-face)
;;     (set-face-attribute 'lsp-modeline-code-actions-face nil
;;                         :inherit font-lock-comment-face)))

(defun lsp-booster--advice-json-parse (old-fn &rest args)
  "Try to parse bytecode instead of json."
  (or
   (when (equal (following-char) ?#)
     (let ((bytecode (read (current-buffer))))
       (when (byte-code-function-p bytecode)
         (funcall bytecode))))
   (apply old-fn args)))
(advice-add (if (progn (require 'json)
                       (fboundp 'json-parse-buffer))
                'json-parse-buffer
              'json-read)
            :around
            #'lsp-booster--advice-json-parse)

(defun lsp-booster--advice-final-command (old-fn cmd &optional test?)
  "Prepend emacs-lsp-booster command to lsp CMD."
  (let ((orig-result (funcall old-fn cmd test?)))
    (if (and (not test?)                             ;; for check lsp-server-present?
             (not (file-remote-p default-directory)) ;; see lsp-resolve-final-command, it would add extra shell wrapper
             lsp-use-plists
             (not (functionp 'json-rpc-connection))  ;; native json-rpc
             (executable-find "emacs-lsp-booster"))
        (progn
          (when-let ((command-from-exec-path (executable-find (car orig-result))))  ;; resolve command from exec-path (in case not found in $PATH)
            (setcar orig-result command-from-exec-path))
          (message "Using emacs-lsp-booster for %s!" orig-result)
          (cons "emacs-lsp-booster" orig-result))
      orig-result)))
(advice-add 'lsp-resolve-final-command :around #'lsp-booster--advice-final-command)

(use-package rust-mode
  :ensure t
  :mode "\\.rs\\'")

(use-package eglot
  :hook ((rust-mode . eglot-ensure)
         (nix-mode  . eglot-ensure)
         (eglot-managed-mode . (lambda () (eldoc-mode -1))))
  :bind (:map eglot-mode-map
              ("M-<return>" . eglot-code-actions)
              ("C-M-."      . xref-find-references)
              ("C-c r"      . eglot-rename))
  :config
  (setq eldoc-echo-area-use-multiline-p nil)
  (add-to-list 'eglot-server-programs '(nix-mode . ("nixd"))))

(use-package eglot-booster
	:straight ( eglot-booster :type git :host nil :repo "https://github.com/jdtsmith/eglot-booster")
	:after eglot
	:config (eglot-booster-mode))

(use-package eldoc-box
  :ensure t
  :straight t
  :defer t)

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
  (if ek-use-nerd-fonts   ;; Check if nerd fonts are being used
	  (setopt magit-format-file-function #'magit-format-file-nerd-icons)) ;; Turns on magit nerd-icons
  :defer t)

(use-package indent-guide
  :defer t
  :straight t
  :ensure t
  :hook
  (prog-mode . indent-guide-mode)  ;; Activate indent-guide in programming modes.
  :config
  (setq indent-guide-char "│"))    ;; Set the character used for the indent guide.

(use-package add-node-modules-path
  :ensure t
  :straight t
  :defer t
  :custom
  ;; Makes sure you are using the local bin for your
  ;; node project. Local eslint, typescript server...
  (eval-after-load 'typescript-ts-mode
    '(add-hook 'typescript-ts-mode-hook #'add-node-modules-path))
  (eval-after-load 'tsx-ts-mode
    '(add-hook 'tsx-ts-mode-hook #'add-node-modules-path))
  (eval-after-load 'typescriptreact-mode
    '(add-hook 'typescriptreact-mode-hook #'add-node-modules-path))
  (eval-after-load 'js-mode
    '(add-hook 'js-mode-hook #'add-node-modules-path)))

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
  :straight t
  :after general
  :init
  (setq evil-want-integration t
        evil-want-keybinding nil
        evil-want-C-u-scroll t
        evil-want-C-u-delete t
        evil-want-C-i-jump nil)
  
  :config
  (evil-set-undo-system 'undo-tree)
  (setq evil-leader/in-all-states t
        evil-want-fine-undo t)
  
  (evil-mode 1)
  
  (define-key evil-normal-state-map (kbd "SPC") nil)
  (define-key evil-motion-state-map (kbd "SPC") nil)
  (define-key evil-normal-state-map (kbd ",") nil)
  (define-key evil-visual-state-map (kbd ",") nil)
  (define-key evil-motion-state-map (kbd ",") nil)
  
  (setq evil-kill-on-visual-paste nil)
  
  (defun my/evil-no-kill-ring (orig-fn beg end &optional type register yank-handler)
    (let ((register (or register ?_)))
      (funcall orig-fn beg end type register yank-handler)))

  (advice-add 'evil-yank :around #'my/evil-no-kill-ring)
  (advice-add 'evil-delete :around #'my/evil-no-kill-ring)
  (advice-add 'evil-change :around #'my/evil-no-kill-ring)
  
  (defun ek/lsp-describe-and-jump ()
    (interactive)
    (lsp-describe-thing-at-point)
    (let ((help-buffer "*lsp-help*"))
      (when (get-buffer help-buffer)
        (switch-to-buffer-other-window help-buffer)))))

(use-package avy
  :ensure t
  :straight t
  :after evil
  :general
  
  :config
  (setq avy-all-windows t
        avy-all-windows-alt t
        avy-background t
        avy-case-fold-search t
        avy-timeout-seconds 0.3
        avy-style 'at-full
        avy-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l ?q ?w ?e ?r ?t ?y ?u ?i ?o ?p)))

(defun avy-action-exchange (pt)
  "Exchange sexp at PT with the one at point."
  (set-mark pt)
  (transpose-sexps 0))

(add-to-list 'avy-dispatch-alist '(?e . avy-action-exchange))

(use-package evil-collection
  :defer t
  :straight t
  :ensure t
  :custom
  (evil-collection-want-find-usages-bindings t)
  ;; Hook to initialize `evil-collection' when `evil-mode' is activated.
  :hook
  (evil-mode . evil-collection-init))


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

(use-package undo-tree
  :defer t
  :ensure t
  :straight t
  :hook
  (after-init . global-undo-tree-mode)
  :init
  (setq undo-tree-visualizer-timestamps t
		undo-tree-visualizer-diff t
		;; Increase undo limits to avoid losing history due to Emacs' garbage collection.
		;; These values can be adjusted based on your needs.
		;; 10X bump of the undo limits to avoid issues with premature
		;; Emacs GC which truncates the undo history very aggressively.
		undo-limit 800000                     ;; Limit for undo entries.
		undo-strong-limit 12000000            ;; Strong limit for undo entries.
		undo-outer-limit 120000000)           ;; Outer limit for undo entries.
  :config
  ;; Set the directory where `undo-tree' will save its history files.
  ;; This keeps undo history across sessions, stored in a cache directory.
  (setq undo-tree-history-directory-alist '(("." . "~/.emacs.d/.cache/undo"))))

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
  :straight t
  :ensure t
  :hook
  (after-init . pulsar-global-mode)
  :config
  (setq pulsar-pulse t)
  (setq pulsar-delay 0.025)
  (setq pulsar-iterations 10)
  (setq pulsar-face 'evil-ex-lazy-highlight)

  (add-to-list 'pulsar-pulse-functions 'evil-scroll-down)
  (add-to-list 'pulsar-pulse-functions 'flymake-goto-next-error)
  (add-to-list 'pulsar-pulse-functions 'flymake-goto-prev-error)
  (add-to-list 'pulsar-pulse-functions 'evil-yank)
  (add-to-list 'pulsar-pulse-functions 'evil-yank-line)
  (add-to-list 'pulsar-pulse-functions 'evil-delete)
  (add-to-list 'pulsar-pulse-functions 'evil-delete-line)
  (add-to-list 'pulsar-pulse-functions 'evil-jump-item)
  (add-to-list 'pulsar-pulse-functions 'diff-hl-next-hunk)
  (add-to-list 'pulsar-pulse-functions 'diff-hl-previous-hunk))

;;; DOOM MODELINE
;; The `doom-modeline' package provides a sleek, modern mode-line that is visually appealing
;; and functional. It integrates well with various Emacs features, enhancing the overall user
;; experience by displaying relevant information in a compact format.
;; (use-package doom-modeline
;;   :ensure t
;;   :straight t
;;   :defer t
;;   :custom
;;   (doom-modeline-buffer-file-name-style 'buffer-name)  ;; Set the buffer file name style to just the buffer name (without path).
;;   (doom-modeline-project-detection 'project)           ;; Enable project detection for displaying the project name.
;;   (doom-modeline-buffer-name t)                        ;; Show the buffer name in the mode line.
;;   (doom-modeline-vcs-max-length 25)                    ;; Limit the version control system (VCS) branch name length to 25 characters.
;;   :config
;;   (if ek-use-nerd-fonts                                ;; Check if nerd fonts are being used.
;;       (setq doom-modeline-icon t)                      ;; Enable icons in the mode line if nerd fonts are used.
;;     (setq doom-modeline-icon nil))                     ;; Disable icons if nerd fonts are not being used.
;;   :hook
;;   (after-init . doom-modeline-mode))

(use-package evil-org
  :ensure t
  :straight t
  :after org
  :hook (org-mode . (lambda () evil-org-mode))
  :config
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys))

;;; NEOTREE
;; The `neotree' package provides a file tree explorer for Emacs, allowing easy navigation
;; through directories and files. It presents a visual representation of the file system
;; and integrates with version control to show file states.
;; (use-package neotree
;;   :ensure t
;;   :straight t
;;   :custom
;;   (neo-show-hidden-files t)                ;; By default shows hidden files (toggle with H)
;;   (neo-theme 'nerd)                        ;; Set the default theme for Neotree to 'nerd' for a visually appealing look.
;;   (neo-vc-integration '(face char))        ;; Enable VC integration to display file states with faces (color coding) and characters (icons).
;;   :defer t                                 ;; Load the package only when needed to improve startup time.
;;   :config
;;   (if ek-use-nerd-fonts                    ;; Check if nerd fonts are being used.
;;       (setq neo-theme 'nerd-icons)         ;; Set the theme to 'nerd-icons' if nerd fonts are available.
;;     (setq neo-theme 'nerd)))               ;; Otherwise, fall back to the 'nerd' theme.

;;; NERD ICONS
;; The `nerd-icons' package provides a set of icons for use in Emacs. These icons can
;; enhance the visual appearance of various modes and packages, making it easier to
;; distinguish between different file types and functionalities.
(use-package nerd-icons
  :if ek-use-nerd-fonts                   ;; Load the package only if the user has configured to use nerd fonts.
  :ensure t                               ;; Ensure the package is installed.
  :straight t
  :defer t)                               ;; Load the package only when needed to improve startup time.

 ;;; NERD ICONS Dired
;; The `nerd-icons-dired' package integrates nerd icons into the Dired mode,
;; providing visual icons for files and directories. This enhances the Dired
;; interface by making it easier to identify file types at a glance.
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

;;; CATPPUCCIN THEME
;; The `catppuccin-theme' package provides a visually pleasing color theme
;; for Emacs that is inspired by the popular Catppuccin color palette.
;; This theme aims to create a comfortable and aesthetic coding environment
;; with soft colors that are easy on the eyes.
;; (use-package catppuccin-theme
;;   :ensure t
;;   :straight t
;;   :config
;;   (custom-set-faces
;;    ;; Set the color for changes in the diff highlighting to blue.
;;    `(diff-hl-change ((t (:background unspecified :foreground ,(catppuccin-get-color 'blue))))))

;;   (custom-set-faces
;;    ;; Set the color for deletions in the diff highlighting to red.
;;    `(diff-hl-delete ((t (:background unspecified :foreground ,(catppuccin-get-color 'red))))))

;;   (custom-set-faces
;;    ;; Set the color for insertions in the diff highlighting to green.
;;    `(diff-hl-insert ((t (:background unspecified :foreground ,(catppuccin-get-color 'green))))))

;;   ;; Load the Catppuccin theme without prompting for confirmation.
;;   (load-theme 'catppuccin :no-confirm))

;;; UTILITARY FUNCTION TO INSTALL EMACS-KICK
(defun ek/first-install ()
  "Install tree-sitter grammars and compile packages on first run..."
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

(provide 'init)
;;; init.el ends here

(use-package org-modern
  :ensure t
  :straight t)
(with-eval-after-load 'org (global-org-modern-mode))

(setq org-modern-star 'fold)
(setq org-modern-fold-stars '(("◉" . "○")))
(setq org-modern-star 'replace)
(setq org-modern-replace-stars "◉○◉○◉")

(require 'battery)
(require 'nerd-icons)

(defface my-battery-charging
  '((t :inherit success))
  "Face for charging battery.")

(defface my-battery-full
  '((t :inherit success))
  "Face for full battery.")

(defface my-battery-normal
  '((t :inherit mode-line))
  "Face for normal battery.")

(defface my-battery-warning
  '((t :inherit warning))
  "Face for low battery.")

(defface my-battery-critical
  '((t :inherit error))
  "Face for critical battery.")

(defface my-battery-error
  '((t :inherit error))
  "Face for battery error.")

(defvar my-battery-string nil)

(defun my-update-battery ()
  (setq my-battery-string
        (when (bound-and-true-p display-battery-mode)
          (let* ((data (and battery-status-function
                            (functionp battery-status-function)
                            (funcall battery-status-function)))
                 (status (cdr (assoc ?L data)))
                 (charging? (or (string-equal "AC" status)
                                (string-equal "on-line" status)))
                 (percentage (car (read-from-string (or (cdr (assq ?p data)) "ERR"))))
                 (valid? (and (numberp percentage)
                              (>= percentage 0)
                              (<= percentage battery-mode-line-limit)))
                 (face (if valid?
                           (cond (charging? 'my-battery-charging)
                                 ((< percentage battery-load-critical) 'my-battery-critical)
                                 ((< percentage 25) 'my-battery-warning)
                                 ((< percentage 95) 'my-battery-normal)
                                 (t 'my-battery-full))
                         'my-battery-error))
                 (icon (if valid?
                           (cond
                            ((>= percentage 100)
                             (if charging?
                                 (nerd-icons-mdicon "nf-md-battery_charging_100" :face face)
                               (nerd-icons-mdicon "nf-md-battery" :face face)))
                            ((>= percentage 90)
                             (if charging?
                                 (nerd-icons-mdicon "nf-md-battery_charging_90" :face face)
                               (nerd-icons-mdicon "nf-md-battery_90" :face face)))
                            ((>= percentage 80)
                             (if charging?
                                 (nerd-icons-mdicon "nf-md-battery_charging_80" :face face)
                               (nerd-icons-mdicon "nf-md-battery_80" :face face)))
                            ((>= percentage 70)
                             (if charging?
                                 (nerd-icons-mdicon "nf-md-battery_charging_70" :face face)
                               (nerd-icons-mdicon "nf-md-battery_70" :face face)))
                            ((>= percentage 60)
                             (if charging?
                                 (nerd-icons-mdicon "nf-md-battery_charging_60" :face face)
                               (nerd-icons-mdicon "nf-md-battery_60" :face face)))
                            ((>= percentage 50)
                             (if charging?
                                 (nerd-icons-mdicon "nf-md-battery_charging_50" :face face)
                               (nerd-icons-mdicon "nf-md-battery_50" :face face)))
                            ((>= percentage 40)
                             (if charging?
                                 (nerd-icons-mdicon "nf-md-battery_charging_40" :face face)
                               (nerd-icons-mdicon "nf-md-battery_40" :face face)))
                            ((>= percentage 30)
                             (if charging?
                                 (nerd-icons-mdicon "nf-md-battery_charging_30" :face face)
                               (nerd-icons-mdicon "nf-md-battery_30" :face face)))
                            ((>= percentage 20)
                             (if charging?
                                 (nerd-icons-mdicon "nf-md-battery_charging_20" :face face)
                               (nerd-icons-mdicon "nf-md-battery_20" :face face)))
                            ((>= percentage 10)
                             (if charging?
                                 (nerd-icons-mdicon "nf-md-battery_charging_10" :face face)
                               (nerd-icons-mdicon "nf-md-battery_10" :face face)))
                            (t (if charging?
                                   (nerd-icons-mdicon "nf-md-battery_charging_outline" :face face)
                                 (nerd-icons-mdicon "nf-md-battery_outline" :face face))))
                         (nerd-icons-mdicon "nf-md-battery_alert" :face face)))
                 (text (if valid? (format " %d%%" percentage) " N/A"))
                 (help-echo (if (and battery-echo-area-format data valid?)
                                (battery-format battery-echo-area-format data)
                              "Battery status not available")))
            (concat (propertize icon 'help-echo help-echo)
                    (propertize text 'face face 'help-echo help-echo))))))

(defun my-override-battery ()
  (when (bound-and-true-p display-battery-mode)
    (advice-add #'battery-update :after #'my-update-battery)
    (setq global-mode-string (delq 'battery-mode-line-string global-mode-string))
    (my-update-battery)))

(add-hook 'display-battery-mode-hook #'my-override-battery)

(display-time-mode 1)
(display-battery-mode 1)

(defvar lsp-modeline--code-actions-string nil)

(setq-default header-line-format
  '("%e"
	(:propertize " " display (raise +0.4))
	(:propertize " " display (raise -0.4))

	(:propertize "λ " face font-lock-comment-face)
	mode-line-frame-identification
	mode-line-buffer-identification

	(:eval (when-let (vc vc-mode)
			 (list (propertize "   " 'face 'font-lock-comment-face)
				   (propertize (truncate-string-to-width
                                (substring vc 5) 50)
							   'face 'font-lock-comment-face))))

	(:propertize "  %4l:%c" face mode-line-buffer-id)

	(:eval (propertize
			 " " 'display
			 `((space :align-to
					  (-  (+ right right-fringe right-margin)
						 ,(+ 3
                             (string-width (or my-battery-string ""))
                             (string-width (or display-time-string ""))))))))

    (:eval my-battery-string)
	" "
	(:eval display-time-string)))

(setq-default mode-line-format nil)

(use-package hide-mode-line
  :straight t
  :defer t
  :bind (:map custom-bindings-map ("C-c h m" . hide-mode-line-mode)))

(use-package adaptive-wrap
  :defer t
  :hook (visual-line-mode . adaptive-wrap-prefix-mode))

(setq package-gnupghome-dir "~/.gnupg")

(blink-cursor-mode        0)
(setq-default cursor-type 'bar)

(setq my-whitespace-style '(face tabs lines-tail)
      whitespace-style my-whitespace-style
      whitespace-line-column 120
      fill-column 120
      whitespace-display-mappings
      '((space-mark 32 [183] [46])
        (newline-mark 10 [36 10])
        (tab-mark 9 [9655 9] [92 9])))

;; in e.g. clojure-mode-hook
;; (whitespace-mode 1)
;; or globally
;; (global-whitespace-mode 1)
(add-hook 'prog-mode 'whitespace-mode)

(defvar cashmere/font-height 170)

(when (member "Fragment Mono" (font-family-list))
  (set-face-attribute 'default nil :font "Fragment Mono" :height cashmere/font-height)
  (set-face-attribute 'fixed-pitch nil :family "Fragment Mono" :height cashmere/font-height))

(when (member "Open Sans" (font-family-list))
  (set-face-attribute 'variable-pitch nil :family "Open Sans" :height cashmere/font-height))

(use-package mixed-pitch
  :straight t
  :defer t
  :hook ((org-mode   . mixed-pitch-mode)
         (LaTeX-mode . mixed-pitch-mode)))

(use-package autothemer
  :straight t
  :defer t)

(use-package doom-themes
:straight t
:ensure t
:custom
;; Global settings (defaults)
(doom-themes-enable-bold t)   ; if nil, bold is universally disabled
(doom-themes-enable-italic t) ; if nil, italics is universally disabled
;; for treemacs users
(doom-themes-treemacs-theme "doom-nord-light") ; use "doom-colors" for less minimal icon theme
:config
(load-theme 'doom-nord-light t)

;; Enable flashing mode-line on errors
(doom-themes-visual-bell-config)
;; Enable custom neotree theme (nerd-icons must be installed!)
(doom-themes-neotree-config)
;; or for treemacs users
(doom-themes-treemacs-config)
;; Corrects (and improves) org-mode's native fontification.
(doom-themes-org-config))

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

(use-package nix-mode
  :ensure t
  :mode "\\.nix\\'")

(use-package olivetti
  :defer t)

(setq-default olivetti-body-width 95)
(define-globalized-minor-mode my-global-olivetti-mode olivetti-mode
  (lambda () (olivetti-mode 1)))
(my-global-olivetti-mode)

(setq ibuffer-never-show-predicates
      '(;; System buffers
        "^\\*Messages\\*$"
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

(use-package eat
  :ensure t
  :defer t
  :config
  (when (fboundp 'eat-global-mode)
    (eat-global-mode)
    (setq eat-kill-buffer-on-exit t)))

(use-package projectile
  :ensure t
  :straight t
  :demand t
  :config
  (projectile-mode +1)
  (setq projectile-completion-system 'default
        projectile-enable-caching t
        projectile-indexing-method 'alien
        projectile-sort-order 'recentf
        projectile-require-project-root nil))

(use-package consult-projectile
  :ensure t
  :straight t
  :after (consult projectile)
  :config
  (setq consult-project-function #'projectile-project-root))

(defun my/smart-find-file ()
  (interactive)
  (if (projectile-project-p)
      (projectile-find-file)
    (consult-buffer)))

(my-leader
  "sp" '(consult-ripgrep :wk "search project")
  "/" '(consult-line :wk "search buffer")
  "." '(find-file :wk "find file")
  "," '(consult-buffer :wk "switch buffer")
  "SPC" '(my/smart-find-file :wk "find file/buffer")
  ":" (lambda () (interactive) (execute-extended-command nil))
  
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
  "pd" '(projectile-dired :wk "root dir")
  "pr" '(projectile-recentf :wk "recent files")
  "pa" '(projectile-add-known-project :wk "add project")
  "pc" '(projectile-compile-project :wk "compile")
  "pt" '(projectile-test-project :wk "test")
  "pi" '(projectile-invalidate-cache :wk "invalidate cache")
  
  "g" '(:ignore t :wk "git")
  "gg" '(magit-status :wk "status")
  "gl" '(magit-log-current :wk "log")
  "gd" '(magit-diff-buffer-file :wk "diff file")
  "gs" '(magit-status :wk "status")
  "gb" '(vc-annotate :wk "blame")
  
  "o" '(:ignore t :wk "open")
  "op" '(neotree-toggle :wk "neotree")
  "oP" '(dired-jump :wk "dired")
  "od" '(dirvish :wk "dirvish")
  
  "h" '(:ignore t :wk "help")
  "hm" '(describe-mode :wk "mode")
  "hf" '(describe-function :wk "function")
  "hv" '(describe-variable :wk "variable")
  "hk" '(describe-key :wk "key")
  
  "y" '(:ignore t :wk "yank to kill-ring")
  "yy" (lambda ()
         (interactive)
         (kill-new (buffer-substring (line-beginning-position) (line-end-position)))
         (message "Yanked line to kill-ring"))
  "yw" (lambda ()
         (interactive)
         (kill-new (thing-at-point 'word))
         (message "Yanked word to kill-ring"))
  
  "w" '(:ignore t :wk "windows")
  "wv" '(split-window-right :wk "split right")
  "ws" '(split-window-below :wk "split below")
  "wd" '(delete-window :wk "delete")
  "wo" '(delete-other-windows :wk "delete others")
  
  "c" '(:ignore t :wk "code")
  
  "m" '(:ignore t :wk "mode")
  "mp" (list (lambda ()
               (interactive)
               (shell-command (concat "prettier --write " 
                                    (shell-quote-argument (buffer-file-name))))
               (revert-buffer t t t))
             :wk "format prettier")
  
  "q" '(:ignore t :wk "quit")
  "qq" '(save-buffers-kill-terminal :wk "quit emacs")
  "qr" '(restart-emacs :wk "restart")
  
  "a" '(embark-act :wk "embark")
  "u" '(undo-tree-visualize :wk "undo tree")
  "P" '(consult-yank-from-kill-ring :wk "paste history"))

(my-local-leader
  "t" '(eat :wk "terminal"))

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
  "K" (if (>= emacs-major-version 31)
          #'eldoc-box-help-at-point
        #'ek/lsp-describe-and-jump)
  "gcc" (lambda ()
          (interactive)
          (unless (use-region-p)
            (comment-or-uncomment-region 
             (line-beginning-position) 
             (line-end-position))))
  )

(general-def 'visual 'override
  "gc" (lambda ()
         (interactive)
         (when (use-region-p)
           (comment-or-uncomment-region 
            (region-beginning) 
            (region-end)))))

(general-def '(normal visual) 'override
  "s" (lambda ()
        (interactive)
        (let ((avy-all-windows t)
              (avy-background t)
              (scroll-margin 0)
              (maximum-scroll-margin 0))
          (call-interactively 'avy-goto-char-timer))))

(general-def 'normal dirvish-mode-map
  "?" 'dirvish-dispatch
  "q" 'dirvish-quit
  "b" 'dirvish-quick-access
  "f" 'dirvish-file-info-menu
  "p" 'dirvish-yank
  "S" 'dirvish-quicksort
  "F" 'dirvish-layout-toggle
  "z" 'dirvish-history-jump
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
  :keymaps 'org-mode-map
  "h" '(consult-org-heading :wk "search headings"))

(define-key minibuffer-local-map [escape] 'abort-recursive-edit)
(define-key minibuffer-local-ns-map [escape] 'abort-recursive-edit)
(define-key minibuffer-local-completion-map [escape] 'abort-recursive-edit)
(define-key minibuffer-local-must-match-map [escape] 'abort-recursive-edit)
(define-key minibuffer-local-isearch-map [escape] 'abort-recursive-edit)
