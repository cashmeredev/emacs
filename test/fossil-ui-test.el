;;; fossil-ui-test.el --- Tests for fossil-ui -*- lexical-binding: t; -*-

(require 'ert)
(require 'fossil-ui)

(defun fossil-ui-test--call (directory &rest args)
  "Run Fossil ARGS in DIRECTORY and fail the test on error."
  (pcase-let ((`(,code ,output) (apply #'fossil-ui--call-in directory args)))
    (unless (zerop code)
      (ert-fail (format "fossil %S failed (%d): %s" args code output)))
    output))

(defun fossil-ui-test--write (file contents)
  "Write CONTENTS to FILE."
  (make-directory (file-name-directory file) t)
  (with-temp-file file (insert contents)))

(defun fossil-ui-test--write-bytes (file bytes)
  "Write exact unibyte BYTES to FILE."
  (make-directory (file-name-directory file) t)
  (fossil-ui--write-bytes file bytes))

(defmacro fossil-ui-test--with-checkout (&rest body)
  "Create a temporary Fossil checkout and evaluate BODY there."
  (declare (indent 0) (debug t))
  `(let* ((base (make-temp-file "fossil-ui-test-" t))
          (repo (expand-file-name "project.fossil" base))
          (root (file-name-as-directory (expand-file-name "checkout" base)))
          (fossil-ui-stage-directory (expand-file-name "stage/" base)))
     (unwind-protect
         (progn
           (make-directory root)
           (fossil-ui-test--call base "init" repo)
           (fossil-ui-test--call base "user" "new" "tester"
                                 "tester@example.invalid" "test-password" "-R" repo)
           (fossil-ui-test--call base "user" "default" "tester" "-R" repo)
           (fossil-ui-test--call root "open" repo)
           (fossil-ui-test--write (expand-file-name "tracked.txt" root) "initial\n")
           (fossil-ui-test--call root "add" "tracked.txt")
           (fossil-ui-test--call root "commit" "--nosync" "-m" "initial")
           ,@body)
       (delete-directory base t))))

(defun fossil-ui-test--cat-bytes (root path)
  "Return committed PATH from ROOT as exact bytes."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (let ((default-directory root)
          (coding-system-for-read 'no-conversion))
      (should (zerop (process-file fossil-ui-program nil t nil "cat" "-r" "current" "--" path))))
    (buffer-string)))

(ert-deftest fossil-ui-parse-change-line-preserves-spaces ()
  (should
   (equal (fossil-ui--parse-change-line "EDITED     \"dir/file name.el\"")
          '(:status "EDITED" :path "dir/file name.el"))))

(ert-deftest fossil-ui-parse-numstat-text-and-spaced-paths ()
  (should (equal (fossil-ui--parse-numstat-line "12\t3\tdir/file name.el")
                 '(:path "dir/file name.el" :insertions 12 :deletions 3
                   :binary nil))))

(ert-deftest fossil-ui-parse-numstat-binary-and-deleted-files ()
  (should (equal (fossil-ui--parse-numstat-line "-\t-\timage file.png")
                 '(:path "image file.png" :insertions nil :deletions nil
                   :binary t)))
  (should (equal (fossil-ui--parse-numstat-line "0 19 old file.txt")
                 '(:path "old file.txt" :insertions 0 :deletions 19
                   :binary nil))))

(ert-deftest fossil-ui-numstat-association-handles-extras ()
  (let ((stats (make-hash-table :test #'equal)))
    (puthash "edited.txt" '(:path "edited.txt" :insertions 4 :deletions 2)
             stats)
    (should
     (equal (fossil-ui--attach-numstat
             '((:status "EDITED" :path "edited.txt")
               (:status "EXTRA" :path "new file.txt")) stats)
            '((:status "EDITED" :path "edited.txt" :insertions 4 :deletions 2)
              (:status "EXTRA" :path "new file.txt" :extra t))))))

(ert-deftest fossil-ui-snapshot-finds-edited-and-extra-files ()
  (fossil-ui-test--with-checkout
    (fossil-ui-test--write (expand-file-name "tracked.txt" root) "changed content\n")
    (fossil-ui-test--write (expand-file-name "extra file.txt" root) "extra\n")
    (let* ((snapshot (fossil-ui--snapshot root))
           (changes (plist-get snapshot :changes)))
      (should (equal (plist-get snapshot :root) root))
      (should (cl-find-if
               (lambda (change)
                 (and (equal (plist-get change :status) "EDITED")
                      (equal (plist-get change :path) "tracked.txt")))
               changes))
      (should (cl-find-if
               (lambda (change)
                 (and (equal (plist-get change :status) "EXTRA")
                      (equal (plist-get change :path) "extra file.txt")))
               changes))
      (let ((edited (cl-find "tracked.txt" changes
                             :key (lambda (change) (plist-get change :path))
                             :test #'equal)))
        (should (numberp (plist-get edited :insertions)))
        (should (numberp (plist-get edited :deletions)))))))

(ert-deftest fossil-ui-snapshot-retains-only-live-selections ()
  (fossil-ui-test--with-checkout
    (fossil-ui-test--write (expand-file-name "tracked.txt" root) "changed content\n")
    (let ((snapshot (fossil-ui--snapshot root '("tracked.txt" "gone.txt"))))
      (should (equal (plist-get snapshot :selected) '("tracked.txt"))))))

(ert-deftest fossil-ui-branch-json-includes-new-branch ()
  (fossil-ui-test--with-checkout
    (fossil-ui-test--write (expand-file-name "tracked.txt" root) "feature content\n")
    (fossil-ui-test--call root "commit" "--hash" "--nosync" "--branch" "feature"
                          "-m" "start feature")
    (should (member "feature" (fossil-ui--branches root)))))

(ert-deftest fossil-ui-render-fits-common-widths-and-heights ()
  (fossil-ui-test--with-checkout
    (fossil-ui-test--write (expand-file-name "tracked.txt" root) "changed content\n")
    (let ((textui-state (fossil-ui--snapshot root '("tracked.txt"))))
      (dolist (height '(18 32 70))
        (setq textui-state (plist-put textui-state :height height))
        (dolist (width '(80 120 190))
          (let* ((frame (fossil-ui--frame width))
                 (rendered
                  (substring-no-properties
                   (textui--render-specs
                    (textui--prepare-frame frame) width))))
            (should (string-match-p "tracked.txt" rendered))
            (should (string-match-p "\\[x\\].*tracked.txt" rendered))
            (should (string-match-p
                     "Repository.*Checkout.*Synchronization" rendered))
            (when (= width 80)
              (should (string-match-p "EDITED.*[+].*−" rendered))
              (should-not (string-match-p "Changes.*Recent commits" rendered)))
            (should (string-match-p "Staged changes" rendered))
            (should (string-match-p "Unstaged changes" rendered))
            (dolist (line (split-string rendered "\n"))
              (should
               (<=
                (string-width (string-trim-right line))
                (if fossil-ui-content-width
                    (min width fossil-ui-content-width)
                  width))))
            (when (= width 190)
              (should
               (cl-some
                (lambda (line)
                  (= (string-width line) 190))
                (split-string rendered "\n"))))))))))

(ert-deftest fossil-ui-icons-have-portable-fallback ()
  (let ((fossil-ui-use-icons nil))
    (should (equal (fossil-ui--icon 'repository) "R"))
    (should (equal (fossil-ui--status-icon "EXTRA") "?")))
  (let ((fossil-ui-use-icons 'auto))
    (cl-letf (((symbol-function 'display-graphic-p) (lambda (&optional _) nil)))
      (should (equal (fossil-ui--icon 'branch) "B")))))

(ert-deftest fossil-ui-metadata-grid-reduces-columns-responsively ()
  (should (= (fossil-ui--metadata-columns 80) 3))
  (should (= (fossil-ui--metadata-columns 70) 2))
  (should (= (fossil-ui--metadata-columns 23) 1)))

(ert-deftest fossil-ui-render-shows-clean-busy-error-and-no-remote-cards ()
  (let* ((textui-state
          '(:root "/tmp/project/"
            :repository "/tmp/project.fossil"
            :checkout "0123456789abcdef"
            :branch "trunk"
            :autosync "off"
            :remote nil
            :changes nil
            :selected nil
            :timeline nil
            :busy "sync"
            :error "network unavailable"
            :height 32))
         (rendered
          (substring-no-properties
           (textui--render-specs
            (textui--prepare-frame (fossil-ui--frame 120)) 120))))
    (should (string-match-p "No unstaged changes" rendered))
    (should (string-match-p "Running" rendered))
    (should (string-match-p "sync is running" rendered))
    (should (string-match-p "Error" rendered))
    (should (string-match-p "network unavailable" rendered))
    (should (string-match-p "no remote" rendered))))

(ert-deftest fossil-ui-highlight-range-stays-inside-file-widget ()
  (with-temp-buffer
    (insert "│ ")
    (let ((begin (point)))
      (insert (propertize "[x] README.org" 'fossil-ui-path "README.org"))
      (let ((end (point)))
        (insert "                         │ Recent commits │")
        (goto-char begin)
        (pcase-let ((`(,range-begin . ,range-end) (fossil-ui--card-range)))
          (should (= range-begin begin))
          (should (= range-end end))
          (should (< range-end (line-end-position))))))))

(ert-deftest fossil-ui-partial-commit-leaves-unselected-file-dirty ()
  (fossil-ui-test--with-checkout
    (fossil-ui-test--write (expand-file-name "other.txt" root) "other initial\n")
    (fossil-ui-test--call root "add" "other.txt")
    (fossil-ui-test--call root "commit" "--hash" "--nosync" "-m" "add other")
    (fossil-ui-test--write (expand-file-name "tracked.txt" root) "tracked change\n")
    (fossil-ui-test--write (expand-file-name "other.txt" root) "other change\n")
    (fossil-ui-test--call root "commit" "--hash" "--nosync" "--no-prompt"
                          "--comment" "partial" "--" "tracked.txt")
    (let ((changes (fossil-ui--changes root)))
      (should-not (cl-find "tracked.txt" changes
                           :key (lambda (change) (plist-get change :path))
                           :test #'equal))
      (should (cl-find "other.txt" changes
                       :key (lambda (change) (plist-get change :path))
                       :test #'equal)))))

(ert-deftest fossil-ui-missing-file-can-be-staged-unstaged-and-committed-as-deletion ()
  (fossil-ui-test--with-checkout
    (delete-file (expand-file-name "tracked.txt" root))
    (let ((buffer (save-window-excursion (fossil-ui-status root))))
      (unwind-protect
          (with-current-buffer buffer
            (fossil-ui--goto-path "tracked.txt")
            (should (equal (fossil-ui--status-at-point) "MISSING"))
            (fossil-ui-stage)
            (should (plist-get (car (plist-get (fossil-ui--index root) :entries)) :deleted))
            (should (equal (plist-get (car (fossil-ui--changes root)) :status) "DELETED"))
            (fossil-ui--goto-path "tracked.txt" t)
            (fossil-ui-unstage)
            (should-not (plist-get (fossil-ui--index root) :entries))
            (should (equal (plist-get (car (fossil-ui--changes root)) :status) "DELETED"))
            (fossil-ui--goto-path "tracked.txt")
            (fossil-ui-stage)
            (fossil-ui--commit-staged root "remove tracked file")
            (should-not (member "tracked.txt" (split-string (fossil-ui-test--call root "ls" "-r" "current") "\n" t))))
        (when (buffer-live-p buffer) (kill-buffer buffer))))))

(ert-deftest fossil-ui-staged-and-unstaged-inline-sections-are-independent ()
  (fossil-ui-test--with-checkout
    (fossil-ui-test--write (expand-file-name "tracked.txt" root) "staged version\n")
    (let ((buffer (save-window-excursion (fossil-ui-status root))))
      (unwind-protect
          (with-current-buffer buffer
            (fossil-ui--goto-path "tracked.txt")
            (fossil-ui-stage)
            (fossil-ui-test--write (expand-file-name "tracked.txt" root) "working version\n")
            (fossil-ui-refresh)
            (fossil-ui--goto-path "tracked.txt" t)
            (fossil-ui-diff)
            (fossil-ui--goto-path "tracked.txt" nil)
            (fossil-ui-diff)
            (should (member '(t "tracked.txt") (plist-get textui-state :expanded-diffs)))
            (should (member '(nil "tracked.txt") (plist-get textui-state :expanded-diffs)))
            (goto-char (point-min))
            (should (text-property-search-forward 'fossil-ui-location '(file t "tracked.txt") #'equal))
            (should (text-property-search-forward 'fossil-ui-location '(file nil "tracked.txt") #'equal)))
        (when (buffer-live-p buffer) (kill-buffer buffer))))))

(ert-deftest fossil-ui-inline-hunk-stage-and-stale-diff-guard ()
  (fossil-ui-test--with-checkout
    (fossil-ui-test--write (expand-file-name "tracked.txt" root) "changed\n")
    (let ((buffer (save-window-excursion (fossil-ui-status root))))
      (unwind-protect
          (with-current-buffer buffer
            (fossil-ui--goto-path "tracked.txt")
            (fossil-ui-diff)
            (goto-char (point-min))
            (let ((hunk (text-property-search-forward 'fossil-ui-hunk-header t #'eq)))
              (should hunk)
              (goto-char (prop-match-beginning hunk))
              (fossil-ui-test--write (expand-file-name "tracked.txt" root) "changed again\n")
              (should-error (fossil-ui-stage) :type 'user-error)
              (fossil-ui-refresh)
              (goto-char (point-min))
              (setq hunk (text-property-search-forward 'fossil-ui-hunk-header t #'eq))
              (goto-char (prop-match-beginning hunk))
              (fossil-ui-stage)
              (let* ((entry (car (plist-get (fossil-ui--index root) :entries))))
                (should (equal (plist-get entry :staged) "changed again\n")))))
        (when (buffer-live-p buffer) (kill-buffer buffer))))))

(defun fossil-ui-test--select-replacement-lines ()
  "Activate a region spanning the first removed and added inline lines."
  (goto-char (point-min))
  (let* ((removed (or (text-property-search-forward 'fossil-ui-line-kind ?- #'eq)
                      (ert-fail "No removed line")))
         (begin (prop-match-beginning removed))
         (added (or (text-property-search-forward 'fossil-ui-line-kind ?+ #'eq)
                    (ert-fail "No added line")))
         (end (prop-match-end added)))
    (goto-char (max begin (1- end)))
    (set-mark begin)
    (activate-mark)))

(ert-deftest fossil-ui-visual-lines-stage-unstage-and-discard ()
  (fossil-ui-test--with-checkout
    (fossil-ui-test--write (expand-file-name "tracked.txt" root) "replacement\n")
    (let ((buffer (save-window-excursion (fossil-ui-status root)))
          (fossil-ui-confirm-revert nil))
      (unwind-protect
          (with-current-buffer buffer
            (setq-local transient-mark-mode t)
            (fossil-ui--goto-path "tracked.txt")
            (fossil-ui-diff)
            (fossil-ui-test--select-replacement-lines)
            (fossil-ui-stage)
            (should (equal (plist-get (car (plist-get (fossil-ui--index root) :entries)) :staged) "replacement\n"))
            (fossil-ui--goto-path "tracked.txt" t)
            (fossil-ui-diff)
            (fossil-ui-test--select-replacement-lines)
            (fossil-ui-unstage)
            (should-not (plist-get (fossil-ui--index root) :entries))
            (fossil-ui--goto-path "tracked.txt")
            (fossil-ui-diff)
            (fossil-ui-test--select-replacement-lines)
            (fossil-ui-discard)
            (should (equal (fossil-ui--text-file (expand-file-name "tracked.txt" root)) "initial\n")))
        (when (buffer-live-p buffer) (kill-buffer buffer))))))

(ert-deftest fossil-ui-ret-from-inline-line-visits-correct-source-line ()
  (fossil-ui-test--with-checkout
    (fossil-ui-test--write (expand-file-name "tracked.txt" root) "initial\nsecond line\n")
    (let ((buffer (save-window-excursion (fossil-ui-status root)))
          visited)
      (unwind-protect
          (with-current-buffer buffer
            (fossil-ui--goto-path "tracked.txt")
            (fossil-ui-diff)
            (goto-char (point-min))
            (let ((line (text-property-search-forward 'fossil-ui-line-kind ?+ #'eq)))
              (should line)
              (goto-char (prop-match-beginning line))
              (should (= (fossil-ui--property-at-line 'fossil-ui-target-line) 2))
              (cl-letf (((symbol-function 'find-file)
                         (lambda (file)
                           (setq visited (find-file-noselect file))
                           (set-buffer visited))))
                (fossil-ui-visit-file)
                (should (= (line-number-at-pos) 2)))))
        (when (buffer-live-p visited) (kill-buffer visited))
        (when (buffer-live-p buffer) (kill-buffer buffer))))))

(ert-deftest fossil-ui-invalid-utf8-whole-file-stage-cleans-snapshot-on-unstage ()
  (fossil-ui-test--with-checkout
    (let ((bytes (concat (string-make-unibyte "age-encryption.org/v1\n") (unibyte-string #xff #x80) "\n")))
      (fossil-ui-test--write-bytes (expand-file-name "tracked.txt" root) bytes)
      (let ((buffer (save-window-excursion (fossil-ui-status root))))
        (unwind-protect
            (with-current-buffer buffer
              (let ((change (cl-find "tracked.txt" (plist-get textui-state :changes)
                                     :key (lambda (candidate) (plist-get candidate :path)) :test #'equal)))
                (should (plist-get change :binary)))
              (fossil-ui--goto-path "tracked.txt")
              (fossil-ui-diff)
              (should (string-search "Binary files differ" (buffer-substring-no-properties (point-min) (point-max))))
              (goto-char (point-min))
              (should-not (text-property-search-forward 'fossil-ui-hunk-header t #'eq))
              (goto-char (point-min))
              (let ((binary-line (text-property-search-forward 'fossil-ui-diff-key '(nil "tracked.txt") #'equal)))
                (should binary-line)
                (goto-char (prop-match-beginning binary-line)))
              (fossil-ui-stage)
              (let* ((entry (car (plist-get (fossil-ui--index root) :entries)))
                     (snapshot (plist-get entry :snapshot)))
                (should (plist-get entry :binary))
                (should (equal (fossil-ui--read-bytes snapshot) bytes))
                (should (= (logand (file-modes snapshot) #o777) #o600))
                (fossil-ui--goto-path "tracked.txt" t)
                (fossil-ui-unstage)
                (should-not (file-exists-p snapshot))
                (should-not (plist-get (fossil-ui--index root) :entries))
                (fossil-ui--goto-path "tracked.txt")
                (fossil-ui-stage)
                (let* ((restaged (car (plist-get (fossil-ui--index root) :entries)))
                       (restaged-snapshot (plist-get restaged :snapshot)))
                  (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
                    (fossil-ui-clear-stage))
                  (should-not (file-exists-p restaged-snapshot))
                  (should-not (plist-get (fossil-ui--index root) :entries)))))
          (when (buffer-live-p buffer) (kill-buffer buffer)))))))

(ert-deftest fossil-ui-encoding-glob-allows-invalid-utf8-warning-override ()
  (fossil-ui-test--with-checkout
    (fossil-ui-test--call root "settings" "encoding-glob" "*.txt")
    (fossil-ui-test--write-bytes (expand-file-name "tracked.txt" root) (unibyte-string #xff #xfe))
    (should (equal (fossil-ui--commit-warning-arguments root '("tracked.txt")) '("--no-warnings")))))

(ert-deftest fossil-ui-configured-invalid-utf8-commit-is-byte-exact ()
  (fossil-ui-test--with-checkout
    (fossil-ui-test--call root "settings" "binary-glob" "*.txt")
    (let* ((staged (concat (string-make-unibyte "age-v1\n") (unibyte-string #xff #xfe) "\n"))
           (working (concat (string-make-unibyte "age-v2\n") (unibyte-string #x80 #x81) "\n")))
      (fossil-ui-test--write-bytes (expand-file-name "tracked.txt" root) staged)
      (let ((buffer (save-window-excursion (fossil-ui-status root))))
        (unwind-protect
            (with-current-buffer buffer
              (fossil-ui--goto-path "tracked.txt")
              (fossil-ui-stage)
              (let* ((entry (car (plist-get (fossil-ui--index root) :entries)))
                     (snapshot (plist-get entry :snapshot)))
                (should (equal (fossil-ui--commit-warning-arguments root '("tracked.txt") (list entry)) '("--no-warnings")))
                (fossil-ui-test--write-bytes (expand-file-name "tracked.txt" root) working)
                (fossil-ui--commit-staged root "binary update")
                (should (equal (fossil-ui-test--cat-bytes root "tracked.txt") staged))
                (should (equal (fossil-ui--read-bytes (expand-file-name "tracked.txt" root)) working))
                (should-not (file-exists-p snapshot))
                (should-not (plist-get (fossil-ui--index root) :entries))))
          (when (buffer-live-p buffer) (kill-buffer buffer)))))))

(ert-deftest fossil-ui-unconfigured-invalid-utf8-commit-is-rejected ()
  (fossil-ui-test--with-checkout
    (let ((bytes (concat (string-make-unibyte "invalid\n") (unibyte-string #xff) "\n")))
      (fossil-ui-test--write-bytes (expand-file-name "tracked.txt" root) bytes)
      (let ((buffer (save-window-excursion (fossil-ui-status root))))
        (unwind-protect
            (with-current-buffer buffer
              (fossil-ui--goto-path "tracked.txt")
              (fossil-ui-stage)
              (let ((error (should-error (fossil-ui--commit-staged root "must fail") :type 'user-error)))
                (should (string-match-p "binary-glob" (error-message-string error)))
                (should (plist-get (fossil-ui--index root) :entries))))
          (when (buffer-live-p buffer) (kill-buffer buffer)))))))

(ert-deftest fossil-ui-warning-override-requires-every-invalid-file-to-be-configured ()
  (fossil-ui-test--with-checkout
    (fossil-ui-test--call root "settings" "binary-glob" "tracked.txt")
    (fossil-ui-test--write-bytes (expand-file-name "tracked.txt" root) (unibyte-string #xff))
    (fossil-ui-test--write-bytes (expand-file-name "other.bin" root) (unibyte-string #xfe))
    (let ((error (should-error (fossil-ui--commit-warning-arguments root '("tracked.txt" "other.bin")) :type 'user-error)))
      (should (string-match-p "other.bin" (error-message-string error))))))

(ert-deftest fossil-ui-inline-diff-starts-collapsed-and-folds-file-and-hunk ()
  (fossil-ui-test--with-checkout
    (fossil-ui-test--write (expand-file-name "tracked.txt" root)
                           "first changed line\nsecond line\n")
    (let ((buffer (save-window-excursion (fossil-ui-status root))))
      (unwind-protect
          (with-current-buffer buffer
            (should-not (plist-get textui-state :expanded-diffs))
            (should-not (text-property-search-forward 'fossil-ui-hunk-header t #'eq))
            (fossil-ui--goto-path "tracked.txt")
            (fossil-ui-diff)
            (should (member '(nil "tracked.txt") (plist-get textui-state :expanded-diffs)))
            (goto-char (point-min))
            (let ((hunk (text-property-search-forward 'fossil-ui-hunk-header t #'eq)))
              (should hunk)
              (goto-char (prop-match-beginning hunk))
              (let ((id (fossil-ui--property-at-line 'fossil-ui-hunk-id)))
                (should id)
                (fossil-ui-diff)
                (should (member id (plist-get textui-state :collapsed-hunks)))
                (goto-char (point-min))
                (should-not (text-property-search-forward 'fossil-ui-line-kind ?+ #'eq))
                (should (text-property-search-forward 'fossil-ui-hunk-header t #'eq)))))
        (when (buffer-live-p buffer) (kill-buffer buffer))))))

(ert-deftest fossil-ui-delta-render-keeps-hunks-and-emacs-faces ()
  (skip-unless (executable-find fossil-ui-delta-program))
  (let* ((raw (concat "Index: example.el\n"
                      "==================================================================\n"
                      "--- example.el\n"
                      "+++ example.el\n"
                      "@@ -1,1 +1,1 @@\n"
                      "-(message \"old\")\n"
                      "+(message \"new\")\n"))
         (fossil-ui-diff-renderer 'delta)
         (rendered (fossil-ui--render-diff raw)))
    (should (string-search "@@ -1,1 +1,1 @@" rendered))
    (should-not (string-search (string ?\e) rendered))
    (should (text-property-not-all 0 (length rendered) 'face nil rendered))))

(ert-deftest fossil-ui-delta-color-mode-follows-frame-background ()
  (let ((fossil-ui-delta-color-mode 'auto)
        (fossil-ui-delta-arguments '("--paging=never" "--color-only")))
    (cl-letf (((symbol-function 'frame-parameter)
               (lambda (_frame parameter)
                 (and (eq parameter 'background-mode) 'light))))
      (should (equal (fossil-ui--effective-delta-arguments)
                     '("--light" "--paging=never" "--color-only"))))
    (cl-letf (((symbol-function 'frame-parameter)
               (lambda (_frame parameter)
                 (and (eq parameter 'background-mode) 'dark))))
      (should (equal (fossil-ui--effective-delta-arguments)
                     '("--dark" "--paging=never" "--color-only"))))))

(ert-deftest fossil-ui-delta-color-mode-respects-explicit-arguments ()
  (let ((fossil-ui-delta-color-mode 'auto))
    (dolist (arguments '(("--light" "--color-only")
                         ("--dark" "--color-only")
                         ("--syntax-theme" "GitHub" "--color-only")
                         ("--syntax-theme=GitHub" "--color-only")))
      (let ((fossil-ui-delta-arguments arguments))
        (should (eq (fossil-ui--effective-delta-arguments) arguments))))))

(ert-deftest fossil-ui-theme-change-rerenders-inline-diff-in-place ()
  (save-window-excursion
    (fossil-ui-test--with-checkout
      (fossil-ui-test--write (expand-file-name "tracked.txt" root) "theme change\n")
      (let ((buffer (fossil-ui-status root)))
        (unwind-protect
            (with-current-buffer buffer
              (fossil-ui--goto-path "tracked.txt")
              (fossil-ui-diff)
              (let* ((key '(nil "tracked.txt"))
                     (raw (plist-get (alist-get key (plist-get textui-state :inline-diffs) nil nil #'equal) :diff))
                     (point-before (point)))
                (cl-letf (((symbol-function 'fossil-ui--display-diff)
                           (lambda (_diff &optional _frame) (propertize raw 'face 'success))))
                  (fossil-ui--theme-enabled 'test-theme))
                (let ((display (plist-get (alist-get key (plist-get textui-state :inline-diffs) nil nil #'equal) :display)))
                  (should (equal (substring-no-properties display) raw))
                  (should (eq (get-text-property 0 'face display) 'success)))
                (should (= (point) point-before))))
          (when (buffer-live-p buffer) (kill-buffer buffer)))))))

(ert-deftest fossil-ui-status-opens-rendered-dashboard ()
  (fossil-ui-test--with-checkout
    (fossil-ui-test--write (expand-file-name "tracked.txt" root) "changed content\n")
    (let ((buffer (save-window-excursion (fossil-ui-status root))))
      (unwind-protect
          (with-current-buffer buffer
            (should (derived-mode-p 'fossil-ui-mode))
            (should (equal default-directory root))
            (goto-char (point-min))
            (should (text-property-search-forward
                     'fossil-ui-path "tracked.txt" #'equal)))
        (when (buffer-live-p buffer) (kill-buffer buffer))))))

(ert-deftest fossil-ui-rejects-directory-without-checkout ()
  (let ((directory (make-temp-file "fossil-ui-empty-" t)))
    (unwind-protect
        (should-error (fossil-ui--checkout-info directory) :type 'user-error)
      (delete-directory directory t))))

(ert-deftest fossil-ui-display-diff-rejects-structurally-changed-delta-output ()
  (let ((raw "@@ -1 +1 @@\n-old\n+new\n"))
    (cl-letf (((symbol-function 'fossil-ui--render-diff)
               (lambda (_diff &optional _frame) (propertize "changed structure" 'face 'success))))
      (should (equal (fossil-ui--display-diff raw) raw)))))

(ert-deftest fossil-ui-inline-diff-survives-refresh ()
  (fossil-ui-test--with-checkout
    (fossil-ui-test--write (expand-file-name "tracked.txt" root) "inline change\n")
    (let ((buffer (save-window-excursion (fossil-ui-status root))))
      (unwind-protect
          (with-current-buffer buffer
            (fossil-ui--goto-path "tracked.txt")
            (fossil-ui-diff)
            (goto-char (point-min))
            (let ((hunk (text-property-search-forward 'fossil-ui-hunk-header t #'eq)))
              (should hunk)
              (goto-char (prop-match-beginning hunk)))
            (let ((location (fossil-ui--property-at-line 'fossil-ui-location)))
              (fossil-ui-test--write (expand-file-name "tracked.txt" root) "new inline change\n")
              (fossil-ui-refresh)
              (should (member '(nil "tracked.txt") (plist-get textui-state :expanded-diffs)))
              (should (equal (fossil-ui--property-at-line 'fossil-ui-location) location)))
            (should (string-search "+new inline change" (buffer-substring-no-properties (point-min) (point-max))))
            (fossil-ui--goto-path "tracked.txt")
            (fossil-ui-diff)
            (should-not (plist-get textui-state :expanded-diffs))
            (fossil-ui-test--write (expand-file-name "tracked.txt" root) "initial\n")
            (fossil-ui-refresh)
            (should-not (plist-get textui-state :expanded-diffs)))
        (when (buffer-live-p buffer)
          (kill-buffer buffer))))))

(provide 'fossil-ui-test)
;;; fossil-ui-test.el ends here
