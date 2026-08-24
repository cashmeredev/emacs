;;; bbs-ui.el --- A Fossil-native BBS for Emacs -*- lexical-binding: t; -*-

;; Copyright (C) 2026 cashmere

;; Author: cashmere
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (textui "0.5.1") (markdown-mode "2.7"))
;; Keywords: applications, hypermedia, tools

;;; Commentary:

;; bbs-ui treats a Fossil repository as the durable local copy of a forum and
;; wiki.  Reading is entirely local.  Pull and push are deliberately separate:
;; opening the UI may pull, while publishing always requires an explicit,
;; confirmed command.  Forum writes go through Fossil's own local web handler;
;; this package never writes Fossil's SQLite tables or constructs artifacts.

;;; Code:

(require 'browse-url)
(require 'cl-lib)
(require 'json)
(require 'markdown-mode)
(require 'seq)
(require 'subr-x)
(require 'textui)
(require 'textui-widgets)
(require 'url-parse)
(require 'url-util)
(require 'wid-edit)

(declare-function evil-define-key* "evil-core" (state keymap key def &rest bindings))
(declare-function evil-get-auxiliary-keymap "evil-core"
                  (map state &optional create noinherit))
(declare-function evil-make-intercept-map "evil-core" (keymap &optional state aux))
(declare-function evil-normalize-keymaps "evil-core" (&optional state))
(declare-function evil-set-initial-state "evil-core" (mode state))
(declare-function general-define-key "general" (&rest args))
(declare-function general-local-map "general" ())
(defvar general-override-local-mode-map)

(defgroup bbs-ui nil
  "A local-first TextUI client for Fossil forums and wikis."
  :group 'applications
  :prefix "bbs-ui-")

(defcustom bbs-ui-repository-file nil
  "Default Fossil repository opened by `bbs'.
When nil, `bbs' asks for a repository file."
  :type '(choice (const :tag "Ask each time" nil) file)
  :group 'bbs-ui)

(defcustom bbs-ui-fossil-program "fossil"
  "Fossil executable used by the BBS client."
  :type 'string
  :group 'bbs-ui)

(defcustom bbs-ui-pull-on-open t
  "Whether `bbs-open' starts a pull after rendering the local snapshot.
This option never runs sync or push."
  :type 'boolean
  :group 'bbs-ui)

(defcustom bbs-ui-web-base-url nil
  "Public browser URL for the BBS, independent of Fossil sync remotes.
This is used only after an explicit `bbs-ui-open-web' command and never by
opening, reading, refreshing, or composing in the Emacs client."
  :type '(choice (const :tag "Use Fossil remote" nil) url)
  :group 'bbs-ui)

(defcustom bbs-ui-state-file nil
  "JSON file used for read and saved markers.
Nil means bbs/state.json below `xdg-state-home'."
  :type '(choice (const :tag "XDG state directory" nil) file)
  :group 'bbs-ui)

(defcustom bbs-ui-cache-directory nil
  "Directory used for locally extracted avatars.
Nil means bbs below `xdg-cache-home'."
  :type '(choice (const :tag "XDG cache directory" nil) directory)
  :group 'bbs-ui)

(defcustom bbs-ui-wide-layout-width 96
  "Minimum width for the BBS master/detail layout."
  :type 'integer
  :group 'bbs-ui)

(defcustom bbs-ui-compact-layout-width 72
  "Width below which secondary BBS list columns are hidden."
  :type 'integer
  :group 'bbs-ui)

(defcustom bbs-ui-board-limit 80
  "Maximum number of threads rendered in the board list."
  :type 'integer
  :group 'bbs-ui)

(defface bbs-ui-logo
  '((t :foreground "#ffaf5f" :weight bold))
  "The BBS wordmark."
  :group 'bbs-ui)

(defface bbs-ui-cyan
  '((t :foreground "#7ee8fa"))
  "Cyan structural accents."
  :group 'bbs-ui)

(defface bbs-ui-magenta
  '((t :foreground "#c792ea" :weight bold))
  "Magenta labels and important accents."
  :group 'bbs-ui)

(defface bbs-ui-green
  '((t :foreground "#c3e88d" :weight bold))
  "Connected and completed state."
  :group 'bbs-ui)

(defface bbs-ui-yellow
  '((t :foreground "#ffc777" :weight bold))
  "Unread and queued state."
  :group 'bbs-ui)

(defface bbs-ui-blue
  '((t :foreground "#82aaff"))
  "Actionable BBS text."
  :group 'bbs-ui)

(defface bbs-ui-muted
  '((t :foreground "#697098"))
  "Secondary BBS text."
  :group 'bbs-ui)

(defface bbs-ui-selected
  '((t :background "#193a73" :foreground "#f8f8f2" :weight bold))
  "The selected BBS row."
  :group 'bbs-ui)

(defface bbs-ui-deleted
  '((t :inherit shadow :strike-through t))
  "Deleted forum posts."
  :group 'bbs-ui)

(defface bbs-ui-frame
  '((t :foreground "#315d9c"))
  "Outer rails and pane separators."
  :group 'bbs-ui)

(defface bbs-ui-bar
  '((t :background "#001a38" :foreground "#7ee8fa" :weight bold))
  "Persistent BBS header and command bars."
  :group 'bbs-ui)

(defface bbs-ui-error
  '((t :background "#3a1018" :foreground "#ff757f" :weight bold))
  "Recoverable BBS error notices."
  :group 'bbs-ui)

(defvar-local bbs-ui--process nil)
(defvar-local bbs-ui--window-height nil)
(defvar-local bbs-ui--compose-owner nil)
(defvar-local bbs-ui--compose-kind nil)
(defvar-local bbs-ui--compose-target nil)
(defvar-local bbs-ui--compose-title nil)
(defvar-local bbs-ui--compose-mimetype nil)
(defvar-local bbs-ui--compose-page nil)
(defvar-local bbs-ui--diagnostics nil)
(defvar-local bbs-ui--last-render-error nil)
(defvar-local bbs-ui--keys-active nil)

(defun bbs-ui--set-notice (text)
  "Display transient status TEXT in the persistent BBS footer."
  (textui-update
   (current-buffer)
   (lambda (state)
     (let ((next (copy-sequence state)))
       (setq next (plist-put next :error nil))
       (plist-put next :notice text)))))

(defun bbs-ui--single-line-string (value)
  "Return VALUE with every cursor-breaking character made horizontal."
  (let ((text (format "%s" (or value ""))))
    ;; `truncate-string-to-width' may append a Unicode ellipsis.  Ensure its
    ;; destination is never an unibyte string first.
    (unless (multibyte-string-p text)
      (setq text (string-to-multibyte text)))
    (replace-regexp-in-string "[\n\r\t]+" " " text)))

(defun bbs-ui--measure-row (widget)
  "Return the visible value of BBS row WIDGET."
  (let ((value (bbs-ui--single-line-string (widget-get widget :value))))
    (when (string-match-p "[\n\r]" value)
      (error "BBS interactive rows must be exactly one line"))
    value))

(defun bbs-ui--attach-row (widget from to)
  "Attach WIDGET and its BBS identity between FROM and TO."
  (textui-widgets-attach-button widget from to)
  (add-text-properties
   from to
   (list 'bbs-ui-kind (widget-get widget :bbs-ui-kind)
         'bbs-ui-id (widget-get widget :bbs-ui-id))))

(define-widget 'bbs-ui-row 'push-button
  "A flat, focusable BBS row."
  :format "%v"
  :button-face 'default
  :textui-measure #'bbs-ui--measure-row
  :textui-attach #'bbs-ui--attach-row)

(define-widget 'bbs-ui-keycap 'push-button
  "A compact BBS command button."
  :format "%v"
  :button-face 'default
  :textui-measure #'bbs-ui--measure-row
  :textui-attach #'textui-widgets-attach-button)

(defun bbs-ui--state-path ()
  "Return the configured persistent state path."
  (expand-file-name
   (or bbs-ui-state-file
       (expand-file-name "bbs/state.json" (xdg-state-home)))))

(defun bbs-ui--cache-path ()
  "Return the configured cache directory."
  (file-name-as-directory
   (expand-file-name
    (or bbs-ui-cache-directory
        (expand-file-name "bbs" (xdg-cache-home))))))

(defun bbs-ui--call-raw (input &rest args)
  "Run Fossil ARGS with optional INPUT and return (CODE OUTPUT).
OUTPUT is decoded as raw bytes so Fossil W-card byte lengths remain valid."
  (with-temp-buffer
    (when input
      (set-buffer-multibyte nil)
      (insert (encode-coding-string input 'utf-8)))
    (let ((coding-system-for-read 'binary)
          (coding-system-for-write 'binary))
      (list
       (condition-case err
           (if input
               (apply #'call-process-region
                      (point-min) (point-max) bbs-ui-fossil-program
                      t (list t t) nil args)
             (apply #'process-file bbs-ui-fossil-program nil (list t t) nil args))
         (file-missing
          (erase-buffer)
          (insert (error-message-string err))
          127)
         (error
          (erase-buffer)
          (insert (error-message-string err))
          1))
       (buffer-string)))))

(defun bbs-ui--call (&rest args)
  "Run Fossil ARGS and return (CODE decoded-output)."
  (pcase-let ((`(,code ,raw) (apply #'bbs-ui--call-raw nil args)))
    (list code (string-trim-right (decode-coding-string raw 'utf-8)))))

(defun bbs-ui--require (&rest args)
  "Run Fossil ARGS and return output, or signal a user error."
  (pcase-let ((`(,code ,output) (apply #'bbs-ui--call args)))
    (if (zerop code)
        output
      (user-error "%s" (if (string-empty-p output)
                             (format "Fossil exited with status %d" code)
                           output)))))

(defun bbs-ui--sql (repository query)
  "Run read-only Fossil SQL QUERY against REPOSITORY."
  (bbs-ui--require "sql" "-R" repository query))

(defun bbs-ui--hex-decode (hex)
  "Decode UTF-8 text represented by HEX."
  (unless (zerop (% (length hex) 2))
    (error "Odd hexadecimal payload length"))
  (let ((bytes (make-string (/ (length hex) 2) 0)))
    (dotimes (index (/ (length hex) 2))
      (aset bytes index
            (string-to-number (substring hex (* 2 index) (+ 2 (* 2 index))) 16)))
    (decode-coding-string (encode-coding-string bytes 'binary) 'utf-8)))

(defun bbs-ui--hex-bytes (hex)
  "Decode HEX to an unibyte string."
  (let ((bytes (make-string (/ (length hex) 2) 0)))
    (dotimes (index (/ (length hex) 2))
      (aset bytes index
            (string-to-number (substring hex (* 2 index) (+ 2 (* 2 index))) 16)))
    (encode-coding-string bytes 'binary)))

(defun bbs-ui--fossil-unescape (value)
  "Decode Fossil card escapes in VALUE."
  (let ((index 0)
        (limit (length value))
        pieces)
    (while (< index limit)
      (let ((char (aref value index)))
        (if (and (= char ?\\) (< (1+ index) limit))
            (let ((escaped (aref value (1+ index))))
              (push (char-to-string
                     (pcase escaped
                       (?s ?\s) (?n ?\n) (?r ?\r) (?t ?\t) (?\\ ?\\)
                       (_ escaped)))
                    pieces)
              (setq index (+ index 2)))
          (push (char-to-string char) pieces)
          (setq index (1+ index)))))
    (apply #'concat (nreverse pieces))))

(defun bbs-ui--parse-artifact (raw)
  "Parse the Fossil forum or wiki artifact RAW into a plist."
  (let ((position 0)
        (limit (length raw))
        cards body)
    (while (< position limit)
      (let ((newline (string-search "\n" raw position)))
        (if (not newline)
            (setq position limit)
          (let* ((line-bytes (substring raw position newline))
                 (line (decode-coding-string line-bytes 'utf-8)))
            (setq position (1+ newline))
            (when (string-match "\\`\\([A-Z]\\)\\(?: \\(.*\\)\\)?\\'" line)
              (let ((card (string-to-char (match-string 1 line)))
                    (value (or (match-string 2 line) "")))
                (if (= card ?W)
                    (let ((count (string-to-number value)))
                      (when (> (+ position count) limit)
                        (error "Truncated Fossil W card"))
                      (setq body (decode-coding-string
                                  (substring raw position (+ position count)) 'utf-8)
                            position (+ position count))
                      (when (and (< position limit) (= (aref raw position) ?\n))
                        (setq position (1+ position))))
                  (push (cons card (bbs-ui--fossil-unescape value)) cards))))))))
    (list :date (cdr (assq ?D cards))
          :title (cdr (assq ?H cards))
          :root (cdr (assq ?G cards))
          :irt (cdr (assq ?I cards))
          :mimetype (or (cdr (assq ?N cards)) "text/x-fossil-wiki")
          :previous (cdr (assq ?P cards))
          :user (or (cdr (assq ?U cards)) "unknown")
          :wiki-name (cdr (assq ?L cards))
          :body (or body ""))))

(defun bbs-ui--parse-time (value)
  "Convert Fossil ISO timestamp VALUE to seconds since the epoch."
  (condition-case nil
      (if (string-match
           "\\`\\([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\\)\\(?:\\.\\([0-9]+\\)\\)?Z?\\'"
           value)
          (let ((base (match-string 1 value))
                (fraction (match-string 2 value)))
            (+ (float-time (date-to-time (concat base "Z")))
               (if fraction
                   (/ (string-to-number fraction)
                      (float (expt 10 (length fraction))))
                 0.0)))
        (float-time (date-to-time value)))
    (error 0.0)))

(defun bbs-ui--rows (output fields)
  "Split SQL OUTPUT into rows containing exactly FIELDS columns."
  (mapcar
   (lambda (line)
     (let ((parts (split-string line "|" nil)))
       (unless (= (length parts) fields)
         (error "Unexpected Fossil SQL row: %s" line))
       parts))
   (split-string output "\n" t)))

(defconst bbs-ui--forum-query
  (concat
   "SELECT hex(b.uuid),p.fpid,p.froot,coalesce(p.fprev,0),"
   "coalesce(p.firt,0),hex(content(b.uuid)) "
   "FROM forumpost p JOIN blob b ON b.rid=p.fpid "
   "ORDER BY p.fmtime,p.fpid;")
  "Read-only query used to load complete forum artifacts.")

(defun bbs-ui--load-forum-versions (repository)
  "Load raw forum versions from REPOSITORY."
  (if (string= "0" (bbs-ui--sql
                    repository
                    "SELECT count(*) FROM sqlite_schema WHERE name='forumpost';"))
      nil
    (mapcar
     (lambda (columns)
       (pcase-let ((`(,uuid-hex ,rid ,root ,prev ,irt ,artifact-hex) columns))
         (let* ((uuid (bbs-ui--hex-decode uuid-hex))
                (artifact (bbs-ui--parse-artifact
                           (bbs-ui--hex-bytes artifact-hex))))
           (append
            (list :uuid uuid
                  :rid (string-to-number rid)
                  :root-rid (string-to-number root)
                  :previous-rid (string-to-number prev)
                  :irt-rid (string-to-number irt)
                  :time (bbs-ui--parse-time (plist-get artifact :date)))
            artifact))))
     (bbs-ui--rows (bbs-ui--sql repository bbs-ui--forum-query) 6))))

(defun bbs-ui--collapse-posts (versions)
  "Collapse forum VERSIONS into logical posts and threads."
  (let ((by-rid (make-hash-table :test #'eql))
        (logical-cache (make-hash-table :test #'eql))
        (groups (make-hash-table :test #'eql))
        (aliases (make-hash-table :test #'equal))
        logical-posts)
    (dolist (version versions)
      (puthash (plist-get version :rid) version by-rid))
    (cl-labels
        ((logical-rid
          (rid &optional seen)
          (or (gethash rid logical-cache)
              (let* ((version (gethash rid by-rid))
                     (previous (and version (plist-get version :previous-rid)))
                     (logical
                      (if (and previous (> previous 0) (not (memq rid seen)))
                          (logical-rid previous (cons rid seen))
                        rid)))
                (puthash rid logical logical-cache)
                logical))))
      (dolist (version versions)
        (let* ((logical (logical-rid (plist-get version :rid)))
               (existing (gethash logical groups)))
          (puthash logical (cons version existing) groups)))
      (maphash
       (lambda (logical history)
         (setq history (sort history
                             (lambda (a b)
                               (if (= (plist-get a :time) (plist-get b :time))
                                   (< (plist-get a :rid) (plist-get b :rid))
                                 (< (plist-get a :time) (plist-get b :time))))))
         (let* ((base (or (gethash logical by-rid) (car history)))
                (current (car (last history)))
                (post (copy-sequence current)))
           (setq post (plist-put post :logical-rid logical)
                 post (plist-put post :logical-id (plist-get base :uuid))
                 post (plist-put post :history history)
                 post (plist-put post :edited (> (length history) 1))
                 post (plist-put post :deleted
                                 (string-empty-p (plist-get current :body))))
           (dolist (version history)
             (puthash (plist-get version :uuid) (plist-get base :uuid) aliases))
           (push post logical-posts)))
       groups))
    (dolist (post logical-posts)
      (let* ((root-version (gethash (plist-get post :root-rid) by-rid))
             (root-id (and root-version
                           (gethash (plist-get root-version :uuid) aliases)))
             (irt (plist-get post :irt)))
        (setq post (plist-put post :thread-id
                              (or root-id (plist-get post :logical-id)))
              post (plist-put post :reply-to (and irt (gethash irt aliases))))))
    (list logical-posts aliases)))

(defun bbs-ui--jget (key object)
  "Get KEY from JSON alist OBJECT regardless of key representation."
  (or (alist-get key object)
      (alist-get (if (symbolp key) (symbol-name key) (intern-soft key)) object nil nil
                 #'equal)
      (alist-get (if (stringp key) key (symbol-name key)) object nil nil #'equal)))

(defun bbs-ui--optional-json (repository name)
  "Read unversioned JSON NAME locally from REPOSITORY, or return nil."
  (pcase-let ((`(,code ,output)
               (bbs-ui--call "uv" "cat" "-R" repository name)))
    (when (zerop code)
      (condition-case nil
          (json-parse-string output :object-type 'alist :array-type 'list
                             :null-object nil :false-object nil)
        (error nil)))))

(defun bbs-ui--thread-metadata (root-id metadata)
  "Return optional thread data for ROOT-ID from METADATA."
  (and metadata
       (bbs-ui--jget root-id (bbs-ui--jget 'threads metadata))))

(defun bbs-ui--rank-for (user ranks)
  "Return USER's optional Copland rank from RANKS."
  (or (and ranks (bbs-ui--jget user (bbs-ui--jget 'users ranks))) "node"))

(defun bbs-ui--build-threads (posts forum-meta ranks)
  "Build logical threads from POSTS and optional FORUM-META and RANKS."
  (let ((groups (make-hash-table :test #'equal))
        threads)
    (dolist (post posts)
      (let ((root (plist-get post :thread-id)))
        (puthash root (cons post (gethash root groups)) groups)))
    (maphash
     (lambda (root-id members)
       (let* ((sorted (sort members
                            (lambda (a b) (< (plist-get a :time)
                                             (plist-get b :time)))))
              (root (or (cl-find root-id sorted
                                 :key (lambda (post) (plist-get post :logical-id))
                                 :test #'equal)
                        (car sorted)))
              (metadata (bbs-ui--thread-metadata root-id forum-meta))
              (updated (apply #'max (mapcar (lambda (post) (plist-get post :time))
                                             sorted))))
         (dolist (post sorted)
           (setq post (plist-put post :rank
                                 (bbs-ui--rank-for (plist-get post :user) ranks))))
         (push (list :id root-id
                     :title (or (plist-get root :title) "Untitled transmission")
                     :root root
                     :posts sorted
                     :updated updated
                     :author (plist-get root :user)
                     :rank (bbs-ui--rank-for (plist-get root :user) ranks)
                     :reply-count (max 0 (1- (length sorted)))
                     :pinned (and metadata (bbs-ui--jget 'pinned metadata))
                     :labels (and metadata (bbs-ui--jget 'labels metadata)))
               threads)))
     groups)
    (sort threads
          (lambda (a b)
            (if (eq (not (plist-get a :pinned)) (not (plist-get b :pinned)))
                (> (plist-get a :updated) (plist-get b :updated))
              (plist-get a :pinned))))))

(defconst bbs-ui--wiki-query
  (concat
   "WITH versions AS ("
   " SELECT substr(e.comment,2) AS page,e.comment,e.mtime,e.user,b.uuid,"
   " content(b.uuid) AS artifact,"
   " row_number() OVER (PARTITION BY substr(e.comment,2)"
   "                    ORDER BY e.mtime DESC,e.objid DESC) AS n"
   " FROM event e JOIN blob b ON b.rid=e.objid"
   " WHERE e.type='w' AND substr(e.comment,1,1) IN('+',':','-')"
   ") SELECT hex(page),hex(coalesce(user,'')),hex(uuid),hex(artifact)"
   " FROM versions WHERE n=1 AND substr(comment,1,1) IN('+',':')"
   " ORDER BY page COLLATE nocase;")
  "Read-only query used to load current wiki pages.")

(defun bbs-ui--load-wiki (repository)
  "Load current wiki pages from REPOSITORY."
  (mapcar
   (lambda (columns)
     (pcase-let ((`(,page-hex ,user-hex ,uuid-hex ,artifact-hex) columns))
       (let* ((artifact (bbs-ui--parse-artifact
                         (bbs-ui--hex-bytes artifact-hex)))
              (date (plist-get artifact :date)))
         (list :name (bbs-ui--hex-decode page-hex)
               :user (bbs-ui--hex-decode user-hex)
               :uuid (bbs-ui--hex-decode uuid-hex)
               :mimetype (plist-get artifact :mimetype)
               :body (plist-get artifact :body)
               :time (bbs-ui--parse-time date)))))
   (bbs-ui--rows (bbs-ui--sql repository bbs-ui--wiki-query) 4)))

(defun bbs-ui--config-value (repository name)
  "Return Fossil configuration NAME from REPOSITORY."
  (let* ((quoted (replace-regexp-in-string "'" "''" name t t))
         (output (bbs-ui--sql
                  repository (format "SELECT hex(value) FROM config WHERE name='%s';"
                                     quoted))))
    (unless (string-empty-p output)
      (bbs-ui--hex-decode (car (split-string output "\n" t))))))

(defun bbs-ui--safe-remote (remote)
  "Remove a password, if any, from REMOTE."
  (if (and remote
           (string-match "\\`\\(https?://[^:/@]+\\):[^@/]+@" remote))
      (replace-match "\\1@" t nil remote)
    remote))

(defun bbs-ui--remote (repository)
  "Return the configured sanitized remote for REPOSITORY."
  (pcase-let ((`(,code ,output) (bbs-ui--call "remote" "-R" repository)))
    (and (zerop code) (not (string-empty-p output)) (not (string= output "off"))
         (bbs-ui--safe-remote output))))

(defun bbs-ui--user (repository)
  "Return the default Fossil user for REPOSITORY."
  (pcase-let ((`(,code ,output)
               (bbs-ui--call "user" "default" "-R" repository)))
    (if (and (zerop code) (not (string-empty-p output))) output "unknown")))

(defun bbs-ui--unsent (repository)
  "Return all unpublished local artifacts in REPOSITORY."
  (mapcar
   (lambda (columns)
     (pcase-let ((`(,uuid-hex ,type-hex ,comment-hex ,user-hex) columns))
       (list :uuid (bbs-ui--hex-decode uuid-hex)
             :type (bbs-ui--hex-decode type-hex)
             :comment (bbs-ui--hex-decode comment-hex)
             :user (bbs-ui--hex-decode user-hex))))
   (bbs-ui--rows
    (bbs-ui--sql
     repository
     (concat
      "SELECT hex(b.uuid),hex(coalesce(e.type,'')),"
      "hex(coalesce(e.comment,'')),hex(coalesce(e.user,'')) "
      "FROM unsent u JOIN blob b ON b.rid=u.rid "
      "LEFT JOIN event e ON e.objid=u.rid ORDER BY u.rid;"))
    4)))

(defun bbs-ui--read-json-file (file)
  "Read FILE as JSON, returning nil for absent or malformed files."
  (when (file-readable-p file)
    (condition-case nil
        (json-parse-string
         (with-temp-buffer
           (insert-file-contents file)
           (buffer-string))
         :object-type 'alist :array-type 'array :null-object nil :false-object nil)
      (error nil))))

(defun bbs-ui--project-local-state (project-code)
  "Load read and saved state for PROJECT-CODE."
  (let* ((data (bbs-ui--read-json-file (bbs-ui--state-path)))
         (projects (bbs-ui--jget 'projects data))
         (project (cl-find project-code projects
                           :key (lambda (entry) (bbs-ui--jget 'code entry))
                           :test #'equal)))
    (list :read (mapcar
                 (lambda (entry)
                   (cons (bbs-ui--jget 'id entry) (bbs-ui--jget 'time entry)))
                 (or (bbs-ui--jget 'read project) nil))
          :saved (append (or (bbs-ui--jget 'saved project) nil) nil))))

(defun bbs-ui--write-json-atomically (file object)
  "Write JSON OBJECT atomically to FILE."
  (make-directory (file-name-directory file) t)
  (let ((temporary (make-temp-file
                    (expand-file-name ".bbs-state-" (file-name-directory file)))))
    (unwind-protect
        (progn
          (with-temp-file temporary
            (insert (json-serialize object :null-object nil :false-object :false))
            (insert "\n"))
          (set-file-modes temporary #o600)
          (rename-file temporary file t))
      (when (file-exists-p temporary)
        (delete-file temporary)))))

(defun bbs-ui--save-project-state (project-code local-state)
  "Persist LOCAL-STATE for PROJECT-CODE."
  (let* ((file (bbs-ui--state-path))
         (data (or (bbs-ui--read-json-file file)
                   '((version . 1) (projects . []))))
         (projects (append (bbs-ui--jget 'projects data) nil))
         (entry `((code . ,project-code)
                  (read . ,(vconcat
                            (mapcar
                             (lambda (cell)
                               `((id . ,(car cell)) (time . ,(cdr cell))))
                             (or (plist-get local-state :read) nil))))
                  (saved . ,(vconcat (or (plist-get local-state :saved) nil)))))
         (found nil)
         next)
    (dolist (project projects)
      (if (equal (bbs-ui--jget 'code project) project-code)
          (progn (push entry next) (setq found t))
        (push project next)))
    (unless found (push entry next))
    (bbs-ui--write-json-atomically
     file `((version . 1) (projects . ,(vconcat (nreverse next)))))))

(defun bbs-ui--avatar-files (repository)
  "Return an alist of username to local avatar cache from REPOSITORY."
  (pcase-let ((`(,code ,output)
               (bbs-ui--call "uv" "list" "-R" repository "--glob" "avatars/*")))
    (let (result)
      (when (zerop code)
        (dolist (line (split-string output "\n" t))
          (when (string-match
                 "\\`\\([[:xdigit:]]+\\).*?[[:space:]]\\(avatars/[^[:space:]]+\\)\\'"
                 line)
            (let* ((hash (match-string 1 line))
                   (uv-name (match-string 2 line))
                   (base (file-name-nondirectory uv-name))
                   (user (file-name-base base))
                   (directory (expand-file-name "avatars" (bbs-ui--cache-path)))
                   (target (expand-file-name
                            (format "%s-%s" (substring hash 0 (min 12 (length hash)))
                                    base)
                            directory)))
              (unless (file-readable-p target)
                (make-directory directory t)
                (pcase-let ((`(,export-code ,_)
                             (bbs-ui--call "uv" "export" "-R" repository
                                           uv-name target)))
                  (unless (zerop export-code)
                    (setq target nil))))
              (when target (push (cons user target) result)))))
        result))))

(defun bbs-ui--profiles (posts wiki ranks avatars)
  "Build profiles from POSTS, WIKI, RANKS and AVATARS."
  (let ((names (make-hash-table :test #'equal))
        result)
    (dolist (post posts) (puthash (plist-get post :user) t names))
    (dolist (page wiki)
      (when (string-match "\\`users/\\(.+\\)\\'" (plist-get page :name))
        (puthash (match-string 1 (plist-get page :name)) t names)))
    (when ranks
      (dolist (entry (bbs-ui--jget 'users ranks))
        (puthash (if (symbolp (car entry)) (symbol-name (car entry)) (car entry))
                 t names)))
    (maphash
     (lambda (name _)
       (let ((page (cl-find (concat "users/" name) wiki
                            :key (lambda (entry) (plist-get entry :name))
                            :test #'equal)))
         (push (list :name name
                     :rank (bbs-ui--rank-for name ranks)
                     :bio (and page (plist-get page :body))
                     :avatar (cdr (assoc-string name avatars t))
                     :posts (cl-count name posts
                                      :key (lambda (post) (plist-get post :user))
                                      :test #'equal))
               result)))
     names)
    (sort result (lambda (a b) (string-lessp (downcase (plist-get a :name))
                                             (downcase (plist-get b :name)))))))

(defun bbs-ui--snapshot (repository &optional previous-state)
  "Build a complete local snapshot of REPOSITORY.
PREVIOUS-STATE contributes current navigation and transient status."
  (setq repository (expand-file-name repository))
  (unless (file-readable-p repository)
    (user-error "Unreadable Fossil repository: %s" repository))
  (unless (executable-find bbs-ui-fossil-program)
    (user-error "Cannot find Fossil executable: %s" bbs-ui-fossil-program))
  (let* ((project (or (bbs-ui--config-value repository "project-name")
                      (file-name-base repository)))
         (project-code (or (bbs-ui--config-value repository "project-code")
                           (secure-hash 'sha256 repository)))
         (versions (bbs-ui--load-forum-versions repository))
         (collapsed (bbs-ui--collapse-posts versions))
         (posts (car collapsed))
         (forum-meta (bbs-ui--optional-json repository "bbs/forum-meta.json"))
         (ranks (bbs-ui--optional-json repository "bbs/ranks.json"))
         (wiki (bbs-ui--load-wiki repository))
         (avatars (bbs-ui--avatar-files repository))
         (threads (bbs-ui--build-threads posts forum-meta ranks))
         (profiles (bbs-ui--profiles posts wiki ranks avatars))
         (local-state (or (and previous-state (plist-get previous-state :local-state))
                          (bbs-ui--project-local-state project-code)))
         (view (or (and previous-state (plist-get previous-state :view)) 'board))
         (selected (or (and previous-state (plist-get previous-state :selected-root))
                       (and threads (plist-get (car threads) :id)))))
    (list :repository repository
          :project project
          :project-code project-code
          :remote (bbs-ui--remote repository)
          :user (bbs-ui--user repository)
          :versions versions
          :posts posts
          :threads threads
          :wiki wiki
          :profiles profiles
          :forum-meta forum-meta
          :ranks ranks
          :local-state local-state
          :view view
          :view-id (and previous-state (plist-get previous-state :view-id))
          :selected-root selected
          :selected-post
          (or (and previous-state (plist-get previous-state :selected-post))
              (and threads
                   (plist-get (plist-get (car threads) :root) :logical-id)))
          :selected-wiki
          (or (and previous-state (plist-get previous-state :selected-wiki))
              (and wiki (plist-get (car wiki) :name)))
          :selected-profile
          (or (and previous-state (plist-get previous-state :selected-profile))
              (and profiles (plist-get (car profiles) :name)))
          :selected-saved (and previous-state (plist-get previous-state :selected-saved))
          :selected-search (and previous-state (plist-get previous-state :selected-search))
          :active-pane (or (and previous-state (plist-get previous-state :active-pane))
                           'list)
          :board-offset (or (and previous-state (plist-get previous-state :board-offset)) 0)
          :thread-offset (or (and previous-state (plist-get previous-state :thread-offset)) 0)
          :wiki-offset (or (and previous-state (plist-get previous-state :wiki-offset)) 0)
          :users-offset (or (and previous-state (plist-get previous-state :users-offset)) 0)
          :saved-offset (or (and previous-state (plist-get previous-state :saved-offset)) 0)
          :search-offset (or (and previous-state (plist-get previous-state :search-offset)) 0)
          :body-offset (or (and previous-state (plist-get previous-state :body-offset)) 0)
          :query (and previous-state (plist-get previous-state :query))
          :unsent (bbs-ui--unsent repository)
          :busy (and previous-state (plist-get previous-state :busy))
          :connection (or (and previous-state (plist-get previous-state :connection))
                          'local)
          :error nil
          :notice (and previous-state (plist-get previous-state :notice))
          :diagnostic-id (and previous-state (plist-get previous-state :diagnostic-id))
          :height (or (and previous-state (plist-get previous-state :height)) 32))))

(defun bbs-ui--find-thread (id)
  "Find thread ID in current TextUI state."
  (cl-find id (plist-get textui-state :threads)
           :key (lambda (thread) (plist-get thread :id)) :test #'equal))

(defun bbs-ui--find-post (id)
  "Find logical post ID in current TextUI state."
  (cl-find id (plist-get textui-state :posts)
           :key (lambda (post) (plist-get post :logical-id)) :test #'equal))

(defun bbs-ui--find-wiki (name)
  "Find wiki page NAME in current TextUI state."
  (cl-find name (plist-get textui-state :wiki)
           :key (lambda (page) (plist-get page :name)) :test #'equal))

(defun bbs-ui--find-profile (name)
  "Find profile NAME in current TextUI state."
  (cl-find name (plist-get textui-state :profiles)
           :key (lambda (profile) (plist-get profile :name)) :test #'equal))

(defun bbs-ui--read-time (thread-id)
  "Return last read timestamp for THREAD-ID."
  (let ((read (plist-get (plist-get textui-state :local-state) :read)))
    (cdr (assoc-string thread-id read t))))

(defun bbs-ui--unread-p (thread)
  "Return non-nil when THREAD is newer than its local read marker."
  (< (or (bbs-ui--read-time (plist-get thread :id)) 0)
     (plist-get thread :updated)))

(defun bbs-ui--persist-local-state (local-state)
  "Persist LOCAL-STATE and install it in the current BBS buffer."
  (bbs-ui--save-project-state (plist-get textui-state :project-code) local-state)
  (textui-set-state (current-buffer) :local-state local-state))

(defun bbs-ui--mark-thread-read (thread)
  "Mark THREAD read through its latest local update."
  (let* ((local (copy-tree (plist-get textui-state :local-state)))
         (read (copy-tree (plist-get local :read)))
         (id (plist-get thread :id))
         (cell (assoc-string id read t)))
    (if cell
        (setcdr cell (plist-get thread :updated))
      (push (cons id (plist-get thread :updated)) read))
    (setq local (plist-put local :read read))
    (bbs-ui--persist-local-state local)))

(defun bbs-ui--saved-p (id)
  "Return non-nil when logical post ID is saved."
  (member id (plist-get (plist-get textui-state :local-state) :saved)))

(defun bbs-ui-toggle-save ()
  "Toggle the post or thread at point in Saved."
  (interactive)
  (let* ((target (or (bbs-ui--semantic-target)
                     (cons (bbs-ui--kind-at-point) (bbs-ui--id-at-point))))
         (kind (car target))
         (id (cdr target))
         (post-id
          (pcase kind
            ('post id)
            ('thread (and-let* ((thread (bbs-ui--find-thread id)))
                       (plist-get (plist-get thread :root) :logical-id)))
            (_ nil))))
    (unless post-id (user-error "No post at point"))
    (let* ((local (copy-tree (plist-get textui-state :local-state)))
           (saved (copy-sequence (plist-get local :saved))))
      (setq saved (if (member post-id saved) (delete post-id saved)
                    (cons post-id saved))
            local (plist-put local :saved saved))
      (bbs-ui--persist-local-state local)
      (bbs-ui--set-notice
       (format "%s TRANSMISSION %s"
               (if (member post-id saved) "ARCHIVED" "REMOVED FROM ARCHIVE")
               (substring post-id 0 (min 10 (length post-id))))))))

(defun bbs-ui--ago (timestamp)
  "Format TIMESTAMP as compact relative time."
  (let ((seconds (max 0 (- (float-time) (or timestamp 0)))))
    (cond ((< seconds 60) "now")
          ((< seconds 3600) (format "%dm" (/ seconds 60)))
          ((< seconds 86400) (format "%dh" (/ seconds 3600)))
          ((< seconds (* 86400 30)) (format "%dd" (/ seconds 86400)))
          (t (format-time-string "%Y-%m-%d" (seconds-to-time timestamp))))))

(defun bbs-ui--fit (text width &optional face right)
  "Make TEXT exactly WIDTH cells wide and optionally apply FACE.
When RIGHT is non-nil, right-align the value.  Newlines are always flattened."
  (let* ((width (max 0 width))
         (text (bbs-ui--single-line-string text))
         (value (truncate-string-to-width text width nil nil "…"))
         (space (make-string (max 0 (- width (string-width value))) ?\s))
         (value (if right (concat space value) (concat value space))))
    (if face (propertize value 'face face) value)))

(defun bbs-ui--line (text width &optional face)
  "Return one fixed-width TextUI line containing TEXT."
  (list :type :text :value (bbs-ui--fit text width face)
        :layout (list :width width :min-width (min width 8) :grow 0)))

(defun bbs-ui--column (children width)
  "Return a gapless TextUI column of CHILDREN at WIDTH."
  (list :type :flex :direction :column :gap 0 :children children
        :layout (list :width width :min-width (min width 8) :grow 0)))

(defun bbs-ui--row (text kind id action width &optional selected)
  "Return a one-line BBS button for TEXT, KIND, ID and ACTION at WIDTH."
  (let ((value (bbs-ui--fit text width)))
    (list :type 'bbs-ui-row
          :value value
          :button-face (if selected 'bbs-ui-selected 'default)
          :bbs-ui-kind kind :bbs-ui-id id
          :layout (list :width width :focus-id (list kind id))
          :action (lambda (&rest _) (funcall action kind id)))))

(defun bbs-ui--rank-chip (rank)
  "Format RANK as a compact Copland access chip."
  (propertize (format "<%s>" (upcase (or rank "node")))
              'face (pcase (downcase (or rank "node"))
                      ("wired" 'bbs-ui-magenta)
                      ("sysop" 'bbs-ui-yellow)
                      ("operator" 'bbs-ui-green)
                      (_ 'bbs-ui-cyan))))

(defun bbs-ui--label-text (labels)
  "Format thread LABELS as compact uppercase tags."
  (if labels
      (mapconcat (lambda (label)
                   (propertize (format "[%s]" (upcase (format "%s" label)))
                               'face 'bbs-ui-magenta))
                 labels " ")
    ""))

(defun bbs-ui--markup-text (body mimetype)
  "Fontify BODY according to MIMETYPE without changing its source form."
  (setq body (or body ""))
  (cond
   ((string= mimetype "text/x-markdown")
    (with-temp-buffer
      (insert body)
      (delay-mode-hooks (markdown-mode))
      (font-lock-ensure)
      (buffer-substring (point-min) (point-max))))
   ((string= mimetype "text/x-fossil-wiki")
    (let ((copy (copy-sequence body)))
      (dolist (regexp '("^==+ .* ==+$" "^[-*] " "\\[https?://[^]]+\\]"))
        (let ((start 0))
          (while (string-match regexp copy start)
            (add-face-text-property (match-beginning 0) (match-end 0)
                                    'bbs-ui-cyan nil copy)
            (setq start (match-end 0)))))
      copy))
   (t body)))

(defun bbs-ui--wrapped-lines (text width)
  "Wrap TEXT into display lines no wider than WIDTH."
  (let ((width (max 8 width)) result)
    (dolist (source (split-string (or text "") "\n" nil))
      (if (string-empty-p source)
          (push "" result)
        (with-temp-buffer
          (insert source)
          (let ((fill-column width)
                (sentence-end-double-space nil))
            (fill-region (point-min) (point-max)))
          (dolist (line (split-string (buffer-string) "\n" nil))
            (push line result)))))
    (or (nreverse result) (list ""))))

(defun bbs-ui--body-window (text width height &optional offset-key)
  "Return a HEIGHT-line window over TEXT wrapped to WIDTH.
OFFSET-KEY names the state entry used for scrolling."
  (let* ((height (max 0 height))
         (lines (bbs-ui--wrapped-lines text width))
         (total (length lines))
         (maximum (max 0 (- total height)))
         (offset (min maximum (max 0 (or (and offset-key
                                               (plist-get textui-state offset-key))
                                          0))))
         (end (min total (+ offset height)))
         (visible (cl-subseq lines offset end)))
    (when offset-key
      (setq textui-state (plist-put (copy-sequence textui-state)
                                    offset-key offset)))
    (list :lines (append visible (make-list (max 0 (- height (length visible))) ""))
          :start offset :end end :total total)))

(defun bbs-ui--viewport (items id-function selection-key offset-key capacity)
  "Return a bounded slice of ITEMS and keep its selection visible."
  (let* ((capacity (max 1 capacity))
         (total (length items))
         (selected (plist-get textui-state selection-key))
         (index (and selected
                     (cl-position selected items :key id-function :test #'equal))))
    (when (and items (null index))
      (setq index 0 selected (funcall id-function (car items)))
      (setq textui-state (plist-put (copy-sequence textui-state)
                                    selection-key selected)))
    (let* ((maximum (max 0 (- total capacity)))
           (offset (min maximum (max 0 (or (plist-get textui-state offset-key) 0)))))
      (when index
        (cond ((< index offset) (setq offset index))
              ((>= index (+ offset capacity))
               (setq offset (- (1+ index) capacity)))))
      (setq offset (min maximum (max 0 offset)))
      (setq textui-state (plist-put (copy-sequence textui-state) offset-key offset))
      (list :items (cl-subseq items offset (min total (+ offset capacity)))
            :selected selected :start offset
            :end (min total (+ offset capacity)) :total total))))

(defun bbs-ui--bar-line (left text fill right width &optional face)
  "Build a fixed WIDTH BBS rail using LEFT, TEXT, FILL and RIGHT."
  (let* ((inner (max 0 (- width (string-width left) (string-width right))))
         (text (truncate-string-to-width (bbs-ui--single-line-string text)
                                         inner nil nil "…"))
         (fill-count (max 0 (- inner (string-width text))))
         (value (concat left text (make-string fill-count fill) right)))
    (bbs-ui--line value width (or face 'bbs-ui-frame))))

(defun bbs-ui--view-name ()
  "Return the current screen's BBS-style name."
  (pcase (plist-get textui-state :view)
    ('board "BOARD / MESSAGE BASE")
    ('thread "THREAD / MESSAGE READER")
    ('wiki "WIKI / FILE INDEX")
    ('wiki-page "WIKI / DOCUMENT READER")
    ('users "USERS / NODE DIRECTORY")
    ('profile "USER / PROFILE")
    ('saved "ARCHIVE / SAVED TRANSMISSIONS")
    ('search "SEARCH / LOCAL INDEX")
    (_ "BOARD / MESSAGE BASE")))

(defun bbs-ui--status-chip ()
  "Return the current link status as a short string."
  (pcase (plist-get textui-state :connection)
    ('pulling "PULLING") ('online "ONLINE") ('offline "OFFLINE") (_ "LOCAL")))

(defun bbs-ui--header (width)
  "Return the persistent three-line BBS header for WIDTH."
  (let* ((unsent (length (plist-get textui-state :unsent)))
         (identity (format " FEED://BBS  %-22s  NODE @%-14s  %-7s%s "
                           (or (plist-get textui-state :project) "unknown")
                           (or (plist-get textui-state :user) "anonymous")
                           (bbs-ui--status-chip)
                           (if (> unsent 0) (format "  QUEUE:%d" unsent) ""))))
    (list
     (bbs-ui--bar-line "╔═" " COPLAND.SYSTEMS // PRIVATE PACKET NETWORK " ?═ "═╗"
                       width 'bbs-ui-logo)
     (bbs-ui--bar-line "║" identity ?\s "║" width 'bbs-ui-bar)
     (bbs-ui--bar-line "╠═" (concat " " (bbs-ui--view-name) " ") ?═ "═╣"
                       width 'bbs-ui-cyan))))

(defun bbs-ui--identicon-lines (name rows width)
  "Return a deterministic mirrored block identicon for NAME."
  (let* ((hash (secure-hash 'sha1 (downcase (or name "?"))))
         (half (max 1 (/ width 2)))
         result)
    (cl-loop for scanline below rows do
      (let (left)
        (dotimes (column half)
          (let* ((index (% (+ (* scanline half) column) (length hash)))
                 (on (>= (string-to-number (substring hash index (1+ index)) 16) 8)))
            (push (if on "█" " ") left)))
        (setq left (nreverse left))
        (let* ((mirror (reverse (if (cl-oddp width) (butlast left) left)))
               (line (apply #'concat (append left mirror))))
          (push (propertize (bbs-ui--fit line width) 'face 'bbs-ui-magenta)
                result))))
    (nreverse result)))

(defun bbs-ui--avatar-element (profile rows width)
  "Return PROFILE's avatar in ROWS by WIDTH cells with an identicon fallback."
  (let ((file (and profile (plist-get profile :avatar)))
        (name (or (and profile (plist-get profile :name)) "unknown")))
    (if (and (display-graphic-p) file (file-readable-p file))
        (list :type :image :file file :rows rows
              ;; TextUI inserts :alt into an unibyte image-slice placeholder.
              ;; Its final image width may be narrower than WIDTH, so even an
              ;; already fitted label can be truncated a second time with a
              ;; Unicode ellipsis.  One ASCII cell is safe at every possible
              ;; slice width; the complete name is rendered beside the image.
              :alt "@"
              :layout (list :width width :min-width width :grow 0))
      (list :type :text
            :value (mapconcat #'identity
                              (bbs-ui--identicon-lines name rows width) "\n")
            :layout (list :width width :min-width width :grow 0)))))

(defun bbs-ui--identity-block (profile details width rows avatar-width)
  "Render PROFILE avatar and DETAILS in a fixed-size identity block."
  (let* ((avatar-width (min avatar-width (max 5 (/ width 3))))
         (detail-width (max 1 (- width avatar-width 1)))
         (details (append (seq-take details rows)
                          (make-list (max 0 (- rows (length details))) ""))))
    (list :type :flex :direction :row :gap 1
          :layout (list :width width :min-width width :grow 0)
          :children
          (list (bbs-ui--avatar-element profile rows avatar-width)
                (bbs-ui--column
                 (mapcar (lambda (line) (bbs-ui--line line detail-width)) details)
                 detail-width)))))

(defun bbs-ui--position-line (slice width noun)
  "Render SLICE position at WIDTH using NOUN."
  (let ((total (plist-get slice :total))
        (start (plist-get slice :start))
        (end (plist-get slice :end)))
    (bbs-ui--line
     (if (> total 0)
         (format " ── %s %d–%d / %d " noun (1+ start) end total)
       (format " ── NO %s " noun))
     width 'bbs-ui-muted)))

(defun bbs-ui--thread-subject (thread)
  "Return a useful one-line subject for THREAD, including untitled posts."
  (let ((title (string-trim (or (plist-get thread :title) ""))))
    (if (not (string-empty-p title))
        title
      (let* ((root (plist-get thread :root))
             (body (string-trim (bbs-ui--single-line-string
                                 (and root (plist-get root :body)))))
             (body (replace-regexp-in-string
                    "\\`[[:space:]#>*_-]+" "" body)))
        (if (string-empty-p body) "(no subject)" body)))))

(defun bbs-ui--thread-header (width)
  "Build the dense board column header for WIDTH."
  (let* ((wide (>= width 56))
         (author-width (if wide 12 0))
         (fixed (+ 2 1 author-width (if wide 1 0) 1 2 1 6))
         (title-width (max 6 (- width fixed))))
    (concat (bbs-ui--fit "ST" 2 'bbs-ui-cyan) " "
            (bbs-ui--fit "SUBJECT" title-width 'bbs-ui-cyan)
            (if wide
                (concat " " (bbs-ui--fit "FROM" author-width 'bbs-ui-cyan))
              "")
            " " (bbs-ui--fit "RE" 2 'bbs-ui-cyan t)
            " " (bbs-ui--fit "AGE" 6 'bbs-ui-cyan t))))

(defun bbs-ui--thread-line (thread width)
  "Build one compact board line for THREAD fitting WIDTH."
  (let* ((unread (bbs-ui--unread-p thread))
         (flag (concat (if (plist-get thread :pinned) "◆" " ")
                       (if unread "●" "·")))
         (replies (format "%2d" (plist-get thread :reply-count)))
         (age (format "%6s" (bbs-ui--ago (plist-get thread :updated))))
         (author (if (>= width 56)
                     (format "%-12s" (truncate-string-to-width
                                      (plist-get thread :author) 12 nil nil "…"))
                   ""))
         (fixed (+ 2 1 (string-width author) (if (string-empty-p author) 0 1)
                   1 2 1 6))
         (title-width (max 6 (- width fixed)))
         (title (bbs-ui--fit (bbs-ui--thread-subject thread) title-width)))
    (concat (propertize flag 'face (if unread 'bbs-ui-yellow 'bbs-ui-muted))
            " " title
            (unless (string-empty-p author)
              (concat " " (propertize author 'face 'bbs-ui-blue)))
            " " (propertize replies 'face 'bbs-ui-magenta)
            " " (propertize age 'face 'bbs-ui-muted))))

(defun bbs-ui--board-list-pane (width height)
  "Render the bounded board lightbar at WIDTH by HEIGHT."
  (let* ((threads (seq-take (plist-get textui-state :threads) bbs-ui-board-limit))
         (capacity (max 1 (- height 2)))
         (slice (bbs-ui--viewport threads
                                  (lambda (thread) (plist-get thread :id))
                                  :selected-root :board-offset capacity))
         (selected (plist-get slice :selected))
         (rows
          (mapcar
           (lambda (thread)
             (let ((id (plist-get thread :id)))
               (bbs-ui--row (bbs-ui--thread-line thread width)
                            'thread id #'bbs-ui--activate-row width
                            (equal id selected))))
           (plist-get slice :items))))
    (bbs-ui--column
     (append
      (list (bbs-ui--line
             (bbs-ui--thread-header width) width))
      rows
      (make-list (max 0 (- capacity (length rows))) (bbs-ui--line "" width))
      (list (bbs-ui--position-line slice width "TRANSMISSIONS")))
     width)))

(defun bbs-ui--post-details (post thread)
  "Return five identity lines describing POST in THREAD."
  (let* ((posts (and thread (plist-get thread :posts)))
         (index (and post (cl-position post posts :test #'eq))))
    (list
     (format "%s  %s" (bbs-ui--rank-chip (plist-get post :rank))
             (propertize (or (plist-get post :user) "unknown") 'face 'bbs-ui-blue))
     (format "MESSAGE  %d / %d" (if index (1+ index) 1) (max 1 (length posts)))
     (format "DATE     %s" (bbs-ui--ago (plist-get post :time)))
     (format "STATE    %s%s"
             (if (plist-get post :edited)
                 (format "EDITED ×%d" (max 1 (1- (length (plist-get post :history)))))
               "ORIGINAL")
             (if (bbs-ui--saved-p (plist-get post :logical-id)) "  ★ SAVED" ""))
     (format "ID       %s" (substring (or (plist-get post :logical-id) "----------")
                                      0 (min 10 (length (or (plist-get post :logical-id)
                                                            "----------"))))))))

(defun bbs-ui--message-pane (post thread width height &optional heading)
  "Render POST from THREAD as a fixed BBS reader pane."
  (if (not post)
      (bbs-ui--column
       (cons (bbs-ui--line " NO MESSAGE SELECTED" width 'bbs-ui-muted)
             (make-list (max 0 (1- height)) (bbs-ui--line "" width))) width)
    (let* ((profile (bbs-ui--find-profile (plist-get post :user)))
           (body (if (plist-get post :deleted)
                     (propertize "[transmission deleted]" 'face 'bbs-ui-deleted)
                   (bbs-ui--markup-text (plist-get post :body)
                                        (plist-get post :mimetype))))
           (body-height (max 0 (- height 7)))
           (window (bbs-ui--body-window body width body-height :body-offset))
           (range (format " BODY · LINES %d–%d / %d "
                          (if (> (plist-get window :total) 0)
                              (1+ (plist-get window :start)) 0)
                          (plist-get window :end) (plist-get window :total))))
      (bbs-ui--column
       (append
        (list (bbs-ui--line
               (concat " " (or heading "MESSAGE") " // "
                       (if thread (bbs-ui--thread-subject thread) "UNTITLED"))
               width 'bbs-ui-yellow)
              (bbs-ui--identity-block profile (bbs-ui--post-details post thread)
                                      width 5 11)
              (bbs-ui--line range width 'bbs-ui-frame))
        (mapcar (lambda (line) (bbs-ui--line line width))
                (plist-get window :lines)))
       width))))

(defun bbs-ui--board-view (width height)
  "Render the Board at WIDTH by HEIGHT."
  (let* ((threads (plist-get textui-state :threads))
         (selected (plist-get textui-state :selected-root))
         (thread (cl-find selected threads
                          :key (lambda (item) (plist-get item :id)) :test #'equal)))
    (if (>= width bbs-ui-wide-layout-width)
        (let* ((left (max 40 (floor (* (1- width) 0.43))))
               (right (- width left 1)))
          (list :type :flex :direction :row :gap 1
                :layout (list :width width :min-width width)
                :children
                (list (bbs-ui--board-list-pane left height)
                      (bbs-ui--message-pane (and thread (plist-get thread :root))
                                            thread right height "PREVIEW"))))
      (bbs-ui--board-list-pane width height))))

(defun bbs-ui--post-depth (post posts)
  "Return POST nesting depth among POSTS, bounded for display."
  (let ((parent (plist-get post :reply-to)) (depth 0) seen)
    (while (and parent (< depth 6) (not (member parent seen)))
      (push parent seen)
      (setq depth (1+ depth))
      (setq parent
            (and-let* ((match (cl-find parent posts
                                       :key (lambda (item)
                                              (plist-get item :logical-id))
                                       :test #'equal)))
              (plist-get match :reply-to))))
    depth))

(defun bbs-ui--post-tree-line (post posts width)
  "Format POST as one compact reply-tree row."
  (let* ((depth (bbs-ui--post-depth post posts))
         (prefix (if (zerop depth) "◆ "
                   (concat (make-string (* 2 (1- depth)) ?\s) "└─")))
         (age (format "%6s" (bbs-ui--ago (plist-get post :time))))
         (saved (if (bbs-ui--saved-p (plist-get post :logical-id)) "★" " "))
         (name-width (max 5 (- width (string-width prefix) 9)))
         (name (bbs-ui--fit (plist-get post :user) name-width)))
    (concat (propertize prefix 'face 'bbs-ui-frame)
            (propertize saved 'face 'bbs-ui-yellow) " "
            (propertize name 'face 'bbs-ui-blue) " "
            (propertize age 'face 'bbs-ui-muted))))

(defun bbs-ui--thread-tree-pane (thread width height)
  "Render THREAD's bounded reply tree."
  (let* ((posts (plist-get thread :posts))
         (capacity (max 1 (- height 2)))
         (slice (bbs-ui--viewport posts
                                  (lambda (post) (plist-get post :logical-id))
                                  :selected-post :thread-offset capacity))
         (selected (plist-get slice :selected))
         (rows
          (mapcar
           (lambda (post)
             (let ((id (plist-get post :logical-id)))
               (bbs-ui--row (bbs-ui--post-tree-line post posts width)
                            'post id #'bbs-ui--activate-row width
                            (equal id selected))))
           (plist-get slice :items))))
    (bbs-ui--column
     (append (list (bbs-ui--line " REPLY TREE // AUTHOR                 AGE"
                                      width 'bbs-ui-cyan))
             rows
             (make-list (max 0 (- capacity (length rows)))
                        (bbs-ui--line "" width))
             (list (bbs-ui--position-line slice width "MESSAGES")))
     width)))

(defun bbs-ui--thread-view (width height id)
  "Render thread ID at WIDTH by HEIGHT."
  (let ((thread (bbs-ui--find-thread id)))
    (if (not thread)
        (bbs-ui--column
         (cons (bbs-ui--line " THREAD NOT FOUND" width 'bbs-ui-error)
               (make-list (max 0 (1- height)) (bbs-ui--line "" width))) width)
      (let* ((posts (plist-get thread :posts))
             (selected (or (bbs-ui--find-post (plist-get textui-state :selected-post))
                           (plist-get thread :root))))
        (unless (member selected posts)
          (setq selected (plist-get thread :root)
                textui-state (plist-put (copy-sequence textui-state)
                                        :selected-post
                                        (plist-get selected :logical-id))))
        (if (>= width bbs-ui-wide-layout-width)
            (let* ((left (max 31 (floor (* (1- width) 0.34))))
                   (right (- width left 1)))
              (list :type :flex :direction :row :gap 1
                    :layout (list :width width :min-width width)
                    :children
                    (list (bbs-ui--thread-tree-pane thread left height)
                          (bbs-ui--message-pane selected thread right height))))
          (bbs-ui--message-pane selected thread width height))))))

(defun bbs-ui--wiki-line (page width)
  "Format wiki PAGE as a dense file-index line."
  (let* ((name (plist-get page :name))
         (age (format "%10s" (bbs-ui--ago (plist-get page :time))))
         (author (if (>= width 58)
                     (format "%-12s" (truncate-string-to-width
                                      (plist-get page :user) 12 nil nil "…"))
                   ""))
         (name-width (max 8 (- width 3 10 (if (string-empty-p author) 0 13))))
         (depth (max 0 (1- (length (split-string name "/" t)))))
         (prefix (if (zerop depth) "◆ " (concat (make-string (min 4 depth) ?\s) "└─"))))
    (concat (propertize prefix 'face 'bbs-ui-frame)
            (bbs-ui--fit name name-width 'bbs-ui-blue)
            (unless (string-empty-p author)
              (concat " " (propertize author 'face 'bbs-ui-cyan)))
            " " (propertize age 'face 'bbs-ui-muted))))

(defun bbs-ui--document-pane (page width height &optional heading)
  "Render wiki PAGE as a fixed document reader."
  (if (not page)
      (bbs-ui--column
       (cons (bbs-ui--line " DOCUMENT NOT FOUND" width 'bbs-ui-error)
             (make-list (max 0 (1- height)) (bbs-ui--line "" width))) width)
    (let* ((body-height (max 0 (- height 3)))
           (body (bbs-ui--markup-text (plist-get page :body)
                                      (plist-get page :mimetype)))
           (window (bbs-ui--body-window body width body-height :body-offset)))
      (bbs-ui--column
       (append
        (list (bbs-ui--line (format " %s // %s" (or heading "WIKI")
                                    (plist-get page :name)) width 'bbs-ui-yellow)
              (bbs-ui--line
               (format " AUTHOR %-16s  UPDATED %-10s  FORMAT %s"
                       (plist-get page :user) (bbs-ui--ago (plist-get page :time))
                       (or (plist-get page :mimetype) "text/plain"))
               width 'bbs-ui-muted)
              (bbs-ui--line
               (format " BODY · LINES %d–%d / %d "
                       (if (> (plist-get window :total) 0)
                           (1+ (plist-get window :start)) 0)
                       (plist-get window :end) (plist-get window :total))
               width 'bbs-ui-frame))
        (mapcar (lambda (line) (bbs-ui--line line width))
                (plist-get window :lines)))
       width))))

(defun bbs-ui--wiki-list-pane (width height)
  "Render the bounded wiki file index."
  (let* ((pages (plist-get textui-state :wiki))
         (capacity (max 1 (- height 2)))
         (slice (bbs-ui--viewport pages
                                  (lambda (page) (plist-get page :name))
                                  :selected-wiki :wiki-offset capacity))
         (selected (plist-get slice :selected))
         (rows (mapcar
                (lambda (page)
                  (let ((id (plist-get page :name)))
                    (bbs-ui--row (bbs-ui--wiki-line page width)
                                 'wiki-page id #'bbs-ui--activate-row width
                                 (equal id selected))))
                (plist-get slice :items))))
    (bbs-ui--column
     (append (list (bbs-ui--line " TYPE PAGE                              AUTHOR       UPDATED"
                                      width 'bbs-ui-cyan))
             rows
             (make-list (max 0 (- capacity (length rows))) (bbs-ui--line "" width))
             (list (bbs-ui--position-line slice width "PAGES"))) width)))

(defun bbs-ui--wiki-view (width height)
  "Render the wiki index and optional document preview."
  (let* ((pages (plist-get textui-state :wiki))
         (page (cl-find (plist-get textui-state :selected-wiki) pages
                        :key (lambda (item) (plist-get item :name)) :test #'equal)))
    (if (>= width bbs-ui-wide-layout-width)
        (let* ((left (max 38 (floor (* (1- width) 0.42))))
               (right (- width left 1)))
          (list :type :flex :direction :row :gap 1
                :layout (list :width width :min-width width)
                :children (list (bbs-ui--wiki-list-pane left height)
                                (bbs-ui--document-pane page right height "PREVIEW"))))
      (bbs-ui--wiki-list-pane width height))))

(defun bbs-ui--wiki-page-view (width height name)
  "Render wiki page NAME at WIDTH by HEIGHT."
  (bbs-ui--document-pane (bbs-ui--find-wiki name) width height))

(defun bbs-ui--profile-activity (profile)
  "Return a compact local activity document for PROFILE."
  (let* ((name (plist-get profile :name))
         (posts (sort (cl-remove-if-not
                       (lambda (post) (equal name (plist-get post :user)))
                       (copy-sequence (plist-get textui-state :posts)))
                      (lambda (a b) (> (plist-get a :time) (plist-get b :time)))))
         (pages (sort (cl-remove-if-not
                       (lambda (page) (equal name (plist-get page :user)))
                       (copy-sequence (plist-get textui-state :wiki)))
                      (lambda (a b) (> (plist-get a :time) (plist-get b :time)))))
         lines)
    (push "" lines)
    (push "RECENT ACTIVITY" lines)
    (dolist (post (seq-take posts 5))
      (let ((thread (bbs-ui--find-thread (plist-get post :thread-id))))
        (push (format "F  %-8s  %s" (bbs-ui--ago (plist-get post :time))
                      (if thread (bbs-ui--thread-subject thread) "untitled")) lines)))
    (dolist (page (seq-take pages 3))
      (push (format "W  %-8s  %s" (bbs-ui--ago (plist-get page :time))
                    (plist-get page :name)) lines))
    (when (= (length lines) 2) (push "No activity in this clone." lines))
    (mapconcat #'identity (nreverse lines) "\n")))

(defun bbs-ui--profile-document (profile)
  "Return PROFILE bio followed by locally derived activity."
  (concat (or (plist-get profile :bio) "No profile page in this clone.")
          (bbs-ui--profile-activity profile)))

(defun bbs-ui--profile-pane (profile width height &optional heading)
  "Render PROFILE as a fixed profile reader."
  (if (not profile)
      (bbs-ui--column
       (cons (bbs-ui--line " PROFILE NOT FOUND" width 'bbs-ui-error)
             (make-list (max 0 (1- height)) (bbs-ui--line "" width))) width)
    (let* ((rows (min 7 (max 3 (- height 4))))
           (body-height (max 0 (- height rows 2)))
           (window (bbs-ui--body-window (bbs-ui--profile-document profile)
                                        width body-height :body-offset))
           (details
            (list
             (format "%s" (bbs-ui--rank-chip (plist-get profile :rank)))
             (propertize (format "@%s" (plist-get profile :name)) 'face 'bbs-ui-blue)
             (format "FORUM POSTS  %d" (plist-get profile :posts))
             (format "AVATAR       %s" (if (plist-get profile :avatar) "LOCAL PNG" "IDENTICON"))
             "SOURCE       FOSSIL CLONE")))
      (bbs-ui--column
       (append
        (list (bbs-ui--line (format " %s // %s" (or heading "USER")
                                    (plist-get profile :name)) width 'bbs-ui-yellow)
              (bbs-ui--identity-block profile details width rows 15)
              (bbs-ui--line
               (format " PROFILE DATA · LINES %d–%d / %d "
                       (if (> (plist-get window :total) 0)
                           (1+ (plist-get window :start)) 0)
                       (plist-get window :end) (plist-get window :total))
               width 'bbs-ui-frame))
        (mapcar (lambda (line) (bbs-ui--line line width))
                (plist-get window :lines))) width))))

(defun bbs-ui--profile-entry (profile width selected)
  "Render one three-line PROFILE directory entry with its avatar."
  (let* ((avatar-width 7)
         (info-width (max 8 (- width avatar-width 1)))
         (name (plist-get profile :name))
         (bio (or (plist-get profile :bio) "No profile page in this clone.")))
    (list :type :flex :direction :row :gap 1
          :layout (list :width width :min-width width)
          :children
          (list
           (bbs-ui--avatar-element profile 3 avatar-width)
           (bbs-ui--column
            (list
             (bbs-ui--row
              (format "%s  @%s" (bbs-ui--rank-chip (plist-get profile :rank)) name)
              'profile name #'bbs-ui--activate-row info-width selected)
             (bbs-ui--line (format " %d POSTS · %s"
                                   (plist-get profile :posts)
                                   (if (plist-get profile :avatar) "AVATAR" "IDENTICON"))
                           info-width 'bbs-ui-muted)
             (bbs-ui--line (concat " " (bbs-ui--single-line-string bio))
                           info-width 'bbs-ui-cyan))
            info-width)))))

(defun bbs-ui--users-list-pane (width height)
  "Render the bounded avatar-rich node directory."
  (let* ((profiles (plist-get textui-state :profiles))
         (capacity (max 1 (/ (max 1 (- height 2)) 4)))
         (slice (bbs-ui--viewport profiles
                                  (lambda (profile) (plist-get profile :name))
                                  :selected-profile :users-offset capacity))
         (selected (plist-get slice :selected))
         (children (list (bbs-ui--line " NODE DIRECTORY // LOCAL IDENTITIES"
                                            width 'bbs-ui-cyan))))
    (dolist (profile (plist-get slice :items))
      (setq children
            (append children
                    (list (bbs-ui--profile-entry
                           profile width (equal (plist-get profile :name) selected))
                          (bbs-ui--line "" width)))))
    (setq children (append children (list (bbs-ui--position-line slice width "USERS"))))
    (setq children
          (append children
                  (make-list (max 0 (- height
                                       (+ 2 (* 4 (length (plist-get slice :items))))))
                             (bbs-ui--line "" width))))
    (bbs-ui--column children width)))

(defun bbs-ui--users-view (width height)
  "Render the avatar directory and selected profile."
  (let* ((profiles (plist-get textui-state :profiles))
         (profile (cl-find (plist-get textui-state :selected-profile) profiles
                           :key (lambda (item) (plist-get item :name)) :test #'equal)))
    (if (>= width bbs-ui-wide-layout-width)
        (let* ((left (max 40 (floor (* (1- width) 0.43))))
               (right (- width left 1)))
          (list :type :flex :direction :row :gap 1
                :layout (list :width width :min-width width)
                :children (list (bbs-ui--users-list-pane left height)
                                (bbs-ui--profile-pane profile right height "PROFILE"))))
      (bbs-ui--users-list-pane width height))))

(defun bbs-ui--profile-view (width height name)
  "Render profile NAME at WIDTH by HEIGHT."
  (bbs-ui--profile-pane (bbs-ui--find-profile name) width height))

(defun bbs-ui--saved-posts ()
  "Return locally saved logical posts in persistent order."
  (delq nil
        (mapcar #'bbs-ui--find-post
                (plist-get (plist-get textui-state :local-state) :saved))))

(defun bbs-ui--saved-line (post width)
  "Format saved POST at WIDTH."
  (let* ((thread (bbs-ui--find-thread (plist-get post :thread-id)))
         (age (format "%8s" (bbs-ui--ago (plist-get post :time))))
         (author (format "%-12s" (truncate-string-to-width
                                  (plist-get post :user) 12 nil nil "…")))
         (title-width (max 8 (- width 24))))
    (concat (propertize "★ " 'face 'bbs-ui-yellow)
            (bbs-ui--fit (if thread (bbs-ui--thread-subject thread) "untitled")
                         title-width)
            " " (propertize author 'face 'bbs-ui-blue)
            " " (propertize age 'face 'bbs-ui-muted))))

(defun bbs-ui--saved-list-pane (width height)
  "Render the bounded saved-post index."
  (let* ((posts (bbs-ui--saved-posts))
         (capacity (max 1 (- height 2)))
         (slice (bbs-ui--viewport posts
                                  (lambda (post) (plist-get post :logical-id))
                                  :selected-saved :saved-offset capacity))
         (selected (plist-get slice :selected))
         (rows (mapcar
                (lambda (post)
                  (let ((id (plist-get post :logical-id)))
                    (bbs-ui--row (bbs-ui--saved-line post width)
                                 'post id #'bbs-ui--activate-row width
                                 (equal id selected))))
                (plist-get slice :items))))
    (bbs-ui--column
     (append (list (bbs-ui--line " SAVED // SUBJECT                    AUTHOR           AGE"
                                      width 'bbs-ui-cyan))
             rows
             (make-list (max 0 (- capacity (length rows)))
                        (bbs-ui--line "" width))
             (list (bbs-ui--position-line slice width "SAVED POSTS"))) width)))

(defun bbs-ui--saved-view (width height)
  "Render locally saved posts with a reader preview."
  (let* ((posts (bbs-ui--saved-posts))
         (post (bbs-ui--find-post (plist-get textui-state :selected-saved))))
    (unless (member post posts)
      (setq post (car posts))
      (when post
        (setq textui-state
              (plist-put (copy-sequence textui-state) :selected-saved
                         (plist-get post :logical-id)))))
    (let ((thread (and post (bbs-ui--find-thread (plist-get post :thread-id)))))
    (if (>= width bbs-ui-wide-layout-width)
        (let* ((left (max 40 (floor (* (1- width) 0.43))))
               (right (- width left 1)))
          (list :type :flex :direction :row :gap 1
                :layout (list :width width :min-width width)
                :children (list (bbs-ui--saved-list-pane left height)
                                (bbs-ui--message-pane post thread right height "ARCHIVE"))))
        (bbs-ui--saved-list-pane width height)))))

(defun bbs-ui--search-results (query)
  "Return local forum, wiki and profile results for QUERY."
  (let ((needle (downcase (string-trim (or query "")))) result)
    (unless (string-empty-p needle)
      (dolist (thread (plist-get textui-state :threads))
        (when (string-match-p
               (regexp-quote needle)
               (downcase (concat (plist-get thread :title) "\n"
                                 (mapconcat (lambda (post) (plist-get post :body))
                                            (plist-get thread :posts) "\n"))))
          (push (list :kind 'thread :id (plist-get thread :id)
                      :key (cons 'thread (plist-get thread :id))
                      :title (plist-get thread :title)) result)))
      (dolist (page (plist-get textui-state :wiki))
        (when (string-match-p (regexp-quote needle)
                              (downcase (concat (plist-get page :name) "\n"
                                                (plist-get page :body))))
          (push (list :kind 'wiki-page :id (plist-get page :name)
                      :key (cons 'wiki-page (plist-get page :name))
                      :title (plist-get page :name)) result)))
      (dolist (profile (plist-get textui-state :profiles))
        (when (string-match-p (regexp-quote needle)
                              (downcase (concat (plist-get profile :name) "\n"
                                                (or (plist-get profile :bio) ""))))
          (push (list :kind 'profile :id (plist-get profile :name)
                      :key (cons 'profile (plist-get profile :name))
                      :title (plist-get profile :name)) result))))
    (nreverse result)))

(defun bbs-ui--search-line (result width)
  "Format search RESULT at WIDTH."
  (let* ((kind (pcase (plist-get result :kind)
                 ('thread "FORUM") ('wiki-page "WIKI ") (_ "USER ")))
         (title-width (max 8 (- width 9))))
    (concat (propertize (format " %s  " kind) 'face 'bbs-ui-magenta)
            (bbs-ui--fit (plist-get result :title) title-width 'bbs-ui-blue))))

(defun bbs-ui--search-list-pane (results width height)
  "Render bounded RESULTS at WIDTH by HEIGHT."
  (let* ((capacity (max 1 (- height 2)))
         (slice (bbs-ui--viewport results
                                  (lambda (result) (plist-get result :key))
                                  :selected-search :search-offset capacity))
         (selected (plist-get slice :selected))
         (rows (mapcar
                (lambda (result)
                  (let ((key (plist-get result :key)))
                    (bbs-ui--row (bbs-ui--search-line result width)
                                 (plist-get result :kind) (plist-get result :id)
                                 #'bbs-ui--activate-row width (equal key selected))))
                (plist-get slice :items))))
    (bbs-ui--column
     (append (list (bbs-ui--line
                    (format " LOCAL SEARCH // %s" (or (plist-get textui-state :query) ""))
                    width 'bbs-ui-cyan))
             rows
             (make-list (max 0 (- capacity (length rows)))
                        (bbs-ui--line (if results "" " NO LOCAL MATCHES · / TO SEARCH AGAIN")
                                      width 'bbs-ui-muted))
             (list (bbs-ui--position-line slice width "MATCHES"))) width)))

(defun bbs-ui--search-preview (result width height)
  "Render a detail preview for search RESULT."
  (pcase (and result (plist-get result :kind))
    ('thread
     (let ((thread (bbs-ui--find-thread (plist-get result :id))))
       (bbs-ui--message-pane (and thread (plist-get thread :root))
                             thread width height "MATCH")))
    ('wiki-page
     (bbs-ui--document-pane (bbs-ui--find-wiki (plist-get result :id))
                            width height "MATCH"))
    ('profile
     (bbs-ui--profile-pane (bbs-ui--find-profile (plist-get result :id))
                           width height "MATCH"))
    (_ (bbs-ui--column
        (cons (bbs-ui--line " SELECT A LOCAL MATCH" width 'bbs-ui-muted)
              (make-list (max 0 (1- height)) (bbs-ui--line "" width))) width))))

(defun bbs-ui--search-view (width height)
  "Render current local search at WIDTH by HEIGHT."
  (let* ((results (bbs-ui--search-results (plist-get textui-state :query)))
         (key (plist-get textui-state :selected-search))
         (result (cl-find key results :key (lambda (item) (plist-get item :key))
                          :test #'equal)))
    (if (>= width bbs-ui-wide-layout-width)
        (let* ((left (max 38 (floor (* (1- width) 0.42))))
               (right (- width left 1)))
          (list :type :flex :direction :row :gap 1
                :layout (list :width width :min-width width)
                :children (list (bbs-ui--search-list-pane results left height)
                                (bbs-ui--search-preview result right height))))
      (bbs-ui--search-list-pane results width height))))

(defun bbs-ui--footer-status ()
  "Return a concise user-facing status string and face."
  (let ((error-text (plist-get textui-state :error))
        (busy (plist-get textui-state :busy))
        (notice (plist-get textui-state :notice)))
    (cond
     (error-text
      (cons (format " ERROR · %s · [E] DETAILS · [R] RETRY"
                    (bbs-ui--single-line-string error-text)) 'bbs-ui-error))
     (busy (cons (format " LINK ACTIVITY · %s… · LOCAL DATA REMAINS AVAILABLE" busy)
                 'bbs-ui-yellow))
     (notice (cons (format " %s" (bbs-ui--single-line-string notice)) 'bbs-ui-green))
     (t (cons (format " %s ARCHIVE · %d THREADS · %d WIKI PAGES · %d USERS"
                      (bbs-ui--status-chip)
                      (length (plist-get textui-state :threads))
                      (length (plist-get textui-state :wiki))
                      (length (plist-get textui-state :profiles)))
              'bbs-ui-muted)))))

(defun bbs-ui--command-line ()
  "Return the current view's compact command line."
  (pcase (plist-get textui-state :view)
    ('board " [RET] READ  [N] NEW  [/] FIND  [g] PULL  [P] PUBLISH  [TAB] PREVIEW  [?] HELP ")
    ('thread " [←/→] MESSAGE  [r] REPLY  [e] EDIT  [s] SAVE  [h] HISTORY  [TAB] READER  [q] BACK ")
    ('wiki " [RET] OPEN  [W] NEW PAGE  [/] FIND  [TAB] PREVIEW  [Q] BOARD ")
    ('wiki-page " [e] EDIT  [w] WEB  [j/k] SCROLL  [q] INDEX ")
    ('users " [RET] PROFILE  [j/k] NODE  [TAB] PREVIEW  [q] BOARD ")
    ('profile " [j/k] SCROLL  [q] DIRECTORY ")
    ('saved " [RET] OPEN  [s] UNSAVE  [TAB] PREVIEW  [q] BOARD ")
    ('search " [RET] OPEN  [/] NEW SEARCH  [TAB] PREVIEW  [q] BOARD ")
    (_ " [B] BOARD  [V] WIKI  [U] USERS  [S] SAVED  [?] HELP ")))

(defun bbs-ui--footer (width)
  "Return the persistent two-line status and command footer."
  (pcase-let ((`(,status . ,face) (bbs-ui--footer-status)))
    (list (bbs-ui--bar-line "╟─" status ?─ "─╢" width face)
          (bbs-ui--bar-line "╚═" (bbs-ui--command-line) ?═ "═╝" width 'bbs-ui-bar))))

(defun bbs-ui--screen-body (width height)
  "Return the current view's fixed WIDTH by HEIGHT body."
  (pcase (plist-get textui-state :view)
    ('board (bbs-ui--board-view width height))
    ('thread (bbs-ui--thread-view width height (plist-get textui-state :view-id)))
    ('wiki (bbs-ui--wiki-view width height))
    ('wiki-page (bbs-ui--wiki-page-view width height (plist-get textui-state :view-id)))
    ('users (bbs-ui--users-view width height))
    ('profile (bbs-ui--profile-view width height (plist-get textui-state :view-id)))
    ('saved (bbs-ui--saved-view width height))
    ('search (bbs-ui--search-view width height))
    (_ (bbs-ui--board-view width height))))

(defun bbs-ui--screen (width)
  "Build the complete height-bound BBS screen at WIDTH."
  (let* ((height (max 14 (or (plist-get textui-state :height) 32)))
         (body-height (max 8 (- height 5))))
    (append (bbs-ui--header width)
            (list (bbs-ui--screen-body width body-height))
            (bbs-ui--footer width))))

(defun bbs-ui--record-diagnostic (error-data width)
  "Record ERROR-DATA raised while rendering WIDTH and return its ID."
  (let* ((signature (error-message-string error-data))
         (duplicate (and (equal signature bbs-ui--last-render-error)
                         (car bbs-ui--diagnostics)))
         (id (or (plist-get duplicate :id)
                 (format "%s-%03d" (format-time-string "%Y%m%d-%H%M%S")
                         (% (truncate (* 1000 (float-time))) 1000))))
         (entry (list :id id :time (current-time) :width width
                      :height (plist-get textui-state :height)
                      :view (plist-get textui-state :view)
                      :message signature
                      :backtrace (with-output-to-string (backtrace)))))
    (unless duplicate
      (push entry bbs-ui--diagnostics)
      (setq bbs-ui--last-render-error signature))
    (setq textui-state
          (plist-put (plist-put (copy-sequence textui-state) :diagnostic-id id)
                     :error (format "UI fault %s" id)))
    id))

(defun bbs-ui-show-diagnostics ()
  "Show local UI and Fossil failures captured by this BBS buffer."
  (interactive)
  (let ((entries bbs-ui--diagnostics)
        (source (current-buffer))
        (buffer (get-buffer-create "*BBS diagnostics*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize "COPLAND.SYSTEMS // LOCAL DIAGNOSTICS\n"
                            'face 'bbs-ui-logo)
                (propertize
                 "This viewer transmits nothing and never modifies the Fossil archive.\n\n"
                 'face 'bbs-ui-muted))
        (if (null entries)
            (insert "No BBS faults have been captured in this session.\n")
          (dolist (entry entries)
            (insert (propertize
                     (format "[%s]  %s  VIEW:%s  FRAME:%sx%s\n"
                             (plist-get entry :id)
                             (format-time-string "%Y-%m-%d %H:%M:%S"
                                                 (plist-get entry :time))
                             (upcase (format "%s" (plist-get entry :view)))
                             (or (plist-get entry :width) "?")
                             (or (plist-get entry :height) "?"))
                     'face 'bbs-ui-yellow)
                    (propertize (concat (plist-get entry :message) "\n")
                                'face 'bbs-ui-error)
                    (or (plist-get entry :backtrace) "") "\n")))
        (goto-char (point-min))
        (special-mode)
        (setq-local revert-buffer-function
                    (lambda (&rest _)
                      (when (buffer-live-p source)
                        (with-current-buffer source
                          (bbs-ui-show-diagnostics)))))))
    (pop-to-buffer buffer)))

(defun bbs-ui--fallback-frame (width error-data)
  "Return a dependency-free BBS fallback frame for ERROR-DATA."
  (let* ((height (max 14 (or (plist-get textui-state :height) 32)))
         (message (error-message-string error-data))
         (body-height (- height 5))
         (body
          (append
           (list (bbs-ui--line "" width)
                 (bbs-ui--line "  !!! LOCAL CONSOLE RECOVERY MODE !!!" width 'bbs-ui-error)
                 (bbs-ui--line (concat "  " message) width 'bbs-ui-yellow)
                 (bbs-ui--line "" width)
                 (bbs-ui--line "  The Fossil archive was not modified." width 'bbs-ui-green)
                 (bbs-ui--line "  Press R to rebuild, E for diagnostics, q to leave." width
                               'bbs-ui-cyan))
           (make-list (max 0 (- body-height 6)) (bbs-ui--line "" width)))))
    (list
     (list :type :flex :direction :column :gap 0
           :layout (list :width width :min-width width)
           :children
           (append (bbs-ui--header width)
                   (list (bbs-ui--column body width))
                   (bbs-ui--footer width))))))

(defun bbs-ui--frame (width)
  "Render the BBS safely at WIDTH, falling back without entering the debugger."
  (let ((width (max 24 width)))
    (condition-case error-data
        (let ((frame
               (list
                (list :type :flex :direction :column :gap 0
                      :layout (list :width width :min-width width)
                      :children (bbs-ui--screen width)))))
          ;; TextUI performs measurement after this function returns.  Preflight
          ;; both phases here so BBS-owned layout faults become a recovery screen.
          (textui--render-specs (textui--prepare-frame frame t) width)
          (setq bbs-ui--last-render-error nil)
          frame)
      (error
       (bbs-ui--record-diagnostic error-data width)
       (bbs-ui--fallback-frame width error-data)))))

(defun bbs-ui--kind-at-point ()
  "Return BBS row kind at point."
  (or (get-text-property (point) 'bbs-ui-kind)
      (get-text-property (line-beginning-position) 'bbs-ui-kind)
      (car (bbs-ui--semantic-target))))

(defun bbs-ui--id-at-point ()
  "Return BBS row identity at point."
  (or (get-text-property (point) 'bbs-ui-id)
      (get-text-property (line-beginning-position) 'bbs-ui-id)
      (cdr (bbs-ui--semantic-target))))

(defun bbs-ui--goto-id (id)
  "Move to row ID when visible."
  (goto-char (point-min))
  (when-let* ((match (text-property-search-forward 'bbs-ui-id id #'equal)))
    (goto-char (prop-match-beginning match))))

(defun bbs-ui--set-view (view &optional id)
  "Switch to VIEW and optional ID."
  (textui-update
   (current-buffer)
   (lambda (state)
     (let ((next (copy-sequence state)))
       (setq next (plist-put next :view view))
       (setq next (plist-put next :view-id id))
       (setq next (plist-put next :body-offset 0))
       (plist-put next :active-pane
                  (if (memq view '(wiki-page profile)) 'detail 'list))))))

(defun bbs-ui--semantic-target ()
  "Return the currently selected semantic (KIND . ID), if any."
  (pcase (plist-get textui-state :view)
    ('board (cons 'thread (plist-get textui-state :selected-root)))
    ('thread (cons 'post (plist-get textui-state :selected-post)))
    ('wiki (cons 'wiki-page (plist-get textui-state :selected-wiki)))
    ('wiki-page (cons 'wiki-page (plist-get textui-state :view-id)))
    ('users (cons 'profile (plist-get textui-state :selected-profile)))
    ('profile (cons 'profile (plist-get textui-state :view-id)))
    ('saved (cons 'post (plist-get textui-state :selected-saved)))
    ('search
     (when-let* ((key (plist-get textui-state :selected-search))
                 (result (cl-find key
                                  (bbs-ui--search-results
                                   (plist-get textui-state :query))
                                  :key (lambda (item) (plist-get item :key))
                                  :test #'equal)))
       (cons (plist-get result :kind) (plist-get result :id))))
    (_ nil)))

(defun bbs-ui--activate-row (kind id)
  "Open BBS row KIND and ID."
  (pcase kind
    ('thread
     (when-let* ((thread (bbs-ui--find-thread id)))
       (bbs-ui--mark-thread-read thread)
       (bbs-ui--set-view 'thread id)))
    ('post
     (when-let* ((post (bbs-ui--find-post id))
                 (thread (bbs-ui--find-thread (plist-get post :thread-id))))
       (bbs-ui--mark-thread-read thread)
       (if (and (eq (plist-get textui-state :view) 'thread)
                (equal (plist-get textui-state :view-id)
                       (plist-get thread :id)))
           (textui-update
            (current-buffer)
            (lambda (state)
              (let ((next (copy-sequence state)))
                (setq next (plist-put next :selected-post id))
                (setq next (plist-put next :body-offset 0))
                (plist-put next :active-pane 'detail))))
         (textui-update
          (current-buffer)
          (lambda (state)
            (let ((next (copy-sequence state)))
              (setq next (plist-put next :view 'thread))
              (setq next (plist-put next :view-id (plist-get thread :id)))
              (setq next (plist-put next :selected-post id))
              (setq next (plist-put next :body-offset 0))
              (plist-put next :active-pane 'detail)))))))
    ('wiki-page (bbs-ui--set-view 'wiki-page id))
    ('profile (bbs-ui--set-view 'profile id))
    (_ (user-error "Nothing to open here"))))

(defun bbs-ui-open-at-point ()
  "Open the BBS item at point."
  (interactive)
  (if (and (memq (plist-get textui-state :view) '(thread wiki-page profile))
           (or (< (or textui--last-width 0) bbs-ui-wide-layout-width)
               (eq (plist-get textui-state :active-pane) 'detail)))
      (bbs-ui-page-down)
    (pcase-let ((`(,kind . ,id) (or (bbs-ui--semantic-target)
                                    (cons (bbs-ui--kind-at-point)
                                          (bbs-ui--id-at-point)))))
      (if (and kind id)
          (bbs-ui--activate-row kind id)
        (user-error "No BBS item selected")))))

(defun bbs-ui--selection-model ()
  "Return (ITEMS SELECTION-KEY ID-FUNCTION) for the current list view."
  (pcase (plist-get textui-state :view)
    ('board (list (plist-get textui-state :threads) :selected-root
                  (lambda (thread) (plist-get thread :id))))
    ('thread
     (when-let* ((thread (bbs-ui--find-thread (plist-get textui-state :view-id))))
       (list (plist-get thread :posts) :selected-post
             (lambda (post) (plist-get post :logical-id)))))
    ('wiki (list (plist-get textui-state :wiki) :selected-wiki
                 (lambda (page) (plist-get page :name))))
    ('users (list (plist-get textui-state :profiles) :selected-profile
                  (lambda (profile) (plist-get profile :name))))
    ('saved (list (bbs-ui--saved-posts) :selected-saved
                  (lambda (post) (plist-get post :logical-id))))
    ('search (list (bbs-ui--search-results (plist-get textui-state :query))
                   :selected-search
                   (lambda (result) (plist-get result :key))))
    (_ nil)))

(defun bbs-ui--detail-active-p ()
  "Return non-nil when movement should scroll a reader rather than a list."
  (or (memq (plist-get textui-state :view) '(wiki-page profile))
      (and (eq (plist-get textui-state :view) 'thread)
           (< (or textui--last-width 0) bbs-ui-wide-layout-width))
      (and (>= (or textui--last-width 0) bbs-ui-wide-layout-width)
           (eq (plist-get textui-state :active-pane) 'detail))))

(defun bbs-ui--scroll-body (amount)
  "Scroll the current preview or reader by AMOUNT wrapped lines."
  (textui-set-state (current-buffer) :body-offset
                    (lambda (offset) (max 0 (+ (or offset 0) amount)))))

(defun bbs-ui--move-selection (amount)
  "Move the semantic list selection by AMOUNT entries."
  (if-let* ((model (bbs-ui--selection-model))
            (items (nth 0 model)))
      (let* ((selection-key (nth 1 model))
             (id-function (nth 2 model))
             (selected (plist-get textui-state selection-key))
             (index (or (cl-position selected items :key id-function :test #'equal) 0))
             (next-index (min (1- (length items)) (max 0 (+ index amount))))
             (next-id (funcall id-function (nth next-index items)))
             (buffer (current-buffer)))
        (if (equal next-id selected)
            (message "%s" (if (> amount 0) "End of list" "Top of list"))
          (textui-update
           buffer
           (lambda (state)
             (let ((next (copy-sequence state)))
               (setq next (plist-put next selection-key next-id))
               (setq next (plist-put next :body-offset 0))
               next)))
          (run-at-time 0 nil
                       (lambda (owner id)
                         (when (buffer-live-p owner)
                           (with-current-buffer owner (bbs-ui--goto-id id))))
                       buffer
                       (if (consp next-id) (cdr next-id) next-id))))
    (message "No selectable BBS rows")))

(defun bbs-ui--move-row (direction)
  "Move one logical row in DIRECTION or scroll the active reader."
  (if (bbs-ui--detail-active-p)
      (bbs-ui--scroll-body direction)
    (bbs-ui--move-selection direction)))

(defun bbs-ui-next-row () (interactive) (bbs-ui--move-row 1))
(defun bbs-ui-previous-row () (interactive) (bbs-ui--move-row -1))

(defun bbs-ui-page-down ()
  "Move one BBS viewport page down."
  (interactive)
  (let ((amount (max 1 (- (or (plist-get textui-state :height) 32) 10))))
    (if (bbs-ui--detail-active-p)
        (bbs-ui--scroll-body amount)
      (bbs-ui--move-selection amount))))

(defun bbs-ui-page-up ()
  "Move one BBS viewport page up."
  (interactive)
  (let ((amount (max 1 (- (or (plist-get textui-state :height) 32) 10))))
    (if (bbs-ui--detail-active-p)
        (bbs-ui--scroll-body (- amount))
      (bbs-ui--move-selection (- amount)))))

(defun bbs-ui-toggle-pane ()
  "Toggle between a wide screen's index and detail pane."
  (interactive)
  (if (< (or textui--last-width 0) bbs-ui-wide-layout-width)
      (message "This window has one BBS pane")
    (textui-set-state (current-buffer) :active-pane
                      (lambda (pane) (if (eq pane 'detail) 'list 'detail)))))

(defun bbs-ui-next-message ()
  "Select the next message in the current thread."
  (interactive)
  (if (eq (plist-get textui-state :view) 'thread)
      (bbs-ui--move-selection 1)
    (message "Not in a message thread")))

(defun bbs-ui-previous-message ()
  "Select the previous message in the current thread."
  (interactive)
  (if (eq (plist-get textui-state :view) 'thread)
      (bbs-ui--move-selection -1)
    (message "Not in a message thread")))

(defun bbs-ui-board () "Open the board." (interactive) (bbs-ui--set-view 'board))
(defun bbs-ui-wiki () "Open the wiki index." (interactive) (bbs-ui--set-view 'wiki))
(defun bbs-ui-users () "Open the user index." (interactive) (bbs-ui--set-view 'users))
(defun bbs-ui-saved () "Open locally saved posts." (interactive) (bbs-ui--set-view 'saved))

(defun bbs-ui-search (query)
  "Search the complete local BBS for literal QUERY."
  (interactive (list (read-string "Search local BBS: " (plist-get textui-state :query))))
  (textui-update
   (current-buffer)
   (lambda (state)
     (let ((next (copy-sequence state)))
       (setq next (plist-put next :query query))
       (setq next (plist-put next :view 'search))
       (setq next (plist-put next :view-id nil))
       (setq next (plist-put next :selected-search nil))
       (setq next (plist-put next :search-offset 0))
       (setq next (plist-put next :body-offset 0))
       (plist-put next :active-pane 'list)))))

(defun bbs-ui-back ()
  "Go back one semantic level, or close the BBS from its board."
  (interactive)
  (pcase (plist-get textui-state :view)
    ('board (quit-window))
    ((or 'thread 'saved 'search) (bbs-ui-board))
    ((or 'wiki-page) (bbs-ui-wiki))
    ((or 'profile) (bbs-ui-users))
    (_ (bbs-ui-board))))

(defun bbs-ui--reload (&optional clear-error)
  "Reload the local repository, optionally CLEAR-ERROR."
  (let ((position-id (bbs-ui--id-at-point))
        (old textui-state))
    (condition-case err
        (let ((next (bbs-ui--snapshot (plist-get old :repository) old)))
          (unless clear-error
            (setq next (plist-put next :error (plist-get old :error))
                  next (plist-put next :connection (plist-get old :connection))))
          (textui-update (current-buffer) (lambda (_) next))
          (when position-id (bbs-ui--goto-id position-id)))
      (error
       (bbs-ui--record-diagnostic err (or textui--last-width 0))
       (textui-update
        (current-buffer)
        (lambda (state)
          (let ((next (copy-sequence state)))
            (setq next (plist-put next :notice nil))
            (plist-put next :error (error-message-string err)))))))))

(defun bbs-ui-refresh ()
  "Refresh from the local repository without network access."
  (interactive)
  (bbs-ui--reload t))

(defun bbs-ui--finish-process (owner label code output success)
  "Finish asynchronous LABEL for OWNER using CODE, OUTPUT and SUCCESS."
  (when (buffer-live-p owner)
    (with-current-buffer owner
      (setq bbs-ui--process nil)
      (condition-case err
          (if (zerop code)
              (progn
                (textui-update
                 owner
                 (lambda (state)
                   (let ((next (copy-sequence state)))
                     (setq next (plist-put next :busy nil))
                     (setq next (plist-put next :connection 'online))
                     (setq next (plist-put next :error nil))
                     (plist-put next :notice
                                (format "%s COMPLETE" (upcase label))))))
                (bbs-ui--reload t)
                (bbs-ui--set-notice
                 (format "%s COMPLETE%s" (upcase label)
                         (if (string-empty-p output) ""
                           (format " · %s"
                                   (bbs-ui--single-line-string output)))))
                (when success (funcall success output)))
            (let ((failure (if (string-empty-p output)
                               (format "Fossil %s exited %d" label code)
                             output)))
              (bbs-ui--record-diagnostic
               (list 'error failure) (or textui--last-width 0))
              (textui-update
               owner
               (lambda (state)
                 (let ((next (copy-sequence state)))
                   (setq next (plist-put next :busy nil))
                   (setq next (plist-put next :notice nil))
                   (setq next (plist-put next :connection 'offline))
                   (plist-put next :error failure))))))
        (error
         (bbs-ui--record-diagnostic err (or textui--last-width 0))
         (textui-update
          owner
          (lambda (state)
            (let ((next (copy-sequence state)))
              (setq next (plist-put next :busy nil))
              (setq next (plist-put next :connection 'offline))
              (setq next (plist-put next :notice nil))
              (plist-put next :error (error-message-string err))))))))))

(defun bbs-ui--async-fossil (label args success)
  "Run Fossil ARGS asynchronously as LABEL, then call SUCCESS."
  (when (or (plist-get textui-state :busy)
            (and bbs-ui--process (process-live-p bbs-ui--process)))
    (user-error "BBS is busy: %s" (plist-get textui-state :busy)))
  (let* ((owner (current-buffer))
         (output-buffer (generate-new-buffer (format " *bbs-ui:%s*" label)))
         (default-directory (file-name-directory
                             (plist-get textui-state :repository))))
    (textui-update
     owner
     (lambda (state)
       (let ((next (copy-sequence state)))
         (setq next (plist-put next :busy label)
               next (plist-put next :error nil))
         (plist-put next :connection (if (equal label "pull") 'pulling
                                       (plist-get state :connection))))))
    (setq bbs-ui--process
          (make-process
           :name (format "bbs-ui-%s" label)
           :buffer output-buffer
           :command (cons bbs-ui-fossil-program args)
           :noquery t
           :sentinel
           (lambda (process _event)
             (when (memq (process-status process) '(exit signal))
               (let ((code (process-exit-status process))
                     (output (with-current-buffer (process-buffer process)
                               (string-trim (buffer-string)))))
                 (when (buffer-live-p (process-buffer process))
                   (kill-buffer (process-buffer process)))
                 (bbs-ui--finish-process owner label code output success))))))))

(defun bbs-ui-pull ()
  "Pull durable artifacts from the configured remote.
This command cannot upload local artifacts."
  (interactive)
  (if (not (plist-get textui-state :remote))
      (bbs-ui--set-notice
       "LINK DISABLED · SANDBOX REMAINS LOCAL · NO NETWORK REQUEST SENT")
    (bbs-ui--async-fossil
     "pull" (list "pull" "-R" (plist-get textui-state :repository)) nil)))

(defun bbs-ui--unsent-description (entries)
  "Return a compact description of unsent ENTRIES."
  (mapconcat
   (lambda (entry)
     (format "%s  %-2s  %s"
             (substring (plist-get entry :uuid) 0 10)
             (or (plist-get entry :type) "")
             (or (plist-get entry :comment) "")))
   entries "\n"))

(defun bbs-ui-publish-pending ()
  "Explicitly publish all currently unsent Fossil artifacts."
  (interactive)
  (let ((remote (plist-get textui-state :remote))
        (entries (bbs-ui--unsent (plist-get textui-state :repository))))
    (unless remote (user-error "This repository has no remote"))
    (unless entries (user-error "There are no local artifacts to publish"))
    (unless
        (yes-or-no-p
         (format
          "Publish ALL %d queued artifact(s) as %s to %s?\n%s\n"
          (length entries) (plist-get textui-state :user) remote
          (bbs-ui--unsent-description entries)))
      (user-error "Publish cancelled"))
    ;; This is the only push call in bbs-ui.  It is intentionally behind the
    ;; complete-scope confirmation above.
    (bbs-ui--async-fossil
     "publish" (list "push" "-R" (plist-get textui-state :repository))
     (lambda (_) (message "Queued BBS artifacts published")))))

(defun bbs-ui--form-encode (fields)
  "Encode alist FIELDS for an HTML form."
  (mapconcat
   (lambda (field)
     (concat (url-hexify-string (format "%s" (car field))) "="
             (url-hexify-string (or (cdr field) ""))))
   fields "&"))

(defun bbs-ui--local-http (repository method path &optional fields)
  "Run METHOD PATH with FIELDS through REPOSITORY's local Fossil handler."
  (let* ((body (and fields (bbs-ui--form-encode fields)))
         (host "localhost")
         (request
          (concat method " " path " HTTP/1.0\r\n"
                  "Host: " host "\r\n"
                  "Origin: http://" host "\r\n"
                  "Referer: http://" host path "\r\n"
                  (when body
                    (concat "Content-Type: application/x-www-form-urlencoded\r\n"
                            "Content-Length: "
                            (number-to-string (string-bytes
                                               (encode-coding-string body 'utf-8)))
                            "\r\n"))
                  "\r\n" (or body ""))))
    (pcase-let ((`(,code ,raw)
                 (bbs-ui--call-raw request "test-http" "--test" repository)))
      (let ((response (decode-coding-string raw 'utf-8)))
        (unless (zerop code)
          (user-error "Fossil local forum handler failed: %s" response))
        response))))

(defun bbs-ui--http-status (response)
  "Return numeric HTTP status from RESPONSE."
  (and (string-match "\\`HTTP/[0-9.]+ \\([0-9]+\\)" response)
       (string-to-number (match-string 1 response))))

(defun bbs-ui--html-field (name response)
  "Return HTML input NAME's value from RESPONSE."
  (when (string-match
         (format "name=[\"']%s[\"'][^>]*value=[\"']\\([^\"']+\\)"
                 (regexp-quote name))
         response)
    (match-string 1 response)))

(defun bbs-ui--html-actor (response)
  "Return the locally authenticated forum actor from RESPONSE."
  (when (string-match "From:[[:space:]]*\\([^<\n]+\\)<br>" response)
    (string-trim (match-string 1 response))))

(defun bbs-ui--forum-write (repository kind target title mimetype content)
  "Create a local forum artifact in REPOSITORY.
KIND is `thread', `reply' or `edit'; TARGET is a full artifact ID."
  (let* ((path (pcase kind
                 ('thread "/forume1")
                 ('reply (format "/forume2?fpid=%s" target))
                 ('edit (format "/forume2?fpid=%s&edit=1" target))
                 (_ (error "Unknown forum write kind: %S" kind))))
         (form (bbs-ui--local-http repository "GET" path))
         (status (bbs-ui--http-status form))
         (csrf (bbs-ui--html-field "csrf" form))
         (actor (bbs-ui--html-actor form))
         (expected-user (bbs-ui--user repository))
         (fpid (and target (or (bbs-ui--html-field "fpid" form) target)))
         fields response)
    (unless (= status 200)
      (user-error "Fossil forum form returned HTTP %s" status))
    (unless csrf
      (user-error "Fossil forum form contract changed: no CSRF field"))
    (unless (and actor (equal actor expected-user))
      (user-error "Local Fossil handler would write as %s, expected %s"
                  (or actor "an unknown user") expected-user))
    (setq fields
          (append
           (when title `(("title" . ,title)))
           (when fpid `(("fpid" . ,fpid)))
           (pcase kind ('reply '(("reply" . "1"))) ('edit '(("edit" . "1"))))
           `(("mimetype" . ,mimetype)
             ("content" . ,content)
             ("submit" . "Submit")
             ("csrf" . ,csrf))))
    (setq response
          (bbs-ui--local-http repository "POST"
                              (if (eq kind 'thread) "/forume1" "/forume2") fields))
    (unless (memq (bbs-ui--http-status response) '(302 303))
      (user-error "Fossil rejected the local forum post (HTTP %s)"
                  (bbs-ui--http-status response)))
    response))

(defun bbs-ui--wiki-write (repository page mimetype content)
  "Create or update PAGE with CONTENT locally in REPOSITORY."
  (let ((exists (member page
                        (mapcar (lambda (entry) (plist-get entry :name))
                                (plist-get textui-state :wiki)))))
    (pcase-let ((`(,code ,raw)
                 (bbs-ui--call-raw
                  content "wiki" (if exists "commit" "create") page "-"
                  "-M" mimetype "-R" repository)))
      (let ((output (string-trim (decode-coding-string raw 'utf-8))))
        (unless (zerop code)
          (user-error "%s" output))
        output))))

(defun bbs-ui--compose-body ()
  "Return current composer body."
  (string-trim-right
   (buffer-substring-no-properties (point-min) (point-max))))

(defun bbs-ui-compose-submit (&optional publish)
  "Save the current composer locally; with PUBLISH, explicitly publish it."
  (interactive)
  (let ((body (bbs-ui--compose-body))
        (owner bbs-ui--compose-owner)
        (kind bbs-ui--compose-kind)
        (target bbs-ui--compose-target)
        (title bbs-ui--compose-title)
        (mimetype bbs-ui--compose-mimetype)
        (page bbs-ui--compose-page)
        (buffer (current-buffer)))
    (unless (buffer-live-p owner) (user-error "The BBS buffer was closed"))
    (when (string-empty-p (string-trim body))
      (user-error "Transmission body cannot be empty"))
    (when (and title (or (string-empty-p (string-trim title)) (> (length title) 125)))
      (user-error "Thread title must contain 1–125 characters"))
    (with-current-buffer owner
      (let ((repository (plist-get textui-state :repository)))
        (if (eq kind 'wiki)
            (bbs-ui--wiki-write repository page mimetype body)
          (bbs-ui--forum-write repository kind target title mimetype body))))
    (set-buffer-modified-p nil)
    (kill-buffer buffer)
    (pop-to-buffer owner)
    (with-current-buffer owner
      (bbs-ui--reload t)
      (bbs-ui--set-notice
       (if publish
           "SAVED LOCALLY · PUBLISH SCOPE REVIEW FOLLOWS"
         "SAVED LOCALLY · NOTHING TRANSMITTED"))
      (when publish
        ;; The second confirmation is intentional: it shows the actual
        ;; repository-wide unsent set after the new artifact exists.
        (call-interactively #'bbs-ui-publish-pending)))))

(defun bbs-ui-compose-save ()
  "Save the current composer locally without network activity."
  (interactive)
  (bbs-ui-compose-submit nil))

(defun bbs-ui-compose-publish ()
  "Save locally, then request an explicit repository-wide publish."
  (interactive)
  (bbs-ui-compose-submit t))

(defun bbs-ui-compose-cancel ()
  "Cancel the current composer."
  (interactive)
  (let ((owner bbs-ui--compose-owner))
    (when (or (not (buffer-modified-p))
              (yes-or-no-p "Discard this local draft? "))
      (set-buffer-modified-p nil)
      (kill-buffer (current-buffer))
      (when (buffer-live-p owner) (pop-to-buffer owner)))))

(defun bbs-ui-compose-preview ()
  "Show a source-faithful preview of the current composer."
  (interactive)
  (let ((buffer (get-buffer-create "*BBS preview*"))
        (body (bbs-ui--compose-body))
        (mimetype bbs-ui--compose-mimetype))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (bbs-ui--markup-text body mimetype))
        (goto-char (point-min))
        (special-mode)))
    (display-buffer buffer)))

(defvar bbs-ui-compose-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map markdown-mode-map)
    (define-key map (kbd "C-c C-c") #'bbs-ui-compose-save)
    (define-key map (kbd "C-c C-p") #'bbs-ui-compose-publish)
    (define-key map (kbd "C-c C-v") #'bbs-ui-compose-preview)
    (define-key map (kbd "C-c C-k") #'bbs-ui-compose-cancel)
    map)
  "Keymap for `bbs-ui-compose-mode'.")

(defun bbs-ui-compose--header-line ()
  "Return the transmission editor's context header."
  (let ((subject (or bbs-ui--compose-title bbs-ui--compose-page
                     (upcase (format "%s" bbs-ui--compose-kind)))))
    (concat
     (propertize "  COPLAND.SYSTEMS // TRANSMISSION EDITOR  "
                 'face 'bbs-ui-logo)
     (propertize (format " %-40s "
                         (truncate-string-to-width subject 40 nil nil "…"))
                 'face 'bbs-ui-bar)
     (propertize " LOCAL DRAFT · OFFLINE " 'face 'bbs-ui-green))))

(defun bbs-ui-compose--mode-line ()
  "Return the transmission editor's persistent command bar."
  (propertize
   "  C-c C-c SAVE LOCAL   C-c C-v PREVIEW   C-c C-p REVIEW + PUBLISH   C-c C-k ABORT  "
   'face 'bbs-ui-bar))

(define-derived-mode bbs-ui-compose-mode markdown-mode "BBS-Compose"
  "Major mode for composing local Fossil forum and wiki artifacts."
  (setq-local header-line-format '(:eval (bbs-ui-compose--header-line)))
  (setq-local mode-line-format '(:eval (bbs-ui-compose--mode-line)))
  (setq-local fill-column 78)
  (setq-local cursor-type 'bar))

(defun bbs-ui--open-composer (kind &optional target title mimetype body page)
  "Open a composer for KIND with TARGET, TITLE, MIMETYPE, BODY and PAGE."
  (let* ((owner (current-buffer))
         (name (format "*BBS compose: %s*" (or title page kind)))
         (buffer (get-buffer-create name)))
    (with-current-buffer buffer
      (bbs-ui-compose-mode)
      (setq-local bbs-ui--compose-owner owner
                  bbs-ui--compose-kind kind
                  bbs-ui--compose-target target
                  bbs-ui--compose-title title
                  bbs-ui--compose-mimetype (or mimetype "text/x-markdown")
                  bbs-ui--compose-page page)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (or body ""))
        (goto-char (point-max)))
      (set-buffer-modified-p nil))
    (pop-to-buffer buffer)
    buffer))

(defun bbs-ui-new-thread (title)
  "Compose a new forum thread with TITLE."
  (interactive (list (read-string "Thread title: ")))
  (when (or (string-empty-p (string-trim title)) (> (length title) 125))
    (user-error "Thread title must contain 1–125 characters"))
  (bbs-ui--open-composer 'thread nil title "text/x-markdown"))

(defun bbs-ui-reply ()
  "Reply to the post or selected thread at point."
  (interactive)
  (let* ((target (or (bbs-ui--semantic-target)
                     (cons (bbs-ui--kind-at-point) (bbs-ui--id-at-point))))
         (kind (car target))
         (id (cdr target))
         (post
          (pcase kind
            ('post (bbs-ui--find-post id))
            ('thread (plist-get (bbs-ui--find-thread id) :root))
            (_ (and (eq (plist-get textui-state :view) 'thread)
                    (plist-get (bbs-ui--find-thread (plist-get textui-state :view-id))
                               :root))))))
    (unless post (user-error "No post to reply to"))
    (bbs-ui--open-composer 'reply (plist-get post :uuid) nil
                           (plist-get post :mimetype))))

(defun bbs-ui-edit ()
  "Edit the post at point or the displayed wiki page."
  (interactive)
  (if (eq (plist-get textui-state :view) 'wiki-page)
      (let ((page (bbs-ui--find-wiki (plist-get textui-state :view-id))))
        (unless page (user-error "Wiki page not found"))
        (bbs-ui--open-composer 'wiki nil nil (plist-get page :mimetype)
                               (plist-get page :body) (plist-get page :name)))
    (let* ((id (cdr (or (bbs-ui--semantic-target)
                        (cons nil (bbs-ui--id-at-point)))))
           (post (and id (bbs-ui--find-post id))))
      (unless post (user-error "Move point to a post header before editing"))
      (if (not (equal (plist-get post :user) (plist-get textui-state :user)))
          (bbs-ui--set-notice
           "READ-ONLY TRANSMISSION · MODERATION STAYS IN THE WEB UI")
        (bbs-ui--open-composer 'edit (plist-get post :uuid)
                               (plist-get post :title) (plist-get post :mimetype)
                               (plist-get post :body))))))

(defun bbs-ui-new-wiki-page (name)
  "Compose a new wiki page NAME."
  (interactive (list (read-string "New wiki page: ")))
  (when (string-empty-p (string-trim name))
    (user-error "Wiki page name cannot be empty"))
  (when (bbs-ui--find-wiki name)
    (user-error "Wiki page already exists; open it and press e"))
  (bbs-ui--open-composer 'wiki nil nil "text/x-markdown" nil name))

(defun bbs-ui-history ()
  "Show immutable edit history for the post at point."
  (interactive)
  (let* ((id (cdr (or (bbs-ui--semantic-target)
                      (cons nil (bbs-ui--id-at-point)))))
         (post (and id (bbs-ui--find-post id))))
    (unless post (user-error "No post at point"))
    (let ((buffer (get-buffer-create "*BBS post history*")))
      (with-current-buffer buffer
        (let ((inhibit-read-only t))
          (erase-buffer)
          (dolist (version (reverse (plist-get post :history)))
            (insert (propertize
                     (format "%s  %s  %s\n"
                             (substring (plist-get version :uuid) 0 12)
                             (plist-get version :user)
                             (format-time-string "%Y-%m-%d %H:%M:%S"
                                                 (seconds-to-time
                                                  (plist-get version :time))))
                     'face 'bbs-ui-cyan))
            (insert (bbs-ui--markup-text (plist-get version :body)
                                         (plist-get version :mimetype)) "\n\n"))
          (goto-char (point-min))
          (special-mode)))
      (pop-to-buffer buffer))))

(defun bbs-ui-open-web ()
  "Open the current thread or wiki page on the configured remote."
  (interactive)
  (let ((remote (or bbs-ui-web-base-url
                    (plist-get textui-state :remote)))
        path)
    (if (not remote)
        (bbs-ui--set-notice
         "NO PUBLIC WEB ENDPOINT CONFIGURED · LOCAL ARCHIVE STILL AVAILABLE")
      (setq remote (replace-regexp-in-string "/+\\'" "" remote))
      (setq path
            (pcase (plist-get textui-state :view)
              ('thread (concat "/forumpost/" (plist-get textui-state :view-id)))
              ('wiki-page (concat "/wiki?name="
                                  (url-hexify-string
                                   (plist-get textui-state :view-id))))
              (_ "/forum")))
      (browse-url (concat remote path)))))

(defun bbs-ui-help ()
  "Show the BBS command reference and safety model."
  (interactive)
  (let ((buffer (get-buffer-create "*bbs-ui help*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert
         "FEED://BBS\n\n"
         "The Fossil repository is the offline archive. Opening and refreshing\n"
         "read local data. Pull receives artifacts only. Nothing publishes until\n"
         "you invoke Publish and confirm the complete repository-wide queue.\n\n"
         "This client never exposes moderator or admin operations. Foreign posts\n"
         "are read-only; use the web UI deliberately for administration.\n\n"
         "b/v/u/s     Board / Wiki / Users / Saved\n"
         "/           local full-text search       N new thread\n"
         "j/k, ↑/↓    next / previous row          RET open\n"
         "PgUp/PgDn   page list or reader          TAB index / preview\n"
         "←/→         previous / next reply in a thread\n"
         "r/e         reply / edit                 s toggle saved\n"
         "g           pull only                    P publish queue\n"
         "h/w         post history / open web      E diagnostics\n"
         "q           back or close\n"
         "W           new wiki page                R local refresh\n\n"
         "Composer: C-c C-c Save Local, C-c C-p Publish, C-c C-v Preview,\n"
         "C-c C-k Cancel.\n")
        (goto-char (point-min))
        (special-mode)))
    (pop-to-buffer buffer)))

(defun bbs-ui--visible-height ()
  "Return the smallest body height displaying the current BBS."
  (when-let* ((windows (get-buffer-window-list (current-buffer) nil t)))
    (apply #'min (mapcar #'window-body-height windows))))

(defun bbs-ui--window-size-changed (_window)
  "Track the BBS window height for responsive rendering."
  (when (and (derived-mode-p 'bbs-ui-mode)
             (not (bound-and-true-p textui--refreshing)))
    (when-let* ((height (bbs-ui--visible-height)))
      (unless (equal height bbs-ui--window-height)
        (setq bbs-ui--window-height height)
        (textui-set-state (current-buffer) :height height)))))

(defun bbs-ui--pin-window-start ()
  "Keep every visible BBS window pinned to its full-screen frame."
  (when (derived-mode-p 'bbs-ui-mode)
    (dolist (window (get-buffer-window-list (current-buffer) nil t))
      (set-window-start window (point-min) t))))

(defvar bbs-ui-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map textui-mode-map)
    (define-key map (kbd "b") #'bbs-ui-board)
    (define-key map (kbd "v") #'bbs-ui-wiki)
    (define-key map (kbd "u") #'bbs-ui-users)
    (define-key map (kbd "s") #'bbs-ui-toggle-save)
    (define-key map (kbd "S") #'bbs-ui-saved)
    (define-key map (kbd "/") #'bbs-ui-search)
    (define-key map (kbd "N") #'bbs-ui-new-thread)
    (define-key map (kbd "W") #'bbs-ui-new-wiki-page)
    (define-key map (kbd "g") #'bbs-ui-pull)
    (define-key map (kbd "R") #'bbs-ui-refresh)
    (define-key map (kbd "P") #'bbs-ui-publish-pending)
    (define-key map (kbd "RET") #'bbs-ui-open-at-point)
    (define-key map (kbd "<return>") #'bbs-ui-open-at-point)
    (define-key map (kbd "TAB") #'bbs-ui-toggle-pane)
    (define-key map (kbd "<tab>") #'bbs-ui-toggle-pane)
    (define-key map (kbd "<down>") #'bbs-ui-next-row)
    (define-key map (kbd "<up>") #'bbs-ui-previous-row)
    (define-key map (kbd "<right>") #'bbs-ui-next-message)
    (define-key map (kbd "<left>") #'bbs-ui-previous-message)
    (define-key map (kbd "C-v") #'bbs-ui-page-down)
    (define-key map (kbd "M-v") #'bbs-ui-page-up)
    (define-key map (kbd "<next>") #'bbs-ui-page-down)
    (define-key map (kbd "<prior>") #'bbs-ui-page-up)
    (define-key map (kbd "r") #'bbs-ui-reply)
    (define-key map (kbd "e") #'bbs-ui-edit)
    (define-key map (kbd "h") #'bbs-ui-history)
    (define-key map (kbd "w") #'bbs-ui-open-web)
    (define-key map (kbd "j") #'bbs-ui-next-row)
    (define-key map (kbd "n") #'bbs-ui-next-row)
    (define-key map (kbd "k") #'bbs-ui-previous-row)
    (define-key map (kbd "p") #'bbs-ui-previous-row)
    (define-key map (kbd "?") #'bbs-ui-help)
    (define-key map (kbd "E") #'bbs-ui-show-diagnostics)
    (define-key map (kbd "q") #'bbs-ui-back)
    map)
  "Keymap for `bbs-ui-mode'.")

(defconst bbs-ui--evil-bindings
  '(("b" . bbs-ui-board) ("v" . bbs-ui-wiki) ("u" . bbs-ui-users)
    ("s" . bbs-ui-toggle-save) ("S" . bbs-ui-saved) ("/" . bbs-ui-search)
    ("N" . bbs-ui-new-thread) ("W" . bbs-ui-new-wiki-page)
    ("g" . bbs-ui-pull) ("R" . bbs-ui-refresh) ("P" . bbs-ui-publish-pending)
    ("RET" . bbs-ui-open-at-point) ("<return>" . bbs-ui-open-at-point)
    ("TAB" . bbs-ui-toggle-pane) ("<tab>" . bbs-ui-toggle-pane)
    ("<down>" . bbs-ui-next-row) ("<up>" . bbs-ui-previous-row)
    ("<right>" . bbs-ui-next-message) ("<left>" . bbs-ui-previous-message)
    ("C-v" . bbs-ui-page-down) ("M-v" . bbs-ui-page-up)
    ("<next>" . bbs-ui-page-down) ("<prior>" . bbs-ui-page-up)
    ("r" . bbs-ui-reply) ("e" . bbs-ui-edit) ("h" . bbs-ui-history)
    ("w" . bbs-ui-open-web) ("j" . bbs-ui-next-row) ("n" . bbs-ui-next-row)
    ("k" . bbs-ui-previous-row) ("p" . bbs-ui-previous-row)
    ("?" . bbs-ui-help) ("E" . bbs-ui-show-diagnostics)
    ("q" . bbs-ui-back))
  "Bindings owned by BBS buffers in modal states.")

(defun bbs-ui--refresh-command-map ()
  "Install BBS bindings idempotently, including after a live source reload."
  (set-keymap-parent bbs-ui-mode-map textui-mode-map)
  (dolist (binding bbs-ui--evil-bindings)
    (define-key bbs-ui-mode-map (kbd (car binding)) (cdr binding))))

(bbs-ui--refresh-command-map)

(defvar bbs-ui--emulation-mode-map-alist
  `((bbs-ui--keys-active . ,bbs-ui-mode-map))
  "Highest-priority BBS bindings used while a BBS buffer is active.")

(add-to-list 'emulation-mode-map-alists 'bbs-ui--emulation-mode-map-alist)

(defun bbs-ui--install-general-bindings ()
  "Install buffer-local General overrides for BBS."
  (general-local-map)
  (dolist (binding bbs-ui--evil-bindings)
    (general-define-key :states '(normal motion)
                        :keymaps 'general-override-local-mode-map
                        (car binding) (cdr binding)))
  (when (fboundp 'evil-get-auxiliary-keymap)
    (dolist (state '(normal motion))
      (evil-make-intercept-map
       (evil-get-auxiliary-keymap general-override-local-mode-map state t t)
       state))))

(define-derived-mode bbs-ui-mode textui-mode "BBS"
  "Major mode for the Fossil-native BBS."
  (setq-local truncate-lines t cursor-type nil mode-line-format "")
  (setq-local bbs-ui--keys-active t)
  (add-hook 'window-size-change-functions #'bbs-ui--window-size-changed nil t)
  (add-hook 'post-command-hook #'bbs-ui--pin-window-start nil t)
  (when (fboundp 'general-define-key) (bbs-ui--install-general-bindings))
  (when (fboundp 'evil-normalize-keymaps) (evil-normalize-keymaps)))

;; `load-file' does not re-run the major mode of an already open BBS buffer.
;; Upgrade those buffers in place so no Evil/global command can leak through.
(dolist (buffer (buffer-list))
  (with-current-buffer buffer
    (when (derived-mode-p 'bbs-ui-mode)
      (setq-local bbs-ui--keys-active t))))

(defun bbs-ui--install-evil-bindings ()
  "Make BBS bindings precede global modal bindings."
  (evil-set-initial-state 'bbs-ui-mode 'normal)
  (evil-make-intercept-map bbs-ui-mode-map)
  (dolist (binding bbs-ui--evil-bindings)
    (evil-define-key* '(normal motion) bbs-ui-mode-map
      (kbd (car binding)) (cdr binding))))

(with-eval-after-load 'evil
  (bbs-ui--install-evil-bindings))

(with-eval-after-load 'general
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'bbs-ui-mode)
        (bbs-ui--install-general-bindings)))))

;;;###autoload
(defun bbs-open (repository)
  "Open a local-first BBS backed by Fossil REPOSITORY."
  (interactive
   (list (read-file-name "Fossil BBS repository: " nil bbs-ui-repository-file t
                         nil (lambda (file) (or (file-directory-p file)
                                               (string-suffix-p ".fossil" file))))))
  (setq repository (expand-file-name repository))
  (let* ((snapshot (bbs-ui--snapshot repository))
         (project (plist-get snapshot :project))
         (name (format "*BBS: %s*" project))
         (existing (get-buffer name))
         buffer)
    (when (and existing
               (with-current-buffer existing (not (derived-mode-p 'bbs-ui-mode))))
      (user-error "A non-BBS buffer already uses %s" name))
    (setq buffer (or existing (get-buffer-create name)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'bbs-ui-mode) (bbs-ui-mode))
      (setq-local default-directory (file-name-directory repository)))
    (textui-open name #'bbs-ui--frame snapshot)
    (with-current-buffer buffer
      (when-let* ((height (bbs-ui--visible-height)))
        (setq bbs-ui--window-height height)
        (textui-set-state buffer :height height))
      (when-let* ((target (bbs-ui--semantic-target)))
        (bbs-ui--goto-id (cdr target)))
      (when (and bbs-ui-pull-on-open (plist-get textui-state :remote))
        (bbs-ui-pull)))
    buffer))

;;;###autoload
(defun bbs (&optional repository)
  "Open the configured Fossil BBS REPOSITORY."
  (interactive)
  (bbs-open
   (or repository bbs-ui-repository-file
       (read-file-name "Fossil BBS repository: " nil nil t nil
                       (lambda (file) (or (file-directory-p file)
                                          (string-suffix-p ".fossil" file)))))))

(provide 'bbs-ui)
;;; bbs-ui.el ends here
