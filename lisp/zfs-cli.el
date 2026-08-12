;;; zfs-cli.el --- ZFS command execution and JSON parsing -*- lexical-binding: t; -*-

(require 'subr-x)

(defgroup zfs nil
  "ZFS management interface."
  :group 'tools)

(defcustom zfs-hosts nil
  "Remote ZFS hosts as plists with :name and :ssh keys.
Example: ((:name \"vps1\" :ssh \"cashmere@1.2.3.4\"))"
  :type '(repeat sexp)
  :group 'zfs)

(defcustom zfs-privileged-command '("doas" "-n")
  "Command used to retry ZFS operations with elevated privileges."
  :type '(repeat string)
  :group 'zfs)

(defconst zfs-cli--permission-error-re "permission denied\\|Insufficient privileges\\|delegated permission")

(defconst zfs-cli-dataset-properties
  '(used available referenced usedbysnapshots usedbychildren compressratio
         encryption keystatus mountpoint mounted quota recordsize creation))

(defconst zfs-cli-snapshot-properties
  '(used referenced creation))

(defconst zfs-cli-pool-properties
  '(size allocated free capacity fragmentation health dedupratio))

(defun zfs-cli--argv (host program args sudo)
  (let ((command (append (when sudo zfs-privileged-command) (cons program args))))
    (if-let* ((target (plist-get host :ssh)))
        (list "ssh" "-o" "BatchMode=yes" "-o" "ConnectTimeout=5" target
              (mapconcat #'shell-quote-argument command " "))
      command)))

(defun zfs-cli--call (host program args sudo &optional input)
  (let ((stderr-file (make-temp-file "zfs-cli-"))
        (input-file (and input (make-temp-file "zfs-cli-in-")))
        (argv (zfs-cli--argv host program args sudo)))
    (unwind-protect
        (progn
          (when input-file
            (with-temp-file input-file (insert input)))
          (with-temp-buffer
            (let ((status (apply #'process-file (car argv) input-file (list t stderr-file) nil (cdr argv))))
              (if (zerop status)
                  (cons 0 (buffer-string))
                (cons status
                      (with-temp-buffer
                        (insert-file-contents stderr-file)
                        (string-trim (buffer-string))))))))
      (delete-file stderr-file)
      (when input-file (delete-file input-file)))))

(defun zfs-cli-run (host program args &optional input)
  (let ((result (zfs-cli--call host program args nil input)))
    (when (and (/= 0 (car result))
               (string-match-p zfs-cli--permission-error-re (cdr result)))
      (setq result (zfs-cli--call host program args t input)))
    (if (zerop (car result))
        (cdr result)
      (error "zfs-cli: %s" (cdr result)))))

(defun zfs-cli-run-async (host program args callback &optional sudo)
  (let ((stdout (generate-new-buffer " *zfs-cli-out*"))
        (stderr (generate-new-buffer " *zfs-cli-err*"))
        (argv (zfs-cli--argv host program args sudo)))
    (make-process
     :name "zfs-cli"
     :buffer stdout
     :stderr stderr
     :command argv
     :noquery t
     :sentinel
     (lambda (process _event)
       (when (memq (process-status process) '(exit signal))
         (let ((status (process-exit-status process))
               (out (with-current-buffer stdout (buffer-string)))
               (err (string-trim (with-current-buffer stderr (buffer-string)))))
           (kill-buffer stdout)
           (kill-buffer stderr)
           (if (and (/= 0 status)
                    (not sudo)
                    (string-match-p zfs-cli--permission-error-re err))
               (zfs-cli-run-async host program args callback t)
             (funcall callback (if (zerop status) (cons 0 out) (cons status err))))))))))

(defun zfs-cli-run-json (host program args)
  (json-parse-string (zfs-cli-run host program args)
                     :object-type 'alist
                     :array-type 'list
                     :null-object nil
                     :false-object nil))

(defun zfs-cli--parse-collection (json key)
  (mapcar (lambda (entry) (cons (symbol-name (car entry)) (cdr entry)))
          (alist-get key json)))

(defun zfs-cli-prop (entry property)
  (alist-get 'value (alist-get property (alist-get 'properties (cdr entry)))))

(defun zfs-cli-source (entry property)
  (alist-get 'type (alist-get 'source (alist-get property (alist-get 'properties (cdr entry))))))

(defun zfs-cli--list-args (types properties)
  (list "list" "-j" "-H" "--json-int" "-t" (string-join types ",")
        "-o" (string-join (cons "name" (mapcar #'symbol-name properties)) ",")))

(defun zfs-cli-datasets (host)
  (zfs-cli--parse-collection
   (zfs-cli-run-json host "zfs"
                     (zfs-cli--list-args '("filesystem" "volume") zfs-cli-dataset-properties))
   'datasets))

(defun zfs-cli-snapshots (host &optional dataset)
  (zfs-cli--parse-collection
   (zfs-cli-run-json host "zfs"
                     (append (zfs-cli--list-args '("snapshot") zfs-cli-snapshot-properties)
                             (and dataset (list dataset))))
   'datasets))

(defun zfs-cli-pools (host)
  (zfs-cli--parse-collection
   (zfs-cli-run-json host "zpool"
                     (list "list" "-j" "-H" "--json-int"
                           "-o" (string-join (cons "name" (mapcar #'symbol-name zfs-cli-pool-properties)) ",")))
   'pools))

(defun zfs-cli-snapshot (host dataset snap-name &optional recursive)
  (zfs-cli-run host "zfs"
               (append '("snapshot") (and recursive '("-r"))
                       (list (concat dataset "@" snap-name)))))

(defun zfs-cli-create (host dataset properties)
  (zfs-cli-run host "zfs"
               (append '("create")
                       (mapcan (lambda (pair) (list "-o" (format "%s=%s" (car pair) (cdr pair)))) properties)
                       (list dataset))))

(defun zfs-cli-destroy (host target &optional recursive)
  (zfs-cli-run host "zfs"
               (append '("destroy") (and recursive '("-r")) (list target))))

(defun zfs-cli-rollback (host snapshot &optional force)
  (zfs-cli-run host "zfs"
               (append '("rollback") (and force '("-f")) (list snapshot))))

(defun zfs-cli-diff (host snapshot &optional other)
  (zfs-cli-run host "zfs"
               (append '("diff" "-H") (list snapshot) (and other (list other)))))

(defun zfs-cli-send-preview (host snapshot &optional base)
  (let* ((args (append '("send" "-nPv") (and base (list "-i" base)) (list snapshot)))
         (output (zfs-cli-run host "zfs" args))
         (header (car (split-string output "\n" t)))
         (fields (split-string header "\t")))
    (list :kind (car fields)
          :base (and (equal (car fields) "incremental") (nth 1 fields))
          :bytes (string-to-number (or (car (last fields)) "0")))))

(defun zfs-cli--remote-wrap (host command-string)
  (if-let* ((target (plist-get host :ssh)))
      (format "ssh -o BatchMode=yes -o ConnectTimeout=5 %s %s"
              (shell-quote-argument target)
              (shell-quote-argument command-string))
    command-string))

(defun zfs-cli-send-pipeline (source-host snapshot target-host target-dataset base raw sudo)
  (let* ((send-command (mapconcat #'shell-quote-argument
                                  (append (when sudo zfs-privileged-command)
                                          '("zfs" "send" "-v")
                                          (and raw '("-w"))
                                          (and base (list "-i" base))
                                          (list snapshot))
                                  " "))
         (receive-command (mapconcat #'shell-quote-argument
                                     (append (when sudo zfs-privileged-command)
                                             (list "zfs" "receive" target-dataset))
                                     " ")))
    (concat (zfs-cli--remote-wrap source-host send-command)
            " | "
            (zfs-cli--remote-wrap target-host receive-command))))

(defun zfs-cli-send-async (source-host snapshot target-host target-dataset base raw callback &optional sudo)
  (let* ((stderr-buffer (generate-new-buffer " *zfs-send-err*"))
         (stderr-process
          (make-pipe-process :name "zfs-send-stderr"
                             :buffer stderr-buffer
                             :noquery t
                             :filter (lambda (process chunk)
                                       (when (buffer-live-p (process-buffer process))
                                         (with-current-buffer (process-buffer process)
                                           (goto-char (point-max))
                                           (insert chunk)))
                                       (when-let* ((line (car (last (split-string chunk "\n")))))
                                         (unless (string-blank-p line)
                                           (funcall callback (list :progress (string-trim line))))))))
         (pipeline (zfs-cli-send-pipeline source-host snapshot target-host target-dataset base raw sudo)))
    (make-process
     :name "zfs-send"
     :buffer (generate-new-buffer " *zfs-send-out*")
     :stderr stderr-process
     :command (list "sh" "-c" pipeline)
     :noquery t
     :sentinel
     (lambda (process _event)
       (when (memq (process-status process) '(exit signal))
         (let ((status (process-exit-status process))
               (err (string-trim (with-current-buffer stderr-buffer (buffer-string)))))
           (when (buffer-live-p (process-buffer process))
             (kill-buffer (process-buffer process)))
           (when (process-live-p stderr-process)
             (delete-process stderr-process))
           (kill-buffer stderr-buffer)
           (if (and (/= 0 status)
                    (not sudo)
                    (string-match-p zfs-cli--permission-error-re err))
               (zfs-cli-send-async source-host snapshot target-host target-dataset base raw callback t)
             (funcall callback (list :done status err)))))))))

(defun zfs-cli-mount (host dataset)
  (zfs-cli-run host "zfs" (list "mount" dataset)))

(defun zfs-cli-create-encrypted (host dataset passphrase &optional properties)
  (zfs-cli-run host "zfs"
               (append '("create")
                       (mapcan (lambda (pair) (list "-o" (format "%s=%s" (car pair) (cdr pair))))
                               (append properties
                                       '((encryption . "on")
                                         (keyformat . "passphrase")
                                         (keylocation . "prompt"))))
                       (list dataset))
               (concat passphrase "\n")))

(defun zfs-cli-pool-status (host pool)
  (let ((json (zfs-cli-run-json host "zpool" (list "status" "-j" "--json-int" pool))))
    (alist-get (intern pool) (alist-get 'pools json))))

(defun zfs-cli--vdev-entries (node)
  (cons (list :name (alist-get 'name node)
              :state (alist-get 'state node)
              :read-errors (alist-get 'read_errors node)
              :write-errors (alist-get 'write_errors node)
              :checksum-errors (alist-get 'checksum_errors node)
              :type (alist-get 'vdev_type node))
        (mapcan #'zfs-cli--vdev-entries (mapcar #'cdr (alist-get 'vdevs node)))))

(defun zfs-cli-pool-vdevs (status)
  (mapcan #'zfs-cli--vdev-entries (mapcar #'cdr (alist-get 'vdevs status))))

(defun zfs-cli-scrub (host pool &optional stop)
  (zfs-cli-run host "zpool" (append '("scrub") (and stop '("-s")) (list pool))))

(defun zfs-cli-export (host pool)
  (zfs-cli-run host "zpool" (list "export" pool)))

(defun zfs-cli-import (host pool &optional no-mount)
  (let ((attempt (lambda (extra sudo)
                   (zfs-cli--call host "zpool"
                                  (append '("import") extra (and no-mount '("-N")) (list pool))
                                  sudo)))
        (result nil))
    (dolist (step '((nil . nil) (nil . t) (("-d" "/dev/mapper") . t)))
      (when (or (null result) (/= 0 (car result)))
        (setq result (funcall attempt (car step) (cdr step)))))
    (unless (zerop (car result))
      (error "zfs-cli: %s" (cdr result)))))

(defun zfs-cli--parse-block-device (device)
  (list :name (alist-get 'name device)
        :path (concat "/dev/" (alist-get 'name device))
        :size (alist-get 'size device)
        :fstype (alist-get 'fstype device)
        :model (let ((model (alist-get 'model device)))
                 (and model (string-trim model)))
        :type (alist-get 'type device)
        :mounted (seq-some #'identity (alist-get 'mountpoints device))
        :children (mapcar #'zfs-cli--parse-block-device (alist-get 'children device))))

(defun zfs-cli-block-devices ()
  (let ((json (zfs-cli-run-json nil "lsblk" '("-J" "-b" "-o" "NAME,SIZE,FSTYPE,MODEL,TYPE,MOUNTPOINTS"))))
    (mapcar #'zfs-cli--parse-block-device (alist-get 'blockdevices json))))

(defun zfs-cli-locked-disks ()
  (seq-filter (lambda (device)
                (and (member (plist-get device :type) '("disk" "loop"))
                     (equal (plist-get device :fstype) "crypto_LUKS")))
              (zfs-cli-block-devices)))

(defun zfs-cli-disk-unlocked-p (device)
  (seq-find (lambda (child) (equal (plist-get child :type) "crypt"))
            (plist-get device :children)))

(defun zfs-cli-disk-mapper (device)
  (when-let* ((child (seq-find (lambda (entry) (equal (plist-get entry :type) "crypt"))
                               (plist-get device :children))))
    (plist-get child :name)))

(defun zfs-cli--device-tree-mounted-p (device)
  (or (plist-get device :mounted)
      (seq-some #'zfs-cli--device-tree-mounted-p (plist-get device :children))))

(defun zfs-cli--device-tree-active-p (device)
  (or (member (plist-get device :type) '("crypt" "lvm" "raid"))
      (seq-some #'zfs-cli--device-tree-active-p (plist-get device :children))))

(defun zfs-cli-disk-candidates ()
  (seq-filter (lambda (device)
                (and (equal (plist-get device :type) "disk")
                     (not (zfs-cli--device-tree-mounted-p device))
                     (not (zfs-cli--device-tree-active-p device))))
              (zfs-cli-block-devices)))

(defun zfs-cli-pool-on-device (device)
  (let ((result (zfs-cli--call nil "zdb" (list "-l" device) t)))
    (when (and (zerop (car result))
               (string-match "name: '\\([^']+\\)'" (cdr result)))
      (match-string 1 (cdr result)))))

(defun zfs-cli-luks-open (device name passphrase)
  (let ((result (zfs-cli--call nil "cryptsetup" (list "luksOpen" device name) t
                               (concat passphrase "\n"))))
    (unless (zerop (car result))
      (error "%s" (cdr result)))))

(defun zfs-cli-luks-close (name)
  (let ((result (zfs-cli--call nil "cryptsetup" (list "luksClose" name) t)))
    (unless (zerop (car result))
      (error "%s" (cdr result)))))

(defun zfs-cli--pipe-async (pipeline stream on-chunk on-done)
  (let ((out-buffer (generate-new-buffer " *zfs-pipe-out*"))
        (err-buffer (generate-new-buffer " *zfs-pipe-err*"))
        (consumer nil))
    (when (eq stream 'stderr)
      (setq consumer
            (make-pipe-process
             :name "zfs-pipe-stderr"
             :buffer err-buffer
             :noquery t
             :filter (lambda (process chunk)
                       (when (buffer-live-p (process-buffer process))
                         (with-current-buffer (process-buffer process)
                           (goto-char (point-max))
                           (insert chunk)))
                       (funcall on-chunk chunk)))))
    (make-process
     :name "zfs-pipe"
     :buffer out-buffer
     :stderr (or consumer err-buffer)
     :command (list "sh" "-c" pipeline)
     :noquery t
     :filter (when (eq stream 'stdout)
               (lambda (process chunk)
                 (when (buffer-live-p (process-buffer process))
                   (with-current-buffer (process-buffer process)
                     (goto-char (point-max))
                     (insert chunk)))
                 (funcall on-chunk chunk)))
     :sentinel
     (lambda (process _event)
       (when (memq (process-status process) '(exit signal))
         (let ((status (process-exit-status process))
               (out (with-current-buffer out-buffer (buffer-string)))
               (err (string-trim (with-current-buffer err-buffer (buffer-string)))))
           (when (process-live-p consumer)
             (delete-process consumer))
           (kill-buffer out-buffer)
           (kill-buffer err-buffer)
           (funcall on-done status err out)))))))

(defun zfs-cli-format-disk-async (device pool-name mapper-name passphrase callback)
  (let ((key-file (and passphrase (make-temp-file "zfs-luks-key-"))))
    (when key-file
      (with-temp-file key-file (insert passphrase))
      (chmod key-file #o600))
    (let ((pipeline
           (if passphrase
               (mapconcat
                #'identity
                (list (format "doas -n wipefs -a %s" (shell-quote-argument device))
                      (format "doas -n cryptsetup luksFormat -q --key-file %s %s"
                              (shell-quote-argument key-file) (shell-quote-argument device))
                      (format "doas -n cryptsetup open --key-file %s %s %s"
                              (shell-quote-argument key-file) (shell-quote-argument device)
                              (shell-quote-argument mapper-name))
                      (format "doas -n zpool create -O compression=lz4 -O mountpoint=none %s %s"
                              (shell-quote-argument pool-name)
                              (shell-quote-argument (concat "/dev/mapper/" mapper-name))))
                " && ")
             (format "doas -n wipefs -a %s && doas -n zpool create -f -O compression=lz4 -O mountpoint=none %s %s"
                     (shell-quote-argument device)
                     (shell-quote-argument pool-name)
                     (shell-quote-argument device)))))
      (zfs-cli--pipe-async pipeline 'stderr
                           #'ignore
                           (lambda (status err _out)
                             (when key-file
                               (delete-file key-file))
                             (funcall callback status err))))))

(defun zfs-cli--rsync-source (source mode)
  (let ((path (expand-file-name source)))
    (cond
     ((and (eq mode 'contents) (file-directory-p path))
      (file-name-as-directory path))
     ((file-directory-p path)
      (directory-file-name path))
     (t path))))

(defun zfs-cli-rsync-async (source target mode dry-run callback)
  (let* ((source-arg (zfs-cli--rsync-source source mode))
         (target-arg (file-name-as-directory (expand-file-name target)))
         (args (append '("rsync" "-rlt" "--info=progress2")
                       (and dry-run '("--dry-run" "--itemize-changes"))
                       (and (eq mode 'move) '("--remove-source-files"))
                       (list source-arg target-arg))))
    (zfs-cli--pipe-async
     (mapconcat #'shell-quote-argument args " ")
     'stdout
     (lambda (chunk) (funcall callback (list :progress chunk)))
     (lambda (status err out) (funcall callback (list :done status err out))))))

(provide 'zfs-cli)
;;; zfs-cli.el ends here
