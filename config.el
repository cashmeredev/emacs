;;; config.el --- Emacs-Kick --- A feature rich Emacs config for (neo)vi(m)mers -*- lexical-binding: t; -*-
(setenv "LSP_USE_PLISTS" "true")
;; (setq debug-on-error t)
;; (setenv "LSP_USE_PLISTS" "true")
;; (setq lsp-use-plists t)
(setq pgtk-wait-for-event-timeout 0.001)
(setq package-enable-at-startup nil)
;; (setq-default mode-line-format t) ;; disabled: boolean t is not valid for mode-line-format
(setq default-frame-alist '((undecorated . t)))
;; GC + file-name-handler-alist tuning lives in early-init.el now.
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

(eval-and-compile
  (defvar my/local-packages nil
    "Alist of (PACKAGE . DIRECTORY) loaded from a local checkout.
Set per-host in the gitignored `local.el'.")
  (load (locate-user-emacs-file "local.el") 'noerror 'nomessage))

(dolist (entry my/local-packages)
  (add-to-list 'load-path (expand-file-name (cdr entry))))

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

(defun my/elpaca-skip-local (orig name _keyword args)
  (if (assq name my/local-packages)
      nil
    (funcall orig name _keyword args)))
(advice-add 'use-package-normalize/:ensure :around #'my/elpaca-skip-local)

(use-package emacs
  :ensure nil
  :custom
  (column-number-mode t)
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
  (text-mode-ispell-word-completion nil) ;; Stop ispell capf in text/org buffers (no wordlist on NixOS → corfu errors).
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
  (markdown-mode . display-line-numbers-mode)
  (text-mode . visual-line-mode)       ;; Soft-wrap prose/text files at window edge.
  (conf-mode . visual-line-mode)       ;; Soft-wrap .conf and similar config files.

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
  (global-hl-line-mode 1) ;; Highlight the current line
  (add-hook 'org-mode-hook (lambda () (setq-local global-hl-line-mode nil))) ;; hl-line repaints wipe kitty-graphics scaled headings
  (add-hook 'markdown-mode-hook (lambda () (setq-local global-hl-line-mode nil))) ;; same conflict for kitty-graphics markdown headings
  (global-auto-revert-mode 1) ;; Enable global auto-revert mode to keep buffers up to date with their corresponding files.
  (setq-default indent-tabs-mode nil)
  (when (daemonp)
    (recentf-mode 1) ;; Enable tracking of recently opened files.
    (savehist-mode 1) ;; Enable saving of command history.
    (save-place-mode 1)) ;; Enable saving the place in files for easier return.
  (winner-mode 1) ;; Enable winner mode to easily undo window configuration changes.
  (xterm-mouse-mode 1) ;; Enable mouse support in terminal mode.
  (file-name-shadow-mode 1) ;; Enable shadowing of filenames for clarity.
  (repeat-mode 1) ;; Enable repeat key after key chord

  ;;oding system for files to UTF-8.
  (modify-coding-system-alist 'file "" 'utf-8)

  ;; Add a hook to run code after Emacs has fully initialized.
  (add-hook 'after-init-hook
			(lambda ()
			  (message "Emacs has fully loaded. This code runs after startup.")

			  ;; Insert a welcome message in the *scratch* buffer displaying loading time and activated packages.
			  (with-current-buffer (get-buffer-create "*scratch*")
				(insert (format
						 ";; Welcome to Emacs!
;;
;; Loading time : %s
;; Packages : %s
"
						 (emacs-init-time)
						 (length (elpaca--queued))))))))


(defcustom ek-use-nerd-fonts t
  "Configuration for using Nerd Fonts Symbols."
  :type 'boolean
  :group 'appearance)

(when (eq system-type 'berkeley-unix)
  ;; Start the Emacs server so emacsclient (and pinentry-emacs) can connect.
  (require 'server)
  (unless (server-running-p)
    (server-start))

  ;; Handler for pinentry-emacs: GPG passphrase prompts in the minibuffer.
  (defun pinentry-emacs (desc prompt _ok _error)
    (read-passwd
     (concat (replace-regexp-in-string "%22" "\""
              (replace-regexp-in-string "%0A" "\n" desc))
             prompt ": ")))

  ;; Open a file as root via doas.
  (defun my/find-file-doas (filename)
    "Open FILENAME as root using doas."
    (interactive "FFile (with doas): ")
    (find-file (concat "/doas::" (expand-file-name filename)))))

(defun my/compilation-buffer-p (buffer-name _action)
  "Match any compilation-derived buffer (compile, grep, …) for display."
  (with-current-buffer buffer-name
    (derived-mode-p 'compilation-mode)))

(defun my/compile-or-recompile ()
  "Recompile with the last command if a ghostel compilation ran before, else prompt.
Selects the compilation window so the cursor lands in it."
  (interactive)
  (if (get-buffer ghostel-compile-buffer-name)
      (ghostel-recompile)
    (call-interactively #'ghostel-compile))
  (let ((buffer (get-buffer ghostel-compile-buffer-name)))
    (when buffer
      (pop-to-buffer buffer))))

(defun my/focus-async-shell-window (window)
  "Focus the async-shell window and make q bury it without killing the process."
  (select-window window)
  (with-current-buffer (window-buffer window)
    (evil-local-set-key 'normal (kbd "q") #'quit-window)
    (evil-local-set-key 'motion (kbd "q") #'quit-window)
    (evil-normal-state)))

(use-package window
  :ensure nil
  :custom
  (display-buffer-alist
   '(
     (my/compilation-buffer-p
      (display-buffer-reuse-window display-buffer-below-selected)
      (window-height . 0.3)
      (body-function . select-window))

     ("\\*Async Shell Command\\*"
      (display-buffer-reuse-window display-buffer-below-selected)
      (window-height . 0.3)
      (body-function . my/focus-async-shell-window))

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
  :ensure nil
  :custom
  (dired-listing-switches "-lah --group-directories-first")
  (dired-dwim-target t)
  (dired-guess-shell-alist-user
   '(("\\.\\(mp[34]\\|m4a\\|ogg\\|flac\\|webm\\|mkv\\)" "mpv" "xdg-open" "open")
     (".*" "open" "xdg-open")))
  (dired-kill-when-opening-new-dired-buffer t)
  (dired-create-destination-dirs 'always)
  :config
  (with-eval-after-load 'async
    (dired-async-mode 1))
  
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
  
  (advice-add 'dired-create-directory :around
              (lambda (orig-fun dirname)
                (let ((current-buffer (current-buffer)))
                  (funcall orig-fun dirname)
                  (with-current-buffer current-buffer
                    (revert-buffer)))))
      
  (when (eq system-type 'darwin)
    (let ((gls (executable-find "gls")))
      (when gls
        (setq insert-directory-program gls)))))

(use-package async :ensure t)

(use-package general
  :ensure (:wait t)
  :demand t
  :config
  (general-evil-setup))

(eval-and-compile
  (require 'general)

  (general-create-definer my-leader
    :states '(normal visual insert)
    :keymaps 'override
    :prefix "SPC"
    :non-normal-prefix "M-SPC")

  (general-create-definer my-local-leader
    :states '(normal visual)
    :keymaps 'override
    :prefix ","))

;; Always-available IRC entry points so `M-x run-irc` works from any daemon
;; (hub, work, standalone). Calling `erc-tls` autoloads ERC on demand.
;; Soju routes to the upstream network via the USER string, so we still need
;; one connection per network. We connect to Libera and Ergo only.
(defun my/soju-password ()
  "Read the Soju bouncer password from the sops-nix secret."
  (string-trim
   (with-temp-buffer
     (insert-file-contents
      "/home/cashmere/.config/sops-nix/secrets/senpai_password")
     (buffer-string))))

(defun run-irc ()
  "Connect to Libera and Ergo via the Soju bouncer."
  (interactive)
  (let ((pw (my/soju-password)))
    (erc-tls :server "bouncer.cashmere.rs"
             :port 6699
             :id 'libera
             :nick "cashmere1337"
             :user "cashmere/irc.libera.chat@emacs"
             :password pw)
    (erc-tls :server "bouncer.cashmere.rs"
             :port 6699
             :id 'ergo
             :nick "cashmere"
             :user "cashmere/ergo@emacs"
             :password pw)))

(use-package erc
  :ensure nil
  :defer t
  :custom
  ;; connection
  (erc-nick "cashmere1337")
  (erc-user-full-name "cashmere")

  ;; behaviour
  (erc-join-buffer 'buffer)
  (erc-kill-buffer-on-part nil)
  (erc-kill-queries-on-quit t)
  (erc-kill-server-buffer-on-quit t)

  ;; visuals
  (erc-fill-function 'erc-fill-wrap)
  (erc-timestamp-format "[%H:%M]")
  (erc-timestamp-format-left "[%H:%M]")
  (erc-timestamp-format-right "[%H:%M]")
  (erc-hide-list '("JOIN" "PART" "QUIT" "NICK" "MODE"))
  (erc-track-exclude-types '("JOIN" "PART" "QUIT" "NICK" "MODE" "324" "329" "332" "333" "353" "477"))
  (erc-track-shorten-start 4)
  (erc-track-visibility 'visible)

  ;; prompt
  (erc-prompt (lambda () (concat (buffer-name) ">")))

  ;; modules
  (erc-modules '(autojoin
                 button
                 completion
                 fill
                 irccontrols
                 list
                 match
                 move-to-prompt
                 netsplit
                 networks
                 nicks
                 noncommands
                 notifications
                 readonly
                 ring
                 scrolltobottom
                 stamp
                 track))
  :config
  ;; highlight own nick
  (setq erc-current-nick-highlight-type 'all)
  (setq erc-keywords '("cashmere"))
  (setq erc-pals '("cashmere"))

  ;; nicks module (built-in nick coloring in Emacs 30)
  (setq erc-nicks-contrast-range '(40 . 90))

  ;; scrolltobottom -- keep input always at bottom
  (setq erc-scrolltobottom-all t)
  (erc-scrolltobottom-mode 1)

  ;; fill-wrap -- modern chat-like wrapping
  (setq erc-fill-wrap-align-prompt nil)
  (setq erc-fill-static-center 14)

  ;; track -- activity NOT in modeline (channels list clutters doom-modeline)
  (setq erc-track-position-in-mode-line nil)

  ;; keep large buffer for soju history replay
  (setq erc-max-buffer-size 100000)

  (erc-update-modules))

(defun my/erc-switch-channel ()
  "Switch to an ERC channel buffer via helm."
  (interactive)
  (require 'helm)
  (helm :sources
        (helm-build-sync-source "IRC"
          :candidates
          (lambda ()
            (mapcar #'buffer-name
                    (cl-remove-if-not
                     (lambda (buf)
                       (with-current-buffer buf
                         (derived-mode-p 'erc-mode)))
                     (buffer-list))))
          :action '(("Switch to buffer" . switch-to-buffer)))
        :buffer "*helm erc*"))

(defun my/erc-fetch-history (&optional count)
  "Fetch COUNT previous messages from Soju via CHATHISTORY.
Defaults to 1000 (soju max). With prefix arg, prompts for count.
Temporarily disables notifications during the fetch."
  (interactive "P")
  (let ((target (erc-default-target)))
    (if (not target)
        (message "Not in a channel buffer.")
      (let ((n (min (if count
                       (read-number "Messages to fetch: " 1000)
                     1000)
                    1000)))
        (erc-notifications-disable)
        (erc-server-send (format "CHATHISTORY LATEST %s * %d" target n))
        (run-at-time 5 nil #'erc-notifications-enable)))))

(defun my/erc-quit-all ()
  "Disconnect from IRC and kill all ERC buffers."
  (interactive)
  (erc-cmd-QUIT "bye")
  (run-at-time 1 nil
               (lambda ()
                 (dolist (buf (buffer-list))
                   (when (with-current-buffer buf (derived-mode-p 'erc-mode))
                     (kill-buffer buf))))))

(defun my/erc-reconnect ()
  "Reconnect to the current ERC server."
  (interactive)
  (erc-cmd-RECONNECT))

(defun my/erc-list-channels ()
  "Request channel list from the current ERC server."
  (interactive)
  (erc-cmd-LIST))

(defun persp-irc ()
  "Switch to (or create) the IRC frame and show ERC buffers."
  (interactive)
  (let* ((erc-bufs (cl-remove-if-not
                    (lambda (buf)
                      (with-current-buffer buf
                        (derived-mode-p 'erc-mode)))
                    (buffer-list)))
         (irc-frame (cl-find-if
                     (lambda (f)
                       (string= (frame-parameter f 'name) "irc"))
                     (frame-list))))
    (if irc-frame
        (select-frame-set-input-focus irc-frame)
      (select-frame-set-input-focus (make-frame '((name . "irc")))))
    (if erc-bufs
        (switch-to-buffer (car erc-bufs))
      (letrec ((hook-fn (lambda ()
                          (switch-to-buffer (current-buffer))
                          (remove-hook 'erc-join-hook hook-fn))))
        (add-hook 'erc-join-hook hook-fn))
      (run-irc))))

(with-eval-after-load 'erc
  (add-hook 'erc-mode-hook
            (lambda ()
              (setq-local scroll-margin 0)
              (setq-local maximum-scroll-margin 0.0)
              (setq-local corfu-auto nil)))

  ;; Prevent accidental ERC buffer kills from parting channels
  (add-hook 'kill-buffer-query-functions
            (lambda ()
              (if (and (derived-mode-p 'erc-mode)
                       (erc-server-process-alive)
                       (not (eq this-command 'my/erc-quit-all)))
                  (yes-or-no-p
                   (format "ERC buffer %s is connected. Really kill (will part channel)? "
                           (buffer-name)))
                t)))

  (general-def 'normal erc-mode-map
    "q"   'quit-window
    "Q"   'my/erc-quit-all
    "gb"  'my/erc-switch-channel
    "gn"  'erc-track-switch-buffer
    "gH"  'my/erc-fetch-history
    "go"  'erc-channel-names
    "gj"  'erc-join-channel
    "gl"  'my/erc-list-channels
    "gr"  'my/erc-reconnect
    "RET" 'erc-send-current-line)

  (general-def '(normal insert) erc-mode-map
    "M-n" 'erc-track-switch-buffer
    "C-k" 'erc-previous-command
    "C-j" 'erc-next-command))

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
            scroll-conservatively 101
            maximum-scroll-margin 0.5
            scroll-margin 99999)
      (setq my/centered-cursor-enabled t)
      (message "centered-cursor on"))))

(use-package clipetty
  :ensure t
  :after evil
  :config
  (setq interprogram-cut-function nil)
  (defun my/send-to-clipboard (text)
    (when (stringp text)
      (if (display-graphic-p)
          (gui-select-text text)
        (clipetty-cut #'ignore text))))
  (defun my/evil-yank-to-clipboard (_beg _end &optional _type register _yank-handler)
    (when (and (not register)
               (memq this-command '(evil-yank evil-yank-line)))
      (my/send-to-clipboard (car kill-ring))))
  (advice-add 'evil-yank :after #'my/evil-yank-to-clipboard)
  (defun my/elfeed-yank-to-clipboard (&rest _)
    (my/send-to-clipboard (car kill-ring)))
  (advice-add 'elfeed-search-yank :after #'my/elfeed-yank-to-clipboard)
  (advice-add 'link-hint-copy-link :after #'my/elfeed-yank-to-clipboard)
  (with-eval-after-load 'pass
    (dolist (cmd '(pass-copy
                   pass-copy-field
                   pass-copy-username
                   pass-copy-url
                   pass-otp-token-copy
                   pass-otp-uri-copy
                   pass-view-copy-password
                   pass-view-copy-token))
      (advice-add cmd :after #'my/elfeed-yank-to-clipboard))))

(use-package isearch
  :ensure nil                                  ;; This is built-in, no need to fetch it.
  :config
  (setq isearch-lazy-count t)                  ;; Enable lazy counting to show current match information.
  (setq lazy-count-prefix-format "(%s/%s) ")   ;; Format for displaying current match count.
  (setq lazy-count-suffix-format nil)          ;; Disable suffix formatting for match count.
  (setq search-whitespace-regexp ".*?")        ;; Allow searching across whitespace.
  :bind (("C-s" . isearch-forward)             ;; Bind C-s to forward isearch.
                 ("C-r" . isearch-backward)))          ;; Bind C-r to backward isearch.

(use-package vc
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
                       (mode . sh-mode)
                       (mode . bash-ts-mode)
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
                      (mode . yaml-ts-mode)))
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
           ("Terminal" (or
                        (mode . ghostel-mode)
                        (mode . eat-mode)
                        (mode . eshell-mode)
                        (mode . shell-mode)
                        (mode . term-mode)))
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
           ("ECA - Editor Code Assistant"
            (or
             (mode . eca-chat-mode)))

           ("IRC" (or (mode . erc-mode)))

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

(use-package nerd-icons
  :if ek-use-nerd-fonts
  :ensure t)

(use-package nerd-icons-ibuffer
  :if ek-use-nerd-fonts
  :ensure t
  :hook (ibuffer-mode . nerd-icons-ibuffer-mode))

(use-package smerge-mode
  :ensure nil                                  ;; This is built-in, no need to fetch it.
  :defer t
  :bind (:map smerge-mode-map
                          ("C-c ^ u" . smerge-keep-upper)  ;; Keep the changes from the upper version.
                          ("C-c ^ l" . smerge-keep-lower)  ;; Keep the changes from the lower version.
                          ("C-c ^ n" . smerge-next)        ;; Move to the next conflict.
                          ("C-c ^ p" . smerge-previous)))  ;; Move to the previous conflict.

(use-package markdown-mode
  :ensure t
  :hook (markdown-mode . nb/markdown-unhighlight)
  :init
  (setq-default abbrev-mode t)
  :config
  (defvar nb/current-line '(0 . 0)
    "(start . end) of current line in current buffer")
  (make-variable-buffer-local 'nb/current-line)

  (defun nb/unhide-current-line (limit)
    "Font-lock function"
    (let ((start (max (point) (car nb/current-line)))
          (end (min limit (cdr nb/current-line))))
      (when (< start end)
        (remove-text-properties start end
                                '(invisible t display "" composition ""))
        (goto-char limit)
        t)))

  (defun nb/refontify-on-linemove ()
    "Post-command-hook"
    (let* ((start (line-beginning-position))
           (end (line-beginning-position 2))
           (needs-update (not (equal start (car nb/current-line)))))
      (setq nb/current-line (cons start end))
      (when needs-update
        ;; FIX: Verwende jit-lock-refontify statt font-lock-fontify-block
        (jit-lock-refontify start end))))

  (defun nb/markdown-unhighlight ()
    "Enable markdown concealling"
    (interactive)
    (markdown-toggle-markup-hiding 'toggle)
    (font-lock-add-keywords nil '((nb/unhide-current-line)) t)
    ;; FIX: Stelle sicher dass jit-lock aktiv ist
    (jit-lock-register #'font-lock-fontify-region)
    (add-hook 'post-command-hook #'nb/refontify-on-linemove nil t))

  :custom-face
  (markdown-header-delimiter-face ((t (:foreground "#616161" :height 0.9))))
  (markdown-header-face-1 ((t (:height 1.6 :foreground "#A3BE8C" :weight extra-bold :inherit markdown-header-face))))
  (markdown-header-face-2 ((t (:height 1.4 :foreground "#EBCB8B" :weight extra-bold :inherit markdown-header-face))))
  (markdown-header-face-3 ((t (:height 1.2 :foreground "#D08770" :weight extra-bold :inherit markdown-header-face))))
  (markdown-header-face-4 ((t (:height 1.15 :foreground "#BF616A" :weight bold :inherit markdown-header-face))))
  (markdown-header-face-5 ((t (:height 1.1 :foreground "#b48ead" :weight bold :inherit markdown-header-face))))
  (markdown-header-face-6 ((t (:height 1.05 :foreground "#5e81ac" :weight semi-bold :inherit markdown-header-face)))))

(defun my/agent-shell-autoscroll (&rest _)
  (dolist (win (get-buffer-window-list (current-buffer) 'visible))
    (when (>= (window-point win)
              (save-excursion (goto-char (point-max)) (point)))
      (set-window-point win (point-max)))))

(defun my/agent-shell-display-buffer-rules ()
  '(("\\*Kimi\\(?:\\*\\|:[^*]*\\*\\)"
     (display-buffer-in-side-window)
     (side . bottom)
     (slot . 0)
     (window-height . 0.33)
     (dedicated . t)
     (window-parameters . ((no-other-window . nil)
                           (no-delete-other-windows . nil))))
    ("\\*agent-shell-diff\\*"
     (display-buffer-in-side-window)
     (side . right)
     (slot . 1)
     (window-width . 0.5)
     (dedicated . t)
     (window-parameters . ((no-other-window . nil)
                           (no-delete-other-windows . nil))))))

(use-package agent-shell
  :ensure t
  :config
  (advice-add 'shell-maker-submit :after #'my/agent-shell-autoscroll)
  (dolist (rule (my/agent-shell-display-buffer-rules))
    (add-to-list 'display-buffer-alist rule)) 
  (setq agent-shell-tool-use-expand-by-default t)
  (setq agent-shell-thought-process-expand-by-default t)
  (setq agent-shell-user-message-expand-by-default t)
  (setq agent-shell-diff-delta-command
        (when (executable-find "delta")
          '("delta" "--no-gitconfig" "--color-only")))
  (setq agent-shell-activity-group-header-label-function
      #'agent-shell-activity-group-descriptive-label)


  ;; Work around agent-shell's `window-system' guard so clipboard images
  ;; work in terminal Emacs (`emacs -nw').  The underlying save routine
  ;; already shells out to wl-paste/xclip/pngpaste/powershell, none of
  ;; which require a GUI frame.
  (defun my/agent-shell-send-clipboard-image-in-terminal (orig-fn &optional pick-shell)
    "Call ORIG-FN, but allow `agent-shell-send-clipboard-image' in terminal Emacs."
    (if (window-system)
        (funcall orig-fn pick-shell)
      (let* ((screenshots-dir (agent-shell--dot-subdir "screenshots"))
             (image-path (agent-shell--save-clipboard-image
                          :destination-dir screenshots-dir))
             (shell-buffer (when pick-shell
                             (agent-shell--read-shell-buffer
                              :prompt "Send image to shell: "))))
        (agent-shell-insert
         :text (agent-shell--get-files-context :files (list image-path))
         :shell-buffer shell-buffer))))
  (advice-add 'agent-shell-send-clipboard-image :around
              #'my/agent-shell-send-clipboard-image-in-terminal)

  ;; Also let C-y / `agent-shell-yank-dwim' try the clipboard image first
  ;; in terminal Emacs before falling back to plain text yank.
  (defun my/agent-shell-yank-dwim-in-terminal (orig-fn &optional arg)
    "Call ORIG-FN, but try clipboard image first in terminal Emacs."
    (if (window-system)
        (funcall orig-fn arg)
      (if-let* ((screenshots-dir (agent-shell--dot-subdir "screenshots"))
                (image-path (agent-shell--save-clipboard-image
                             :destination-dir screenshots-dir
                             :no-error t)))
          (agent-shell-insert
           :text (agent-shell--get-files-context :files (list image-path))
           :shell-buffer (agent-shell--shell-buffer))
        (funcall orig-fn arg))))
  (advice-add 'agent-shell-yank-dwim :around
              #'my/agent-shell-yank-dwim-in-terminal))

(use-package agent-shell-sidebar
  :after agent-shell
  :ensure (:host nil :repo "ssh://git@git.cashmere.rs/agent-shell-sidebar.git"))

(use-package eldoc
  :ensure nil
  :config
  (setq eldoc-idle-delay 0.25)
  (setq eldoc-echo-area-use-multiline-p nil)
  (setq eldoc-echo-area-display-truncation-message nil)
  :init
  (global-eldoc-mode))

(use-package flymake
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

(use-package xref
  :ensure nil)

(use-package project
  :ensure nil)

(setq org-directory "~/org/")
(use-package org
  :ensure nil
  :custom
  (org-list-demote-modify-bullet '(("+" . "-") ("-" . "+")))
  :config
  (require 'org-tempo)

  (custom-set-faces
   '(org-document-title ((t (:height 1.5))))
   '(outline-1          ((t (:height 1.5))))
   '(outline-2          ((t (:height 1.4))))
   '(outline-3          ((t (:height 1.3))))
   '(outline-4          ((t (:height 1.25))))
   '(outline-5          ((t (:height 1.2))))
   '(outline-6          ((t (:height 1.175))))
   '(outline-7          ((t (:height 1.0))))
   '(outline-8          ((t (:height 1.0))))
   '(outline-9          ((t (:height 1.0)))))

  (setq org-startup-folded 'overview)
  (setq
   ;; org-adapt-indentation t
		;; org-time-stamp-rounding-minutes '(5 5)	
		org-return-follows-link t
        org-hide-leading-stars t
        org-pretty-entities t
        org-startup-truncated t
        org-ellipsis "  ")
  (setq org-src-fontify-natively t
        org-src-tab-acts-natively t
        org-edit-src-content-indentation 0)
  (add-to-list 'org-src-lang-modes '("nix" . nix-ts))
  (setq org-log-done                       t
        org-auto-align-tags                t
        org-tags-column                    -80
        org-fold-catch-invisible-edits     'show-and-error
        org-special-ctrl-a/e               t
        org-insert-heading-respect-content t)

  ;; (add-hook 'org-mode-hook 'org-indent-mode)
  (add-hook 'org-mode-hook 'visual-line-mode)
  (add-hook 'org-mode-hook (lambda () (electric-indent-local-mode -1)))


  (add-hook 'org-mode-hook
            (lambda ()
              (setq-local font-lock-extra-managed-props
                          (cons 'display font-lock-extra-managed-props))))
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

(use-package org-crypt
  :ensure nil
  :after org
  :config
  (org-crypt-use-before-save-magic)
  (setq org-crypt-key "1ED9D600A040D0AF193AAF30B877C0AC3B080FBB")
  (setq org-tags-exclude-from-inheritance '("crypt"))
  (add-hook 'org-mode-hook (lambda () (setq-local auto-save-default nil))))

(use-package org-appear
  :ensure t
  :commands (org-appear-mode)
  :hook     (org-mode . org-appear-mode)
  :config
  (setq org-hide-emphasis-markers t)  ;; Must be activated for org-appear to work
  (setq org-appear-autoemphasis   t   ;; Show bold, italics, verbatim, etc.
        org-appear-autolinks      t   ;; Show links
        org-appear-autosubmarkers t)) ;; Show sub- and superscripts



(use-package kitty-graphics
  :ensure (:host github :repo "cashmeredev/kitty-graphics.el")
  :demand t
  :custom
  (kitty-graphics-enable-video t)
  (kitty-graphics-shr-scale 'fit)
  (kitty-graphics-shr-fit-width 0.4)
  (kitty-graphics-shr-fit-height 20)
  (kitty-graphics-doc-view-resolution-scale 2.0)
  :hook (dired-mode . kitty-graphics-dired-auto-preview-mode)
  :config
  (setq kitty-graphics-enable-browser t
        kitty-graphics-casty-program "~/projects/casty/bin/casty.js"
        kitty-graphics-casty-chrome "helium-browser")

  (kitty-graphics-setup))

(with-eval-after-load 'org
  (setq org-confirm-babel-evaluate nil)
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t)
     (shell . t)
     (python . t)
     (ruby . t)
     (perl . t)
     (C . t)
     (js . t)
     (css . t)
     (sass . t)
     (sql . t)
     (sqlite . t)
     (lua . t)
     (lisp . t)
     (scheme . t)
     (clojure . t)
     (haskell . t)
     (ocaml . t)
     (java . t)
     (dot . t)
     (gnuplot . t)
     (plantuml . t)
     (ditaa . t)
     (calc . t)
     (latex . t)
     (org . t)
     (makefile . t)
     (awk . t)
     (sed . t)
     (screen . t)
     (eshell . t))))

(with-eval-after-load 'org
  (defun my/org-babel-tangle-targets-missing-p (&optional buffer)
    "Return non-nil if any :tangle target of BUFFER is missing.
BUFFER defaults to the current buffer."
    (with-current-buffer (or buffer (current-buffer))
      (when (and (buffer-file-name) (derived-mode-p 'org-mode))
        (require 'ob-tangle)
        (let* ((default-directory (file-name-directory (buffer-file-name)))
               (targets (mapcar #'car (org-babel-tangle-collect-blocks)))
               missing)
          (dolist (file targets)
            (unless (or missing (file-exists-p file))
              (setq missing t)))
          missing))))

  (defun my/org-babel-tangle-if-missing (&optional org-file target-file lang)
    "Tangle only if a target file is missing.
When called interactively with no arguments, check all :tangle
targets in the current buffer and run `org-babel-tangle' only if
at least one target is missing.

When called non-interactively, tangle ORG-FILE to TARGET-FILE
only if TARGET-FILE does not exist.  Optional LANG restricts
tangling to source blocks of that language."
    (interactive)
    (if (or org-file target-file lang)
        (unless (file-exists-p target-file)
          (org-babel-tangle-file org-file target-file lang))
      (if (my/org-babel-tangle-targets-missing-p)
          (org-babel-tangle)
        (message "All tangle targets already exist; skipping")))))

(use-package ob-async
  :ensure t
  :after org)

(with-eval-after-load 'org
  (defun org-babel-execute:just (body params)
    "Execute a justfile source block.
BODY is the justfile content.  PARAMS may include:
  :recipe  — recipe name to run (default: the default recipe)
  :dir     — working directory (default: `default-directory')"
    (let* ((recipe (cdr (assq :recipe params)))
           (dir (or (cdr (assq :dir params)) default-directory))
           (tmp (make-temp-file "ob-just-" nil "justfile")))
      (unwind-protect
          (progn
            (with-temp-file tmp (insert body))
            (shell-command-to-string
             (format "just --justfile %s --working-directory %s %s"
                     (shell-quote-argument tmp)
                     (shell-quote-argument (expand-file-name dir))
                     (if recipe (shell-quote-argument recipe) ""))))
        (delete-file tmp))))

  (add-to-list 'org-src-lang-modes '("just" . just)))

(defun my/snip-upload (&optional file)
  "Upload FILE, region, or current buffer to bouncer.cashmere.rs.
The xonsh `upload' command copies the URL to the clipboard; it is
also added to the kill ring."
  (interactive)
  (let* ((ext (or (and file (file-name-extension file))
                  (and (buffer-file-name) (file-name-extension (buffer-file-name)))
                  "txt"))
         (cmd (format "xonsh -c 'upload %s'" ext)))
    (if (and file (file-exists-p file))
        (call-process-shell-command
         (format "cat %s | %s" (shell-quote-argument file) cmd))
      (shell-command-on-region
       (if (use-region-p) (region-beginning) (point-min))
       (if (use-region-p) (region-end) (point-max))
       cmd nil nil))
    (let ((url (string-trim (shell-command-to-string "wl-paste"))))
      (if (string-prefix-p "https://" url)
          (progn
            (kill-new url)
            (message "Uploaded: %s" url))
        (message "Upload failed: %s" url)))))

(defun my/snip-upload-file ()
  "Prompt for a file and upload it to bouncer.cashmere.rs."
  (interactive)
  (my/snip-upload (read-file-name "Upload to bouncer: ")))

(defun my/setup-git-remote (dev-name srht-name)
  "Set up origin (dual-push) and backup remotes for the current git repo.
DEV-NAME is the repo name on dev.cashmere.rs, SRHT-NAME on sr.ht."
  (interactive
   (let* ((dev (read-string "Repo name (dev.cashmere.rs): "))
          (srht (read-string (format "Repo name (sr.ht) [%s]: " dev) nil nil dev)))
     (list dev srht)))
  (let* ((root (or (locate-dominating-file default-directory ".git")
                   (error "Not in a git repository")))
         (default-directory root)
         (dev-url (format "ssh://git@dev.cashmere.rs/cashmere/%s" dev-name))
         (srht-url (format "git@git.sr.ht:~cashmere/%s" srht-name)))
    (shell-command (format "git remote remove origin 2>/dev/null; git remote add origin %s" dev-url))
    (shell-command (format "git remote set-url --add --push origin %s" dev-url))
    (shell-command (format "git remote set-url --add --push origin %s" srht-url))
    (shell-command (format "git remote remove backup 2>/dev/null; git remote add backup %s" srht-url))
    (message "Remotes configured:\n  origin -> %s (push to both)\n  backup -> %s"
             dev-url srht-url)))

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

(with-eval-after-load 'org
  ;; Log state changes with timestamps
  (setq org-log-done 'time
        org-log-redeadline 'time
        org-log-reschedule 'time
        org-log-into-drawer t
        org-enforce-todo-dependencies t)

  ;; Update TODO keywords to require notes for WAIT and CANCELLED
  ;; @ means: prompt for note when entering state
  ;; ! means: timestamp when leaving state
  (setq org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "ACTIVE(a!)" "WAIT(w@/!)" "|" "DONE(d!)" "CANCELLED(c@)")))

  ;; Customize note prompts
  (setq org-log-note-headings
        '((done . "CLOSING NOTE %t")
          (state . "State %-12s from %-12S %t")
          (note . "Note taken on %t")
          (reschedule . "Rescheduled from %S on %t")
          (delschedule . "Not scheduled, was %S on %t")
          (redeadline . "New deadline from %S on %t")
          (deldeadline . "Removed deadline, was %S on %t")
          (refile . "Refiled on %t")
          (clock-out . ""))))

(use-package org-clock
  :after org
  :ensure nil
  :commands (org-clock-in org-clock-out org-clock-goto)
  :config
  ;; Setup hooks for clock persistence
  (org-clock-persistence-insinuate)
  (setq org-clock-clocked-in-display 'mode-line
        org-clock-history-length 23
        org-clock-in-switch-to-state 'my/clock-in-to-started
        org-clock-out-when-done t
        org-clock-persist t
        org-clock-persist-query-resume nil)

  ;; Helper function: detect if heading is a project
  (defun my/is-project-p ()
    "Any task with a todo keyword subtask."
    (save-restriction
      (widen)
      (let ((has-subtask)
            (subtree-end (save-excursion (org-end-of-subtree t)))
            (is-a-task (member (nth 2 (org-heading-components)) org-todo-keywords-1)))
        (save-excursion
          (forward-line 1)
          (while (and (not has-subtask)
                      (< (point) subtree-end)
                      (re-search-forward "^\\*+ " subtree-end t))
            (when (member (org-get-todo-state) org-todo-keywords-1)
              (setq has-subtask t))))
        (and is-a-task has-subtask))))

  ;; Helper function: detect if heading is a task
  (defun my/is-task-p ()
    "Any task with a todo keyword and no subtask."
    (save-restriction
      (widen)
      (let ((has-subtask)
            (subtree-end (save-excursion (org-end-of-subtree t)))
            (is-a-task (member (nth 2 (org-heading-components)) org-todo-keywords-1)))
        (save-excursion
          (forward-line 1)
          (while (and (not has-subtask)
                      (< (point) subtree-end)
                      (re-search-forward "^\\*+ " subtree-end t))
            (when (member (org-get-todo-state) org-todo-keywords-1)
              (setq has-subtask t))))
        (and is-a-task (not has-subtask)))))

  ;; Auto-change state when clocking in
  (defun my/clock-in-to-started (kw)
    "Switch task from TODO/NEXT to ACTIVE when clocking in.
Skips capture tasks and projects."
    (when (not (and (boundp 'org-capture-mode) org-capture-mode))
      (cond
       ;; Change TODO/NEXT tasks to ACTIVE when clocking in
       ((and (member (org-get-todo-state) (list "TODO" "NEXT"))
             (my/is-task-p))
        "ACTIVE")
       ;; Change ACTIVE projects back to TODO (projects shouldn't be clocked directly)
       ((and (member (org-get-todo-state) (list "ACTIVE"))
             (my/is-project-p))
        "TODO"))))

  :bind (("<f11>" . org-clock-goto)
         ("C-c C-x C-i" . org-clock-in)
         ("C-c C-x C-o" . org-clock-out)))

(with-eval-after-load 'org
  (setq org-global-properties
        '(("EFFORT_ALL" . "0:15 0:30 1:00 2:00 3:00 5:00 8:00")
          ("COMPLEXITY_ALL" . "low medium high")
          ("PRIORITY_ALL" . "A B C")))

  (setq org-columns-default-format
        "%40ITEM(Task) %TODO %10EFFORT{+} %10CLOCKSUM %10PROGRESS %COMPLEXITY %DEADLINE")

  ;; Auto-set effort from complexity (already exists, keeping it here for reference)
  ;; Low complexity = 30 min, Medium = 2h, High = 5h
  (defun my/org-set-effort-from-complexity ()
    "Auto-set EFFORT property based on COMPLEXITY property."
    (interactive)
    (let* ((complexity (org-entry-get (point) "COMPLEXITY"))
           (effort (org-entry-get (point) "EFFORT")))
      (unless effort
        (cond
         ((string= complexity "low") (org-set-property "EFFORT" "0:30"))
         ((string= complexity "medium") (org-set-property "EFFORT" "2:00"))
         ((string= complexity "high") (org-set-property "EFFORT" "5:00"))))))

  ;; Keybinding for manual effort setting
  (define-key org-mode-map (kbd "C-c e") 'my/org-set-effort-from-complexity))

(defun my/create-project ()
  "Create a new project file with denote and comprehensive project structure."
  (interactive)
  (let* ((project-name (read-string "Project name: "))
         (tags (completing-read-multiple "Additional tags (comma-separated): "
                                         '("work" "personal" "university" "learning")))
         (all-tags (append '("project" "agenda") tags))
         (deadline-str (org-read-date nil nil nil "Project deadline (optional, RET to skip): "))
         (effort-str (completing-read "Estimated total effort: "
                                      '("10h" "20h" "40h" "80h" "160h") nil nil "40h"))
         (file-name (denote project-name all-tags)))
    (find-file file-name)
    (goto-char (point-max))
    (insert "\n")
    (insert "* " project-name "\n")
    (insert ":PROPERTIES:\n")
    (when (and deadline-str (not (string-empty-p deadline-str)))
      (insert ":DEADLINE: <" deadline-str ">\n"))
    (insert ":EFFORT: " effort-str "\n")
    (insert ":PROGRESS: 0%\n")
    (insert ":END:\n\n")

    (insert "** Overview\n\n")
    (insert "- Goal :: \n")
    (insert "- Why :: \n")
    (insert "- Success Criteria :: \n")
    (insert "- Status :: Planning\n\n")

    (insert "** Phases\n\n")
    (insert "*** TODO Phase 1: Planning & Research\n")
    (when (and deadline-str (not (string-empty-p deadline-str)))
      (insert "DEADLINE: <" deadline-str ">\n"))
    (insert ":PROPERTIES:\n")
    (insert ":CREATED: " (format-time-string "[%Y-%m-%d %a %H:%M]") "\n")
    (insert ":END:\n\n")
    (insert "- [ ] Define scope\n")
    (insert "- [ ] Research requirements\n")
    (insert "- [ ] Break down into tasks\n\n")

    (insert "*** TODO Phase 2: Implementation\n")
    (insert ":PROPERTIES:\n")
    (insert ":CREATED: " (format-time-string "[%Y-%m-%d %a %H:%M]") "\n")
    (insert ":END:\n\n")

    (insert "*** TODO Phase 3: Review & Polish\n")
    (insert ":PROPERTIES:\n")
    (insert ":CREATED: " (format-time-string "[%Y-%m-%d %a %H:%M]") "\n")
    (insert ":END:\n\n")

    (insert "** Resources\n\n")
    (insert "- Links :: \n")
    (insert "- Files :: \n")
    (insert "- References :: \n\n")

    (insert "** Time Tracking\n\n")
    (insert "#+BEGIN: clocktable :scope file :maxlevel 3 :emphasize nil :link t\n")
    (insert "#+END:\n\n")
    (insert "Update with C-c C-c on the BEGIN line\n\n")

    (insert "** Status Updates\n\n")
    (insert "Use =C-c C-x C-c= for column view to update PROGRESS and see overview.\n\n")

    (insert "** Retrospective\n\n")
    (insert "- What worked :: \n")
    (insert "- What didn't :: \n")
    (insert "- Lessons learned :: \n")
    (insert "- Would do differently :: \n")

    (org-mode)
    (goto-char (point-min))
    (search-forward "- Goal :: " nil t)))

(defun my/org-capture-to-journal (heading)
  (require 'denote-journal)
  (denote-journal-new-or-existing-entry)
  (goto-char (point-max))
  (insert heading)
  (current-buffer))

(defun my/org-capture-timeblock-to-journal ()
  (my/org-capture-to-journal "\n* Timeblock\n"))

(defun my/org-capture-recurring-to-journal ()
  (my/org-capture-to-journal "\n* Recurring\n"))

(defun my/org-capture-meeting-to-journal ()
  (my/org-capture-to-journal "\n* Meeting: "))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(org-mode . ("harper-ls" "--stdio"))))

(defun my/org-capture-task-to-journal ()
  (let* ((context (read-string "Task: "))
         (todo-state (completing-read "TODO state: "
                                      '("ACTIVE" "NEXT" "TODO" "WAIT"))))
    (my/org-capture-to-journal (format "\n* %s %s\n\n" todo-state context))))

(defun my/org-capture-deadline-to-journal ()
  (let* ((context (read-string "Task with deadline: "))
         (deadline (org-read-date t nil nil "Deadline: ")))
    (my/org-capture-to-journal (format "\n* %s\nDEADLINE: <%s>\n\n" context deadline))))

(defun my/org-capture-scheduled-to-journal ()
  "Capture a scheduled task into today's denote-journal file."
  (let* ((context (read-string "Scheduled task: "))
         (schedule (org-read-date t nil nil "Schedule: ")))
    (my/org-capture-to-journal (format "\n* %s\nSCHEDULED: <%s>\n\n" context schedule))))

(defun my/org-capture-float ()
  (interactive)
  (select-frame
   (make-frame '((title . "org-capture")
                 (width . 160)
                 (height . 14))))
  (org-capture))

(with-eval-after-load 'org
  (setq org-capture-templates
        '(("t" "Task" plain
           (function my/org-capture-task-to-journal)
           "" :immediate-finish t :jump-to-captured t)
          ("d" "Deadline" plain
           (function my/org-capture-deadline-to-journal)
           "" :immediate-finish t :jump-to-captured t)
          ("s" "Scheduled" plain
           (function my/org-capture-scheduled-to-journal)
           "" :immediate-finish t :jump-to-captured t)
          ("b" "Timeblock" plain
           (function my/org-capture-timeblock-to-journal)
           "" :immediate-finish nil :jump-to-captured t)
          ("r" "Recurring" plain
           (function my/org-capture-recurring-to-journal)
           "" :immediate-finish t :jump-to-captured t)
          ("m" "Meeting" plain
           (function my/org-capture-meeting-to-journal)
           "" :immediate-finish nil :jump-to-captured t))))

(use-package org-super-agenda
  :ensure t
  :after org-agenda
  :init
  :config
  (org-super-agenda-mode))

(use-package org-ql
  :ensure t
  :after org-super-agenda)

;;; --- Agenda display settings ---

(setq org-agenda-window-setup 'current-window
      org-agenda-inhibit-startup t
      org-agenda-remove-tags t
      org-agenda-dim-blocked-tasks nil
      org-agenda-skip-scheduled-if-done t
      org-agenda-skip-deadline-if-done t)

(setq org-agenda-scheduled-leaders '("" "-%2d"))

(setq org-agenda-time-grid
  '((daily today require-timed)
    (800 1000 1200 1400 1600 1800 2000)
    "......" "________________"))

(setq org-agenda-current-time-string
  "--- NOW ---------------")

(setq org-agenda-prefix-format
  '((agenda . " %i %?-12t% s")
    (todo   . " %i ")
    (tags   . " %i ")
    (search . " %i ")))

;;; --- Agenda views ---
;;
;; d - Today: daily driver, what to focus on now
;; w - Week:  calendar + upcoming + backlog
;; p - Projects: all project tasks by state
;; o - Overview: schedule + topics (project/dev/blog/self) + backlog

(setq org-agenda-custom-commands
  '(
    ;; ── Today ──────────────────────────────────────────────
    ("d" "Today"
     (
       ;; Block 1: standard agenda — time-grid, NOW line, scheduled + deadlines
       (agenda ""
         ((org-agenda-span 1)
          (org-agenda-start-day ".")
          (org-deadline-warning-days 3)
          (org-scheduled-past-days 0)
          (org-agenda-day-face-function (lambda (date) 'org-agenda-date))
          (org-agenda-overriding-header "")
          (org-super-agenda-groups
           '((:name "Overdue"
              :scheduled past
              :deadline past
              :order 0)
             (:name "Schedule"
              :time-grid t
              :order 1)
             (:name "Scheduled today"
              :scheduled today
              :order 2)
             (:name "Deadlines"
              :deadline today
              :order 3)
             (:discard (:anything t))))))

       ;; Block 2: active + next tasks (what you can work on right now)
       (org-ql-block '(and (todo "ACTIVE" "NEXT")
                           (not (done)))
         ((org-ql-block-header "In Progress")
          (org-super-agenda-groups
           '((:auto-tags t)))))

       ;; Block 3: waiting items
       (org-ql-block '(and (todo "WAIT")
                           (not (done)))
         ((org-ql-block-header "Waiting On")
          (org-super-agenda-groups
           '((:auto-tags t)))))))

    ;; ── Week ───────────────────────────────────────────────
    ("w" "Week"
     (
       ;; Block 1: today in detail
       (agenda ""
         ((org-agenda-span 1)
          (org-deadline-warning-days 0)
          (org-scheduled-past-days 0)
          (org-agenda-day-face-function (lambda (date) 'org-agenda-date))
          (org-agenda-overriding-header "Today")
          (org-super-agenda-groups
           '((:name "Overdue"
              :scheduled past
              :deadline past
              :order 0)
             (:name "Schedule"
              :time-grid t
              :order 1)
             (:name "Scheduled today"
              :scheduled today
              :order 2)
             (:discard (:anything t))))))

       ;; Block 2: next 6 days
       (agenda ""
         ((org-agenda-start-on-weekday nil)
          (org-agenda-start-day "+1d")
          (org-agenda-span 6)
          (org-deadline-warning-days 0)
          (org-agenda-overriding-header "Next 6 Days")
          (org-super-agenda-groups
           '((:anything t)))))

       ;; Block 3: upcoming deadlines beyond this week
       (agenda ""
         ((org-agenda-time-grid nil)
          (org-agenda-start-on-weekday nil)
          (org-agenda-start-day "+7d")
          (org-agenda-span 14)
          (org-agenda-show-all-dates nil)
          (org-agenda-entry-types '(:deadline))
          (org-agenda-overriding-header "Upcoming Deadlines (+14d)")
          (org-super-agenda-groups
           '((:anything t)))))

       ;; Block 4: unscheduled backlog
       (org-ql-block '(and (todo)
                           (not (done))
                           (not (scheduled))
                           (not (deadline)))
         ((org-ql-block-header "Backlog (unscheduled)")
          (org-super-agenda-groups
           '((:name "ACTIVE" :todo "ACTIVE" :order 1)
             (:name "NEXT"   :todo "NEXT"   :order 2)
             (:name "TODO"   :todo "TODO"   :order 3)
             (:name "WAIT"   :todo "WAIT"   :order 4)
             (:discard (:anything t))))))))

    ;; ── Projects ───────────────────────────────────────────
    ("p" "Projects"
     ((org-ql-block '(and (tags "project")
                          (not (done)))
        ((org-ql-block-header "All Project Tasks")
         (org-super-agenda-groups
          '((:name "ACTIVE" :todo "ACTIVE" :order 1)
            (:name "NEXT"   :todo "NEXT"   :order 2)
            (:name "TODO"   :todo "TODO"   :order 3)
            (:name "WAIT"   :todo "WAIT"   :order 4)
            (:discard (:anything t))))))))

    ;; ── Overview ───────────────────────────────────────────
    ;; Full dashboard: schedule + topic sections + backlog
    ("o" "Overview"
     (
       ;; Block 1: today's agenda — schedule, deadlines, overdue
       (agenda ""
         ((org-agenda-span 1)
          (org-agenda-start-day ".")
          (org-deadline-warning-days 3)
          (org-agenda-show-future-repeats nil)
          (org-agenda-overriding-header "")
          (org-super-agenda-groups
           '((:name "Overdue"
              :scheduled past
              :deadline past
              :order 0)
             (:name "Schedule"
              :time-grid t
              :order 1)
             (:name "Scheduled today"
              :scheduled today
              :order 2)
             (:name "Deadlines"
              :deadline today
              :order 3)
             (:discard (:anything t))))))

       ;; Block 2: next 6 days
       (agenda ""
         ((org-agenda-start-on-weekday nil)
          (org-agenda-start-day "+1d")
          (org-agenda-span 6)
          (org-deadline-warning-days 0)
          (org-agenda-overriding-header "Next 6 Days")
          (org-super-agenda-groups
           '((:anything t)))))

       ;; Block 3: upcoming deadlines beyond this week
       (agenda ""
         ((org-agenda-time-grid nil)
          (org-agenda-start-on-weekday nil)
          (org-agenda-start-day "+7d")
          (org-agenda-span 14)
          (org-agenda-show-all-dates nil)
          (org-agenda-entry-types '(:deadline))
          (org-agenda-overriding-header "Upcoming Deadlines (+14d)")
          (org-super-agenda-groups
           '((:anything t)))))

       ;; Block 4: project
       (org-ql-block '(and (tags "project")
                           (not (done)))
         ((org-ql-block-header "Project")
          (org-super-agenda-groups
           '((:name "ACTIVE" :todo "ACTIVE" :order 1)
             (:name "NEXT"   :todo "NEXT"   :order 2)
             (:name "TODO"   :todo "TODO"   :order 3)
             (:name "WAIT"   :todo "WAIT"   :order 4)
             (:discard (:anything t))))))

       ;; Block 5: development
       (org-ql-block '(and (tags "development")
                           (not (done)))
         ((org-ql-block-header "Development")
          (org-super-agenda-groups
           '((:name "ACTIVE" :todo "ACTIVE" :order 1)
             (:name "NEXT"   :todo "NEXT"   :order 2)
             (:name "TODO"   :todo "TODO"   :order 3)
             (:name "WAIT"   :todo "WAIT"   :order 4)
             (:discard (:anything t))))))

       ;; Block 6: blog
       (org-ql-block '(and (tags "blog")
                           (not (done)))
         ((org-ql-block-header "Blog")
          (org-super-agenda-groups
           '((:name "ACTIVE" :todo "ACTIVE" :order 1)
             (:name "NEXT"   :todo "NEXT"   :order 2)
             (:name "TODO"   :todo "TODO"   :order 3)
             (:name "WAIT"   :todo "WAIT"   :order 4)
             (:discard (:anything t))))))

       ;; Block 7: self
       (org-ql-block '(and (tags "self")
                           (not (done)))
         ((org-ql-block-header "Self")
          (org-super-agenda-groups
           '((:name "ACTIVE" :todo "ACTIVE" :order 1)
             (:name "NEXT"   :todo "NEXT"   :order 2)
             (:name "TODO"   :todo "TODO"   :order 3)
             (:name "WAIT"   :todo "WAIT"   :order 4)
             (:discard (:anything t))))))

       ;; Block 8: backlog — everything not covered above
       (org-ql-block '(and (todo)
                           (not (done))
                           (not (tags "project" "development" "blog" "self")))
         ((org-ql-block-header "Backlog")
          (org-super-agenda-groups
           '((:name "ACTIVE" :todo "ACTIVE" :order 1)
             (:name "NEXT"   :todo "NEXT"   :order 2)
             (:name "TODO"   :todo "TODO"   :order 3)
             (:name "WAIT"   :todo "WAIT"   :order 4)
             (:discard (:anything t))))))))))

;;; --- Theme-adaptive TODO keyword faces ---

(setq org-todo-keyword-faces
  '(("TODO"      . (:inherit (warning org-todo)))
    ("NEXT"      . (:inherit (font-lock-type-face org-todo)))
    ("ACTIVE"    . (:inherit (bold org-todo)))
    ("WAIT"      . (:inherit (shadow org-todo)))
    ("DONE"      . (:inherit (success org-todo)))
    ("CANCELLED" . (:inherit (shadow org-done)))))

;; (defun my/update-org-modern-faces ()
;;   (setq org-modern-todo-faces
;;     `(("TODO"      :background ,(face-attribute 'warning :foreground)
;;                    :foreground ,(face-attribute 'default :background))
;;       ("ACTIVE"    :background ,(face-attribute 'error :foreground)
;;                    :foreground ,(face-attribute 'default :background))
;;       ("DONE"      :background ,(face-attribute 'success :foreground)
;;                    :foreground ,(face-attribute 'default :background))
;;       ("CANCELLED" :background ,(face-attribute 'shadow :foreground)
;;                    :foreground ,(face-attribute 'default :background)))))
;;
;; (add-hook 'after-load-theme-hook #'my/update-org-modern-faces)
;; (add-hook 'after-init-hook #'my/update-org-modern-faces)

;;; --- Tag cleanup in agenda buffer ---

(defun my/org-agenda-remove-tags ()
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward " +:[[:alnum:]_@#%:]+: *$" nil t)
      (replace-match ""))))

(add-hook 'org-agenda-finalize-hook #'my/org-agenda-remove-tags)

;;; --- Late-indicator symbols for overdue items ---
;;
;; Replaces the numeric "days late" extra field with visual indicators:
;;   1-2 days: •   3-6 days: !   7-13 days: ‼   14+ days: ✖

(defun my/org-agenda-late-extra (orig-fn extra txt &rest args)
  "Advice around `org-agenda-format-item' to show overdue indicators."
  (let* ((agenda-extra
          (let ((d (when (stringp extra)
                     (abs (string-to-number extra)))))
            (cond
             ((not d) "")
             ((= d 0) "")
             ((< d 3) " •")
             ((< d 7) " !")
             ((< d 14) " ‼")
             (t " ✖")))))
    (apply orig-fn agenda-extra txt args)))

(advice-add 'org-agenda-format-item :around
            #'my/org-agenda-late-extra)

;;; --- Clean up excessive blank lines between agenda blocks ---

(defun my/org-agenda-fix-block-spacing ()
  "Collapse triple+ newlines to double in the agenda buffer."
  (goto-char (point-min))
  (while (re-search-forward "\n\n\n+" nil t)
    (replace-match "\n\n")))

(add-hook 'org-agenda-finalize-hook
          #'my/org-agenda-fix-block-spacing)

(use-package org-contrib
  :ensure (:wait t))

(require 'ox-extra)
(ox-extras-activate '(ignore-headlines))

(use-package ox-typst
  :ensure (:host github :repo "jmpunkt/ox-typst")
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
         :base-directory "~/garden"
         :publishing-directory "~/cashmere.rs/content/wiki"
         :publishing-function denote-publish-to-md
         :recursive nil
         :exclude-tags ("noexport" "draft")
         :section-numbers nil
         :with-creator nil
         :with-toc nil)))

(setq org-export-with-broken-links t)

(use-package ox-pandoc
  :ensure (:wait t)
  :after org)

(use-package denote
  :ensure (:wait t)
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
  (setq denote-agenda-include-regexp "_agenda")
  (denote-agenda-insinuate))

(defun my/denote-toggle-agenda-keyword ()
  "Toggle the \"agenda\" keyword on the current Denote note.
Renames the file and rewrites its front matter, saving the buffer."
  (interactive)
  (unless (and buffer-file-name (denote-file-is-note-p buffer-file-name))
    (user-error "Current buffer is not a Denote note"))
  (save-buffer)
  (let* ((keywords (denote-extract-keywords-from-path buffer-file-name))
         (denote-rename-confirmations nil)
         (denote-save-buffers t)
         (new-keywords (if (member "agenda" keywords)
                           (remove "agenda" keywords)
                         (cons "agenda" keywords))))
    (denote-rename-file buffer-file-name 'keep-current new-keywords
                        'keep-current 'keep-current 'keep-current)
    (message "%s the agenda"
             (if (member "agenda" new-keywords) "Added to" "Removed from"))))

(use-package denote-journal
  :ensure t
  :config
  (setopt denote-journal-title-format 'day-date-month-year))

;; (defun my/denote-journal-template ()
;;   "Insert journal structure into a new journal entry.
;; Only inserts when the buffer has just the front-matter (fresh file)."
;;   (when (and (buffer-file-name)
;;              (string-match-p "journal" (buffer-file-name))
;;              (<= (count-lines (point-min) (point-max)) 6))
;;     (goto-char (point-max))
;;     (insert
;;      "\n* Clockreport \n"
;;      "\n#+BEGIN: clocktable :scope file :maxlevel 3 :emphasize nil :link t\n"
;;      "#+END:\n"
;;      "\n* Agenda \n"
;;      "\n** NEXT Plan the day\n"
;;      ":LOGBOOK:\n"
;;      ":END:\n"
;;      "\n* Braindump \n"
;;      ":PROPERTIES:\n"
;;      ":VISIBILITY: folded\n"
;;      ":END:\n")))

;; (advice-add 'denote-journal-new-or-existing-entry :after
;;             (lambda (&rest _) (my/denote-journal-template)))

(defcustom my/denote-agenda-filename-component-regexp
  "\\(?:[-_.]\\|:\\)agenda\\(?:[-_.]\\|:\\|$\\)"
  "Regexp matching a filename component that denotes the 'agenda' tag.
Works on the base filename (without extension), e.g. matches \"-agenda\", \":agenda:\", \"_agenda_\"."
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

(defun my/denote-remove-agenda-filetag-and-silent-rename ()
  "If current headline became DONE in a Denote note, remove :agenda: filetag and remove 'agenda' from filename silently.
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
        ;; 1) Remove :agenda: from #+filetags:
        (save-excursion
          (goto-char (point-min))
          (when (re-search-forward "^#\\+filetags:\\s-*\\(.*\\)$" nil t)
            (let* ((tags (match-string 1))
                   (clean (replace-regexp-in-string ":agenda:" "" tags))
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
               ;; remove the agenda component from the base
               (new-base (replace-regexp-in-string my/denote-agenda-filename-component-regexp
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
                    (rename-file file target 1)
                    ;; update current buffer to visit the new filename silently
                    (set-visited-file-name target t t)
                    ;; save changes (filetags update + new filename)
                    (save-buffer)
                    (message "Denote: removed 'agenda' component from filename -> %s" (file-name-nondirectory target)))
                (error
                 (message "Denote rename failed: %s" (error-message-string err)))))))))))

(add-hook 'org-after-todo-state-change-hook #'my/denote-remove-agenda-filetag-and-silent-rename)

(use-package denote-menu
  :ensure nil
  :after denote
  :commands (denote-menu))

(use-package denote-org
    :ensure t)

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

(use-package ox-gfm
  :ensure t)

(use-package denote-publish
  :ensure (:repo "https://github.com/vedang/denote-publish"))

(setq denote-publish-default-base-dir "~/garden")
(setq denote-publish-default-output-dir "~/cashmere.rs/content/wiki")

(setq denote-publish-link-class "internal-link")

(setq denote-publish-front-matter-fields
      '(title subtitle identifier date last_updated_at
              aliases tags category skip_archive has_code
              og_image og_description og_video_id))

(use-package tmr
  :ensure (:host github :repo "protesilaos/tmr")
  :config
  (setq tmr-sound-file "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
        tmr-notification-urgency 'normal
        tmr-description-list 'tmr-description-history)
  (define-key global-map (kbd "C-c t") #'tmr-prefix-map)

  ;; ── Timer persistence across Emacs restarts ──────────────
  (defvar my/tmr-save-file
    (expand-file-name "tmr-timers.eld" user-emacs-directory)
    "File to persist active tmr timers across Emacs restarts.")

  (defun my/tmr-save-timers ()
    "Save active (non-finished) tmr timers to `my/tmr-save-file'."
    (let ((active
           (cl-loop for timer in tmr--timers
                    unless (tmr--timer-finishedp timer)
                    collect (list :end-date (tmr--timer-end-date timer)
                                 :creation-date (tmr--timer-creation-date timer)
                                 :input (tmr--timer-input timer)
                                 :description (tmr--timer-description timer)
                                 :acknowledgep (tmr--timer-acknowledgep timer)
                                 :paused-remaining (tmr--timer-paused-remaining timer)))))
      (with-temp-file my/tmr-save-file
        (prin1 active (current-buffer)))))

  (defun my/tmr-restore-timers ()
    "Restore tmr timers from `my/tmr-save-file'.
Timers that expired while Emacs was closed fire immediately."
    (require 'tmr)
    (when (file-exists-p my/tmr-save-file)
      (let ((saved (with-temp-buffer
                     (insert-file-contents my/tmr-save-file)
                     (read (current-buffer)))))
        (dolist (entry saved)
          (let* ((end-date (plist-get entry :end-date))
                 (creation-date (plist-get entry :creation-date))
                 (input (plist-get entry :input))
                 (description (plist-get entry :description))
                 (acknowledgep (plist-get entry :acknowledgep))
                 (paused-remaining (plist-get entry :paused-remaining))
                 (remaining (if paused-remaining
                                paused-remaining
                              (round (- (float-time end-date) (float-time)))))
                 (adjusted-end (if (and (not paused-remaining) (<= remaining 0))
                                   (time-add (current-time) 1)
                                 end-date))
                 (timer (tmr--timer-create
                         :creation-date creation-date
                         :end-date adjusted-end
                         :input input
                         :description description
                         :acknowledgep acknowledgep
                         :paused-remaining paused-remaining)))
            ;; For active timers, schedule the live Emacs timer and store it
            ;; in the timer-object slot (index 5 in the cl-defstruct vector).
            ;; We use aset directly to avoid needing setf expanders at
            ;; macro-expansion time (tmr may not be loaded when config tangles).
            (unless paused-remaining
              (let ((live-timer (run-with-timer (max 1 remaining) nil #'tmr--complete timer)))
                (aset timer 5 live-timer)))
            (push timer tmr--timers)))
        (run-hooks 'tmr--update-hook))
      ;; Clear the save file so we don't double-restore
      (delete-file my/tmr-save-file)))

  (add-hook 'kill-emacs-hook #'my/tmr-save-timers)
  (add-hook 'emacs-startup-hook #'my/tmr-restore-timers))

(use-package denote-merge
  :ensure (:host github :repo "protesilaos/denote-merge") ; not in any package archive
  ;; You can bind these to keys.  They are here so you can learn about them.
  :commands
  (denote-merge-file
    denote-merge-region
    denote-merge-region-plain
    denote-merge-region-plain-indented
    denote-merge-region-org-src
    denote-merge-region-org-quote
    denote-merge-region-org-example
    denote-merge-region-markdown-quote
    denote-merge-region-markdown-fenced-block))

(use-package denote-solo
  :ensure (:host github :repo "pavlo/denote-solo")
  :after denote
  :config
  (setq denote-solo-directories
        '(("org"    . "~/org")
          ("garden" . "~/garden"))
        denote-solo-display-modeline nil)
  (denote-solo-mode 1)

  (defun my/denote-solo-sync-directory (&rest _)
    (when-let* ((solo denote-solo--current-solo)
                (path (denote-solo--directory-for-name solo)))
      (setq-default denote-directory path)
      (dolist (buf (buffer-list))
        (with-current-buffer buf
          (when (local-variable-p 'denote-directory)
            (setq denote-directory path))))))

  (advice-add 'denote-solo-switch :after #'my/denote-solo-sync-directory))

(use-package which-key
  :ensure t
  :defer t
  :hook
  (after-init . which-key-mode)
  :custom
  (which-key-idle-delay 0.3))

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

(use-package cape
  :ensure (:wait t)

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
  :config
  (with-eval-after-load 'eglot
    (advice-add 'eglot-completion-at-point :around #'cape-wrap-noninterruptible)
    (advice-add 'eglot-completion-at-point :around #'cape-wrap-buster)))

(use-package embark
  :ensure (:wait t)
  :defer t
  :bind
  (("C-." . embark-act)
   ("M-." . embark-dwim)
   ("C-h B" . embark-bindings)
   :map minibuffer-local-map
   ("C-c C-a" . embark-act-all)
   ("C-c C-e" . embark-export)
   ("C-c C-o" . embark-collect))
  :init
  (setq prefix-help-command #'embark-prefix-help-command))

(use-package orderless
    :ensure t
    :defer t                                    ;; Load Orderless on demand.
    :after vertico                              ;; Ensure Vertico is loaded before Orderless.
    :init
    (setq completion-styles '(orderless basic)  ;; Set the completion styles.
completion-category-defaults nil      ;; Clear default category settings.
completion-category-overrides '((file (styles partial-completion))))) ;; Customize file completion styles.

(use-package helm
  :ensure (:wait t)
  :hook
  (after-init . helm-mode)
  :custom
  (helm-M-x-fuzzy-match t)
  (helm-buffers-fuzzy-matching t)
  (helm-recentf-fuzzy-match t)
  (helm-move-to-line-cycle-in-source nil)
  (helm-split-window-inside-p t)
  (helm-boring-buffer-regexp-list
   '("\\` "
     "\\`\\*helm"
     "\\`\\*Echo Area"
     "\\`\\*Minibuf"
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
     "\\`\\*elpaca-log\\*\\'"
     "\\`\\*Native-compile-Log\\*\\'"
     "\\`\\*Async-native-compile-log\\*\\'"))
  ;; (helm-display-function #'helm-display-buffer-in-own-frame)
  :bind (:map helm-map
              ("C-j" . helm-next-line)
              ("C-k" . helm-previous-line)))
(global-set-key (kbd "M-x") 'helm-M-x)

(use-package helm-flx
  :ensure t
  :after helm
  :config
  (helm-flx-mode +1))

(use-package eglot
  :ensure nil
  :config
  ;; nil: LSP server stays alive when last managed buffer closes.
  ;; Verhindert churn bei org src edit buffers (C-c ' macht buffer auf/zu
  ;; → mit t neuer pyrefly process jedes Mal).
  (setq eglot-autoshutdown nil)
  (setq eglot-send-changes-idle-time 0.1)
  (setq eglot-sync-connect nil)
  (setq eglot-connect-timeout 30)
  (setq eglot-events-buffer-size 0)
  (setq eglot-report-progress nil)
  (setq jsonrpc-default-request-timeout 10))
  
  ;; (add-hook 'eglot-managed-mode-hook
  ;;           (lambda ()
  ;;             (eglot-inlay-hints-mode -1)))

  ;; (setq eglot-code-action-indications '(eldoc-hint))

  ;; (setq eglot-ignored-server-capabilities
  ;;       '(:inlayHintProvider :documentHighlightProvider)))

(use-package typst-ts-mode
  :ensure t
  :mode "\\.typ\\'"
  :hook (typst-ts-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 `(typst-ts-mode . ,(eglot-alternatives '("tinymist" "lsp"))))))

(use-package yasnippet
  :ensure t
  :config
  (yas-global-mode 1))

(use-package yasnippet-snippets
  :ensure t
  :after yasnippet)

(use-package nix-ts-mode
  :ensure t
  :mode "\\.nix\\'"
  :hook (nix-ts-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(nix-ts-mode . ("nixd")))))

(put 'eglot-workspace-configuration 'safe-local-variable #'listp)

(use-package c-ts-mode
  :ensure nil
  :mode (("\\.c\\'" . c-ts-mode)
         ("\\.h\\'" . c-ts-mode))
  :hook (c-ts-mode . eglot-ensure)
  :custom
  (c-ts-mode-indent-offset 2)
  (c-ts-mode-indent-style 'k&r)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '((c-ts-mode c-mode) .
                   ("clangd"
                    "--background-index"
                    "--clang-tidy"
                    "--header-insertion=never")))))

(use-package c3-ts-mode
  :ensure (:host github :repo "c3lang/c3-ts-mode")
  :mode (("\\.c3\\'" . c3-ts-mode)
         ("\\.c3i\\'" . c3-ts-mode)
         ("\\.c3t\\'" . c3-ts-mode))
  :hook (c3-ts-mode . eglot-ensure)
  :custom
  (c3-ts-mode-indent-offset 2)
  (setq treesit-font-lock-level 4)
  :init
  (add-to-list 'treesit-language-source-alist
               '(c3 "https://github.com/c3lang/tree-sitter-c3"))
  :config
  (unless (treesit-language-available-p 'c3)
    (treesit-install-language-grammar 'c3))
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(c3-ts-mode . ("c3-lsp")))))

(use-package python
  :ensure nil
  :mode ("\\.py\\'" . python-ts-mode)
  :hook (python-ts-mode . eglot-ensure)
  :custom
  (python-indent-offset 4)
  (python-indent-guess-indent-offset-verbose nil)
  (python-shell-interpreter "python3")
  (python-shell-completion-native-enable nil)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '((python-ts-mode python-mode) . ("rass" "--" "pyrefly" "lsp" "--" "ruff" "server")))))

(use-package pyvenv
  :ensure t
  :config
  (setq pyvenv-mode-line-indicator '(pyvenv-virtual-env-name 
                                      (" [venv:" pyvenv-virtual-env-name "] ")))
  (add-hook 'python-ts-mode-hook 
            (lambda ()
              (pyvenv-mode 1))))

(use-package rust-ts-mode
  :ensure nil
  :mode "\\.rs\\'"
  :hook (rust-ts-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(rust-ts-mode .
                   ("rust-analyzer" :initializationOptions 
                    (:check (:command "clippy")))))))

(use-package js
  :ensure nil
  :mode ("\\.js\\'" . js-ts-mode)
  :hook (js-ts-mode . eglot-ensure)
  :config
  (setq js-indent-level 2)
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(js-ts-mode . ("rass" "--" "typescript-language-server" "--stdio" "--" "vscode-eslint-language-server" "--stdio")))))

(use-package typescript-ts-mode
  :ensure nil
  :mode (("\\.ts\\'" . typescript-ts-mode)
         ("\\.tsx\\'" . tsx-ts-mode))
  :hook ((typescript-ts-mode . eglot-ensure)
         (tsx-ts-mode . eglot-ensure))
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '((typescript-ts-mode tsx-ts-mode) . ("rass" "--" "typescript-language-server" "--stdio" "--" "vscode-eslint-language-server" "--stdio")))))

(use-package xonsh-mode
  :ensure (:host github :repo "seanfarley/xonsh-mode")
  :mode ("\\.xsh\\'" "\\.xonshrc\\'"))

(define-derived-mode xonsh-ts-mode python-ts-mode "Xonsh[ts]"
  "Major mode for xonsh, derived from `python-ts-mode'.
Xonsh is a python superset; reuse python tree-sitter parser."
  (setq-local comment-start "# "
              comment-end ""))

(with-eval-after-load 'treesit
  (when (treesit-language-available-p 'python)
    (add-to-list 'auto-mode-alist '("\\.xsh\\'" . xonsh-ts-mode))
    (add-to-list 'auto-mode-alist '("\\.xonshrc\\'" . xonsh-ts-mode))))

(defun my/org-src-eglot-python ()
  "Give org src edit buffers a stable temp file name so eglot can attach.
Name derived from owning org file path → identical across re-opens of
the same src block file, so eglot reuses the existing connection
instead of churning."
  (when (and (derived-mode-p 'python-ts-mode 'python-mode)
             (not buffer-file-name)
             (bound-and-true-p org-src-mode))
    (let* ((parent (or (buffer-file-name (org-src-source-buffer))
                       (buffer-name (org-src-source-buffer))
                       "scratch"))
           (root (or (and (project-current)
                          (project-root (project-current)))
                     temporary-file-directory))
           (name (format "ob-src-%s.py"
                         (substring (md5 parent) 0 8))))
      (setq-local buffer-file-name (expand-file-name name root))
      (set-buffer-modified-p nil)
      (eglot-ensure))))

(add-hook 'org-src-mode-hook #'my/org-src-eglot-python)

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '((xonsh-mode xonsh-ts-mode)
                 . ("rass" "--" "pyrefly" "lsp" "--" "ruff" "server"))))

;; kein auto-eglot fuer xonsh — pyrefly.toml waere noetig. Manuell via
;; M-x my/pyrefly-here-xonsh (legt temp pyrefly.toml an + startet eglot).
;; (add-hook 'xonsh-mode-hook #'eglot-ensure)
;; (add-hook 'xonsh-ts-mode-hook #'eglot-ensure)

(defvar my/ob-xonsh-installer
  (lambda ()
    (defun org-babel-execute:xonsh (body params)
      "Execute a xonsh source block.
BODY is the xonsh script.  PARAMS may include :dir and :cmdline."
      (let* ((dir (or (cdr (assq :dir params)) default-directory))
             (cmdline (or (cdr (assq :cmdline params)) ""))
             (tmp (make-temp-file "ob-xonsh-" nil ".xsh")))
        (unwind-protect
            (progn
              (with-temp-file tmp (insert body))
              (let ((default-directory dir))
                (shell-command-to-string
                 (format "xonsh %s %s"
                         cmdline
                         (shell-quote-argument tmp)))))
          (when (file-exists-p tmp) (delete-file tmp))))))
  "Defines `org-babel-execute:xonsh'; reused in ob-async child processes.")

(with-eval-after-load 'org
  (funcall my/ob-xonsh-installer)
  (add-to-list 'org-src-lang-modes '("xonsh" . xonsh)))

(with-eval-after-load 'ob-async
  (add-hook 'ob-async-pre-execute-src-block-hook my/ob-xonsh-installer))

(use-package yaml-ts-mode
  :ensure nil
  :mode "\\.ya?ml\\'"
  :hook (yaml-ts-mode . eglot-ensure))

(use-package bash-ts-mode
  :ensure nil
  :mode (("\\.sh\\'" . bash-ts-mode)
         ("\\.bash\\'" . bash-ts-mode)
         ("\\.bashrc\\'" . bash-ts-mode)
         ("\\.bash_profile\\'" . bash-ts-mode))
  :hook (bash-ts-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(bash-ts-mode . ("bash-language-server" "start"))))

  (defun sh-mode-setup ()
    (add-hook 'before-save-hook #'eglot-format-buffer -10 t))

  (add-hook 'bash-ts-mode-hook #'sh-mode-setup))

(use-package just-mode
  :ensure t
  :mode ("[Jj]ustfile\\'" "\\.just\\'")
  :hook (just-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(just-mode . ("just-lsp")))))

;; (use-package justl
;;   :ensure t
;;   :after just-mode)

(use-package olivetti
  :ensure t
  ;; :hook (org-mode . olivetti-mode)  ; no auto-center in org buffers
  :custom
  (olivetti-style nil)  ; Use window margins (fringes disabled in early-init)
  (olivetti-margin-width 10)  ; No side margins
  ;; (olivetti-shrink t)
  (olivetti-safe t)
  :config
  ;; Guard: vertico-posframe calls `text-scale-set' on *Minibuf-1*, which
  ;; triggers olivetti's buffer-local text-scale-mode-hook. olivetti then
  ;; calls window-width on the minibuffer window (nil) -> wrong-type-argument.
  (add-hook 'minibuffer-setup-hook
            (lambda ()
              (when (bound-and-true-p olivetti-mode)
                (olivetti-mode -1))))
  (define-advice olivetti-set-window
      (:around (orig win) my/skip-minibuffer)
    (unless (window-minibuffer-p win)
      (funcall orig win)))
  (defun my/olivetti-rebalance (&rest _)
    (dolist (win (get-buffer-window-list nil nil 'visible))
      (when (buffer-local-value 'olivetti-mode (window-buffer win))
        (olivetti-set-window win))))
  (defun my/olivetti-hide-continuation-glyph ()
    (let ((dt (or buffer-display-table (make-display-table))))
      (set-display-table-slot dt 'wrap (if olivetti-mode ?\s nil))
      (setq buffer-display-table dt)))
  (add-hook 'olivetti-mode-hook #'my/olivetti-hide-continuation-glyph)
  (with-eval-after-load 'diff-hl-margin
    (advice-add 'diff-hl-margin-local-mode :after #'my/olivetti-rebalance)
    (advice-add 'diff-hl-margin-ensure-visible :after #'my/olivetti-rebalance)))

(use-package diff-hl
  :ensure t
  :hook ((prog-mode text-mode conf-mode) . diff-hl-mode)
  :custom
  (diff-hl-margin-symbols-alist
   '((insert . "┃") (delete . "▁") (change . "┃")
     (unknown . "?") (ignored . " ")))
  :config
  (diff-hl-flydiff-mode 1)
  (unless (display-graphic-p)
    (diff-hl-margin-mode 1)))

(use-package hl-todo
  :ensure (:host github :repo "tarsius/hl-todo")
  :config
  (global-hl-todo-mode)
  (setq hl-todo-keyword-faces
        '(("FIXME"      . "#FF4500")
          ("BUG"        . "#FF0000")
          ("DEBUG"      . "#A020F0")
          ("HACK"       . "#E6DB74")
          ("TODO"       . "#FF8C00")
          ("REVIEW"     . "#2D9574")
          ("OPTIMIZE"   . "#1E90FF")
          ("STUB"       . "#87CEEB")
          ("DEPRECATED" . "#808080"))))

(use-package magit
  :ensure (:wait t)
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

(defcustom my/auto-git-add-exclude-regexps
  '("/\\.git/" "/node_modules/" "/\\.direnv/" "/straight/" "/elpaca/"
    "\\.gpg\\'" "/\\.cache/" "/__pycache__/")
  "Paths matching these regexps are skipped by `my/auto-git-add-new-file'."
  :type '(repeat regexp)
  :group 'my)

(defun my/auto-git-add-new-file ()
  "Stage newly created file with intent-to-add so magit shows diffs.
Runs on `after-save-hook'. Only acts when the saved file is inside a
git project and currently untracked. Uses `git add -N' (intent-to-add)
so the working-tree diff stays visible until the user explicitly stages."
  (let ((file buffer-file-name))
    (when (and file
               (file-exists-p file)
               (not (seq-some (lambda (re) (string-match-p re file))
                              my/auto-git-add-exclude-regexps))
               (locate-dominating-file file ".git"))
      (let ((default-directory (file-name-directory file)))
        (when (and (zerop (call-process "git" nil nil nil "rev-parse" "--is-inside-work-tree"))
                   ;; ls-files --error-unmatch exits non-zero if untracked
                   (not (zerop (call-process "git" nil nil nil
                                             "ls-files" "--error-unmatch" file))))
          (call-process "git" nil nil nil "add" "-N" file)
          (when (fboundp 'magit-refresh)
            (magit-refresh))
          (message "auto-staged (intent-to-add): %s" (file-name-nondirectory file)))))))

(add-hook 'after-save-hook #'my/auto-git-add-new-file)

(defun my/magit-uncommit ()
  "Undo the last commit, leaving its changes in the working tree, unstaged."
  (interactive)
  (magit-reset-mixed "HEAD^")
  (message "Uncommitted HEAD^ — changes preserved, unstaged"))

(use-package indent-guide
  :defer t
  :ensure t
  :hook
  (prog-mode . indent-guide-mode)  ;; Activate indent-guide in programming modes.
  :config
  (setq indent-guide-char "│")    ;; Set the character used for the indent guide.
  (define-advice indent-guide-show (:around (orig) my/guard-stale-window)
    (when (and (eq (window-buffer) (current-buffer))
               (<= (window-start) (point-max)))
      (funcall orig))))

(use-package evil
  :ensure (:wait t)
  :init
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  (setq evil-want-C-u-delete t)
  (setq evil-want-C-u-scroll t)
  (setq evil-undo-system 'undo-redo)
  (setq evil-split-window-below t)
  (setq evil-vsplit-window-right t)
  (setq evil-paste-from-register nil)
  :config
  (evil-mode 1)
  (evil-set-initial-state 'help-mode 'emacs)
  (evil-set-initial-state 'messages-buffer-mode 'normal)
  (evil-set-initial-state 'dired-mode 'normal)
  (evil-set-initial-state 'ibuffer-mode 'normal)
  (evil-set-initial-state 'erc-mode 'normal)
  (define-key evil-insert-state-map (kbd "C-w") 'evil-window-map))

(modify-syntax-entry ?_ "w")

(defun my/eldoc-and-jump ()
  "Show documentation at point. Works in both GUI and terminal."
  (interactive)
  ;; (if (display-graphic-p)
  ;;     (eldoc-box-help-at-point)
  ;;   (eldoc-doc-buffer t))
  (eldoc-doc-buffer t))

(define-key evil-normal-state-map (kbd "K") #'my/eldoc-and-jump)

(use-package smartparens
  :ensure t
  :init
  (smartparens-global-mode 1)  
  :config
  (require 'smartparens-config)
  (sp-local-pair 'org-mode "~" nil :actions nil))
(use-package evil-smartparens
  :ensure t
  :after evil-collection
  :hook (smartparens-global-mode . evil-smartparens-mode))

(use-package evil-collection
  :after evil
  :ensure (:wait t)
  :config
  (evil-collection-init))

(use-package evil-surround
  :ensure t
  :after evil-collection
  :config
  (global-evil-surround-mode 1))

(use-package evil-matchit
  :ensure t
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

(use-package evil-mc
  :ensure t
  :after evil
  :config
  (global-evil-mc-mode 1)
  
  (defun my/evil-visual-block-p ()
    (and (bound-and-true-p evil-visual-selection)
         (eq evil-visual-selection 'block)))

  (defun my/evil-mc-visual-block-insert ()
    "Erstellt Cursor am Anfang des Blocks und wechselt in Insert-Mode."
    (interactive)
    (if (my/evil-visual-block-p)
        (progn
          (evil-mc-make-cursor-in-visual-selection-beg)
          (evil-insert 1))
      (call-interactively 'evil-insert)))

  (defun my/evil-mc-visual-block-append ()
    "Erstellt Cursor am Ende des Blocks und wechselt in Insert-Mode."
    (interactive)
    (if (my/evil-visual-block-p)
        (progn
          (evil-mc-make-cursor-in-visual-selection-end)
          (evil-append 1))
      ;; Fallback: normales Verhalten
      (call-interactively 'evil-append)))

  (define-key evil-visual-state-map (kbd "I") 'my/evil-mc-visual-block-insert)
  (define-key evil-visual-state-map (kbd "A") 'my/evil-mc-visual-block-append))

(use-package flash
  :ensure (:host github :repo "Prgebish/flash")
  :after evil
  :custom
  (flash-multi-window t)
  (flash-backdrop t)
  (flash-case-fold t)
  (flash-autojump t)
  (flash-highlight-matches t)
  (flash-label-position 'overlay)
  (flash-jump-position 'start)
  (flash-char-jump-labels t)
  (flash-char-multi-line nil)
  (flash-nohlsearch t)
  (flash-jumplist t)
  (flash-rainbow t)
  (flash-rainbow-shade 5)
  :config
  ;; Evil integration: binds gs in normal/visual/operator + enhanced f/t/F/T
  (require 'flash-evil)
  (flash-evil-setup t)

  ;; Restore ; and , after flash-char overwrites them
  ;; ; is used as prefix for prev-navigation (;b, ;d)
  ;; , is the local leader
  (evil-define-key* '(normal visual motion) 'global
    (kbd ";") nil
    (kbd ",") nil)

  ;; Search integration: labels during C-s, /, ?
  (require 'flash-isearch)
  (flash-isearch-mode 1))

(setq undo-limit 800000
      undo-strong-limit 12000000
      undo-outer-limit 120000000)

(use-package rainbow-delimiters
  :defer t
  :ensure t
  :hook
  (prog-mode . rainbow-delimiters-mode))

(use-package dotenv-mode
  :defer t
  :ensure t
  :config)

(add-hook 'org-agenda-finalize-hook #'org-save-all-org-buffers)
(use-package org-agenda
  :ensure nil
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

(use-package nerd-icons-dired
  :if ek-use-nerd-fonts                   ;; Load the package only if the user has configured to use nerd fonts.
  :ensure t                               ;; Ensure the package is installed.
  :defer t                                ;; Load the package only when needed to improve startup time.
  :hook
  (dired-mode . nerd-icons-dired-mode))

(use-package diredfl
  :ensure t
  :hook
  ((dired-mode . diredfl-mode)
   (dirvish-directory-view-mode . diredfl-mode)))

(use-package nerd-icons-completion
  :if ek-use-nerd-fonts                   ;; Load the package only if the user has configured to use nerd fonts.
  :ensure t                               ;; Ensure the package is installed.
  :after nerd-icons
  :config
  (nerd-icons-completion-mode))

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

(display-time-mode 1)

(defvar-local my/doom-modeline--buffer-title nil)

(defun my/doom-modeline--update-title-cache ()
  "Update the cached #+title for the current buffer."
  (setq-local my/doom-modeline--buffer-title
              ;; `org-collect-keywords' runs the org element parser, which
              ;; errors (rx range error) outside org-mode buffers.
              (and (derived-mode-p 'org-mode)
                   (cadar (org-collect-keywords '("TITLE"))))))

(defun my/doom-modeline--buffer-title ()
  "Return the cached #+title, computing it if necessary."
  (unless (local-variable-p 'my/doom-modeline--buffer-title)
    (my/doom-modeline--update-title-cache))
  my/doom-modeline--buffer-title)

(defun my/doom-modeline-set-buffer-title (&rest _)
  "Override doom-modeline's cached file name with the Org #+title.
If no TITLE keyword is found, leave doom-modeline's default name."
  (when-let* ((title (my/doom-modeline--buffer-title)))
    (setq doom-modeline--buffer-file-name
          (propertize title
                      'face 'doom-modeline-buffer-file
                      'mouse-face 'mode-line-highlight
                      'help-echo (concat (or buffer-file-truename (buffer-name))
                                         "\nmouse-1: Previous buffer\nmouse-3: Next buffer")
                      'local-map mode-line-buffer-identification-keymap))))

(defun my/doom-modeline--invalidate-title-cache ()
  "Invalidate the cached title so it gets recomputed on next update."
  (kill-local-variable 'my/doom-modeline--buffer-title))

(use-package doom-modeline
  :ensure t
  :init (doom-modeline-mode 1)
  :config
  (setq doom-modeline-hud t
        doom-modeline-irc t
        doom-modeline-irc-buffers nil
        doom-modeline-mu4e t
        doom-modeline-buffer-file-name-style 'relative-to-project
        doom-modeline-buffer-encoding nil
        doom-modeline-time t
        doom-modeline-time-live-icon t)

  ;; Replace the channel-list segment with the icon-only segment in ERC buffers.
  (doom-modeline-def-modeline 'special
    '(eldoc bar window-state window-number modals matches buffer-info remote-host buffer-position word-count parrot selection-info)
    '(compilation objed-state misc-info battery irc debug minor-modes input-method indent-info buffer-encoding major-mode process time))

  (advice-add #'doom-modeline-update-buffer-file-name :after #'my/doom-modeline-set-buffer-title)
  (add-hook 'before-save-hook #'my/doom-modeline--invalidate-title-cache))

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

(defvar cashmere/font-height 160)

(defun cashmere/set-fonts (&optional frame)
  "Apply the MapleMono faces, but only on graphical frames.
Runs per-frame so a TTY-only daemon never touches fonts while GUI frames
created later still get them."
  (when (display-graphic-p frame)
    (set-face-attribute 'default frame
                        :family "Maple Mono NF"
                        :height cashmere/font-height
                        :font (font-spec
                               :family "Maple Mono NF"
                               :features '(cv04 ss05 zero)
                               ))
    (set-face-attribute 'fixed-pitch frame :family "Maple Mono NF" :weight 'regular)
    (set-face-attribute 'variable-pitch frame :family "Maple Mono NF" :weight 'regular :height 1.1)))

(add-hook 'server-after-make-frame-hook #'cashmere/set-fonts)
(cashmere/set-fonts)



(use-package dirvish
  :ensure (:host github :repo "latiagertrutis/dirvish" :branch "main")
  :init
  (dirvish-override-dired-mode)

  :custom
  (dirvish-quick-access-entries
   '(("h" "~/" "home")
     ("d" "~/Downloads/" "downloads")
     ("c" "~/.config/" "config")))

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

  (define-advice dirvish--preview-dps-validate
      (:around (fn &optional dps) tty-media-filter)
    "Drop GUI-only media dispatchers when the session's frame is a TTY."
    (let ((dps (if (display-graphic-p)
                   dps
                 (cl-remove-if (lambda (d)
                                 (memq d '(image gif video video-mtn)))
                               (or dps dirvish-preview-dispatchers)))))
      (funcall fn dps))))

(use-package zoxide
  :ensure t
  :config
  (defun my/zoxide-add-dired ()
    "Append the current dired/dirvish directory to the zoxide database."
    (when (and default-directory
               (not (file-remote-p default-directory)))
      (zoxide-add default-directory)))
  (add-hook 'dired-after-readin-hook #'my/zoxide-add-dired))

(use-package croc-ui
  :ensure nil
  :commands (croc-ui croc-ui-send-files croc-ui-send-directory
             croc-ui-send-text croc-ui-receive)
  :init
  (with-eval-after-load 'general
    (my-leader "oc" '(croc-ui :wk "croc"))))

(use-package sync-ui
  :ensure nil
  :commands (sync-ui))
  :init
  (with-eval-after-load 'general
    (my-leader "oy" '(sync-ui :wk "sync")))

(defun my/reload-config ()
  "Re-tangle config.org and reload the generated config.el in place.
Applies changes to customs, hooks, keybindings, and variable
settings without restarting Emacs. Packages that are newly added
still require a restart since elpaca queues run at init time."
  (interactive)
  (let* ((org-file  (expand-file-name "config.org" user-emacs-directory))
         (el-file   (expand-file-name "config.el"  user-emacs-directory))
         (start     (current-time)))
    (message "Reloading config…")
    ;; 1. Tangle org → el (skips up-to-date blocks automatically)
    (org-babel-tangle-file org-file el-file "emacs-lisp")
    ;; 2. Load the freshly tangled file
    (load-file el-file)
    (message "Config reloaded in %.2fs"
             (float-time (time-since start)))))

(setq-default olivetti-body-width 100)
(defun my/olivetti-suitable-buffer-p ()
  (and (buffer-file-name)
       (not (minibufferp))
       (not (derived-mode-p 'special-mode))
       (not (string-prefix-p " " (buffer-name)))))

(define-globalized-minor-mode my/global-olivetti-mode olivetti-mode
  (lambda () (when (my/olivetti-suitable-buffer-p) (olivetti-mode 1))))
;; (my/centered-cursor)
;; (my/global-olivetti-mode)

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
  :ensure (:wait t)
  :demand t
  :config
  (projectile-mode +1)
  (setq projectile-completion-system 'default
        projectile-enable-caching t
        projectile-indexing-method 'alien
        projectile-sort-order 'recentf
        projectile-require-project-root nil
        projectile-globally-ignored-buffers '("\\*magit.*"))
  (add-hook 'after-save-hook #'projectile-cache-current-file))

(use-package helm-projectile
  :ensure t
  :after (helm projectile)
  :commands (helm-projectile-find-file helm-projectile-switch-project)
  :custom
  (helm-projectile-fuzzy-match t))

(use-package wgrep
  :ensure t
  :defer t
  :custom
  (wgrep-auto-save-buffer t)
  (wgrep-change-readonly-file t))

(use-package wgrep-helm
  :ensure t
  :after (wgrep helm))

(defun my/project-replace ()
  "Project-wide search via `helm-do-grep-ag-project'.
Press `C-x C-s' in the helm session to save results to a *hgrep*
buffer, then `C-c C-p' (wgrep-change-to-wgrep-mode) to edit in
place. `C-c C-c' commits, `C-c C-k' aborts."
  (interactive)
  (call-interactively #'helm-do-grep-ag-project))

(defun my/helm-find-in (dir)
  (interactive "DFind files in: ")
  (helm-find-1 dir))

(defun my/helm-grep-in (dir)
  (interactive "DGrep in: ")
  (let ((default-directory (file-name-as-directory dir)))
    (helm-do-grep-ag nil)))

(defun my/denote-grep ()
  (interactive)
  (let ((default-directory (expand-file-name denote-directory)))
    (helm-do-grep-ag nil)))

(use-package persp-mode
  :ensure t
  :demand t
  :init
  (setq persp-keymap-prefix nil)
  :config
  (defvar my/workspaces-master "master")
  (defvar my/workspace-last nil)
  (defvar my/workspaces-on-switch-project 'non-empty)
  (defvar my/workspace-switch-project-function #'helm-projectile-find-file)

  (setq persp-autokill-buffer-on-remove 'kill-weak
        persp-reset-windows-on-nil-window-conf nil
        persp-nil-hidden t
        persp-auto-save-fname "autosave"
        persp-save-dir (file-name-concat user-emacs-directory "workspaces/")
        persp-set-last-persp-for-new-frames t
        persp-switch-to-added-buffer nil
        persp-add-buffer-on-after-change-major-mode t
        persp-kill-foreign-buffer-behaviour 'kill
        persp-remove-buffers-from-nil-persp-behaviour nil
        persp-auto-resume-time -1
        persp-auto-save-opt 0
        uniquify-buffer-name-style nil)

  (add-to-list 'persp-filter-save-buffers-functions
               (lambda (buffer)
                 (with-current-buffer buffer
                   (memq major-mode '(eat-mode vterm-mode term-mode shell-mode eshell-mode ghostel-mode)))))

  (defface my/workspace-tab-selected '((t (:inherit highlight)))
    "Active workspace tab." :group 'persp-mode)
  (defface my/workspace-tab '((t (:inherit default)))
    "Inactive workspace tab." :group 'persp-mode)

  (defun my/workspace-current-name ()
    (safe-persp-name (get-current-persp)))
  (defun my/workspace-names ()
    (cl-remove persp-nil-name persp-names-cache :count 1))
  (defun my/workspace-protected-p (name)
    (equal name persp-nil-name))
  (defun my/workspace-exists-p (name)
    (member name (my/workspace-names)))
  (defun my/workspace-fallback-buffer ()
    (get-buffer-create "*scratch*"))
  (defun my/workspace-buffer-list (&optional persp)
    (persp-buffers (or persp (get-current-persp))))

  (defun my/workspace-switch (name &optional create)
    (unless (my/workspace-exists-p name)
      (if create
          (persp-add-new name)
        (user-error "No workspace named '%s'" name)))
    (let ((old (my/workspace-current-name)))
      (unless (equal old name)
        (setq my/workspace-last
              (if (my/workspace-protected-p old) my/workspaces-master old))
        (persp-frame-switch name))))

  (defun my/workspace-switch-to-index (index)
    (let ((name (nth index (my/workspace-names))))
      (if name
          (progn (my/workspace-switch name) (my/workspace-display))
        (user-error "No workspace #%d" (1+ index)))))

  (defun my/workspace--tabline ()
    (let ((current (my/workspace-current-name))
          (i 0))
      (mapconcat
       (lambda (name)
         (setq i (1+ i))
         (propertize (format " [%d] %s " i name)
                     'face (if (equal current name)
                               'my/workspace-tab-selected
                             'my/workspace-tab)))
       (my/workspace-names)
       " ")))

  (defun my/workspace-display ()
    (interactive)
    (let (message-log-max)
      (message "%s" (my/workspace--tabline))))

  (defun my/workspace-new (&optional name)
    (interactive)
    (let ((name (or name
                    (read-string "New workspace: "
                                 (format "#%d" (1+ (length (my/workspace-names))))))))
      (when (my/workspace-protected-p name)
        (user-error "Reserved workspace name"))
      (when (my/workspace-exists-p name)
        (user-error "Workspace '%s' already exists" name))
      (my/workspace-switch name t)
      (switch-to-buffer (my/workspace-fallback-buffer))
      (my/workspace-display)))

  (defun my/workspace-rename (new-name)
    (interactive (list (read-string "Rename workspace to: " (my/workspace-current-name))))
    (when (my/workspace-protected-p (my/workspace-current-name))
      (user-error "Can't rename this workspace"))
    (persp-rename new-name (get-current-persp))
    (my/workspace-display))

  (defun my/workspace-kill (&optional name)
    (interactive)
    (let* ((name (or name (my/workspace-current-name)))
           (others (remove name (my/workspace-names))))
      (when (my/workspace-protected-p name)
        (user-error "Can't kill this workspace"))
      (if (null others)
          (progn
            (my/workspace-switch my/workspaces-master t)
            (unless (equal name my/workspaces-master)
              (persp-kill name)))
        (when (equal name (my/workspace-current-name))
          (my/workspace-switch
           (if (my/workspace-exists-p my/workspace-last)
               my/workspace-last
             (car others))))
        (persp-kill name))
      (my/workspace-display)))

  (defun my/workspace-kill-session ()
    (interactive)
    (when (yes-or-no-p "Clear all workspaces and buffers? ")
      (let ((persp-autokill-buffer-on-remove t))
        (dolist (n (my/workspace-names))
          (unless (equal n my/workspaces-master)
            (persp-kill n))))
      (my/workspace-switch my/workspaces-master t)
      (delete-other-windows)
      (switch-to-buffer (my/workspace-fallback-buffer))
      (my/workspace-display)))

  (defun my/workspace-switch-to (name)
    (interactive (list (completing-read "Switch to workspace: " (my/workspace-names))))
    (my/workspace-switch name t)
    (my/workspace-display))

  (defun my/workspace-switch-to-final ()
    (interactive)
    (when-let* ((name (car (last (my/workspace-names)))))
      (my/workspace-switch name)
      (my/workspace-display)))

  (defun my/workspace-other ()
    (interactive)
    (if (and my/workspace-last (my/workspace-exists-p my/workspace-last))
        (progn (my/workspace-switch my/workspace-last) (my/workspace-display))
      (user-error "No other workspace")))

  (defun my/workspace-cycle (n)
    (let* ((names (my/workspace-names))
           (count (length names))
           (index (cl-position (my/workspace-current-name) names :test #'equal)))
      (if (or (null index) (= count 1))
          (user-error "No other workspace")
        (my/workspace-switch (nth (mod (+ index n) count) names))
        (my/workspace-display))))

  (defun my/workspace-switch-left ()
    (interactive)
    (my/workspace-cycle -1))
  (defun my/workspace-switch-right ()
    (interactive)
    (my/workspace-cycle 1))

  (defun my/workspace-save-session ()
    (interactive)
    (persp-save-state-to-file))
  (defun my/workspace-load-session ()
    (interactive)
    (persp-load-state-from-file)
    (my/workspace-display))

  (defun my/workspace-close-window-or-workspace ()
    (interactive)
    (let ((delete-fn (if (featurep 'evil) #'evil-window-delete #'delete-window)))
      (if (or (window-dedicated-p)
              (my/workspace-protected-p (my/workspace-current-name))
              (cdr (window-list)))
          (funcall delete-fn)
        (my/workspace-kill (my/workspace-current-name)))))

  (defun my/workspace-init-main (&rest _)
    (when persp-mode
      (let (persp-before-switch-functions)
        (unless (or (persp-get-by-name my/workspaces-master)
                    (> (hash-table-count *persp-hash*) 2))
          (persp-add-new my/workspaces-master))
        (when (equal (my/workspace-current-name) persp-nil-name)
          (persp-frame-switch my/workspaces-master)))))
  (add-hook 'persp-mode-hook #'my/workspace-init-main)

  (defun my/workspace-switch-to-project (&optional dir)
    (let* ((dir (or dir default-directory))
           (name (projectile-project-name dir)))
      (when persp-mode
        (if (or (eq my/workspaces-on-switch-project t)
                (my/workspace-protected-p (my/workspace-current-name))
                (my/workspace-buffer-list))
            (progn
              (my/workspace-switch name t)
              (switch-to-buffer (my/workspace-fallback-buffer)))
          (ignore-errors (persp-rename name (get-current-persp))))
        (let ((default-directory dir))
          (funcall my/workspace-switch-project-function)))))
  (with-eval-after-load 'projectile
    (setq projectile-switch-project-action #'my/workspace-switch-to-project))

  (define-key persp-mode-map [remap delete-window]
              #'my/workspace-close-window-or-workspace)
  (with-eval-after-load 'evil
    (define-key persp-mode-map [remap evil-window-delete]
                #'my/workspace-close-window-or-workspace))

  (add-hook 'persp-filter-save-buffers-functions
            (lambda (buf)
              (with-current-buffer buf (derived-mode-p 'erc-mode))))

  (defun my/workspace--inhibit-irc-part (orig &rest args)
    (let ((erc-kill-channel-hook nil)
          (erc-kill-server-hook nil)
          (erc-kill-buffer-hook nil))
      (apply orig args)))
  (advice-add 'my/workspace-kill :around #'my/workspace--inhibit-irc-part)
  (advice-add 'my/workspace-kill-session :around #'my/workspace--inhibit-irc-part)

  (persp-mode 1))

(with-eval-after-load 'ibuffer
  (define-ibuffer-filter persp
      "Limit to buffers in the current workspace."
    (:description "current workspace")
    (persp-contain-buffer-p buf)))

(defun my/ibuffer-workspace ()
  (interactive)
  (let ((name (my/workspace-current-name)))
    (if (equal name my/workspaces-master)
        (ibuffer nil "*ibuffer: master*")
      (ibuffer nil (format "*ibuffer: %s*" name)
               (list (cons 'persp t))))))

(my-leader
  "TAB"     '(:ignore t :wk "workspace")
  "TAB TAB" '(my/workspace-display :wk "display")
  "TAB ."   '(my/workspace-switch-to :wk "switch to…")
  "TAB `"   '(my/workspace-other :wk "last")
  "TAB n"   '(my/workspace-new :wk "new")
  "TAB r"   '(my/workspace-rename :wk "rename")
  "TAB d"   '(my/workspace-kill :wk "delete")
  "TAB x"   '(my/workspace-kill-session :wk "kill session")
  "TAB s"   '(my/workspace-save-session :wk "save session")
  "TAB l"   '(my/workspace-load-session :wk "load session")
  "TAB ["   '(my/workspace-switch-left :wk "prev")
  "TAB ]"   '(my/workspace-switch-right :wk "next")
  "TAB 1"   '((lambda () (interactive) (my/workspace-switch-to-index 0)) :wk "1")
  "TAB 2"   '((lambda () (interactive) (my/workspace-switch-to-index 1)) :wk "2")
  "TAB 3"   '((lambda () (interactive) (my/workspace-switch-to-index 2)) :wk "3")
  "TAB 4"   '((lambda () (interactive) (my/workspace-switch-to-index 3)) :wk "4")
  "TAB 5"   '((lambda () (interactive) (my/workspace-switch-to-index 4)) :wk "5")
  "TAB 6"   '((lambda () (interactive) (my/workspace-switch-to-index 5)) :wk "6")
  "TAB 7"   '((lambda () (interactive) (my/workspace-switch-to-index 6)) :wk "7")
  "TAB 8"   '((lambda () (interactive) (my/workspace-switch-to-index 7)) :wk "8")
  "TAB 9"   '((lambda () (interactive) (my/workspace-switch-to-index 8)) :wk "9")
  "TAB 0"   '(my/workspace-switch-to-final :wk "last"))

(general-def '(normal motion)
  "gt" 'my/workspace-switch-right
  "gT" 'my/workspace-switch-left)

(dotimes (i 9)
  (general-define-key
   :states '(normal visual)
   :keymaps 'override
   :prefix ","
   (number-to-string (1+ i))
   `(lambda () (interactive) (my/workspace-switch-to-index ,i))))
(general-define-key
 :states '(normal visual)
 :keymaps 'override
 :prefix ","
 "0" #'my/workspace-switch-to-final)

(use-package pass
  :ensure t
  :defer t
  :commands (pass)
  :config
  (setq pass-view-font-lock-keywords
        '(("\\(^[^:\t\n]+:\\) " 1 'font-lock-keyword-face)))

  (add-to-list 'display-buffer-alist
               '("\\*Pass.*\\*"
                 (display-buffer-full-frame)))

  (with-eval-after-load 'evil
    (general-def 'normal pass-mode-map
      "q"   'quit-window
      "j"   'pass-next-entry
      "k"   'pass-prev-entry
      "RET" 'pass-view
      "d"   'pass-kill
      "y"   'pass-copy
      "Y"   'pass-copy-field
      "e"   'pass-edit
      "a"   'pass-insert
      "G"   'pass-insert-generated
      "o"   'pass-otp-options
      "r"   'pass-rename
      "/"   'isearch-forward)

    (general-def 'normal pass-view-mode-map
      "q"   'quit-window
      "t"   'pass-view-toggle-password
      "y"   'pass-copy
      "Y"   'pass-copy-field)))

(use-package auth-source
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
  (setq golden-ratio-exclude-buffer-names '(" *which-key*"))
  (setq golden-ratio-exclude-buffer-regexp '("\\`\\*eldoc")))

(use-package pdf-tools
  :ensure nil
  :if (display-graphic-p)
  :magic ("%PDF" . pdf-view-mode)
  :config
  (pdf-loader-install)
  :hook (pdf-view-mode . (lambda () (display-line-numbers-mode -1))))

;; Site-lisp may pre-register pdf-view-mode in magic-mode-alist on TUI emacs.
;; Strip those entries so opening a PDF in -nw falls back to doc-view/fundamental.
(unless (display-graphic-p)
  (setq magic-mode-alist
        (seq-remove (lambda (e) (eq (cdr e) 'pdf-view-mode)) magic-mode-alist))
  (setq auto-mode-alist
        (seq-remove (lambda (e) (eq (cdr e) 'pdf-view-mode)) auto-mode-alist)))

(defun my/format-buffer ()
  (interactive)
  (cond
   ((eq major-mode 'rust-ts-mode) (eglot-format-buffer))
   ((eq major-mode 'nix-ts-mode) (eglot-format-buffer))  
   ((eq major-mode 'python-ts-mode) (eglot-format-buffer))
   ((eq major-mode 'c-mode) (eglot-format-buffer))
   ((bound-and-true-p eglot--managed-mode) (eglot-format-buffer))
   (t (message "No formatter for %s" major-mode))))

(defun my/find-file-or-switch-project ()
  "Find a file in the current project; outside one, pick a project first.
Uses the native Helm sources from `helm-projectile'.  Picking a project
switches to its workspace and shows its files via
`projectile-switch-project-action', so this also works from the master
workspace (e.g. *scratch*)."
  (interactive)
  (if (projectile-project-p)
      (helm-projectile-find-file)
    (helm-projectile-switch-project)))

(my-leader
  "SPC" '(my/find-file-or-switch-project :wk "find file/switch project")
  "sp" '(helm-projectile :wk "search project")
  "ss" '(helm-occur :wk "search line")
  "sg" '(my/helm-grep-in :wk "grep in dir")
  "sf" '(my/helm-find-in :wk "find file in dir")
  "/" '(helm-do-grep-ag-project :wk "search project")
  "." '(helm-find-files :wk "find file")
  "," '(helm-mini :wk "switch buffer")
  ":" (lambda () (interactive) (execute-extended-command nil))
  "u" '(universal-argument :wk "universal argument")

  "d" '(:ignore t :wk "denote")
  "da" '(my/denote-toggle-agenda-keyword :wk "toggle agenda tag")
  "dj" '(denote-journal-new-or-existing-entry :wk "journal")
  "dd" '(denote-menu t :wk "List all notes")
  "dm" '(:ignore t :wk "Merge Notes")
  "dmr" '(denote-merge-region :wk "Merge Region")
  "dmf" '(denote-merge-file :wk "Merge File")
  "dg" '(my/denote-grep :wk "Search")
  "dl" '(denote-link-or-create t :wk "Link Note")
  "dn" '(denote t :wk "Create a new note")
  "dr" '(denote-rename-file t :wk "Rename Note")
  "ds" '(denote-solo-switch :wk "switch silo")
  "dtl" '(tmr-list-timers :wk "list timer")
  "dtt" '(tmr :wk "set timer")

  "f" '(:ignore t :wk "files")
  "fd" '(dired-jump :wk "dired")
  "fD" '(dired-jump :wk "dired jump")
  "fr" '(helm-recentf :wk "recent files")
  "ff" '(helm-find-files :wk "find file")
  "fs" '(save-buffer :wk "save file")

  "b" '(:ignore t :wk "buffer/bookmarks")
  "bb" '(helm-filtered-bookmarks :wk "display current bookmarks")
  "bi" '(my/ibuffer-workspace :wk "ibuffer (workspace)")
  "bp" '(projectile-ibuffer :wk "ibuffer project")
  "bd" '(bookmark-delete :wk "delete bookmark")
  "bk" '(kill-current-buffer :wk "kill buffer")
  "bs" '(bookmark-set :wk "save bookmark")
  "br" '(rename-buffer :wk "rename buffer")

  "p" '(:ignore t :wk "project")
  "pp" '(helm-projectile-switch-project :wk "switch project workspace")
  "pf" '(helm-projectile-find-file :wk "find file")
  "ps" '(helm-projectile-rg :wk "search")
  "pb" '(helm-projectile-switch-to-buffer :wk "buffers")
  "pk" '(projectile-kill-buffers :wk "kill buffers") 
  "pd" '(projectile-remove-known-project :wk "delete project")
  "pr" '(my/project-replace :wk "project replace (wgrep)")
  "pa" '(projectile-add-known-project :wk "add project")
  "pi" '(projectile-invalidate-cache :wk "invalidate cache")
  "pt" '(projectile-run-task :wk "tasks")

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
  "gu" '(my/magit-uncommit :wk "uncommit (keep & unstage)")
  "gb" '(vc-annotate :wk "blame")
  "gT" '(my/code-todos-harvest :wk "harvest code TODOs")
  "aa" '(agent-shell :wk "start")
  "at" '(agent-shell-toggle :wk "toggle")
  "am" '(agent-shell-help-menu :wk "open session")
  "ar" '(agent-shell-send-region :wk "send region")
  "o" '(:ignore t :wk "open")
  "oa" '(my/app-launcher :wk "app launcher")
  "os" '(my/snip-upload :wk "snip buffer/region")
  "oS" '(my/snip-upload-file :wk "snip file")
  "op" '(pass :wk "pass")
  "ot" '(ghostel :wk "ghostel")

  "h" '(:ignore t :wk "help")
  "hm" '(describe-mode :wk "mode")
  "hf" '(describe-function :wk "function")
  "hv" '(describe-variable :wk "variable")
  "hk" '(describe-key :wk "key")
  ;; "ht" '(load-theme :wk "load theme")

  "w w" '(evil-window-next :wk "Close window")
  "w c" '(evil-window-delete :wk "Close window")
  "w o" '(delete-other-windows :wk "Maximize window")
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
  "cc" '(my/compile-or-recompile :wk "compile")
  "cC" '(ghostel-compile :wk "recompile")
  "ca" '(eglot-code-actions :wk "code actions")
  "cr" '(eglot-rename :wk "lsp rename")
  "cf" '(eglot-format :wk "format buffer")
  "cs" '(yas-insert-snippet :wk "snippets")
  "cl" '(flycheck-list-errors :wk "list errors")

  "q" '(:ignore t :wk "quit")
  "qq" '(save-buffers-kill-terminal :wk "quit emacs")
  "qr" '(restart-emacs :wk "restart")
  "hr" '(my/reload-config :wk "reload config")

  "x" '(org-capture :wk "capture")

  ";" '(embark-act :wk "embark")
  "P" '(helm-show-kill-ring :wk "paste history")

  ;; "t" '(:ignore t :wk "treesitter")
  ;; "ts" '(flash-treesitter :wk "flash treesitter")


  "e"   '(:ignore t :wk "eww/web")
  "e e" '(eww :wk "eww browse / search")
  "e n" '(my/eww-new-buffer :wk "new eww buffer")
  "e b" '(eww-list-bookmarks :wk "bookmarks")
  "e h" '(eww-list-histories :wk "history")
  "e f" '(elfeed :wk "elfeed (rss)")
  "e s" '(engine/search-duckduckgo :wk "search duckduckgo")
  "e L" '(link-hint-open-link :wk "hint open link")
  "e C" '(link-hint-copy-link :wk "hint copy link")
  )

(defun my/flash-enabled-p ()
  (and (not (derived-mode-p 'magit-mode 'dired-mode 'ibuffer-mode))
       (not (eq major-mode 'dirvish-mode))))

(defun my/s-key-dispatch ()
  (interactive)
  (if (derived-mode-p 'magit-mode)
      (call-interactively 'magit-stage)
    (when (my/flash-enabled-p)
      (let ((scroll-margin 0)
            (maximum-scroll-margin 0))
        (call-interactively 'flash-evil-jump)))))

(general-def '(normal visual operator) 'override
  :predicate '(not (derived-mode-p 'mu4e-main-mode 'mu4e-headers-mode
                                    'mu4e-view-mode 'mu4e-compose-mode
                                    'croc-ui-mode 'sync-ui-mode))
  "s" 'my/s-key-dispatch)


(general-def 'normal 'override
  "K" 'my/eldoc-and-jump
  "]d" 'flycheck-next-error
  "[d" 'flycheck-previous-error
  "]c" 'diff-hl-next-hunk
  "[c" 'diff-hl-previous-hunk
  "]b" 'switch-to-next-buffer
  "[b" 'switch-to-prev-buffer
  "]t" 'tab-next
  "[t" 'tab-previous
  "P" 'helm-show-kill-ring
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
  "mk" '(kitty-graphics-org-heading-sizes :wk "kgfx headlines")
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
  "ll" '(org-insert-link :wk "link various things")

  "n" '(org-toggle-narrow-to-subtree :wk "narrow"))

(evil-define-key 'normal org-mode-map (kbd "RET") 'org-open-at-point)

(my-leader
  :keymaps '(rust-ts-mode-map)
  "m" '(:wk "rust mode" :ignore)
  "mr" '(rust-run :wk "run")
  "mc" '(rust-run-clippy :wk "clippy")
  "mC" '(rust-check :wk "check"))

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

(defun dirvish-next-file (arg)
  "Move down ARG lines, landing on the filename column.
Uses raw line motion so hidden detail lines (permissions, owner,
date) and the dired header are never skipped."
  (interactive "^p")
  (forward-line arg)
  (dired-move-to-filename))

(defun dirvish-prev-file (arg)
  "Move up ARG lines, landing on the filename column."
  (interactive "^p")
  (forward-line (- arg))
  (dired-move-to-filename))

(general-def 'normal dired-mode-map
  "h" 'dired-up-directory
  "l" 'dired-find-file)

(general-def 'normal dirvish-mode-map
  "?" 'dirvish-dispatch
  "q" 'dirvish-quit
  "b" 'dirvish-quick-access
  "f" 'dirvish-file-info-menu
  "p" 'dirvish-yank
  "S" 'dirvish-quicksort
  "F" 'dirvish-layout-toggle
  "z" 'zoxide-travel
  "j" 'dirvish-next-file
  "k" 'dirvish-prev-file
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

(defun my/dirvish-copy-to-clipboard (&rest _)
  (my/send-to-clipboard (car kill-ring)))

(dolist (fn '(dirvish-copy-file-path
              dirvish-copy-file-name
              dirvish-copy-file-true-path))
  (advice-add fn :after #'my/dirvish-copy-to-clipboard))

(defun my/eshell-clear ()
  (interactive)
  (eshell/clear-scrollback))

(defun my/atuin-history ()
  (interactive)
  (eshell-atuin-history))

(with-eval-after-load 'eshell
  (add-hook 'eshell-mode-hook
            (lambda ()
              (local-set-key (kbd "C-l") 'my/eshell-clear)
              (local-set-key (kbd "C-r") 'my/atuin-history))))

(with-eval-after-load 'evil
  (with-eval-after-load 'eshell
    (evil-define-key '(normal insert) eshell-mode-map
      (kbd "C-r") 'my/atuin-history
      (kbd "C-l") 'my/eshell-clear)))

(my-local-leader
  "a" '(org-agenda :wk "org agenda")
  "c" '(my/centered-cursor :wk "center cursor")
  "f" '(dirvish :wk "file manager")
  "m" '(mu4e :wk "mu4e")
  "i" '(run-irc :wk "irc")
  "r" '(async-shell-command :wk "run async")
  "t" '(ghostel-project :wk "terminal (project)")
  "T" '(ghostel-list-buffers :wk "terminal (switch)")
  "z" '(golden-ratio-mode :wk "zoom/golden ratio")
  "o" '(my/global-olivetti-mode :wk "center buffer")
  "s" '(my-org-sidecar-left :wk "org sidecar"))

(global-set-key (kbd "C-=") 'text-scale-increase)
(global-set-key (kbd "C--") 'text-scale-decrease)

(use-package elfeed
  :ensure (:host github :repo "emacs-elfeed/elfeed" :branch "main")
  :defer t
  :custom
  (elfeed-db-directory "~/.emacs.d/elfeed")
  :config
  (setq elfeed-search-filter "@2-weeks-ago +unread"
        elfeed-search-title-max-width 110)
  (setq elfeed-use-libxml 't)
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

(use-package elfeed-protocol
  :ensure (:host github :repo "fasheng/elfeed-protocol")
  :after elfeed
  :custom
  (elfeed-protocol-work-with-others t)
  (elfeed-protocol-enabled-protocols '(ttrss))
  :init
  (add-to-list 'elfeed-feeds
               '("ttrss+https://cashmere@rss.cashmere.rs"
                 :password (password-store-get "rss.cashmere.rs"))
               :append)
  :config
  (elfeed-protocol-enable))

(defun my/elfeed-reset ()
  "Delete the local elfeed database and re-fetch everything from tt-rss.
Fixes stale feeds that were removed server-side but still show up
locally.  Note: entries no longer present on the server are lost."
  (interactive)
  (when (yes-or-no-p "Delete local elfeed db and re-fetch all feeds from tt-rss? ")
    (elfeed-db-unload)
    (delete-directory elfeed-db-directory t)
    (make-directory elfeed-db-directory t)
    (elfeed-db-load)
    (elfeed-update)))

(use-package elfeed-goodies
  :ensure t
  :after elfeed
  :config
  (elfeed-goodies/setup))

(with-eval-after-load 'elfeed
  (require 'shrface)
  (add-hook 'elfeed-show-mode-hook
            (lambda ()
              (visual-line-mode 1)
              (setq-local shr-width nil
                          shr-use-fonts t
                          shr-max-image-proportion 0.6
                          shr-indentation 2
                          line-spacing 0.2)
              (shrface-mode 1))))

(setq browse-url-browser-function 'eww-browse-url
      browse-url-secondary-browser-function 'browse-url-generic
      browse-url-generic-program "qutebrowser")

(defun my/browse-url-no-frame-guard (orig url &rest args)
  "Around-advice for `browse-url' that resolves and calls the handler
directly, bypassing the upstream `browse-url' body.

Emacs 30+ unconditionally calls `(frame-parameter nil \\='display)`
inside `browse-url' to set DISPLAY from the selected frame. That raises
\"Frames are not in use or not initialized\" in daemon contexts, and
in TUI-only setups the native-compiled frame access inside the subr
can throw even when `(frame-live-p (selected-frame))' returns non-nil
in the caller (the two checks diverge).

For the handlers registered here (`eww-browse-url' is in-frame,
`browse-url-generic' inherits DISPLAY from the daemon env) the DISPLAY
reset is unnecessary, so do the handler resolution ourselves and skip
`browse-url' entirely."
  (interactive (browse-url-interactive-arg "URL: "))
  (unless (called-interactively-p 'interactive)
    (setq args (or args (list browse-url-new-window-flag))))
  (let ((function (or (browse-url-select-handler url)
                      browse-url-browser-function)))
    (if (functionp function)
        (apply function url args)
      (error "No suitable browser for URL %s" url))))

(advice-add 'browse-url :around #'my/browse-url-no-frame-guard)

(use-package eww
  :ensure nil
  :commands (eww eww-search-words)
  :custom
  (eww-search-prefix "https://duckduckgo.com/html/?q=")
  (eww-auto-rename-buffer 'title)
  (eww-browse-url-new-window-is-tab nil)
  (eww-download-directory (expand-file-name "~/Downloads"))
  (eww-bookmarks-directory (locate-user-emacs-file "eww-bookmarks/"))
  (eww-restore-desktop t)
  (eww-desktop-remove-duplicates t)
  (eww-history-limit 150)
  (eww-suggest-uris '(eww-links-at-point
                      thing-at-point-url-at-point))
  (eww-header-line-format "%t — %u")
  (url-privacy-level '(email os emacs lastloc))
  (url-cookie-trusted-urls '())
  :config
  (setq-default shr-inhibit-images nil
                shr-use-fonts t
                shr-use-colors t
                shr-folding-mode t
                shr-bullet "• "
                shr-image-animate nil
                shr-max-image-proportion 0.6
                shr-width nil
                shr-cookie-policy nil)
  (make-directory eww-bookmarks-directory t)

  (with-eval-after-load 'general
    (my-local-leader
      :keymaps 'eww-mode-map
      "B" '(eww-add-bookmark :wk "add bookmark")
      "r" '(eww-readable :wk "reader mode")
      "i" '(my/eww-toggle-images :wk "toggle images")
      "y" '(my/eww-copy-as-org :wk "copy page as org")
      "d" '(eww-download :wk "download"))))

(defun my/eww-new-buffer (url)
  "Open URL in a fresh eww buffer (keep current)."
  (interactive (list (read-from-minibuffer "URL: ")))
  (eww url 4))

(defun my/eww-toggle-images ()
  "Toggle image rendering and reload page."
  (interactive)
  (setq-local shr-inhibit-images (not shr-inhibit-images))
  (eww-reload)
  (message "Images %s" (if shr-inhibit-images "off" "on")))

(defun my/eww-copy-as-org ()
  "Yank visible eww region/page as org-formatted text."
  (interactive)
  (require 'ol-eww)
  (org-eww-copy-for-org-mode))

(use-package shrface
  :ensure t
  :hook (eww-after-render . shrface-mode)
  :custom
  (shrface-bullets-bullet-list '("◉" "○" "✸" "✿"))
  (shrface-href-versatile t)
  :config
  (shrface-basic)
  (shrface-trial)
  (shrface-default-keybindings))

(use-package shr-tag-pre-highlight
  :ensure (:host github :repo "xuchunyang/shr-tag-pre-highlight.el")
  :after shr
  :config
  (add-to-list 'shr-external-rendering-functions
               '(pre . shr-tag-pre-highlight)))

(use-package ace-link
  :ensure t
  :commands (ace-link-eww ace-link-info ace-link-help ace-link-org)
  :config (ace-link-setup-default))

(use-package link-hint
  :ensure t
  :commands (link-hint-open-link link-hint-copy-link))

(with-eval-after-load 'general
  (general-def :states '(normal visual)
    :keymaps '(eww-mode-map elfeed-show-mode-map elfeed-search-mode-map)
    "f" #'link-hint-open-link
    "F" #'link-hint-copy-link))

(use-package mu4e
  :ensure nil
  :defer t
  :commands (mu4e mu4e-compose-new)
  :config
  
  (setq mu4e-mu-binary (executable-find "mu"))
  (setq mu4e-split-view 'vertical)
  (setq mu4e-thread-mode t)
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

(use-package mu4e-alert
  :ensure t
  :after mu4e
  :config
  ;; Use libnotify for desktop notifications (notify-send / swaync)
  (mu4e-alert-set-default-style 'libnotify)

  ;; Interesting mail query: unread, exclude trash and sent folders
  (setq mu4e-alert-interesting-mail-query
        (concat "flag:unread AND NOT flag:trashed"
                " AND NOT maildir:\"/autistici/Sent\""
                " AND NOT maildir:\"/cashmere/cashmere/Sent\""))

  ;; Show both count and per-sender subject notifications
  (setq mu4e-alert-email-notification-types '(count subjects))

  ;; Group desktop notifications by maildir (per-account grouping)
  (setq mu4e-alert-group-by :maildir)

  ;; Disable X11 urgency hints (does not work on Wayland)
  (setq mu4e-alert-set-window-urgency nil)

  ;; Enable desktop notifications
  (mu4e-alert-enable-notifications)

  ;; Enable mode-line data updates (populates mu4e-alert-mode-line variable).
  ;; We strip the default global-mode-string entry afterwards since we use
  ;; a custom maple-modeline segment instead.
  (mu4e-alert-enable-mode-line-display)
  (setq global-mode-string
        (delete '(:eval mu4e-alert-mode-line) global-mode-string)))

(use-package colorful-mode
  ;; :diminish
  :ensure t ; Optional
  :custom
  (colorful-use-prefix t)
  (colorful-only-strings 'only-prog)
  (css-fontify-colors nil)
  :config
  (global-colorful-mode t)
  (add-to-list 'global-colorful-modes 'helpful-mode))

(use-package envrc
  :ensure t
  :defer 1
  :init
  (require 'notifications)
  (defvar my/envrc-notified (make-hash-table :test 'equal)
    "Directories already notified about, to avoid spam.")
  (defun my/envrc-notify (dir status)
    "Desktop notification for DIR with STATUS symbol.
Skip when no .envrc (STATUS `none'). Dedupe by .envrc root so
opening another file in same project does not re-notify."
    (when (and dir (memq status '(on error)))
      (let ((root (or (locate-dominating-file dir ".envrc") dir)))
        (unless (gethash root my/envrc-notified)
          (puthash root t my/envrc-notified)
          (ignore-errors
            (notifications-notify
             :title "direnv"
             :body (format "%s — %s"
                           (abbreviate-file-name root)
                           (pcase status
                             ('on    "environment loaded")
                             ('error "load failed")
                             (_      (format "%s" status))))
             :app-name "emacs"
             :urgency (if (eq status 'error) 'critical 'low)
             :timeout 3000))
          (message "envrc: %s [%s]" root status)))))
  (defun my/envrc-maybe-async ()
    "Enable `envrc-mode' asynchronously for current buffer."
    (when (and (not (bound-and-true-p envrc-mode))
               buffer-file-name
               (not (file-remote-p buffer-file-name)))
      (let ((buf (current-buffer)))
        (run-with-idle-timer
         0.2 nil
         (lambda ()
           (when (buffer-live-p buf)
             (with-current-buffer buf
               (envrc-mode 1)
               (let ((dir (and (boundp 'envrc--status)
                               (car-safe (bound-and-true-p envrc--process-env))
                               default-directory))
                     (status (bound-and-true-p envrc--status)))
                 (when status
                   (my/envrc-notify default-directory status))))))))))
  :hook ((find-file . my/envrc-maybe-async)
         (dired-mode . my/envrc-maybe-async))
  :config
  (when (bound-and-true-p envrc-global-mode)
    (envrc-global-mode -1)))

(use-package tldr
  :ensure t)

(use-package eshell
  :ensure nil
  :config
  (setq eshell-command-aliases-list
        '(("nh-switch" "nh os switch --quiet $*"))))

(use-package el-fetch
  :ensure t)

(use-package ghostel
  :ensure t
  :custom
  (ghostel-shell "xonsh")
  (ghostel-ssh-install-terminfo t)
  :config
  ;; Ghostel's platform detector only knows darwin/linux; teach it FreeBSD
  ;; so it can download the x86_64-freebsd release asset when the user
  ;; first invokes a ghostel command.
  (defun my/ghostel-module-platform-tag (orig)
    (or (funcall orig)
        (and (eq system-type 'berkeley-unix)
             (let* ((raw-arch (car (split-string system-configuration "-")))
                    (arch (pcase raw-arch
                            ("amd64" "x86_64")
                            ("arm64" "aarch64")
                            (_ raw-arch))))
               (format "%s-freebsd" arch)))))
  (advice-add 'ghostel--module-platform-tag :around #'my/ghostel-module-platform-tag)
  (require 'ghostel-compile)
  (setq-default window-adjust-process-window-size-function
                #'window-adjust-process-window-size-largest)
  (evil-define-key 'normal ghostel-mode-map
    (kbd "g t") #'ghostel-next
    (kbd "g T") #'ghostel-previous
    (kbd "g n") #'ghostel
    (kbd "g b") #'ghostel-list-buffers)
  (defun my/ghostel-transparent-buffer-face (fg _bg)
    (unless (equal fg ghostel--face-cookie-fg-bg)
      (when ghostel--face-cookie
        (face-remap-remove-relative ghostel--face-cookie))
      (setq ghostel--face-cookie
            (face-remap-add-relative 'default :foreground fg))
      (setq ghostel--face-cookie-fg-bg fg)))
  (advice-add 'ghostel--set-buffer-face :override
              #'my/ghostel-transparent-buffer-face)
  (advice-add 'enable-theme :after
              (lambda (&rest _)
                (when (fboundp 'ghostel-sync-theme)
                  (ghostel-sync-theme)))))

(use-package evil-ghostel
  :ensure (:host github :repo "dakra/ghostel"
           :files ("extensions/evil-ghostel/*.el"))
  :after (ghostel evil)
  :custom
  (evil-ghostel-escape 'evil)
  :hook (ghostel-mode . evil-ghostel-mode))

(use-package inheritenv
  :ensure t
  :after ghostel
  :config
  (inheritenv-add-advice 'ghostel-compile)
  (inheritenv-add-advice 'ghostel-recompile))

(when-let* ((garden-dir (expand-file-name
                         (or (alist-get 'garden my/local-packages) "~/garden")))
            ((file-directory-p garden-dir)))
  (use-package vui
    :ensure (:host github :repo "d12frosted/vui.el" :files ("*.el")))

  (add-to-list 'load-path (expand-file-name "lisp/" garden-dir))
  (setq garden-directory (file-name-as-directory garden-dir))
  (require 'garden-core)
  (garden-auto-index-mode 1)
  (autoload 'garden "garden-dashboard" nil t)
  (autoload 'garden-sidecar "garden-dashboard" nil t)
  (autoload 'garden-search "garden-dashboard" nil t)
  (autoload 'garden-fleet "garden-fleet" nil t)
  (autoload 'garden-connect "garden-connect" nil t)
  (autoload 'garden-connect-pick "garden-connect" nil t)
  (autoload 'garden-publish "garden-publish" nil t)
  (autoload 'garden-publish-all "garden-publish" nil t)
  (autoload 'garden-publish-wiki "garden-publish" nil t)
  (autoload 'garden-publish-blog "garden-publish" nil t)
  (autoload 'garden-publish-deploy "garden-publish" nil t)
  (autoload 'denote-capf-setup "denote-capf" nil t)
  (with-eval-after-load 'denote-capf
    (setq denote-capf-directories '("~/org/")))
  (add-hook 'org-mode-hook #'denote-capf-setup)

  (defun my/denote-capf-tab-in-insert ()
    (when (featurep 'evil)
      (evil-local-set-key 'insert (kbd "TAB") #'indent-for-tab-command)))
  (add-hook 'org-mode-hook #'my/denote-capf-tab-in-insert))

(use-package sops
  :ensure (:type git :host github :repo "djgoku/sops")
  :init
  (global-sops-mode 1))

(use-package magit-delta
  :ensure t
  :after magit
  :init
  (when (executable-find "delta")
    (add-hook 'magit-mode-hook #'magit-delta-mode)))

(use-package pretty-sha-path
  :ensure t
  :config
  (setopt global-pretty-sha-path-mode 't))

(use-package pulsar
  :ensure t
  :config
  (setq pulsar-pulse t)
  (setq pulsar-delay 0.025)
  (setq pulsar-iterations 10)
  (setq pulsar-face 'evil-ex-lazy-highlight)
  (setq pulsar-tty-color "white")

  (let ((orig-face-background (symbol-function 'face-background)))
    (defun my/pulsar--create-pulse (locus face)
      "Like `pulsar--create-pulse' but with a smarter TTY colour fallback."
      (let ((common-fn (lambda (locus face)
                         (let ((pulse-flag t)
                               (pulse-delay pulsar-delay)
                               (pulse-iterations pulsar-iterations)
                               (overlay (make-overlay (car locus) (cdr locus))))
                           (overlay-put overlay 'pulse-delete t)
                           (overlay-put overlay 'window (frame-selected-window))
                           (pulse-momentary-highlight-overlay overlay face)))))
        (if (display-graphic-p)
            (funcall common-fn locus face)
          (cl-letf (((symbol-function 'face-background)
                     (lambda (f &optional frame inherit)
                       (let ((bg (funcall orig-face-background f frame inherit)))
                         (cond
                          ((and (eq f 'default) (null bg))
                           (or (frame-parameter frame 'background-color)
                               (if (eq (frame-parameter frame 'background-mode) 'light)
                                   "white"
                                 "black")))
                          ((null bg) pulsar-tty-color)
                          (t bg))))))
            (funcall common-fn locus face))))))
  (advice-add 'pulsar--create-pulse :override #'my/pulsar--create-pulse)

  (add-to-list 'pulsar-pulse-functions 'evil-scroll-down)
  (add-to-list 'pulsar-pulse-functions 'flymake-goto-next-error)
  (add-to-list 'pulsar-pulse-functions 'flymake-goto-prev-error)
  (add-to-list 'pulsar-pulse-functions 'evil-yank)
  (add-to-list 'pulsar-pulse-functions 'evil-yank-line)
  (add-to-list 'pulsar-pulse-functions 'evil-delete)
  (add-to-list 'pulsar-pulse-functions 'evil-delete-line)
  (add-to-list 'pulsar-pulse-functions 'evil-jump-item)
  (add-to-list 'pulsar-pulse-functions 'diff-hl-next-hunk)
  (add-to-list 'pulsar-pulse-functions 'diff-hl-previous-hunk)

  (pulsar-global-mode))

(use-package org-auto-tangle
  :ensure t
  :hook (org-mode . org-auto-tangle-mode))

(use-package zfs
  :ensure nil
  :commands (zfs))

(provide 'init)
