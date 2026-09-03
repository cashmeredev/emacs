;;; citre-index.el --- Automatic project and live-buffer tags -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'json)
(require 'project)
(require 'filenotify)
(require 'subr-x)

(defgroup my/citre nil "Automatic Citre indexes." :group 'tools)
(defcustom my/project-ctags-program (expand-file-name "bin/project-ctags" user-emacs-directory)
  "Worker used for disk indexes and buffer snapshots." :type 'file :group 'my/citre)
(defcustom my/citre-index-cache-directory (expand-file-name "citre-cache/" user-emacs-directory)
  "Persistent disk indexes; live snapshots are private to this Emacs session." :type 'directory :group 'my/citre)
(defcustom my/citre-index-idle-delay 0.1
  "Idle seconds before parsing changed buffers." :type 'number :group 'my/citre)
(defcustom my/citre-index-refresh-delay 0.2
  "Seconds to collect disk changes before checking the project." :type 'number :group 'my/citre)
(defcustom my/citre-index-check-interval 30
  "Seconds between background checks of projects with open buffers." :type 'number :group 'my/citre)
(defcustom my/citre-index-dependency-check-interval 300
  "Seconds between dependency discovery when declarations have not changed." :type 'number :group 'my/citre)
(defcustom my/citre-index-max-watches 256
  "Maximum directory watches per project; periodic checks cover the remainder." :type 'integer :group 'my/citre)
(defcustom my/citre-index-max-buffer-size (* 2 1024 1024)
  "Maximum buffer size for live snapshots; larger files use the disk index." :type 'integer :group 'my/citre)
(defcustom my/citre-index-process-timeout 120
  "Maximum seconds for a disk-index worker." :type 'number :group 'my/citre)
(defcustom my/citre-index-excluded-directories
  '(".git" ".hg" ".svn" ".direnv" ".venv" ".pixi" "__pycache__" "node_modules" "target" "build" "dist" "citre-cache")
  "Directory names excluded from automatic project and live-buffer indexing." :type '(repeat string) :group 'my/citre)
(defvar-local my/project-ctags-arguments nil
  "Additional worker arguments, usually configured in project directory locals.")
(put 'my/project-ctags-arguments 'safe-local-variable
     (lambda (value) (and (listp value) (seq-every-p #'stringp value))))

(cl-defstruct (my/citre-index-state (:constructor my/citre-index--make-state))
  root cache environment paths arguments
  disk-process live-process disk-timer live-timer pending force
  entries watches live-directory error checked (revision 0))

(defvar my/citre-index--projects (make-hash-table :test #'equal))
(defvar my/citre-index--timer nil)
(defvar my/citre-index-mode nil)
(defvar my/citre-index-updated-hook nil
  "Functions called with the project state after an index changes.")
(defvar-local my/citre-index--state nil)
(defvar-local my/citre-index--dirty nil)

(defun my/citre-index--path ()
  "Return the canonical visited filename, including for a new file."
  (when buffer-file-name (file-truename buffer-file-name)))

(defun my/citre-index--eligible-p ()
  "Whether the current buffer is a local source file eligible for indexing."
  (and buffer-file-name (derived-mode-p 'prog-mode)
       (not (file-remote-p buffer-file-name))
       (not (cl-intersection (split-string buffer-file-name "/" t)
                             my/citre-index-excluded-directories :test #'equal))))

(defun my/citre-index--root ()
  "Find a local project root without prompting."
  (when (my/citre-index--eligible-p)
    (when-let* ((root (or (and (fboundp 'projectile-project-root)
                              (ignore-errors (projectile-project-root)))
                         (when-let* ((project (project-current nil)))
                           (project-root project)))))
      (file-name-as-directory (file-truename root)))))

(defun my/citre-index--buffers (state)
  "Return living buffers attached to STATE."
  (cl-remove-if-not
   (lambda (buffer)
     (and (buffer-live-p buffer)
          (eq (buffer-local-value 'my/citre-index--state buffer) state)))
   (buffer-list)))

(defun my/citre-index--log (state)
  "Return the private worker log for STATE."
  (get-buffer-create (format " *citre-index:%s*" (my/citre-index-state-root state))))

(defun my/citre-index--updated (state)
  "Invalidate consumers after publishing a new index in STATE."
  (cl-incf (my/citre-index-state-revision state))
  (run-hook-with-args 'my/citre-index-updated-hook state))

(defun my/citre-index--environment (state)
  "Capture the current buffer's project environment in STATE."
  (setf (my/citre-index-state-environment state) (copy-sequence process-environment)
        (my/citre-index-state-paths state) (copy-sequence exec-path)
        (my/citre-index-state-arguments state) (copy-sequence my/project-ctags-arguments)))

(defun my/citre-index--cancel-timer (timer)
  "Cancel TIMER if it exists."
  (when (timerp timer) (cancel-timer timer)))

(defun my/citre-index--record-error (state error)
  "Record ERROR without interrupting editing or displaying a buffer."
  (setf (my/citre-index-state-error state) (format "%s" error))
  (with-current-buffer (my/citre-index--log state)
    (goto-char (point-max))
    (insert (format "\n%s\n" error))))

(defun my/citre-index--spawn (state name arguments sentinel &optional filter)
  "Start one worker for STATE using ARGUMENTS, SENTINEL and FILTER."
  (let ((default-directory (my/citre-index-state-root state))
        (process-environment (my/citre-index-state-environment state))
        (exec-path (my/citre-index-state-paths state)))
    (make-process :name name :buffer (my/citre-index--log state)
                  :command (append (list my/project-ctags-program default-directory) arguments)
                  :connection-type 'pipe :noquery t :sentinel sentinel :filter filter
                  :stderr (my/citre-index--log state))))

(defun my/citre-index--watch (state directories)
  "Reconcile bounded directory watches for STATE with DIRECTORIES."
  (let* ((git (expand-file-name ".git" (my/citre-index-state-root state)))
         (wanted (seq-take (delete-dups
                            (append (list (my/citre-index-state-root state))
                                    (when (file-directory-p git) (list git (expand-file-name "refs/heads" git)))
                                    directories))
                           my/citre-index-max-watches))
         (watches (my/citre-index-state-watches state)))
    (maphash (lambda (directory descriptor)
               (unless (and (member directory wanted) (file-notify-valid-p descriptor))
                 (ignore-errors (file-notify-rm-watch descriptor))
                 (remhash directory watches)))
             watches)
    (dolist (directory wanted)
      (when (and (file-directory-p directory) (not (gethash directory watches)))
        (condition-case nil
            (puthash directory
                     (file-notify-add-watch
                      directory '(change)
                      (lambda (event)
                        (unless (or (eq (nth 1 event) 'stopped)
                                    (cl-some (lambda (path)
                                               (and (stringp path)
                                                    (string-prefix-p (file-name-as-directory my/citre-index-cache-directory) path)))
                                             (cddr event)))
                          (my/citre-index-request-refresh state))))
                     watches)
          (file-notify-error nil))))))

(defun my/citre-index--disk-filter (state process chunk)
  "Consume line-delimited worker events for STATE from PROCESS and CHUNK."
  (let* ((text (concat (or (process-get process 'partial) "") chunk))
         (lines (split-string text "\n")))
    (process-put process 'partial (car (last lines)))
    (dolist (line (butlast lines))
      (condition-case nil
          (let ((event (json-parse-string line :object-type 'alist :array-type 'list :false-object nil)))
            (when (equal (alist-get 'event event) "complete")
              (process-put process 'manifest event))
            (when (alist-get 'changed event)
              (process-put process 'changed t)
              (when (equal (alist-get 'event event) "project")
                (my/citre-index--updated state))))
        (error (with-current-buffer (my/citre-index--log state)
                 (goto-char (point-max)) (insert line "\n")))))))

(defun my/citre-index--disk-finished (state process _event)
  "Publish a finished disk worker for STATE."
  (when (memq (process-status process) '(exit signal))
    (my/citre-index--cancel-timer (process-get process 'timeout))
    (when (eq process (my/citre-index-state-disk-process state))
      (setf (my/citre-index-state-disk-process state) nil)
      (if (and (eq (process-status process) 'exit) (zerop (process-exit-status process)))
          (condition-case error
              (let ((manifest (process-get process 'manifest)))
                (setf (my/citre-index-state-error state) nil
                      (my/citre-index-state-checked state) (current-time))
                (my/citre-index--watch state (alist-get 'directories manifest))
                (when (process-get process 'changed)
                  (my/citre-index--updated state)))
            (error (my/citre-index--record-error state error)))
        (my/citre-index--record-error state (format "Disk worker exited: %s" (process-exit-status process))))
      (when (my/citre-index-state-pending state)
        (my/citre-index-request-refresh state)))))

(defun my/citre-index--start-disk (state)
  "Start or coalesce the next disk check for STATE."
  (setf (my/citre-index-state-disk-timer state) nil)
  (when (and my/citre-index-mode (my/citre-index--buffers state))
    (if (process-live-p (my/citre-index-state-disk-process state))
        (setf (my/citre-index-state-pending state) t)
      (condition-case error
          (let* ((arguments
                  (append (my/citre-index-state-arguments state)
                          (list "--cache-dir" (my/citre-index-state-cache state)
                                "--dependency-check-interval" (number-to-string my/citre-index-dependency-check-interval)
                                "--watch-limit" (number-to-string my/citre-index-max-watches))
                          (cl-mapcan (lambda (name) (list "--exclude-dir" name)) my/citre-index-excluded-directories)
                          (when (my/citre-index-state-force state) '("--force"))))
                 (process (my/citre-index--spawn state "citre-disk" arguments
                                                (lambda (process event) (my/citre-index--disk-finished state process event))
                                                (lambda (process chunk) (my/citre-index--disk-filter state process chunk)))))
            (setf (my/citre-index-state-disk-process state) process
                  (my/citre-index-state-pending state) nil
                  (my/citre-index-state-force state) nil)
            (process-put process 'timeout
                         (run-at-time my/citre-index-process-timeout nil
                                      (lambda () (when (process-live-p process) (delete-process process))))))
        (error (my/citre-index--record-error state error))))))

(defun my/citre-index-request-refresh (state &optional force)
  "Schedule a background disk check for STATE; FORCE requests a full rebuild."
  (when (and my/citre-index-mode state)
    (when force (setf (my/citre-index-state-force state) t))
    (setf (my/citre-index-state-pending state) t)
    (unless (timerp (my/citre-index-state-disk-timer state))
      (setf (my/citre-index-state-disk-timer state)
            (run-at-time my/citre-index-refresh-delay nil #'my/citre-index--start-disk state)))))

(defun my/citre-index-live-entries (state)
  "Return valid live entries in STATE and retire entries of detached or renamed buffers."
  (let (entries retired)
    (maphash
     (lambda (path entry)
       (let ((buffer (plist-get entry :buffer)))
         (if (and (buffer-live-p buffer)
                  (with-current-buffer buffer
                    (and (eq my/citre-index--state state) (equal path (my/citre-index--path))
                         (or (buffer-modified-p) (verify-visited-file-modtime buffer)))))
             (push (cons path entry) entries)
           (push path retired)
           (ignore-errors (delete-file (plist-get entry :file))))))
     (my/citre-index-state-entries state))
    (dolist (path retired) (remhash path (my/citre-index-state-entries state)))
    entries))

(defun my/citre-index--live-finished (state directory jobs process _event)
  "Publish only matching buffer versions from JOBS, then remove DIRECTORY."
  (when (memq (process-status process) '(exit signal))
    (my/citre-index--cancel-timer (process-get process 'timeout))
    (when (eq process (my/citre-index-state-live-process state))
      (setf (my/citre-index-state-live-process state) nil)
      (unwind-protect
          (if (and (eq (process-status process) 'exit) (zerop (process-exit-status process)))
              (progn
                (dolist (job jobs)
                  (let ((buffer (plist-get job :buffer))
                        (path (plist-get job :source)))
                    (when (and (buffer-live-p buffer)
                               (with-current-buffer buffer
                                 (and (eq my/citre-index--state state)
                                      (equal path (my/citre-index--path))
                                      (= (buffer-chars-modified-tick) (plist-get job :tick)))))
                      (let* ((old (gethash path (my/citre-index-state-entries state)))
                             (output (make-temp-file (expand-file-name "buffer-" (my/citre-index-state-live-directory state)) nil ".tags")))
                        (rename-file (plist-get job :output) output t)
                        (puthash path (list :file output :buffer buffer :tick (plist-get job :tick))
                                 (my/citre-index-state-entries state))
                        (when old (ignore-errors (delete-file (plist-get old :file))))
                        (with-current-buffer buffer (setq my/citre-index--dirty nil))))))
                (my/citre-index--updated state))
            ;; Retry on the next edit or explicit rebuild, not in an error loop.
            (dolist (job jobs)
              (when (buffer-live-p (plist-get job :buffer))
                (with-current-buffer (plist-get job :buffer)
                  (when (= (buffer-chars-modified-tick) (plist-get job :tick))
                    (setq my/citre-index--dirty nil)))))
            (my/citre-index--record-error state (format "Live worker exited: %s" (process-exit-status process))))
        (ignore-errors (delete-directory directory t)))
      (when (cl-some (lambda (buffer) (buffer-local-value 'my/citre-index--dirty buffer))
                     (my/citre-index--buffers state))
        (my/citre-index--schedule-live state)))))

(defun my/citre-index--start-live (state)
  "Parse dirty buffers of STATE independently of slower dependency checks."
  (my/citre-index--cancel-timer (my/citre-index-state-live-timer state))
  (setf (my/citre-index-state-live-timer state) nil)
  (when (and my/citre-index-mode (not (process-live-p (my/citre-index-state-live-process state))))
    (let ((directory (make-temp-file (expand-file-name "job-" (my/citre-index-state-live-directory state)) t))
          jobs request)
      (condition-case error
          (progn
            (dolist (buffer (my/citre-index--buffers state))
              (with-current-buffer buffer
                (when my/citre-index--dirty
                  (if (or (> (buffer-size) my/citre-index-max-buffer-size)
                          (not (my/citre-index--eligible-p)))
                      (setq my/citre-index--dirty nil)
                    (let* ((source (my/citre-index--path))
                           (snapshot (expand-file-name (concat (number-to-string (length jobs)) "/" (file-name-nondirectory source)) directory))
                           (output (concat snapshot ".tags"))
                           (tick (buffer-chars-modified-tick)))
                      (make-directory (file-name-directory snapshot) t)
                      (let ((coding-system-for-write (or buffer-file-coding-system 'utf-8-unix)))
                        (save-restriction
                          (widen)
                          (write-region (point-min) (point-max) snapshot nil 'silent)))
                      (push (list :buffer buffer :source source :output output :tick tick) jobs)
                      (push (list (cons 'source source) (cons 'snapshot snapshot) (cons 'output output)) request))))))
            (if (null jobs)
                (delete-directory directory t)
              (let ((request-file (expand-file-name "request.json" directory)))
                (with-temp-file request-file (insert (json-encode (vconcat request))))
                (let ((process (my/citre-index--spawn
                                state "citre-live" (append (my/citre-index-state-arguments state) (list "--snapshot-request" request-file))
                                (lambda (process event) (my/citre-index--live-finished state directory jobs process event)))))
                  (setf (my/citre-index-state-live-process state) process)
                  (process-put process 'timeout
                               (run-at-time 10 nil (lambda () (when (process-live-p process) (delete-process process)))))))))
        (error
         (ignore-errors (delete-directory directory t))
         (my/citre-index--record-error state error))))))

(defun my/citre-index--schedule-live (state)
  "Debounce live parsing for STATE."
  (unless (timerp (my/citre-index-state-live-timer state))
    (setf (my/citre-index-state-live-timer state)
          (run-with-idle-timer my/citre-index-idle-delay nil #'my/citre-index--start-live state))))

(defun my/citre-index--changed (&rest _)
  "Mark the current buffer dirty without running a parser inside the change hook."
  (when my/citre-index--state
    (setq my/citre-index--dirty t)
    (my/citre-index--schedule-live my/citre-index--state)))

(defun my/citre-index--saved ()
  "Refresh disk state after a save or revert."
  (when my/citre-index--state
    (my/citre-index--environment my/citre-index--state)
    (my/citre-index--changed)
    (my/citre-index-request-refresh my/citre-index--state)))

(defun my/citre-index--renamed ()
  "Reattach live content when the visited filename or project changes."
  (my/citre-index--detach)
  (my/citre-index-attach))

(defun my/citre-index--flush ()
  "Start a pending live update when leaving Evil insert state."
  (when (and my/citre-index--state my/citre-index--dirty)
    (my/citre-index--start-live my/citre-index--state)))

(defun my/citre-index--detach ()
  "Detach the current buffer and invalidate its live results."
  (when-let* ((state my/citre-index--state))
    (setq my/citre-index--state nil my/citre-index--dirty nil)
    (my/citre-index-live-entries state)
    (my/citre-index--updated state)
    (if (my/citre-index--buffers state)
        (my/citre-index-request-refresh state)
      (my/citre-index--release state))))

(defun my/citre-index-attach ()
  "Attach a local programming buffer to its automatic project index."
  (when my/citre-index-mode
    (when-let* ((root (my/citre-index--root)))
      (when my/citre-index--state
        (my/citre-index--environment my/citre-index--state))
      (unless (and my/citre-index--state (equal root (my/citre-index-state-root my/citre-index--state)))
        (my/citre-index--detach)
        (let ((state (gethash root my/citre-index--projects)))
          (unless state
            (let ((cache (expand-file-name (secure-hash 'sha256 root) my/citre-index-cache-directory)))
              (make-directory cache t)
              (setq state (my/citre-index--make-state
                           :root root :cache cache :entries (make-hash-table :test #'equal)
                           :watches (make-hash-table :test #'equal)
                           :live-directory (make-temp-file (expand-file-name "live-" cache) t)))
              (puthash root state my/citre-index--projects)))
          (setq my/citre-index--state state)
          (my/citre-index--environment state)
          (add-hook 'after-change-functions #'my/citre-index--changed nil t)
          (add-hook 'after-save-hook #'my/citre-index--saved nil t)
          (add-hook 'after-revert-hook #'my/citre-index--saved nil t)
          (add-hook 'after-set-visited-file-name-hook #'my/citre-index--renamed nil t)
          (add-hook 'kill-buffer-hook #'my/citre-index--detach nil t)
          (add-hook 'change-major-mode-hook #'my/citre-index--detach nil t)
          (add-hook 'evil-insert-state-exit-hook #'my/citre-index--flush nil t)
          (when (fboundp 'citre-mode) (citre-mode 1))
          (my/citre-index--changed)
          (my/citre-index-request-refresh state))))))

(defun my/citre-index--check ()
  "Check active projects and refresh environments after direnv or project switches."
  (when my/citre-index-mode
    (maphash
     (lambda (_root state)
       (when-let* ((buffers (my/citre-index--buffers state)))
         (with-current-buffer (if (memq (current-buffer) buffers) (current-buffer) (car buffers))
           (my/citre-index--environment state))
         (my/citre-index-request-refresh state)))
     my/citre-index--projects)))

(defun my/citre-index--focus ()
  "Check project files when Emacs regains focus."
  (when (frame-focus-state) (my/citre-index--check)))

(defun my/project-ctags-setup ()
  "Force a complete asynchronous rebuild of this project's disk and live indexes."
  (interactive)
  (my/citre-index-attach)
  (unless my/citre-index--state (user-error "No local programming project in this buffer"))
  (dolist (buffer (my/citre-index--buffers my/citre-index--state))
    (with-current-buffer buffer (my/citre-index--changed)))
  (my/citre-index-request-refresh my/citre-index--state t)
  (message "Citre rebuild scheduled"))

(defun my/citre-index-status ()
  "Show index state and offer the log without opening it during ordinary editing."
  (interactive)
  (unless my/citre-index--state (user-error "No automatic Citre index in this buffer"))
  (let ((state my/citre-index--state))
    (with-help-window "*Citre index status*"
      (princ (format "Project: %s\nCache: %s\nLive buffers: %d\nDisk worker: %s\nLive worker: %s\nLast check: %s\nLast error: %s\nLog: %s\n"
                     (my/citre-index-state-root state) (my/citre-index-state-cache state)
                     (length (my/citre-index-live-entries state))
                     (if (process-live-p (my/citre-index-state-disk-process state)) "running" "idle")
                     (if (process-live-p (my/citre-index-state-live-process state)) "running" "idle")
                     (if (my/citre-index-state-checked state) (format-time-string "%F %T" (my/citre-index-state-checked state)) "pending")
                     (or (my/citre-index-state-error state) "none")
                     (buffer-name (my/citre-index--log state)))))))

(defun my/citre-index--release (state)
  "Release workers and watches belonging to STATE and remove its session snapshots."
  (my/citre-index--cancel-timer (my/citre-index-state-disk-timer state))
  (my/citre-index--cancel-timer (my/citre-index-state-live-timer state))
  (dolist (process (list (my/citre-index-state-disk-process state) (my/citre-index-state-live-process state)))
    (when (processp process)
      (my/citre-index--cancel-timer (process-get process 'timeout))
      (set-process-sentinel process #'ignore)
      (when (process-live-p process) (delete-process process))))
  (maphash (lambda (_directory descriptor) (ignore-errors (file-notify-rm-watch descriptor)))
           (my/citre-index-state-watches state))
  (ignore-errors (delete-directory (my/citre-index-state-live-directory state) t))
  (remhash (my/citre-index-state-root state) my/citre-index--projects))

(defun my/citre-index--stop ()
  "Stop workers and watches and remove only this session's live snapshots."
  (my/citre-index--cancel-timer my/citre-index--timer)
  (setq my/citre-index--timer nil)
  (maphash (lambda (_root state) (my/citre-index--release state)) my/citre-index--projects)
  (clrhash my/citre-index--projects)
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when my/citre-index--state
        (setq my/citre-index--state nil my/citre-index--dirty nil)
        (remove-hook 'after-change-functions #'my/citre-index--changed t)
        (remove-hook 'after-save-hook #'my/citre-index--saved t)
        (remove-hook 'after-revert-hook #'my/citre-index--saved t)
        (remove-hook 'after-set-visited-file-name-hook #'my/citre-index--renamed t)
        (remove-hook 'kill-buffer-hook #'my/citre-index--detach t)
        (remove-hook 'change-major-mode-hook #'my/citre-index--detach t)
        (remove-hook 'evil-insert-state-exit-hook #'my/citre-index--flush t)))))

(define-minor-mode my/citre-index-mode
  "Maintain project tags and unsaved-buffer tags automatically."
  :global t :group 'my/citre
  (if my/citre-index-mode
      (progn
        (add-hook 'find-file-hook #'my/citre-index-attach)
        (add-hook 'after-change-major-mode-hook #'my/citre-index-attach)
        (add-hook 'magit-post-refresh-hook #'my/citre-index--check)
        (add-hook 'kill-emacs-hook #'my/citre-index--stop)
        (add-function :after after-focus-change-function #'my/citre-index--focus)
        (my/citre-index--cancel-timer my/citre-index--timer)
        (setq my/citre-index--timer (run-at-time my/citre-index-check-interval my/citre-index-check-interval #'my/citre-index--check))
        (dolist (buffer (buffer-list)) (with-current-buffer buffer (my/citre-index-attach))))
    (remove-hook 'find-file-hook #'my/citre-index-attach)
    (remove-hook 'after-change-major-mode-hook #'my/citre-index-attach)
    (remove-hook 'magit-post-refresh-hook #'my/citre-index--check)
    (remove-hook 'kill-emacs-hook #'my/citre-index--stop)
    (remove-function after-focus-change-function #'my/citre-index--focus)
    (my/citre-index--stop)))

(provide 'citre-index)
;;; citre-index.el ends here
