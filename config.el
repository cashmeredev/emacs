;;; config.el --- Emacs-Kick --- A feature rich Emacs config for (neo)vi(m)mers -*- lexical-binding: t; -*-
(setenv "LSP_USE_PLISTS" "true")
;; (setq debug-on-error t)
(setq gc-cons-threshold #x40000000)
;; (setq gc-cons-threshold 50000000)
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

;;; Daemon detection — determines which daemon we're running as.
;;; Start Emacs with: emacs --fg-daemon=hub   (persistent: IRC, mail, agenda)
;;;                   emacs --fg-daemon=work  (restartable: code, projects)
;;;                   emacs                   (standalone, loads everything)

(defvar my/daemon-name
  (let ((d (daemonp)))
    (cond
     ((stringp d) d)       ; named daemon: "hub" or "work"
     (d           "work")  ; unnamed daemon (--daemon without name) → treat as work
     (t           nil)))   ; standalone emacs
  "Name of the current Emacs daemon, or nil for standalone.")

(defun my/hub-p ()
  "Return non-nil when running as the hub daemon."
  (equal my/daemon-name "hub"))

(defun my/work-p ()
  "Return non-nil when running as the work daemon."
  (equal my/daemon-name "work"))

(defun my/standalone-p ()
  "Return non-nil when running standalone (not as daemon)."
  (null my/daemon-name))

(defun my/load-for-hub-p ()
  "Return non-nil if hub packages should be loaded (hub or standalone)."
  (or (my/hub-p) (my/standalone-p)))

(defun my/load-for-work-p ()
  "Return non-nil if work packages should be loaded (work or standalone)."
  (or (my/work-p) (my/standalone-p)))

;; Per-daemon state files to avoid conflicts between hub and work daemons
(when my/daemon-name
  (let ((suffix (concat "-" my/daemon-name)))
    (setq recentf-save-file
          (expand-file-name (concat "recentf" suffix ".eld") user-emacs-directory))
    (setq savehist-file
          (expand-file-name (concat "savehist" suffix ".el") user-emacs-directory))
    (setq save-place-file
          (expand-file-name (concat "places" suffix ".eld") user-emacs-directory))
    (setq bookmark-default-file
          (expand-file-name (concat "bookmarks" suffix ".eld") user-emacs-directory))
    (setq projectile-known-projects-file
          (expand-file-name (concat "projectile-bookmarks" suffix ".eld") user-emacs-directory))
    (setq org-clock-persist-file
          (expand-file-name (concat "org-clock-save" suffix ".el") user-emacs-directory))))

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
  ;; (set-frame-parameter (selected-frame) 'alpha-background 80)
  ;; (add-to-list 'default-frame-alist '(alpha-background . 80))
  ;; (global-hl-line-mode -1) ;; Disable highlight of the current line
  (global-auto-revert-mode 1) ;; Enable global auto-revert mode to keep buffers up to date with their corresponding files.
  (setq-default indent-tabs-mode nil)
  (recentf-mode 1) ;; Enable tracking of recently opened files.
  (savehist-mode 1) ;; Enable saving of command history.
  (save-place-mode 1) ;; Enable saving the place in files for easier return.
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

;; Always-available IRC entry points so `M-x run-irc` works from any daemon
;; (hub, work, standalone). Calling `erc-tls` autoloads ERC on demand.
(defun my/soju-password ()
  "Read the Soju bouncer password from the sops-nix secret."
  (string-trim
   (with-temp-buffer
     (insert-file-contents
      "/home/cashmere/.config/sops-nix/secrets/senpai_password")
     (buffer-string))))

(defun run-irc ()
  "Connect to all IRC networks via Soju bouncer."
  (interactive)
  (let ((pw (my/soju-password)))
    (erc-tls :server "bouncer.cashmere.rs"
             :port 6699
             :nick "cashmere1337"
             :user "cashmere/irc.libera.chat@emacs"
             :password pw)
    (erc-tls :server "bouncer.cashmere.rs"
             :port 6699
             :nick "cashmere"
             :user "cashmere/ergo@emacs"
             :password pw)))

(when (my/load-for-hub-p)
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

  ;; track -- activity in modeline
  (setq erc-track-position-in-mode-line t)

  ;; keep large buffer for soju history replay
  (setq erc-max-buffer-size 100000)

  (erc-update-modules))

(defvar my/consult-source-erc
  (list :name "IRC"
        :narrow ?i
        :category 'buffer
        :face 'erc-default-face
        :state #'consult--buffer-state
        :items (lambda ()
                 (mapcar #'buffer-name
                         (cl-remove-if-not
                          (lambda (buf)
                            (with-current-buffer buf
                              (derived-mode-p 'erc-mode)))
                          (buffer-list))))))

(defun my/erc-switch-channel ()
  "Switch to an ERC channel buffer via consult."
  (interactive)
  (consult-buffer (list my/consult-source-erc)))

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

) ;; end (when (my/load-for-hub-p) ...)

;; ERC keybindings and hooks — register from any daemon, since `run-irc`
;; autoloads ERC even outside the hub daemon.
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

  (with-eval-after-load 'general
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
      "C-j" 'erc-next-command)))

;; Auto-start ERC in hub daemon on first frame
(when (my/hub-p)
  (defun my/hub-auto-start-erc (&optional _frame)
    "Auto-connect ERC when first hub frame is created."
    (run-irc)
    (remove-hook 'server-after-make-frame-hook #'my/hub-auto-start-erc))
  (add-hook 'server-after-make-frame-hook #'my/hub-auto-start-erc))

;; (use-package lambda-themes
;;   :ensure (:host github :repo "lambda-emacs/lambda-themes")
;;   :custom
;;   (lambda-themes-set-italic-comments t)
;;   (lambda-themes-set-italic-keywords t)
;;   (lambda-themes-set-variable-pitch t) 
;;   (lambda-themes-set-theme 'light)
;;   :config
;;   (load-theme 'lambda-light))

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
                       (mode . shell-mode)
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
           ("ECA - Editor Code Assistant"
            (or
             (mode . eca-chat-mode)))

           ("ERC" (or (mode . erc-mode)))

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

(use-package general
  :ensure (:wait t)
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

(use-package claude-code-ide
  :ensure (:host github :repo "manzaltu/claude-code-ide.el"
           :files ("*.el"))
  :defer t
  :commands (claude-code-ide
             claude-code-ide-menu
             claude-code-ide-toggle
             claude-code-ide-toggle-recent
             claude-code-ide-continue
             claude-code-ide-resume
             claude-code-ide-stop
             claude-code-ide-send-prompt
             claude-code-ide-insert-at-mentioned
             claude-code-ide-switch-to-buffer
             claude-code-ide-list-sessions
             claude-code-ide-check-status
             claude-code-ide-show-debug
             claude-code-ide-clear-debug)
  :custom
  ;; CLI
  (claude-code-ide-cli-path "claude")
  (claude-code-ide-cli-debug nil)
  ;; Terminal backend — vterm is preferred, eat as fallback
  (claude-code-ide-terminal-backend 'vterm)
  (claude-code-ide-vterm-anti-flicker nil)

  ;; Window placement — mirror eca on the right side so the two AI assistants
  ;; don't fight over the same slot
  (claude-code-ide-use-side-window t)
  (claude-code-ide-window-side 'right)
  (claude-code-ide-window-width 100)
  (claude-code-ide-focus-on-open t)

  ;; Ediff integration for code suggestions
  (claude-code-ide-use-ide-diff t)
  (claude-code-ide-focus-claude-after-ediff t)
  (claude-code-ide-show-claude-window-in-ediff t)
  (claude-code-ide-switch-tab-on-ediff t)

  ;; Diagnostics — auto-pick flycheck/flymake
  (claude-code-ide-diagnostics-backend 'auto)

  ;; Allow Claude to evaluate Elisp in this Emacs (executeCode MCP tool)
  (claude-code-ide-enable-execute-code t)

  :init
  ;; Evil: open the Claude terminal in insert state so you can type immediately.
  ;; Defined in :init so it applies even before claude-code-ide loads.
  (with-eval-after-load 'evil
    (evil-set-initial-state 'vterm-mode 'insert)
    (evil-set-initial-state 'eat-mode 'insert))

  (defun my/claude-code-ide--enter-insert (&rest _)
    "Force evil insert state in the Claude terminal buffer after invocation."
    (when (bound-and-true-p evil-mode)
      (run-at-time
       0.05 nil
       (lambda ()
         (when-let* ((buf (seq-find
                           (lambda (b)
                             (string-match-p "\\*claude-code"
                                             (buffer-name b)))
                           (buffer-list))))
           (with-current-buffer buf
             (when (get-buffer-window buf)
               (select-window (get-buffer-window buf)))
             (evil-insert-state)))))))

  (dolist (cmd '(claude-code-ide
                 claude-code-ide-toggle
                 claude-code-ide-toggle-recent
                 claude-code-ide-continue
                 claude-code-ide-resume
                 claude-code-ide-switch-to-buffer))
    (advice-add cmd :after #'my/claude-code-ide--enter-insert))

  ;; Leader-key bindings (SPC a …) — defined pre-load so :commands autoloads fire.
  (with-eval-after-load 'general
    (my-leader
      "a"  '(:ignore t :wk "claude-code")
      "aa" '(claude-code-ide :wk "start / toggle")
      "am" '(claude-code-ide-menu :wk "transient menu")
      "at" '(claude-code-ide-toggle :wk "toggle window")
      "aT" '(claude-code-ide-toggle-recent :wk "toggle recent")
      "ap" '(claude-code-ide-send-prompt :wk "send prompt")
      "a@" '(claude-code-ide-insert-at-mentioned :wk "@mention region")
      "ac" '(claude-code-ide-continue :wk "continue last")
      "ar" '(claude-code-ide-resume :wk "resume session")
      "as" '(claude-code-ide-switch-to-buffer :wk "switch buffer")
      "al" '(claude-code-ide-list-sessions :wk "list sessions")
      "aq" '(claude-code-ide-stop :wk "stop")
      "a?" '(claude-code-ide-check-status :wk "check status")
      "ad" '(claude-code-ide-show-debug :wk "show debug")
      "aD" '(claude-code-ide-clear-debug :wk "clear debug"))

    (my-leader 'visual
      "a@" '(claude-code-ide-insert-at-mentioned :wk "@mention region")))

  (global-set-key (kbd "C-c C-'") #'claude-code-ide-menu)

  :config
  ;; Runs only on first invocation — not at Emacs startup.
  (claude-code-ide-emacs-tools-setup))

(use-package eldoc
  :ensure nil
  :config
  (setq eldoc-idle-delay 0.25)
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
  (setq flycheck-global-modes '(not org-mode))
  (setq flycheck-display-errors-function nil)
  (add-hook 'after-init-hook #'global-flycheck-mode))

(use-package flycheck-rust
  :ensure t
  :config
  (setq flycheck-rust-check-tests nil)
  (add-hook 'rust-ts-mode-hook #'flycheck-rust-setup))

(use-package flycheck-python-ruff
  :ensure (:host github :repo "v4n6/flycheck-python-ruff")
  :hook (python-ts-mode . flycheck-python-ruff-setup))

(use-package flycheck-eglot
  :ensure t
  :after (flycheck eglot)
  :config
  (global-flycheck-eglot-mode 1))

(use-package sideline
  :ensure t
  :hook (flycheck-mode . sideline-mode)
  :config
  (setq sideline-delay 0.001)
  :custom
  (sideline-backends-right '(sideline-flycheck))
  (sideline-display-backend-name t))

(use-package sideline-flycheck
  :ensure t
  :hook (flycheck-mode . sideline-flycheck-setup))

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
  (setq org-log-done                       t
        org-auto-align-tags                t
        org-tags-column                    -80
        org-fold-catch-invisible-edits     'show-and-error
        org-special-ctrl-a/e               t
        org-insert-heading-respect-content t)

  (add-hook 'org-mode-hook 'variable-pitch-mode)
  ;; (add-hook 'org-mode-hook 'org-indent-mode)
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



;; (add-to-list 'load-path "~/render-org.el")
;; (require 'render-org)
;; (add-hook 'org-mode-hook #'render-org-mode)

;; ;; Markdown support
;; (require 'render-markdown)
;; (add-hook 'markdown-mode-hook #'render-markdown-mode)

;; ;; SVG scaled headings via kitty-graphics
;; (setq render-org-heading-gfx-enabled 'nil)
;; ;; (setq render-org-heading-gfx-scales '(1.25 1.15 1.05 1.0 1.0 1.0))
;; ;; (setq render-org-heading-gfx-font-family "MapleMono NF")

;; TEMP: load kitty-graphics from local dev clone (/home/cashmere/projects/
;; kitty-graphics/) instead of the elpaca-managed build, so edits to the
;; source apply on Emacs restart without an `elpaca-rebuild' cycle.
;; Swap back to the `use-package' / `:ensure' form below once changes are
;; committed + pushed and elpaca has pulled the new commit.
(when (not (display-graphic-p))
  (add-to-list 'load-path "/home/cashmere/projects/kitty-graphics")
  (require 'kitty-graphics)
  (setq kitty-gfx-enable-video t)
  (add-hook 'dired-mode-hook #'kitty-gfx-dired-auto-preview-mode)
  (setq kitty-gfx-debug nil)
  (kitty-graphics-mode 1))

;; (use-package kitty-graphics
;;     :ensure (:host github :repo "cashmeredev/kitty-graphics.el")
;;     :if (not (display-graphic-p))
;;     :custom
;;     (kitty-gfx-enable-video t)
;;     :hook
;;     (dired-mode . kitty-gfx-dired-auto-preview-mode)
;;     :config
;;     (kitty-graphics-mode 1))

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

(use-package ob-async
  :ensure t
  :after org)

(use-package jupyter
  :ensure t
  :defer t
  :commands (jupyter-run-repl jupyter-connect-repl)
  :init
  ;; lazy: kein :after org, kein emacs-zmq native build beim startup.
  ;; jupyter laedt erst wenn ein jupyter-* src block ausgefuehrt wird.
  (with-eval-after-load 'org
    (setq org-babel-default-header-args:jupyter-python
          '((:async . "yes")
            (:session . "py")
            (:kernel . "python3")
            (:results . "raw drawer")))
    (advice-add 'org-babel-get-src-block-info :around
                (lambda (orig &rest a)
                  (let ((info (apply orig a)))
                    (when (and info
                               (stringp (nth 0 info))
                               (string-prefix-p "jupyter-" (nth 0 info))
                               (not (featurep 'jupyter)))
                      (require 'jupyter)
                      (org-babel-do-load-languages
                       'org-babel-load-languages
                       (append org-babel-load-languages '((jupyter . t)))))
                    info)))))

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
  "Upload FILE, region, or current buffer to snips.sh.
Passes -ext flag to hint the file type for syntax highlighting.
Copies the resulting URL to the kill ring and clipboard."
  (interactive)
  (let* ((input (cond
                 (file file)
                 ((use-region-p)
                  (buffer-substring-no-properties (region-beginning) (region-end)))
                 (t (buffer-substring-no-properties (point-min) (point-max)))))
         (ext (cond
               ((and file (file-name-extension file))
                (file-name-extension file))
               ((and (not file) (buffer-file-name) (file-name-extension (buffer-file-name)))
                (file-name-extension (buffer-file-name)))))
         (ext-flag (if ext (format " -- -ext %s" ext) ""))
         (cmd (format "ssh pb@pb.moneyspread.st%s 2>/dev/null | sed 's/\\x1b\\[[0-9;]*m//g' | grep -oP 'https://\\S+/f/\\S+'" ext-flag))
         (url (string-trim
               (if (and file (file-exists-p file))
                   (shell-command-to-string (format "cat %s | %s" (shell-quote-argument file) cmd))
                 (with-temp-buffer
                   (insert input)
                   (shell-command-on-region (point-min) (point-max) cmd nil t)
                   (buffer-string))))))
    (if (string-prefix-p "https://" url)
        (let ((final-url (if (and ext (member (downcase ext)
                                              '("png" "jpg" "jpeg" "gif" "webp" "svg" "bmp" "ico" "tiff")))
                              (concat url "?r=1")
                            url)))
          (kill-new final-url)
          (message "Uploaded: %s" final-url))
      (message "Upload failed"))))

(defun my/snip-upload-file ()
  "Prompt for a file and upload it to snips.sh."
  (interactive)
  (my/snip-upload (read-file-name "Upload to snips.sh: ")))

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


(defun my/org-capture-timeblock-to-journal ()
  "Capture function: jump to today's journal for a timeblock."
  (require 'denote)
  (require 'denote-journal)
  (let* ((today (format-time-string "%Y-%m-%d"))
         (journal-files (denote-directory-files "journal"))
         (today-journal (seq-find
                        (lambda (file)
                          (string-match-p today (file-name-nondirectory file)))
                        journal-files)))
    (if today-journal
        (find-file today-journal)
      (denote-journal-new-or-existing-entry))
    (goto-char (point-max))
    (insert "\n* Timeblock\n")))

(defun my/org-capture-recurring-to-journal ()
  "Capture function: jump to today's journal for a recurring task."
  (require 'denote)
  (require 'denote-journal)
  (let* ((today (format-time-string "%Y-%m-%d"))
         (journal-files (denote-directory-files "journal"))
         (today-journal (seq-find
                        (lambda (file)
                          (string-match-p today (file-name-nondirectory file)))
                        journal-files)))
    (if today-journal
        (find-file today-journal)
      (denote-journal-new-or-existing-entry))
    (goto-char (point-max))
    (insert "\n* Recurring\n")))

(defun my/org-capture-meeting-to-journal ()
  "Capture function: jump to today's journal for a meeting note."
  (require 'denote)
  (require 'denote-journal)
  (let* ((today (format-time-string "%Y-%m-%d"))
         (journal-files (denote-directory-files "journal"))
         (today-journal (seq-find
                        (lambda (file)
                          (string-match-p today (file-name-nondirectory file)))
                        journal-files)))
    (if today-journal
        (find-file today-journal)
      (denote-journal-new-or-existing-entry))
    (goto-char (point-max))
    (insert "\n* Meeting: ")))

;; capture templates are merged in the org-capture section below

(use-package org-noter
  :ensure t
  :defer t)

(use-package nov
  :ensure t
  :mode ("\\.epub\\'" . nov-mode))

(use-package yequake
  :ensure t
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
         (file-name (denote nil '("agenda"))))
    (find-file file-name)
    (goto-char (point-min))
    (forward-line 4)
    (insert (format "\n* %s\nDEADLINE: <%s>\n\n" context deadline))
    (current-buffer)))

(defun my/org-capture-denote-scheduled ()
  (let* ((context (read-string "Scheduled task: "))
         (schedule (org-read-date t nil nil "Schedule: "))
         (file-name (denote nil '("agenda"))))
    (find-file file-name)
    (goto-char (point-min))
    (forward-line 4)
    (insert (format "\n* %s\nSCHEDULED: <%s>\n\n" context schedule))
    (current-buffer)))

(defun my/org-capture-denote-task ()
  (let* ((context (read-string "Task: "))
         (todo-state (completing-read "TODO state: "
                                      '("ACTIVE" "NEXT" "TODO" "WAIT")))
         (file-name (denote nil '("agenda"))))
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
             (:name "Deadlines"
              :deadline today
              :order 2)
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
             (:name "Deadlines"
              :deadline today
              :order 2)
             (:discard (:anything t))))))

       ;; Block 2: project
       (org-ql-block '(and (tags "project")
                           (not (done)))
         ((org-ql-block-header "Project")
          (org-super-agenda-groups
           '((:name "ACTIVE" :todo "ACTIVE" :order 1)
             (:name "NEXT"   :todo "NEXT"   :order 2)
             (:name "TODO"   :todo "TODO"   :order 3)
             (:name "WAIT"   :todo "WAIT"   :order 4)
             (:discard (:anything t))))))

       ;; Block 3: development
       (org-ql-block '(and (tags "development")
                           (not (done)))
         ((org-ql-block-header "Development")
          (org-super-agenda-groups
           '((:name "ACTIVE" :todo "ACTIVE" :order 1)
             (:name "NEXT"   :todo "NEXT"   :order 2)
             (:name "TODO"   :todo "TODO"   :order 3)
             (:name "WAIT"   :todo "WAIT"   :order 4)
             (:discard (:anything t))))))

       ;; Block 4: blog
       (org-ql-block '(and (tags "blog")
                           (not (done)))
         ((org-ql-block-header "Blog")
          (org-super-agenda-groups
           '((:name "ACTIVE" :todo "ACTIVE" :order 1)
             (:name "NEXT"   :todo "NEXT"   :order 2)
             (:name "TODO"   :todo "TODO"   :order 3)
             (:name "WAIT"   :todo "WAIT"   :order 4)
             (:discard (:anything t))))))

       ;; Block 5: self
       (org-ql-block '(and (tags "self")
                           (not (done)))
         ((org-ql-block-header "Self")
          (org-super-agenda-groups
           '((:name "ACTIVE" :todo "ACTIVE" :order 1)
             (:name "NEXT"   :todo "NEXT"   :order 2)
             (:name "TODO"   :todo "TODO"   :order 3)
             (:name "WAIT"   :todo "WAIT"   :order 4)
             (:discard (:anything t))))))

       ;; Block 6: backlog — everything not covered above
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

(defun my/agenda-app ()
  "Launch Emacs as a dedicated agenda kiosk.
Opens the 'd' (Today) agenda view in a clean, distraction-free frame.
Usage: emacs --eval '(my/agenda-app)' --no-splash"
  (interactive)
  (set-frame-name "Agenda")
  (delete-other-windows)
  (org-agenda nil "d")
  (delete-other-windows)
  (setq mode-line-format nil)
  (menu-bar-mode -1)
  (tool-bar-mode -1)
  (scroll-bar-mode -1)
  (when (bound-and-true-p tab-bar-mode)
    (tab-bar-mode -1))
  (when (find-font (font-spec :family "Lato"))
    (buffer-face-set '(:family "Lato")))
  (text-scale-increase 2)
  (hide-mode-line-mode 1)
  (winner-mode 1))

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

(use-package ox-slidev
  :ensure (:repo "https://dev.cashmere.rs/cashmere/ox-slidev"
           :files (:defaults "templates"))
  :after org
  :config
  (require 'org-slidev))

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
  (setq denote-agenda-include-regexp "_agenda")
  (denote-agenda-insinuate))

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
  :ensure t
  :defer t
  :config
  (setq denote-menu-title-column-width 60))

(use-package denote-org
    :ensure t)

(use-package consult-denote
  :ensure (:host github :repo "protesilaos/consult-denote")
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
  :ensure t)

(use-package ox-gfm
  :ensure t)

(use-package denote-publish
  :ensure (:repo "https://github.com/vedang/denote-publish"))

(setq denote-publish-default-base-dir "~/wiki")
(setq denote-publish-default-output-dir "~/blog/wiki")

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

(use-package which-key
  :ensure t
  :defer t
  :hook
  (after-init . which-key-mode)
  :custom
  (which-key-idle-delay 0.3))

(use-package vertico
  :ensure t
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

(use-package corfu
  :ensure t
  :custom
  (corfu-cycle t)
  (corfu-auto t)
  (corfu-auto-delay 0.001)
  (corfu-auto-prefix 2)
  :init
  (global-corfu-mode)
  (corfu-history-mode)
  (corfu-popupinfo-mode))

;; (defun my/suppress-corfu-terminal-warning (orig-fun type message &rest args)
;;   (unless (and (eq type 'corfu)
;;                (string-match-p "corfu-terminal.*not needed" message))
;;     (apply orig-fun type message args)))

;; (advice-add 'display-warning :around #'my/suppress-corfu-terminal-warning)

;; (use-package corfu-terminal
;;   :ensure t
;;   :after corfu
;;   :init
;;   (corfu-terminal-mode +1))

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
          "\\`\\*elpaca-log\\*\\'"
          "\\`\\*Native-compile-Log\\*\\'"
          "\\`\\*Async-native-compile-log\\*\\'")))

;; (use-package treesit-auto
;;   :ensure t
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
  :defer t
  :bind
  (("C-." . embark-act)
   ("M-." . embark-dwim)
   ("C-h B" . embark-bindings)
   :map minibuffer-local-map
   ("C-c C-e" . embark-export)
   ("C-c C-o" . embark-collect))
  :init
  (setq prefix-help-command #'embark-prefix-help-command))

(use-package embark-consult
  :ensure t
  :hook
  (embark-collect-mode . consult-preview-at-point-mode)) ;; Enable preview in Embark collect mode.

(use-package orderless
    :ensure t
    :defer t                                    ;; Load Orderless on demand.
    :after vertico                              ;; Ensure Vertico is loaded before Orderless.
    :init
    (setq completion-styles '(orderless basic)  ;; Set the completion styles.
completion-category-defaults nil      ;; Clear default category settings.
completion-category-overrides '((file (styles partial-completion))))) ;; Customize file completion styles.

(use-package marginalia
  :ensure t
  :hook
  (after-init . marginalia-mode)
  :config
  (setq marginalia-align 'center))

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
  (setq jsonrpc-default-request-timeout 10)
  
  (add-hook 'eglot-managed-mode-hook 
            (lambda () 
              (eglot-inlay-hints-mode -1)))
  
  (setq eglot-ignored-server-capabilities 
        '(:inlayhintprovider :documenthighlightprovider)))



;; (use-package eglot-booster
;;   :ensure (:repo "https://github.com/jdtsmith/eglot-booster")
;;   :after eglot
;;   :config	(eglot-booster-mode))

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

;; (use-package elm-mode
;;   :ensure t
;;   :mode  "\\.elm\\'"
;;   :hook (elm-mode . eglot-ensure)
;;   :config
;;   (with-eval-after-load 'eglot-server-programs
;; 	'(elm-mode . ("elm-language-server"))))

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

;; (use-package rustic
;;   :ensure t
;;   :config
;;   (setq rustic-format-on-save nil)
;;   (setq rustic-lsp-client nil)
;;   :custom
;;   (rustic-cargo-use-last-stored-arguments t))

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

(use-package web-mode
  :ensure t
  :mode "\\.vue\\'"
  :hook (web-mode . eglot-ensure)
  :config
  (setq web-mode-markup-indent-offset 2)
  (setq web-mode-css-indent-offset 2)
  (setq web-mode-code-indent-offset 2)
  (setq web-mode-style-padding 2)
  (setq web-mode-script-padding 2)
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(web-mode . ("rass" "vuetail")))))

(use-package mint-mode
  :ensure (:host github :repo "creatorrr/emacs-mint-mode")
  :mode "\\.mint\\'"
  :hook (mint-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(mint-mode . ("mint" "tool" "ls")))))

;; (use-package nushell-mode
;;   :ensure nil
;;   :mode "\\.nu\\'")

;; (use-package nushell-ts-babel
;;   :ensure (:host github :repo "herbertjones/nushell-ts-babel")
;;   :after org
;;   :config
;;   (org-babel-do-load-languages
;;    'org-babel-load-languages
;;    (append org-babel-load-languages
;;            '((nushell . t)))))

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
           (name (format ".ob-src-%s.py"
                         (substring (md5 parent) 0 8))))
      (setq-local buffer-file-name (expand-file-name name root))
      (set-buffer-modified-p nil)
      (eglot-ensure))))

(add-hook 'org-src-mode-hook #'my/org-src-eglot-python)

;; Kein cleanup-hook: temp file bleibt liegen. Sonst killed eglot
;; jedesmal die LSP connection wenn C-c ' das buffer schliesst →
;; neuer pyrefly process beim naechsten Edit. File ist harmlos (gitignored
;; via .gitignore pattern .ob-src-*.py).

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '((xonsh-mode xonsh-ts-mode)
                 . ("rass" "--" "pyrefly" "lsp" "--" "ruff" "server"))))

;; kein auto-eglot fuer xonsh — pyrefly.toml waere noetig. Manuell via
;; M-x my/pyrefly-here-xonsh (legt temp pyrefly.toml an + startet eglot).
;; (add-hook 'xonsh-mode-hook #'eglot-ensure)
;; (add-hook 'xonsh-ts-mode-hook #'eglot-ensure)

(with-eval-after-load 'org
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
        (when (file-exists-p tmp) (delete-file tmp)))))
  (add-to-list 'org-src-lang-modes '("xonsh" . xonsh)))

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

(use-package json-ts-mode
  :ensure nil
  :mode "\\.json\\'"
  :hook (json-ts-mode . eglot-ensure)
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '(json-ts-mode . ("vscode-json-language-server" "--stdio")))))

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

(use-package jinja2-mode
  :ensure t
  :defer t)

(use-package protobuf-mode
  :ensure (:host github :repo "protocolbuffers/protobuf"
           :files ("editors/protobuf-mode.el"))
  :mode ("\\.proto\\'" . protobuf-mode))

(use-package janet-mode
  :mode "\\.janet\\'"
  :ensure t
  :config
  (with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(janet-mode . ("janet-lsp")))))

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

(use-package vterm
  :ensure t
  :config
  (setq vterm-timer-delay 0.0001)
  (setq vterm-shell "xonsh"))

(use-package multi-vterm
  :ensure t
  :defer t)

(use-package eat
  :ensure t
  :custom
  (eat-shell "fish")
  (eat-kill-buffer-on-exit t)
  (eat-enable-shell-prompt-annotation t)
  (eat-term-name "xterm-256color")
  :hook
  ;; Enable shell integration for directory tracking, prompt navigation, etc.
  (eshell-load . eat-eshell-mode)
  (eshell-load . eat-eshell-visual-command-mode)
  :config
  ;; Tell yazi (and other programs) that this terminal supports Sixel.
  ;; Eat supports Sixel rendering but yazi doesn't recognize it as a known
  ;; terminal. Setting TERM_PROGRAM to "foot" (a known Sixel terminal) makes
  ;; yazi select the Sixel adapter for image previews.
  (advice-add 'eat :around
              (lambda (orig-fn &rest args)
                (let ((process-environment
                       (append '("TERM_PROGRAM=foot"
                                 "TERM_PROGRAM_VERSION=1.18.0")
                               process-environment)))
                  (apply orig-fn args))))
  ;; ──────────────────────────────────────────────────
  ;; Evil integration: make eat behave like vterm
  ;;
  ;; Strategy:
  ;;   - "emacs mode" in eat = normal state (vim motions on buffer text)
  ;;   - "semi-char mode" in eat = insert state (keys pass to terminal)
  ;;   - ESC switches from semi-char → emacs mode (insert → normal)
  ;;   - i/a/A etc switch from emacs → semi-char mode (normal → insert)
  ;; ──────────────────────────────────────────────────

  ;; Don't move cursor back on ESC (inappropriate in terminal buffers)
  (add-hook 'eat-mode-hook (lambda () (setq-local evil-move-cursor-back nil)))

  ;; Start eat in insert state (semi-char mode) so typing goes to shell
  (evil-set-initial-state 'eat-mode 'insert)

  ;; -- Normal state: vim motions on terminal text --------------------------

  ;; Entering insert state switches eat to semi-char mode (passthrough)
  (defun my/eat-semi-char-mode-entry ()
    "Switch eat to semi-char mode when entering evil insert state."
    (when (and (derived-mode-p 'eat-mode)
               (eat-term-p (buffer-local-value 'eat-terminal (current-buffer))))
      (eat-semi-char-mode)))

  ;; Exiting insert state switches eat to emacs mode (vim motions)
  (defun my/eat-emacs-mode-entry ()
    "Switch eat to emacs mode when entering evil normal state."
    (when (and (derived-mode-p 'eat-mode)
               (eat-term-p (buffer-local-value 'eat-terminal (current-buffer))))
      (eat-emacs-mode)))

  (add-hook 'evil-insert-state-entry-hook #'my/eat-semi-char-mode-entry)
  (add-hook 'evil-normal-state-entry-hook #'my/eat-emacs-mode-entry)

  ;; In normal state, bind standard vim keys to re-enter insert (semi-char)
  (evil-define-key 'normal eat-mode-map
    "i" (lambda () (interactive) (eat-semi-char-mode) (evil-insert-state))
    "a" (lambda () (interactive) (forward-char 1) (eat-semi-char-mode) (evil-insert-state))
    "A" (lambda () (interactive) (end-of-line) (eat-semi-char-mode) (evil-insert-state))
    "I" (lambda () (interactive) (back-to-indentation) (eat-semi-char-mode) (evil-insert-state))
    "o" (lambda () (interactive) (eat-semi-char-mode) (evil-insert-state)
         (eat-self-input 1 ?\n))
    ;; Paste from kill ring in normal mode
    "p"  (lambda () (interactive)
           (eat-semi-char-mode)
           (eat-yank)
           (eat-emacs-mode))
    ;; Navigate prompts
    (kbd "[ [") #'eat-previous-shell-prompt
    (kbd "] ]") #'eat-next-shell-prompt)

  ;; In insert state: ESC escapes back to normal (emacs mode intercepts it)
  ;; The default eat-semi-char-mode lets C-c, C-x, etc. pass through to Emacs
  ;; which is exactly what we want. ESC is also not captured by semi-char mode,
  ;; so evil's ESC → normal state transition works naturally.

  ;; -- Multi-eat: manage multiple terminal buffers -------------------------

  (defvar my/eat-buffer-counter 0
    "Counter for naming eat terminal buffers.")

  (defun my/eat-new ()
    "Create a new eat terminal buffer."
    (interactive)
    (cl-incf my/eat-buffer-counter)
    (let ((buf (generate-new-buffer
                (format "*eat<%d>*" my/eat-buffer-counter)))
          (process-environment
           (append '("TERM_PROGRAM=foot" "TERM_PROGRAM_VERSION=1.18.0")
                   process-environment)))
      (with-current-buffer buf
        (eat-mode)
        (eat-exec buf (buffer-name buf) eat-shell nil nil))
      (switch-to-buffer buf)))

  (defun my/eat-toggle ()
    "Toggle an eat terminal. Create one if none exists.
With prefix arg, always create a new terminal."
    (interactive)
    (if current-prefix-arg
        (my/eat-new)
      (let ((eat-bufs (cl-remove-if-not
                       (lambda (b) (with-current-buffer b
                                     (derived-mode-p 'eat-mode)))
                       (buffer-list))))
        (cond
         ;; Currently in an eat buffer → bury it
         ((derived-mode-p 'eat-mode)
          (bury-buffer))
         ;; Existing eat buffers → switch to most recent
         (eat-bufs
          (switch-to-buffer (car eat-bufs)))
         ;; No eat buffers → create one
         (t (eat)))))))

(use-package olivetti
  :ensure t
  :hook (org-mode . olivetti-mode)
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
      (funcall orig win))))

(defun my-org-sidecar-left ()
  "Pick an org-mode buffer via consult and display it as a left sidecar."
  (interactive)
  (let* ((bufs (cl-remove-if-not
                (lambda (b)
                  (with-current-buffer b
                    (derived-mode-p 'org-mode)))
                (buffer-list)))
         (names (mapcar #'buffer-name bufs))
         (choice (consult--read names
                   :prompt "Org sidecar: "
                   :sort nil
                   :require-match t
                   :category 'buffer)))
    (when-let* ((buf (get-buffer choice)))
      (display-buffer-in-side-window
       buf
       '((side . left)
         (window-width . 0.25)
         (slot . 0))))))

;; (use-package visual-fill-column
;;   :ensure t
;;   :hook ((text-mode . visual-line-mode)        ;; Soft-Wrapping aktivieren
;;          (text-mode . visual-fill-column-mode)) ;; Das Zentrieren aktivieren
;;   :custom
;;   (visual-fill-column-width 110)      ;; Maximale Breite des Textes (statt 0.67 relativ)
;;   (visual-fill-column-center-text nil)
;;   (visual-fill-column-enable-sensible-window-split t)
;;   :config
;;   (when (display-graphic-p)
;;     (setq-default visual-fill-column-center-text t)))

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
  :ensure t
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

(use-package indent-guide
  :defer t
  :ensure t
  :hook
  (prog-mode . indent-guide-mode)  ;; Activate indent-guide in programming modes.
  :config
  (setq indent-guide-char "│"))    ;; Set the character used for the indent guide.

(use-package evil
  :ensure (:wait t)
  :init
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  (setq evil-want-C-u-delete t)
  (setq evil-want-C-u-scroll t)
  (setq evil-undo-system 'undo-tree)
  (setq evil-split-window-below t)
  (setq evil-vsplit-window-right t)
  (setq evil-paste-from-register nil)
  :config
  (evil-mode 1)
  (define-key evil-normal-state-map "u" 'undo-tree-undo)
  (define-key evil-normal-state-map (kbd "C-r") 'undo-tree-redo)
  (evil-set-initial-state 'help-mode 'emacs)
  (evil-set-initial-state 'messages-buffer-mode 'normal)
  (evil-set-initial-state 'dired-mode 'normal)
  (evil-set-initial-state 'ibuffer-mode 'normal)
  (evil-set-initial-state 'erc-mode 'normal))

(modify-syntax-entry ?_ "w")

(defun my/eldoc-and-jump ()
  "Show documentation at point. Works in both GUI and terminal."
  (interactive)
  (if (display-graphic-p)
      (eldoc-box-help-at-point)
    (eldoc-doc-buffer t)))

(define-key evil-normal-state-map (kbd "K") #'my/eldoc-and-jump)

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

(use-package undo-tree
  :defer t
  :ensure t
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

(use-package nerd-icons-completion
  :if ek-use-nerd-fonts                   ;; Load the package only if the user has configured to use nerd fonts.
  :ensure t                               ;; Ensure the package is installed.
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
;;   :ensure (:host github :repo "manateelazycat/awesome-tray")
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
;;   :ensure (:host github :repo "lambda-emacs/lambda-line")
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
  :disabled t
  :ensure (:host github :repo "honmaple/emacs-maple-modeline")
  ;; :hook (elpaca-after-init . maple-modeline-mode)
  :config
  (setq maple-modeline-separator 'nil)
  (setq maple-modeline-height 25)
  (setq maple-modeline-icon t)
  
  (maple-modeline-define-segment my-modeline-time
    :format (propertize (downcase (format-time-string " %I:%M %p "))
                        'face 'bold))

  (maple-modeline-define-segment org-clock-task
    :if (and (fboundp 'org-clocking-p) (org-clocking-p))
    :format
    (let ((heading (truncate-string-to-width
                    (substring-no-properties org-clock-heading) 35 nil nil "...")))
      (concat
       (maple-modeline--concat-or
        (maple-modeline--icon 'mdicon "nf-md-clock_outline" face)
        "CLK")
       " " (propertize heading 'face face
                       'mouse-face 'mode-line-highlight
                       'help-echo "Go to clocked task"
                       'local-map (make-mode-line-mouse-map 'mouse-1 'org-clock-goto)))))

  (maple-modeline-define-segment tmr-timer
    :if (and (fboundp 'tmr-mode-line--get-active-timers)
             (tmr-mode-line--get-active-timers))
    :format
    (let* ((timer (car (tmr-mode-line--get-active-timers)))
           (remaining (tmr-mode-line--format-remaining timer))
           (desc (tmr-mode-line--format-description timer)))
      (concat remaining desc)))

  (maple-modeline-define-segment mu4e-mail
    :defines (mu4e-alert-mode-line)
    :functions (mu4e-alert-view-unread-mails)
    :if (and (bound-and-true-p mu4e-alert-mode-line)
             (stringp mu4e-alert-mode-line)
             (not (string-empty-p (string-trim mu4e-alert-mode-line))))
    :format
    (let* ((raw mu4e-alert-mode-line)
           ;; Extract the count number from the mode-line string (e.g. " [5] ")
           (count-str (if (string-match "\\[\\([0-9]+\\)\\]" raw)
                          (match-string 1 raw)
                        (string-trim raw))))
      (concat
       (maple-modeline--concat-or
        (maple-modeline--icon 'mdicon "nf-md-email" face)
        "Mail")
       " " (propertize count-str
                       'face face
                       'mouse-face 'mode-line-highlight
                       'help-echo "View unread emails"
                       'local-map (make-mode-line-mouse-map
                                   'mouse-1 'mu4e-alert-view-unread-mails)))))

  (maple-modeline-define my-custom-style
    :left ((evil :left (bar :left ""))
           macro
           buffer-info
           flycheck
           version-control
           remote-host
           region)
    :right (narrow
            org-clock-task
            tmr-timer
            mu4e-mail
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

(use-package punch-line
  :ensure (:host github :repo "cashmeredev/punch-line")
  :config
  (setq punch-line-left-separator "  "
        punch-line-right-separator "  "
		punch-show-git-info nil
		punch-show-buffer-position t
		punch-show-column-info t
        punch-line-music-max-length 80
		punch-line-modal-divider-style 'block
		punch-line-section-backgrounds 'auto
		punch-show-weather-info t
		punch-weather-longitude "10.41"
		punch-weather-latitude "53.25"
		punch-cpu-usage t
		punch-show-processes-info t)
  (punch-line-mode 1))

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

  (set-face-attribute 'default nil
    :family "MapleMono NF"                                                                                           
    :height 160
    :font (font-spec                                                                                                 
           :family "MapleMono NF"                                                                                    
           :features '(cv04 ss05 zero)))

(set-face-attribute 'fixed-pitch nil :family "MapleMono NF" :weight 'regular)
(set-face-attribute 'variable-pitch nil :family "MapleMono NF" :weight 'regular :height 1.1)

(use-package mixed-pitch
  :ensure t
  :defer t
  :hook ((org-mode   . mixed-pitch-mode)
         (LaTeX-mode . mixed-pitch-mode)))

(use-package grip-mode
  :ensure t
  :config 
  (setq grip-command 'auto)) ;; auto, grip, go-grip or mdopen

;; (use-package catppuccin-theme
;;   :ensure t
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
;;   :ensure (:repo "https://gitlab.com/magus/modus-catppuccin"
;;            :branch "main")
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

(add-to-list 'custom-theme-load-path "~/.emacs.d/themes/")
(load-theme 'noctalia t)

;; (use-package nano-theme
;;   :ensure (:host github :repo "rougier/nano-theme")
;;   :init
;;   (setq nano-fonts-use nil)              ;; keep MapleMono NF, don't force Roboto
;;   (setq nano-window-divider-show t)      ;; subtle dividers between windows
;;   :config
;;   (load-theme 'nano-dark t)

;;   ;; Convenience: cycle between nano-light and nano-dark.
;;   (defun cashmere/nano-toggle-theme ()
;;     "Toggle between `nano-light' and `nano-dark'."
;;     (interactive)
;;     (let ((dark-active (member 'nano-dark custom-enabled-themes)))
;;       (mapc #'disable-theme custom-enabled-themes)
;;       (load-theme (if dark-active 'nano-light 'nano-dark) t)))

;;   ;; Soften a few faces that nano leaves a bit too plain.
;;   (with-eval-after-load 'org
;;     (set-face-attribute 'org-document-title nil :height 1.4 :weight 'light)
;;     (set-face-attribute 'org-level-1 nil :height 1.2 :weight 'medium)
;;     (set-face-attribute 'org-level-2 nil :height 1.1 :weight 'medium)
;;     (set-face-attribute 'org-level-3 nil :height 1.05 :weight 'medium)))

(use-package dirvish
  :ensure t
  :init
  (dirvish-override-dired-mode)

  :custom
  (dirvish-quick-access-entries
   '(("h" "~/" "Home")
     ("d" "~/Downloads/" "Downloads")
     ;; ("p" "~/projects/" "Projects")
     ))

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

  ;; On TTY: drop dirvish's GUI-only media dispatchers (image/video/gif).
  ;; They call `create-image' + `image-size' on cached thumbnails →
  ;; "Window system frame should be used" on terminal frames.  Bare
  ;; symbols here — `dirvish-*-dp' names only appear after
  ;; `dirvish--preview-dps-validate' interns them (dirvish.el:577).
  ;;
  ;; kitty-graphics ships its own dirvish dispatcher (`kitty-image',
  ;; registered by `kitty-gfx--install-dirvish' on `kitty-graphics-mode'
  ;; enable, see kitty-graphics.el:4040) that handles images + video
  ;; thumbnails via the Kitty protocol.  It runs before this filter
  ;; thanks to being prepended; removing the GUI dispatchers is purely
  ;; a safety net for cases where `kitty-image' returns nil (backend
  ;; lost, mode disabled mid-flight).
  (unless (display-graphic-p)
    (with-eval-after-load 'dirvish
      (setq dirvish-preview-dispatchers
            (cl-remove-if (lambda (d)
                            (memq d '(image gif video video-mtn)))
                          dirvish-preview-dispatchers)))))

;; (use-package tramp-hlo
;;     :ensure (:host github :repo "jsadusk/tramp-hlo")
;;     :config
;;     (tramp-hlo-setup))

(add-to-list 'load-path "/home/cashmere/.emacs.d/tramp-rpc/lisp")
(require 'tramp-rpc)


(use-package zoxide
  :ensure t) 

(use-package dired-rsync 
  :ensure t)

(use-package dired-rsync-transient
  :ensure t
  :after (dired-rsync transient))

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
(define-globalized-minor-mode my/global-olivetti-mode olivetti-mode
 (lambda () (olivetti-mode 1)))
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

(use-package consult-projectile
  :ensure t
  :after (consult projectile)
  :defer t
  :config
  (setq consult-project-function #'projectile-project-root))

(use-package wgrep
  :ensure t
  :defer t
  :custom
  (wgrep-auto-save-buffer t)
  (wgrep-change-readonly-file t))

(defun my/project-replace ()
  "Project-wide search via `consult-ripgrep'.
In the minibuffer press `C-c C-e' (embark-export) — wgrep mode
activates automatically. Edit, then `C-c C-c' commits, `C-c C-k' aborts."
  (interactive)
  (call-interactively #'consult-ripgrep))

(defun my/embark-export-auto-wgrep (&rest _)
  "Enter wgrep mode automatically after `embark-export'."
  (when (and (derived-mode-p 'grep-mode)
             (fboundp 'wgrep-change-to-wgrep-mode))
    (wgrep-change-to-wgrep-mode)))

(with-eval-after-load 'embark
  (advice-add 'embark-export :after #'my/embark-export-auto-wgrep))

(use-package pass
  :ensure t
  :defer t
  :commands (pass)
  :config
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
      "g"   'pass-update-buffer
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
)

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
  "dj" '(denote-journal-new-or-existing-entry :wk "journal")
  "dd" '(denote-menu-list-notes t :wk "List all notes")
  "dm" '(:ignore t :wk "Merge Notes")
  "dmr" '(denote-merge-region :wk "Merge Region")
  "dmf" '(denote-merge-file :wk "Merge File")
  "dg" '(consult-denote-grep t :wk "Search")
  "dl" '(denote-link-or-create t :wk "Link Note")
  "dn" '(denote t :wk "Create a new note")
  "dr" '(denote-rename-file t :wk "Rename Note")
  "dtl" '(tmr-list-timers :wk "list timer")
  "dtt" '(tmr :wk "set timer")

  "f" '(:ignore t :wk "files")
  "fd" '(dired-jump :wk "dired")
  "fD" '(dired-jump :wk "dired jump")
  "fr" '(consult-recent-file :wk "recent files")
  "ff" '(find-file :wk "find file")
  "fs" '(save-buffer :wk "save file")

  "b" '(:ignore t :wk "buffer/bookmarks")
  "bb" '(consult-bookmark :wk "display current bookmarks")
  "ba" '(ibuffer :wk "ibuffer")
  "bi" '(projectile-ibuffer :wk "ibuffer project")
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
  "pr" '(my/project-replace :wk "project replace (wgrep)")
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
  "gT" '(my/code-todos-harvest :wk "harvest code TODOs")

  "o" '(:ignore t :wk "open")
  "os" '(my/snip-upload :wk "snip buffer/region")
  "oS" '(my/snip-upload-file :wk "snip file")
  "op" '(pass :wk "pass")

  "h" '(:ignore t :wk "help")
  "hm" '(describe-mode :wk "mode")
  "hf" '(describe-function :wk "function")
  "hv" '(describe-variable :wk "variable")
  "hk" '(describe-key :wk "key")
  "ht" '(consult-theme :wk "load theme")

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
  "u" '(undo-tree-visualize :wk "undo tree")
  "P" '(consult-yank-from-kill-ring :wk "paste history")

  "t" '(:ignore t :wk "treesitter")
  "ts" '(flash-treesitter :wk "flash treesitter")


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
  "ll" '(org-insert-link :wk "link various things")

  "n" '(org-toggle-narrow-to-subtree :wk "narrow"))

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
  :keymaps '(rust-ts-mode-map)
  "m" '(:wk "rust mode" :ignore)
  "mr" '(rust-run :wk "run")
  "mc" '(rust-run-clippy :wk "clippy")
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
  "r" '(async-shell-command :wk "run async")
  "t" '(projectile-run-vterm :wk "terminal")
  "e" '(eshell :wk "eshell")
  "z" '(golden-ratio-mode :wk "zoom/golden ratio")
  "o" '(my/global-olivetti-mode :wk "center buffer")
  "s" '(my-org-sidecar-left :wk "org sidecar"))

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

(use-package elfeed-goodies
  :ensure t
  :after elfeed
  :config
  (elfeed-goodies/setup))

(use-package shrface
  :ensure t
  :after elfeed
  :config
  (shrface-basic)
  (shrface-trial)
  (shrface-default-keybindings)
  (setq shrface-href-versatile t
        shrface-bullets-bullet-list '("◉" "○" "✸" "✿")))

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
  (shrface-trial))

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

(use-package engine-mode
  :ensure t
  :commands (engine/search-duckduckgo
             engine/search-google
             engine/search-github
             engine/search-mdn
             engine/search-wikipedia
             engine/search-arch-wiki
             engine/search-nixpkgs
             engine/search-rustdocs)
  :config
  (engine-mode 1)
  (setq engine/browser-function 'eww-browse-url)
  (defengine duckduckgo "https://duckduckgo.com/html/?q=%s" :keybinding "d")
  (defengine google     "https://google.com/search?q=%s"    :keybinding "g")
  (defengine github     "https://github.com/search?q=%s&type=code" :keybinding "h")
  (defengine mdn        "https://developer.mozilla.org/en-US/search?q=%s" :keybinding "m")
  (defengine wikipedia  "https://en.wikipedia.org/wiki/Special:Search?search=%s" :keybinding "w")
  (defengine arch-wiki  "https://wiki.archlinux.org/index.php?search=%s" :keybinding "a")
  (defengine nixpkgs    "https://search.nixos.org/packages?query=%s" :keybinding "n")
  (defengine rustdocs   "https://docs.rs/releases/search?query=%s" :keybinding "r"))

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

(use-package denote-project-notes
  :ensure t
  :after org
  :config
  (setq denote-project-notes-identifier '(project stayem)))

(use-package emacs-everywhere
  :ensure t)

;; (profiler-start 'cpu)
;; (org-agenda nil "c")
;; (profiler-report)
;; (profiler-stop)

(use-package arrow
  :ensure t
  :elpaca (arrow :host github :repo "vmargb/arrow.el")
  :config
  (setq arrow-mode 1))

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

(use-package gleam-ts-mode
  :ensure t
  :mode "\\.gleam\\'"
  :hook (gleam-ts-mode . eglot-ensure)
  :config
  (add-to-list 'eglot-server-programs
               '(gleam-ts-mode . ("gleam" "lsp"))))

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

(use-package eshell-atuin
  :ensure t
  :after eshell
  :config
  (eshell-atuin-mode))

(use-package el-fetch
  :ensure t)

(provide 'init)
