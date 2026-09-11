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

(defmacro fossil-ui-test--with-checkout (&rest body)
  "Create a temporary Fossil checkout and evaluate BODY there."
  (declare (indent 0) (debug t))
  `(let* ((base (make-temp-file "fossil-ui-test-" t))
          (repo (expand-file-name "project.fossil" base))
          (root (file-name-as-directory (expand-file-name "checkout" base))))
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

(ert-deftest fossil-ui-diff-produces-navigable-hunks ()
  (fossil-ui-test--with-checkout
    (fossil-ui-test--write (expand-file-name "tracked.txt" root)
                           "first changed line\nsecond line\n")
    (let ((diff (fossil-ui-test--call
                 root "diff" "--internal" "--unified" "--" "tracked.txt")))
      (should (string-match-p "^@@ " diff))
      (with-temp-buffer
        (fossil-ui-diff-mode)
        (should (eq (key-binding (kbd "]c")) #'diff-hunk-next))
        (should (eq (key-binding (kbd "[c")) #'diff-hunk-prev))
        (should (eq (key-binding (kbd "TAB")) #'outline-toggle-children))))))

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

(ert-deftest fossil-ui-theme-change-rerenders-open-diff-in-place ()
  (save-window-excursion
    (with-temp-buffer
      (let* ((buffer (current-buffer))
             (raw (mapconcat (lambda (number) (format "line %d" number)) (number-sequence 1 80) "\n"))
             (context (list :root "/tmp/project/" :path "example.el" :diff raw)))
        (fossil-ui-diff-mode)
        (let ((inhibit-read-only t))
          (insert raw))
        (set-buffer-modified-p nil)
        (setq-local fossil-ui-diff-context context)
        (switch-to-buffer buffer)
        (goto-char (point-min))
        (forward-line 40)
        (let ((point-before (point))
              (window-before (selected-window)))
          (set-window-start window-before (save-excursion
                                            (goto-char (point-min))
                                            (forward-line 20)
                                            (point)))
          (let ((start-before (window-start window-before)))
            (cl-letf (((symbol-function 'fossil-ui--display-diff)
                       (lambda (_diff &optional _frame)
                         (propertize raw 'face 'success))))
              (fossil-ui--theme-enabled 'test-theme))
            (should (eq (selected-window) window-before))
            (should (= (point) point-before))
            (should (= (window-start window-before) start-before))
            (should-not (buffer-modified-p))
            (should (equal fossil-ui-diff-context context))
            (should (equal (buffer-substring-no-properties (point-min) (point-max)) raw))
            (should (eq (get-text-property (point-min) 'face) 'success))))))))

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

(ert-deftest fossil-ui-preview-block-resizes-and-retains-diff-faces ()
  (let* ((fossil-ui-preview-lines 3)
         (widget
          (widget-convert 'fossil-ui-preview
                          :path "tracked.txt"
                          :value "@@ -1 +1 @@\n-old\n+new\n context")))
    (dolist (width '(20 80 120))
      (let ((rendered (textui-layout-widget widget width)))
        (should (text-property-not-all 0 (length rendered) 'face nil rendered))
        (dolist (line (split-string rendered "\n"))
          (should (<= (string-width line) width)))
        (with-temp-buffer
          (insert rendered)
          (textui-attach-widget widget (point-min) (point-max))
          (should (equal (buffer-string) rendered))
          (widget-delete widget))))))

(ert-deftest fossil-ui-preview-toggle-refresh-and-clean-checkout ()
  (fossil-ui-test--with-checkout
    (fossil-ui-test--write (expand-file-name "tracked.txt" root) "preview change\n")
    (let ((buffer (save-window-excursion (fossil-ui-status root))))
      (unwind-protect
          (with-current-buffer buffer
            (fossil-ui--goto-path "tracked.txt")
            (should (eq (key-binding (kbd "P")) #'fossil-ui-toggle-preview))
            (fossil-ui-toggle-preview)
            (should (equal (plist-get textui-state :preview-path) "tracked.txt"))
            (textui-refresh buffer)
            (should (string-search "+preview change" (buffer-substring-no-properties (point-min) (point-max))))
            (fossil-ui-test--write (expand-file-name "tracked.txt" root) "new preview\n")
            (fossil-ui-refresh)
            (textui-refresh buffer)
            (should (string-search "+new preview" (buffer-substring-no-properties (point-min) (point-max))))
            (fossil-ui--goto-path "tracked.txt")
            (fossil-ui-toggle-preview)
            (should-not (plist-get textui-state :preview-path))
            (fossil-ui-toggle-preview)
            (fossil-ui-test--write (expand-file-name "tracked.txt" root) "initial\n")
            (fossil-ui-refresh)
            (should-not (plist-get textui-state :preview-path)))
        (when (buffer-live-p buffer)
          (kill-buffer buffer))))))

(provide 'fossil-ui-test)
;;; fossil-ui-test.el ends here
