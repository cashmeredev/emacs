;;; agent-shell-kimi.el --- Kimi Code agent configurations -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Nicolai Singh

;; This package is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This package is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This file includes Kimi Code configuration using `kimi acp'.
;;
;; It exposes the Kimi-specific flags that are available when starting an
;; ACP server (`--yolo', `--auto', `--plan', `--model', `--add-dir',
;; `--skills-dir') and integrates with Kimi's session index so recent
;; sessions can be resumed from Emacs.

;;; Code:

(eval-when-compile
  (require 'cl-lib))
(require 'json)
(require 'shell-maker)
(require 'acp)

(declare-function agent-shell--indent-string "agent-shell")
(declare-function agent-shell--make-acp-client "agent-shell")
(declare-function agent-shell-make-agent-config "agent-shell")
(autoload 'agent-shell-make-agent-config "agent-shell")
(declare-function agent-shell--dwim "agent-shell")
(declare-function agent-shell-start "agent-shell")
(declare-function shell-maker-welcome-message "shell-maker")
(defvar shell-maker-prompt)
(defvar shell-maker-prompt-regexp)

(defcustom agent-shell-kimi-acp-command
  '("kimi" "acp")
  "Command and parameters for the Kimi Code CLI client.

The first element is the command name, and the rest are command parameters.
This is the base command; flags controlled by the other custom variables
in this file are prepended before the `acp' subcommand."
  :type '(repeat string)
  :group 'agent-shell)

(defcustom agent-shell-kimi-default-model-id
  nil
  "Default Kimi model ID.

Must be one of the model ID's displayed under \"Available models\"
when starting a new shell.

Can be set to either a string or a function that returns a string."
  :type '(choice (const nil) string function)
  :group 'agent-shell)

(defcustom agent-shell-kimi-default-session-mode-id
  nil
  "Default Kimi Code session mode ID.

Must be one of the mode ID's displayed under \"Available modes\"
when starting a new shell.

Can be set to either a string or a function that returns a string."
  :type '(choice (const nil) string function)
  :group 'agent-shell)

(defcustom agent-shell-kimi-environment
  nil
  "Environment variables for the Kimi Code CLI client.

This should be a list of environment variables to be used when
starting the Kimi client process."
  :type '(repeat string)
  :group 'agent-shell)

(defcustom agent-shell-kimi-yolo
  nil
  "When non-nil, pass `--yolo' to `kimi' so all actions are auto-approved.

See `kimi --help' for the exact semantics."
  :type 'boolean
  :group 'agent-shell)

(defcustom agent-shell-kimi-auto
  nil
  "When non-nil, pass `--auto' to `kimi' to start in auto permission mode."
  :type 'boolean
  :group 'agent-shell)

(defcustom agent-shell-kimi-plan
  nil
  "When non-nil, pass `--plan' to `kimi' to start in plan mode."
  :type 'boolean
  :group 'agent-shell)

(defcustom agent-shell-kimi-model
  nil
  "Kimi model alias passed to `--model'.

Can be either a string or a function that returns a string.  When nil,
no `--model' flag is added and Kimi uses its configured default."
  :type '(choice (const nil) string function)
  :group 'agent-shell)

(defcustom agent-shell-kimi-additional-dirs
  nil
  "List of additional workspace directories passed via `--add-dir'.

Each entry should be an expanded directory path."
  :type '(repeat string)
  :group 'agent-shell)

(defcustom agent-shell-kimi-skills-dirs
  nil
  "List of skills directories passed via `--skills-dir'.

Each entry should be an expanded directory path."
  :type '(repeat string)
  :group 'agent-shell)

(defcustom agent-shell-kimi-extra-command-params
  nil
  "Extra command-line parameters passed to `kimi' before the `acp' subcommand.

Use this for flags that do not yet have a dedicated custom variable."
  :type '(repeat string)
  :group 'agent-shell)

(defcustom agent-shell-kimi-session-index
  (expand-file-name "~/.kimi-code/session_index.jsonl")
  "Path to Kimi's session index file.

Used by `agent-shell-kimi-resume-session' to list recent sessions."
  :type 'file
  :group 'agent-shell)

(cl-defun agent-shell-kimi-make-authentication (&key api-key login none)
  "Create a Kimi authentication configuration.

API-KEY is a Kimi API key string or a function that returns one.
LOGIN when non-nil indicates login-based (device-code) authentication.
NONE when non-nil indicates no authentication method is requested.

Only one of API-KEY, LOGIN, or NONE should be provided."
  (when (> (seq-count #'identity (list api-key login none)) 1)
    (error "Cannot specify multiple authentication methods - choose one"))
  (unless (> (seq-count #'identity (list api-key login none)) 0)
    (error "Must specify one of :api-key, :login, or :none"))
  (cond
   (api-key `((:api-key . ,api-key)))
   (login `((:login . t)))
   (none `((:none . t)))))

(defcustom agent-shell-kimi-authentication
  (agent-shell-kimi-make-authentication :none t)
  "Configuration for Kimi authentication.

For no explicit authentication (default):

  (setq agent-shell-kimi-authentication
        (agent-shell-kimi-make-authentication :none t))

For login-based authentication:

  (setq agent-shell-kimi-authentication
        (agent-shell-kimi-make-authentication :login t))

For API key (string):

  (setq agent-shell-kimi-authentication
        (agent-shell-kimi-make-authentication :api-key \"your-key\"))

For API key (function):

  (setq agent-shell-kimi-authentication
        (agent-shell-kimi-make-authentication :api-key (lambda () ...)))"
  :type 'alist
  :group 'agent-shell)

(defcustom agent-shell-kimi-login-command
  '("kimi" "login")
  "Command used by `agent-shell-kimi-login' to run the device-code flow."
  :type '(repeat string)
  :group 'agent-shell)

(defcustom agent-shell-kimi-show-model-in-prompt
  t
  "When non-nil, include the active model/mode in the Kimi shell prompt."
  :type 'boolean
  :group 'agent-shell)

;;;; Faces

(defface agent-shell-kimi-prompt-face
  '((t (:foreground "#81c8be" :weight bold :inherit fixed-pitch)))
  "Face for the Kimi shell prompt."
  :group 'agent-shell)

(defface agent-shell-kimi-user-face
  '((t (:inherit default)))
  "Face for user messages in the Kimi shell."
  :group 'agent-shell)

(defface agent-shell-kimi-assistant-face
  '((t (:foreground "#8caaee")))
  "Face for assistant messages in the Kimi shell."
  :group 'agent-shell)

(defface agent-shell-kimi-tool-face
  '((t (:foreground "#ca9ee6")))
  "Face for tool-use sections in the Kimi shell."
  :group 'agent-shell)

(defface agent-shell-kimi-thought-face
  '((t (:foreground "#a5adce" :slant italic)))
  "Face for thought-process sections in the Kimi shell."
  :group 'agent-shell)

(defface agent-shell-kimi-error-face
  '((t (:foreground "#e78284" :weight bold)))
  "Face for errors in the Kimi shell."
  :group 'agent-shell)

;;;; Authentication & helpers

(defun agent-shell-kimi-key ()
  "Get the Kimi API key from `agent-shell-kimi-authentication'."
  (cond ((stringp (map-elt agent-shell-kimi-authentication :api-key))
         (map-elt agent-shell-kimi-authentication :api-key))
        ((functionp (map-elt agent-shell-kimi-authentication :api-key))
         (condition-case _err
             (funcall (map-elt agent-shell-kimi-authentication :api-key))
           (error
            "API key not found.  Check out `agent-shell-kimi-authentication'")))
        (t
         nil)))

(defun agent-shell-kimi-login ()
  "Run `kimi login' to authenticate via the device-code flow."
  (interactive)
  (unless agent-shell-kimi-login-command
    (user-error "`agent-shell-kimi-login-command' is not set"))
  (let ((command (mapconcat #'shell-quote-argument agent-shell-kimi-login-command " ")))
    (async-shell-command command "*Kimi login*")))

(defun agent-shell-kimi--resolve-string-or-function (value)
  "Resolve VALUE if it is a function, otherwise return it as-is."
  (if (functionp value)
      (funcall value)
    value))

(defun agent-shell-kimi--command-params ()
  "Return the complete list of parameters passed to `kimi' before `acp'."
  (let ((params nil))
    (when agent-shell-kimi-yolo
      (push "--yolo" params))
    (when agent-shell-kimi-auto
      (push "--auto" params))
    (when agent-shell-kimi-plan
      (push "--plan" params))
    (when-let* ((model (agent-shell-kimi--resolve-string-or-function agent-shell-kimi-model))
                ((not (string-empty-p model))))
      (push "--model" params)
      (push model params))
    (dolist (dir (reverse agent-shell-kimi-additional-dirs))
      (push "--add-dir" params)
      (push dir params))
    (dolist (dir (reverse agent-shell-kimi-skills-dirs))
      (push "--skills-dir" params)
      (push dir params))
    (dolist (arg (reverse agent-shell-kimi-extra-command-params))
      (push arg params))
    (nreverse params)))

(defun agent-shell-kimi--active-model-string ()
  "Return the currently configured Kimi model alias, or nil if none."
  (when-let* ((model (agent-shell-kimi--resolve-string-or-function
                      agent-shell-kimi-model))
              ((not (string-empty-p model))))
    model))

(defun agent-shell-kimi--active-mode-string ()
  "Return the currently configured Kimi session mode ID, or nil if none."
  (when-let* ((mode (agent-shell-kimi--resolve-string-or-function
                     agent-shell-kimi-default-session-mode-id))
              ((not (string-empty-p mode))))
    mode))

(defun agent-shell-kimi--prompt-string ()
  "Return the propertized Kimi shell prompt string."
  (let ((extra nil))
    (when agent-shell-kimi-show-model-in-prompt
      (let ((model (agent-shell-kimi--active-model-string))
            (mode (agent-shell-kimi--active-mode-string)))
        (when (or model mode)
          (setq extra (concat "("
                              (or model "default")
                              (when mode (concat "|" mode))
                              ")")))))
    (propertize (concat "Kimi" extra "> ")
                'font-lock-face 'agent-shell-kimi-prompt-face)))

(defun agent-shell-kimi-update-prompt ()
  "Update the prompt in the current Kimi shell buffer."
  (interactive)
  (when (eq major-mode 'agent-shell-mode)
    (setq-local shell-maker-prompt (agent-shell-kimi--prompt-string))
    (setq-local shell-maker-prompt-regexp
                (concat "^" (regexp-quote (substring-no-properties shell-maker-prompt))))))

(defun agent-shell-kimi-make-config ()
  "Create a Kimi Code agent configuration.

Returns an agent configuration alist using `agent-shell-make-agent-config'."
  (agent-shell-make-agent-config
   :identifier 'kimi
   :mode-line-name "Kimi"
   :buffer-name "Kimi"
   :shell-prompt (agent-shell-kimi--prompt-string)
   :shell-prompt-regexp "Kimi[^>]*> "
   :welcome-function #'agent-shell-kimi--welcome-message
   :client-maker (lambda (buffer)
                   (agent-shell-kimi-make-client :buffer buffer))
   :default-model-id (lambda () (agent-shell-kimi--resolve-string-or-function
                                 agent-shell-kimi-default-model-id))
   :default-session-mode-id (lambda () (agent-shell-kimi--resolve-string-or-function
                                        agent-shell-kimi-default-session-mode-id))
   :install-instructions "See https://www.kimi.com/code for installation."))

(defun agent-shell-kimi-start-agent ()
  "Start an interactive Kimi Code agent shell."
  (interactive)
  (agent-shell--dwim :config (agent-shell-kimi-make-config)
                     :new-shell t))

(defun agent-shell-kimi-start-coding ()
  "Start a Kimi shell for normal coding.

This is equivalent to `agent-shell-kimi-start-agent' but explicitly
resets `--plan' and `--yolo' so the shell starts in plain coding mode."
  (interactive)
  (let ((agent-shell-kimi-plan nil)
        (agent-shell-kimi-yolo nil))
    (agent-shell-kimi-start-agent)))

(defun agent-shell-kimi-start-plan ()
  "Start a Kimi shell in plan mode (`--plan')."
  (interactive)
  (let ((agent-shell-kimi-plan t)
        (agent-shell-kimi-yolo nil))
    (agent-shell-kimi-start-agent)))

(defun agent-shell-kimi-start-yolo ()
  "Start a Kimi shell in yolo/auto-approve mode (`--yolo')."
  (interactive)
  (let ((agent-shell-kimi-yolo t))
    (agent-shell-kimi-start-agent)))

(defun agent-shell-kimi-start-review ()
  "Start a Kimi shell tuned for code review.

Enables `--plan' and, if no model is set, falls back to
`kimi-for-coding'.  Customize `agent-shell-kimi-model' to change the
review model."
  (interactive)
  (let ((agent-shell-kimi-plan t)
        (agent-shell-kimi-yolo nil)
        (agent-shell-kimi-model (or agent-shell-kimi-model "kimi-for-coding")))
    (agent-shell-kimi-start-agent)))

(cl-defun agent-shell-kimi-make-client (&key buffer)
  "Create a Kimi Code ACP client with BUFFER as context."
  (unless buffer
    (error "Missing required argument: :buffer"))
  (let* ((command (car agent-shell-kimi-acp-command))
         (base-params (cdr agent-shell-kimi-acp-command))
         (kimi-params (agent-shell-kimi--command-params))
         ;; Global `kimi' flags go before the `acp' subcommand.
         (command-params (if (string= (car base-params) "acp")
                             (append kimi-params base-params)
                           (append base-params kimi-params)))
         (env-vars (append agent-shell-kimi-environment
                           (when-let* ((api-key (agent-shell-kimi-key))
                                       ((not (map-elt agent-shell-kimi-authentication :none))))
                             (list (format "KIMI_API_KEY=%s" api-key))))))
    (agent-shell--make-acp-client :command command
                                  :command-params command-params
                                  :environment-variables env-vars
                                  :context-buffer buffer)))

(defun agent-shell-kimi--read-jsonl (path)
  "Return a list of parsed JSON objects from PATH (one per line)."
  (when (file-exists-p path)
    (with-temp-buffer
      (insert-file-contents path)
      (let ((result nil))
        (goto-char (point-min))
        (while (not (eobp))
          (let ((line (string-trim (thing-at-point 'line t))))
            (unless (string-empty-p line)
              (push (json-parse-string line :object-type 'alist) result)))
          (forward-line 1))
        (nreverse result)))))

(defun agent-shell-kimi--session-mtime (session)
  "Return the modification time of SESSION's directory, or 0 if missing."
  (let ((dir (cdr (assq 'sessionDir session))))
    (if (file-directory-p dir)
        (time-to-seconds (file-attribute-modification-time (file-attributes dir)))
      0)))

(defun agent-shell-kimi--relative-time (seconds)
  "Return a human-readable string for SECONDS since the epoch."
  (let ((delta (max 0 (- (float-time) seconds))))
    (cond ((< delta 60) "just now")
          ((< delta 3600) (format "%d min ago" (floor delta 60)))
          ((< delta 86400) (format "%d hr ago" (floor delta 3600)))
          ((< delta 604800) (format "%d days ago" (floor delta 86400)))
          (t (format "%d wks ago" (floor delta 604800))))))

(defun agent-shell-kimi--session-project-name (session)
  "Return a project-like name for SESSION's working directory."
  (let ((dir (abbreviate-file-name (or (cdr (assq 'workDir session)) ""))))
    (if (string-empty-p dir)
        "?"
      (file-name-nondirectory (directory-file-name dir)))))

(defun agent-shell-kimi--session-label (session)
  "Return a display label for SESSION suitable for `completing-read'."
  (let ((id (cdr (assq 'sessionId session)))
        (dir (abbreviate-file-name (or (cdr (assq 'workDir session)) "")))
        (project (agent-shell-kimi--session-project-name session))
        (mtime (agent-shell-kimi--session-mtime session)))
    (format "%s  %s  %s  %s"
            project
            (agent-shell-kimi--relative-time mtime)
            dir
            (or id ""))))

(defun agent-shell-kimi--session-current-p (session)
  "Return non-nil if SESSION's workDir is under `default-directory'."
  (let ((dir (cdr (assq 'workDir session)))
        (cwd (expand-file-name default-directory)))
    (and dir
         (string-prefix-p cwd (expand-file-name dir)))))

(defun agent-shell-kimi-clean-session-index ()
  "Remove session index entries whose working directory no longer exists.

Returns the number of removed entries.  The original index file is
renamed with a timestamp backup before rewriting."
  (interactive)
  (unless (file-exists-p agent-shell-kimi-session-index)
    (user-error "Session index not found: %s" agent-shell-kimi-session-index))
  (let* ((sessions (agent-shell-kimi--read-jsonl agent-shell-kimi-session-index))
         (valid (seq-filter (lambda (s)
                              (let ((dir (cdr (assq 'workDir s))))
                                (and dir (file-directory-p dir))))
                            sessions))
         (removed (- (length sessions) (length valid))))
    (when (> removed 0)
      (rename-file agent-shell-kimi-session-index
                   (format "%s.bak-%s" agent-shell-kimi-session-index
                           (format-time-string "%Y%m%d-%H%M%S"))
                   t)
      (with-temp-file agent-shell-kimi-session-index
        (dolist (s valid)
          (insert (json-encode s) "\n"))))
    (message "Removed %d stale Kimi session(s)" removed)
    removed))

(defun agent-shell-kimi-resume-session (cleanup)
  "Resume a recent Kimi session by selecting from the session index.

With prefix arg CLEANUP, first remove index entries whose working
directory no longer exists."
  (interactive "P")
  (when cleanup
    (agent-shell-kimi-clean-session-index))
  (let* ((sessions (agent-shell-kimi--read-jsonl agent-shell-kimi-session-index))
         (sessions (seq-filter (lambda (s)
                                 (let ((dir (cdr (assq 'workDir s))))
                                   (and dir (file-directory-p dir))))
                               sessions))
         (sessions (seq-sort-by #'agent-shell-kimi--session-mtime #'> sessions))
         ;; Surface sessions from the current project first.
         (sessions (append (seq-filter #'agent-shell-kimi--session-current-p sessions)
                           (seq-remove #'agent-shell-kimi--session-current-p sessions)))
         (choices (mapcar (lambda (s)
                            (cons (agent-shell-kimi--session-label s) s))
                          sessions))
         (choice (completing-read "Resume Kimi session: " choices nil t))
         (session (cdr (assoc choice choices)))
         (dir (cdr (assq 'workDir session)))
         (id (cdr (assq 'sessionId session))))
    (unless session
      (user-error "No session selected"))
    (unless (and dir (file-directory-p dir))
      (user-error "Session working directory no longer exists: %s" dir))
    (let ((default-directory dir))
      (agent-shell-start :config (agent-shell-kimi-make-config)
                         :session-id id))))

(defun agent-shell-kimi--welcome-status-line ()
  "Return a short status line for the Kimi welcome message."
  (let ((model (or (agent-shell-kimi--active-model-string) "default"))
        (mode (or (agent-shell-kimi--active-mode-string) "default")))
    (concat
     (propertize "model" 'font-lock-face 'agent-shell-kimi-tool-face)
     ": " model "  "
     (propertize "mode" 'font-lock-face 'agent-shell-kimi-tool-face)
     ": " mode "  "
     (propertize "send" 'font-lock-face 'agent-shell-kimi-thought-face) " M-RET  "
     (propertize "interrupt" 'font-lock-face 'agent-shell-kimi-thought-face) " C-c C-c  "
     (propertize "menu" 'font-lock-face 'agent-shell-kimi-thought-face) " SPC a k")))

(defun agent-shell-kimi--welcome-message (config)
  "Return Kimi ASCII art using `shell-maker' CONFIG."
  (let ((art (agent-shell--indent-string 4 (agent-shell-kimi--ascii-art)))
        (message (string-trim-left (shell-maker-welcome-message config) "\n")))
    (concat "\n\n"
            art
            "\n\n"
            "  " (agent-shell-kimi--welcome-status-line) "\n\n"
            message)))

(defun agent-shell-kimi--ascii-art ()
  "Kimi ASCII art."
  (let* ((is-dark (eq (frame-parameter nil 'background-mode) 'dark))
         (text (string-trim "
 ██╗  ██╗ ██╗ ███╗   ███╗ ██╗
 ██║ ██╔╝ ██║ ████╗ ████║ ██║
 █████╔╝  ██║ ██╔████╔██║ ██║
 ██╔═██╗  ██║ ██║╚██╔╝██║ ██║
 ██║  ██╗ ██║ ██║ ╚═╝ ██║ ██║
 ╚═╝  ╚═╝ ╚═╝ ╚═╝     ╚═╝ ╚═╝
" "\n")))
    (propertize text 'font-lock-face (if is-dark
                                         '(:foreground "#dddddd" :inherit fixed-pitch)
                                       '(:foreground "#000000" :inherit fixed-pitch)))))

(defcustom agent-shell-kimi-model-choices
  '("kimi-for-coding" "kimi-k2" "kimi-k2-5")
  "List of model aliases offered by `agent-shell-kimi-set-model'.

Set this to the model aliases your Kimi CLI installation supports."
  :type '(repeat string)
  :group 'agent-shell)

(defun agent-shell-kimi-set-model (model)
  "Interactively set `agent-shell-kimi-model' to MODEL.

Use `agent-shell-kimi-model-choices' for completion.  An empty choice
clears the model and uses Kimi's configured default."
  (interactive
   (list (completing-read "Kimi model (empty for default): "
                          agent-shell-kimi-model-choices
                          nil nil
                          (or (agent-shell-kimi--active-model-string) ""))))
  (setq agent-shell-kimi-model (if (string-empty-p model) nil model))
  (message "Kimi model set to %s" (or agent-shell-kimi-model "default")))

(defun agent-shell-kimi-set-directory (dir)
  "Add DIR to `agent-shell-kimi-additional-dirs'.

Existing entries are preserved; duplicates are removed."
  (interactive "DAdditional workspace directory: ")
  (setq agent-shell-kimi-additional-dirs
        (seq-uniq (append agent-shell-kimi-additional-dirs
                          (list (expand-file-name dir)))))
  (message "Kimi additional dirs: %s" agent-shell-kimi-additional-dirs))

(defcustom agent-shell-kimi-pulse-on-done
  t
  "When non-nil, pulse the mode-line when Kimi finishes responding.

Only applies when the Kimi buffer is not the selected window; the
pulse is meant as a subtle TUI notification."
  :type 'boolean
  :group 'agent-shell)

(declare-function shell-maker--announce-response "shell-maker")

(defun agent-shell-kimi-response-done-pulse (buffer)
  "Pulse the mode-line to notify that BUFFER has finished responding.

Meant to be added as :after advice to `shell-maker--announce-response'."
  (when (and agent-shell-kimi-pulse-on-done
             (buffer-live-p buffer)
             (not (eq buffer (window-buffer (selected-window)))))
    (let ((face 'agent-shell-kimi-prompt-face)
          (original-face (face-attribute 'mode-line :inherit)))
      (set-face-attribute 'mode-line nil :inherit face)
      (run-with-timer 0.3 nil
                      (lambda ()
                        (set-face-attribute 'mode-line nil :inherit original-face))))))

(advice-add 'shell-maker--announce-response :after #'agent-shell-kimi-response-done-pulse)

(provide 'agent-shell-kimi)

;;; agent-shell-kimi.el ends here
