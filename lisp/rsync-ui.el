;;; rsync-ui.el --- Clear rsync transfers with VUI -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'vui)
(require 'vui-components)

(declare-function dired-get-marked-files "dired")
(declare-function evil-define-key* "evil-core" (state keymap key def &rest bindings))
(declare-function evil-set-initial-state "evil-core" (mode state))

(defgroup rsync-ui nil
  "Rsync transfers."
  :group 'tools)

(defcustom rsync-ui-program "rsync"
  "Rsync executable."
  :type 'string
  :group 'rsync-ui)

(defcustom rsync-ui-buffer-name "*rsync*"
  "Transfer buffer."
  :type 'string
  :group 'rsync-ui)


(defface rsync-ui-strong
  '((t :inherit bold))
  "Structural text."
  :group 'rsync-ui)

(defface rsync-ui-faded
  '((t :inherit shadow))
  "Secondary text."
  :group 'rsync-ui)

(defvar-local rsync-ui--actions nil)
(defvar-local rsync-ui--process nil)

(defun rsync-ui--remote-p (kind)
  (equal kind "ssh"))

(defun rsync-ui--source-arguments (sources mode)
  (let ((paths (mapcar (lambda (path)
                         (expand-file-name path))
                       sources)))
    (if (and (= (length paths) 1)
             (file-directory-p (car paths))
             (equal mode "contents"))
        (list (file-name-as-directory (car paths)))
      (mapcar #'directory-file-name paths))))

(defun rsync-ui--target-argument (kind local-target ssh-host ssh-path)
  (if (rsync-ui--remote-p kind)
      (format "%s:%s" ssh-host (file-name-as-directory ssh-path))
    (file-name-as-directory (expand-file-name local-target))))

(defun rsync-ui--valid-host-p (host)
  (and (not (string-empty-p host))
       (string-match-p "\\`[-[:alnum:]_.@%]+\\'" host)))

(defun rsync-ui--validate (sources kind local-target ssh-host ssh-path ssh-port)
  (cond
   ((null sources) "Choose at least one source.")
   ((seq-some (lambda (path) (not (file-exists-p path))) sources)
    "A source no longer exists.")
   ((and (not (rsync-ui--remote-p kind)) (string-empty-p local-target))
    "Choose a destination folder.")
   ((and (rsync-ui--remote-p kind) (not (rsync-ui--valid-host-p ssh-host)))
    "Enter an SSH host such as user@example.org.")
   ((and (rsync-ui--remote-p kind) (string-empty-p ssh-path))
    "Enter the folder on the SSH host.")
   ((and (rsync-ui--remote-p kind)
         (not (string-match-p "\\`[0-9]+\\'" ssh-port)))
    "The SSH port must be a number.")
   ((and (rsync-ui--remote-p kind)
         (not (<= 1 (string-to-number ssh-port) 65535)))
    "The SSH port must be between 1 and 65535.")
   (nil nil)))

(defun rsync-ui--arguments (sources kind local-target ssh-host ssh-path ssh-port remote-rsync mode compress delete preview)
  (let ((arguments (list "-a" "--human-readable" "--protect-args" "--stats"
                         "--out-format=%i|%n%L")))
    (if preview
        (setq arguments (append arguments (list "--dry-run" "--itemize-changes")))
      (setq arguments (append arguments (list "--info=progress2"))))
    (when (and compress (rsync-ui--remote-p kind))
      (setq arguments (append arguments (list "--compress"))))
    (when delete
      (setq arguments (append arguments (list "--delete"))))
    (when (and (rsync-ui--remote-p kind) (not (equal ssh-port "22")))
      (setq arguments
            (append arguments (list "--rsh" (format "ssh -p %d" (string-to-number ssh-port))))))
    (when (and (rsync-ui--remote-p kind)
               remote-rsync
               (not (equal remote-rsync "rsync")))
      (setq arguments
            (append arguments (list (concat "--rsync-path=" remote-rsync)))))
    (append arguments
            (rsync-ui--source-arguments sources mode)
            (list (rsync-ui--target-argument kind local-target ssh-host ssh-path)))))

(defun rsync-ui--format-bytes (text)
  (if (string-match "\\([0-9.,]+\\)\\([KMGTPE]?\\)\\(?:B\\|[[:space:]]+bytes\\)" text)
      (concat (match-string 1 text)
              (if (string-empty-p (match-string 2 text))
                  " B"
                (concat (match-string 2 text) "B")))
    "0 B"))

(defun rsync-ui--preview-summary (output)
  (let* ((lines (split-string output "\n" t))
         (changes (seq-filter (lambda (line)
                                (string-match-p "\\`[^|[:space:]]+|" line))
                              lines))
         (size-line (seq-find (lambda (line)
                                (string-prefix-p "Total transferred file size:" line))
                              lines))
         (size (if size-line (rsync-ui--format-bytes size-line) "0 B")))
    (list :count (length changes)
          :size size
          :sample (seq-take changes 6))))

(defun rsync-ui--progress-data (chunk)
  (let ((start 0)
        result)
    (while (string-match
            "\\([0-9.,]+[KMGTPE]?\\)[[:space:]]+\\([0-9]+\\)%[[:space:]]+\\([^[:space:]]+\\)[[:space:]]+\\([0-9:]+\\)"
            chunk start)
      (setq result (list :bytes (save-match-data
                                  (rsync-ui--format-bytes
                                   (concat (match-string 1 chunk) " bytes")))
                         :percent (string-to-number (match-string 2 chunk))
                         :speed (match-string 3 chunk)
                         :eta (match-string 4 chunk))
            start (match-end 0)))
    result))

(defun rsync-ui--process-error (kind ssh-host output)
  (let ((message (string-trim output)))
    (cond
     ((and (rsync-ui--remote-p kind)
           (string-match-p "\\brsync: \\(?:command \\)?not found\\b" message))
      (format "Rsync is not installed on %s. Install rsync on the SSH server, then preview again."
              ssh-host))
     ((and (rsync-ui--remote-p kind)
           (string-match-p "Permission denied" message))
      (format "SSH authentication failed for %s. Check your SSH key or agent." ssh-host))
     ((and (rsync-ui--remote-p kind)
           (string-match-p "Connection refused" message))
      (format "SSH connection to %s was refused. Check the host and SSH port." ssh-host))
     ((string-empty-p message)
      "Rsync failed without an error message.")
     (t message))))

(defun rsync-ui--start-process (arguments on-output on-done)
  (let* ((stderr-buffer (generate-new-buffer " *rsync-ui-stderr*"))
         (output "")
         (parse-tail "")
         (process-environment (cons "LC_ALL=C" process-environment))
         (process
          (make-process
           :name "rsync-ui"
           :command (cons rsync-ui-program arguments)
           :connection-type 'pipe
           :noquery t
           :stderr stderr-buffer
           :filter (lambda (_process chunk)
                     (setq output (concat output chunk)
                           parse-tail (concat parse-tail chunk))
                     (funcall on-output parse-tail)
                     (when (> (length parse-tail) 512)
                       (setq parse-tail (substring parse-tail -512))))
           :sentinel (lambda (finished _event)
                       (unless (process-live-p finished)
                         (let ((stderr (when (buffer-live-p stderr-buffer)
                                         (with-current-buffer stderr-buffer
                                           (buffer-string)))))
                           (when (buffer-live-p stderr-buffer)
                             (kill-buffer stderr-buffer))
                           (funcall on-done (process-exit-status finished)
                                    (concat output stderr))))))))
    process))

(defun rsync-ui--find-remote-rsync (host port callback)
  (let* ((buffer (generate-new-buffer " *rsync-ui-ssh-check*"))
         (script (concat
                  "command -v rsync 2>/dev/null || "
                  "for path in /run/current-system/sw/bin/rsync "
                  "/nix/var/nix/profiles/default/bin/rsync "
                  "/usr/local/bin/rsync; do "
                  "if [ -x \"$path\" ]; then printf '%s\\n' \"$path\"; exit 0; fi; "
                  "done; exit 127"))
         (process-environment (cons "LC_ALL=C" process-environment))
         (process
          (make-process
           :name "rsync-ui-ssh-check"
           :command (list "ssh" "-o" "BatchMode=yes" "-p" port host script)
           :buffer buffer
           :stderr buffer
           :connection-type 'pipe
           :noquery t
           :sentinel
           (lambda (finished _event)
             (unless (process-live-p finished)
               (let* ((output (when (buffer-live-p buffer)
                                (with-current-buffer buffer
                                  (string-trim (buffer-string)))))
                      (path (and (zerop (process-exit-status finished))
                                 (car (split-string output "\n" t)))))
                 (when (buffer-live-p buffer)
                   (kill-buffer buffer))
                 (funcall callback path output)))))))
    process))

(defun rsync-ui--source-title (sources)
  (cond
   ((null sources) "No source selected")
   ((= (length sources) 1) (abbreviate-file-name (car sources)))
   (t (format "%d selected items" (length sources)))))

(defun rsync-ui--destination-title (kind local-target ssh-host ssh-path)
  (if (rsync-ui--remote-p kind)
      (if (and (not (string-empty-p ssh-host)) (not (string-empty-p ssh-path)))
          (format "%s:%s" ssh-host ssh-path)
        "SSH destination incomplete")
    (if (string-empty-p local-target)
        "No destination selected"
      (abbreviate-file-name local-target))))

(defun rsync-ui--step-strip (stage)
  (let ((position (pcase stage
                    ('setup 1)
                    ((or 'previewing 'ready) 2)
                    (_ 3))))
    (vui-flex
     :width 'fill-column
     :justify :space-between
     (vui-text (if (> position 1) "✓ 1  ROUTE" "● 1  ROUTE")
               :face (if (= position 1) 'rsync-ui-strong 'success))
     (vui-text (cond
                ((> position 2) "✓ 2  PREVIEW")
                ((= position 2) "● 2  PREVIEW")
                (t "○ 2  PREVIEW"))
               :face (cond ((> position 2) 'success)
                           ((= position 2) 'rsync-ui-strong)
                           (t 'rsync-ui-faded)))
     (vui-text (if (= position 3) "● 3  TRANSFER" "○ 3  TRANSFER")
               :face (if (= position 3) 'rsync-ui-strong 'rsync-ui-faded)))))

(defun rsync-ui--window-width ()
  (if-let* ((window (get-buffer-window (current-buffer) t)))
      (window-body-width window)
    (window-width)))

(defun rsync-ui--route (sources kind local-target ssh-host ssh-path)
  (let* ((width (max 24 (- (rsync-ui--window-width) 2)))
         (remote (rsync-ui--remote-p kind))
         (destination-label (if remote "SSH DESTINATION" "LOCAL DESTINATION"))
         (destination-glyph (if remote "⌁" "◎"))
         (destination-face (if remote 'warning 'success)))
    (if (>= width 72)
        (let* ((card-width (min 30 (/ (- width 8) 2)))
               (text-width (- card-width 2))
               (source (truncate-string-to-width
                        (rsync-ui--source-title sources) text-width nil nil "…"))
               (destination (truncate-string-to-width
                             (rsync-ui--destination-title kind local-target ssh-host ssh-path)
                             text-width nil nil "…")))
          (vui-vstack
           :spacing 0
           (vui-hstack
            :spacing 2
            (vui-box (vui-text "●" :face '(:inherit link :height 1.5 :weight bold))
                     :width card-width :align :center)
            (vui-box (vui-text "") :width 4)
            (vui-box (vui-text destination-glyph
                               :face `(:inherit ,destination-face :height 1.5 :weight bold))
                     :width card-width :align :center))
           (vui-hstack
            :spacing 2
            (vui-box (vui-text "SOURCE" :face 'rsync-ui-faded)
                     :width card-width :align :center)
            (vui-box (vui-text "") :width 4)
            (vui-box (vui-text destination-label :face 'rsync-ui-faded)
                     :width card-width :align :center))
           (vui-hstack
            :spacing 2
            (vui-box (vui-text source :face 'rsync-ui-strong)
                     :width card-width :align :center)
            (vui-box (vui-text "→" :face 'shadow) :width 4 :align :center)
            (vui-box (vui-text destination :face 'rsync-ui-strong)
                     :width card-width :align :center))))
      (let* ((card-width (min 56 width))
             (text-width (- card-width 2))
             (source (truncate-string-to-width
                      (rsync-ui--source-title sources) text-width nil nil "…"))
             (destination (truncate-string-to-width
                           (rsync-ui--destination-title kind local-target ssh-host ssh-path)
                           text-width nil nil "…")))
        (vui-vstack
         :spacing 0
         (vui-hstack
          (vui-text "● " :face 'link)
          (vui-text "SOURCE" :face 'rsync-ui-faded))
         (vui-box (vui-text source :face 'rsync-ui-strong)
                  :width card-width :align :left :padding-left 2)
         (vui-box (vui-text "↓" :face 'shadow) :width card-width :align :center)
         (vui-hstack
          (vui-text (concat destination-glyph " ") :face destination-face)
          (vui-text destination-label :face 'rsync-ui-faded))
         (vui-box (vui-text destination :face 'rsync-ui-strong)
                  :width card-width :align :left :padding-left 2))))))

(defun rsync-ui--field-row (label field)
  (vui-hstack
   (vui-box (vui-text label :face 'rsync-ui-faded) :width 16 :align :right)
   field))

(defun rsync-ui--gauge (progress)
  (let* ((width 44)
         (done (max 0 (min width (round (* width (/ progress 100.0)))))))
    (vui-vstack
     :spacing 0
     (vui-box
      (vui-hstack
       :spacing 0
       (vui-text (make-string done ?█) :face 'success)
       (vui-text (make-string (- width done) ?░) :face 'shadow))
      :width 52 :align :center)
     (vui-box (vui-text (format "%3d%%" progress)
                        :face '(:inherit bold :height 1.6))
              :width 52 :align :center))))

(defun rsync-ui--preview-panel (preview delete)
  (let ((count (plist-get preview :count))
        (size (plist-get preview :size)))
    (vui-vstack
     :spacing 1
     (vui-box
      (vui-text (if (zerop count)
                    "Everything is already in sync"
                  (format "%d changes · %s to transfer" count size))
                :face (if (zerop count) 'success 'rsync-ui-strong))
      :width 66 :align :center)
     (when delete
       (vui-box (vui-text "Delete is enabled: extra files at the destination will be removed."
                          :face '(:inherit warning :weight bold))
                :width 66 :align :center))
     (when-let* ((sample (plist-get preview :sample)))
       (vui-vstack
        :spacing 0 :indent 4
        (mapcar (lambda (line)
                  (vui-text (truncate-string-to-width line 62 nil nil "…") :face 'shadow))
                sample))))))


(vui-defcomponent rsync-ui-app (initial-sources initial-target)
  :state ((sources (mapcar #'expand-file-name initial-sources))
          (kind "local")
          (local-target (or initial-target ""))
          (ssh-host "")
          (ssh-path "~/")
          (ssh-port "22")
          (mode "contents")
          (compress t)
          (delete nil)
          (stage 'setup)
          (preview nil)
          (status nil)
          (progress 0)
          (transferred "0 B")
          (speed "")
          (eta "")
          (remote-rsync nil)
          (process nil))
  :on-unmount
  (when (process-live-p process)
    (delete-process process))
  :render
  (let* ((invalidate
          (lambda (key value)
            (vui-batch
             (vui-set-state key value)
             (vui-set-state :stage 'setup)
             (vui-set-state :preview nil)
             (vui-set-state :remote-rsync nil)
             (vui-set-state :status nil))))
         (choose-source
          (vui-async-callback ()
            (when-let* ((path (read-file-name "Source file or folder: " nil nil t)))
              (funcall invalidate :sources (list path)))))
         (choose-target
          (vui-async-callback ()
            (when-let* ((path (read-directory-name "Destination folder: " nil nil nil)))
              (funcall invalidate :local-target path))))
         (start-preview
          (vui-async-callback (rsync-path)
            (let* ((arguments (rsync-ui--arguments
                               sources kind local-target ssh-host ssh-path ssh-port
                               rsync-path mode compress delete t))
                   (runner
                    (rsync-ui--start-process
                     arguments
                     (vui-async-callback (_chunk) nil)
                     (vui-async-callback (exit output)
                       (vui-set-state :process nil)
                       (setq rsync-ui--process nil)
                       (if (zerop exit)
                           (vui-batch
                            (vui-set-state :preview (rsync-ui--preview-summary output))
                            (vui-set-state :stage 'ready)
                            (vui-set-state :status nil))
                         (vui-batch
                          (vui-set-state :stage 'setup)
                          (vui-set-state :status
                                         (cons (rsync-ui--process-error kind ssh-host output)
                                               'error))))))))
              (setq rsync-ui--process runner)
              (vui-batch
               (vui-set-state :process runner)
               (vui-set-state :stage 'previewing)
               (vui-set-state :status
                              (cons "Checking the route without changing files…" 'shadow))))))
         (run-preview
          (vui-async-callback ()
            (let ((problem (rsync-ui--validate sources kind local-target ssh-host ssh-path ssh-port)))
              (cond
               (problem
                (vui-set-state :status (cons problem 'error)))
               ((not (rsync-ui--remote-p kind))
                (funcall start-preview nil))
               (remote-rsync
                (funcall start-preview remote-rsync))
               (t
                (let ((runner
                       (rsync-ui--find-remote-rsync
                        ssh-host ssh-port
                        (vui-async-callback (path output)
                          (vui-set-state :process nil)
                          (setq rsync-ui--process nil)
                          (if path
                              (progn
                                (vui-set-state :remote-rsync path)
                                (funcall start-preview path))
                            (vui-batch
                             (vui-set-state :stage 'setup)
                             (vui-set-state
                              :status
                              (cons
                               (if (string-empty-p output)
                                   (format
                                    "Rsync is unavailable to non-interactive SSH on %s. Add it to the remote PATH."
                                    ssh-host)
                                 (rsync-ui--process-error kind ssh-host output))
                               'error))))))))
                  (setq rsync-ui--process runner)
                  (vui-batch
                   (vui-set-state :process runner)
                   (vui-set-state :stage 'previewing)
                   (vui-set-state :status
                                  (cons "Locating rsync on the SSH server…" 'shadow)))))))))
         (run-transfer
          (vui-async-callback ()
            (when (eq stage 'ready)
              (let* ((arguments (rsync-ui--arguments
                                 sources kind local-target ssh-host ssh-path ssh-port
                                 remote-rsync mode compress delete nil))
                     (runner
                      (rsync-ui--start-process
                       arguments
                       (vui-async-callback (chunk)
                         (when-let* ((data (rsync-ui--progress-data chunk)))
                           (vui-batch
                            (vui-set-state :progress (plist-get data :percent))
                            (vui-set-state :transferred (plist-get data :bytes))
                            (vui-set-state :speed (plist-get data :speed))
                            (vui-set-state :eta (plist-get data :eta)))))
                       (vui-async-callback (exit output)
                         (setq rsync-ui--process nil)
                         (vui-set-state :process nil)
                         (if (zerop exit)
                             (vui-batch
                              (vui-set-state :progress 100)
                              (vui-set-state :stage 'done)
                              (vui-set-state :status (cons "Transfer complete." 'success)))
                           (vui-batch
                            (vui-set-state :stage 'failed)
                            (vui-set-state :status
                                           (cons (rsync-ui--process-error kind ssh-host output)
                                                 'error))))))))
                (setq rsync-ui--process runner)
                (vui-batch
                 (vui-set-state :process runner)
                 (vui-set-state :stage 'running)
                 (vui-set-state :progress 0)
                 (vui-set-state :status nil))))))
         (cancel-transfer
          (vui-async-callback ()
            (when (process-live-p process)
              (delete-process process)
              (setq rsync-ui--process nil)
              (vui-batch
               (vui-set-state :process nil)
               (vui-set-state :stage 'cancelled)
               (vui-set-state :status (cons "Transfer cancelled. Files already copied remain valid." 'warning))))))
         (reset
          (vui-async-callback ()
            (unless (process-live-p process)
              (vui-batch
               (vui-set-state :stage 'setup)
               (vui-set-state :preview nil)
               (vui-set-state :status nil)
               (vui-set-state :progress 0)))))
         (busy (process-live-p process))
         (source-width (max 12 (min 42 (- (rsync-ui--window-width) 31)))))
    (setq rsync-ui--actions
          (list :choose-source choose-source
                :choose-target choose-target
                :preview run-preview
                :start run-transfer
                :cancel cancel-transfer
                :reset reset))
    (vui-vstack
     :spacing 1
     (rsync-ui--step-strip stage)
     (rsync-ui--route sources kind local-target ssh-host ssh-path)
     (cond
      ((memq stage '(running done failed cancelled))
       (vui-vstack
        :spacing 1
        (rsync-ui--gauge progress)
        (vui-flex
         :width 52 :justify :space-between
         (vui-text transferred :face 'rsync-ui-strong)
         (vui-text (if (string-empty-p speed) "Waiting for data…" speed) :face 'shadow)
         (vui-text (if (string-empty-p eta) "" (format "ETA %s" eta)) :face 'shadow))))
      ((eq stage 'ready)
       (rsync-ui--preview-panel preview delete))
      (t
       (vui-vstack
        :spacing 1
        (rsync-ui--field-row
         "Source"
         (vui-hstack
          :spacing 1
          (vui-box
           (vui-text
            (truncate-string-to-width
             (rsync-ui--source-title sources) (max 10 (- source-width 2)) nil nil "…"))
           :width source-width)
          (vui-button "Choose…" :on-click choose-source :disabled busy)))
        (rsync-ui--field-row
         "Destination"
         (vui-select :value kind
                     :options '(("local" . "Local folder") ("ssh" . "SSH server"))
                     :on-change (lambda (value) (funcall invalidate :kind value))))
        (if (rsync-ui--remote-p kind)
            (vui-vstack
             :spacing 1
             (rsync-ui--field-row
              "SSH host"
              (vui-field :value ssh-host :size 42 :key 'ssh-host
                         :placeholder "user@example.org"
                         :on-change (lambda (value) (funcall invalidate :ssh-host value))))
             (rsync-ui--field-row
              "Remote folder"
              (vui-field :value ssh-path :size 42 :key 'ssh-path
                         :placeholder "~/Backups/"
                         :on-change (lambda (value) (funcall invalidate :ssh-path value))))
             (rsync-ui--field-row
              "SSH port"
              (vui-field :value ssh-port :size 8 :key 'ssh-port
                         :on-change (lambda (value) (funcall invalidate :ssh-port value))))
             (rsync-ui--field-row
              ""
              (vui-muted "Uses your SSH key or agent; no password is stored.")))
          (rsync-ui--field-row
           "Local folder"
           (vui-hstack
            :spacing 1
            (vui-field :value local-target :size 36 :key 'local-target
                       :placeholder "~/Backups/"
                       :on-change (lambda (value) (funcall invalidate :local-target value)))
            (vui-button "Choose…" :on-click choose-target :disabled busy))))
        (rsync-ui--field-row
         "Folder behavior"
         (vui-select :value mode
                     :options '(("contents" . "Copy its contents")
                                ("item" . "Copy the folder itself"))
                     :on-change (lambda (value) (funcall invalidate :mode value))))
        (vui-collapsible
         :title "Advanced options"
         :initially-expanded nil
         (vui-vstack
          :spacing 1 :indent 16
          (vui-checkbox :checked compress
                        :label "Compress data sent over SSH"
                        :on-change (lambda (value) (funcall invalidate :compress value)))
          (vui-checkbox :checked delete
                        :label "Delete destination files missing from the source"
                        :on-change (lambda (value) (funcall invalidate :delete value)))
          (when delete
            (vui-warning "Preview deletions carefully. This option changes the destination.")))))))
     (when status
       (vui-box (vui-text (car status) :face (cdr status)) :width 66 :align :center))
     (vui-flex
      :width 'fill-column
      :justify :space-between
      (vui-hstack
       :spacing 2
       (vui-button "Preview" :on-click run-preview :disabled busy)
       (vui-button "Start transfer" :on-click run-transfer
                   :disabled (or busy (not (eq stage 'ready)))
                   :face (when (eq stage 'ready) 'success))
       (vui-button "Cancel" :on-click cancel-transfer :disabled (not busy) :face 'warning)
       (vui-button "Reset" :on-click reset :disabled busy :face 'shadow))
      (vui-muted "p preview · s start · x cancel · r reset · q close")))))

(defun rsync-ui--invoke (action)
  (if-let* ((callback (plist-get rsync-ui--actions action)))
      (funcall callback)
    (user-error "That action is not available")))

(defun rsync-ui-preview ()
  (interactive)
  (rsync-ui--invoke :preview))

(defun rsync-ui-start ()
  (interactive)
  (rsync-ui--invoke :start))

(defun rsync-ui-cancel ()
  (interactive)
  (rsync-ui--invoke :cancel))

(defun rsync-ui-reset ()
  (interactive)
  (rsync-ui--invoke :reset))

(defun rsync-ui-choose-source ()
  (interactive)
  (rsync-ui--invoke :choose-source))

(defun rsync-ui-choose-target ()
  (interactive)
  (rsync-ui--invoke :choose-target))

(defun rsync-ui-next-widget ()
  (interactive)
  (condition-case nil
      (widget-forward 1)
    (error
     (goto-char (point-min))
     (widget-forward 1))))

(defun rsync-ui-previous-widget ()
  (interactive)
  (condition-case nil
      (widget-backward 1)
    (error
     (goto-char (point-max))
     (widget-backward 1))))

(defvar rsync-ui-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map vui-mode-map)
    (define-key map (kbd "j") #'rsync-ui-next-widget)
    (define-key map (kbd "k") #'rsync-ui-previous-widget)
    (define-key map (kbd "TAB") #'rsync-ui-next-widget)
    (define-key map (kbd "<backtab>") #'rsync-ui-previous-widget)
    (define-key map (kbd "RET") #'vui-activate)
    (define-key map (kbd "p") #'rsync-ui-preview)
    (define-key map (kbd "s") #'rsync-ui-start)
    (define-key map (kbd "x") #'rsync-ui-cancel)
    (define-key map (kbd "r") #'rsync-ui-reset)
    (define-key map (kbd "o") #'rsync-ui-choose-source)
    (define-key map (kbd "d") #'rsync-ui-choose-target)
    (define-key map (kbd "q") #'quit-window)
    map))

(define-derived-mode rsync-ui-mode vui-mode "Rsync"
  (setq-local header-line-format nil)
  (setq-local mode-line-format nil)
  (setq-local truncate-lines t)
  (setq-local cursor-type 'box))

(with-eval-after-load 'evil
  (evil-set-initial-state 'rsync-ui-mode 'normal)
  (evil-define-key* '(normal motion) rsync-ui-mode-map
    (kbd "j") #'rsync-ui-next-widget
    (kbd "k") #'rsync-ui-previous-widget
    (kbd "RET") #'vui-activate
    (kbd "p") #'rsync-ui-preview
    (kbd "s") #'rsync-ui-start
    (kbd "x") #'rsync-ui-cancel
    (kbd "r") #'rsync-ui-reset
    (kbd "o") #'rsync-ui-choose-source
    (kbd "d") #'rsync-ui-choose-target
    (kbd "q") #'quit-window))

(defun rsync-ui--open (sources target)
  (let ((buffer (get-buffer-create rsync-ui-buffer-name)))
    (if (and (buffer-local-value 'rsync-ui--process buffer)
             (process-live-p (buffer-local-value 'rsync-ui--process buffer)))
        (pop-to-buffer buffer)
      (with-current-buffer buffer
        (when (vui-get-instance buffer)
          (vui-unmount buffer))
        (rsync-ui-mode)
        (vui-mount (vui-component 'rsync-ui-app
                     :initial-sources sources
                     :initial-target target)
                   buffer)
        (vui-rerender-on-resize))
      (pop-to-buffer buffer))))

;;;###autoload
(defun rsync-ui (&optional source target)
  (interactive)
  (rsync-ui--open (and source (list source)) target))

;;;###autoload
(defun rsync-ui-dired ()
  (interactive)
  (rsync-ui--open (dired-get-marked-files) nil))

(provide 'rsync-ui)
