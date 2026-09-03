;;; my-header-line.el --- Custom header line built with mode-line-maker -*- lexical-binding: t; -*-

(require 'mode-line-maker)

(defcustom my/header-line-height 35
  "Minimum graphical header-line height, before image scaling.
Matches the default height of Dirvish's full-frame header line."
  :type 'natnum
  :group 'mode-line)

(defcustom my/header-line-show-major-mode nil
  "Whether to show the major mode next to the clock in the header line."
  :type 'boolean
  :group 'mode-line)

(defface my/header-line-evil-normal
  '((t (:inherit font-lock-keyword-face :weight bold)))
  "Face for the evil normal state indicator.")

(defface my/header-line-evil-insert
  '((t (:inherit success :weight bold)))
  "Face for the evil insert state indicator.")

(defface my/header-line-evil-visual
  '((t (:inherit warning :weight bold)))
  "Face for the evil visual state indicator.")

(defface my/header-line-evil-replace
  '((t (:inherit error :weight bold)))
  "Face for the evil replace state indicator.")

(defface my/header-line-evil-motion
  '((t (:inherit font-lock-constant-face :weight bold)))
  "Face for the evil motion state indicator.")

(defface my/header-line-evil-emacs
  '((t (:inherit font-lock-builtin-face :weight bold)))
  "Face for the evil Emacs state indicator.")

(defface my/header-line-buffer-icon-face
  '((t (:inherit mode-line-buffer-id)))
  "Face for the current buffer's file or mode icon.")

(defface my/header-line-irc-face
  '((t (:inherit font-lock-builtin-face :weight bold)))
  "Face for the IRC activity indicator.")

(defface my/header-line-clatter-face
  '((t (:inherit success :weight bold)))
  "Theme success color for Clatter's connected-channel indicator.")

(defface my/header-line-mu4e-face
  '((t (:inherit font-lock-type-face :weight bold)))
  "Theme type accent for the unread mail indicator.")

(defface my/header-line-time-face
  '((t (:inherit mode-line-buffer-id :weight normal)))
  "Theme buffer-name accent for the clock, in regular weight.")

(defface my/header-line-state-saved-face
  '((t (:inherit success)))
  "Face for the saved buffer state icon.")

(defface my/header-line-state-modified-face
  '((t (:inherit warning :weight bold)))
  "Face for the modified buffer state icon.")

(defface my/header-line-state-read-only-face
  '((t (:inherit error)))
  "Face for the read-only buffer state icon.")

(defface my/header-line-position-face
  '((t (:inherit shadow :weight normal :slant normal)))
  "Quiet face for the scroll percentage and cursor position.")

(defface my/header-line-workspace-active-face
  '((t (:inherit my/header-line-position-face :inverse-video nil :box nil)))
  "Current workspace, styled like the percentage and cursor position.")

(defface my/header-line-workspace-inactive-face
  '((t (:inherit shadow :weight normal :slant normal)))
  "Quiet numbers for other open workspaces.")

(defvar my/header-line-workspaces-expanded nil
  "Whether the header line also shows the other open workspaces.")

(defconst my/header-line-position
  '(" "
    (:propertize "%p" face my/header-line-position-face
                 help-echo "Window scroll position")
    " "
    (:propertize "%l:%c" face my/header-line-position-face
                 help-echo "Line : column (columns start at 0)"))
  "Compact scroll percentage and line:column display.")

(defvar-local my/header-line--buffer-title nil)

(defconst my/header-line--missing (make-symbol "missing")
  "Sentinel used when checking membership in package hash tables.")

(defvar my/header-line--format nil
  "The installed global header-line format.")

(defun my/header-line--update-title-cache ()
  "Update the cached #+title for the current buffer."
  (setq-local my/header-line--buffer-title
              (and (derived-mode-p 'org-mode)
                   (cadar (org-collect-keywords '("TITLE"))))))

(defun my/header-line--buffer-title ()
  "Return the cached #+title, computing it if necessary."
  (unless (local-variable-p 'my/header-line--buffer-title)
    (my/header-line--update-title-cache))
  my/header-line--buffer-title)

(defun my/header-line--invalidate-title-cache ()
  "Invalidate the cached title so it gets recomputed on next update."
  (kill-local-variable 'my/header-line--buffer-title))

(defun my/header-line-buffer-name ()
  "Buffer name for the header line.
Uses the Org #+title if present, otherwise the file path relative to
the project root, falling back to the plain buffer name."
  (or (my/header-line--buffer-title)
      (if-let* ((file buffer-file-name)
                (project (project-current))
                (root (project-root project)))
          (file-relative-name file root)
        (buffer-name))))

(defun my/header-line--nerd-icons-p ()
  "Return non-nil when Nerd Icons are enabled and available."
  (and (bound-and-true-p ek-use-nerd-fonts)
       (require 'nerd-icons nil t)))

(defun my/header-line--icon (name face &optional fallback)
  "Render Nerd icon NAME with FACE, or FALLBACK when unavailable."
  (if (my/header-line--nerd-icons-p)
      (propertize (nerd-icons-mdicon name) 'face face)
    (propertize (or fallback "") 'face face)))

(defun my/header-line-buffer-icon ()
  "Nerd icon for the current buffer, or nil."
  (when (my/header-line--nerd-icons-p)
    (or (and buffer-file-name
             (ignore-errors
               (nerd-icons-icon-for-file
                buffer-file-name :face 'my/header-line-buffer-icon-face)))
        (ignore-errors
          (nerd-icons-icon-for-mode
           major-mode :face 'my/header-line-buffer-icon-face)))))

(defconst my/header-line--evil-states
  '((normal  "N" my/header-line-evil-normal)
    (insert  "I" my/header-line-evil-insert)
    (visual  "V" my/header-line-evil-visual)
    (replace "R" my/header-line-evil-replace)
    (motion  "M" my/header-line-evil-motion)
    (emacs   "E" my/header-line-evil-emacs))
  "Display labels and theme-derived faces for Evil states.")

(defun my/header-line-evil-state ()
  "Compact, theme-aware indicator for the current Evil state."
  (when (bound-and-true-p evil-state)
    (let* ((entry (assq evil-state my/header-line--evil-states))
           (tag (or (nth 1 entry)
                    (upcase (substring (symbol-name evil-state) 0 1))))
           (face (or (nth 2 entry) 'my/header-line-evil-normal)))
      (propertize (format " %s " tag) 'face face))))

(defun my/header-line-buffer-state ()
  "Render a clean lock, edit, or saved indicator for the current buffer."
  (cond
   (buffer-read-only
    (my/header-line--icon "nf-md-lock"
                        'my/header-line-state-read-only-face "RO"))
   ((buffer-modified-p)
    (my/header-line--icon "nf-md-pencil"
                        'my/header-line-state-modified-face "*"))
   (t
    (my/header-line--icon "nf-md-check"
                        'my/header-line-state-saved-face "="))))

(defun my/header-line-remote ()
  "Show a remote indicator only for an actual remote directory.
Unlike the built-in `mode-line-remote', local buffers render nothing instead
of a literal dash."
  (when (file-remote-p default-directory)
    (my/header-line--icon "nf-md-cloud_outline"
                        'font-lock-constant-face "@")))

(defun my/header-line-irc ()
  "IRC activity indicator: icon plus number of buffers with unread activity."
  (when (bound-and-true-p erc-modified-channels-alist)
    (let ((icon (my/header-line--icon "nf-md-forum_outline"
                                    'my/header-line-irc-face "irc")))
      (propertize (format "%s %d" icon
                          (length erc-modified-channels-alist))
                  'face 'my/header-line-irc-face))))

(defun my/header-line-clatter ()
  "Clatter indicator showing the number of joined channels."
  (when (featurep 'clatter)
    (let ((count 0))
      (dolist (buffer (clatter-all-buffers))
        (when (with-current-buffer buffer
                (and (eq clatter--buffer-type 'channel)
                     (hash-table-p clatter--nick-list)
                     (when-let* ((connection
                                  (clatter-get-connection clatter--network))
                                 ((eq (clatter-connection-state connection)
                                      :connected))
                                 (nick (clatter-connection-nick connection)))
                       (not (eq (gethash (downcase nick) clatter--nick-list
                                         my/header-line--missing)
                                my/header-line--missing)))))
          (setq count (1+ count))))
      (when (> count 0)
        (let ((icon (my/header-line--icon "nf-md-forum_outline"
                                        'my/header-line-clatter-face "irc")))
          (propertize (format "%s %d" icon count)
                      'face 'my/header-line-clatter-face))))))

(defun my/header-line-mu4e-formatter (mail-count)
  "Format MAIL-COUNT for the custom header line without an extra icon."
  (unless (zerop mail-count)
    (number-to-string mail-count)))

(defun my/header-line-mu4e ()
  "Unread mail indicator from mu4e-alert, or nil when mu4e is not in use."
  (when (bound-and-true-p mu4e-alert-mode-line)
    (let ((icon (my/header-line--icon "nf-md-email_outline"
                                    'my/header-line-mu4e-face "mail")))
      (propertize (format "%s %s" icon
                          (string-trim mu4e-alert-mode-line))
                  'face 'my/header-line-mu4e-face))))

(defvar my/header-line--clock-icons
  ["nf-md-clock_time_twelve" "nf-md-clock_time_one" "nf-md-clock_time_two"
   "nf-md-clock_time_three" "nf-md-clock_time_four" "nf-md-clock_time_five"
   "nf-md-clock_time_six" "nf-md-clock_time_seven" "nf-md-clock_time_eight"
   "nf-md-clock_time_nine" "nf-md-clock_time_ten" "nf-md-clock_time_eleven"]
  "Nerd icon clock faces indexed by hour modulo 12.")

(defun my/header-line-time ()
  "Time with a live clock icon showing the current hour."
  (when (bound-and-true-p display-time-string)
    (let* ((hour (% (string-to-number (format-time-string "%I")) 12))
           (icon (and (my/header-line--nerd-icons-p)
                      (nerd-icons-mdicon (aref my/header-line--clock-icons hour))))
           (time (string-trim display-time-string)))
      (propertize (if icon (concat icon " " time) time)
                  'face 'my/header-line-time-face))))

(defun my/toggle-header-line-workspaces ()
  "Toggle between the current workspace and all open workspace names."
  (interactive)
  (setq my/header-line-workspaces-expanded
        (not my/header-line-workspaces-expanded))
  (force-mode-line-update t))

(defun my/header-line--workspace-number (index)
  "Return an outlined Nerd Icon for workspace INDEX, with a text fallback."
  (let ((fallback (format "[%d]" index)))
    (if (<= 1 index 10)
        (my/header-line--icon
         (format "nf-md-numeric_%d_box_outline" index)
         'my/header-line-position-face fallback)
      fallback)))

(defun my/header-line-workspaces ()
  "Show the current workspace or all workspaces, each with its number icon."
  (when (and (bound-and-true-p persp-mode)
             (fboundp 'my/workspace-current-name)
             (fboundp 'my/workspace-names))
    (let ((current (my/workspace-current-name))
          (names (my/workspace-names))
          (index 0))
      (when (member current names)
        (string-join
         (delq nil
               (mapcar
                (lambda (name)
                  ;; Keep the same numbering as workspace switching.
                  (setq index (1+ index))
                  (let ((active (equal name current)))
                    (when (or active my/header-line-workspaces-expanded)
                      (propertize
                       ;; The maker expands this before the final header.
                       (string-replace
                        "%" "%%"
                        (concat (my/header-line--workspace-number index)
                                " " name))
                       'face (if active 'my/header-line-workspace-active-face
                               'my/header-line-workspace-inactive-face)
                       'help-echo
                       (format "%d: %s — t: toggle workspaces" index name)))))
                names))
         " ")))))

(defun my/header-line--refresh-workspaces (&rest _args)
  "Refresh all headers after workspace changes."
  (force-mode-line-update t))

(defun my/header-line-sync-theme (&optional _theme)
  "Make helper padding inherit the live header-line theme face.
Optional THEME is ignored so this function also fits
`enable-theme-functions'."
  (set-face-attribute 'mode-line-maker-padding-face nil
                      :inherit 'header-line
                      :foreground 'unspecified
                      :background 'unspecified
                      :box nil
                      :overline nil
                      :underline nil
                      :inverse-video nil
                      :strike-through nil))

(defun my/header-line--height-spacer ()
  "Return a transparent height spacer, using the same approach as Dirvish."
  (when (and (display-graphic-p)
             (image-type-available-p 'pbm)
             (> my/header-line-height 0))
    (propertize
     " " 'display
     (create-image
      (concat (format "P1\n1 %d\n" my/header-line-height)
              (make-string my/header-line-height ?0) "\n")
      'pbm t :foreground "None" :ascent 'center))))

(define-minor-mode my/global-header-line-mode
  "Show the custom header line globally.

When disabled, local informational headers, such as Elfeed's column
headings, remain visible."
  :global t
  :init-value t
  :group 'mode-line
  (setq-default header-line-format
                (and my/global-header-line-mode my/header-line--format))
  (force-mode-line-update t))

(defun my/toggle-header-line ()
  "Toggle the custom header line globally."
  (interactive)
  (my/global-header-line-mode (if my/global-header-line-mode -1 1)))

(defun my/header-line--make (left right)
  "Build a header from LEFT and RIGHT, preserving literal percent signs."
  ;; The maker has already expanded %p, %l, etc.  Escape its result before
  ;; redisplay interprets it again, including percent signs in buffer names.
  (let ((format (mode-line-maker left right)))
    `(:eval (string-replace "%" "%%"
                            (apply #'concat ,(cadr format))))))

(defun my/header-line-install ()
  "Install the custom header line built with mode-line-maker."
  (setq global-mode-string (delq 'display-time-string global-mode-string))
  (my/header-line-sync-theme)
  (add-hook 'enable-theme-functions #'my/header-line-sync-theme)
  (setq my/header-line--format
        (list
         '(:eval (my/header-line--height-spacer))
         (my/header-line--make
          '((:eval (my/header-line-evil-state)) " "
            (:eval (my/header-line-buffer-state))
            (:eval (my/header-line-remote)) " "
            (:eval (my/header-line-buffer-icon)) " "
            (:eval (propertize (my/header-line-buffer-name)
                               'face 'mode-line-buffer-id
                               'mouse-face 'mode-line-highlight
                               'help-echo (concat (or buffer-file-truename (buffer-name))
                                                  "\nmouse-1: Previous buffer\nmouse-3: Next buffer")
                               'local-map mode-line-buffer-identification-keymap))
            my/header-line-position)
          '("" (:eval (my/header-line-irc)) " "
            (:eval (my/header-line-clatter)) " "
            (:eval (my/header-line-mu4e)) " "
            mode-line-process " "
            (:eval (my/header-line-time)) " "
            (my/header-line-show-major-mode ("" mode-name " "))
            (:eval (my/header-line-workspaces)) " "))))
  ;; The header line is visible on every startup, regardless of its previous
  ;; interactive state in a long-running session.
  (my/global-header-line-mode 1)
  (add-hook 'before-save-hook #'my/header-line--invalidate-title-cache)
  (with-eval-after-load 'persp-mode
    (add-hook 'persp-activated-functions #'my/header-line--refresh-workspaces)
    (add-hook 'persp-names-cache-changed-functions
              #'my/header-line--refresh-workspaces)))

(provide 'my-header-line)
;;; my-header-line.el ends here
