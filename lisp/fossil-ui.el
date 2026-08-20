;;; fossil-ui.el --- Small TextUI frontend for Fossil -*- lexical-binding: t; -*-

;; Copyright (C) 2026 cashmere

;; Author: cashmere
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (textui "0.5.1"))
;; Keywords: tools, vc

;;; Commentary:

;; A deliberately small Fossil dashboard.  It follows Fossil's own model:
;; files may be selected for a partial commit, but there is no staging area.
;; Local inspection is synchronous; operations which may trigger autosync run
;; asynchronously.

;;; Code:

(require 'ansi-color)
(require 'cl-lib)
(require 'diff-mode)
(require 'json)
(require 'outline)
(require 'seq)
(require 'subr-x)
(require 'textui)
(require 'textui-widgets)

(declare-function evil-define-key* "evil-core" (state keymap key def &rest bindings))
(declare-function evil-get-auxiliary-keymap "evil-core"
                  (map state &optional create noinherit))
(declare-function evil-make-intercept-map "evil-core" (keymap &optional state aux))
(declare-function evil-normalize-keymaps "evil-core" (&optional state))
(declare-function evil-set-initial-state "evil-core" (mode state))
(declare-function general-define-key "general" (&rest args))
(declare-function general-local-map "general" ())
(defvar general-override-local-mode-map)

(defgroup fossil-ui nil
  "A compact TextUI frontend for Fossil."
  :group 'tools
  :prefix "fossil-ui-")

(defcustom fossil-ui-program "fossil"
  "Fossil executable used by the dashboard."
  :type 'string
  :group 'fossil-ui)

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

(defun fossil-ui--snapshot (directory &optional selected)
  "Collect dashboard state for DIRECTORY, retaining SELECTED paths."
  (let* ((info (fossil-ui--checkout-info directory))
         (root (plist-get info :root))
         (changes (fossil-ui--attach-numstat
                   (fossil-ui--changes root) (fossil-ui--numstat root)))
         (paths (mapcar (lambda (change) (plist-get change :path)) changes)))
    (list :root root
          :repository (plist-get info :repository)
          :checkout (plist-get info :checkout)
          :branch (or (plist-get info :tags) "trunk")
          :user (plist-get info :user)
          :remote (fossil-ui--remote root)
          :autosync (fossil-ui--setting root "autosync")
          :changes changes
          :selected (cl-remove-if-not (lambda (path) (member path paths)) selected)
          :timeline (condition-case err
                        (fossil-ui--timeline root)
                      (error (list (list (cons 'comment
                                              (error-message-string err))))))
          :branches (condition-case nil (fossil-ui--branches root) (error nil))
          :height fossil-ui--window-height
          :busy nil
          :error nil)))

(defun fossil-ui--fit (value width &optional face)
  "Return VALUE truncated or padded to WIDTH, optionally using FACE."
  (let* ((width (max 0 width))
         (value (truncate-string-to-width (format "%s" (or value ""))
                                          width nil nil "..."))
         (result (concat value
                         (make-string (max 0 (- width (string-width value))) ?\s))))
    (if face (propertize result 'face face) result)))

(defun fossil-ui--item (value &optional face)
  "Return a TextUI item for VALUE with optional FACE."
  `(:type item :format "%v"
    :value ,(if face (propertize value 'face face) value)))

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
         (line (concat (propertize "▎" 'face (fossil-ui--status-face status))
                       (if marked "[x] " "[ ] ")
                       (propertize (concat (fossil-ui--status-icon status) " ")
                                   'face (fossil-ui--status-face status))
                       (fossil-ui--fit path (if narrow (- width 7) path-width)
                                       (if marked 'fossil-ui-salient 'default))
                       (unless narrow
                         (propertize metadata 'face
                                     (fossil-ui--status-face status))))))
    `(:type fossil-ui-row
      :value ,line
      :fossil-ui-path ,path
      :fossil-ui-status ,status
      :layout (:focus-id ,(list 'file path))
      :action ,(lambda (&rest _) (fossil-ui-diff)))))

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
  (let* ((uuid (or (alist-get 'uuid entry) ""))
         (short (substring uuid 0 (min 10 (length uuid))))
         (timestamp (alist-get 'timestamp entry))
         (date (if (numberp timestamp)
                   (format-time-string "%b %d %H:%M" (seconds-to-time timestamp))
                 "unknown time"))
         (user (or (alist-get 'user entry) ""))
         (comment (or (alist-get 'comment entry) ""))
         (tags (or (alist-get 'tags entry) (alist-get 'branch entry)))
         (tag-text (cond ((listp tags) (mapconcat (lambda (tag) (format "%s" tag))
                                                   tags ", "))
                         (tags (format "%s" tags)) (t "")))
         (author (truncate-string-to-width user 18 nil nil "…")))
    (list
     (fossil-ui--item
      (concat (propertize "● " 'face 'fossil-ui-salient)
              (fossil-ui--fit comment (max 12 (- width 16)))
              "  "
              (propertize date 'face 'fossil-ui-faded)))
     (fossil-ui--item
      (fossil-ui--fit
       (format "│  %s  %s%s" short author
               (if (string-empty-p tag-text) "" (concat "  ·  " tag-text))) width)
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
  `(:type :flex :direction :column :gap 1 :padding 1 :border t
    :layout (:width ,width :min-width ,(or minimum width) :grow ,(or grow 0))
    :children (,(fossil-ui--item
                 title (unless (get-text-property 0 'face title)
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
   (list (fossil-ui--item (fossil-ui--fit message (max 8 (- width 4))) face))
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
         (timeline (seq-take (plist-get textui-state :timeline)
                             (fossil-ui--timeline-count)))
         (chips (concat
                 (fossil-ui--chip (if changes (format "%d changed" (length changes))
                                    "clean")
                                  (if changes 'warning 'success))
                 " "
                 (when selected
                   (concat (fossil-ui--chip (format "%d selected" (length selected))
                                            'highlight) " "))
                 (when busy (fossil-ui--chip (format "running: %s" busy) 'warning))
                 (when error-text (fossil-ui--chip "error" 'error)))))
    (append
     (list
      (fossil-ui--item
       (fossil-ui--fit
        (format "%s  %s" (fossil-ui--icon 'repository) project) width)
       'fossil-ui-strong)
      `(:type :flex :direction :row :gap 1
        :children
        (,(fossil-ui--keycap "g" "Refresh" #'fossil-ui-refresh 'refresh)
         ,(fossil-ui--keycap "c" "Commit" #'fossil-ui-commit 'commit)
         ,(fossil-ui--keycap "u" "Update" #'fossil-ui-update 'update)
         ,(fossil-ui--keycap "s" "Sync" #'fossil-ui-sync 'sync (not remote-value))
         ,(fossil-ui--keycap "b" "Branch" #'fossil-ui-switch-branch 'branch)))
      (fossil-ui--metadata-grid width chips))
     (when busy
       (list (fossil-ui--banner "Running" (format "%s is running…" busy)
                                width 'fossil-ui-warning)))
     (when error-text
       (list (fossil-ui--banner "Error" error-text width 'fossil-ui-critical)))
     (list
      (fossil-ui--main-panels width changes selected timeline)
      (fossil-ui--item "? Help · q Close" 'fossil-ui-faded)))))

(defun fossil-ui--frame (width)
  "Render the Fossil dashboard at WIDTH."
  (let ((content-width
         (max 1 (if fossil-ui-content-width
                    (min width fossil-ui-content-width)
                  width))))
    (list `(:type :flex :direction :column :gap 1
            :layout (:width ,content-width)
            :children ,(fossil-ui--screen-elements content-width)))))

(defun fossil-ui--path-at-point ()
  "Return the Fossil path at point."
  (or (get-text-property (point) 'fossil-ui-path)
      (get-text-property (line-beginning-position) 'fossil-ui-path)))

(defun fossil-ui--status-at-point ()
  "Return the Fossil status at point."
  (or (get-text-property (point) 'fossil-ui-status)
      (get-text-property (line-beginning-position) 'fossil-ui-status)))

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

(defun fossil-ui-refresh ()
  "Refresh the current Fossil dashboard."
  (interactive)
  (when (plist-get textui-state :busy)
    (user-error "Fossil is busy: %s" (plist-get textui-state :busy)))
  (let ((path (fossil-ui--path-at-point))
        (selected (plist-get textui-state :selected))
        (root (plist-get textui-state :root)))
    (condition-case err
        (let ((next (fossil-ui--snapshot root selected)))
          (textui-update (current-buffer) (lambda (_) next))
          (when path (fossil-ui--goto-path path)))
      (error
       (textui-set-state (current-buffer) :error (error-message-string err))))))

(defun fossil-ui-toggle-mark ()
  "Toggle the commit mark on the file at point."
  (interactive)
  (let ((path (or (fossil-ui--path-at-point) (user-error "No file at point")))
        (status (fossil-ui--status-at-point)))
    (when (string= status "EXTRA")
      (user-error "Add this file before selecting it for a commit"))
    (textui-update
     (current-buffer)
     (lambda (state)
       (let* ((next (copy-sequence state))
              (selected (copy-sequence (plist-get state :selected))))
         (plist-put next :selected
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
    (define-key map (kbd "q") #'quit-window)
    map))

(defconst fossil-ui--diff-evil-bindings
  '(("]c" . diff-hunk-next)
    ("[c" . diff-hunk-prev)
    ("TAB" . outline-toggle-children)
    ("q" . quit-window))
  "Bindings which a Fossil diff buffer owns in modal states.")

(define-derived-mode fossil-ui-diff-mode diff-mode "Fossil-Diff"
  "Mode for a Fossil working-tree diff."
  (setq-local outline-regexp "^@@ ")
  (outline-minor-mode 1)
  (setq buffer-read-only t)
  (when (fboundp 'general-define-key)
    (fossil-ui--install-general-local-map fossil-ui--diff-evil-bindings))
  (when (fboundp 'evil-normalize-keymaps)
    (evil-normalize-keymaps)))

(defun fossil-ui--delta-render (diff)
  "Render unified DIFF through Delta and return propertized Emacs text.
Return nil when Delta exits unsuccessfully."
  (with-temp-buffer
    (insert diff)
    (let ((code (condition-case nil
                    (apply #'call-process-region
                           (point-min) (point-max)
                           fossil-ui-delta-program t t nil
                           fossil-ui-delta-arguments)
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

(defun fossil-ui--render-diff (diff)
  "Render unified DIFF according to `fossil-ui-diff-renderer'."
  (pcase fossil-ui-diff-renderer
    ('plain diff)
    ('delta
     (or (and (executable-find fossil-ui-delta-program)
              (fossil-ui--delta-render diff))
         (user-error "Delta could not render this diff")))
    ('auto
     (or (and (executable-find fossil-ui-delta-program)
              (fossil-ui--delta-render diff))
         diff))
    (_ (user-error "Unknown Fossil diff renderer: %S"
                   fossil-ui-diff-renderer))))

(defun fossil-ui-diff ()
  "Show the diff for the file at point."
  (interactive)
  (let* ((path (or (fossil-ui--path-at-point) (user-error "No file at point")))
         (status (fossil-ui--status-at-point))
         (root (plist-get textui-state :root))
         (result (if (string= status "EXTRA")
                     (fossil-ui--call-in root "xdiff" path)
                   (fossil-ui--call-in root "diff" "--internal" "--unified" "--" path)))
         (code (car result))
         (output (cadr result)))
    (unless (zerop code)
      (user-error "%s" output))
    (fossil-ui--show-output
     (format "*fossil diff: %s*" path)
     (if (string-empty-p output)
         "No textual diff available.\n"
       (fossil-ui--render-diff output))
     #'fossil-ui-diff-mode)))

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

(defun fossil-ui--selected-or-current ()
  "Return selected paths, or the path at point when none are selected."
  (or (copy-sequence (plist-get textui-state :selected))
      (and-let* ((path (fossil-ui--path-at-point))) (list path))
      (user-error "No files selected")))

(defun fossil-ui-revert ()
  "Revert selected files, or the file at point."
  (interactive)
  (let ((paths (fossil-ui--selected-or-current)))
    (when (yes-or-no-p
           (format "Revert %d file%s? Fossil undo can restore this once. "
                   (length paths) (if (= (length paths) 1) "" "s")))
      (apply #'fossil-ui--require-success
             (plist-get textui-state :root) "revert" "--" paths)
      (fossil-ui-refresh)
      (message "Reverted %d file(s)" (length paths)))))

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

(defun fossil-ui--commit-with-message (message paths)
  "Commit PATHS with MESSAGE from the current Fossil dashboard."
  (when (string-empty-p (string-trim message))
    (user-error "Commit message cannot be empty"))
  (fossil-ui--async
   "commit"
   (append (list "commit" "--hash" "--no-prompt" "--comment" message "--") paths)
   (lambda (_)
     (when (buffer-live-p (current-buffer))
       (textui-set-state (current-buffer) :selected nil)))))

(defun fossil-ui-commit (&optional edit)
  "Commit selected files; with prefix EDIT, use a multiline buffer."
  (interactive "P")
  (let ((paths (copy-sequence (plist-get textui-state :selected))))
    (unless paths
      (user-error "Select files with SPC before committing"))
    (if edit
        (fossil-ui--open-commit-buffer paths)
      (let ((message (read-string "Commit message: " nil
                                  'fossil-ui--commit-history)))
        (fossil-ui--commit-with-message message paths)))))

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
  "Open a multiline commit buffer for PATHS."
  (let ((owner (current-buffer))
        (buffer (get-buffer-create
                 (format "*fossil commit: %s*"
                         (file-name-nondirectory
                          (directory-file-name (plist-get textui-state :root)))))))
    (with-current-buffer buffer
      (fossil-ui-commit-mode)
      (setq-local fossil-ui--commit-owner owner
                  fossil-ui--commit-paths paths)
      (erase-buffer))
    (pop-to-buffer buffer)))

(defun fossil-ui-commit-submit ()
  "Submit the current multiline Fossil commit message."
  (interactive)
  (let ((message (string-trim-right (buffer-substring-no-properties
                                     (point-min) (point-max))))
        (owner fossil-ui--commit-owner)
        (paths fossil-ui--commit-paths)
        (buffer (current-buffer)))
    (unless (buffer-live-p owner)
      (user-error "The Fossil dashboard was closed"))
    (when (string-empty-p (string-trim message))
      (user-error "Commit message cannot be empty"))
    (kill-buffer buffer)
    (pop-to-buffer owner)
    (with-current-buffer owner
      (fossil-ui--commit-with-message message paths))))

(defun fossil-ui-commit-cancel ()
  "Cancel the current multiline Fossil commit."
  (interactive)
  (let ((owner fossil-ui--commit-owner))
    (kill-buffer (current-buffer))
    (when (buffer-live-p owner) (pop-to-buffer owner))
    (message "Commit cancelled")))

(defun fossil-ui-update ()
  "Update the current Fossil branch."
  (interactive)
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
  (let* ((branches (or (plist-get textui-state :branches)
                       (user-error "No branches found")))
         (current (plist-get textui-state :branch))
         (branch (completing-read "Update to branch: " branches nil t nil nil current)))
    (unless (string= branch current)
      (when (or (null (plist-get textui-state :changes))
                (yes-or-no-p
                 (format "Update to %s and merge your local changes into it? " branch)))
        (fossil-ui--async (format "update %s" branch) (list "update" branch))))))

(defun fossil-ui-help ()
  "Show the compact Fossil UI key reference."
  (interactive)
  (fossil-ui--show-output
   "*fossil-ui help*"
   (concat
    "Fossil UI\n\n"
    "There is no staging area. [x] only means that the file will be passed\n"
    "to the next commit from this buffer. Fossil itself is unchanged.\n\n"
    "SPC       toggle commit selection     A / X     select all / none\n"
    "RET       show file diff              o         visit file\n"
    "a         add an unversioned file     f         stop tracking file\n"
    "r         revert selected/current     U         preview and run undo\n"
    "c         commit selected files       C-u c     multiline comment\n"
    "u / s     update / sync               b         switch branch\n"
    "g         refresh                     j/k,n/p   move between files\n"
    "q         close\n\n"
    "In a diff: [c and ]c move between hunks; TAB folds a hunk.\n")))

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
    (define-key map (kbd "RET") #'fossil-ui-diff)
    (define-key map (kbd "<return>") #'fossil-ui-diff)
    (define-key map (kbd "o") #'fossil-ui-visit-file)
    (define-key map (kbd "a") #'fossil-ui-add)
    (define-key map (kbd "f") #'fossil-ui-forget)
    (define-key map (kbd "r") #'fossil-ui-revert)
    (define-key map (kbd "U") #'fossil-ui-undo)
    (define-key map (kbd "c") #'fossil-ui-commit)
    (define-key map (kbd "u") #'fossil-ui-update)
    (define-key map (kbd "s") #'fossil-ui-sync)
    (define-key map (kbd "b") #'fossil-ui-switch-branch)
    (define-key map (kbd "g") #'fossil-ui-refresh)
    (define-key map (kbd "?") #'fossil-ui-help)
    (define-key map (kbd "j") #'fossil-ui-next-file)
    (define-key map (kbd "n") #'fossil-ui-next-file)
    (define-key map (kbd "k") #'fossil-ui-previous-file)
    (define-key map (kbd "p") #'fossil-ui-previous-file)
    (define-key map (kbd "q") #'quit-window)
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
  (when (fboundp 'general-define-key)
    (fossil-ui--install-general-local-bindings))
  (when (fboundp 'evil-normalize-keymaps)
    (evil-normalize-keymaps)))

(defconst fossil-ui--evil-bindings
  '(("SPC" . fossil-ui-toggle-mark)
    ("A" . fossil-ui-mark-all)
    ("X" . fossil-ui-unmark-all)
    ("RET" . fossil-ui-diff)
    ("<return>" . fossil-ui-diff)
    ("o" . fossil-ui-visit-file)
    ("a" . fossil-ui-add)
    ("f" . fossil-ui-forget)
    ("r" . fossil-ui-revert)
    ("U" . fossil-ui-undo)
    ("c" . fossil-ui-commit)
    ("u" . fossil-ui-update)
    ("s" . fossil-ui-sync)
    ("b" . fossil-ui-switch-branch)
    ("g" . fossil-ui-refresh)
    ("?" . fossil-ui-help)
    ("j" . fossil-ui-next-file)
    ("n" . fossil-ui-next-file)
    ("k" . fossil-ui-previous-file)
    ("p" . fossil-ui-previous-file)
    ("q" . quit-window))
  "Bindings which the Fossil dashboard owns in modal states.")

(defun fossil-ui--install-general-local-bindings ()
  "Install buffer-local General overrides for the Fossil dashboard."
  (fossil-ui--install-general-local-map fossil-ui--evil-bindings))

(defun fossil-ui--install-general-local-map (bindings)
  "Install buffer-local General overrides from BINDINGS."
  (general-local-map)
  (dolist (binding bindings)
    (general-define-key
     :states '(normal motion)
     :keymaps 'general-override-local-mode-map
     (car binding) (cdr binding)))
  ;; General marks its global override auxiliaries as Evil intercept maps, but
  ;; not its buffer-local override auxiliaries.  Promote the latter as well so
  ;; the local dashboard bindings precede General's global ones.
  (when (fboundp 'evil-get-auxiliary-keymap)
    (dolist (state '(normal motion))
      (evil-make-intercept-map
       (evil-get-auxiliary-keymap general-override-local-mode-map
                                  state t t)
       state))))

(defun fossil-ui--install-evil-bindings ()
  "Make the Fossil map win over global Evil and General maps."
  (evil-set-initial-state 'fossil-ui-mode 'normal)
  (evil-set-initial-state 'fossil-ui-diff-mode 'normal)
  ;; An intercept map is deliberately used here.  A regular major-mode map is
  ;; consulted after Evil's normal-state maps, where keys such as `g' and SPC
  ;; are prefixes.  The dashboard must own its complete one-key vocabulary.
  (evil-make-intercept-map fossil-ui-mode-map)
  (dolist (binding fossil-ui--evil-bindings)
    (evil-define-key* '(normal motion) fossil-ui-mode-map
      (kbd (car binding)) (cdr binding)))
  (evil-make-intercept-map fossil-ui-diff-mode-map)
  (dolist (binding fossil-ui--diff-evil-bindings)
    (evil-define-key* '(normal motion) fossil-ui-diff-mode-map
      (kbd (car binding)) (cdr binding)))
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'fossil-ui-mode 'fossil-ui-diff-mode)
        (evil-normalize-keymaps)))))

(with-eval-after-load 'evil
  (fossil-ui--install-evil-bindings))

(with-eval-after-load 'general
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'fossil-ui-mode 'fossil-ui-diff-mode)
        (fossil-ui--install-general-local-map
         (if (derived-mode-p 'fossil-ui-diff-mode)
             fossil-ui--diff-evil-bindings
           fossil-ui--evil-bindings))
        (when (fboundp 'evil-normalize-keymaps)
          (evil-normalize-keymaps))))))

;;;###autoload
(defun fossil-ui-status (&optional directory)
  "Open a Fossil dashboard for DIRECTORY or the current checkout."
  (interactive)
  (let* ((start (fossil-ui--input-directory directory))
         (snapshot (fossil-ui--snapshot start))
         (root (plist-get snapshot :root))
         (name (format "*fossil: %s*"
                       (file-name-nondirectory (directory-file-name root))))
         (existing (get-buffer name)))
    (when (and existing
               (with-current-buffer existing
                 (not (derived-mode-p 'fossil-ui-mode))))
      (user-error "A non-Fossil buffer already uses %s" name))
    (let ((buffer (or existing (get-buffer-create name))))
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

;;;###autoload
(defalias 'fossil-ui #'fossil-ui-status)

(provide 'fossil-ui)
;;; fossil-ui.el ends here
