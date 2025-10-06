;;; config.el --- Emacs-Kick --- A feature rich Emacs config for (neo)vi(m)mers -*- lexical-binding: t; -*-
(setq gc-cons-threshold #x40000000)

(setq read-process-output-max (* 1024 1024 4))

(setq package-enable-at-startup nil)

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
  (pixel-scroll-precision-mode t)                 ;; Enable precise pixel scrolling.
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

(use-package flymake
:straight nil
    :ensure nil          ;; This is built-in, no need to fetch it.
    :defer t
    :hook (prog-mode . flymake-mode)
    :custom
    (flymake-margin-indicators-string
    '((error "!»" compilation-error) (warning "»" compilation-warning)
	(note "»" compilation-info))))

(use-package org
:straight nil
    :ensure nil     ;; This is built-in, no need to fetch it.
    :defer t
    :config
    (require 'org-tempo))

(use-package which-key
:straight nil
    :ensure nil     ;; This is built-in, no need to fetch it.
    :defer t        ;; Defer loading Which-Key until after init.
    :hook
    (after-init . which-key-mode)) ;; Enable which-key mode after initialization.

      (setq which-key-idle-delay 0.001)

(use-package vertico
    :ensure t
    :straight t
    :hook
    (after-init . vertico-mode)           ;; Enable vertico after Emacs has initialized.
    :custom
    (vertico-count 10)                    ;; Number of candidates to display in the completion list.
    (vertico-resize nil)                  ;; Disable resizing of the vertico minibuffer.
    (vertico-cycle nil)                   ;; Do not cycle through candidates when reaching the end of the list.
    :config
    ;; Customize the display of the current candidate in the completion list.
    ;; This will prefix the current candidate with “» ” to make it stand out.
    ;; Reference: https://github.com/minad/vertico/wiki#prefix-current-candidate-with-arrow
    (advice-add #'vertico--format-candidate :around
		(lambda (orig cand prefix suffix index _start)
		(setq cand (funcall orig cand prefix suffix index _start))
		(concat
		    (if (= vertico--index index)
			(propertize "» " 'face '(:foreground "#80adf0" :weight bold))
		    "  ")
		    cand))))

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
  ;; Enhance register preview with thin lines and no mode line.
  (advice-add #'register-preview :override #'consult-register-window)

  ;; Use Consult for xref locations with a preview feature.
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref))

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
  (corfu-auto nil)                        ;; Only completes when hitting TAB
  ;; (corfu-auto-delay 0)                ;; Delay before popup (enable if corfu-auto is t)
  (corfu-auto-prefix 1)                  ;; Trigger completion after typing 1 character
  (corfu-quit-no-match t)                ;; Quit popup if no match
  (corfu-scroll-margin 5)                ;; Margin when scrolling completions
  (corfu-max-width 50)                   ;; Maximum width of completion popup
  (corfu-min-width 50)                   ;; Minimum width of completion popup
  (corfu-popupinfo-delay 0.5)            ;; Delay before showing documentation popup
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

(use-package lsp-mode
    :ensure t
    :straight t
    :defer t
    :hook (;; Replace XXX-mode with concrete major mode (e.g. python-mode)
	    (lsp-mode . lsp-enable-which-key-integration)  ;; Integrate with Which Key
	    ((js-mode                                      ;; Enable LSP for JavaScript
	    tsx-ts-mode                                  ;; Enable LSP for TSX
	    typescript-ts-base-mode                      ;; Enable LSP for TypeScript
	    css-mode                                     ;; Enable LSP for CSS
	    go-ts-mode                                   ;; Enable LSP for Go
	    js-ts-mode                                   ;; Enable LSP for JavaScript (TS mode)
	    prisma-mode                                  ;; Enable LSP for Prisma
	    python-base-mode                             ;; Enable LSP for Python
	    ruby-base-mode                               ;; Enable LSP for Ruby
	    rust-ts-mode                                 ;; Enable LSP for Rust
		nix-mode
	    web-mode) . lsp-deferred))                   ;; Enable LSP for Web (HTML)
    :commands lsp
    :custom
    (lsp-keymap-prefix "C-c l")                           ;; Set the prefix for LSP commands.
    (lsp-inlay-hint-enable nil)                           ;; Usage of inlay hints.
    (lsp-completion-provider :none)                       ;; Disable the default completion provider.
    (lsp-session-file (locate-user-emacs-file ".lsp-session")) ;; Specify session file location.
    (lsp-log-io nil)                                      ;; Disable IO logging for speed.
    (lsp-idle-delay 0.5)                                  ;; Set the delay for LSP to 0 (debouncing).
    (lsp-keep-workspace-alive nil)                        ;; Disable keeping the workspace alive.
    ;; Core settings
    (lsp-enable-xref t)                                   ;; Enable cross-references.
    (lsp-auto-configure t)                                ;; Automatically configure LSP.
    (lsp-enable-links nil)                                ;; Disable links.
    (lsp-eldoc-enable-hover t)                            ;; Enable ElDoc hover.
    (lsp-enable-file-watchers nil)                        ;; Disable file watchers.
    (lsp-enable-folding nil)                              ;; Disable folding.
    (lsp-enable-imenu t)                                  ;; Enable Imenu support.
    (lsp-enable-indentation nil)                          ;; Disable indentation.
    (lsp-enable-on-type-formatting nil)                   ;; Disable on-type formatting.
    (lsp-enable-suggest-server-download t)                ;; Enable server download suggestion.
    (lsp-enable-symbol-highlighting t)                    ;; Enable symbol highlighting.
    (lsp-enable-text-document-color t)                    ;; Enable text document color.
    ;; Modeline settings
    (lsp-modeline-code-actions-enable nil)                ;; Keep modeline clean.
    (lsp-modeline-diagnostics-enable nil)                 ;; Use `flymake' instead.
    (lsp-modeline-workspace-status-enable t)              ;; Display "LSP" in the modeline when enabled.
    (lsp-signature-doc-lines 1)                           ;; Limit echo area to one line.
    (lsp-eldoc-render-all t)                              ;; Render all ElDoc messages.
    ;; Completion settings
    (lsp-completion-enable t)                             ;; Enable completion.
    (lsp-completion-enable-additional-text-edit t)        ;; Enable additional text edits for completions.
    (lsp-enable-snippet nil)                              ;; Disable snippets
    (lsp-completion-show-kind t)                          ;; Show kind in completions.
    ;; Lens settings
    (lsp-lens-enable t)                                   ;; Enable lens support.
    ;; Headerline settings
    (lsp-headerline-breadcrumb-enable-symbol-numbers t)   ;; Enable symbol numbers in the headerline.
    (lsp-headerline-arrow "▶")                            ;; Set arrow for headerline.
    (lsp-headerline-breadcrumb-enable-diagnostics nil)    ;; Disable diagnostics in headerline.
    (lsp-headerline-breadcrumb-icons-enable nil)          ;; Disable icons in breadcrumb.
    ;; Semantic settings
    (lsp-semantic-tokens-enable nil))                     ;; Disable semantic tokens.


        ;;; LSP Additional Servers
        ;; You can extend `lsp-mode' by integrating additional language servers for specific
        ;; technologies. For example, `lsp-tailwindcss' provides support for Tailwind CSS
        ;; classes within your HTML files. By using various LSP packages, you can connect
        ;; multiple LSP servers simultaneously, enhancing your coding experience across
        ;; different languages and frameworks.
        (use-package lsp-tailwindcss
          :ensure t
          :straight t
          :defer t
          :config
          (add-to-list 'lsp-language-id-configuration '(".*\\.erb$" . "html")) ;; Associate ERB files with HTML.
          :init
          (setq lsp-tailwindcss-add-on-mode t))

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
  :init
  (setq evil-want-integration t
        evil-want-keybinding nil
        evil-want-C-u-scroll t
        evil-want-C-u-delete t)
  :config
  (evil-set-undo-system 'undo-tree)
  (setq evil-leader/in-all-states t
        evil-want-fine-undo t)
  
  (my-leader
    "sp" 'consult-ripgrep
    "/" 'consult-line
    "." 'find-file
    "," 'consult-buffer
    "SPC" 'consult-buffer
    ":" (lambda () (interactive) (execute-extended-command nil))
    
    "f" '(:ignore t :wk "file")
    "fd" 'dired
    "fD" 'dired-jump
    "fr" 'consult-buffer
    "ff" 'find-file
    "fs" 'save-buffer
    
    "b" '(:ignore t :wk "buffer")
    "bb" 'consult-buffer
    "bi" 'ibuffer
    "bd" 'kill-current-buffer
    "bk" 'kill-current-buffer
    "bx" 'kill-current-buffer
    "bs" 'save-buffer
    
    "p" '(:ignore t :wk "project")
    "pb" 'consult-project-buffer
    "pp" 'project-switch-project
    "pf" 'project-find-file
    "ps" 'project-find-regexp
    "pk" 'project-kill-buffers
    "pd" 'project-dired
    
    "g" '(:ignore t :wk "git")
    "gg" 'magit-status
    "gl" 'magit-log-current
    "gd" 'magit-diff-buffer-file
    "gs" 'magit-status
    "gb" 'vc-annotate
    
    "o" '(:ignore t :wk "open")
    "op" 'neotree-toggle
    "oP" 'dired-jump
    
    "h" '(:ignore t :wk "help")
    "hm" 'describe-mode
    "hf" 'describe-function
    "hv" 'describe-variable
    "hk" 'describe-key
    
    "w" '(:ignore t :wk "window")
    "wv" 'split-window-right
    "ws" 'split-window-below
    "wd" 'delete-window
    "wo" 'delete-other-windows
    
    "c" '(:ignore t :wk "code")
    
    "m" '(:ignore t :wk "mode")
    "mp" (lambda ()
           (interactive)
           (shell-command (concat "prettier --write " 
                                  (shell-quote-argument (buffer-file-name))))
           (revert-buffer t t t))
    
    "q" '(:ignore t :wk "quit")
    "qq" 'save-buffers-kill-terminal
    
    "a" 'embark-act
    "u" 'undo-tree-visualize
    "P" 'consult-yank-from-kill-ring)
  
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
               (line-end-position)))))
  
  (general-def 'visual 'override
    "gc" (lambda ()
           (interactive)
           (when (use-region-p)
             (comment-or-uncomment-region 
              (region-beginning) 
              (region-end)))))
  
  (defun ek/lsp-describe-and-jump ()
    (interactive)
    (lsp-describe-thing-at-point)
    (let ((help-buffer "*lsp-help*"))
      (when (get-buffer help-buffer)
        (switch-to-buffer-other-window help-buffer))))

  (evil-mode 1))
(define-key minibuffer-local-map [escape] 'abort-recursive-edit)
(define-key minibuffer-local-ns-map [escape] 'abort-recursive-edit)
(define-key minibuffer-local-completion-map [escape] 'abort-recursive-edit)
(define-key minibuffer-local-must-match-map [escape] 'abort-recursive-edit)
(define-key minibuffer-local-isearch-map [escape] 'abort-recursive-edit)

(use-package avy
    :ensure t
    :straight t
    :after evil
    :general
    (my-local-leader
	  "d" 'dirvish)

    (general-def 'normal 'override
    "s" 'avy-goto-char-timer)

    :config
    (setq avy-all-windows t
	avy-case-fold-search t
	avy-timeout-seconds 0.39))

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
(use-package neotree
  :ensure t
  :straight t
  :custom
  (neo-show-hidden-files t)                ;; By default shows hidden files (toggle with H)
  (neo-theme 'nerd)                        ;; Set the default theme for Neotree to 'nerd' for a visually appealing look.
  (neo-vc-integration '(face char))        ;; Enable VC integration to display file states with faces (color coding) and characters (icons).
  :defer t                                 ;; Load the package only when needed to improve startup time.
  :config
  (if ek-use-nerd-fonts                    ;; Check if nerd fonts are being used.
      (setq neo-theme 'nerd-icons)         ;; Set the theme to 'nerd-icons' if nerd fonts are available.
    (setq neo-theme 'nerd)))               ;; Otherwise, fall back to the 'nerd' theme.

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

(defvar cashmere/font-height 200)

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

(add-to-list 'default-frame-alist '(alpha-background . 90))

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
  (setq dired-mouse-drag-files t)
  
  (general-define-key
   :states 'normal
   :keymaps 'dirvish-mode-map
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
   "TAB" 'dirvish-subtree-toggle)
  
  (general-define-key
   :states '(normal visual motion)
   :keymaps 'dirvish-mode-map
   "[h" 'dirvish-history-go-backward
   "]h" 'dirvish-history-go-forward
   "[e" 'dirvish-emerge-next-group
   "]e" 'dirvish-emerge-previous-group
   "M-b" 'dirvish-history-go-backward
   "M-f" 'dirvish-history-go-forward
   "M-n" 'dirvish-narrow
   "M-m" 'dirvish-mark-menu
   "M-s" 'dirvish-setup-menu
   "M-e" 'dirvish-emerge-menu)
  
  (general-define-key
   :states 'normal
   :keymaps 'dirvish-mode-map
   :prefix "y"
   "l" 'dirvish-copy-file-true-path
   "n" 'dirvish-copy-file-name
   "p" 'dirvish-copy-file-path
   "r" 'dirvish-copy-remote-path
   "y" 'dired-do-copy)
  
  (general-define-key
   :states 'normal
   :keymaps 'dirvish-mode-map
   :prefix "s"
   "s" 'dirvish-symlink
   "S" 'dirvish-relative-symlink
   "h" 'dirvish-hardlink))

(use-package nix-mode
  :ensure t
  :mode "\\.nix\\'")
