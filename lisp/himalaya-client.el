;;; himalaya-client.el --- Asynchronous Himalaya client -*- lexical-binding: t; -*-

(require 'json)
(require 'message)
(require 'mml)
(require 'subr-x)

(defgroup himalaya-client nil
  "Himalaya mail client."
  :group 'mail)

(defcustom himalaya-client-program "himalaya"
  "Himalaya executable."
  :type 'string
  :group 'himalaya-client)

(defcustom himalaya-client-page-size 30
  "Number of envelopes requested per page."
  :type 'integer
  :group 'himalaya-client)

(defcustom himalaya-client-download-directory (expand-file-name "Downloads" "~")
  "Directory used for downloaded attachments."
  :type 'directory
  :group 'himalaya-client)

(defcustom himalaya-client-drafts-folder "Drafts"
  "Folder used for saved drafts."
  :type 'string
  :group 'himalaya-client)

(defun himalaya-client--concise-error (text fallback)
  (let ((message (string-trim
                  (replace-regexp-in-string "[[:space:]\n\r]+" " " (or text "")))))
    (if (string-empty-p message)
        fallback
      (truncate-string-to-width message 300 nil nil "…"))))

(defun himalaya-client--process-result (process stdout stderr callback plain-output)
  (unless (process-get process 'himalaya-client-finished)
    (process-put process 'himalaya-client-finished t)
    (let ((status (process-exit-status process))
          (output (with-current-buffer stdout (buffer-string)))
          (error-output (with-current-buffer stderr (buffer-string))))
      (kill-buffer stdout)
      (kill-buffer stderr)
      (cond
       ((not (zerop status))
        (funcall callback nil
                 (himalaya-client--concise-error
                  (if (string-empty-p (string-trim error-output)) output error-output)
                  (format "Himalaya exited with status %d" status))))
       ((not (string-empty-p error-output))
        (funcall callback nil
                 (himalaya-client--concise-error
                  error-output
                  "Himalaya wrote to stderr")))
       (plain-output
        (funcall callback output nil))
       (t
        (let (result parse-error)
          (condition-case error
              (setq result
                    (unless (string-empty-p (string-trim output))
                      (json-parse-string output
                                         :object-type 'plist
                                         :array-type 'list
                                         :null-object nil
                                         :false-object nil)))
            (error
             (setq parse-error
                   (format "Invalid Himalaya JSON: %s"
                           (error-message-string error)))))
          (if parse-error
              (funcall callback nil parse-error)
            (funcall callback result nil))))))))

(defun himalaya-client-request (arguments callback &optional input plain-output)
  "Run Himalaya with ARGUMENTS and call CALLBACK with result and error."
  (let ((stdout (generate-new-buffer " *himalaya-client-out*"))
        (stderr (generate-new-buffer " *himalaya-client-err*"))
        process)
    (condition-case error
        (progn
          (setq process
                (make-process
                 :name "himalaya-client"
                 :buffer stdout
                 :stderr stderr
                 :command (append (list himalaya-client-program "--quiet" "--output"
                                        (if plain-output "plain" "json"))
                                  arguments)
                 :connection-type 'pipe
                 :coding '(utf-8-unix . utf-8-unix)
                 :noquery t
                 :sentinel
                 (lambda (finished-process _event)
                   (when (memq (process-status finished-process) '(exit signal))
                     (himalaya-client--process-result
                      finished-process stdout stderr callback plain-output)))))
          (when (process-live-p process)
            (when input
              (process-send-string process input))
            (process-send-eof process))
          process)
      (error
       (when process
         (process-put process 'himalaya-client-finished t))
       (kill-buffer stdout)
       (kill-buffer stderr)
       (funcall callback nil (error-message-string error))
       nil))))

(defun himalaya-client--value (object key)
  (let ((name (substring (symbol-name key) 1)))
    (cond
     ((hash-table-p object)
      (or (gethash key object)
          (gethash (intern name) object)
          (gethash name object)))
     ((and (listp object) (keywordp (car object)))
      (plist-get object key))
     ((listp object)
      (or (alist-get key object)
          (alist-get (intern name) object)
          (alist-get name object nil nil #'equal))))))

(defun himalaya-client--flag-name (flag)
  (when (or (stringp flag) (symbolp flag))
    (let ((name (replace-regexp-in-string
                 "\\`[:\\\\]+" "" (if (symbolp flag) (symbol-name flag) flag))))
      (unless (string-empty-p name)
        (downcase name)))))

(defun himalaya-client--flag-names (flags)
  (cond
   ((null flags) nil)
   ((or (stringp flags) (symbolp flags))
    (let ((name (himalaya-client--flag-name flags)))
      (and name (list name))))
   ((vectorp flags)
    (himalaya-client--flag-names (append flags nil)))
   ((hash-table-p flags)
    (let ((name (or (gethash :name flags)
                    (gethash 'name flags)
                    (gethash "name" flags)))
          names)
      (if name
          (himalaya-client--flag-names name)
        (maphash
         (lambda (key value)
           (when value
             (setq names (append names (himalaya-client--flag-names key)))))
         flags)
        names)))
   ((and (listp flags) (keywordp (car flags)))
    (let ((name (plist-get flags :name))
          names)
      (if name
          (himalaya-client--flag-names name)
        (while flags
          (when (cadr flags)
            (setq names
                  (append names (himalaya-client--flag-names (car flags)))))
          (setq flags (cddr flags)))
        names)))
   ((listp flags)
    (let (names)
      (dolist (flag flags names)
        (setq names (append names (himalaya-client--flag-names flag))))))))

(defun himalaya-client--address-value (address key alternate)
  (or (himalaya-client--value address key)
      (himalaya-client--value address alternate)))

(defun himalaya-client--normalize-envelope (envelope)
  (let* ((from (himalaya-client--value envelope :from))
         (to (himalaya-client--value envelope :to))
         (flags (delete-dups
                 (himalaya-client--flag-names
                  (himalaya-client--value envelope :flags))))
         (id (himalaya-client--value envelope :id)))
    (list :id (and id (format "%s" id))
          :subject (or (himalaya-client--value envelope :subject) "")
          :from-name (or (himalaya-client--address-value from :name :display-name) "")
          :from-address (or (himalaya-client--address-value from :addr :address) "")
          :to-name (or (himalaya-client--address-value to :name :display-name) "")
          :to-address (or (himalaya-client--address-value to :addr :address) "")
          :date (or (himalaya-client--value envelope :date) "")
          :flags flags
          :unread (not (member "seen" flags))
          :starred (and (member "flagged" flags) t)
          :deleted (and (member "deleted" flags) t)
          :draft (and (member "draft" flags) t)
          :answered (and (member "answered" flags) t)
          :has-attachment
          (and (or (himalaya-client--value envelope :has_attachment)
                   (himalaya-client--value envelope :has-attachment))
               t))))

(defun himalaya-client--as-list (value)
  (cond
   ((null value) nil)
   ((vectorp value) (append value nil))
   ((listp value) value)
   (t (list value))))

(defun himalaya-client--strings (values)
  (mapcar (lambda (value) (format "%s" value))
          (himalaya-client--as-list values)))

(defun himalaya-client--query-string (value)
  (cond
   ((null value) nil)
   ((stringp value) (unless (string-empty-p (string-trim value)) value))
   ((listp value) (string-join (himalaya-client--strings value) " "))
   (t (format "%s" value))))

(defun himalaya-client--envelope-query (query sort)
  (let ((filter (himalaya-client--query-string query))
        (ordering (himalaya-client--query-string sort)))
    (when (and ordering
               (not (string-match-p "\\`[[:space:]]*order[[:space:]]+by\\_>" ordering)))
      (setq ordering (concat "order by " ordering)))
    (string-join (delq nil (list filter ordering)) " ")))

(defun himalaya-client-accounts (callback)
  "Fetch configured accounts and call CALLBACK."
  (himalaya-client-request '("account" "list") callback))

(defun himalaya-client-folders (account callback)
  "Fetch folders for ACCOUNT and call CALLBACK."
  (himalaya-client-request
   (list "folder" "list" "--account" account)
   callback))

(defun himalaya-client-envelopes (account folder page query sort callback)
  "Fetch one envelope page and call CALLBACK with normalized envelopes."
  (let ((arguments
         (list "envelope" "list"
               "--account" account
               "--folder" folder
               "--page" (number-to-string (or page 1))
               "--page-size" (number-to-string himalaya-client-page-size)))
        (search (himalaya-client--envelope-query query sort)))
    (when (not (string-empty-p search))
      (setq arguments (append arguments (list search))))
    (himalaya-client-request
     arguments
     (lambda (result error)
       (if error
           (funcall callback nil error)
         (funcall callback
                  (mapcar #'himalaya-client--normalize-envelope result)
                  nil))))))

(defun himalaya-client-read (account folder id callback)
  "Preview message ID in FOLDER for ACCOUNT and call CALLBACK."
  (himalaya-client-request
   (list "message" "read" "--account" account "--folder" folder "--preview"
         (format "%s" id))
   callback))

(defun himalaya-client-thread (account folder id callback)
  "Preview the thread containing ID and call CALLBACK."
  (himalaya-client-request
   (list "message" "thread" "--account" account "--folder" folder "--preview"
         (format "%s" id))
   callback))

(defun himalaya-client--operation-name (operation allowed)
  (let ((name (downcase (format "%s" operation))))
    (unless (member name allowed)
      (error "Unsupported Himalaya operation: %s" operation))
    name))

(defun himalaya-client-flag (account folder operation ids flags callback)
  "Apply flag OPERATION to IDS in FOLDER and call CALLBACK."
  (let ((name (himalaya-client--operation-name operation '("add" "set" "remove"))))
    (himalaya-client-request
     (append (list "flag" name "--account" account "--folder" folder)
             (himalaya-client--strings ids)
             (himalaya-client--strings flags))
     callback)))

(defun himalaya-client-transfer (account folder operation target ids callback)
  "Apply transfer OPERATION to IDS and call CALLBACK."
  (let ((name (himalaya-client--operation-name operation '("copy" "move"))))
    (himalaya-client-request
     (append (list "message" name "--account" account "--folder" folder target)
             (himalaya-client--strings ids))
     callback)))

(defun himalaya-client-delete (account folder ids callback)
  "Mark IDS deleted in FOLDER and call CALLBACK."
  (himalaya-client-flag account folder "add" ids '("deleted") callback))

(defun himalaya-client-expunge (account folder callback)
  "Expunge deleted messages from FOLDER and call CALLBACK."
  (himalaya-client-request
   (list "folder" "expunge" "--account" account folder)
   callback))

(defun himalaya-client-download (account folder ids callback)
  "Download attachments from IDS and call CALLBACK."
  (himalaya-client-request
   (append (list "attachment" "download"
                 "--account" account
                 "--folder" folder
                 "--downloads-dir"
                 (expand-file-name himalaya-client-download-directory))
           (himalaya-client--strings ids))
   callback))

(defvar-local himalaya-client-compose-account nil)
(defvar-local himalaya-client-compose-pending nil)

(define-derived-mode himalaya-client-compose-mode message-mode "Himalaya Compose"
  "Edit a Himalaya MML message.")

(defun himalaya-client--compose-contents ()
  (buffer-substring-no-properties (point-min) (point-max)))

(defun himalaya-client--compose-mime ()
  (let ((contents (himalaya-client--compose-contents))
        (directory default-directory)
        (options message-options)
        (separator mail-header-separator))
    (with-temp-buffer
      (let ((default-directory directory)
            (message-options options)
            (mail-header-separator separator)
            (message-inhibit-body-encoding nil))
        (insert contents)
        (mml-to-mime)
        (buffer-string)))))

(defun himalaya-client--finish-compose (buffer action result error)
  (if error
      (progn
        (when (buffer-live-p buffer)
          (with-current-buffer buffer
            (setq himalaya-client-compose-pending nil)))
        (message "Himalaya could not %s message: %s" action error))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (set-buffer-modified-p nil))
      (kill-buffer buffer))
    (message "Himalaya message %s%s"
             (if (string= action "send") "sent" "saved to drafts")
             (if (and (stringp result) (not (string-empty-p (string-trim result))))
                 (format ": %s" (string-trim result))
               ""))))

(defun himalaya-client-compose-send ()
  "Send the current Himalaya MML message."
  (interactive)
  (unless (derived-mode-p 'himalaya-client-compose-mode)
    (user-error "Not in a Himalaya compose buffer"))
  (when himalaya-client-compose-pending
    (user-error "A Himalaya compose operation is already running"))
  (let ((buffer (current-buffer))
        (account himalaya-client-compose-account)
        (contents (himalaya-client--compose-contents)))
    (setq himalaya-client-compose-pending t)
    (himalaya-client-request
     (list "template" "send" "--account" account)
     (lambda (result error)
       (himalaya-client--finish-compose buffer "send" result error))
     contents)))

(defun himalaya-client-compose-save-draft ()
  "Save the current compose buffer to the drafts folder."
  (interactive)
  (unless (derived-mode-p 'himalaya-client-compose-mode)
    (user-error "Not in a Himalaya compose buffer"))
  (when himalaya-client-compose-pending
    (user-error "A Himalaya compose operation is already running"))
  (let ((buffer (current-buffer))
        (account himalaya-client-compose-account)
        (mime (himalaya-client--compose-mime)))
    (setq himalaya-client-compose-pending t)
    (himalaya-client-request
     (list "message" "save"
           "--account" account
           "--folder" himalaya-client-drafts-folder)
     (lambda (result error)
       (himalaya-client--finish-compose buffer "save" result error))
     mime
     t)))

(define-key himalaya-client-compose-mode-map (kbd "C-c C-c")
            #'himalaya-client-compose-send)
(define-key himalaya-client-compose-mode-map (kbd "C-c C-d")
            #'himalaya-client-compose-save-draft)
(define-key himalaya-client-compose-mode-map (kbd "C-c C-a")
            #'mml-attach-file)

(defun himalaya-client--template-arguments (account folder id kind)
  (let ((name (if kind (downcase (format "%s" kind)) "new")))
    (unless (member name '("new" "reply" "reply-all" "forward"))
      (user-error "Unsupported compose kind: %s" kind))
    (when (and (not (string= name "new")) (or (null folder) (null id)))
      (user-error "Compose kind %s requires a folder and message ID" name))
    (cond
     ((string= name "new")
      (list "template" "write" "--account" account))
     ((string= name "reply")
      (list "template" "reply" "--account" account "--folder" folder
            (format "%s" id)))
     ((string= name "reply-all")
      (list "template" "reply" "--account" account "--folder" folder "--all"
            (format "%s" id)))
     (t
      (list "template" "forward" "--account" account "--folder" folder
            (format "%s" id))))))

(defun himalaya-client--place-template-cursor (cursor)
  (let ((row (or (himalaya-client--value cursor :row) 1))
        (column (or (himalaya-client--value cursor :col) 0)))
    (goto-char (point-min))
    (forward-line (max 0 (1- row)))
    (move-to-column column)))

(defun himalaya-client--open-compose-buffer (account template)
  (let ((content (if (stringp template)
                     template
                   (himalaya-client--value template :content)))
        (cursor (and (listp template)
                     (himalaya-client--value template :cursor)))
        (buffer (generate-new-buffer "*Himalaya compose*")))
    (unless (stringp content)
      (kill-buffer buffer)
      (error "Himalaya returned an invalid message template"))
    (with-current-buffer buffer
      (himalaya-client-compose-mode)
      (setq himalaya-client-compose-account account)
      (insert content)
      (if cursor
          (himalaya-client--place-template-cursor cursor)
        (goto-char (point-max))))
    (pop-to-buffer buffer)))

(defun himalaya-client-compose (account &optional folder id kind)
  "Open an asynchronous compose buffer for ACCOUNT."
  (interactive "sAccount: ")
  (let ((arguments (himalaya-client--template-arguments account folder id kind)))
    (himalaya-client-request
     arguments
     (lambda (template error)
       (if error
           (message "Himalaya could not compose message: %s" error)
         (condition-case compose-error
             (himalaya-client--open-compose-buffer account template)
           (error
            (message "Himalaya could not compose message: %s"
                     (error-message-string compose-error)))))))))

(provide 'himalaya-client)

;;; himalaya-client.el ends here
