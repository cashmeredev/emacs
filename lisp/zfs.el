;;; zfs.el --- ZFS management UI -*- lexical-binding: t; -*-

(require 'vui)
(require 'vui-components)
(require 'async)
(require 'zfs-cli)

(defcustom zfs-buffer-name "*zfs*"
  "Name of the ZFS management buffer."
  :type 'string
  :group 'zfs)

(defcustom zfs-targets-file (locate-user-emacs-file "zfs-targets.eld")
  "File where backup targets are stored as a plain elisp list."
  :type 'file
  :group 'zfs)

(defcustom zfs-backup-targets nil
  "Seed backup targets, used when `zfs-targets-file' does not exist yet.
Same plist shape as documented there."
  :type '(repeat sexp)
  :group 'zfs)

(defvar-local zfs-ui--row-actions nil)
(defvar-local zfs-ui--refresh-fn nil)

(defun zfs-ui--targets-load ()
  (if (file-exists-p zfs-targets-file)
      (with-temp-buffer
        (insert-file-contents zfs-targets-file)
        (goto-char (point-min))
        (read (current-buffer)))
    zfs-backup-targets))

(defun zfs-ui--targets-save (targets)
  (with-temp-file zfs-targets-file
    (pp targets (current-buffer))))

(defun zfs--format-bytes (bytes)
  (cond
   ((null bytes) "-")
   ((not (numberp bytes)) (format "%s" bytes))
   (t (let ((units '((1099511627776 . "T") (1073741824 . "G") (1048576 . "M") (1024 . "K")))
            (result nil))
        (dolist (unit units)
          (when (and (not result) (>= bytes (car unit)))
            (let ((value (/ bytes (float (car unit)))))
              (setq result (if (< value 10) (format "%.1f%s" value (cdr unit))
                             (format "%.0f%s" value (cdr unit)))))))
        (or result (format "%dB" bytes))))))

(defun zfs--format-ago (epoch)
  (if (not (numberp epoch))
      "-"
    (let ((delta (- (float-time) epoch)))
      (cond
       ((< delta 90) "just now")
       ((< delta 3600) (format "%dm ago" (truncate (/ delta 60))))
       ((< delta 86400) (format "%dh ago" (truncate (/ delta 3600))))
       ((< delta (* 30 86400)) (format "%dd ago" (truncate (/ delta 86400))))
       ((< delta (* 365 86400)) (format "%dmo ago" (truncate (/ delta (* 30 86400)))))
       (t (format "%dy ago" (truncate (/ delta (* 365 86400)))))))))

(defun zfs--gauge (percent &optional width)
  (let* ((width (or width 20))
         (done (max 0 (min width (round (* width (/ (or percent 0) 100.0)))))))
    (concat (make-string done ?█) (make-string (- width done) ?░))))

(defun zfs--health-face (health)
  (pcase health
    ("ONLINE" 'success)
    ("DEGRADED" 'warning)
    (_ 'error)))

(defun zfs--capacity-face (percent)
  (cond
   ((>= (or percent 0) 90) 'error)
   ((>= (or percent 0) 75) 'warning)
   (t 'success)))

(defun zfs--direct-children (datasets parent)
  (let ((prefix (concat parent "/")))
    (seq-filter (lambda (entry)
                  (and (string-prefix-p prefix (car entry))
                       (not (string-match-p "/" (substring (car entry) (length prefix))))))
                datasets)))

(defun zfs--snapshots-of (snaps dataset)
  (seq-filter (lambda (entry)
                (string-prefix-p (concat dataset "@") (car entry)))
              snaps))

(defun zfs--snapshot-leaf (full-name)
  (car (last (split-string full-name "@" t))))

(defun zfs-ui--fetch (host include-disks callback)
  (let ((cli-dir (file-name-directory (locate-library "zfs-cli.el"))))
    (async-start
     `(lambda ()
        (add-to-list 'load-path ,cli-dir)
        (require 'zfs-cli)
        (list :pools (condition-case err (zfs-cli-pools ',host)
                       (error (cons :error (error-message-string err))))
              :datasets (condition-case err (zfs-cli-datasets ',host)
                          (error (cons :error (error-message-string err))))
              :snaps (condition-case err (zfs-cli-snapshots ',host)
                       (error (cons :error (error-message-string err))))
              :locked ,(if include-disks
                           '(condition-case err
                                (mapcar (lambda (device)
                                          (append device
                                                  (list :pool (and (zfs-cli-disk-unlocked-p device)
                                                                   (zfs-cli-pool-on-device
                                                                    (concat "/dev/mapper/" (zfs-cli-disk-mapper device)))))))
                                        (zfs-cli-locked-disks))
                              (error (cons :error (error-message-string err))))
                         nil)))
     callback)))

(defun zfs-ui--fetch-done (result)
  (let ((pools (plist-get result :pools))
        (datasets (plist-get result :datasets))
        (snaps (plist-get result :snaps))
        (locked (plist-get result :locked)))
    (vui-batch
     (vui-set-state :loading nil)
     (vui-set-state :refreshed (format-time-string "%H:%M"))
     (if (and (eq (car-safe pools) :error) (eq (car-safe datasets) :error))
         (vui-set-state :message (cons (format "Could not reach host: %s" (cdr pools)) 'error))
       (vui-set-state :pools (and (not (eq (car-safe pools) :error)) pools))
       (vui-set-state :datasets (and (not (eq (car-safe datasets) :error)) datasets))
       (vui-set-state :snaps (and (not (eq (car-safe snaps) :error)) snaps))
       (vui-set-state :locked (and (listp locked) (not (eq (car-safe locked) :error)) locked))))))

(defun zfs-ui--refresh (host)
  (vui-set-state :loading t)
  (zfs-ui--fetch host (null host) (vui-async-callback (result) (zfs-ui--fetch-done result))))

(defun zfs-ui--go (page &optional arg)
  (vui-batch
   (vui-set-state :page page)
   (vui-set-state :page-arg arg)
   (vui-set-state :backup-target nil)
   (vui-set-state :backup-preview nil)
   (vui-set-state :backup-progress nil)
   (vui-set-state :backup-done nil)
   (vui-set-state :create-status nil)
   (vui-set-state :format-disk nil)
   (vui-set-state :format-status nil)))

(defun zfs-ui--fail (err)
  (vui-set-state :message (cons (format "Error: %s" (error-message-string err)) 'error)))

(defun zfs-ui--do-snapshot (host dataset)
  (let ((snap-name (read-string (format "Snapshot name for %s: " dataset)
                                (format-time-string "manual-%Y-%m-%d_%H-%M"))))
    (condition-case err
        (progn
          (zfs-cli-snapshot host dataset snap-name)
          (vui-set-state :message (cons (format "Snapshot %s@%s created" dataset snap-name) 'success))
          (zfs-ui--refresh host))
      (error (zfs-ui--fail err)))))

(defun zfs-ui--do-destroy (host target has-dependents)
  (when (yes-or-no-p (if has-dependents
                         (format "Destroy %s including its children and snapshots? " target)
                       (format "Destroy %s? " target)))
    (condition-case err
        (progn
          (zfs-cli-destroy host target has-dependents)
          (vui-set-state :message (cons (format "Destroyed %s" target) 'success))
          (zfs-ui--refresh host))
      (error (zfs-ui--fail err)))))

(defun zfs-ui--do-rollback (host snapshot)
  (when (yes-or-no-p (format "Roll back to %s? Snapshots taken after it are destroyed. " snapshot))
    (condition-case err
        (progn
          (zfs-cli-rollback host snapshot)
          (vui-set-state :message (cons (format "Rolled back to %s" snapshot) 'success))
          (zfs-ui--refresh host))
      (error (zfs-ui--fail err)))))

(defun zfs-ui--do-mount (host dataset)
  (condition-case err
      (progn
        (zfs-cli-mount host dataset)
        (vui-set-state :message (cons (format "Mounted %s" dataset) 'success))
        (zfs-ui--refresh host))
    (error (zfs-ui--fail err))))

(defun zfs-ui--do-diff (host snapshot)
  (let ((command (if host
                     (format "ssh -o BatchMode=yes %s %s"
                             (shell-quote-argument (plist-get host :ssh))
                             (shell-quote-argument (concat "doas -n zfs diff -H " snapshot)))
                   (format "doas -n zfs diff -H %s" snapshot))))
    (if (fboundp 'ghostel-compile)
        (ghostel-compile command)
      (compile command))))

(defun zfs-ui--do-scrub (host pool stop)
  (condition-case err
      (progn
        (zfs-cli-scrub host pool stop)
        (vui-set-state :message (cons (if stop "Scrub stopped" "Scrub started — reads all data, verifies checksums")
                                      'success))
        (zfs-ui--refresh host))
    (error (zfs-ui--fail err))))

(defun zfs-ui--do-export (host pool)
  (when (yes-or-no-p (format "Export %s? The pool goes offline until imported again. " pool))
    (condition-case err
        (progn
          (zfs-cli-export host pool)
          (vui-set-state :message (cons (format "Exported %s" pool) 'success))
          (zfs-ui--go 'overview)
          (zfs-ui--refresh host))
      (error (zfs-ui--fail err)))))

(defun zfs-ui--do-unlock (device)
  (let ((passphrase (read-passwd (format "LUKS passphrase for %s: " (plist-get device :name)))))
    (condition-case err
        (let ((mapper (concat "luks-" (plist-get device :name))))
          (zfs-cli-luks-open (plist-get device :path) mapper passphrase)
          (let ((pool (zfs-cli-pool-on-device (concat "/dev/mapper/" mapper))))
            (if pool
                (progn
                  (zfs-cli-import nil pool t)
                  (vui-set-state :message (cons (format "Unlocked — pool %s imported" pool) 'success)))
              (vui-set-state :message (cons "Unlocked, but no ZFS pool found on the device" 'warning))))
          (zfs-ui--refresh nil))
      (error (zfs-ui--fail err)))))

(defun zfs-ui--do-import (device)
  (condition-case err
      (let ((pool (zfs-cli-pool-on-device (concat "/dev/mapper/" (zfs-cli-disk-mapper device)))))
        (if pool
            (progn
              (zfs-cli-import nil pool t)
              (vui-set-state :message (cons (format "Imported %s" pool) 'success))
              (zfs-ui--refresh nil))
          (vui-set-state :message (cons "No ZFS pool found on the device" 'warning))))
    (error (zfs-ui--fail err))))

(defun zfs-ui--do-lock (device pools)
  (let* ((mapper (zfs-cli-disk-mapper device))
         (pool (zfs-cli-pool-on-device (concat "/dev/mapper/" mapper))))
    (when (yes-or-no-p (if (and pool (assoc pool pools))
                           (format "Export %s and lock %s? " pool (plist-get device :name))
                         (format "Lock %s? " (plist-get device :name))))
      (condition-case err
          (progn
            (when (and pool (assoc pool pools))
              (zfs-cli-export nil pool))
            (zfs-cli-luks-close mapper)
            (vui-set-state :message (cons (format "Locked %s" (plist-get device :name)) 'success))
            (zfs-ui--refresh nil))
        (error (zfs-ui--fail err))))))

(defun zfs-ui--common-base (snaps target-snap-names dataset)
  (let* ((own (zfs--snapshots-of snaps dataset))
         (common (seq-filter (lambda (entry)
                               (member (zfs--snapshot-leaf (car entry)) target-snap-names))
                             own))
         (sorted (sort (copy-sequence common)
                       (lambda (a b) (< (or (zfs-cli-prop a 'creation) 0)
                                        (or (zfs-cli-prop b 'creation) 0))))))
    (when sorted
      (car (car (last sorted))))))

(defun zfs-ui--newest-snapshot (snaps dataset)
  (let ((sorted (sort (copy-sequence (zfs--snapshots-of snaps dataset))
                      (lambda (a b) (< (or (zfs-cli-prop a 'creation) 0)
                                       (or (zfs-cli-prop b 'creation) 0))))))
    (car (last sorted))))

(defun zfs-ui--backup-preview (host dataset snapshot snaps entry target)
  (let* ((leaf (file-name-nondirectory dataset))
         (target-dataset (concat (plist-get target :dataset) "/" leaf))
         (target-snap-names (condition-case nil
                                (mapcar (lambda (snap-entry) (zfs--snapshot-leaf (car snap-entry)))
                                        (zfs-cli-snapshots target target-dataset))
                              (error nil)))
         (base (zfs-ui--common-base snaps target-snap-names dataset))
         (raw (and entry (not (member (zfs-cli-prop entry 'encryption) '(nil "off")))))
         (preview (zfs-cli-send-preview host snapshot base)))
    (list :target-dataset target-dataset
          :base base
          :raw raw
          :kind (plist-get preview :kind)
          :bytes (plist-get preview :bytes))))

(defun zfs-ui--backup-event (event)
  (pcase (car event)
    (:progress
     (vui-set-state :backup-progress (nth 1 event)))
    (:done
     (if (zerop (nth 1 event))
         (vui-batch
          (vui-set-state :backup-done 'success)
          (vui-set-state :backup-progress nil))
       (vui-batch
        (vui-set-state :backup-done (format "%s" (nth 2 event)))
        (vui-set-state :backup-progress nil))))))

(defun zfs-ui--start-backup (host snapshot target preview)
  (vui-batch
   (vui-set-state :backup-progress "starting…")
   (vui-set-state :backup-done nil))
  (zfs-cli-send-async host snapshot target (plist-get preview :target-dataset)
                      (plist-get preview :base) (plist-get preview :raw)
                      (vui-async-callback (event)
                        (zfs-ui--backup-event event))))

(defun zfs-ui--field-string (key)
  (or (vui-field-value key) ""))

(defun zfs-ui--start-move (host dataset mountpoint move-dir)
  (vui-set-state :create-status (cons "Copying… 0%" 'shadow))
  (zfs-cli-rsync-async
   move-dir mountpoint
   (vui-async-callback (event)
     (pcase (car event)
       (:progress
        (when (string-match "\\([0-9]+%\\)" (nth 1 event))
          (vui-set-state :create-status
                         (cons (format "Copying… %s" (match-string 1 (nth 1 event))) 'shadow))))
       (:done
        (if (zerop (nth 1 event))
            (vui-set-state :message
                           (cons (format "%s created, data copied — original kept in %s" dataset move-dir)
                                 'success))
          (vui-set-state :message
                         (cons (format "%s created, but copying failed: %s" dataset (nth 2 event))
                               'error)))
        (zfs-ui--go 'dataset dataset)
        (zfs-ui--refresh host))))))

(defun zfs-ui--do-create-dataset (host parent)
  (let* ((leaf (zfs-ui--field-string "create-name"))
         (mountpoint (zfs-ui--field-string "create-mountpoint"))
         (quota (zfs-ui--field-string "create-quota"))
         (passphrase (zfs-ui--field-string "create-passphrase"))
         (encrypted (not (string-blank-p passphrase)))
         (compression (zfs-ui--field-string "create-compression"))
         (move-dir (zfs-ui--field-string "create-move"))
         (dataset (concat parent "/" leaf)))
    (cond
     ((string-blank-p leaf)
      (vui-set-state :create-status (cons "Name is empty" 'error)))
     ((string-match-p "/" leaf)
      (vui-set-state :create-status (cons "Name must be a single segment, no slashes" 'error)))
     ((and (not (string-blank-p move-dir)) (string-blank-p mountpoint))
      (vui-set-state :create-status (cons "Moving a folder in needs a mountpoint" 'error)))
     (t
      (let ((properties nil))
        (when (and compression (not (equal compression "inherit")))
          (push (cons "compression" compression) properties))
        (when (and mountpoint (not (string-blank-p mountpoint)) (not (equal mountpoint "none")))
          (push (cons "mountpoint" mountpoint) properties))
        (when (and quota (not (string-blank-p quota)))
          (push (cons "quota" quota) properties))
        (condition-case err
            (progn
              (if encrypted
                  (zfs-cli-create-encrypted host dataset passphrase properties)
                (zfs-cli-create host dataset properties))
              (when (and (not (string-blank-p mountpoint)) (not (equal mountpoint "none")))
                (ignore-errors (zfs-cli-mount host dataset)))
              (if (not (string-blank-p move-dir))
                  (zfs-ui--start-move host dataset mountpoint move-dir)
                (vui-set-state :message (cons (format "Created %s" dataset) 'success))
                (zfs-ui--go 'dataset dataset)
                (zfs-ui--refresh host)))
          (error (vui-set-state :create-status (cons (error-message-string err) 'error)))))))))

(defun zfs-ui--do-format (device pool-name encrypted passphrase)
  (let ((mapper (concat "luks-" (plist-get device :name))))
    (vui-set-state :format-status (cons "Formatting… this takes a moment" 'shadow))
    (zfs-cli-format-disk-async
     (plist-get device :path) pool-name mapper (and encrypted passphrase)
     (vui-async-callback (status err)
       (if (zerop status)
           (vui-batch
            (vui-set-state :format-status (cons (format "Pool %s created on %s" pool-name (plist-get device :name))
                                                'success))
            (vui-set-state :format-disk nil)
            (zfs-ui--refresh nil))
         (vui-set-state :format-status (cons (format "Format failed: %s" err) 'error)))))))

(defconst zfs-ui--property-glossary
  '(("used" . "live data + snapshots + children together")
    ("referenced" . "live data right now, snapshots excluded")
    ("usedbysnapshots" . "only reachable through snapshots; freed when you delete them")
    ("usedbychildren" . "used by datasets below this one")
    ("available" . "room this dataset can still grow into")
    ("compressratio" . "how much smaller data is stored; 1.31x ≈ 24% saved")
    ("encryption" . "dataset-level encryption, independent of disk LUKS")
    ("keystatus" . "available = key loaded, data readable")
    ("mountpoint" . "where it shows up; legacy = mounted by the system, not zfs")
    ("recordsize" . "max block size; matters for databases and VM images")
    ("quota" . "hard size limit, if set")
    ("reservation" . "space guaranteed to this dataset, if set")
    ("creation" . "when the dataset was created")
    ("mounted" . "whether it is currently mounted")))

(defun zfs-ui--dataset-row (entry depth snap-count)
  (let* ((name (car entry))
         (short (file-name-nondirectory name))
         (label (concat (make-string (* 2 depth) ?\s)
                        (if (> snap-count 0) "▸ " "  ")
                        short
                        (when (> snap-count 0) (format " (%d)" snap-count))))
         (encryption (zfs-cli-prop entry 'encryption))
         (keystatus (zfs-cli-prop entry 'keystatus)))
    (vui-hstack
     (vui-box (vui-button (truncate-string-to-width label 32) :no-decoration t
                          :key (concat "ds:" name)
                          :on-click (lambda () (zfs-ui--go 'dataset name)))
              :width 34)
     (vui-box (vui-text (zfs--format-bytes (zfs-cli-prop entry 'used))) :width 9)
     (vui-box (vui-text (zfs--format-bytes (zfs-cli-prop entry 'available)) :face 'shadow) :width 9)
     (vui-box (vui-text (format "%s" (or (zfs-cli-prop entry 'compressratio) "-")) :face 'shadow) :width 7)
     (vui-box (cond
               ((or (null encryption) (equal encryption "off")) (vui-text "·" :face 'shadow))
               ((equal keystatus "available") (vui-text "🔓" :face 'success))
               (t (vui-text "🔒" :face 'warning)))
              :width 4))))

(defun zfs-ui--dataset-rows (entry depth datasets snaps)
  (let* ((name (car entry))
         (children (zfs--direct-children datasets name))
         (own-snaps (zfs--snapshots-of snaps name)))
    (push (cons (concat "ds:" name)
                (list :open (vui-with-async-context (zfs-ui--go 'dataset name))
                      :backup (vui-with-async-context (zfs-ui--go 'backup name))
                      :create-child (vui-with-async-context (zfs-ui--go 'create name))))
          zfs-ui--row-actions)
    (cons (zfs-ui--dataset-row entry depth (length own-snaps))
          (mapcan (lambda (child) (zfs-ui--dataset-rows child (1+ depth) datasets snaps))
                  children))))

(defun zfs-ui--pool-row (pool)
  (let* ((name (car pool))
         (health (zfs-cli-prop pool 'health))
         (capacity (zfs-cli-prop pool 'capacity))
         (size (zfs-cli-prop pool 'size))
         (free (zfs-cli-prop pool 'free)))
    (push (cons (concat "pool:" name)
                (list :open (vui-with-async-context (zfs-ui--go 'pool name))
                      :create-child (vui-with-async-context (zfs-ui--go 'create name))))
          zfs-ui--row-actions)
    (vui-hstack
     :spacing 1
     (vui-box (vui-button name :no-decoration t
                          :key (concat "pool:" name)
                          :on-click (lambda () (zfs-ui--go 'pool name)))
              :width 10)
     (vui-box (vui-text (or health "?") :face (zfs--health-face health)) :width 9)
     (vui-box (vui-text (zfs--gauge capacity)
                        :face (zfs--capacity-face capacity))
              :width 22)
     (vui-text (format "%d%% · %s free of %s"
                       (or capacity 0)
                       (zfs--format-bytes free)
                       (zfs--format-bytes size))
               :face 'shadow))))

(defun zfs-ui--locked-disk-row (device pools)
  (let* ((name (plist-get device :name))
         (unlocked (zfs-cli-disk-unlocked-p device))
         (mapper (zfs-cli-disk-mapper device))
         (pool (plist-get device :pool))
         (imported (and pool (assoc pool pools))))
    (push (cons (concat "lock:" name)
                (if unlocked
                    (append (unless imported
                              (list :import (vui-with-async-context (zfs-ui--do-import device))))
                            (list :lock (vui-with-async-context (zfs-ui--do-lock device pools))))
                  (list :unlock (vui-with-async-context (zfs-ui--do-unlock device)))))
          zfs-ui--row-actions)
    (vui-hstack
     :spacing 1
     (vui-box (vui-text (if unlocked "🔓" "🔒") :face (if unlocked 'warning 'shadow)) :width 3)
     (vui-box (vui-button name :no-decoration t
                          :key (concat "lock:" name)
                          :on-click (lambda () nil))
              :width 10)
     (vui-box (vui-text (or (plist-get device :model) "?") :face 'shadow) :width 24)
     (vui-box (vui-text (zfs--format-bytes (plist-get device :size)) :face 'shadow) :width 8)
     (vui-text (cond
                (imported (format "pool %s imported · L ejects and locks" pool))
                (unlocked (format "unlocked as %s · i imports pool %s · L locks" mapper (or pool "?")))
                (t "locked · u unlock"))
               :face 'shadow))))

(defun zfs-ui--page-overview (pools datasets snaps locked)
  (push (cons 'page
              (list :format (vui-with-async-context (zfs-ui--go 'new-pool))
                    :targets (vui-with-async-context (zfs-ui--go 'targets))))
        zfs-ui--row-actions)
  (let ((roots (seq-filter (lambda (entry) (not (string-match-p "/" (car entry)))) datasets)))
    (apply
     #'vui-vstack
     :spacing 1
     (append
      (when locked
        (list (vui-vstack
               :spacing 0
               (vui-heading-3 "Disks")
               (vui-muted "LUKS disks ZFS can use once unlocked")
               (apply #'vui-vstack :spacing 0
                      (mapcar (lambda (device) (zfs-ui--locked-disk-row device pools)) locked)))))
      (list
       (vui-vstack
        :spacing 0
        (vui-heading-3 "Pools")
        (vui-muted "teams of disks; datasets live inside them · RET details · F format a disk")
        (apply #'vui-vstack :spacing 0 (mapcar #'zfs-ui--pool-row pools)))
       (vui-vstack
        :spacing 0
        (vui-heading-3 "Datasets")
        (vui-muted "named drawers · RET details · b backup · c new dataset inside")
        (vui-hstack
         (vui-box (vui-text "NAME" :face 'shadow) :width 34)
         (vui-box (vui-text "USED" :face 'shadow) :width 9)
         (vui-box (vui-text "AVAIL" :face 'shadow) :width 9)
         (vui-box (vui-text "RATIO" :face 'shadow) :width 7)
         (vui-box (vui-text "ENC" :face 'shadow) :width 4))
        (apply #'vui-vstack :spacing 0
               (mapcan (lambda (root) (zfs-ui--dataset-rows root 0 datasets snaps)) roots))))))))

(defun zfs-ui--property-row (entry property)
  (let* ((raw (zfs-cli-prop entry (intern property)))
         (value (cond
                 ((equal property "creation") (format "%s (%s)"
                                                     (format-time-string "%Y-%m-%d" raw)
                                                     (zfs--format-ago raw)))
                 ((and (member property '("quota" "reservation")) (or (null raw) (equal raw 0))) "none")
                 ((numberp raw) (zfs--format-bytes raw))
                 (t (format "%s" (or raw "-")))))
         (gloss (cdr (assoc property zfs-ui--property-glossary))))
    (vui-hstack
     (vui-box (vui-text property :face 'shadow) :width 18)
     (vui-box (vui-text value) :width 22)
     (vui-text (or gloss "") :face 'shadow))))

(defun zfs-ui--snapshot-row (snap dataset host)
  (let* ((full-name (car snap))
         (leaf (zfs--snapshot-leaf full-name)))
    (push (cons (concat "snap:" full-name)
                (list :diff (vui-with-async-context (zfs-ui--do-diff host full-name))
                      :rollback (vui-with-async-context (zfs-ui--do-rollback host full-name))
                      :backup (vui-with-async-context (zfs-ui--go 'backup (cons dataset full-name)))
                      :destroy (vui-with-async-context (zfs-ui--do-destroy host full-name nil))))
          zfs-ui--row-actions)
    (vui-hstack
     (vui-box (vui-button (concat "@" leaf) :no-decoration t :face 'shadow
                          :key (concat "snap:" full-name)
                          :on-click (lambda () nil))
              :width 38)
     (vui-box (vui-text (zfs--format-bytes (zfs-cli-prop snap 'used)) :face 'shadow) :width 9)
     (vui-text (zfs--format-ago (zfs-cli-prop snap 'creation)) :face 'shadow))))

(defun zfs-ui--page-dataset (name host datasets snaps)
  (let* ((entry (assoc name datasets))
         (own-snaps (zfs--snapshots-of snaps name)))
    (when entry
      (push (cons 'page
                  (list :snapshot (vui-with-async-context (zfs-ui--do-snapshot host name))
                        :backup (vui-with-async-context (zfs-ui--go 'backup name))
                        :create-child (vui-with-async-context (zfs-ui--go 'create name))
                        :destroy (vui-with-async-context (zfs-ui--do-destroy host name t))
                        :mount (vui-with-async-context (zfs-ui--do-mount host name))))
            zfs-ui--row-actions))
    (if (null entry)
        (vui-text (format "%s not found — g to refresh" name) :face 'error)
      (apply
       #'vui-vstack
       :spacing 1
       (append
        (list
         (vui-hstack :spacing 2
                     (vui-heading-3 name)
                     (vui-text (downcase (or (alist-get 'type (cdr entry)) "")) :face 'shadow))
         (vui-muted (format "Everything in this dataset and its snapshots uses %s."
                            (zfs--format-bytes (zfs-cli-prop entry 'used))))
         (vui-text "s snapshot · b backup · c new dataset inside · m mount · D destroy" :face 'shadow)
         (apply #'vui-vstack :spacing 0
                (mapcar (lambda (property) (zfs-ui--property-row entry property))
                        '("used" "referenced" "usedbysnapshots" "usedbychildren" "available"
                          "compressratio" "encryption" "keystatus" "mountpoint" "recordsize"
                          "quota" "creation" "mounted"))))
        (list
         (apply
          #'vui-vstack
          :spacing 0
          (append
           (list (vui-heading-3 (format "Snapshots (%d)" (length own-snaps)))
                 (vui-muted "frozen moments · d what changed since · r roll back to · D delete"))
           (if own-snaps
               (mapcar (lambda (snap) (zfs-ui--snapshot-row snap name host)) own-snaps)
             (list (vui-muted "none yet — press s to freeze this moment")))))))))))

(defun zfs-ui--vdev-row (vdev depth)
  (vui-hstack
   (vui-box (vui-text (concat (make-string (* 2 depth) ?\s) (plist-get vdev :name))) :width 40)
   (vui-box (vui-text (or (plist-get vdev :state) "?")
                      :face (zfs--health-face (plist-get vdev :state)))
            :width 9)
   (vui-text (format "%s/%s/%s errors"
                     (or (plist-get vdev :read-errors) 0)
                     (or (plist-get vdev :write-errors) 0)
                     (or (plist-get vdev :checksum-errors) 0))
             :face 'shadow)))

(defun zfs-ui--page-pool (name host)
  (let ((status (ignore-errors (zfs-cli-pool-status host name))))
    (when status
      (push (cons 'page
                  (list :scrub-start (vui-with-async-context (zfs-ui--do-scrub host name nil))
                        :scrub-stop (vui-with-async-context (zfs-ui--do-scrub host name t))
                        :export (vui-with-async-context (zfs-ui--do-export host name))))
            zfs-ui--row-actions))
    (if (null status)
        (vui-text (format "Could not read status of %s" name) :face 'error)
      (let ((state (alist-get 'state status))
            (error-count (alist-get 'error_count status))
            (scan (alist-get 'scan status))
            (vdevs (zfs-cli-pool-vdevs status)))
        (vui-vstack
         :spacing 1
         (vui-hstack :spacing 2
                     (vui-heading-3 name)
                     (vui-text state :face (zfs--health-face state)))
         (vui-muted (if (> (or error-count 0) 0)
                        (format "%d errors — check the devices below" error-count)
                      "No known data errors."))
         (vui-text (if scan
                       (format "Scan: %s" (or (alist-get 'state scan) "recorded"))
                     "Scrub: never run here — it reads everything and verifies checksums")
                   :face 'shadow)
         (vui-text "1 scrub start · 2 scrub stop · x export (take offline)" :face 'shadow)
         (vui-vstack
          :spacing 0
          (vui-heading-3 "Devices")
          (apply #'vui-vstack :spacing 0
                 (mapcar (lambda (vdev) (zfs-ui--vdev-row vdev 0)) vdevs))))))))

(defun zfs-ui--form-row (label content &optional gloss)
  (vui-hstack
   (vui-box (vui-text label :face 'shadow) :width 14 :align :right)
   content
   (when gloss (vui-hstack (vui-space 2) (vui-text gloss :face 'shadow)))))

(defun zfs-ui--page-create (parent host create-status)
  (push (cons 'page (list :submit (vui-with-async-context (zfs-ui--do-create-dataset host parent))))
        zfs-ui--row-actions)
  (vui-vstack
   :spacing 1
   (vui-heading-3 (format "New dataset inside %s" parent))
   (vui-muted "A dataset is a drawer: its own compression, quota and snapshots.")
   (zfs-ui--form-row "Name"
                     (vui-field :size 24 :key "create-name" :placeholder "music")
                     (format "→ %s/<name>" parent))
   (zfs-ui--form-row "Mountpoint"
                     (vui-field :size 24 :key "create-mountpoint"
                                :placeholder (expand-file-name "~/music"))
                     "where it appears; empty = not mounted")
   (zfs-ui--form-row "Compression"
                     (vui-field :size 24 :key "create-compression" :value "zstd"
                                :placeholder "zstd")
                     "zstd squeezes better, lz4 is faster, off disables")
   (zfs-ui--form-row "Passphrase"
                     (vui-field :size 24 :key "create-passphrase" :secret t
                                :placeholder "empty = not encrypted")
                     "dataset-level, on top of disk LUKS")
   (zfs-ui--form-row "Quota"
                     (vui-field :size 24 :key "create-quota" :placeholder "empty = no limit")
                     "e.g. 50G")
   (zfs-ui--form-row "Move folder in"
                     (vui-field :size 24 :key "create-move"
                                :placeholder "empty = start empty")
                     "rsync copy with progress; original is kept")
   (vui-hstack
    (vui-box (vui-text "") :width 14)
    (vui-button "Create dataset" :on-click (lambda () (zfs-ui--do-create-dataset host parent))))
   (when create-status
     (vui-text (car create-status) :face (cdr create-status)))))

(defun zfs-ui--page-backup (arg host datasets snaps targets backup-target backup-preview backup-progress backup-done)
  (let* ((dataset (if (consp arg) (car arg) arg))
         (snapshot (if (consp arg) (cdr arg)
                     (car (zfs-ui--newest-snapshot snaps dataset))))
         (entry (assoc dataset datasets)))
    (if (null snapshot)
        (vui-vstack
         :spacing 1
         (vui-heading-3 (format "Backup %s" dataset))
         (vui-text "No snapshots yet — a backup sends a snapshot." :face 'warning)
         (vui-button "Create one now"
                     :on-click (lambda () (zfs-ui--do-snapshot host dataset))))
      (vui-vstack
       :spacing 1
       (vui-heading-3 (format "Backup %s" dataset))
       (vui-muted "Sends a snapshot to another machine or pool. After the first full copy only the changes travel.")
       (vui-hstack
        (vui-box (vui-text "Snapshot" :face 'shadow) :width 14 :align :right)
        (vui-text (concat "@" (zfs--snapshot-leaf snapshot)))
        (vui-space 2)
        (vui-text (format "(%s)" (zfs--format-ago (zfs-cli-prop (assoc snapshot snaps) 'creation)))
                  :face 'shadow))
       (vui-vstack
        :spacing 0
        (vui-hstack (vui-box (vui-text "Target" :face 'shadow) :width 14 :align :right)
                    (vui-text ""))
        (apply
         #'vui-vstack
         :spacing 0
         (mapcar (lambda (target)
                   (vui-hstack
                    (vui-box (vui-text "") :width 14)
                    (vui-button (format "%s — %s %s"
                                        (plist-get target :name)
                                        (or (plist-get target :ssh) "this machine")
                                        (plist-get target :dataset))
                                :no-decoration (not (equal target backup-target))
                                :face (when (equal target backup-target) 'success)
                                :on-click
                                (lambda ()
                                  (vui-set-state :backup-target target)
                                  (condition-case err
                                      (vui-set-state :backup-preview
                                                     (zfs-ui--backup-preview host dataset snapshot snaps entry target))
                                    (error (vui-set-state :message
                                                          (cons (format "Preview failed: %s" (error-message-string err)) 'error))))))))
                 targets)))
       (vui-hstack
        (vui-box (vui-text "One-off" :face 'shadow) :width 14 :align :right)
        (vui-field :size 18 :key "oneoff-ssh" :placeholder "user@host — empty = local")
        (vui-space 1)
        (vui-field :size 18 :key "oneoff-prefix" :placeholder "pool/prefix")
        (vui-space 1)
        (vui-button "Use once"
                    :on-click
                    (lambda ()
                      (let ((prefix (zfs-ui--field-string "oneoff-prefix")))
                        (if (string-blank-p prefix)
                            (vui-set-state :message (cons "One-off target needs a dataset prefix" 'error))
                          (let ((target (list :name "one-off" :dataset prefix))
                                (ssh (zfs-ui--field-string "oneoff-ssh")))
                            (unless (string-blank-p ssh)
                              (setq target (append target (list :ssh ssh))))
                            (vui-set-state :backup-target target)
                            (condition-case err
                                (vui-set-state :backup-preview
                                               (zfs-ui--backup-preview host dataset snapshot snaps entry target))
                              (error (vui-set-state :message
                                                    (cons (format "Preview failed: %s" (error-message-string err)) 'error))))))))))
       (when backup-target
         (vui-hstack
          (vui-box (vui-text "Will send" :face 'shadow) :width 14 :align :right)
          (if backup-preview
              (vui-text (format "%s · %s%s"
                                (if (equal (plist-get backup-preview :kind) "incremental")
                                    (format "only changes since @%s" (zfs--snapshot-leaf (plist-get backup-preview :base)))
                                  "everything (first time)")
                                (zfs--format-bytes (plist-get backup-preview :bytes))
                                (if (plist-get backup-preview :raw) " · stays encrypted" "")))
            (vui-text "…" :face 'shadow))))
       (when (and backup-target backup-preview (not backup-progress) (not backup-done))
         (vui-hstack
          (vui-box (vui-text "") :width 14)
          (vui-button "Start backup"
                      :on-click (lambda () (zfs-ui--start-backup host snapshot backup-target backup-preview)))))
       (when backup-progress
         (vui-hstack
          (vui-box (vui-text "Sending" :face 'shadow) :width 14 :align :right)
          (vui-text backup-progress :face 'shadow)))
       (when backup-done
         (vui-hstack
          (vui-box (vui-text "") :width 14)
          (if (eq backup-done 'success)
              (vui-text "Backup complete." :face 'success)
            (vui-text (format "Backup failed: %s" backup-done) :face 'error))))))))

(defun zfs-ui--page-format (format-disk format-status)
  (if (null format-disk)
      (let ((candidates (zfs-cli-disk-candidates)))
        (vui-vstack
         :spacing 1
         (vui-heading-3 "Format a disk as ZFS")
         (vui-muted "Everything on the chosen disk is erased. Only unused disks are listed.")
         (if candidates
             (apply
              #'vui-vstack
              :spacing 0
              (mapcar (lambda (device)
                        (vui-button (format "%s — %s — %s"
                                            (plist-get device :name)
                                            (or (plist-get device :model) "?")
                                            (zfs--format-bytes (plist-get device :size)))
                                    :no-decoration t
                                    :on-click (lambda () (vui-set-state :format-disk device))))
                      candidates))
           (vui-muted "No unused disks found. Plug one in and press g."))))
    (vui-vstack
     :spacing 1
     (vui-heading-3 (format "Format %s" (plist-get format-disk :name)))
     (vui-text (format "%s · %s — all data on it is erased"
                       (or (plist-get format-disk :model) "?")
                       (zfs--format-bytes (plist-get format-disk :size)))
               :face 'warning)
     (zfs-ui--form-row "Pool name" (vui-field :size 24 :key "format-pool" :placeholder "tank"))
     (zfs-ui--form-row "Passphrase" (vui-field :size 24 :key "format-pass" :secret t
                                               :placeholder "empty = no encryption")
                       "LUKS passphrase; empty leaves the disk unencrypted")
     (zfs-ui--form-row "Type disk name" (vui-field :size 24 :key "format-confirm"
                                                   :placeholder (plist-get format-disk :name))
                       "confirms you picked the right disk")
     (vui-hstack
      (vui-box (vui-text "") :width 14)
      (vui-button "Format"
                  :face 'error
                  :on-click
                  (lambda ()
                    (let ((pool-name (zfs-ui--field-string "format-pool"))
                          (passphrase (zfs-ui--field-string "format-pass")))
                      (cond
                       ((string-blank-p pool-name)
                        (vui-set-state :format-status (cons "Pool name is empty" 'error)))
                       ((not (equal (zfs-ui--field-string "format-confirm") (plist-get format-disk :name)))
                        (vui-set-state :format-status (cons "Type the disk name to confirm" 'error)))
                       (t
                        (zfs-ui--do-format format-disk
                                           pool-name
                                           (not (string-blank-p passphrase))
                                           passphrase)))))))
     (when format-status
       (vui-text (car format-status) :face (cdr format-status))))))

(defun zfs-ui--page-targets (targets)
  (push (cons 'page
              (list :add (vui-with-async-context
                           (let ((name (zfs-ui--field-string "target-name"))
                                 (ssh (zfs-ui--field-string "target-ssh"))
                                 (prefix (zfs-ui--field-string "target-prefix")))
                             (if (or (string-blank-p name) (string-blank-p prefix))
                                 (vui-set-state :message (cons "Name and dataset prefix are required" 'error))
                               (let ((new (list :name name :dataset prefix)))
                                 (unless (string-blank-p ssh)
                                   (setq new (append new (list :ssh ssh))))
                                 (let ((updated (append targets (list new))))
                                   (zfs-ui--targets-save updated)
                                   (vui-set-state :targets updated)
                                   (vui-set-state :message (cons (format "Target %s saved to %s" name zfs-targets-file)
                                                                 'success)))))))))
        zfs-ui--row-actions)
  (apply
   #'vui-vstack
   :spacing 1
   (append
    (list
     (vui-heading-3 "Backup targets")
     (vui-muted (format "Stored as plain elisp data in %s — edit by hand or here." zfs-targets-file)))
    (if targets
        (list (apply
               #'vui-vstack
               :spacing 0
               (mapcar (lambda (target)
                         (vui-hstack
                          :spacing 2
                          (vui-box (vui-text (plist-get target :name)) :width 16)
                          (vui-box (vui-text (or (plist-get target :ssh) "this machine") :face 'shadow) :width 24)
                          (vui-box (vui-text (plist-get target :dataset) :face 'shadow) :width 28)
                          (vui-button "Delete" :face 'error
                                      :on-click
                                      (lambda ()
                                        (when (yes-or-no-p (format "Delete target %s? " (plist-get target :name)))
                                          (let ((updated (seq-remove (lambda (other) (equal other target)) targets)))
                                            (zfs-ui--targets-save updated)
                                            (vui-set-state :targets updated)
                                            (vui-set-state :message (cons "Target deleted" 'success))))))))
                       targets)))
      (list (vui-muted "No targets yet — add one below.")))
    (list
     (vui-vstack
      :spacing 1
      (vui-heading-3 "Add target")
      (zfs-ui--form-row "Name" (vui-field :size 24 :key "target-name" :placeholder "interserver"))
      (zfs-ui--form-row "SSH" (vui-field :size 24 :key "target-ssh" :placeholder "user@host — empty = this machine"))
      (zfs-ui--form-row "Dataset prefix" (vui-field :size 24 :key "target-prefix" :placeholder "backuppool/mainframe")
                        "must exist on the target; the dataset's leaf name is appended")
      (vui-hstack
       (vui-box (vui-text "") :width 14)
       (vui-button "Save target"
                   :on-click (lambda ()
                               (when-let* ((actions (cdr (assoc 'page zfs-ui--row-actions)))
                                           (fn (plist-get actions :add)))
                                 (funcall fn))))))))))

(vui-defcomponent zfs-app ()
  :state ((page 'overview)
          (page-arg nil)
          (host nil)
          (pools nil)
          (datasets nil)
          (snaps nil)
          (locked nil)
          (targets (zfs-ui--targets-load))
          (loading t)
          (message nil)
          (refreshed nil)
          (backup-target nil)
          (backup-preview nil)
          (backup-progress nil)
          (backup-done nil)
          (create-status nil)
          (format-disk nil)
          (format-status nil))
  :render
  (progn
    (vui-use-effect ()
      (zfs-ui--refresh host)
      nil)
    (setq zfs-ui--row-actions nil)
    (setq zfs-ui--refresh-fn (vui-with-async-context (zfs-ui--refresh host)))
    (push (cons 'nav
                (list :back (vui-with-async-context
                              (if (eq page 'overview)
                                  (bury-buffer)
                                (zfs-ui--go 'overview)))))
          zfs-ui--row-actions)
    (let ((content
           (cond
            (loading (vui-text "Loading…" :face 'shadow))
            ((eq page 'overview)
             (if pools
                 (zfs-ui--page-overview pools datasets snaps locked)
               (vui-vstack :spacing 1
                           (vui-heading-3 "No pools found")
                           (vui-muted "ZFS returned no pools. Kernel module loaded, pools imported?"))))
            ((eq page 'dataset) (zfs-ui--page-dataset page-arg host datasets snaps))
            ((eq page 'pool) (zfs-ui--page-pool page-arg host))
            ((eq page 'create) (zfs-ui--page-create page-arg host create-status))
            ((eq page 'backup) (zfs-ui--page-backup page-arg host datasets snaps targets
                                                    backup-target backup-preview
                                                    backup-progress backup-done))
            ((eq page 'new-pool) (zfs-ui--page-format format-disk format-status))
            ((eq page 'targets) (zfs-ui--page-targets targets))
            (t (vui-text "unknown page" :face 'error)))))
      (vui-vstack
       :spacing 1
       (vui-flex :width 'window :justify :space-between
                 (vui-hstack :spacing 2
                             (vui-heading-2 "ZFS")
                             (vui-text (cond
                                        ((eq page 'overview) (if host (format "on %s" (plist-get host :name)) "on this machine"))
                                        (t (format "› %s" (if (symbolp page) (symbol-name page) page))))
                                       :face 'shadow))
                 (vui-text (format "%s pools · refreshed %s" (length pools) (or refreshed "—")) :face 'shadow))
       (if message
           (vui-text (car message) :face (cdr message))
         (vui-text " "))
       content
       (vui-text (pcase page
                   ('overview "RET open · u unlock · F format disk · T targets · g refresh · q quit")
                   ('dataset "q back · s snapshot · b backup · c new dataset · d diff · r rollback · D destroy · g refresh")
                   ('pool "q back · 1 scrub start · 2 scrub stop · x export · g refresh")
                   ('backup "q back · click a target · g refresh")
                   (_ "q back · g refresh"))
                 :face 'shadow)))))

(defun zfs-ui--key-on-line ()
  (save-excursion
    (beginning-of-line)
    (let ((end (line-end-position))
          (found nil))
      (while (and (<= (point) end) (not found))
        (setq found (vui-key-at))
        (forward-char 1))
      found)))

(defun zfs-ui--invoke (action)
  (let* ((key (zfs-ui--key-on-line))
         (row (and key (cdr (assoc key zfs-ui--row-actions))))
         (page (cdr (assoc 'page zfs-ui--row-actions))))
    (cond
     ((plist-get row action) (funcall (plist-get row action)))
     ((and (eq action :open) (plist-get row :open)) (funcall (plist-get row :open)))
     ((plist-get page action) (funcall (plist-get page action)))
     (t (message "Nothing here for that key")))))

(define-derived-mode zfs-mode vui-mode "ZFS"
  (hl-line-mode 1))

(define-key zfs-mode-map (kbd "q") (lambda () (interactive) (zfs-ui--invoke :back)))
(define-key zfs-mode-map (kbd "g") (lambda () (interactive) (when zfs-ui--refresh-fn (funcall zfs-ui--refresh-fn))))
(define-key zfs-mode-map (kbd "s") (lambda () (interactive) (zfs-ui--invoke :snapshot)))
(define-key zfs-mode-map (kbd "b") (lambda () (interactive) (zfs-ui--invoke :backup)))
(define-key zfs-mode-map (kbd "c") (lambda () (interactive) (zfs-ui--invoke :create-child)))
(define-key zfs-mode-map (kbd "d") (lambda () (interactive) (zfs-ui--invoke :diff)))
(define-key zfs-mode-map (kbd "r") (lambda () (interactive) (zfs-ui--invoke :rollback)))
(define-key zfs-mode-map (kbd "D") (lambda () (interactive) (zfs-ui--invoke :destroy)))
(define-key zfs-mode-map (kbd "m") (lambda () (interactive) (zfs-ui--invoke :mount)))
(define-key zfs-mode-map (kbd "u") (lambda () (interactive) (zfs-ui--invoke :unlock)))
(define-key zfs-mode-map (kbd "i") (lambda () (interactive) (zfs-ui--invoke :import)))
(define-key zfs-mode-map (kbd "L") (lambda () (interactive) (zfs-ui--invoke :lock)))
(define-key zfs-mode-map (kbd "F") (lambda () (interactive) (zfs-ui--invoke :format)))
(define-key zfs-mode-map (kbd "T") (lambda () (interactive) (zfs-ui--invoke :targets)))
(define-key zfs-mode-map (kbd "1") (lambda () (interactive) (zfs-ui--invoke :scrub-start)))
(define-key zfs-mode-map (kbd "2") (lambda () (interactive) (zfs-ui--invoke :scrub-stop)))
(define-key zfs-mode-map (kbd "x") (lambda () (interactive) (zfs-ui--invoke :export)))

;;;###autoload
(defun zfs ()
  (interactive)
  (let ((buffer (get-buffer-create zfs-buffer-name)))
    (with-current-buffer buffer
      (unless (eq major-mode 'zfs-mode)
        (zfs-mode)
        (vui-mount (vui-component 'zfs-app) buffer)
        (vui-rerender-on-resize)))
    (pop-to-buffer buffer)))

(provide 'zfs)
;;; zfs.el ends here
