;;; fossil-ui.el --- Small TextUI frontend for Fossil -*- lexical-binding: t; -*-

;; Copyright (C) 2026 cashmere

;; Author: cashmere
;; Version: 0.2.0
;; Package-Requires: ((emacs "29.1") (textui "0.8.0"))
;; Keywords: tools, vc

;;; Commentary:

;; Fossil dashboard with persistent local staging, partial commits, and recovery.

;;; Code:

(require 'ansi-color)
(require 'cl-lib)
(declare-function evil-make-overriding-map "evil-core" (keymap &optional state copy))
(require 'textui-keyed-region)
(require 'diff-mode)
(require 'json)
(require 'outline)
(require 'seq)
(require 'subr-x)
(require 'text-property-search)
(require 'vc)
(require 'textui)
(require 'textui-widgets)

(declare-function evil-define-key* "evil-core" (state keymap key def &rest bindings))
(declare-function evil-normalize-keymaps "evil-core" (&optional state))
(declare-function evil-set-initial-state "evil-core" (mode state))
(declare-function evil-visual-range "evil-states" ())
(declare-function evil-exit-visual-state "evil-states" ())
(declare-function diff-hl-update "diff-hl" ())
(declare-function diff-hl-remove-overlays "diff-hl" ())

(defgroup fossil-ui nil
  "A compact TextUI frontend for Fossil."
  :group 'tools
  :prefix "fossil-ui-")

(defvar fossil-ui-post-refresh-hook nil
  "Hook run in the dashboard after a successful checkout refresh.")

(defcustom fossil-ui-program "fossil"
  "Fossil executable used by the dashboard."
  :type 'string
  :group 'fossil-ui)

(defcustom fossil-ui-stage-directory (expand-file-name "fossil-stage/" user-emacs-directory)
  "Private local staging snapshots and interrupted-commit recovery files."
  :type 'directory
  :group 'fossil-ui)

(defcustom fossil-ui-max-stage-bytes (* 5 1024 1024)
  "Maximum text file size accepted for partial staging."
  :type 'integer
  :group 'fossil-ui)

(defcustom fossil-ui-full-frame t
  "Open Fossil using the entire Emacs frame."
  :type 'boolean
  :group 'fossil-ui)

(defcustom fossil-ui-confirm-revert t
  "Confirm before discarding selected working changes."
  :type 'boolean
  :group 'fossil-ui)

(defcustom fossil-ui-compact-layout t
  "Keep dashboard cards compact so changes and recent commits fit together."
  :type 'boolean
  :group 'fossil-ui)

(defcustom fossil-ui-keyed-timeline t
  "Reconcile timeline entries using TextUI's stable keyed regions."
  :type 'boolean
  :group 'fossil-ui)

(defvar-local fossil-ui-window-configuration nil)
(defvar-local fossil-ui-diff-context nil)
(defvar-local fossil-ui-commit-index nil)

(defcustom fossil-ui-timeline-limit 25
  "Maximum number of recent check-ins loaded for the dashboard."
  :type 'integer
  :group 'fossil-ui)

(defcustom fossil-ui-content-width nil
  "Optional maximum width of dashboard content in columns.
Nil, the default, uses the complete TextUI window width.  Set an integer only
when a deliberately compact dashboard is preferred."
  :type '(choice (const :tag "Use full window width" nil)
                 (integer :tag "Maximum columns"))
  :group 'fossil-ui)

(defcustom fossil-ui-use-icons 'auto
  "Whether to use Nerd Font icons in the dashboard.
When set to `auto', use them only in graphical displays when nerd-icons is
already loaded.  Nil always uses portable text symbols."
  :type '(choice (const :tag "Automatically" auto)
                 (const :tag "Always" t)
                 (const :tag "Never" nil))
  :group 'fossil-ui)

(defcustom fossil-ui-timeline-minimum 8
  "Minimum number of timeline entries shown when available."
  :type 'integer
  :group 'fossil-ui)

(defcustom fossil-ui-diff-renderer 'auto
  "Renderer used for working-tree diffs.
`auto' uses Delta when available and otherwise keeps the plain Fossil diff.
`delta' requires `fossil-ui-delta-program' to be executable.  `plain' never
runs an external renderer."
  :type '(choice (const :tag "Delta when available" auto)
                 (const :tag "Always Delta" delta)
                 (const :tag "Plain Fossil diff" plain))
  :group 'fossil-ui)

(defcustom fossil-ui-delta-program "delta"
  "Delta executable used to render Fossil diffs."
  :type 'string
  :group 'fossil-ui)

(defcustom fossil-ui-delta-arguments '("--paging=never" "--color-only")
  "Arguments passed to Delta after the Fossil diff on standard input."
  :type '(repeat string)
  :group 'fossil-ui)

(defcustom fossil-ui-delta-color-mode 'auto
  "Color mode passed to Delta when no explicit color or syntax-theme argument is configured."
  :type '(choice (const :tag "Follow the current Emacs theme" auto)
                 (const :tag "Light backgrounds" light)
                 (const :tag "Dark backgrounds" dark))
  :group 'fossil-ui)

(defcustom fossil-ui-title-alignment 'center
  "TextUI alignment of the project heading."
  :type '(choice (const left) (const center) (const right))
  :group 'fossil-ui)

(defcustom fossil-ui-text-wrap 'greedy
  "TextUI line-breaking strategy for commit messages and status banners."
  :type '(choice (const greedy) (const balanced))
  :group 'fossil-ui)

(defcustom fossil-ui-preview-lines 20
  "Maximum number of diff lines shown in the inline preview."
  :type '(integer 1 *)
  :group 'fossil-ui)

(defun fossil-ui--text (value &optional face align)
  "Return wrapping TextUI text for VALUE with FACE and ALIGN."
  `(:type :text
    :value ,(if face
                (propertize value 'face face)
              value)
    :align ,(or align 'left)
    :wrap ,fossil-ui-text-wrap))

(defun fossil-ui--preview-layout (widget width)
  "Lay out a read-only diff WIDGET at WIDTH without wrapping code lines."
  (let* ((width
          (if fossil-ui-content-width
              (min width fossil-ui-content-width)
            width))
         (lines (split-string (widget-get widget :value) "\n"))
         (limit (max 1 fossil-ui-preview-lines))
         (visible (seq-take lines limit)))
    (concat
     (propertize
      (fossil-ui--fit (format "Diff preview · %s · P closes" (widget-get widget :path)) width) 'face 'fossil-ui-strong)
     "\n"
     (mapconcat
      (lambda (line)
        (propertize
         (truncate-string-to-width (replace-regexp-in-string "\t" "    " line) width nil nil)
         'face
         (cond
          ((string-prefix-p "@@" line)
           'diff-hunk-header)
          ((string-prefix-p "+" line)
           'diff-added)
          ((string-prefix-p "-" line)
           'diff-removed)
          (t 'default))))
      visible "\n")
     (when (> (length lines) limit)
       (concat "\n" (fossil-ui--fit "… RET on file opens the complete diff" width))))))

(defun fossil-ui--preview-attach (widget from to)
  "Attach preview WIDGET to existing text between FROM and TO."
  (widget-put widget :from (copy-marker from t))
  (widget-put widget :to (copy-marker to nil))
  (widget-put widget :delete #'widget-leave-text))

(define-widget 'fossil-ui-preview 'item
  "A width-aware TextUI 0.8 block widget for a read-only diff preview."
  :textui-layout #'fossil-ui--preview-layout
  :textui-attach #'fossil-ui--preview-attach)

(defun fossil-ui--preview-data (root path)
  "Read the internal unified diff for PATH under ROOT."
  (let ((output (fossil-ui--require-success root "diff" "--internal" "--unified" "--" path)))
    (if (string-empty-p output)
        "No textual diff available."
      output)))

(defun fossil-ui-toggle-preview ()
  "Toggle an inline diff preview for the tracked file at point."
  (interactive)
  (let ((path (fossil-ui--path-at-point))
        (previous (plist-get textui-state :preview-path)))
    (if (or (and path
                 (equal path (plist-get textui-state :preview-path)))
            (and (not path)
                 (plist-get textui-state :preview-path)))
        (textui-update
         (current-buffer)
         (lambda (state)
           (plist-put (plist-put state :preview-path nil) :preview nil)))
      (unless path
        (user-error "No file at point"))
      (when (equal (fossil-ui--status-at-point) "EXTRA")
        (user-error "Add the file first to preview its Fossil diff"))
      (let ((diff (fossil-ui--preview-data (plist-get textui-state :root) path)))
        (textui-update
         (current-buffer)
         (lambda (state)
           (plist-put (plist-put state :preview-path path) :preview diff)))))
    (textui-refresh (current-buffer))
    (if (plist-get textui-state :preview-path)
        (progn
          (goto-char (point-min))
          (when (re-search-forward "^Diff preview" nil t)
            (beginning-of-line)
            (when (eq (window-buffer) (current-buffer))
              (recenter 0))))
      (when (or path
                previous)
        (fossil-ui--goto-path (or path
                                  previous))))))

(defface fossil-ui-strong '((t :inherit bold))
  "Structural text."
  :group 'fossil-ui)

(defface fossil-ui-faded '((t :inherit shadow))
  "Secondary text."
  :group 'fossil-ui)

(defface fossil-ui-salient '((t :inherit link))
  "Selected and actionable text."
  :group 'fossil-ui)

(defface fossil-ui-warning '((t :inherit warning))
  "Changed or noteworthy state."
  :group 'fossil-ui)

(defface fossil-ui-critical '((t :inherit error))
  "Conflicts and command errors."
  :group 'fossil-ui)

(defface fossil-ui-selected '((t :inherit highlight :weight bold))
  "Current file row."
  :group 'fossil-ui)

(defun fossil-ui--measure-row (widget)
  "Return the visible single-line value of file-row WIDGET."
  (format "%s" (or (widget-get widget :value) "")))

(defun fossil-ui--attach-row (widget from to)
  "Attach file-row WIDGET to the TextUI text between FROM and TO."
  (textui-widgets-attach-button widget from to)
  (add-text-properties
   from to
   (list 'fossil-ui-path (widget-get widget :fossil-ui-path)
         'fossil-ui-status (widget-get widget :fossil-ui-status))))

(define-widget 'fossil-ui-row 'push-button
  "A flat, clickable Fossil file row."
  :format "%v"
  :button-face 'default
  :textui-measure #'fossil-ui--measure-row
  :textui-attach #'fossil-ui--attach-row)

(define-widget 'fossil-ui-keycap 'push-button
  "A flat keycap and label action."
  :format "%v"
  :button-face 'default
  :textui-measure #'fossil-ui--measure-row
  :textui-attach #'textui-widgets-attach-button)

(defvar fossil-ui--commit-history nil)
(defvar-local fossil-ui--process nil)
(defvar-local fossil-ui--commit-owner nil)
(defvar-local fossil-ui--commit-paths nil)
(defvar-local fossil-ui--window-height nil)

(defun fossil-ui--call-in (directory &rest args)
  "Run Fossil ARGS synchronously in DIRECTORY and return (CODE OUTPUT)."
  (with-temp-buffer
    (let ((default-directory (file-name-as-directory directory)))
      (list (condition-case err
                (apply #'process-file fossil-ui-program nil (list t t) nil args)
              (file-missing
               (insert (error-message-string err))
               127)
              (error
               (insert (error-message-string err))
               1))
            (string-trim-right (buffer-string))))))

(defun fossil-ui--require-success (directory &rest args)
  "Run Fossil ARGS in DIRECTORY and return output or signal a user error."
  (pcase-let ((`(,code ,output) (apply #'fossil-ui--call-in directory args)))
    (if (zerop code)
        output
      (user-error "%s" (if (string-empty-p output)
                             (format "Fossil exited with status %d" code)
                           output)))))

(defun fossil-ui--input-directory (&optional directory)
  "Return a usable starting directory for DIRECTORY or the current buffer."
  (file-name-as-directory
   (expand-file-name
    (or directory
        (and buffer-file-name (file-name-directory buffer-file-name))
        default-directory))))

(defun fossil-ui--checkout-info (directory)
  "Return checkout metadata for DIRECTORY, or signal a user error."
  (let ((output (fossil-ui--require-success directory "info"))
        result)
    (dolist (line (split-string output "\n" t))
      (when (string-match "\\`\\([^:[:space:]]+\\):[[:space:]]*\\(.*\\)\\'" line)
        (setq result
              (plist-put result
                         (intern (concat ":" (match-string 1 line)))
                         (string-trim (match-string 2 line))))))
    (unless (plist-get result :local-root)
      (user-error "%s is not inside an open Fossil checkout" directory))
    (plist-put result :root
               (file-name-as-directory (plist-get result :local-root)))))

(defun fossil-ui--json-command (root &rest args)
  "Run Fossil JSON command ARGS at ROOT and return its payload."
  (let* ((output (apply #'fossil-ui--require-success root "json" args))
         (data (condition-case err
                   (json-parse-string output
                                      :object-type 'alist
                                      :array-type 'list
                                      :null-object nil
                                      :false-object nil)
                 (error
                  (user-error "Invalid Fossil JSON: %s"
                              (error-message-string err))))))
    (or (alist-get 'payload data)
        (user-error "Fossil JSON response has no payload"))))

(defun fossil-ui--parse-change-line (line)
  "Parse one Fossil changes LINE into a plist."
  (when (string-match "\\`\\([A-Z_]+\\)[[:space:]]+\\(.*\\)\\'" line)
    (let* ((status (match-string 1 line))
           (raw (match-string 2 line))
           (parts (condition-case nil
                      (split-string-and-unquote raw)
                    (error (list raw))))
           (path (mapconcat #'identity parts " ")))
      (list :status status :path path))))

(defun fossil-ui--changes (root)
  "Return changed and unmanaged files below ROOT."
  (let ((output (fossil-ui--require-success
                 root "changes" "--hash" "--classify" "--differ" "--rel-paths")))
    (delq nil (mapcar #'fossil-ui--parse-change-line
                      (split-string output "\n" t)))))

(defun fossil-ui--parse-numstat-line (line)
  "Parse one Fossil diff --numstat LINE into a plist.
Paths may contain spaces.  A dash in either count denotes binary data."
  (when (and
         (string-match
          "\\`[\t ]*\\([0-9]+\\|-\\)[\t ]+\\([0-9]+\\|-\\)[\t ]+\\(.*\\)\\'"
          line)
         (not (string-prefix-p "TOTAL " (match-string 3 line))))
    (let ((insertions (match-string 1 line))
          (deletions (match-string 2 line))
          (path (match-string 3 line)))
      (list :path (string-remove-prefix "./" path)
            :insertions (unless (string= insertions "-")
                          (string-to-number insertions))
            :deletions (unless (string= deletions "-")
                         (string-to-number deletions))
            :binary (or (string= insertions "-") (string= deletions "-"))))))

(defun fossil-ui--numstat (root)
  "Return a hash table of diff statistics keyed by relative path at ROOT."
  (let ((table (make-hash-table :test #'equal)))
    (pcase-let ((`(,code ,output)
                 (fossil-ui--call-in root "diff" "--numstat" "--internal")))
      (when (zerop code)
        (dolist (line (split-string output "\n" t))
          (when-let* ((stat (fossil-ui--parse-numstat-line line)))
            (puthash (plist-get stat :path) stat table)))))
    table))

(defun fossil-ui--attach-numstat (changes stats)
  "Copy CHANGES and attach matching insertion/deletion data from STATS."
  (mapcar
   (lambda (change)
     (let* ((next (copy-sequence change))
            (stat (gethash (plist-get change :path) stats)))
       (if stat
           (progn
             (setq next (plist-put next :insertions (plist-get stat :insertions)))
             (setq next (plist-put next :deletions (plist-get stat :deletions)))
             (when (plist-get stat :binary)
               (setq next (plist-put next :binary t))))
         (when (string= (plist-get change :status) "EXTRA")
           (setq next (plist-put next :extra t))))
       next))
   changes))

(defun fossil-ui--setting (root name)
  "Return Fossil setting NAME at ROOT."
  (pcase-let ((`(,code ,output) (fossil-ui--call-in root "settings")))
    (if (not (zerop code))
        "unknown"
      (if-let* ((line (cl-find-if
                       (lambda (candidate)
                         (string-match-p
                          (format "\\`%s\\(?:[[:space:]]\\|\\'\\)"
                                  (regexp-quote name))
                          candidate))
                       (split-string output "\n" t)))
                (parts (split-string line)))
          (or (nth 2 parts) "on")
        "unknown"))))

(defun fossil-ui--remote (root)
  "Return the default Fossil remote at ROOT."
  (pcase-let ((`(,code ,output) (fossil-ui--call-in root "remote" "list")))
    (if (or (not (zerop code)) (string-empty-p output))
        nil
      (let ((line (car (split-string output "\n" t))))
        (if (string-match "^[[:space:]]*\\([^[:space:]]+\\)[[:space:]]+\\(.*\\)$" line)
            (match-string 2 line)
          line)))))

(defun fossil-ui--timeline (root)
  "Return recent check-ins at ROOT."
  (let* ((payload (fossil-ui--json-command
                   root "timeline" "checkin"
                   "--limit" (number-to-string fossil-ui-timeline-limit)))
         (entries (alist-get 'timeline payload)))
    (or entries nil)))

(defun fossil-ui--branches (root)
  "Return open branch names at ROOT."
  (let* ((payload (fossil-ui--json-command root "branch" "list"))
         (branches (alist-get 'branches payload)))
    (sort (copy-sequence (or branches nil)) #'string-lessp)))

(defun fossil-ui--checkout-snapshot (directory &optional selected)
  "Collect dashboard state for DIRECTORY, retaining SELECTED paths."
  (let* ((info (fossil-ui--checkout-info directory))
         (root (plist-get info :root))
         (changes
          (fossil-ui--attach-numstat
           (fossil-ui--changes root) (fossil-ui--numstat root)))
         (paths (mapcar (lambda (change)
                          (plist-get change :path)) changes)))
    (list :root root
          :repository (plist-get info :repository)
          :checkout (plist-get info :checkout)
          :branch (or (plist-get info :tags)
                      "trunk")
          :user (plist-get info :user)
          :remote (fossil-ui--remote root)
          :autosync (fossil-ui--setting root "autosync")
          :changes changes
          :selected (cl-remove-if-not
                     (lambda (path)
                       (member path paths))
                     selected)
          :timeline (condition-case err
                        (fossil-ui--timeline root)
                      (error
                       (list
                        (list (cons 'comment
                                    (error-message-string err))))))
          :branches (condition-case nil (fossil-ui--branches root) (error nil))
          :height fossil-ui--window-height
          :busy nil
          :error nil)))

(defun fossil-ui--single-line (value)
  "Return VALUE as a string without native-widget line breaks."
  (replace-regexp-in-string "[\r\n]+" " " (format "%s" (or value ""))))

(defun fossil-ui--fit (value width &optional face)
  "Return VALUE truncated or padded to WIDTH, optionally using FACE."
  (let* ((width (max 0 width))
         (value (truncate-string-to-width (fossil-ui--single-line value)
                                          width nil nil "..."))
         (result (concat value
                         (make-string (max 0 (- width (string-width value))) ?\s))))
    (if face (propertize result 'face face) result)))

(defun fossil-ui--item (value &optional face)
  "Return a TextUI item for VALUE with optional FACE."
  (let ((value (fossil-ui--single-line value)))
    `(:type item :format "%v"
      :value ,(if face (propertize value 'face face) value))))

(defun fossil-ui--icons-p ()
  "Return non-nil when dashboard Nerd Font icons should be used."
  (pcase fossil-ui-use-icons
    ('auto (and (display-graphic-p) (featurep 'nerd-icons)))
    ((pred null) nil)
    (_ t)))

(defun fossil-ui--icon (kind)
  "Return a small icon for KIND, with a portable fallback."
  (let ((icons '((repository . "󰆼") (branch . "󰘬") (sync . "󰓦")
                 (edited . "󰏫") (added . "󰐕") (deleted . "󰍵")
                 (extra . "󰋗") (conflict . "󰀦") (missing . "󰅖")))
        (fallbacks '((repository . "R") (branch . "B") (sync . "S")
                     (edited . "~") (added . "+") (deleted . "-")
                     (extra . "?") (conflict . "!") (missing . "!"))))
    (or (alist-get kind (if (fossil-ui--icons-p) icons fallbacks)) "·")))

(defun fossil-ui--keycap (key label action focus-id &optional disabled)
  "Return a flat KEY LABEL control for ACTION with stable FOCUS-ID.
When DISABLED is non-nil, retain the control but render it quietly."
  (let* ((face (if disabled 'fossil-ui-faded 'default))
         (value (concat (propertize (format " %s " key)
                                    'face (if disabled 'shadow 'highlight))
                        (propertize label 'face face))))
    `(:type fossil-ui-keycap
      :value ,value
      :inactive ,disabled
      :layout (:focus-id ,focus-id)
      :action ,(lambda (&rest _)
                 (unless disabled (call-interactively action))))))

(defun fossil-ui--status-face (status)
  "Return a face for Fossil STATUS."
  (cond
   ((member status '("CONFLICT" "MISSING")) 'fossil-ui-critical)
   ((member status '("EXTRA" "ADDED" "DELETED")) 'fossil-ui-salient)
   (t 'fossil-ui-warning)))

(defun fossil-ui--status-icon (status)
  "Return an icon representing Fossil STATUS."
  (fossil-ui--icon
   (pcase status
     ("EDITED" 'edited) ("ADDED" 'added) ("DELETED" 'deleted)
     ("EXTRA" 'extra) ("CONFLICT" 'conflict) ("MISSING" 'missing)
     (_ 'edited))))

(defun fossil-ui--change-stat (change)
  "Return a compact human-readable statistic for CHANGE."
  (cond
   ((plist-get change :extra) "untracked")
   ((plist-get change :binary) "binary")
   ((or (numberp (plist-get change :insertions))
        (numberp (plist-get change :deletions)))
    (format "+%d −%d" (or (plist-get change :insertions) 0)
            (or (plist-get change :deletions) 0)))
   (t "—")))

(defun fossil-ui--change-row (change width selected &optional narrow)
  "Render CHANGE at WIDTH, using SELECTED paths.
When NARROW is non-nil return a primary row without trailing metadata."
  (let* ((status (plist-get change :status))
         (path (plist-get change :path))
         (marked (member path selected))
         (metadata (format "%s  %s" status (fossil-ui--change-stat change)))
         (meta-width (string-width metadata))
         (path-width (max 10 (- width meta-width 9)))
         (line
          (concat
           (propertize "▎" 'face (fossil-ui--status-face status))
           (if marked
               "[x] "
             "[ ] ")
           (propertize
            (concat (fossil-ui--status-icon status) " ")
            'face
            (fossil-ui--status-face status))
           (fossil-ui--fit path
                           (if narrow
                               (- width 7)
                             path-width)
                           (if marked
                               'fossil-ui-salient
                             'default))
           (unless narrow
             (propertize metadata 'face
                         (fossil-ui--status-face status))))))
    `(:type fossil-ui-row
      :value ,line
      :fossil-ui-path ,path
      :fossil-ui-status ,status
      :layout (:focus-id ,(list 'file path (equal status "STAGED")))
      :action ,(lambda (&rest _)
                 (fossil-ui-visit-file)))))

(defun fossil-ui--change-elements (change width selected)
  "Return responsive dashboard elements for CHANGE."
  (if (< width 90)
      (list (fossil-ui--change-row change width selected t)
            (fossil-ui--item
             (fossil-ui--fit
              (format "      %s  ·  %s" (plist-get change :status)
                      (fossil-ui--change-stat change)) width)
             'fossil-ui-faded))
    (list (fossil-ui--change-row change width selected))))

(defun fossil-ui--short-checkout (checkout)
  "Return a short check-in identifier from CHECKOUT."
  (if (and checkout (string-match "\\`\\([[:xdigit:]]+\\)" checkout))
      (substring (match-string 1 checkout)
                 0 (min 10 (length (match-string 1 checkout))))
    "unknown"))

(defun fossil-ui--timeline-elements (entry width)
  "Render timeline ENTRY at WIDTH as a two-line rail."
  (let* ((uuid (or (alist-get 'uuid entry)
                   ""))
         (short (substring uuid 0 (min 10 (length uuid))))
         (timestamp (alist-get 'timestamp entry))
         (date
          (if (numberp timestamp)
              (format-time-string "%b %d %H:%M" (seconds-to-time timestamp))
            "unknown time"))
         (user (or (alist-get 'user entry)
                   ""))
         (comment (or (alist-get 'comment entry)
                      ""))
         (tags (or (alist-get 'tags entry)
                   (alist-get 'branch entry)))
         (tag-text
          (cond
           ((listp tags)
            (mapconcat
             (lambda (tag)
               (format "%s" tag))
             tags ", "))
           (tags (format "%s" tags))
           (t "")))
         (author (truncate-string-to-width user 18 nil nil "…")))
    (list
     (fossil-ui--text (concat "● " comment))
     (fossil-ui--item
      (fossil-ui--fit
       (format "│  %s  %s  %s%s" short date author
               (if (string-empty-p tag-text)
                   ""
                 (concat "  ·  " tag-text)))
       width)
      'fossil-ui-faded))))

(defun fossil-ui--timeline-count ()
  "Return the number of loaded timeline rows suitable for current height."
  (let* ((height (or (plist-get textui-state :height) 32))
         (available (max fossil-ui-timeline-minimum (floor (/ (- height 14) 2)))))
    (min fossil-ui-timeline-limit (max fossil-ui-timeline-minimum available))))

(defun fossil-ui--chip (text face)
  "Return a compact status chip with TEXT and FACE."
  (propertize (format " %s " text) 'face face))

(defconst fossil-ui--wide-layout-width 115
  "Minimum width for side-by-side changes and commit panels.")

(defconst fossil-ui--metadata-minimum-width 24
  "Minimum outer width of a repository metadata card.")

(defun fossil-ui--column (children)
  "Return a tightly stacked TextUI column containing CHILDREN."
  `(:type :flex :direction :column :gap 0 :children ,children))

(defun fossil-ui--card (title children width &optional minimum grow)
  "Return a padded card named TITLE containing CHILDREN at WIDTH.
MINIMUM and GROW are parent-facing Flex sizing hints."
  `(:type :flex
    :direction :column
    :gap ,(if fossil-ui-compact-layout 0 1)
    :padding ,(if fossil-ui-compact-layout 0 1)
    :border t
    :layout (:width ,width
             :min-width ,(or minimum width)
             :grow ,(or grow 0))
    :children (,(fossil-ui--item
                 title
                 (unless (get-text-property 0 'face title)
                   'fossil-ui-strong))
               ,(fossil-ui--column children))))

(defun fossil-ui--metadata-columns (width)
  "Return the responsive metadata grid column count for WIDTH."
  (min 3 (max 1 (/ (1+ width) (1+ fossil-ui--metadata-minimum-width)))))

(defun fossil-ui--metadata-track-width (width)
  "Return a conservative equal metadata track width for WIDTH."
  (let ((columns (fossil-ui--metadata-columns width)))
    (/ (- width (1- columns)) columns)))

(defun fossil-ui--metadata-grid (width chips)
  "Return repository metadata cards for WIDTH using status CHIPS."
  (let* ((root (plist-get textui-state :root))
         (repository (plist-get textui-state :repository))
         (remote (plist-get textui-state :remote))
         (track-width (fossil-ui--metadata-track-width width))
         (inner-width (max 8 (- track-width 4)))
         (card-layout (list track-width fossil-ui--metadata-minimum-width 1)))
    `(:type :grid :columns 3
      :min-column-width ,fossil-ui--metadata-minimum-width :gap 1
      :children
      (,(apply #'fossil-ui--card
               "Repository"
               (list
                (fossil-ui--item
                 (fossil-ui--fit (abbreviate-file-name root) inner-width))
                (fossil-ui--item
                 (fossil-ui--fit (abbreviate-file-name
                                  (or repository "unknown repository"))
                                 inner-width)
                 'fossil-ui-faded)
                (fossil-ui--item " "))
               card-layout)
       ,(apply #'fossil-ui--card
               "Checkout"
               (list
                (fossil-ui--item
                 (fossil-ui--fit
                  (format "%s  %s" (fossil-ui--icon 'branch)
                          (plist-get textui-state :branch)) inner-width)
                 'fossil-ui-salient)
                (fossil-ui--item
                 (fossil-ui--fit
                  (format "commit  %s"
                          (fossil-ui--short-checkout
                           (plist-get textui-state :checkout))) inner-width)
                 'fossil-ui-faded)
                (fossil-ui--item (fossil-ui--fit chips inner-width)))
               card-layout)
       ,(apply #'fossil-ui--card
               "Synchronization"
               (list
                (fossil-ui--item
                 (fossil-ui--fit
                  (format "autosync  %s" (plist-get textui-state :autosync))
                  inner-width))
                (fossil-ui--item
                 (fossil-ui--fit
                  (format "%s  %s" (fossil-ui--icon 'sync)
                          (or remote "no remote")) inner-width)
                 (if remote 'link 'fossil-ui-faded))
                (fossil-ui--item " "))
               card-layout)))))

(defun fossil-ui--changes-panel (outer-width changes selected)
  "Return the changed-files card at OUTER-WIDTH."
  (let* ((inner-width (max 8 (- outer-width 4)))
         (title (format "Changes  %d  ·  Selected  %d"
                        (length changes) (length selected)))
         (body (if changes
                   (mapcan (lambda (change)
                             (fossil-ui--change-elements
                              change inner-width selected)) changes)
                 (list (fossil-ui--item "✓  Working checkout is clean"
                                        'success)))))
    (fossil-ui--card title body outer-width outer-width 0)))

(defun fossil-ui--commits-panel (outer-width timeline)
  "Return the recent-commits card at OUTER-WIDTH using TIMELINE."
  (let ((inner-width (max 8 (- outer-width 4))))
    (fossil-ui--card
     "Recent commits"
     (if timeline
         (mapcan (lambda (entry)
                   (fossil-ui--timeline-elements entry inner-width)) timeline)
       (list (fossil-ui--item "No commits available" 'fossil-ui-faded)))
     outer-width outer-width 0)))

(defun fossil-ui--main-panels (width changes selected timeline)
  "Return responsive work panels for WIDTH and dashboard data."
  (if (>= width fossil-ui--wide-layout-width)
      (let* ((available (1- width))
             (changes-width (floor (* available 0.64)))
             (commits-width (- available changes-width)))
        `(:type :flex :direction :row :gap 1
          :children (,(fossil-ui--changes-panel changes-width changes selected)
                     ,(fossil-ui--commits-panel commits-width timeline))))
    `(:type :flex :direction :column :gap 1
      :children (,(fossil-ui--changes-panel width changes selected)
                 ,(fossil-ui--commits-panel width timeline)))))

(defun fossil-ui--banner (title message width face)
  "Return a full-width status banner with TITLE, MESSAGE and FACE."
  (fossil-ui--card
   (propertize title 'face face)
   (list (fossil-ui--text message face))
   width width 0))

(defun fossil-ui--screen-elements (width)
  "Return dashboard elements for WIDTH."
  (let* ((root (plist-get textui-state :root))
         (changes (plist-get textui-state :changes))
         (selected (plist-get textui-state :selected))
         (busy (plist-get textui-state :busy))
         (error-text (plist-get textui-state :error))
         (remote-value (plist-get textui-state :remote))
         (project (file-name-nondirectory (directory-file-name root)))
         (timeline
          (seq-take
           (plist-get textui-state :timeline)
           (fossil-ui--timeline-count)))
         (chips
          (concat
           (fossil-ui--chip
            (if changes
                (format "%d changed" (length changes))
              "clean")
            (if changes
                'warning
              'success))
           " "
           (when selected
             (concat
              (fossil-ui--chip
               (format "%d selected" (length selected))
               'highlight)
              " "))
           (when busy
             (fossil-ui--chip (format "running: %s" busy) 'warning))
           (when error-text
             (fossil-ui--chip "error" 'error)))))
    (append
     (list
      (fossil-ui--text
       (format "%s  %s" (fossil-ui--icon 'repository) project)
       'fossil-ui-strong fossil-ui-title-alignment)
      `(:type :flex
        :direction :row
        :gap 1
        :children
        (,(fossil-ui--keycap "r" "Refresh" #'fossil-ui-refresh 'refresh)
         ,(fossil-ui--keycap "c c" "Commit" #'fossil-ui-commit 'commit)
         ,(fossil-ui--keycap "F" "Update" #'fossil-ui-update 'update)
         ,(fossil-ui--keycap "S" "Sync" #'fossil-ui-sync 'sync (not remote-value))
         ,(fossil-ui--keycap "b" "Branch" #'fossil-ui-switch-branch 'branch)))
      (fossil-ui--metadata-grid width chips))
     (when busy
       (list
        (fossil-ui--banner "Running"
                           (format "%s is running…" busy)
                           width 'fossil-ui-warning)))
     (when error-text
       (list (fossil-ui--banner "Error" error-text width 'fossil-ui-critical)))
     (list
      (fossil-ui--main-panels width changes selected timeline)
      (fossil-ui--item "P Diff preview · ? Help · q Close" 'fossil-ui-faded)))))

(defun fossil-ui--path-at-point ()
  "Return the file path anywhere on the current dashboard row."
  (or (get-text-property (point) 'fossil-ui-path)
      (save-excursion
        (goto-char (line-beginning-position))
        (let ((end (line-end-position))
              path)
          (while (and (< (point) end)
                      (not path))
            (setq path (get-text-property (point) 'fossil-ui-path))
            (unless path
              (goto-char (next-single-property-change (point) 'fossil-ui-path nil end))))
          path))))

(defun fossil-ui--status-at-point ()
  "Return the Fossil status anywhere on the current dashboard row."
  (or (get-text-property (point) 'fossil-ui-status)
      (save-excursion
        (goto-char (line-beginning-position))
        (let ((end (line-end-position))
              status)
          (while (and (< (point) end)
                      (not status))
            (setq status (get-text-property (point) 'fossil-ui-status))
            (unless status
              (goto-char (next-single-property-change (point) 'fossil-ui-status nil end))))
          status))))

(defun fossil-ui--goto-path (path)
  "Move point to PATH when it is visible."
  (goto-char (point-min))
  (when-let* ((match (text-property-search-forward
                      'fossil-ui-path path #'equal)))
    (goto-char (prop-match-beginning match))))

(defun fossil-ui-next-file ()
  "Move to the next changed file, wrapping at the bottom."
  (interactive)
  (let ((origin (point)))
    (goto-char (min (point-max) (1+ (line-end-position))))
    (if-let* ((match (text-property-search-forward
                      'fossil-ui-path nil nil t)))
        (goto-char (prop-match-beginning match))
      (goto-char (point-min))
      (if-let* ((first (text-property-search-forward
                        'fossil-ui-path nil nil t)))
          (goto-char (prop-match-beginning first))
        (goto-char origin)
        (message "No changed files")))))

(defun fossil-ui-previous-file ()
  "Move to the previous changed file, wrapping at the top."
  (interactive)
  (let (positions)
    (save-excursion
      (goto-char (point-min))
      (while-let ((match (text-property-search-forward
                          'fossil-ui-path nil nil t)))
        (push (prop-match-beginning match) positions)
        (goto-char (prop-match-end match))))
    (setq positions (nreverse positions))
    (if-let* ((target (or (car (last (cl-remove-if-not
                                      (lambda (position) (< position (point)))
                                      positions)))
                          (car (last positions)))))
        (goto-char target)
      (message "No changed files"))))

(defun fossil-ui--file-positions (staged)
  "Return file positions in the STAGED or unstaged section in display order."
  (save-excursion
    (goto-char (point-min))
    (let (rows seen)
      (while-let
          ((match
            (text-property-search-forward 'fossil-ui-path nil nil
                                          t)))
        (let* ((start (prop-match-beginning match))
               (path (prop-match-value match))
               (is-staged
                (equal (get-text-property start 'fossil-ui-status)
                       "STAGED")))
          (when (and (eq is-staged staged)
                     (not (member path seen)))
            (push path seen)
            (push (cons path start) rows))))
      (nreverse rows))))

(defun fossil-ui--dashboard-position ()
  "Capture the dashboard row and its position within the visible window."
  (let ((window (get-buffer-window (current-buffer))))
    (save-excursion
      (when window
        (goto-char (window-point window)))
      (let* ((path (fossil-ui--path-at-point))
             (staged (equal (fossil-ui--status-at-point) "STAGED"))
             (line (line-number-at-pos)))
        (list :path path
              :staged staged
              :index
              (and path
                   (cl-position path
                                (fossil-ui--file-positions staged)
                                :key #'car
                                :test #'equal))
              :line line
              :column (current-column)
              :window window
              :offset (and window
                           (- line
                              (line-number-at-pos (window-start window)))))))))

(defun fossil-ui--restore-dashboard-position (position)
  "Restore POSITION without following a file into another staging section."
  (let* ((rows
          (and (plist-get position :path)
               (fossil-ui--file-positions (plist-get position :staged))))
         (target
          (or (assoc (plist-get position :path) rows)
              (and rows
                   (nth
                    (min (or (plist-get position :index)
                             0)
                         (1- (length rows)))
                    rows))))
         (window (plist-get position :window)))
    (if target
        (goto-char (cdr target))
      (goto-char (point-min))
      (forward-line (1- (plist-get position :line))))
    (move-to-column (plist-get position :column))
    (when (and (window-live-p window)
               (eq (window-buffer window) (current-buffer)))
      (set-window-point window (point))
      (save-excursion
        (forward-line (- (or (plist-get position :offset)
                             0)))
        (set-window-start window (line-beginning-position) t)))))

(defun fossil-ui--preserve-dashboard-position (original buffer &rest args)
  "Keep file-list position when ORIGINAL redraws dashboard BUFFER with ARGS."
  (if (not
       (and (buffer-live-p buffer)
            (with-current-buffer buffer
              (derived-mode-p 'fossil-ui-mode))))
      (apply original buffer args)
    (with-current-buffer buffer
      (let ((position (fossil-ui--dashboard-position)))
        (prog1 (apply original buffer args)
          (fossil-ui--restore-dashboard-position position))))))

(defun fossil-ui-refresh ()
  "Refresh the current Fossil dashboard."
  (interactive)
  (when (plist-get textui-state :busy)
    (user-error "Fossil is busy: %s" (plist-get textui-state :busy)))
  (let ((selected (plist-get textui-state :selected))
        (root (plist-get textui-state :root)))
    (condition-case err
        (let ((next (fossil-ui--snapshot root selected))
              (preview-path (plist-get textui-state :preview-path)))
          (when (and preview-path
                     (cl-find preview-path
                              (plist-get next :changes)
                              :key (lambda (change)
                                     (plist-get change :path))
                              :test #'equal))
            (setq next (plist-put next :preview-path preview-path))
            (setq next (plist-put next :preview (fossil-ui--preview-data root preview-path))))
          (setq textui-state next)
          (textui-refresh (current-buffer))
          (run-hooks 'fossil-ui-post-refresh-hook))
      (error
       (textui-set-state (current-buffer) :error (error-message-string err))))))

(defun fossil-ui-diff-hl-refresh ()
  "Refresh VC state and diff-hl in file buffers belonging to this checkout."
  (when (featurep 'diff-hl)
    (let ((root (plist-get textui-state :root)))
      (when (and root
                 (not (file-remote-p root)))
        (dolist (buffer (buffer-list))
          (with-current-buffer buffer
            (when (and (bound-and-true-p diff-hl-mode)
                       buffer-file-name
                       (not (file-remote-p buffer-file-name))
                       (file-in-directory-p buffer-file-name root))
              (condition-case err
                  (progn
                    (when (and (file-exists-p buffer-file-name)
                               (not (buffer-modified-p))
                               (not
                                (verify-visited-file-modtime (current-buffer))))
                      (revert-buffer t t t))
                    (vc-file-clearprops buffer-file-name)
                    (if (file-exists-p buffer-file-name)
                        (progn
                          (when (eq (vc-backend buffer-file-name) 'Fossil)
                            (vc-state-refresh buffer-file-name 'Fossil))
                          (diff-hl-update))
                      (diff-hl-remove-overlays)))
                (error
                 (message "Fossil diff-hl (%s): %s"
                          (buffer-name)
                          (error-message-string err)))))))))))

(defun fossil-ui-toggle-mark ()
  "Toggle the commit mark on the file at point."
  (interactive)
  (let ((path (or (fossil-ui--path-at-point)
                  (user-error "No file at point")))
        (status (fossil-ui--status-at-point)))
    (when (string= status "EXTRA")
      (let ((root (plist-get textui-state :root)))
        (fossil-ui--clean-buffer (expand-file-name path root))
        (fossil-ui--require-success root "add" "--" path)
        (fossil-ui-refresh)))
    (textui-update
     (current-buffer)
     (lambda (state)
       (let* ((next (copy-sequence state))
              (selected (copy-sequence (plist-get state :selected))))
         (plist-put next
                    :selected
                    (if (member path selected)
                        (delete path selected)
                      (append selected (list path)))))))
    (fossil-ui--goto-path path)))

(defun fossil-ui-mark-all ()
  "Select all managed changes for commit."
  (interactive)
  (textui-set-state
   (current-buffer) :selected
   (mapcar (lambda (change) (plist-get change :path))
           (cl-remove-if (lambda (change)
                           (string= (plist-get change :status) "EXTRA"))
                         (plist-get textui-state :changes)))))

(defun fossil-ui-unmark-all ()
  "Clear all commit selections."
  (interactive)
  (textui-set-state (current-buffer) :selected nil))

(defun fossil-ui--show-output (title output &optional mode)
  "Show OUTPUT in a buffer named TITLE, optionally enabling MODE."
  (let ((buffer (get-buffer-create title)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert output)
        (goto-char (point-min))
        (funcall (or mode #'special-mode))))
    (pop-to-buffer buffer)
    buffer))

(defvar fossil-ui-diff-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map diff-mode-map)
    (define-key map (kbd "]c") #'diff-hunk-next)
    (define-key map (kbd "[c") #'diff-hunk-prev)
    (define-key map (kbd "TAB") #'outline-toggle-children)
    (define-key map (kbd "q") #'fossil-ui-quit)
    (define-key map (kbd "s") #'fossil-ui-stage)
    (define-key map (kbd "u") #'fossil-ui-unstage)
    (define-key map (kbd "x") #'fossil-ui-discard)
    (define-key map (kbd "r") #'fossil-ui-diff-refresh)
    (define-key map (kbd "D") #'fossil-ui-diff-toggle)
    map))

(defconst fossil-ui--diff-evil-bindings
  '(("D" . fossil-ui-diff-toggle)
    ("r" . fossil-ui-diff-refresh)
    ("x" . fossil-ui-discard)
    ("u" . fossil-ui-unstage)
    ("s" . fossil-ui-stage)
    ("]c" . diff-hunk-next)
    ("[c" . diff-hunk-prev)
    ("TAB" . outline-toggle-children)
    ("q" . fossil-ui-quit))
  "Bindings which a Fossil diff buffer owns in modal states.")

(define-derived-mode fossil-ui-diff-mode diff-mode "Fossil-Diff"
  "Mode for a Fossil working-tree diff."
  (setq-local outline-regexp "^@@ ")
  (outline-minor-mode 1)
  (setq buffer-read-only t)
  (when (fboundp 'evil-normalize-keymaps)
    (evil-normalize-keymaps)))

(defun fossil-ui--own-diff-bindings ()
  "Keep the generic Diff minor-mode bindings from shadowing Fossil commands."
  (when (fboundp 'evil-collection-diff-mode)
    (evil-collection-diff-mode -1))
  (when (fboundp 'evil-normalize-keymaps)
    (evil-normalize-keymaps)))

(add-hook 'fossil-ui-diff-mode-hook #'fossil-ui--own-diff-bindings t)

(defun fossil-ui--delta-color-argument (&optional frame)
  "Return the Delta color argument for FRAME according to `fossil-ui-delta-color-mode'."
  (pcase fossil-ui-delta-color-mode
    ('auto (if (eq (frame-parameter frame 'background-mode) 'dark)
               "--dark"
             "--light"))
    ('light "--light")
    ('dark "--dark")
    (_ (user-error "Unknown Fossil Delta color mode: %S" fossil-ui-delta-color-mode))))

(defun fossil-ui--delta-color-argument-p (argument)
  "Return non-nil when ARGUMENT explicitly controls Delta's color mode or syntax theme."
  (string-match-p "\\`--\\(?:light\\|dark\\|syntax-theme\\)\\(?:=\\|\\'\\)" argument))

(defun fossil-ui--effective-delta-arguments (&optional frame)
  "Return Delta arguments for FRAME with an automatic color mode when needed."
  (if (seq-some #'fossil-ui--delta-color-argument-p fossil-ui-delta-arguments)
      fossil-ui-delta-arguments
    (cons (fossil-ui--delta-color-argument frame) fossil-ui-delta-arguments)))

(defun fossil-ui--delta-render (diff &optional frame)
  "Render unified DIFF through Delta and return propertized Emacs text.
Return nil when Delta exits unsuccessfully."
  (with-temp-buffer
    (insert diff)
    (let ((code (condition-case nil
                    (apply #'call-process-region
                           (point-min) (point-max)
                           fossil-ui-delta-program t t nil
                           (fossil-ui--effective-delta-arguments frame))
                  (file-missing 127)
                  (error 1))))
      (when (zerop code)
        (let* ((rendered (ansi-color-apply (buffer-string)))
               (position 0)
               (limit (length rendered)))
          ;; `ansi-color-apply' uses `font-lock-face'.  Promote Delta's faces
          ;; to ordinary `face' properties so diff-mode fontification cannot
          ;; overwrite them later.
          (while (< position limit)
            (let* ((next (next-single-property-change
                          position 'font-lock-face rendered limit))
                   (face (get-text-property position 'font-lock-face rendered)))
              (when face
                (add-text-properties position next (list 'face face) rendered)
                (remove-text-properties position next '(font-lock-face nil)
                                        rendered))
              (setq position next)))
          rendered)))))

(defun fossil-ui--render-diff (diff &optional frame)
  "Render unified DIFF for FRAME according to `fossil-ui-diff-renderer'."
  (pcase fossil-ui-diff-renderer
    ('plain diff)
    ('delta
     (or (and (executable-find fossil-ui-delta-program)
              (fossil-ui--delta-render diff frame))
         (user-error "Delta could not render this diff")))
    ('auto
     (or (and (executable-find fossil-ui-delta-program)
              (fossil-ui--delta-render diff frame))
         diff))
    (_ (user-error "Unknown Fossil diff renderer: %S"
                   fossil-ui-diff-renderer))))

(defun fossil-ui--display-diff (diff &optional frame)
  "Return an actionable rendering of DIFF for FRAME."
  (let ((rendered (fossil-ui--render-diff diff frame)))
    (if (equal diff (substring-no-properties rendered))
        rendered
      diff)))

(defun fossil-ui--rerender-diff-buffer (&optional frame)
  "Rerender the current Fossil diff buffer for FRAME without querying Fossil."
  (when (and (derived-mode-p 'fossil-ui-diff-mode)
             fossil-ui-diff-context)
    (let* ((diff (plist-get fossil-ui-diff-context :diff))
           (display (fossil-ui--display-diff diff frame))
           (colored (text-property-not-all 0 (length display) 'face nil display))
           (buffer-point (point))
           (modified (buffer-modified-p))
           (windows (mapcar (lambda (window)
                              (list window (window-start window) (window-point window)))
                            (get-buffer-window-list (current-buffer) nil t))))
      (if colored
          (font-lock-mode -1)
        (font-lock-mode 1))
      (let ((inhibit-read-only t)
            (buffer-undo-list t))
        (erase-buffer)
        (insert display))
      (set-buffer-modified-p modified)
      (goto-char (min buffer-point (point-max)))
      (dolist (state windows)
        (pcase-let ((`(,window ,start ,window-point) state))
          (when (window-live-p window)
            (set-window-start window (min start (point-max)) t)
            (set-window-point window (min window-point (point-max))))))
      (unless colored
        (font-lock-ensure)))))

(defun fossil-ui--theme-enabled (_theme)
  "Rerender live Fossil diff buffers after a theme has been enabled."
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (and (derived-mode-p 'fossil-ui-diff-mode)
                 fossil-ui-diff-context)
        (let* ((window (get-buffer-window buffer t))
               (frame (and window (window-frame window))))
          (condition-case error
              (fossil-ui--rerender-diff-buffer frame)
            (error
             (message "Could not recolor %s: %s" (buffer-name buffer) (error-message-string error)))))))))

(add-hook 'enable-theme-functions #'fossil-ui--theme-enabled)

(defun fossil-ui-visit-file ()
  "Visit the file at point."
  (interactive)
  (find-file (expand-file-name
              (or (fossil-ui--path-at-point) (user-error "No file at point"))
              (plist-get textui-state :root))))

(defun fossil-ui-add ()
  "Add the unversioned file at point to Fossil."
  (interactive)
  (let ((path (or (fossil-ui--path-at-point) (user-error "No file at point"))))
    (unless (string= (fossil-ui--status-at-point) "EXTRA")
      (user-error "%s is already managed" path))
    (fossil-ui--require-success (plist-get textui-state :root) "add" "--" path)
    (fossil-ui-refresh)
    (fossil-ui--goto-path path)
    (message "Added %s" path)))

(defun fossil-ui-forget ()
  "Stop tracking the file at point without deleting it."
  (interactive)
  (let ((path (or (fossil-ui--path-at-point) (user-error "No file at point"))))
    (when (string= (fossil-ui--status-at-point) "EXTRA")
      (user-error "%s is not tracked" path))
    (when (yes-or-no-p (format "Stop tracking %s? The disk file stays. " path))
      (fossil-ui--require-success (plist-get textui-state :root) "forget" "--" path)
      (fossil-ui-refresh)
      (message "Stopped tracking %s" path))))

(defun fossil-ui-delete ()
  "Delete selected tracked files and stage their removal after confirmation."
  (interactive)
  (let* ((root (fossil-ui--root))
         (paths (fossil-ui--selected-file-paths))
         (index (fossil-ui--index root))
         (changes (fossil-ui--changes root)))
    (fossil-ui--validate-index root index)
    (dolist (path paths)
      (when (cl-find path
                     (plist-get index :entries)
                     :key
                     (lambda (e)
                       (plist-get e :path))
                     :test #'equal)
        (user-error "Unstage %s with u before deleting it" path))
      (when (equal
             (plist-get
              (cl-find path changes
                       :key
                       (lambda (c)
                         (plist-get c :path))
                       :test
                       #'equal)
              :status)
             "EXTRA")
        (user-error "Use x to delete untracked file %s" path))
      (when (file-directory-p (expand-file-name path root))
        (user-error "Select files, not directories"))
      (fossil-ui--clean-buffer (expand-file-name path root)))
    (when (yes-or-no-p
           (format "Delete from disk and stage removal: %s? "
                   (string-join paths ", ")))
      (unwind-protect
          (dolist (path paths)
            (fossil-ui--require-success root "rm" "--hard" "--" path)
            (when (cl-find-if
                   (lambda (c)
                     (and (equal (plist-get c :path) path)
                          (equal (plist-get c :status) "DELETED")))
                   (fossil-ui--changes root))
              (fossil-ui--put-entry root index
                                    (list :path path :base "" :staged ""
                                          :deleted t))
              (setq index (fossil-ui--index root))))
        (when (and (boundp 'evil-state)
                   (eq evil-state 'visual))
          (evil-exit-visual-state))
        (deactivate-mark)
        (fossil-ui-refresh)))))

(defun fossil-ui--selected-or-current ()
  "Return selected paths, or the path at point when none are selected."
  (or (copy-sequence (plist-get textui-state :selected))
      (and-let* ((path (fossil-ui--path-at-point))) (list path))
      (user-error "No files selected")))

(defun fossil-ui-revert ()
  "Revert tracked paths and delete untracked files after confirmation."
  (interactive)
  (let* ((paths (fossil-ui--selected-or-current))
         (root (plist-get textui-state :root))
         (changes (fossil-ui--changes root))
         (extras
          (seq-filter
           (lambda (path)
             (equal
              (plist-get
               (cl-find path changes
                        :key
                        (lambda (change)
                          (plist-get change :path))
                        :test
                        #'equal)
               :status)
              "EXTRA"))
           paths))
         (tracked (seq-difference paths extras #'equal)))
    (dolist (path paths)
      (fossil-ui--clean-buffer (expand-file-name path root)))
    (when (yes-or-no-p
           (if extras
               (format "Delete untracked %s%s? "
                       (string-join extras ", ")
                       (if tracked
                           (format " and revert %d tracked file(s)"
                                   (length tracked))
                         ""))
             (format "Revert %d file(s)? Fossil undo can restore this once. "
                     (length tracked))))
      (unwind-protect
          (progn
            (when tracked
              (apply #'fossil-ui--require-success root "revert" "--"
                     tracked))
            (dolist (path extras)
              (delete-file (expand-file-name path root) t))
            (message "Reverted %d tracked file(s), deleted %d untracked file(s)"
                     (length tracked)
                     (length extras)))
        (fossil-ui-refresh)))))

(defun fossil-ui-undo ()
  "Preview and run Fossil's one-level undo."
  (interactive)
  (let* ((root (plist-get textui-state :root))
         (preview (fossil-ui--require-success root "undo" "--dry-run")))
    (if (string-empty-p preview)
        (message "Fossil has nothing to undo")
      (when (yes-or-no-p (format "%s\nRun this undo? " preview))
        (fossil-ui--require-success root "undo")
        (fossil-ui-refresh)
        (message "Fossil undo completed")))))

(defun fossil-ui--async (label args &optional on-success)
  "Run Fossil ARGS asynchronously, displaying LABEL while active."
  (when (or (plist-get textui-state :busy)
            (and fossil-ui--process (process-live-p fossil-ui--process)))
    (user-error "Fossil is already busy"))
  (let* ((owner (current-buffer))
         (root (plist-get textui-state :root))
         (output-buffer (generate-new-buffer (format " *fossil-ui:%s*" label))))
    (textui-update owner
                   (lambda (state)
                     (let ((next (copy-sequence state)))
                       (setq next (plist-put next :busy label))
                       (plist-put next :error nil))))
    (let ((default-directory root))
      (setq fossil-ui--process
            (make-process
             :name (format "fossil-ui-%s" label)
             :buffer output-buffer
             :command (cons fossil-ui-program args)
             :noquery t
             :sentinel
             (lambda (process _event)
               (when (memq (process-status process) '(exit signal))
                 (let ((code (process-exit-status process))
                       (output (with-current-buffer (process-buffer process)
                                 (string-trim (buffer-string)))))
                   (when (buffer-live-p (process-buffer process))
                     (kill-buffer (process-buffer process)))
                   (when (buffer-live-p owner)
                     (with-current-buffer owner
                       (setq fossil-ui--process nil)
                       (if (zerop code)
                           (progn
                             (textui-set-state owner :busy nil)
                             (fossil-ui-refresh)
                             (when on-success (funcall on-success output))
                             (message "Fossil %s completed%s"
                                      label
                                      (if (string-empty-p output) ""
                                        (format ": %s" output))))
                         (textui-update
                          owner
                          (lambda (state)
                            (let ((next (copy-sequence state)))
                              (setq next (plist-put next :busy nil))
                              (plist-put next :error
                                         (if (string-empty-p output)
                                             (format "%s exited %d" label code)
                                           output)))))
                         (fossil-ui--show-output
                          (format "*fossil error: %s*" label)
                          (concat output "\n")))))))))))))

(defun fossil-ui--commit-marked-files (message paths)
  "Commit PATHS with MESSAGE from the current Fossil dashboard."
  (when (string-empty-p (string-trim message))
    (user-error "Commit message cannot be empty"))
  (fossil-ui--async
   "commit"
   (append (list "commit" "--hash" "--no-prompt" "--comment" message "--") paths)
   (lambda (_)
     (when (buffer-live-p (current-buffer))
       (textui-set-state (current-buffer) :selected nil)))))

(defvar fossil-ui-commit-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map text-mode-map)
    (define-key map (kbd "C-c C-c") #'fossil-ui-commit-submit)
    (define-key map (kbd "C-c C-k") #'fossil-ui-commit-cancel)
    map))

(define-derived-mode fossil-ui-commit-mode text-mode "Fossil-Commit"
  "Major mode for composing a Fossil check-in comment."
  (setq-local header-line-format
              "Write a check-in comment · C-c C-c commit · C-c C-k cancel"))

(defun fossil-ui--open-commit-buffer (paths)
  "Open or resume the commit message for PATHS below the dashboard."
  (let* ((owner (current-buffer))
         (name
          (format "*fossil commit: %s*"
                  (file-name-nondirectory
                   (directory-file-name (plist-get textui-state :root)))))
         (existing (get-buffer name))
         (buffer (get-buffer-create name))
         (window
          (or (get-buffer-window buffer)
              (split-window
               (or (get-buffer-window owner)
                   (selected-window)) nil
               'below))))
    (with-current-buffer buffer
      (unless (derived-mode-p 'fossil-ui-commit-mode)
        (fossil-ui-commit-mode))
      (setq-local default-directory
                  (buffer-local-value 'default-directory owner)
                  fossil-ui--commit-owner owner fossil-ui--commit-paths paths)
      (unless existing
        (erase-buffer)))
    (set-window-buffer window buffer)
    (select-window window)
    (when (fboundp 'evil-insert-state)
      (evil-insert-state))
    buffer))

(defun fossil-ui--close-commit-buffer (buffer owner)
  "Close commit BUFFER and its windows, returning to OWNER."
  (let ((owner-window (and (buffer-live-p owner)
                           (get-buffer-window owner))))
    (dolist (window (get-buffer-window-list buffer nil t))
      (if (one-window-p t (window-frame window))
          (when (buffer-live-p owner)
            (set-window-buffer window owner))
        (delete-window window)))
    (kill-buffer buffer)
    (when (window-live-p owner-window)
      (select-window owner-window))))

(defun fossil-ui-commit-submit ()
  "Submit the commit message, retaining the editor if submission fails."
  (interactive)
  (fossil-ui--check-message-stage)
  (let ((message
         (string-trim-right
          (buffer-substring-no-properties (point-min) (point-max))))
        (owner fossil-ui--commit-owner)
        (paths fossil-ui--commit-paths)
        (buffer (current-buffer)))
    (unless (buffer-live-p owner)
      (user-error "The Fossil dashboard was closed"))
    (when (string-empty-p (string-trim message))
      (user-error "Commit message cannot be empty"))
    (with-current-buffer owner
      (fossil-ui--commit-with-message message paths))
    (fossil-ui--close-commit-buffer buffer owner)))

(defun fossil-ui-commit-cancel ()
  "Cancel the message and close its split, retaining staged changes."
  (interactive)
  (fossil-ui--close-commit-buffer (current-buffer) fossil-ui--commit-owner)
  (message "Commit cancelled; staged changes retained"))

(defun fossil-ui-update ()
  "Update the current Fossil branch."
  (interactive)
  (fossil-ui--guard-checkout-change)
  (fossil-ui--async "update" '("update")))

(defun fossil-ui-sync ()
  "Synchronize the current Fossil repository."
  (interactive)
  (unless (plist-get textui-state :remote)
    (user-error "This repository has no configured remote"))
  (fossil-ui--async "sync" '("sync")))

(defun fossil-ui-switch-branch ()
  "Update the checkout to an existing branch."
  (interactive)
  (fossil-ui--guard-checkout-change)
  (let* ((branches
          (or (plist-get textui-state :branches)
              (user-error "No branches found")))
         (current (plist-get textui-state :branch))
         (branch (completing-read "Update to branch: " branches nil t nil nil current)))
    (unless (string= branch current)
      (when (or (null (plist-get textui-state :changes))
                (yes-or-no-p
                 (format "Update to %s and merge your local changes into it? " branch)))
        (fossil-ui--async (format "update %s" branch) (list "update" branch))))))

(defun fossil-ui--card-range ()
  "Return only the current changed-file widget span for hl-line."
  (if-let* ((path (fossil-ui--path-at-point))
            (match (save-excursion
                     (goto-char (line-beginning-position))
                     (text-property-search-forward
                      'fossil-ui-path path #'equal))))
      (cons (prop-match-beginning match) (prop-match-end match))
    (cons (point) (point))))

(defun fossil-ui--visible-height ()
  "Return the smallest body height displaying the current buffer."
  (let ((windows (get-buffer-window-list (current-buffer) nil t)))
    (when windows
      (apply #'min (mapcar #'window-body-height windows)))))

(defun fossil-ui--window-size-changed (_window)
  "Refresh timeline density when this dashboard's window height changes."
  (when (and (derived-mode-p 'fossil-ui-mode)
             (not (bound-and-true-p textui--refreshing)))
    (when-let* ((height (fossil-ui--visible-height)))
      (unless (equal height fossil-ui--window-height)
        (let ((path (fossil-ui--path-at-point)))
          (setq fossil-ui--window-height height)
          (textui-set-state (current-buffer) :height height)
          (when path (fossil-ui--goto-path path)))))))

(defvar fossil-ui-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map textui-mode-map)
    (define-key map (kbd "SPC") #'fossil-ui-toggle-mark)
    (define-key map (kbd "A") #'fossil-ui-mark-all)
    (define-key map (kbd "X") #'fossil-ui-unmark-all)
    (define-key map (kbd "RET") #'fossil-ui-visit-file)
    (define-key map (kbd "<return>") #'fossil-ui-visit-file)
    (define-key map (kbd "P") #'fossil-ui-toggle-preview)
    (define-key map (kbd "o") #'fossil-ui-visit-file)
    (define-key map (kbd "a") #'fossil-ui-add)
    (define-key map (kbd "f") #'fossil-ui-forget)
    (define-key map (kbd "r") #'fossil-ui-refresh)
    (define-key map (kbd "U") #'fossil-ui-undo)
    (define-key map (kbd "c c") #'fossil-ui-commit)
    (define-key map (kbd "u") #'fossil-ui-unstage)
    (define-key map (kbd "s") #'fossil-ui-stage)
    (define-key map (kbd "b") #'fossil-ui-switch-branch)
    (define-key map (kbd "?") #'fossil-ui-help)
    (define-key map (kbd "j") #'fossil-ui-next-file)
    (define-key map (kbd "n") #'fossil-ui-next-file)
    (define-key map (kbd "k") #'fossil-ui-previous-file)
    (define-key map (kbd "p") #'fossil-ui-previous-file)
    (define-key map (kbd "q") #'fossil-ui-quit)
    (define-key map (kbd "x") #'fossil-ui-discard)
    (define-key map (kbd "TAB") #'fossil-ui-diff)
    (define-key map (kbd "<tab>") #'fossil-ui-diff)
    (define-key map (kbd "S") #'fossil-ui-sync)
    (define-key map (kbd "F") #'fossil-ui-update)
    (define-key map (kbd "D") #'fossil-ui-staged-diff)
    map))

(define-derived-mode fossil-ui-mode textui-mode "Fossil"
  "Major mode for the compact Fossil dashboard."
  (setq-local truncate-lines t
              cursor-type nil
              mode-line-format ""
              hl-line-range-function #'fossil-ui--card-range)
  (face-remap-set-base 'hl-line 'fossil-ui-selected)
  (hl-line-mode 1)
  (add-hook 'window-size-change-functions #'fossil-ui--window-size-changed nil t)
  (when (fboundp 'evil-normalize-keymaps)
    (evil-normalize-keymaps)))

(defconst fossil-ui--evil-bindings
  '(("D" . fossil-ui-staged-diff)
    ("F" . fossil-ui-update)
    ("S" . fossil-ui-sync)
    ("TAB" . fossil-ui-diff)
    ("<tab>" . fossil-ui-diff)
    ("x" . fossil-ui-discard)
    ("SPC" . fossil-ui-toggle-mark)
    ("A" . fossil-ui-mark-all)
    ("X" . fossil-ui-unmark-all)
    ("RET" . fossil-ui-visit-file)
    ("<return>" . fossil-ui-visit-file)
    ("P" . fossil-ui-toggle-preview)
    ("o" . fossil-ui-visit-file)
    ("a" . fossil-ui-add)
    ("f" . fossil-ui-forget)
    ("r" . fossil-ui-refresh)
    ("U" . fossil-ui-undo)
    ("c c" . fossil-ui-commit)
    ("u" . fossil-ui-unstage)
    ("s" . fossil-ui-stage)
    ("b" . fossil-ui-switch-branch)
    ("?" . fossil-ui-help)
    ("j" . fossil-ui-next-file)
    ("n" . fossil-ui-next-file)
    ("k" . fossil-ui-previous-file)
    ("p" . fossil-ui-previous-file)
    ("q" . fossil-ui-quit))
  "Bindings which the Fossil dashboard owns in modal states.")

(defun fossil-ui--install-evil-bindings ()
  "Give Fossil maps precedence over global Evil bindings."
  (evil-set-initial-state 'fossil-ui-mode 'normal)
  (evil-set-initial-state 'fossil-ui-diff-mode 'normal)
  (evil-make-overriding-map fossil-ui-mode-map 'all)
  (dolist (binding fossil-ui--evil-bindings)
    (evil-define-key* '(normal motion visual) fossil-ui-mode-map
                      (kbd (car binding))
                      (cdr binding)))
  (evil-make-overriding-map fossil-ui-diff-mode-map 'all)
  (dolist (binding fossil-ui--diff-evil-bindings)
    (evil-define-key* '(normal motion visual) fossil-ui-diff-mode-map
                      (kbd (car binding))
                      (cdr binding)))
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'fossil-ui-mode 'fossil-ui-diff-mode)
        (evil-normalize-keymaps)))))

(with-eval-after-load 'evil
  (fossil-ui--install-evil-bindings))

;;;###autoload
(defun fossil-ui--open-dashboard (&optional directory)
  "Open a Fossil dashboard for DIRECTORY or the current checkout."
  (interactive)
  (let* ((start (fossil-ui--input-directory directory))
         (snapshot (fossil-ui--snapshot start))
         (root (plist-get snapshot :root))
         (name
          (format "*fossil: %s*"
                  (file-name-nondirectory (directory-file-name root))))
         (existing (get-buffer name)))
    (when (and existing
               (with-current-buffer existing
                 (not (derived-mode-p 'fossil-ui-mode))))
      (user-error "A non-Fossil buffer already uses %s" name))
    (let ((buffer (or existing
                      (get-buffer-create name))))
      (with-current-buffer buffer
        (unless (derived-mode-p 'fossil-ui-mode)
          (fossil-ui-mode))
        (setq-local default-directory root))
      (textui-open name #'fossil-ui--frame snapshot)
      (with-current-buffer buffer
        (when-let* ((height (fossil-ui--visible-height)))
          (setq fossil-ui--window-height height)
          (textui-set-state buffer :height height))
        (fossil-ui-next-file))
      buffer)))

(defvar evil-visual-selection)

(defun fossil-ui--directory (root)
  "Return ROOT's private staging directory."
  (expand-file-name (secure-hash 'sha256 (file-truename root)) fossil-ui-stage-directory))

(defun fossil-ui--save (file data)
  "Atomically save DATA to private FILE."
  (make-directory (file-name-directory file) t)
  (set-file-modes (file-name-directory file) #o700)
  (let ((temporary (make-temp-file (concat file "."))))
    (unwind-protect
        (progn
          (with-temp-file temporary
            (let ((print-length nil)
                  (print-level nil))
              (prin1 data (current-buffer))))
          (set-file-modes temporary #o600)
          (rename-file temporary file t))
      (when (file-exists-p temporary)
        (delete-file temporary)))))

(defun fossil-ui--read (file)
  "Read saved data from FILE, if it exists."
  (when (file-exists-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (read (current-buffer)))))

(defun fossil-ui--revision (root)
  "Return ROOT's exact checkout revision."
  (car (split-string (plist-get (fossil-ui--checkout-info root) :checkout))))

(defun fossil-ui--index (root)
  "Read ROOT's index, refusing an outstanding commit recovery."
  (let ((directory (fossil-ui--directory root)))
    (when (file-exists-p (expand-file-name "transaction.eld" directory))
      (user-error "Interrupted partial commit: run M-x fossil-ui-recover in this checkout"))
    (let ((index (fossil-ui--read (expand-file-name "index.eld" directory))))
      (if (plist-get index :entries)
          index
        (list :root root :revision (fossil-ui--revision root) :entries nil)))))

(defun fossil-ui--ensure-idle (root)
  "Refuse writes while a dashboard is running a Fossil operation in ROOT."
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (and (derived-mode-p 'fossil-ui-mode)
                 (equal (plist-get textui-state :root) root)
                 (or (plist-get textui-state :busy)
                     (and fossil-ui--process
                          (process-live-p fossil-ui--process))))
        (user-error "Fossil is busy; wait for the current operation")))))

(defun fossil-ui--validate-index (root index)
  "Refuse INDEX if ROOT's base revision changed."
  (fossil-ui--ensure-idle root)
  (unless (equal (plist-get index :revision) (fossil-ui--revision root))
    (user-error "Checkout changed since staging; inspect staged changes, then clear staging with M-x fossil-ui-clear-stage")))

(defun fossil-ui--save-index (root index)
  "Persist INDEX for ROOT."
  (fossil-ui--save (expand-file-name "index.eld" (fossil-ui--directory root)) index))

(defun fossil-ui--text-file (file)
  "Read regular UTF-8 FILE exactly, preserving its line endings."
  (unless (and (file-regular-p file)
               (not (file-symlink-p file)))
    (user-error "Partial staging requires a regular file: %s" file))
  (when (> (file-attribute-size (file-attributes file)) fossil-ui-max-stage-bytes)
    (user-error "File exceeds fossil-ui-max-stage-bytes: %s" file))
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (insert-file-contents-literally file)
    (let* ((bytes (buffer-string))
           (text (decode-coding-string bytes 'utf-8-unix)))
      (when (or (string-search (string 0) bytes)
                (not (equal bytes (encode-coding-string text 'utf-8-unix))))
        (user-error "Partial staging requires UTF-8 text: %s" file))
      text)))

(defun fossil-ui--write-text (file text)
  "Write TEXT to FILE preserving UTF-8 bytes and line endings."
  (let ((coding-system-for-write 'utf-8-unix))
    (write-region text nil file nil 'silent)))

(defun fossil-ui--clean-buffer (file)
  "Protect unsaved edits and synchronize an unchanged visiting buffer for FILE."
  (when-let* ((buffer (find-buffer-visiting file)))
    (with-current-buffer buffer
      (when (buffer-modified-p)
        (user-error "Save the modified file buffer first: %s" file))
      (when (and (file-exists-p file)
                 (not (verify-visited-file-modtime buffer)))
        (revert-buffer t t t)))))

(defun fossil-ui--base (root path)
  "Read exact committed text for PATH, or empty text for an added file."
  (let* ((change
          (cl-find path
                   (fossil-ui--changes root)
                   :key (lambda (c)
                          (plist-get c :path))
                   :test #'equal))
         (status (plist-get change :status)))
    (if (or (member status '("ADDED" "EXTRA"))
            (and (equal status "MISSING")
                 (string-empty-p
                  (fossil-ui--require-success root "ls" "-r" "current" "--"
                                              path))))
        ""
      (with-temp-buffer
        (let ((default-directory root)
              (coding-system-for-read 'utf-8-unix))
          (unless (zerop (process-file fossil-ui-program nil t nil "cat" "-r" "current" "--" path))
            (user-error "Cannot read baseline for %s" path)))
        (buffer-string)))))

(defun fossil-ui--entry (root path index)
  "Return PATH's saved entry or its baseline in ROOT and INDEX."
  (or (cl-find path
               (plist-get index :entries)
               :key (lambda (e)
                      (plist-get e :path))
               :test #'equal)
      (let ((base (fossil-ui--base root path)))
        (list :path path :base base :staged base))))

(defun fossil-ui--put-entry (root index entry)
  "Save ENTRY in INDEX for ROOT, dropping empty selections."
  (let* ((path (plist-get entry :path))
         (others
          (cl-remove path
                     (plist-get index :entries)
                     :key (lambda (e)
                            (plist-get e :path))
                     :test #'equal)))
    (unless (and (not (plist-get entry :deleted))
                 (equal (plist-get entry :base) (plist-get entry :staged)))
      (fossil-ui--validate-index root index)
      (when (cl-find-if
             (lambda (change)
               (and (equal (plist-get change :path) path)
                    (equal (plist-get change :status)
                           "EXTRA")))
             (fossil-ui--changes root))
        (fossil-ui--require-success root "add" "--" path))
      (push entry others))
    (fossil-ui--save-index root (plist-put index :entries others))))

(defun fossil-ui--diff (path left right)
  "Return a unified diff from LEFT to RIGHT labeled with PATH."
  (let ((a (make-temp-file "fossil-left-"))
        (b (make-temp-file "fossil-right-")))
    (unwind-protect
        (progn
          (fossil-ui--write-text a left)
          (fossil-ui--write-text b right)
          (with-temp-buffer
            (let ((coding-system-for-read 'utf-8-unix))
              (unless (memq (process-file "diff" nil t nil "-U3" "--label" path "--label" path a b) '(0 1))
                (error "Cannot compute staging diff")))
            (buffer-string)))
      (delete-file a)
      (delete-file b))))

(defun fossil-ui--hunks (diff)
  "Parse DIFF into hunks with source positions and exact line records."
  (with-temp-buffer
    (insert diff)
    (goto-char (point-min))
    (let (hunks)
      (while (re-search-forward "^@@ -\\([0-9]+\\)\\(?:,\\([0-9]+\\)\\)? +\\+\\([0-9]+\\)\\(?:,\\([0-9]+\\)\\)? @@.*$" nil t)
        (let ((hunk
               (list :begin (line-beginning-position)
                     :old (string-to-number (match-string 1))
                     :old-count (if (match-string 2)
                                    (string-to-number (match-string 2))
                                  1)
                     :new (string-to-number (match-string 3))
                     :new-count (if (match-string 4)
                                    (string-to-number (match-string 4))
                                  1)))
              lines)
          (forward-line 1)
          (while (and (not (eobp))
                      (memq (char-after) '(?\s ?+ ?- ?\\)))
            (if (eq (char-after) ?\\)
                (when lines
                  (setf (plist-get (car lines) :text) (string-remove-suffix "\n" (plist-get (car lines) :text))))
              (push
               (list :begin (point)
                     :end (min (point-max) (1+ (line-end-position)))
                     :kind (char-after)
                     :text (buffer-substring-no-properties (1+ (point)) (min (point-max) (1+ (line-end-position)))))
               lines))
            (forward-line 1))
          (push (append hunk (list :end (point) :lines (nreverse lines))) hunks)))
      (nreverse hunks))))

(defun fossil-ui--apply-selection (source diff begin end reverse)
  "Apply selected changed lines of DIFF to SOURCE; REVERSE discards or unstages. BEGIN and END are positions in the unmodified diff string; nil selects the entire diff."
  (let ((hunks (fossil-ui--hunks diff))
        (changed nil))
    (with-temp-buffer
      (insert source)
      (dolist (hunk (reverse hunks))
        (let (before after selected)
          (dolist (line (plist-get hunk :lines))
            (let* ((kind (plist-get line :kind))
                   (text (plist-get line :text))
                   (choose
                    (and (memq kind '(?+ ?-))
                         (or (not begin)
                             (and (< (plist-get line :begin) end)
                                  (> (plist-get line :end) begin)))))
                   (remove (if reverse
                               ?+
                             ?-))
                   (add (if reverse
                            ?-
                          ?+)))
              (when choose
                (setq selected t changed t))
              (when (memq kind (list ?\s remove))
                (push text before))
              (when (or (eq kind ?\s)
                        (and (eq kind remove)
                             (not choose))
                        (and (eq kind add)
                             choose))
                (push text after))))
          (when selected
            (let* ((line
                    (plist-get hunk
                               (if reverse
                                   :new
                                 :old)))
                   (count
                    (plist-get hunk
                               (if reverse
                                   :new-count
                                 :old-count)))
                   (old (apply #'concat (nreverse before)))
                   (new (apply #'concat (nreverse after))))
              (goto-char (point-min))
              (forward-line
               (if (zerop count)
                   line
                 (max 0 (1- line))))
              (unless (and (<= (+ (point) (length old)) (point-max))
                           (equal old (buffer-substring-no-properties (point) (+ (point) (length old)))))
                (user-error "Diff no longer matches; refresh before changing it"))
              (delete-region (point) (+ (point) (length old)))
              (insert new)))))
      (unless changed
        (user-error "Select added or removed lines, or place point inside a hunk"))
      (buffer-string))))

(defun fossil-ui--root ()
  "Return the current dashboard or diff root."
  (or (plist-get fossil-ui-diff-context :root)
      (plist-get textui-state :root)
      (user-error "Not a Fossil working buffer")))

(defun fossil-ui--bounds ()
  "Return the visual/active line selection or the hunk at point."
  (when (and (boundp 'evil-state)
             (eq evil-state 'visual)
             (eq evil-visual-selection 'block))
    (user-error "Use v or V for staging lines; rectangular selections are not supported"))
  (cond
   ((and (boundp 'evil-state)
         (eq evil-state 'visual)
         (fboundp 'evil-visual-range))
    (let ((range (evil-visual-range)))
      (cons (nth 0 range) (nth 1 range))))
   ((use-region-p)
    (cons (region-beginning) (region-end)))
   (t
    (let ((hunk
           (cl-find-if
            (lambda (h)
              (and (<= (plist-get h :begin) (point))
                   (< (point) (plist-get h :end))))
            (fossil-ui--hunks (plist-get fossil-ui-diff-context :diff)))))
      (unless hunk
        (user-error "Place point in a hunk"))
      (cons (plist-get hunk :begin) (plist-get hunk :end))))))

(defun fossil-ui--show-diff (root path &optional staged owner)
  "Show PATH in ROOT as an actionable staged or unstaged diff owned by OWNER."
  (let* ((previous-line
          (when (and fossil-ui-diff-context
                     (equal path
                            (plist-get fossil-ui-diff-context
                                       :path)))
            (line-number-at-pos)))
         (index (fossil-ui--index root))
         (entry (fossil-ui--entry root path index))
         (_
          (when (or (plist-get entry :deleted)
                    (cl-find-if
                     (lambda (c)
                       (and (equal (plist-get c :path) path)
                            (equal (plist-get c :status) "DELETED")))
                     (fossil-ui--changes root)))
            (user-error "File removal is a whole-file change; use s/u in the dashboard")))
         (work
          (if (file-exists-p (expand-file-name path root))
              (fossil-ui--text-file (expand-file-name path root))
            ""))
         (left
          (plist-get entry
                     (if staged
                         :base
                       :staged)))
         (right (if staged
                    (plist-get entry :staged)
                  work))
         (diff (fossil-ui--diff path left right))
         (display (fossil-ui--display-diff diff))
         (buffer
          (get-buffer-create
           (format "*fossil %s: %s/%s*"
                   (if staged
                       "staged"
                     "unstaged")
                   (file-name-nondirectory (directory-file-name root)) path))))
    (with-current-buffer buffer
      (fossil-ui-diff-mode)
      (when (text-property-not-all 0 (length display) 'face nil display)
        (font-lock-mode -1))
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert display))
      (setq-local default-directory root
                  fossil-ui-diff-context
                  (list :root root
                        :path path
                        :staged staged
                        :work work
                        :left left
                        :right right
                        :diff diff
                        :owner owner)
                  header-line-format
                  (format "%s · %s · s stage · u unstage · x discard · v/V select lines · D switch staged/unstaged · r refresh"
                          (if staged
                              "Staged"
                            "Unstaged")
                          path))
      (goto-char (point-min))
      (when previous-line
        (forward-line (1- previous-line)))
      (unless (cl-some
               (lambda (hunk)
                 (and (<= (plist-get hunk :begin) (point))
                      (< (point) (plist-get hunk :end))))
               (fossil-ui--hunks diff))
        (goto-char (point-min))
        (re-search-forward "^@@" nil t)
        (beginning-of-line)))
    (let* ((owner-window (and (buffer-live-p owner)
                              (get-buffer-window owner)))
           (existing
            (cl-find-if
             (lambda (window)
               (and owner
                    (eq (window-parameter window 'fossil-ui-diff-owner)
                        owner)
                    (with-current-buffer
                        (window-buffer window)
                      (derived-mode-p
                       'fossil-ui-diff-mode))))
             (window-list)))
           (window
            (or existing
                (and owner-window
                     (split-window owner-window nil 'right))
                (selected-window))))
      (set-window-buffer window buffer)
      (when owner-window
        (set-window-parameter window 'fossil-ui-diff-owner
                              owner))
      (select-window window))
    buffer))

(defun fossil-ui-diff (&optional staged)
  "Open the file at point; prefix STAGED shows the selection to commit."
  (interactive "P")
  (let ((path
         (or (fossil-ui--path-at-point)
             (plist-get textui-state :preview-path)
             (user-error "No file at point"))))
    (fossil-ui--show-diff
     (fossil-ui--root) path
     (or staged
         (equal (fossil-ui--status-at-point) "STAGED"))
     (current-buffer))))

(defun fossil-ui-diff-refresh (&optional toggle)
  "Refresh this diff; TOGGLE switches between staged and unstaged."
  (interactive)
  (let ((context fossil-ui-diff-context))
    (fossil-ui--show-diff
     (plist-get context :root)
     (plist-get context :path)
     (if toggle
         (not (plist-get context :staged))
       (plist-get context :staged))
     (plist-get context :owner))))

(defun fossil-ui-diff-toggle ()
  "Switch between staged and unstaged changes."
  (interactive)
  (fossil-ui-diff-refresh t))

(defun fossil-ui--refresh-owner (owner)
  "Refresh dashboard OWNER if it still exists."
  (when (buffer-live-p owner)
    (with-current-buffer owner
      (fossil-ui-refresh))))

(defun fossil-ui--change-selection (action)
  "Perform stage, unstage or discard ACTION in an actionable diff."
  (unless fossil-ui-diff-context
    (user-error "Open an actionable file diff with TAB first"))
  (let* ((context fossil-ui-diff-context)
         (root (plist-get context :root))
         (path (plist-get context :path))
         (file (expand-file-name path root))
         (index (fossil-ui--index root))
         (entry (copy-sequence (fossil-ui--entry root path index)))
         (staged (plist-get context :staged))
         (bounds (fossil-ui--bounds))
         (diff (plist-get context :diff)))
    (fossil-ui--validate-index root index)
    (fossil-ui--clean-buffer file)
    (unless (and (equal (plist-get context :work) (fossil-ui--text-file file))
                 (equal
                  (plist-get entry
                             (if staged
                                 :base
                               :staged))
                  (plist-get context :left))
                 (or (not staged)
                     (equal (plist-get entry :staged) (plist-get context :right))))
      (user-error "File or staging changed; press r to refresh"))
    (when (or (and (eq action 'stage)
                   staged)
              (and (eq action 'unstage)
                   (not staged)))
      (user-error "Press D to switch to %s changes first"
                  (if staged
                      "unstaged"
                    "staged")))
    (when (and staged
               (eq action 'discard))
      (user-error "Unstage with u first, then discard in the unstaged diff"))
    (let ((result
           (fossil-ui--apply-selection
            (plist-get context
                       (if (eq action 'stage)
                           :left
                         :right))
            diff
            (car bounds)
            (cdr bounds)
            (not (eq action 'stage)))))
      (if (eq action 'discard)
          (when (or (not fossil-ui-confirm-revert)
                    (yes-or-no-p (format "Discard selected working changes in %s? " path)))
            (let ((buffer (find-file-noselect file)))
              (with-current-buffer buffer
                (undo-boundary)
                (atomic-change-group
                  (erase-buffer)
                  (insert (decode-coding-string (encode-coding-string result 'utf-8-unix) buffer-file-coding-system)))
                (fossil-ui--write-text file result)
                (set-visited-file-modtime)
                (set-buffer-modified-p nil)
                (undo-boundary))))
        (fossil-ui--put-entry root index (plist-put entry :staged result))))
    (when (and (fboundp 'evil-exit-visual-state)
               (boundp 'evil-state)
               (eq evil-state 'visual))
      (evil-exit-visual-state))
    (deactivate-mark)
    (fossil-ui--refresh-owner (plist-get context :owner))
    (fossil-ui-diff-refresh)
    (when (and (eq action 'stage)
               (string-empty-p (plist-get fossil-ui-diff-context :diff)))
      (fossil-ui-quit))))

(defun fossil-ui--selected-file-paths ()
  "Return unique file paths in the visual region or at point."
  (let ((range
         (cond
          ((and (boundp 'evil-state)
                (eq evil-state 'visual))
           (when (eq evil-visual-selection 'block)
             (user-error "Use V to select file rows"))
           (evil-visual-range))
          ((use-region-p)
           (list (region-beginning) (region-end))))))
    (if (not range)
        (list (or (fossil-ui--path-at-point)
                  (user-error "No file at point")))
      (let ((pos (car range))
            (end (cadr range))
            paths)
        (while (< pos end)
          (when-let* ((path (get-text-property pos 'fossil-ui-path)))
            (unless (member path paths)
              (push path paths)))
          (setq pos (next-single-property-change pos 'fossil-ui-path nil end)))
        (or (nreverse paths)
            (user-error "No files in selection"))))))

(defun fossil-ui--change-files (stage)
  "Stage selected files when STAGE is non-nil; otherwise unstage them."
  (let* ((root (fossil-ui--root))
         (paths (fossil-ui--selected-file-paths))
         (index (fossil-ui--index root))
         (changes (fossil-ui--changes root))
         (entries
          (mapcar
           (lambda (path)
             (let* ((file (expand-file-name path root))
                    (deleted
                     (equal
                      (plist-get
                       (cl-find path changes
                                :key
                                (lambda (c)
                                  (plist-get c :path))
                                :test #'equal)
                       :status)
                      "DELETED"))
                    (entry
                     (if deleted
                         (list :path path :base "" :staged "")
                       (copy-sequence
                        (fossil-ui--entry root path
                                          index)))))
               (when stage
                 (fossil-ui--clean-buffer file))
               (if deleted
                   (plist-put entry :deleted stage)
                 (plist-put entry
                            :staged
                            (if stage
                                (fossil-ui--text-file file)
                              (plist-get entry :base))))))
           paths)))
    (fossil-ui--validate-index root index)
    (dolist (entry entries)
      (fossil-ui--put-entry root index entry)
      (setq index (fossil-ui--index root)))
    (when (and (boundp 'evil-state)
               (eq evil-state 'visual))
      (evil-exit-visual-state))
    (deactivate-mark)
    (fossil-ui-refresh)))

(defun fossil-ui-stage ()
  "Stage selected file rows, or selected hunks and lines in a diff."
  (interactive)
  (if fossil-ui-diff-context
      (fossil-ui--change-selection 'stage)
    (fossil-ui--change-files t)))

(defun fossil-ui-unstage ()
  "Unstage selected file rows, or selected hunks and lines in a diff."
  (interactive)
  (if fossil-ui-diff-context
      (fossil-ui--change-selection 'unstage)
    (fossil-ui--change-files nil)))

(defun fossil-ui-discard ()
  "Discard the hunk/visual lines, or unstaged dashboard files after confirmation."
  (interactive)
  (fossil-ui--ensure-idle (fossil-ui--root))
  (cond
   (fossil-ui-diff-context (fossil-ui--change-selection 'discard))
   ((equal (fossil-ui--status-at-point) "STAGED")
    (user-error "Unstage with u before discarding"))
   (t (fossil-ui-revert))))

(defun fossil-ui-clear-stage ()
  "Clear this checkout's staging snapshots after confirmation."
  (interactive)
  (let ((root (fossil-ui--root)))
    (when (yes-or-no-p "Clear all staged selections? Working files stay unchanged. ")
      (let ((index (fossil-ui--index root)))
        (fossil-ui--save-index root
                               (plist-put (plist-put index :revision (fossil-ui--revision root)) :entries nil)))
      (when (derived-mode-p 'fossil-ui-mode)
        (fossil-ui-refresh)))))

(defun fossil-ui--restore-transaction (root transaction)
  "Restore working files from TRANSACTION in ROOT without overwriting intervening edits."
  (dolist (item (plist-get transaction :files))
    (let* ((file (expand-file-name (plist-get item :path) root))
           (original (fossil-ui--text-file (plist-get item :backup)))
           (current (fossil-ui--text-file file)))
      (unless (or (equal current original)
                  (equal current (plist-get item :staged)))
        (user-error "File changed during commit: %s; recovery copies retained in %s" file
                    (fossil-ui--directory root)))
      (unless (equal current original)
        (copy-file (plist-get item :backup) file t t t)
        (set-file-modes file (plist-get item :mode)))
      (when-let* ((buffer (find-buffer-visiting file)))
        (with-current-buffer buffer
          (set-visited-file-modtime)))))
  (let ((revision (fossil-ui--revision root)))
    (unless (equal revision (plist-get transaction :revision))
      (fossil-ui--save-index root (list :root root :revision revision :entries nil))))
  (delete-file (expand-file-name "transaction.eld" (fossil-ui--directory root)))
  (dolist (item (plist-get transaction :files))
    (delete-file (plist-get item :backup))))

(defun fossil-ui-recover ()
  "Restore working files after an interrupted partial commit, retaining ambiguous edits."
  (interactive)
  (let* ((root
          (or (ignore-errors (fossil-ui--root))
              (plist-get (fossil-ui--checkout-info default-directory) :root)))
         (transaction (fossil-ui--read (expand-file-name "transaction.eld" (fossil-ui--directory root)))))
    (unless transaction
      (user-error "No interrupted partial commit for this checkout"))
    (fossil-ui--restore-transaction root transaction)
    (message "Working files restored; inspect Fossil status before committing again")))

(defun fossil-ui--commit-staged (root message)
  "Commit ROOT's staged snapshots with MESSAGE and restore all remaining edits."
  (let* ((index (fossil-ui--index root))
         (entries (plist-get index :entries))
         (directory (fossil-ui--directory root))
         (transaction-file (expand-file-name "transaction.eld" directory))
         (transaction (list :revision (fossil-ui--revision root) :files nil))
         (inhibit-quit t))
    (fossil-ui--validate-index root index)
    (unless entries
      (user-error "Nothing staged; use s first"))
    (when (string-empty-p (string-trim message))
      (user-error "Commit message cannot be empty"))
    (when (string-match-p "^\\(?:MERGED\\|CONFLICT\\)"
                          (fossil-ui--require-success root "changes" "--classify"))
      (user-error "Resolve/commit the pending merge before partial commits"))
    (make-directory directory t)
    ;; Prepare every durable backup before touching any working file.
    (dolist (entry entries)
      (when (plist-get entry :deleted)
        (fossil-ui--clean-buffer
         (expand-file-name (plist-get entry :path) root))
        (when (or (file-exists-p
                   (expand-file-name (plist-get entry :path) root))
                  (not
                   (cl-find-if
                    (lambda (c)
                      (and (equal (plist-get c :path)
                                  (plist-get entry :path))
                           (equal (plist-get c :status) "DELETED")))
                    (fossil-ui--changes root))))
          (user-error "Deletion changed; unstage and review %s"
                      (plist-get entry :path)))))
    (dolist (entry (seq-remove (lambda (e)
                                 (plist-get e :deleted)) entries))
      (let* ((path (plist-get entry :path))
             (file (expand-file-name path root))
             (backup (make-temp-file (expand-file-name "working-" directory))))
        (fossil-ui--clean-buffer file)
        (fossil-ui--text-file file)
        (copy-file file backup t t t)
        (set-file-modes backup #o600)
        (push
         (list :path path :backup backup :mode (file-modes file) :staged (plist-get entry :staged))
         (plist-get transaction :files))))
    (fossil-ui--save transaction-file transaction)
    (unwind-protect
        (progn
          (dolist (entry
                   (seq-remove
                    (lambda (e)
                      (plist-get e :deleted))
                    entries))
            (fossil-ui--write-text (expand-file-name (plist-get entry :path) root) (plist-get entry :staged)))
          (apply #'fossil-ui--require-success root "commit" "--hash" "--nosync" "--no-prompt" "--comment" message "--"
                 (mapcar (lambda (e)
                           (plist-get e :path)) entries)))
      (fossil-ui--restore-transaction root transaction))))

(defun fossil-ui--commit-with-message (message paths)
  "Commit staged snapshots or marked PATHS with MESSAGE."
  (let* ((root (fossil-ui--root))
         (index (fossil-ui--index root)))
    (if (not (plist-get index :entries))
        (fossil-ui--commit-marked-files message paths)
      (when (plist-get textui-state :busy)
        (user-error "Fossil is busy"))
      (fossil-ui--commit-staged root message)
      (textui-set-state (current-buffer) :selected nil)
      (fossil-ui-refresh)
      (message "Staged changes committed locally; remaining edits restored. S synchronizes."))))

(defun fossil-ui-commit (&optional _edit)
  "Open the commit-message split for staged snapshots or marked files."
  (interactive "P")
  (let* ((index (fossil-ui--index (fossil-ui--root)))
         (entries (plist-get index :entries))
         (paths
          (if entries
              (mapcar
               (lambda (entry)
                 (plist-get entry :path))
               entries)
            (plist-get textui-state :selected))))
    (unless paths
      (user-error "Stage changes with s first"))
    (when (and entries
               (plist-get textui-state :selected))
      (user-error "Clear old file marks with X before committing staged changes"))
    (fossil-ui--open-commit-buffer paths)
    (setq-local fossil-ui-commit-index (and entries
                                            index))))

(defun fossil-ui--check-message-stage (&rest _)
  "Keep an open staged-commit message from committing a changed selection."
  (when fossil-ui-commit-index
    (unless (and (buffer-live-p fossil-ui--commit-owner)
                 (equal fossil-ui-commit-index
                        (fossil-ui--index (buffer-local-value 'default-directory fossil-ui--commit-owner))))
      (user-error "Staging changed while writing the message; cancel and review the selection before committing"))))

(defun fossil-ui--guard-checkout-change (&rest _)
  "Require staged selections to be committed or cleared before changing the checkout."
  (when (plist-get (fossil-ui--index (fossil-ui--root)) :entries)
    (user-error "Commit or clear staged selections before updating or switching branches")))

(defun fossil-ui--snapshot (directory &optional selected)
  "Collect checkout and staging state for DIRECTORY and SELECTED."
  (let* ((state (fossil-ui--checkout-snapshot directory selected))
         (root (plist-get state :root))
         (index (condition-case err (fossil-ui--index root) (error (list :error (error-message-string err)))))
         (entries (plist-get index :entries)))
    (when-let* ((error-text (plist-get index :error)))
      (setq state (plist-put state :error error-text)))
    (when (and entries
               (not (equal (plist-get index :revision) (car (split-string (plist-get state :checkout))))))
      (setq state
            (plist-put state
                       :error "Staging belongs to an older checkout; inspect and clear it before continuing.")))
    (setq state (plist-put state :stage-entries entries))
    (let ((changes (copy-tree (plist-get state :changes))))
      (dolist (entry entries)
        (let* ((path (plist-get entry :path))
               (file (expand-file-name path root))
               (change
                (cl-find path changes
                         :key (lambda (c)
                                (plist-get c :path))
                         :test #'equal)))
          (when (plist-get entry :deleted)
            (setq changes
                  (cl-remove path changes
                             :key
                             (lambda (c)
                               (plist-get c :path))
                             :test
                             #'equal)))
          (when (and (file-regular-p file)
                     (not (file-symlink-p file)))
            (let ((work (condition-case nil (fossil-ui--text-file file) (error nil))))
              (if (equal work (plist-get entry :staged))
                  (setq changes
                        (cl-remove path changes
                                   :key (lambda (c)
                                          (plist-get c :path))
                                   :test #'equal))
                (unless change
                  (push (list :path path :status "EDITED") changes)))))))
      (plist-put state :unstaged changes))))

(defun fossil-ui--stage-panel (width)
  "Render the persistent staging selection and remaining changes at WIDTH."
  (let ((entries (plist-get textui-state :stage-entries)))
    (fossil-ui--card
     (format "Staged changes · %d files" (length entries))
     (if entries
         (mapcar
          (lambda (entry)
            (fossil-ui--change-row
             (list :path (plist-get entry :path) :status "STAGED")
             (max 8 (- width 4))
             (list (plist-get entry :path))))
          entries)
       (list
        (fossil-ui--text "Nothing staged. s selects a file; TAB opens hunks, v/V selects changed lines, and s stages that selection." 'fossil-ui-faded)))
     width)))

(defun fossil-ui--unstaged-panel (width state)
  "Show remaining working changes at WIDTH from STATE."
  (let* ((changes
          (if (plist-member state :unstaged)
              (plist-get state :unstaged)
            (plist-get state :changes)))
         (card (fossil-ui--changes-panel width changes (plist-get state :selected))))
    (setf
     (car (plist-get card :children))
     (fossil-ui--text (format "Unstaged changes · %d files" (length changes)) 'fossil-ui-strong))
    (unless changes
      (setf
       (cadr (plist-get card :children))
       (fossil-ui--column (list (fossil-ui--text "No unstaged changes." 'success)))))
    card))

(defun fossil-ui-refresh-timeline ()
  "Refresh only recent commits while preserving unchanged timeline entries."
  (interactive)
  (setq textui-state (plist-put textui-state :timeline (fossil-ui--timeline (fossil-ui--root))))
  (if fossil-ui-keyed-timeline
      (textui-reconcile-keyed-region (current-buffer) 'fossil-timeline #'fossil-ui--timeline-entries)
    (textui-refresh (current-buffer))))

(defun fossil-ui--timeline-entries (width)
  "Return stable keyed timeline entries at WIDTH."
  (mapcar
   (lambda (entry)
     (list
      (or (alist-get 'uuid entry)
          (format "%S" entry))
      (fossil-ui--column (fossil-ui--timeline-elements entry width))))
   (seq-take (plist-get textui-state :timeline) (fossil-ui--timeline-count))))

(defun fossil-ui--frame (width)
  "Render the working dashboard with full-width stable timeline and staging sections."
  (let* ((width
          (max 1
               (if fossil-ui-content-width
                   (min width fossil-ui-content-width)
                 width)))
         (state textui-state)
         (elements (fossil-ui--screen-elements width))
         (prefix (butlast elements 2))
         (entries (fossil-ui--timeline-entries width)))
    (let ((parts
           (append
            (list
             (fossil-ui--column prefix)
             (fossil-ui--stage-panel width)
             (fossil-ui--unstaged-panel width state))
            (when (plist-get state :preview-path)
              (list `(:type fossil-ui-preview
                      :path ,(plist-get state :preview-path)
                      :value ,(plist-get state :preview))))
            (list
             (fossil-ui--text "Recent commits" 'fossil-ui-strong)
             `(:type :flex
               :direction :column
               :gap 1
               :layout (:refresh-id fossil-timeline)
               :children ,(or (mapcar #'cadr entries)
                              (list (fossil-ui--item "No commits available"))))
             (fossil-ui--text "s Stage · u Unstage · x Discard · d Delete · c c Commit · S Sync · F Update · RET File · TAB Diff · D Staged diff · P Preview · q Back" 'fossil-ui-faded)))))
      (cl-loop for part in parts for first = t then nil
               unless first collect '(:type :text :value "\n\n" :align left :wrap greedy)
               collect part))))

(defun fossil-ui--after-refresh (&optional buffer &rest _)
  "Install or reconcile the full-width timeline after BUFFER's dashboard refresh."
  (with-current-buffer (or buffer
                           (current-buffer))
    (when (and fossil-ui-keyed-timeline
               (derived-mode-p 'fossil-ui-mode)
               (assq 'fossil-timeline textui--refresh-regions))
      (textui-reconcile-keyed-region (current-buffer) 'fossil-timeline #'fossil-ui--timeline-entries))))

(defun fossil-ui-status (&optional directory)
  "Open DIRECTORY's Fossil dashboard full-frame, remembering the previous windows."
  (interactive)
  (let* ((configuration (current-window-configuration))
         (buffer (fossil-ui--open-dashboard directory)))
    (when fossil-ui-full-frame
      (switch-to-buffer buffer)
      (delete-other-windows)
      (with-current-buffer buffer
        (unless fossil-ui-window-configuration
          (setq fossil-ui-window-configuration configuration))
        (textui-refresh buffer)))
    buffer))

(defun fossil-ui-quit ()
  "Close this Fossil buffer and its diff window, or restore the previous layout."
  (interactive)
  (let ((buffer (current-buffer))
        (owner (plist-get fossil-ui-diff-context :owner))
        (configuration fossil-ui-window-configuration))
    (cond
     (fossil-ui-diff-context
      (let ((owner-window (and (buffer-live-p owner)
                               (get-buffer-window owner))))
        (dolist (window (get-buffer-window-list buffer nil t))
          (if (one-window-p t (window-frame window))
              (when (buffer-live-p owner)
                (set-window-buffer window owner))
            (delete-window window)))
        (kill-buffer buffer)
        (when (window-live-p owner-window)
          (select-window owner-window))))
     (configuration
      (setq fossil-ui-window-configuration nil)
      (set-window-configuration configuration)
      (kill-buffer buffer))
     (t (quit-window t)))))

(defun fossil-ui-help ()
  "Show the workflow's actual keybindings and selection semantics."
  (interactive)
  (fossil-ui--show-output "*fossil-ui help*"
                          "Fossil workflow\n\ns / u  Stage / unstage file, hunk, or selected changed lines\nx      Discard working file or selected unstaged diff lines (asks first)\nv / V  Select changed lines in a diff; partial characters select their whole lines\nRET    Open file\nTAB    Open actionable diff in a split\nD      Open staged diff / switch staged and unstaged views\n[c ]c  Previous / next hunk; TAB folds a hunk\nr      Refresh; stale diffs refuse writes\nc c    Open commit editor; C-c C-c submits, C-c C-k cancels\nS      Synchronize; F updates the checkout; b switches branch\nP      Toggle read-only dashboard preview; use TAB for hunk actions\nq      Return to dashboard / restore previous window layout\n\nStaging persists locally across Emacs restarts. Partial staging supports regular UTF-8 text files, including added files, with original line endings preserved. Binary files, symlinks, renames/deletions, and pending merges require whole-file handling. Legacy SPC/A/X file marks remain available for that purpose; do not mix marks with staging.\n\nPartial commits run locally without autosync, restore remaining edits, and retain recovery data on interruption. Use S to synchronize. M-x fossil-ui-recover restores interrupted commits; M-x fossil-ui-clear-stage clears an outdated selection. Hunk discard uses the visiting file buffer, so Emacs undo can restore it.\n"))

(defun fossil-ui-staged-diff ()
  "Open staged changes of the dashboard file."
  (interactive)
  (fossil-ui-diff t))

(advice-add 'textui-refresh :after #'fossil-ui--after-refresh)
(advice-add 'textui-refresh :around #'fossil-ui--preserve-dashboard-position)

;;;###autoload
(defalias 'fossil-ui #'fossil-ui-status)

(provide 'fossil-ui)
;;; fossil-ui.el ends here
