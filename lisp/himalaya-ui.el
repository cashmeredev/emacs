;;; himalaya-ui.el --- Keyboard-first VUI for Himalaya -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'himalaya-client)
(require 'vui)
(require 'vui-components)

(declare-function evil-define-key* "evil-core" (state keymap key def &rest bindings))
(declare-function evil-set-initial-state "evil-core" (mode state))

(defvar-local himalaya-ui--dispatch nil)
(defvar-local himalaya-ui--visible-ids nil)
(defvar-local himalaya-ui--folders nil)
(defvar-local himalaya-ui--marked nil)
(defvar-local himalaya-ui--view 'mailbox)
(defvar-local himalaya-ui--message-id nil)
(defvar-local himalaya-ui--folders-request-generation 0)
(defvar-local himalaya-ui--folders-request nil)
(defvar-local himalaya-ui--envelopes-request-generation 0)
(defvar-local himalaya-ui--envelopes-request nil)
(defvar-local himalaya-ui--preview-request-generation 0)
(defvar-local himalaya-ui--preview-request nil)
(defvar-local himalaya-ui--mutation-generation 0)

(defun himalaya-ui--value (object key)
  (cond
   ((hash-table-p object)
    (or (gethash key object)
        (gethash (substring (symbol-name key) 1) object)))
   ((and (listp object) (keywordp (car object)))
    (plist-get object key))
   ((listp object)
    (or (alist-get key object)
        (alist-get (substring (symbol-name key) 1) object nil nil #'equal)))))

(defun himalaya-ui--items (result key)
  (let ((items (or (himalaya-ui--value result key) result)))
    (cond
     ((vectorp items) (append items nil))
     ((null items) nil)
     ((and (listp items) (keywordp (car items))) (list items))
     ((listp items) items)
     (t (list items)))))

(defun himalaya-ui--names (result key)
  (delete-dups
   (delq nil
         (mapcar
          (lambda (item)
            (let ((name (if (stringp item)
                            item
                          (or (himalaya-ui--value item :name)
                              (himalaya-ui--value item :account)
                              (himalaya-ui--value item :folder)
                              (himalaya-ui--value item :id)))))
              (when name (format "%s" name))))
          (himalaya-ui--items result key)))))

(defun himalaya-ui--fit (value width)
  (let ((text (if value (format "%s" value) "")))
    (if (> (string-width text) width)
        (truncate-string-to-width text width nil nil "…")
      text)))

(defun himalaya-ui--sender (envelope)
  (let ((name (plist-get envelope :from-name))
        (address (plist-get envelope :from-address)))
    (cond
     ((not (string-empty-p (or name ""))) name)
     ((not (string-empty-p (or address ""))) address)
     (t "Unknown sender"))))

(defun himalaya-ui--recipient (envelope)
  (let ((name (plist-get envelope :to-name))
        (address (plist-get envelope :to-address)))
    (cond
     ((not (string-empty-p (or name ""))) name)
     ((not (string-empty-p (or address ""))) address)
     (t "Unknown recipient"))))

(defun himalaya-ui--subject (envelope)
  (or (plist-get envelope :subject) "(no subject)"))

(defun himalaya-ui--subject-face (envelope)
  (cond
   ((plist-get envelope :deleted) 'error)
   ((plist-get envelope :unread) 'outline-2)
   (t 'shadow)))

(defun himalaya-ui--indicators (envelope marked)
  (format "%s%s%s%s"
          (if (member (plist-get envelope :id) marked) "+" " ")
          (if (plist-get envelope :unread) "N" " ")
          (if (plist-get envelope :starred) "*" " ")
          (if (plist-get envelope :has-attachment) "@" " ")))

(defun himalaya-ui--envelope (id envelopes)
  (seq-find (lambda (envelope)
              (equal (plist-get envelope :id) id))
            envelopes))

(defun himalaya-ui--split-width (text width)
  (let ((start 0)
        (index 0)
        (column 0)
        (pieces nil))
    (while (< index (length text))
      (let ((next (+ column (max 1 (or (char-width (aref text index)) 1)))))
        (when (and (> next width) (> index start))
          (push (substring text start index) pieces)
          (setq start index
                column 0
                next (max 1 (or (char-width (aref text index)) 1))))
        (setq column next
              index (1+ index))))
    (when (< start (length text))
      (push (substring text start) pieces))
    (nreverse (or pieces (list "")))))

(defun himalaya-ui--wrap-line (line width)
  (if (string-empty-p line)
      (list "")
    (let ((current "")
          (current-width 0)
          (lines nil))
      (dolist (word (split-string line nil t))
        (dolist (piece (himalaya-ui--split-width word width))
          (let ((piece-width (string-width piece)))
            (if (and (not (string-empty-p current))
                     (> (+ current-width 1 piece-width) width))
                (progn
                  (push current lines)
                  (setq current piece
                        current-width piece-width))
              (setq current (if (string-empty-p current)
                                piece
                              (concat current " " piece))
                    current-width (if (zerop current-width)
                                      piece-width
                                    (+ current-width 1 piece-width)))))))
      (unless (string-empty-p current)
        (push current lines))
      (nreverse (or lines (list ""))))))

(defun himalaya-ui--wrap-body (body width)
  (mapcan (lambda (line)
            (himalaya-ui--wrap-line line width))
          (split-string (or body "") "\n" nil)))

(defun himalaya-ui--body-text (result)
  (cond
   ((stringp result) result)
   ((vectorp result)
    (mapconcat #'himalaya-ui--body-text (append result nil) "\n\n"))
   ((and (listp result) (not (keywordp (car result))))
    (mapconcat #'himalaya-ui--body-text result "\n\n"))
   (t
    (let ((body (or (himalaya-ui--value result :body)
                    (himalaya-ui--value result :content)
                    (himalaya-ui--value result :text)
                    (himalaya-ui--value result :message)
                    (himalaya-ui--value result :preview))))
      (if body
          (himalaya-ui--body-text body)
        (format "%s" result))))))

(defun himalaya-ui--last-sync (last-sync)
  (if last-sync
      (format-time-string "%H:%M" (seconds-to-time last-sync))
    "never"))

(defun himalaya-ui--quiet-button (label face callback &optional key)
  (vui-button label
    :on-click callback
    :no-decoration t
    :face face
    :help-echo nil
    :key key))

(defun himalaya-ui--wide-messages (envelopes marked open-message width)
  (let* ((sender-width 22)
         (date-width 16)
         (status-width 4)
         (separator-width 3)
         (subject-width
          (max 20 (- width sender-width date-width status-width separator-width))))
    (vui-table
     :columns `((:header "" :width ,status-width :grow t :truncate t :align :left)
                (:header "From" :width ,sender-width :grow t :truncate t :align :left)
                (:header "Date" :width ,date-width :grow t :truncate t :align :left)
                (:header "Subject" :width ,subject-width :grow t :truncate t :align :left))
     :rows
     (mapcar
      (lambda (envelope)
        (let ((id (plist-get envelope :id)))
          (list
           (vui-text (himalaya-ui--fit (himalaya-ui--indicators envelope marked)
                                       status-width)
                     :face (if (member id marked) 'success 'shadow))
           (vui-text (himalaya-ui--fit (himalaya-ui--sender envelope) sender-width)
                     :face (if (plist-get envelope :unread) 'outline-3 'shadow))
           (vui-text (himalaya-ui--fit (plist-get envelope :date) date-width)
                     :face 'shadow)
           (himalaya-ui--quiet-button
            (himalaya-ui--fit (himalaya-ui--subject envelope) subject-width)
            (himalaya-ui--subject-face envelope)
            (lambda () (funcall open-message id))
            id))))
      envelopes)
     :border nil
     :header-face 'outline-3
     :border-face 'shadow)))

(defun himalaya-ui--compact-messages (envelopes marked open-message width)
  (vui-list
   envelopes
   (lambda (envelope)
     (let* ((id (plist-get envelope :id))
            (label-width (max 12 (- width 5)))
            (meta-width (max 12 (- width 6))))
       (vui-vstack
        :spacing 0
        (himalaya-ui--quiet-button
         (format "%s %s"
                 (himalaya-ui--indicators envelope marked)
                 (himalaya-ui--fit (himalaya-ui--subject envelope) label-width))
         (himalaya-ui--subject-face envelope)
         (lambda () (funcall open-message id))
         id)
        (vui-text
         (format "     %s"
                 (himalaya-ui--fit
                  (format "%s · %s"
                          (himalaya-ui--sender envelope)
                          (or (plist-get envelope :date) ""))
                  meta-width))
         :face 'shadow))))
   (lambda (envelope) (plist-get envelope :id))))

(defun himalaya-ui--empty-state (folder query width)
  (let ((text (cond
               ((not (string-empty-p query)) "No messages match this search")
               ((and folder (string-equal-ignore-case folder "INBOX")) "Inbox zero")
               (t (format "%s is empty" (or folder "Folder"))))))
    (vui-vstack
     :spacing 1
     (vui-box (vui-text "—" :face 'shadow) :width width :align :center)
     (vui-box (vui-text text :face 'shadow) :width width :align :center))))

(defun himalaya-ui--header (account folder unread loading refreshing last-sync width)
  (vui-flex
   :width width
   :justify :space-between
   (vui-hstack
    :spacing 1
    (vui-text "HIMALAYA" :face 'outline-1)
    (vui-text "/" :face 'shadow)
    (vui-text (himalaya-ui--fit (or account "no account") 20) :face 'outline-2)
    (vui-text "/" :face 'shadow)
    (vui-text (himalaya-ui--fit (or folder "no folder") 24) :face 'outline-3))
   (vui-text
    (cond
     (loading "loading")
     (refreshing (format "%d unread · syncing" unread))
     (t (format "%d unread · synced %s" unread
                (himalaya-ui--last-sync last-sync))))
    :face (cond (loading 'warning) (refreshing 'warning) (t 'success)))))

(defun himalaya-ui--folder-navigation (accounts account folders folder select-account select-folder refresh search clear compose)
  (vui-vstack
   :spacing 0
   (vui-hstack
    :spacing 1
    (vui-text "Accounts" :face 'shadow)
    (vui-list
     accounts
     (lambda (name)
       (himalaya-ui--quiet-button
        (himalaya-ui--fit name 16)
        (if (equal name account) 'outline-2 'link)
        (lambda () (funcall select-account name))))
     #'identity
     :vertical nil
     :spacing 2))
   (vui-hstack
    :spacing 1
    (vui-text "Folders " :face 'shadow)
    (vui-list
     folders
     (lambda (name)
       (himalaya-ui--quiet-button
        (himalaya-ui--fit name 18)
        (if (equal name folder) 'outline-3 'link)
        (lambda () (funcall select-folder name))))
     #'identity
     :vertical nil
     :spacing 2))
   (vui-hstack
    :spacing 2
    (himalaya-ui--quiet-button "refresh" 'link refresh)
    (himalaya-ui--quiet-button "search" 'link search)
    (himalaya-ui--quiet-button "clear" 'link clear)
    (himalaya-ui--quiet-button "new message" 'link compose))))

(defun himalaya-ui--reader (view account folder envelope body loading error width)
  (let* ((subject (if envelope (himalaya-ui--subject envelope) "Message"))
         (body-width (max 24 (- width 4)))
         (kind (if (eq view 'thread) "thread preview" "message preview")))
    (vui-vstack
     :spacing 1
     (vui-flex
      :width width
      :justify :space-between
      (vui-hstack
       :spacing 0
       (vui-text "mail" :face 'shadow)
       (vui-text " / " :face 'shadow)
       (vui-text (himalaya-ui--fit account 18) :face 'link)
       (vui-text " / " :face 'shadow)
       (vui-text (himalaya-ui--fit folder 20) :face 'link)
       (vui-text " / " :face 'shadow)
       (vui-text (if (eq view 'thread) "thread" "message") :face 'outline-3))
      (vui-text kind :face 'shadow))
     (vui-box
      (vui-text (himalaya-ui--fit subject (max 20 (- width 4))) :face 'outline-1)
      :width width
      :align :center)
     (vui-flex
      :width width
      :justify :space-between
      (vui-text (if envelope
                    (format "%s <%s>"
                            (himalaya-ui--fit (himalaya-ui--sender envelope) 28)
                            (himalaya-ui--fit (plist-get envelope :from-address) 32))
                  "Unknown sender")
                :face 'outline-2)
      (vui-text (himalaya-ui--fit (and envelope (plist-get envelope :date)) 28)
                :face 'shadow))
     (when envelope
       (vui-collapsible
        :title "Details"
        :title-face 'link
        :expanded-indicator "-"
        :collapsed-indicator "+"
        :key 'message-details
        (vui-vstack
         :spacing 0
         (vui-text (format "From: %s <%s>"
                           (himalaya-ui--sender envelope)
                           (or (plist-get envelope :from-address) ""))
                   :face 'shadow)
         (vui-text (format "To:   %s <%s>"
                           (himalaya-ui--recipient envelope)
                           (or (plist-get envelope :to-address) ""))
                   :face 'shadow)
         (vui-text (format "ID:   %s" (plist-get envelope :id)) :face 'shadow)
         (vui-text (format "Flags: %s"
                           (mapconcat (lambda (flag) (format "%s" flag))
                                      (or (plist-get envelope :flags) nil) ", "))
                   :face 'shadow))))
     (let ((navigation-actions
            (vui-hstack
             :spacing 2
             (himalaya-ui--quiet-button "back" 'link #'himalaya-ui-back-or-quit)
             (himalaya-ui--quiet-button "reply" 'link #'himalaya-ui-reply)
             (himalaya-ui--quiet-button "reply all" 'link #'himalaya-ui-reply-all)
             (himalaya-ui--quiet-button "forward" 'link #'himalaya-ui-forward)))
           (message-actions
            (vui-hstack
             :spacing 2
             (himalaya-ui--quiet-button "seen" 'link #'himalaya-ui-toggle-seen)
             (himalaya-ui--quiet-button "flag" 'link #'himalaya-ui-toggle-flagged)
             (himalaya-ui--quiet-button "archive" 'warning #'himalaya-ui-archive)
             (himalaya-ui--quiet-button "delete" 'error #'himalaya-ui-delete)
             (himalaya-ui--quiet-button "attachments" 'link #'himalaya-ui-download))))
       (if (>= width 73)
           (vui-hstack :spacing 2 navigation-actions message-actions)
         (vui-vstack :spacing 0 navigation-actions message-actions)))
     (vui-text (make-string (max 1 width) ?-) :face 'shadow)
     (cond
      (loading
       (vui-box (vui-text "Loading preview…" :face 'warning)
                :width width :align :center))
      (error
       (vui-box (vui-text (format "Preview failed: %s" error) :face 'error)
                :width width :align :center))
      ((string-empty-p (or body ""))
       (vui-box (vui-text "This message has no displayable body" :face 'shadow)
                :width width :align :center))
      (t
       (vui-vstack
        :spacing 0
        :indent 2
        (mapcar (lambda (line) (vui-text line))
                (himalaya-ui--wrap-body body body-width))))))))

(defun himalaya-ui--mailbox-footer (page count marked query sort width)
  (let ((primary "RET open · t thread · m mark · U seen · * flag · a archive · d delete")
        (secondary "/ search · c clear · [ ] page · s sort · g refresh · N new · ? help")
        (summary (format "page %d · %d messages · %d marked"
                         page count (length marked)))
        (scope (format "%s%s"
                       (if (string-empty-p query) "all mail" (format "search: %s" query))
                       (if sort (format " · %s" sort) ""))))
    (if (>= width 110)
        (vui-vstack
         :spacing 0
         (vui-flex
          :width width
          :justify :space-between
          (vui-text primary :face 'shadow)
          (vui-text summary :face 'shadow))
         (vui-flex
          :width width
          :justify :space-between
          (vui-text secondary :face 'shadow)
          (vui-text scope :face 'shadow)))
      (vui-vstack
       :spacing 0
       (vui-text primary :face 'shadow)
       (vui-text summary :face 'shadow)
       (vui-text secondary :face 'shadow)
       (vui-text scope :face 'shadow)))))

(defun himalaya-ui--reader-footer (view width)
  (let ((keys "r reply · R reply all · f forward · a archive · d delete · q back")
        (scope (if (eq view 'thread) "thread preview" "message preview")))
    (if (>= width 96)
        (vui-flex
         :width width
         :justify :space-between
         (vui-text keys :face 'shadow)
         (vui-text scope :face 'shadow))
      (vui-vstack
       :spacing 0
       (vui-text keys :face 'shadow)
       (vui-text scope :face 'shadow)))))

(vui-defcomponent himalaya-ui-root ()
  :state ((accounts nil)
          (account nil)
          (folders nil)
          (folder nil)
          (envelopes nil)
          (page 1)
          (query "")
          (sort nil)
          (loading t)
          (refreshing nil)
          (error nil)
          (last-sync nil)
          (marked nil)
          (view 'mailbox)
          (message-id nil)
          (message-body nil))
  :render
  (cl-labels
      ((fetch-envelopes
        (selected-account selected-folder selected-page selected-query selected-sort clear-marked)
        (cl-incf himalaya-ui--mutation-generation)
        (let* ((ownership-changed
                (or (not (equal selected-account account))
                    (not (equal selected-folder folder))))
               (cached (and (not ownership-changed) last-sync))
               (request
                (list (cl-incf himalaya-ui--envelopes-request-generation)
                      selected-account selected-folder selected-page
                      selected-query selected-sort)))
          (setq himalaya-ui--envelopes-request request
                himalaya-ui--preview-request nil)
          (vui-batch
            (vui-set-state :account selected-account)
            (vui-set-state :folder selected-folder)
            (vui-set-state :page selected-page)
            (vui-set-state :query selected-query)
            (vui-set-state :sort selected-sort)
            (vui-set-state :error nil)
            (vui-set-state :loading (not cached))
            (vui-set-state :refreshing (and cached t))
            (vui-set-state :view 'mailbox)
            (vui-set-state :message-id nil)
            (vui-set-state :message-body nil)
            (when ownership-changed
              (vui-set-state :envelopes nil)
              (vui-set-state :last-sync nil))
            (when (or ownership-changed clear-marked)
              (vui-set-state :marked nil)))
          (himalaya-client-envelopes
           selected-account selected-folder selected-page selected-query selected-sort
           (vui-async-callback (result backend-error)
             (when (equal request himalaya-ui--envelopes-request)
               (if backend-error
                   (vui-batch
                     (vui-set-state :loading nil)
                     (vui-set-state :refreshing nil)
                     (vui-set-state :error backend-error))
                 (vui-batch
                   (vui-set-state :envelopes (or result nil))
                   (vui-set-state :loading nil)
                   (vui-set-state :refreshing nil)
                   (vui-set-state :error nil)
                   (vui-set-state :last-sync (float-time)))))))))
       (load-folders
        (selected-account)
        (cl-incf himalaya-ui--mutation-generation)
        (let ((request
               (list (cl-incf himalaya-ui--folders-request-generation)
                     selected-account)))
          (setq himalaya-ui--folders-request request
                himalaya-ui--envelopes-request nil
                himalaya-ui--preview-request nil)
          (vui-batch
            (vui-set-state :account selected-account)
            (vui-set-state :folders nil)
            (vui-set-state :folder nil)
            (vui-set-state :envelopes nil)
            (vui-set-state :marked nil)
            (vui-set-state :loading t)
            (vui-set-state :refreshing nil)
            (vui-set-state :error nil)
            (vui-set-state :last-sync nil))
          (himalaya-client-folders
           selected-account
           (vui-async-callback (result backend-error)
             (when (equal request himalaya-ui--folders-request)
               (if backend-error
                   (vui-batch
                     (vui-set-state :loading nil)
                     (vui-set-state :error backend-error))
                 (let* ((names (himalaya-ui--names result :folders))
                        (inbox (seq-find (lambda (name)
                                           (string-equal-ignore-case name "INBOX"))
                                         names))
                        (selected-folder (or inbox (car names))))
                   (vui-set-state :folders names)
                   (if selected-folder
                       (fetch-envelopes selected-account selected-folder 1 "" sort t)
                     (vui-batch
                       (vui-set-state :loading nil)
                       (vui-set-state :error "This account has no folders"))))))))))
       (start-up
        ()
        (vui-batch
          (vui-set-state :loading t)
          (vui-set-state :error nil))
        (himalaya-client-accounts
         (vui-async-callback (result backend-error)
           (if backend-error
               (vui-batch
                 (vui-set-state :loading nil)
                 (vui-set-state :error backend-error))
             (let ((names (himalaya-ui--names result :accounts)))
               (vui-set-state :accounts names)
               (if names
                   (load-folders (car names))
                 (vui-batch
                   (vui-set-state :loading nil)
                   (vui-set-state :error "No Himalaya accounts are configured"))))))))
       (open-preview
        (kind id)
        (cl-incf himalaya-ui--mutation-generation)
        (let ((request
               (list (cl-incf himalaya-ui--preview-request-generation)
                     kind account folder id)))
          (setq himalaya-ui--preview-request request
                himalaya-ui--envelopes-request nil)
          (vui-batch
            (vui-set-state :view (lambda (_current) kind))
            (vui-set-state :message-id id)
            (vui-set-state :message-body nil)
            (vui-set-state :loading t)
            (vui-set-state :refreshing nil)
            (vui-set-state :error nil))
          (funcall
           (if (eq kind 'thread) #'himalaya-client-thread #'himalaya-client-read)
           account folder id
           (vui-async-callback (result backend-error)
             (when (equal request himalaya-ui--preview-request)
               (if backend-error
                   (vui-batch
                     (vui-set-state :loading nil)
                     (vui-set-state :error backend-error))
                 (vui-batch
                   (vui-set-state :message-body (himalaya-ui--body-text result))
                   (vui-set-state :loading nil)
                   (vui-set-state :error nil))))))))
       (refresh-current
        ()
        (if (eq view 'mailbox)
            (when (and account folder)
              (fetch-envelopes account folder page query sort nil))
          (when message-id
            (open-preview view message-id))))
       (finish-mutation
        (generation)
        (vui-async-callback (_result backend-error)
          (when (= generation himalaya-ui--mutation-generation)
            (if backend-error
                (vui-batch
                  (vui-set-state :loading nil)
                  (vui-set-state :refreshing nil)
                  (vui-set-state :error backend-error))
              (fetch-envelopes account folder page query sort t)))))
       (run-bulk
        (action ids target)
        (when (and account folder ids)
          (let* ((generation (cl-incf himalaya-ui--mutation-generation))
                 (callback (finish-mutation generation)))
            (pcase action
              ('seen-add
               (himalaya-client-flag account folder "add" ids '("seen") callback))
              ('seen-remove
               (himalaya-client-flag account folder "remove" ids '("seen") callback))
              ('flagged-add
               (himalaya-client-flag account folder "add" ids '("flagged") callback))
              ('flagged-remove
               (himalaya-client-flag account folder "remove" ids '("flagged") callback))
              ('delete
               (himalaya-client-delete account folder ids callback))
              ('download
               (himalaya-client-download account folder ids callback))
              ('move
               (himalaya-client-transfer account folder "move" target ids callback))
              ('copy
               (himalaya-client-transfer account folder "copy" target ids callback))))))
       (toggle-seen
        (ids)
        (let ((make-seen
               (seq-some
                (lambda (id)
                  (let ((envelope (himalaya-ui--envelope id envelopes)))
                    (or (null envelope) (plist-get envelope :unread))))
                ids)))
          (run-bulk (if make-seen 'seen-add 'seen-remove) ids nil)))
       (toggle-flagged
        (ids)
        (let ((make-flagged
               (seq-some
                (lambda (id)
                  (let ((envelope (himalaya-ui--envelope id envelopes)))
                    (or (null envelope) (not (plist-get envelope :starred)))))
                ids)))
          (run-bulk (if make-flagged 'flagged-add 'flagged-remove) ids nil)))
       (toggle-mark
        (id)
        (when (and (eq view 'mailbox) id)
          (vui-set-state :marked
                         (if (member id marked)
                             (remove id marked)
                           (cons id marked)))))
       (toggle-all
        ()
        (when (eq view 'mailbox)
          (let ((ids (mapcar (lambda (envelope) (plist-get envelope :id)) envelopes)))
            (vui-set-state
             :marked
             (if (and ids (seq-every-p (lambda (id) (member id marked)) ids))
                 (seq-remove (lambda (id) (member id ids)) marked)
               (delete-dups (append ids marked)))))))
       (cycle-sort
        ()
        (let ((next-sort (cond
                          ((null sort) "date desc")
                          ((equal sort "date desc") "date asc")
                          ((equal sort "date asc") "subject asc")
                          (t nil))))
          (fetch-envelopes account folder 1 query next-sort t)))
       (go-back
        ()
        (if (eq view 'mailbox)
            (quit-window)
          (setq himalaya-ui--preview-request nil)
          (vui-batch
            (vui-set-state :view 'mailbox)
            (vui-set-state :message-id nil)
            (vui-set-state :message-body nil)
            (vui-set-state :loading nil)
            (vui-set-state :error nil))))
       (compose
        (kind id)
        (when account
          (himalaya-client-compose account folder id kind))))
    (vui-use-effect ()
      (start-up)
      nil)
    (let* ((dispatch (make-hash-table :test 'eq))
           (window (or (get-buffer-window (current-buffer)) (selected-window)))
           (width (max 40 (- (window-body-width window) 2)))
           (unread (seq-count (lambda (envelope) (plist-get envelope :unread)) envelopes)))
      (puthash 'open (vui-async-callback (id) (open-preview 'message id)) dispatch)
      (puthash 'thread (vui-async-callback (id) (open-preview 'thread id)) dispatch)
      (puthash 'refresh (vui-with-async-context (refresh-current)) dispatch)
      (puthash 'search
               (vui-async-callback (new-query)
                 (fetch-envelopes account folder 1 new-query sort t))
               dispatch)
      (puthash 'clear
               (vui-with-async-context
                 (fetch-envelopes account folder 1 "" sort t))
               dispatch)
      (puthash 'page
               (vui-async-callback (new-page)
                 (fetch-envelopes account folder new-page query sort t))
               dispatch)
      (puthash 'sort (vui-with-async-context (cycle-sort)) dispatch)
      (puthash 'mark (vui-async-callback (id) (toggle-mark id)) dispatch)
      (puthash 'mark-all (vui-with-async-context (toggle-all)) dispatch)
      (puthash 'seen (vui-async-callback (ids) (toggle-seen ids)) dispatch)
      (puthash 'flagged (vui-async-callback (ids) (toggle-flagged ids)) dispatch)
      (puthash 'delete (vui-async-callback (ids) (run-bulk 'delete ids nil)) dispatch)
      (puthash 'download (vui-async-callback (ids) (run-bulk 'download ids nil)) dispatch)
      (puthash 'transfer
               (vui-async-callback (operation target ids)
                 (run-bulk operation ids target))
               dispatch)
      (puthash 'expunge
               (vui-with-async-context
                 (when (and account folder)
                   (let ((generation (cl-incf himalaya-ui--mutation-generation)))
                     (himalaya-client-expunge
                      account folder (finish-mutation generation)))))
               dispatch)
      (puthash 'compose (vui-async-callback (kind id) (compose kind id)) dispatch)
      (puthash 'back (vui-with-async-context (go-back)) dispatch)
      (puthash 'current-page page dispatch)
      (setq himalaya-ui--dispatch dispatch
            himalaya-ui--visible-ids
            (mapcar (lambda (envelope) (plist-get envelope :id)) envelopes)
            himalaya-ui--folders folders
            himalaya-ui--marked marked
            himalaya-ui--view view
            himalaya-ui--message-id message-id)
      (vui-vstack
       :spacing 1
       (himalaya-ui--header account folder unread loading refreshing last-sync width)
       (if (eq view 'mailbox)
           (vui-vstack
            :spacing 0
            (himalaya-ui--folder-navigation
             accounts account folders folder
             (lambda (name) (load-folders name))
             (lambda (name) (fetch-envelopes account name 1 "" sort t))
             (lambda () (refresh-current))
             #'himalaya-ui-search
             #'himalaya-ui-clear-search
             #'himalaya-ui-compose)
            (when refreshing
              (vui-text "Refreshing — cached messages remain visible" :face 'warning))
            (when (and error last-sync)
              (vui-text (format "Refresh failed — showing cached mail: %s" error)
                        :face 'error))
            (cond
             ((and loading (null last-sync))
              (vui-box (vui-text "Loading mailbox…" :face 'warning)
                       :width width :align :center))
             ((and error (null last-sync))
              (vui-vstack
               :spacing 1
               (vui-box (vui-text "Mailbox unavailable" :face 'error)
                        :width width :align :center)
               (vui-box (vui-text error :face 'error)
                        :width width :align :center)
               (vui-box (himalaya-ui--quiet-button
                         "retry" 'link (lambda () (start-up)))
                        :width width :align :center)))
             ((null envelopes)
              (himalaya-ui--empty-state folder query width))
             ((>= width 88)
              (himalaya-ui--wide-messages
               envelopes marked
               (lambda (id) (open-preview 'message id))
               width))
             (t
              (himalaya-ui--compact-messages
               envelopes marked
               (lambda (id) (open-preview 'message id))
               width)))
            (himalaya-ui--mailbox-footer
             page (length envelopes) marked query sort width))
         (vui-vstack
          :spacing 1
          (himalaya-ui--reader
           view account folder
           (himalaya-ui--envelope message-id envelopes)
           message-body loading error width)
          (himalaya-ui--reader-footer view width)))))))

(defun himalaya-ui--invoke (action arguments)
  (let ((callback (and himalaya-ui--dispatch
                       (gethash action himalaya-ui--dispatch))))
    (if callback
        (apply callback arguments)
      (message "Himalaya UI is not ready"))))

(defun himalaya-ui--id-at-point ()
  (or (let ((key (vui-key-at)))
        (and (member key himalaya-ui--visible-ids) key))
      (save-excursion
        (forward-line -1)
        (let ((start (line-beginning-position)))
          (forward-line 3)
          (cl-loop for position from start below (point)
                   for key = (vui-key-at position)
                   when (member key himalaya-ui--visible-ids)
                   return key)))))

(defun himalaya-ui--targets ()
  (if (eq himalaya-ui--view 'mailbox)
      (or himalaya-ui--marked
          (let ((id (himalaya-ui--id-at-point)))
            (and id (list id))))
    (and himalaya-ui--message-id (list himalaya-ui--message-id))))

(defun himalaya-ui--require-targets (action)
  (let ((ids (himalaya-ui--targets)))
    (if ids
        (progn (himalaya-ui--invoke action (list ids)) t)
      (message "No message selected")
      nil)))

(defun himalaya-ui--move-row (direction)
  (if (null himalaya-ui--visible-ids)
      (message "No message rows")
    (let ((move (if (> direction 0) #'vui-forward #'vui-backward))
          (first-position nil)
          (found nil)
          (finished nil))
      (while (not finished)
        (funcall move)
        (let ((position (point))
              (key (vui-key-at)))
          (cond
           ((and first-position (= position first-position))
            (setq finished t))
           ((member key himalaya-ui--visible-ids)
            (setq found t
                  finished t))
           (t
            (unless first-position
              (setq first-position position))))))
      (unless found
        (message "No message rows")))))

(defun himalaya-ui-next-row ()
  "Move to the next message row."
  (interactive)
  (himalaya-ui--move-row 1))

(defun himalaya-ui-previous-row ()
  "Move to the previous message row."
  (interactive)
  (himalaya-ui--move-row -1))

(defun himalaya-ui-open ()
  "Open the message preview at point."
  (interactive)
  (if-let* ((id (or (himalaya-ui--id-at-point) himalaya-ui--message-id)))
      (himalaya-ui--invoke 'open (list id))
    (message "No message selected")))

(defun himalaya-ui-open-thread ()
  "Open the thread preview at point."
  (interactive)
  (if-let* ((id (or (himalaya-ui--id-at-point) himalaya-ui--message-id)))
      (himalaya-ui--invoke 'thread (list id))
    (message "No message selected")))

(defun himalaya-ui-refresh ()
  "Refresh the current view."
  (interactive)
  (himalaya-ui--invoke 'refresh nil))

(defun himalaya-ui-search ()
  "Search the current folder."
  (interactive)
  (himalaya-ui--invoke
   'search
   (list (read-string "Search mail: " nil nil ""))))

(defun himalaya-ui-clear-search ()
  "Clear the current search."
  (interactive)
  (himalaya-ui--invoke 'clear nil))

(defun himalaya-ui-next-page ()
  "Open the next mailbox page."
  (interactive)
  (let ((page (or (and himalaya-ui--dispatch
                       (gethash 'current-page himalaya-ui--dispatch))
                  1)))
    (himalaya-ui--invoke 'page (list (1+ page)))))

(defun himalaya-ui-previous-page ()
  "Open the previous mailbox page."
  (interactive)
  (let ((page (or (and himalaya-ui--dispatch
                       (gethash 'current-page himalaya-ui--dispatch))
                  1)))
    (if (> page 1)
        (himalaya-ui--invoke 'page (list (1- page)))
      (message "Already on the first page"))))

(defun himalaya-ui-cycle-sort ()
  "Cycle mailbox sorting."
  (interactive)
  (himalaya-ui--invoke 'sort nil))

(defun himalaya-ui-toggle-mark ()
  "Toggle the mark on the message at point."
  (interactive)
  (if (not (eq himalaya-ui--view 'mailbox))
      (message "Marks are only available in the mailbox")
    (if-let* ((id (himalaya-ui--id-at-point)))
        (himalaya-ui--invoke 'mark (list id))
      (message "No message selected"))))

(defun himalaya-ui-toggle-mark-all ()
  "Toggle marks on all visible messages."
  (interactive)
  (if (eq himalaya-ui--view 'mailbox)
      (himalaya-ui--invoke 'mark-all nil)
    (message "Marks are only available in the mailbox")))

(defun himalaya-ui-toggle-seen ()
  "Toggle the seen flag on the current targets."
  (interactive)
  (himalaya-ui--require-targets 'seen))

(defun himalaya-ui-toggle-flagged ()
  "Toggle the flagged flag on the current targets."
  (interactive)
  (himalaya-ui--require-targets 'flagged))

(defun himalaya-ui--choose-folder (prompt)
  (if himalaya-ui--folders
      (completing-read prompt himalaya-ui--folders nil t)
    (message "No folders are available")
    nil))

(defun himalaya-ui-archive ()
  "Move the current targets to Archive."
  (interactive)
  (let ((ids (himalaya-ui--targets)))
    (if (null ids)
        (message "No message selected")
      (let ((archive (seq-find (lambda (name)
                                 (string-equal-ignore-case name "Archive"))
                               himalaya-ui--folders)))
        (setq archive (or archive (himalaya-ui--choose-folder "Archive to: ")))
        (when archive
          (himalaya-ui--invoke 'transfer (list 'move archive ids)))))))

(defun himalaya-ui-move ()
  "Move the current targets to a folder."
  (interactive)
  (let ((ids (himalaya-ui--targets)))
    (if (null ids)
        (message "No message selected")
      (let ((target (himalaya-ui--choose-folder "Move to: ")))
        (when target
          (himalaya-ui--invoke 'transfer (list 'move target ids)))))))

(defun himalaya-ui-copy ()
  "Copy the current targets to a folder."
  (interactive)
  (let ((ids (himalaya-ui--targets)))
    (if (null ids)
        (message "No message selected")
      (let ((target (himalaya-ui--choose-folder "Copy to: ")))
        (when target
          (himalaya-ui--invoke 'transfer (list 'copy target ids)))))))

(defun himalaya-ui-delete ()
  "Flag the current targets as deleted."
  (interactive)
  (himalaya-ui--require-targets 'delete))

(defun himalaya-ui-expunge ()
  "Expunge deleted messages after confirmation."
  (interactive)
  (when (yes-or-no-p "Permanently expunge deleted messages? ")
    (himalaya-ui--invoke 'expunge nil)))

(defun himalaya-ui-download ()
  "Download attachments from the current targets."
  (interactive)
  (himalaya-ui--require-targets 'download))

(defun himalaya-ui-compose ()
  "Compose a new message."
  (interactive)
  (himalaya-ui--invoke 'compose (list nil nil)))

(defun himalaya-ui-reply ()
  "Reply to the selected message."
  (interactive)
  (if-let* ((id (or (himalaya-ui--id-at-point) himalaya-ui--message-id)))
      (himalaya-ui--invoke 'compose (list 'reply id))
    (message "No message selected")))

(defun himalaya-ui-reply-all ()
  "Reply to all recipients of the selected message."
  (interactive)
  (if-let* ((id (or (himalaya-ui--id-at-point) himalaya-ui--message-id)))
      (himalaya-ui--invoke 'compose (list 'reply-all id))
    (message "No message selected")))

(defun himalaya-ui-forward ()
  "Forward the selected message."
  (interactive)
  (if-let* ((id (or (himalaya-ui--id-at-point) himalaya-ui--message-id)))
      (himalaya-ui--invoke 'compose (list 'forward id))
    (message "No message selected")))

(defun himalaya-ui-back-or-quit ()
  "Return to the mailbox or quit its window."
  (interactive)
  (himalaya-ui--invoke 'back nil))

(defun himalaya-ui-help ()
  "Show Himalaya UI keys."
  (interactive)
  (with-help-window "*Himalaya Help*"
    (princ "Himalaya\n\n")
    (princ "n/p or j/k  next/previous message\n")
    (princ "RET/o         open preview\n")
    (princ "t             thread preview\n")
    (princ "g             refresh\n")
    (princ "/ / c         search / clear search\n")
    (princ "[ / ]         previous / next page\n")
    (princ "s             cycle sort\n")
    (princ "m / M         mark one / all visible\n")
    (princ "U / *         toggle seen / flagged\n")
    (princ "a / v / y     archive / move / copy\n")
    (princ "d / x         deleted flag / expunge\n")
    (princ "A             download attachments\n")
    (princ "N             compose\n")
    (princ "r / R / f     reply / reply all / forward\n")
    (princ "q             back / quit\n")
    (princ "TAB           next VUI control\n")))

(defvar himalaya-ui-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map vui-mode-map)
    (define-key map (kbd "n") #'himalaya-ui-next-row)
    (define-key map (kbd "p") #'himalaya-ui-previous-row)
    (define-key map (kbd "RET") #'himalaya-ui-open)
    (define-key map (kbd "o") #'himalaya-ui-open)
    (define-key map (kbd "t") #'himalaya-ui-open-thread)
    (define-key map (kbd "g") #'himalaya-ui-refresh)
    (define-key map (kbd "/") #'himalaya-ui-search)
    (define-key map (kbd "c") #'himalaya-ui-clear-search)
    (define-key map (kbd "]") #'himalaya-ui-next-page)
    (define-key map (kbd "[") #'himalaya-ui-previous-page)
    (define-key map (kbd "s") #'himalaya-ui-cycle-sort)
    (define-key map (kbd "m") #'himalaya-ui-toggle-mark)
    (define-key map (kbd "M") #'himalaya-ui-toggle-mark-all)
    (define-key map (kbd "U") #'himalaya-ui-toggle-seen)
    (define-key map (kbd "*") #'himalaya-ui-toggle-flagged)
    (define-key map (kbd "a") #'himalaya-ui-archive)
    (define-key map (kbd "v") #'himalaya-ui-move)
    (define-key map (kbd "y") #'himalaya-ui-copy)
    (define-key map (kbd "d") #'himalaya-ui-delete)
    (define-key map (kbd "x") #'himalaya-ui-expunge)
    (define-key map (kbd "A") #'himalaya-ui-download)
    (define-key map (kbd "N") #'himalaya-ui-compose)
    (define-key map (kbd "r") #'himalaya-ui-reply)
    (define-key map (kbd "R") #'himalaya-ui-reply-all)
    (define-key map (kbd "f") #'himalaya-ui-forward)
    (define-key map (kbd "q") #'himalaya-ui-back-or-quit)
    (define-key map (kbd "?") #'himalaya-ui-help)
    map))

(define-derived-mode himalaya-ui-mode vui-mode "Himalaya"
  "Major mode for the Himalaya VUI client."
  (hl-line-mode 1)
  (setq-local truncate-lines t))

(with-eval-after-load 'evil
  (evil-set-initial-state 'himalaya-ui-mode 'motion)
  (evil-define-key* '(motion normal) himalaya-ui-mode-map
    (kbd "j") #'himalaya-ui-next-row
    (kbd "k") #'himalaya-ui-previous-row
    (kbd "p") #'himalaya-ui-previous-row
    (kbd "RET") #'himalaya-ui-open
    (kbd "o") #'himalaya-ui-open
    (kbd "t") #'himalaya-ui-open-thread
    (kbd "g") #'himalaya-ui-refresh
    (kbd "/") #'himalaya-ui-search
    (kbd "c") #'himalaya-ui-clear-search
    (kbd "]") #'himalaya-ui-next-page
    (kbd "[") #'himalaya-ui-previous-page
    (kbd "s") #'himalaya-ui-cycle-sort
    (kbd "m") #'himalaya-ui-toggle-mark
    (kbd "M") #'himalaya-ui-toggle-mark-all
    (kbd "U") #'himalaya-ui-toggle-seen
    (kbd "*") #'himalaya-ui-toggle-flagged
    (kbd "a") #'himalaya-ui-archive
    (kbd "v") #'himalaya-ui-move
    (kbd "y") #'himalaya-ui-copy
    (kbd "d") #'himalaya-ui-delete
    (kbd "x") #'himalaya-ui-expunge
    (kbd "A") #'himalaya-ui-download
    (kbd "n") #'himalaya-ui-compose
    (kbd "N") #'himalaya-ui-compose
    (kbd "r") #'himalaya-ui-reply
    (kbd "R") #'himalaya-ui-reply-all
    (kbd "f") #'himalaya-ui-forward
    (kbd "q") #'himalaya-ui-back-or-quit
    (kbd "?") #'himalaya-ui-help))

;;;###autoload
(defun himalaya-ui ()
  "Open the Himalaya VUI mail client."
  (interactive)
  (let ((buffer (get-buffer-create "*Himalaya*")))
    (unless (vui-get-instance buffer)
      (with-current-buffer buffer
        (himalaya-ui-mode))
      (vui-mount (vui-component 'himalaya-ui-root) buffer)
      (with-current-buffer buffer
        (vui-rerender-on-resize)))
    (pop-to-buffer buffer)))

(provide 'himalaya-ui)
;;; himalaya-ui.el ends here
