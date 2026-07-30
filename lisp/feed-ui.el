;;; feed-ui.el --- A vui client for feed.org -*- lexical-binding: t -*-

;; A vui.el front-end for the git-powered decentralized feed living in
;; feed.org.  The org file stays the single source of truth; this file
;; is only a client.  All git operations and post parsing reuse the
;; `feed//...' engine defined in feed.org's `engine' src block - open
;; feed.org once (accepting the file-local variables) before `M-x feed'.

;; Layout: borderless, left-aligned.  Cards carry the thread semantics:
;;   ● own root post   ○ other root post   ◐ reply
;; Views: timeline -> thread (org-like tree) -> profile / tag, with a
;; navigation stack (q goes back, then quits).
;; Keys: RET thread · r reply · m mute · g sync · q back/quit.

;;; Code:

(require 'vui)
(require 'vui-components)
(require 'cl-lib)

;;; § 1 Engine bridge

(defgroup feed-ui nil
  "vui client for feed.org."
  :group 'applications)

(defcustom feed-ui-file
  (expand-file-name "feed.org"
                    (file-name-directory
                     (or load-file-name buffer-file-name default-directory)))
  "Path to the feed.org console file."
  :type 'file
  :group 'feed-ui)

;; Defined by feed.org's `engine' block:
(defvar feed/file)
(declare-function feed//collect "feed")
(declare-function feed//newer "feed")
(declare-function feed//seconds "feed")
(declare-function feed//pending-all "feed")
(declare-function feed//own-files "feed")
(declare-function feed//pick-own-file "feed")
(declare-function feed//git "feed")
(declare-function feed//approved-branch "feed")
(declare-function feed//remote-branch "feed")
(declare-function feed/sync "feed")
(declare-function feed/approve "feed")
(declare-function feed/review "feed")
(declare-function feed/publish "feed")

(defun feed-ui--ensure-engine ()
  "Make sure the feed.org engine is loaded, or signal a helpful error."
  (unless (fboundp 'feed//collect)
    (when (file-exists-p feed-ui-file)
      (find-file-noselect feed-ui-file)) ; file-local eval loads the engine
    (unless (fboundp 'feed//collect)
      (user-error "feed-ui: engine not loaded - open %s and accept the file-local variables"
                  feed-ui-file))))

;;; § 2 Data layer
;;
;; The engine yields posts as (ts nick body reply-to tags).  The client
;; adapts them to plists once; every view works with these.

(defun feed-ui--post-plist (post)
  "Adapt an engine POST tuple to a plist.
:id is \"nick/ts\" - the same string a :REPLY_TO: property points at,
so it doubles as the threading key and the vui reconciliation key."
  (pcase-let ((`(,ts ,nick ,body ,reply-to ,tags) post))
    (list :id (concat nick "/" ts)
          :ts ts
          :nick nick
          :body body
          :reply-to reply-to
          :tags tags
          :seconds (feed//seconds ts))))

(defun feed-ui--posts ()
  "Collect every approved post, newest first, as plists."
  (mapcar #'feed-ui--post-plist (sort (feed//collect) #'feed//newer)))

(defun feed-ui--own-nicks ()
  "Nicks hosted by this repo (basenames of local <nick>.org files)."
  (mapcar #'file-name-base (feed//own-files)))

(defun feed-ui--ago (seconds)
  "Human relative time for SECONDS since epoch."
  (let ((d (- (float-time) seconds)))
    (cond ((< d 90) "now")
          ((< d 3600) (format "%dm" (floor d 60)))
          ((< d 86400) (format "%dh" (floor d 3600)))
          ((< d (* 7 86400)) (format "%dd" (floor d 86400)))
          (t (format-time-string "%Y-%m-%d" (seconds-to-time seconds))))))

(defun feed-ui--children-of (posts id)
  "Direct replies to the post ID, oldest first (conversation order)."
  (sort (cl-remove-if-not (lambda (p) (equal (plist-get p :reply-to) id))
                          posts)
        (lambda (a b) (< (plist-get a :seconds) (plist-get b :seconds)))))

(defun feed-ui--reply-counts (posts)
  "Hash post-id -> number of direct replies."
  (let ((counts (make-hash-table :test 'equal)))
    (dolist (p posts counts)
      (when-let* ((parent (plist-get p :reply-to)))
        (puthash parent (1+ (gethash parent counts 0)) counts)))))

(defun feed-ui--pending-posts (nick)
  "Posts that NICK's unapproved commits would add, oldest commit first.
Parses the added lines of `git log --patch' over the pending range:
every added `** TIMESTAMP' heading starts a post, the following added
lines (property drawer excluded) are its body."
  (let* ((approved (feed//approved-branch nick))
         (branch (feed//remote-branch nick))
         (range (if approved (concat approved ".." branch) branch))
         (diff (or (feed//git (list "log" "--patch" range)) ""))
         (added nil))
    (dolist (line (split-string diff "\n"))
      (when (and (string-prefix-p "+" line)
                 (not (string-prefix-p "+++" line)))
        (push (substring line 1) added)))
    (let ((posts nil) (cur nil) (in-drawer nil))
      (dolist (line (nreverse added))
        (cond
         ;; new post heading: capture the timestamp title
         ((string-match "\\`\\*+ \\([0-9][^ 
]*\\)" line)
          (when cur (push cur posts))
          (setq cur (list (match-string 1 line) nil)
                in-drawer nil))
         ((string-prefix-p ":PROPERTIES:" (string-trim line))
          (setq in-drawer t))
         ((string-prefix-p ":END:" (string-trim line))
          (setq in-drawer nil))
         ((and cur (not in-drawer))
          (push line (cadr cur)))))
      (when cur (push cur posts))
      (mapcar (lambda (p)
                (list :ts (car p)
                      :body (string-trim (string-join (nreverse (cadr p)) "\n"))))
              (nreverse posts)))))

;;; § 3 Atoms

(defun feed-ui--tokens (text)
  "Split TEXT into (RAW . DISPLAY-WIDTH) tokens.
Org links are atomic: the raw form keeps the full [[url][desc]] syntax
(so the line renderer can still make it a button), while the display
width counts only what the button will show."
  (let ((tokens nil) (pos 0))
    (while (< pos (length text))
      (cond
       ((string-match "\\[\\[\\([^]\n]+\\)\\]\\(?:\\[\\([^]\n]+\\)\\]\\)?\\]" text pos)
        ;; Capture match data BEFORE `split-string' clobbers it.
        (let ((beg (match-beginning 0))
              (end (match-end 0))
              (raw (match-string 0 text))
              (disp (or (match-string 2 text) (match-string 1 text))))
          (when (> beg pos)
            (dolist (word (split-string (substring text pos beg) nil t))
              (push (cons word (string-width word)) tokens)))
          (push (cons raw (string-width disp)) tokens)
          (setq pos end)))
       (t
        (dolist (word (split-string (substring text pos) nil t))
          (push (cons word (string-width word)) tokens))
        (setq pos (length text)))))
    (nreverse tokens)))

(defun feed-ui--wrap (text width)
  "Greedy word-wrap TEXT to WIDTH display columns.
Returns a list of lines.  Org links are never split across lines."
  (let ((lines nil) (cur nil) (cur-w 0))
    (dolist (tok (feed-ui--tokens text))
      (if (and cur (> (+ cur-w 1 (cdr tok)) width))
          (progn
            (push (mapconcat #'car (nreverse cur) " ") lines)
            (setq cur (list tok)
                  cur-w (cdr tok)))
        (push tok cur)
        (setq cur-w (if (cdr cur) (+ cur-w 1 (cdr tok)) (cdr tok)))))
    (when cur
      (push (mapconcat #'car (nreverse cur) " ") lines))
    (nreverse (or lines (list "")))))

(defun feed-ui--line-vnode (line)
  "Render one body LINE, turning [[url][desc]] org links into buttons."
  (let ((parts nil) (pos 0))
    (while (string-match "\\[\\[\\([^]\n]+\\)\\]\\(?:\\[\\([^]\n]+\\)\\]\\)?\\]" line pos)
      (let ((url (match-string 1 line))
            (desc (or (match-string 2 line) (match-string 1 line)))
            (start (match-beginning 0)))
        (push (vui-text (substring line pos start)) parts)
        (push (vui-button desc
                :on-click (lambda () (browse-url url))
                :no-decoration t
                :face 'link
                :help-echo nil)
              parts)
        (setq pos (match-end 0))))
    (push (vui-text (substring line pos)) parts)
    (if (cdr parts)
        (apply #'vui-hstack :spacing 0 (nreverse parts))
      (car parts))))

(defun feed-ui--body-vnodes (body)
  "Render post BODY as a list of vnodes, one per line.
Each source line is word-wrapped so the rendered card, indent
included, stays within `fill-column'."
  (let ((width (max 20 (- fill-column 2))))
    (mapcan (lambda (line)
              (mapcar #'feed-ui--line-vnode
                      (if (string-empty-p (string-trim line))
                          (list "")
                        (feed-ui--wrap line width))))
            (split-string body "\n"))))

(defun feed-ui--tag-pill (tag on-click)
  "Render TAG as a quiet clickable pill calling ON-CLICK."
  (vui-button (concat ":" tag ":")
    :on-click on-click
    :no-decoration t
    :face 'shadow
    :help-echo nil))

;;; § 4 Post card - the shared molecule

(defun feed-ui--card (post own-p reply-count on-nav &optional guide full-ts)
  "Render POST as a card.  OWN-P marks posts by this repo's own nicks.
REPLY-COUNT decorates the thread button.  ON-NAV is called with
\(view . args) for profile/thread/tag navigation.  GUIDE is an optional
tree-guide prefix (\"├─\"/\"└─\") for the meta line; FULL-TS shows the
raw timestamp instead of relative time.
Every interactive child carries the post id as :key so point-based
commands (RET/r/m) can find the post under the cursor via `vui-key-at'."
  (let* ((id (plist-get post :id))
         (nick (plist-get post :nick))
         (reply-to (plist-get post :reply-to))
         (marker (cond (reply-to "◐") (own-p "●") (t "○")))
         (marker-face (cond (reply-to 'warning) (own-p 'success) (t 'shadow))))
    (vui-vstack
     :spacing 0
     ;; meta line: [guide] marker · nick · ago · reply indicator
     (vui-hstack
      :spacing 1
      (when guide (vui-text guide :face 'shadow))
      (vui-text marker :face marker-face)
      (vui-button nick
        :key id
        :on-click (lambda () (funcall on-nav 'profile nick))
        :no-decoration t
        :face (if own-p '(:inherit success :weight bold) 'bold)
        :help-echo nil)
      (vui-text "·" :face 'shadow)
      (vui-text (if full-ts
                    (plist-get post :ts)
                  (feed-ui--ago (plist-get post :seconds)))
                :face 'shadow)
      (when reply-to
        (list (vui-text "·" :face 'shadow)
              (vui-text (format "↩ %s" (car (split-string reply-to "/")))
                        :face 'shadow))))
     ;; body
     (apply #'vui-vstack :indent 2 :spacing 0
            (feed-ui--body-vnodes (plist-get post :body)))
     ;; tags + actions
     (vui-hstack
      :spacing 1
      (vui-space 2)
      (mapcar (lambda (tag)
                (feed-ui--tag-pill tag (lambda () (funcall on-nav 'tag tag))))
              (plist-get post :tags))
      (when (plist-get post :tags) (vui-text "·" :face 'shadow))
      (vui-button "↩ reply"
        :key id
        :on-click (lambda () (feed-ui-compose id))
        :no-decoration t
        :face 'shadow
        :help-echo nil)
      (vui-text "·" :face 'shadow)
      (vui-button (if (> reply-count 0)
                      (format "▸ thread (%d)" reply-count)
                    "▸ thread")
        :key id
        :on-click (lambda () (funcall on-nav 'thread id))
        :no-decoration t
        :face 'shadow
        :help-echo nil)))))

;;; § 5 Views

(defun feed-ui--thread-node (post posts own-nicks counts on-nav &optional guide full-ts)
  "Render POST and its whole reply subtree, org-outline style.
Children are indented one level; each gets a \"├─\"/\"└─\" guide."
  (let* ((id (plist-get post :id))
         (children (feed-ui--children-of posts id)))
    (vui-vstack
     :spacing 1
     (feed-ui--card post (member (plist-get post :nick) own-nicks)
                    (gethash id counts 0) on-nav guide full-ts)
     (when children
       (apply #'vui-vstack :indent 2 :spacing 1
              (cl-loop for child in children
                       for rest on children
                       collect (feed-ui--thread-node
                                child posts own-nicks counts on-nav
                                (if (null (cdr rest)) "└─" "├─"))))))))

(defun feed-ui--thread-view (id posts own-nicks counts on-nav)
  "Full-thread view rooted at post ID."
  (let ((root (cl-find-if (lambda (p) (equal (plist-get p :id) id)) posts)))
    (if (null root)
        (vui-text "Post not found (not approved yet?)" :face 'warning)
      (feed-ui--thread-node root posts own-nicks counts on-nav nil t))))

(defun feed-ui--profile-view (nick posts own-nicks counts on-nav)
  "Profile view: stats header plus NICK's posts, newest first."
  (let* ((mine (cl-remove-if-not (lambda (p) (equal (plist-get p :nick) nick)) posts))
         (tags (delete-dups (apply #'append
                                   (mapcar (lambda (p) (copy-sequence (plist-get p :tags)))
                                           mine))))
         (nreplies (cl-count-if (lambda (p) (plist-get p :reply-to)) mine)))
    (if (null mine)
        (vui-text "No approved posts from this nick." :face 'shadow)
      (vui-vstack
       :spacing 1
       (vui-text (format "%d posts · %d replies" (length mine) nreplies)
                 :face 'shadow)
       (when tags
         (vui-hstack
          :spacing 1
          (mapcar (lambda (tag)
                    (feed-ui--tag-pill tag (lambda () (funcall on-nav 'tag tag))))
                  tags)))
       (vui-list mine
                 (lambda (post)
                   (feed-ui--card post
                                  (member (plist-get post :nick) own-nicks)
                                  (gethash (plist-get post :id) counts 0)
                                  on-nav))
                 (lambda (post) (plist-get post :id))
                 :spacing 1)))))

(defun feed-ui--tag-view (tag posts own-nicks counts on-nav)
  "Every post carrying TAG, newest first."
  (let ((hits (cl-remove-if-not
               (lambda (p) (member tag (plist-get p :tags))) posts)))
    (if (null hits)
        (vui-text "No posts with this tag." :face 'shadow)
      (vui-list hits
                (lambda (post)
                  (feed-ui--card post
                                 (member (plist-get post :nick) own-nicks)
                                 (gethash (plist-get post :id) counts 0)
                                 on-nav))
                (lambda (post) (plist-get post :id))
                :spacing 1))))

(defun feed-ui--review-view (pending on-nav)
  "Review queue: one row per nick with unapproved commits."
  (if (null pending)
      (vui-text "Nothing pending." :face 'shadow)
    (vui-vstack
     :spacing 0
     (mapcar (lambda (p)
               (vui-hstack
                :spacing 1
                (vui-text "▸" :face 'warning)
                (vui-button (car p)
                  :on-click (lambda () (funcall on-nav 'review-detail (car p)))
                  :no-decoration t
                  :face 'bold
                  :help-echo nil)
                (vui-text (format "%d pending" (cdr p)) :face 'warning)))
             pending))))

(defun feed-ui--review-detail-view (nick on-approve)
  "The posts NICK's pending commits would add, plus the approve button."
  (let ((pending (feed-ui--pending-posts nick)))
    (vui-vstack
     :spacing 1
     (if (null pending)
         (vui-text "No new posts in the pending commits." :face 'shadow)
       (vui-vstack
        :spacing 1
        (mapcar (lambda (p)
                  (vui-vstack
                   :spacing 0
                   (vui-text (format "+ %s" (plist-get p :ts)) :face 'success)
                   (apply #'vui-vstack :indent 2 :spacing 0
                          (feed-ui--body-vnodes (plist-get p :body)))))
                pending)))
     (vui-hstack
      :spacing 2
      (vui-button "approve" :face 'success :on-click on-approve)
      (vui-text "unapproved commits never enter any timeline" :face 'shadow)))))

;;; § 5b Compose
;;
;; A post body is org content - links, emphasis, src blocks, whole blog
;; posts - so it is edited in a real org buffer.  The vui part is an
;; inline form pinned at the top (tags, reply context, actions); the
;; body is everything below the form's managed region.

(defvar-local feed-ui--compose-reply-to nil
  "Post id this compose buffer replies to, or nil.")

(defvar-local feed-ui--compose-instance nil
  "The inline vui instance managing the compose form region.")

(defvar feed-ui--live-refresh nil
  "Refresh closure stashed by the last feed-app render, or nil.")

(vui-defcomponent feed-compose-form (reply-to)
  "Inline compose form: tags field, reply context, submit actions."
  :render
  ;; wid-edit's `widget-before-change' rejects EVERY edit outside an
  ;; editable field - including the body area below this form, which is
  ;; the point of the compose buffer.  vui installs it buffer-wide via
  ;; `widget-setup' on every inline commit (a policy meant for dedicated
  ;; vui buffers), so remove it after every mount commit.  NOTE: any
  ;; future inline RE-render re-arms it and the removal must be repeated
  ;; (effects run post-commit); this form currently never re-renders.
  (progn
    (vui-use-effect ()
      (remove-hook 'before-change-functions 'widget-before-change t))
    (vui-vstack
   :spacing 1
   (vui-hstack
    :spacing 1
    (vui-box (vui-text "tags:" :face 'shadow) :width 7 :align :right)
    (vui-field :size 48 :key 'tags :placeholder "emacs vui (space separated, optional)"))
   (when reply-to
     (vui-hstack
      :spacing 1
      (vui-box (vui-text "reply:" :face 'shadow) :width 7 :align :right)
      (vui-text reply-to :face 'shadow)))
   (vui-hstack
    :spacing 2
    (vui-box (vui-text "") :width 7)
    (vui-button "post" :on-click (lambda () (feed-ui--compose-submit nil)))
    (vui-button "post & publish" :on-click (lambda () (feed-ui--compose-submit t)))
    (vui-button "cancel"
      :on-click (lambda () (feed-ui--compose-cancel))
      :no-decoration t
      :face 'shadow
      :help-echo nil))
   (vui-hstack
    :spacing 1
    (vui-box (vui-text "") :width 7)
    (vui-text "write the body below · C-c C-c post · C-c C-k cancel"
              :face 'shadow)))))

(defun feed-ui--write-post (body tags reply-to)
  "Write a complete post with BODY and TAGS into the user's own org file.
Mirrors the engine's insertion format exactly; REPLY-TO, when non-nil,
lands in the :REPLY_TO: drawer property.  Returns the file written."
  (let ((file (feed//pick-own-file)))
    (unless (file-exists-p file)
      (write-region (format "#+TITLE: %s\n\n* Journal :posts:\n"
                            (file-name-base file))
                    nil file))
    (with-current-buffer (find-file-noselect file)
      (save-excursion
        (goto-char (point-min))
        (unless (re-search-forward "^\\*+ [^\n]*:posts:" nil t)
          (user-error "No headline tagged :posts: in %s" file))
        (beginning-of-line)
        (looking-at "^\\*+")
        (forward-line 1)
        (insert (format "%s %s%s\n:PROPERTIES:\n%s:END:\n\n%s\n\n"
                        (make-string (1+ (length (match-string 0))) ?*)
                        (format-time-string "%Y-%m-%dT%H:%M:%S%z")
                        (if tags
                            (concat " "
                                    (mapconcat (lambda (tag) (concat ":" tag))
                                               tags "")
                                    ":")
                          "")
                        (if reply-to (format ":REPLY_TO: %s\n" reply-to) "")
                        body)))
      (save-buffer))
    file))

(defun feed-ui--compose-body ()
  "Buffer text below the inline form region, trimmed."
  (string-trim
   (buffer-substring-no-properties
    (marker-position (vui-instance-region-end feed-ui--compose-instance))
    (point-max))))

(defun feed-ui--compose-cancel ()
  "Discard the compose buffer."
  (interactive)
  (when feed-ui--compose-instance
    (vui-unmount feed-ui--compose-instance)
    (setq feed-ui--compose-instance nil))
  (kill-buffer (current-buffer)))

(defun feed-ui--compose-submit (&optional publish)
  "Write the composed post; with PUBLISH, also commit and push."
  (interactive)
  (let* ((tags-raw (or (vui-field-value 'tags) ""))
         (tags (split-string tags-raw nil t))
         (body (feed-ui--compose-body)))
    (when (string-empty-p body)
      (user-error "feed: body is empty"))
    (feed-ui--write-post body tags feed-ui--compose-reply-to)
    (feed-ui--compose-cancel)
    (when feed-ui--live-refresh
      (funcall feed-ui--live-refresh))
    (when publish
      (feed/publish))
    (message "feed: posted%s" (if publish " and published" ""))))

(defvar feed-ui-compose-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") (lambda () (interactive) (feed-ui--compose-submit nil)))
    (define-key map (kbd "C-c C-k") #'feed-ui--compose-cancel)
    map)
  "Keymap for `feed-ui-compose-mode'.")

(define-derived-mode feed-ui-compose-mode org-mode "feed-compose"
  "Mode for feed compose buffers: org-mode plus an inline vui form.")

(defun feed-ui-compose (&optional reply-to)
  "Open a compose buffer; with REPLY-TO, a post id to reply to."
  (interactive)
  (feed-ui--ensure-engine)
  (let ((buf (get-buffer-create
              (if reply-to
                  (format "*feed: reply %s*" reply-to)
                "*feed: compose*"))))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer))
      ;; Body area first; the form region is inserted before it.
      (insert "\n\n")
      (feed-ui-compose-mode)
      (setq feed-ui--compose-reply-to reply-to)
      (setq feed-ui--compose-instance
            (vui-mount-inline
             (vui-component 'feed-compose-form :reply-to reply-to)
             (point-min)))
      (goto-char (point-max)))
    (pop-to-buffer buf)))

;;; § 6 App

(defvar-local feed-ui--sync-action nil
  "Sync closure stashed during render (has component context).")

(defvar-local feed-ui--back-action nil
  "Back/quit closure stashed during render (has component context).")

(defvar-local feed-ui--mute-actions nil
  "Hash post-id -> mute-toggle closure stashed during render.")

(defvar-local feed-ui--thread-actions nil
  "Hash post-id -> open-thread closure stashed during render.")

(defun feed-ui--refresh ()
  "Re-collect posts and pending counts into the app's state.
Must run inside a component context (button callback or
`vui-with-async-context')."
  (vui-batch
    (vui-set-state :posts (feed-ui--posts))
    (vui-set-state :pending (or (feed//pending-all) '()))
    (vui-set-state :last-sync (float-time))))

(vui-defcomponent feed-app ()
  "Root component: header, routed view (timeline/thread/profile/tag),
statusline.  Navigation is a stack: drilling in pushes, `q' pops."
  :state ((posts (feed-ui--posts))
          (pending (or (feed//pending-all) '()))
          (own-nicks (feed-ui--own-nicks))
          (muted '())
          (view 'timeline)
          (view-args nil)
          (nav-stack '())
          (last-sync nil))
  :render
  (let* ((counts (feed-ui--reply-counts posts))
         (pending-count (cl-reduce #'+ (mapcar #'cdr pending) :initial-value 0))
         (nav (lambda (v args)
                (vui-batch
                  (vui-set-state :nav-stack (cons (cons view view-args) nav-stack))
                  (vui-set-state :view v)
                  (vui-set-state :view-args args))))
         (view-label
          (pcase view
            ('timeline nil)
            ('thread (format "thread · %s" view-args))
            ('profile (format "profile · %s" view-args))
            ('tag (format "tag · :%s:" view-args))
            ('review "review queue")
            ('review-detail (format "review · %s" view-args))))
         (back (lambda ()
                 (if (null nav-stack)
                     (quit-window)
                   (vui-batch
                     (vui-set-state :view (caar nav-stack))
                     (vui-set-state :view-args (cdar nav-stack))
                     (vui-set-state :nav-stack (cdr nav-stack)))))))
    ;; Stash actions for mode-keymap commands (no component context there).
    (setq feed-ui--live-refresh
          (vui-with-async-context (feed-ui--refresh)))
    (setq feed-ui--sync-action
          (vui-with-async-context
            (message "feed: syncing…")
            (feed/sync)
            (feed-ui--refresh)))
    (setq feed-ui--back-action
          (vui-with-async-context (funcall back)))
    (setq feed-ui--mute-actions (make-hash-table :test 'equal))
    (setq feed-ui--thread-actions (make-hash-table :test 'equal))
    (dolist (p posts)
      (let ((id (plist-get p :id))
            (nick (plist-get p :nick)))
        (puthash id
                 (vui-with-async-context
                   (vui-set-state :muted (if (member nick muted)
                                             (delete nick muted)
                                           (cons nick muted))))
                 feed-ui--mute-actions)
        (puthash id
                 (vui-with-async-context (funcall nav 'thread id))
                 feed-ui--thread-actions)))
    (vui-vstack
     :spacing 1
     ;; header
     (vui-hstack
      :spacing 2
      (vui-heading-2 "feed")
      (when nav-stack
        (vui-button "‹ back"
          :on-click (lambda () (funcall feed-ui--back-action))
          :no-decoration t
          :face 'shadow
          :help-echo nil))
      (when (> pending-count 0)
        (vui-button (format "%d pending review" pending-count)
          :face 'warning
          :on-click (lambda () (funcall nav 'review nil)))))
     (vui-hstack
      :spacing 2
      (vui-button "new post" :on-click (lambda () (feed-ui-compose)))
      (vui-button "sync" :on-click (lambda () (funcall feed-ui--sync-action)))
      (vui-button "refresh" :on-click (lambda () (feed-ui--refresh))))
     (when view-label
       (vui-text view-label :face 'shadow))
     (when muted
       (vui-hstack
        :spacing 1
        (vui-text "muted:" :face 'shadow)
        (mapcar (lambda (nick)
                  (vui-button nick
                    :on-click (lambda () (vui-set-state :muted (delete nick muted)))
                    :no-decoration t
                    :face 'shadow
                    :help-echo "unmute"))
                muted)))
     ;; routed view
     (pcase view
       ('timeline
        (let ((visible (cl-remove-if-not
                        (lambda (p) (not (member (plist-get p :nick) muted)))
                        posts)))
          (if (null visible)
              (vui-vstack
               :spacing 1
               (vui-text "Nothing here yet." :face 'shadow)
               (vui-button "write the first post"
                 :on-click (lambda () (feed-ui-compose))))
            (vui-list visible
                      (lambda (post)
                        (feed-ui--card post
                                       (member (plist-get post :nick) own-nicks)
                                       (gethash (plist-get post :id) counts 0)
                                       nav))
                      (lambda (post) (plist-get post :id))
                      :spacing 1))))
       ('thread (feed-ui--thread-view view-args posts own-nicks counts nav))
       ('profile (feed-ui--profile-view view-args posts own-nicks counts nav))
       ('tag (feed-ui--tag-view view-args posts own-nicks counts nav))
       ('review (feed-ui--review-view pending nav))
       ('review-detail
        (feed-ui--review-detail-view
         view-args
         (lambda ()
           (feed/approve view-args)
           (feed-ui--refresh)
           (funcall back)))))
     ;; statusline
     (vui-vstack
      :spacing 0
      (vui-text
       (format "%d posts · %d nicks%s"
               (length posts)
               (length (delete-dups (mapcar (lambda (p) (plist-get p :nick)) posts)))
               (if last-sync
                   (format " · synced %s" (feed-ui--ago last-sync))
                 ""))
       :face 'shadow)
      (vui-text "RET thread · r reply · m mute · g sync · q back/quit"
                :face 'shadow)))))

;;; § 7 Mode and entry point

(defun feed-ui--key-near (pos)
  "Post id at POS, scanning backward for the nearest keyed element.
Card bodies are plain text; the keyed buttons sit on the meta line
above and the actions row below."
  (or (vui-key-at pos)
      (cl-loop for p from (1- pos) downto (max (point-min) (- pos 400))
               thereis (vui-key-at p))))

(defun feed-ui-open-thread-at-point ()
  "Open the thread of the card under point, in the native view."
  (interactive)
  (if-let* ((id (feed-ui--key-near (point))))
      (funcall (gethash id feed-ui--thread-actions))
    (message "feed: no post here")))

(defun feed-ui-reply-at-point ()
  "Reply to the card under point in a compose buffer."
  (interactive)
  (if-let* ((id (feed-ui--key-near (point))))
      (feed-ui-compose id)
    (message "feed: no post here")))

(defun feed-ui-mute-at-point ()
  "Toggle muting the nick of the card under point."
  (interactive)
  (if-let* ((id (feed-ui--key-near (point))))
      (funcall (gethash id feed-ui--mute-actions))
    (message "feed: no post here")))

(defun feed-ui-sync ()
  "Sync subscriptions and refresh the timeline."
  (interactive)
  (when feed-ui--sync-action
    (funcall feed-ui--sync-action)))

(defun feed-ui-back-or-quit ()
  "Pop the navigation stack; quit the window at the root view."
  (interactive)
  (when feed-ui--back-action
    (funcall feed-ui--back-action)))

(defvar feed-ui-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'feed-ui-open-thread-at-point)
    (define-key map (kbd "r") #'feed-ui-reply-at-point)
    (define-key map (kbd "m") #'feed-ui-mute-at-point)
    (define-key map (kbd "g") #'feed-ui-sync)
    (define-key map (kbd "q") #'feed-ui-back-or-quit)
    map)
  "Keymap for `feed-ui-mode'.")

(define-derived-mode feed-ui-mode vui-mode "feed-ui"
  "Major mode for the feed.org vui client."
  (hl-line-mode 1))

(with-eval-after-load 'evil
  (evil-set-initial-state 'feed-ui-mode 'normal)
  (evil-define-key 'normal feed-ui-mode-map
    (kbd "RET") #'feed-ui-open-thread-at-point
    "r" #'feed-ui-reply-at-point
    "m" #'feed-ui-mute-at-point
    "g" #'feed-ui-sync
    "q" #'feed-ui-back-or-quit))

;;;###autoload
(defun feed ()
  "Open the feed.org vui client."
  (interactive)
  (feed-ui--ensure-engine)
  (let ((buf (get-buffer-create "*feed*")))
    (with-current-buffer buf
      ;; Enable the derived mode BEFORE mounting so vui preserves it.
      (feed-ui-mode))
    (vui-mount (vui-component 'feed-app) "*feed*")
    (pop-to-buffer buf)))

(provide 'feed-ui)
;;; feed-ui.el ends here
