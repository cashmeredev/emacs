;;; org-fmt.el --- Opinionated Org formatter -*- lexical-binding: t; -*-

;; Spec: ~/garden/20260813T130151--org-fmt-spec__emacs_org_project.org

;;; Code:

(require 'org-element)
(require 'org-table)

(defgroup org-fmt nil
  "Opinionated Org formatter."
  :group 'org)

(define-error 'org-fmt-refusal "org-fmt refusal" 'error)

(defcustom org-fmt-rules
  '(org-fmt--rule-trailing-whitespace
    org-fmt--rule-front-matter
    org-fmt--rule-block-case
    org-fmt--rule-blank-lines
    org-fmt--rule-headline-space
    org-fmt--rule-tables
    org-fmt--rule-drawer-case
    org-fmt--rule-eof-newline)
  "Formatting rules applied in order."
  :type '(repeat function))

(defcustom org-fmt-refusal-scanners nil
  "Functions scanning the current buffer for unsafe regions.
Each returns a list of refusal records (LINE REASON FILE-LEVEL-P)."
  :type '(repeat function))

(defvar org-fmt--refusals nil
  "Refusal records for the current buffer, set by `org-fmt-format-buffer'.")

(defun org-fmt--collect-refusals ()
  (setq org-fmt--refusals nil)
  (dolist (scanner org-fmt-refusal-scanners)
    (setq org-fmt--refusals (nconc (funcall scanner) org-fmt--refusals)))
  org-fmt--refusals)

(defun org-fmt--refused-lines-p (beg end)
  "Non-nil when any refused line falls within BEG..END."
  (and org-fmt--refusals
       (let ((first (line-number-at-pos beg))
             (last (line-number-at-pos end)))
         (seq-some (lambda (r) (<= first (car r) last)) org-fmt--refusals))))

(defun org-fmt-format-buffer ()
  "Format the current Org buffer.
Signals `org-fmt-refusal' when a file-level refusal was found."
  (org-fmt--collect-refusals)
  (let ((file-level (seq-filter (lambda (r) (nth 2 r)) org-fmt--refusals)))
    (when file-level
      (signal 'org-fmt-refusal (list file-level))))
  (save-excursion
    (dolist (rule org-fmt-rules)
      (goto-char (point-min))
      (funcall rule))))

(defun org-fmt-format-string (text &optional rules)
  "Format TEXT as an Org buffer and return the result.
RULES overrides `org-fmt-rules'.  Refusals are left in `org-fmt--refusals'."
  (with-temp-buffer
    (insert text)
    (delay-mode-hooks (org-mode))
    (let ((org-fmt-rules (or rules org-fmt-rules)))
      (org-fmt-format-buffer))
    (buffer-string)))

(defun org-fmt-format-file (file &optional check)
  "Format FILE in place.
With CHECK non-nil, do not write.  Returns a plist with :changed
and :refusals.  Signals `org-fmt-refusal' on file-level refusal."
  (let* ((input (with-temp-buffer
                  (insert-file-contents file)
                  (buffer-string)))
         (org-fmt--refusals nil)
         (output (org-fmt-format-string input)))
    (unless (or check (equal input output))
      (with-temp-file file
        (insert output)))
    (list :changed (not (equal input output))
          :refusals org-fmt--refusals)))

;;;; R1 Trailing whitespace

(defun org-fmt--content-end (node)
  "Return the position just past NODE's last content line, excluding post-blank."
  (save-excursion
    (goto-char (org-element-property :end node))
    (let ((post-blank (or (org-element-property :post-blank node) 0)))
      (cond ((> post-blank 0)
             (forward-line (- post-blank))
             (point))
            ((bolp) (point))
            (t (line-end-position))))))

(defun org-fmt--literal-line-ranges ()
  "Return (FIRST-LINE . LAST-LINE) ranges covering literal block bodies.
Literal blocks are src, example, export and comment blocks; when the
element exposes no contents boundaries the whole element is protected."
  (org-element-map (org-element-parse-buffer)
      '(src-block example-block export-block comment-block dynamic-block)
    (lambda (blk)
      (let ((beg (or (org-element-property :contents-begin blk)
                     (org-element-property :post-affiliated blk)
                     (org-element-property :begin blk)))
            (end (or (org-element-property :contents-end blk)
                     (org-fmt--content-end blk))))
        (cons (line-number-at-pos beg)
              (line-number-at-pos (max beg (1- end))))))))

(defun org-fmt--rule-trailing-whitespace ()
  "Strip trailing spaces and tabs from every line outside literal regions.
Lines consisting of only a structural prefix (headline stars or a list
bullet) and whitespace keep a single trailing space: stripping it would
reparse the line as plain text."
  (let ((ranges (org-fmt--literal-line-ranges)))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (let ((line (line-number-at-pos)))
          (unless (or (org-fmt--refused-lines-p (line-beginning-position)
                                                (line-end-position))
                      (seq-some (lambda (r) (<= (car r) line (cdr r))) ranges))
            (goto-char (line-end-position))
            (skip-chars-backward " \t" (line-beginning-position))
            (if (looking-back "^\\(?:\\*+\\|[-+]\\|[0-9]+[.)]\\)"
                              (line-beginning-position))
                (progn
                  (delete-region (point) (line-end-position))
                  (insert " "))
              (delete-region (point) (line-end-position)))))
        (forward-line 1)))))

;;;; R2 Front matter

(defconst org-fmt--front-matter-key-order
  '("title" "date" "description" "author" "email"
    "filetags" "identifier" "tags" "slug" "status")
  "Canonical order of known front matter keys.")

(defconst org-fmt--keyword-line-regexp
  "^\\([ \t]*\\)#\\+\\([^ \t:[\n]+\\):[ \t]*"
  "Regexp matching a keyword line.
Group 1 is the leading whitespace, group 2 the keyword name; the
match ends where the value begins, past any post-colon whitespace.")

(defun org-fmt--front-matter-keyword-p ()
  "Non-nil when the line at point is a column-zero keyword line."
  (and (looking-at org-fmt--keyword-line-regexp)
       (zerop (length (match-string-no-properties 1)))))

(defun org-fmt--front-matter-run ()
  "Collect the front matter keyword run at the start of the buffer.
The run is the leading series of consecutive column-zero keyword
lines; it stops at the first blank or non-keyword line.  When a
non-blank line follows the run directly, trailing affiliated
keywords (CAPTION, NAME, HEADER, ...) belong to that element and
are dropped from the run.  Returns a
list of entries (RAW NAME VALUE REFUSED), where RAW is the original
line text, NAME is downcased, VALUE preserves every byte past the
post-colon whitespace and REFUSED marks refused lines."
  (goto-char (point-min))
  (let (entries)
    (while (and (not (eobp)) (org-fmt--front-matter-keyword-p))
      (push (list (buffer-substring-no-properties (point) (line-end-position))
                  (downcase (match-string-no-properties 2))
                  (buffer-substring-no-properties (match-end 0)
                                                  (line-end-position))
                  (org-fmt--refused-lines-p (point) (line-end-position)))
            entries)
      (forward-line 1))
    (setq entries (nreverse entries))
    (when (and entries
               (not (eobp))
               (not (looking-at-p "[ \t]*$")))
      (let ((case-fold-search t)
            (tail (nreverse entries)))
        (while (and tail
                    (string-match-p (concat "\\`" org-element--affiliated-re)
                                    (concat (nth 0 (car tail)) "\n")))
          (pop tail))
        (setq entries (nreverse tail))))
    entries))

(defun org-fmt--front-matter-rank (name)
  "Sort rank of front matter key NAME; unknown keys sort last."
  (or (seq-position org-fmt--front-matter-key-order name)
      (length org-fmt--front-matter-key-order)))

(defun org-fmt--front-matter-line (name value)
  "Canonical front matter line for downcased NAME and VALUE.
The keyword field is padded so VALUE starts at column 15; fields
longer than 13 characters get exactly one space.  An empty VALUE
gets no padding."
  (let ((prefix (concat "#+" name ":")))
    (if (zerop (length value))
        prefix
      (concat prefix
              (if (> (length prefix) 13)
                  " "
                (make-string (- 14 (length prefix)) ?\s))
              value))))

(defun org-fmt--front-matter-segment-text (segment)
  "Canonical text for SEGMENT of front matter entries, sorted by key.
The sort is stable, so unknown keys and duplicate keys keep their
original relative order."
  (mapconcat
   (lambda (entry) (org-fmt--front-matter-line (nth 1 entry) (nth 2 entry)))
   (sort segment
         (lambda (a b)
           (< (org-fmt--front-matter-rank (nth 1 a))
              (org-fmt--front-matter-rank (nth 1 b)))))
   "\n"))

(defun org-fmt--front-matter-blank-line ()
  "Enforce exactly one blank line between point and the next content.
Point must be at the first line after the front matter run.  Blank
lines are removed; a single blank line is inserted only when more
content follows.  Does nothing when the affected lines are refused."
  (let ((beg (point)))
    (while (and (not (eobp)) (looking-at-p "[ \t]*$"))
      (forward-line 1))
    (unless (org-fmt--refused-lines-p beg (max beg (1- (point))))
      (delete-region beg (point))
      (unless (eobp)
        (insert "\n")))))

(defun org-fmt--front-matter-format-run ()
  "Align, sort and re-space the front matter run at the start of the buffer.
Refused lines keep their original text and position; other lines
are normalized and stably sorted within each segment between
refused lines.  Exactly one blank line follows the run."
  (let ((entries (org-fmt--front-matter-run)))
    (when entries
      (let ((chunks nil)
            (segment nil))
        (dolist (entry entries)
          (if (nth 3 entry)
              (progn
                (when segment
                  (push (org-fmt--front-matter-segment-text (nreverse segment))
                        chunks)
                  (setq segment nil))
                (push (nth 0 entry) chunks))
            (push entry segment)))
        (when segment
          (push (org-fmt--front-matter-segment-text (nreverse segment)) chunks))
        (let ((new (mapconcat #'identity (nreverse chunks) "\n")))
          (goto-char (point-min))
          (let ((beg (point)))
            (forward-line (length entries))
            (when (and (> (point) beg) (eq (char-before (point)) ?\n))
              (setq new (concat new "\n")))
            (unless (string= (buffer-substring-no-properties beg (point)) new)
              (delete-region beg (point))
              (insert new)))))
      (org-fmt--front-matter-blank-line))))

(defun org-fmt--front-matter-format-strays ()
  "Normalize keyword lines outside the front matter run.
Names are lowercased and followed by exactly one space; values and
indentation are untouched.  Lines inside literal regions and refused
lines are left byte-identical."
  (let ((ranges (org-fmt--literal-line-ranges)))
    (goto-char (point-min))
    (while (and (not (eobp)) (org-fmt--front-matter-keyword-p))
      (forward-line 1))
    (while (not (eobp))
      (when (and (looking-at org-fmt--keyword-line-regexp)
                 (not (org-fmt--refused-lines-p (point) (line-end-position)))
                 (not (seq-some (lambda (range)
                                  (<= (car range) (line-number-at-pos) (cdr range)))
                                ranges)))
        (let* ((new (let ((value (buffer-substring-no-properties
                                  (match-end 0) (line-end-position))))
                      (concat (match-string-no-properties 1)
                              "#+" (downcase (match-string-no-properties 2)) ":"
                              (unless (zerop (length value))
                                (concat " " value)))))
               (old (buffer-substring-no-properties (point) (line-end-position))))
          (unless (string= old new)
            (delete-region (point) (line-end-position))
            (insert new))))
      (forward-line 1))))

(defun org-fmt--rule-front-matter ()
  "Normalize front matter and stray keyword lines.
Front matter keywords are lowercased, aligned to column 15 and
sorted per `org-fmt--front-matter-key-order', with exactly one
blank line after the block.  Keyword lines elsewhere are lowercased
and given a single space after the colon, without reordering."
  (org-fmt--front-matter-format-run)
  (org-fmt--front-matter-format-strays))

;;;; R3 Block delimiter case

(defun org-fmt--rule-block-case ()
  "Lowercase the begin/end keywords of every block delimiter line.
Language names, switches and parameters are preserved byte-for-byte."
  (let ((case-fold-search t))
    (org-element-map (org-element-parse-buffer)
        '(src-block example-block export-block comment-block
          dynamic-block
          quote-block verse-block center-block special-block)
      (lambda (blk)
        (let ((begin-line (save-excursion
                            (goto-char (org-element-property :post-affiliated blk))
                            (line-beginning-position)))
              (end-line (save-excursion
                          (goto-char (max (point-min)
                                          (1- (org-fmt--content-end blk))))
                          (line-beginning-position))))
          (save-excursion
            (goto-char begin-line)
            (unless (org-fmt--refused-lines-p begin-line (line-end-position))
              (when (looking-at "[ \t]*\\(#\\+begin\\(?:_[a-z0-9_-]+\\|:\\)\\)")
                (replace-match (downcase (match-string 1)) t nil nil 1))))
          (save-excursion
            (goto-char end-line)
            (unless (org-fmt--refused-lines-p end-line (line-end-position))
              (when (looking-at "[ \t]*\\(#\\+end\\(?:_[a-z0-9_-]+\\|:\\)\\)")
                (replace-match (downcase (match-string 1)) t nil nil 1)))))))))

;;;; R4 Blank lines

(defun org-fmt--literal-body-ranges (ast)
  "Line ranges (FIRST . LAST) of literal block bodies in AST.
Covers src, example, export, comment and verse blocks."
  (let ((ranges nil))
    (org-element-map ast '(src-block example-block export-block comment-block verse-block dynamic-block)
      (lambda (block)
        (let* ((beg (or (org-element-property :post-affiliated block)
                        (org-element-property :begin block)))
               (end (org-element-property :end block))
               (post-blank (or (org-element-property :post-blank block) 0))
               (first (1+ (line-number-at-pos beg)))
               (last (save-excursion
                       (goto-char end)
                       (- (line-number-at-pos)
                          (if (bolp) (1+ post-blank) 0)
                          1))))
          (when (>= last first)
            (push (cons first last) ranges)))))
    (nreverse ranges)))

(defun org-fmt--headline-lines (ast)
  "Hash table of line numbers where a headline begins in AST."
  (let ((lines (make-hash-table :test #'eql)))
    (org-element-map ast 'headline
      (lambda (headline)
        (puthash (line-number-at-pos (org-element-property :begin headline)) t lines)))
    lines))

(defun org-fmt--buffer-newline ()
  "Newline string matching the current buffer's line-ending style."
  (save-excursion
    (goto-char (point-min))
    (if (and (search-forward "\n" nil t)
             (> (point) 1)
             (eq (char-before (1- (point))) ?\r))
        "\r\n"
      "\n")))

(defun org-fmt--rule-blank-lines ()
  "Normalize blank lines outside literal block bodies.
Runs of two or more blank lines collapse to one, and blank lines at
the start of the buffer are removed.  A headline following content
gets exactly one preceding blank line; a headline following another
headline gets none.  Bodies of src, example, export, comment and
verse blocks, and refused lines, are treated as opaque content."
  (let* ((ast (org-element-parse-buffer))
         (ranges (org-fmt--literal-body-ranges ast))
         (headlines (org-fmt--headline-lines ast))
         (refused (make-hash-table :test #'eql))
         (kinds nil)
         (line 0))
    (dolist (record org-fmt--refusals)
      (puthash (car record) t refused))
    (goto-char (point-min))
    (while (not (eobp))
      (setq line (1+ line))
      (push (cond
             ((or (gethash line refused)
                  (seq-some (lambda (r) (<= (car r) line (cdr r))) ranges))
              'opaque)
             ((looking-at-p "[ \t]*\r?$") 'blank)
             ((gethash line headlines) 'headline)
             (t 'content))
            kinds)
      (forward-line 1))
    (let* ((kinds (vconcat (nreverse kinds)))
           (n (length kinds))
           (ops nil)
           (i 0)
           (prev nil))
      (while (< i n)
        (let ((kind (aref kinds i)))
          (if (eq kind 'blank)
              (let ((start i))
                (while (and (< i n) (eq (aref kinds i) 'blank))
                  (setq i (1+ i)))
                (let* ((len (- i start))
                       (next (and (< i n) (aref kinds i)))
                       (keep (cond
                              ((null prev) 0)
                              ((eq next 'headline)
                               (if (eq prev 'headline) 0 1))
                              (t (min len 1)))))
                  (when (< keep len)
                    (push (list (+ start keep 1) 'delete (+ start keep 1) (+ start len))
                          ops))))
            (when (and (eq kind 'headline)
                       (> i 0)
                       (memq (aref kinds (1- i)) '(content opaque)))
              (push (list (1+ i) 'insert (1+ i)) ops))
            (setq prev kind)
            (setq i (1+ i)))))
      (dolist (op (sort ops (lambda (a b) (> (car a) (car b)))))
        (goto-char (point-min))
        (pcase (cdr op)
          (`(delete ,first ,last)
           (forward-line (1- first))
           (let ((beg (point)))
             (forward-line (1+ (- last first)))
             (delete-region beg (point))))
          (`(insert ,target)
           (forward-line (1- target))
           (insert (org-fmt--buffer-newline))))))))

;;;; R5 Headline spacing

(defun org-fmt--rule-headline-space ()
  "Exactly one space between a headline's star run and its title.
Tag padding and title bytes are preserved verbatim."
  (let ((begs (org-element-map (org-element-parse-buffer) 'headline
                (lambda (hl) (org-element-property :begin hl)))))
    (dolist (beg (sort begs #'>))
      (save-excursion
        (goto-char beg)
        (unless (org-fmt--refused-lines-p beg (line-end-position))
          (when (and (looking-at "\\(\\*+\\) +")
                     (not (string= (match-string 0)
                                   (concat (match-string 1) " "))))
            (replace-match "\\1 ")))))))

;;;; R6 Tables

(defun org-fmt--rule-tables ()
  "Realign every Org table with `org-table-align'.
table.el tables and tables overlapping refused lines are left untouched."
  (let ((tables nil))
    (org-element-map (org-element-parse-buffer) 'table
      (lambda (table)
        (when (eq (org-element-property :type table) 'org)
          (push (list (org-element-property :begin table)
                      (1- (org-element-property
                           :end (car (last (org-element-contents table))))))
                tables))))
    (save-excursion
      (dolist (range (sort tables (lambda (a b) (> (car a) (car b)))))
        (unless (org-fmt--refused-lines-p (car range) (cadr range))
          (goto-char (car range))
          (org-table-align))))))

;;;; Refusals

(defun org-fmt--scan-indented-tables ()
  "Refuse every line of each table whose rows are indented."
  (let (refusals)
    (org-element-map (org-element-parse-buffer) 'table
      (lambda (table)
        (save-excursion
          (goto-char (org-element-property :begin table))
          (let ((lines nil) (indented nil))
            (while (looking-at-p "[ \t]*|")
              (push (line-number-at-pos) lines)
              (when (looking-at-p "[ \t]+|")
                (setq indented t))
              (forward-line 1))
            (when indented
              (dolist (line lines)
                (push (list line "indented table" nil) refusals)))))))
    refusals))

(defun org-fmt--scan-indented-blocks ()
  "Refuse every line of each block whose delimiter lines are indented."
  (let ((literals (org-element-map (org-element-parse-buffer)
                      '(src-block example-block export-block comment-block dynamic-block)
                    (lambda (block)
                      (cons (line-number-at-pos (org-element-property :begin block))
                            (line-number-at-pos (org-element-property :end block))))))
        (case-fold-search t)
        refusals)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^[ \t]+#\\+begin_\\([-_A-Za-z0-9]+\\)" nil t)
        (let ((first (line-number-at-pos (line-beginning-position)))
              (end-re (concat "^[ \t]*#\\+end_" (match-string-no-properties 1)
                              "[ \t]*$")))
          (unless (seq-some (lambda (range) (<= (car range) first (cdr range)))
                            literals)
            (push (list first "indented block delimiter" nil) refusals)
            (when (re-search-forward end-re nil t)
              (let ((last (line-number-at-pos (line-beginning-position))))
                (dotimes (n (- last first 1))
                  (push (list (+ first 1 n) "indented block delimiter" nil)
                        refusals))))))))
    refusals))

(defun org-fmt--scan-indented-fixed-width ()
  "Refuse fixed-width lines with indentation before the colon."
  (let (refusals)
    (org-element-map (org-element-parse-buffer) 'fixed-width
      (lambda (fixed-width)
        (save-excursion
          (goto-char (org-element-property :begin fixed-width))
          (while (looking-at-p "[ \t]*:\\( \\|$\\)")
            (when (looking-at-p "[ \t]+:")
              (push (list (line-number-at-pos) "indented fixed-width" nil)
                    refusals))
            (forward-line 1)))))
    refusals))

(defun org-fmt--scan-interleaved-affiliated ()
  "Refuse affiliated keyword lines repeated with a different keyword between."
  (let ((case-fold-search t)
        refusals)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward (concat "^" org-element--affiliated-re) nil t)
        (goto-char (line-beginning-position))
        (let ((run nil))
          (while (looking-at org-element--affiliated-re)
            (push (cons (upcase (match-string-no-properties 1))
                        (line-number-at-pos))
                  run)
            (forward-line 1))
          (setq run (nreverse run))
          (when (and (not (looking-at-p "[ \t]*$"))
                     (not (looking-at-p "[ \t]*#\\+[-_A-Za-z0-9]+:")))
            (when (seq-some
                   (lambda (key)
                     (let ((lines (mapcar #'cdr (seq-filter (lambda (entry)
                                                              (equal (car entry) key))
                                                            run))))
                       (and (cdr lines)
                            (seq-some (lambda (entry)
                                        (not (equal (car entry) key)))
                                      (seq-subseq run
                                                  (cl-position key run :key #'car
                                                               :test #'equal)
                                                  (1+ (cl-position key run
                                                                   :key #'car
                                                                   :test #'equal
                                                                   :from-end t)))))))
                   (delete-dups (mapcar #'car run)))
              (dolist (entry run)
                (push (list (cdr entry) "interleaved affiliated keyword" nil)
                      refusals)))))))
    refusals))

(defconst org-fmt--known-element-types
  '(org-data section headline paragraph keyword src-block example-block
    export-block quote-block comment-block verse-block special-block
    plain-list item table table-row drawer property-drawer node-property dynamic-block
    planning comment fixed-width horizontal-rule)
  "Element types org-fmt can format safely.")

(defun org-fmt--scan-unknown-elements ()
  "Refuse the whole file when it contains an element of unknown type."
  (let (refusals)
    (org-element-map (org-element-parse-buffer 'element) t
      (lambda (el)
        (unless (stringp el)
          (let ((type (org-element-type el)))
            (unless (memq type org-fmt--known-element-types)
              (push (list (line-number-at-pos (org-element-property :begin el))
                          (format "unknown element type: %s" type)
                          t)
                    refusals))))))
    (nreverse refusals)))

(dolist (scanner '(org-fmt--scan-indented-tables
                   org-fmt--scan-indented-blocks
                   org-fmt--scan-indented-fixed-width
                   org-fmt--scan-interleaved-affiliated
                   org-fmt--scan-unknown-elements))
  (add-to-list 'org-fmt-refusal-scanners scanner))

;;;; R7 Drawer case

(defun org-fmt--rule-drawer-case ()
  "Uppercase drawer and property-drawer delimiter lines.
Node-property lines (`:KEY: value') are preserved verbatim."
  (let ((case-fold-search t))
    (org-element-map (org-element-parse-buffer) '(drawer property-drawer)
      (lambda (dr)
        (let ((begin-line (org-element-property :begin dr))
              (end-line (save-excursion
                          (goto-char (max (point-min)
                                          (1- (org-fmt--content-end dr))))
                          (line-beginning-position))))
          (save-excursion
            (goto-char begin-line)
            (unless (org-fmt--refused-lines-p begin-line (line-end-position))
              (when (looking-at "[ \t]*\\(:[^:\n]+:\\)[ \t]*$")
                (replace-match (upcase (match-string 1)) t nil nil 1))))
          (save-excursion
            (goto-char end-line)
            (unless (org-fmt--refused-lines-p end-line (line-end-position))
              (when (looking-at "[ \t]*\\(:end:\\)[ \t]*$")
                (replace-match ":END:" t nil nil 1)))))))))

;;;; R8 EOF newline

(defun org-fmt--rule-eof-newline ()
  "Ensure the buffer ends with exactly one newline."
  (unless (zerop (buffer-size))
    (save-excursion
      (goto-char (point-max))
      (skip-chars-backward "\n")
      (cond ((= (point) (point-max))
             (insert "\n"))
            ((> (- (point-max) (point)) 1)
             (delete-region (1+ (point)) (point-max)))))))

;;;; Batch CLI

;;;###autoload
(defun org-fmt-buffer ()
  "Format the current buffer with all `org-fmt-rules'."
  (interactive)
  (org-fmt-format-buffer))

(defun org-fmt--cli-parse-args (args)
  "Parse batch CLI ARGS into a plist (:check BOOL :paths LIST)."
  (let ((check nil)
        (paths nil))
    (dolist (arg args)
      (cond
       ((string= arg "--check")
        (setq check t))
       ((string= arg "--"))
       (t (push arg paths))))
    (list :check check :paths (nreverse paths))))

(defun org-fmt--cli-exit-code (check changed errors)
  "Exit code for a batch run: 2 when ERRORS, 1 when CHECK and CHANGED, else 0."
  (cond (errors 2)
        ((and check changed) 1)
        (t 0)))

(defun org-fmt--org-files-under (dir)
  "All .org files under DIR, recursively, skipping dot-directories."
  (let ((files nil))
    (dolist (entry (directory-files dir t))
      (let ((base (file-name-nondirectory entry)))
        (unless (member base '("." ".."))
          (cond
           ((file-directory-p entry)
            (unless (string-prefix-p "." base)
              (setq files (nconc files (org-fmt--org-files-under entry)))))
           ((string-suffix-p ".org" base)
            (setq files (nconc files (list entry))))))))
    files))

(defun org-fmt--cli-format-one (file check)
  "Format FILE, printing a status line.
With CHECK non-nil, do not write.  Returns one of the symbols
formatted, unchanged, would-format, refused or unreadable."
  (cond
   ((not (string-suffix-p ".org" file))
    (message "%s: UNREADABLE not an Org file" file)
    'unreadable)
   ((not (file-readable-p file))
    (message "%s: UNREADABLE cannot read file" file)
    'unreadable)
   (t
    (let ((result (condition-case err
                      (org-fmt-format-file file check)
                    (org-fmt-refusal
                     (dolist (r (cadr err))
                       (message "%s:%d: %s" file (car r) (nth 1 r)))
                     'refused)
                    (file-error
                     (message "%s: UNREADABLE %s" file (error-message-string err))
                     'unreadable)
                    (error
                     (message "%s: UNREADABLE %s" file (error-message-string err))
                     'unreadable))))
      (if (symbolp result)
          result
        (let ((changed (plist-get result :changed))
              (refusals (plist-get result :refusals)))
          (cond
           (refusals
            (dolist (r refusals)
              (message "%s:%d: %s" file (car r) (nth 1 r)))
            (message "%s: REFUSED" file)
            'refused)
           ((and changed check)
            (message "%s: would-format" file)
            'would-format)
           (changed
            (message "%s: formatted" file)
            'formatted)
           (t
            (message "%s: unchanged" file)
            'unchanged))))))))

(defun org-fmt-batch-cli ()
  "Batch entry point formatting files from `command-line-args-left'.
\\--check checks without writing; remaining args are .org files or
directories, which are recursed for .org files skipping
dot-directories.  Exits via `kill-emacs': 0 when all files are
clean or were formatted, 1 when --check found changes, 2 on any
refusal or unreadable file."
  (let* ((args (org-fmt--cli-parse-args command-line-args-left))
         (check (plist-get args :check))
         (files nil)
         (changed nil)
         (errors nil))
    (dolist (path (plist-get args :paths))
      (if (file-directory-p path)
          (setq files (nconc files (org-fmt--org-files-under path)))
        (setq files (nconc files (list path)))))
    (dolist (file files)
      (pcase (org-fmt--cli-format-one file check)
        ((or 'refused 'unreadable) (setq errors t))
        ((or 'formatted 'would-format) (setq changed t))))
    (kill-emacs (org-fmt--cli-exit-code check changed errors))))

;;;; Pipeline

(defun org-fmt-corpus-check (dir &optional exclude)
  "Run the G3 corpus gate over every .org file under DIR.
Files whose name matches EXCLUDE (a regexp) are skipped.  Each
file is formatted in memory; the gate asserts idempotence and,
when `org-fmt-oracle-equal-p' is fbound, AST equivalence of
input and output.  Returns a report plist (:files :changed
:idempotence-failures :oracle-failures :refusals) and prints a
readable summary."
  (let ((files (seq-remove (lambda (f)
                             (and exclude (string-match-p exclude f)))
                           (org-fmt--org-files-under (expand-file-name dir))))
        (oracle-p (fboundp 'org-fmt-oracle-equal-p))
        (changed nil)
        (idempotence-failures nil)
        (oracle-failures nil)
        (refusals nil))
    (dolist (file files)
      (let ((org-fmt--refusals nil)
            (input (with-temp-buffer
                     (insert-file-contents file)
                     (buffer-string))))
        (condition-case err
            (let ((once (org-fmt-format-string input)))
              (when org-fmt--refusals
                (push (cons file (mapcar (lambda (r) (nth 1 r)) org-fmt--refusals))
                      refusals))
              (unless (equal once (org-fmt-format-string once))
                (push file idempotence-failures))
              (unless (equal input once)
                (push file changed))
              (when (and oracle-p (not (funcall #'org-fmt-oracle-equal-p input once)))
                (push file oracle-failures)))
          (error
           (push (cons file (list (error-message-string err))) refusals)))))
    (let ((report (list :files (length files)
                        :changed (nreverse changed)
                        :idempotence-failures (nreverse idempotence-failures)
                        :oracle-failures (nreverse oracle-failures)
                        :refusals (nreverse refusals))))
      (message "G3 corpus check: %s" dir)
      (message "  files: %d, changed: %d, idempotence failures: %d, oracle failures: %d (%s), refused: %d"
               (plist-get report :files)
               (length (plist-get report :changed))
               (length (plist-get report :idempotence-failures))
               (length (plist-get report :oracle-failures))
               (if oracle-p "oracle: checked" "oracle: skipped")
               (length (plist-get report :refusals)))
      (dolist (f (plist-get report :idempotence-failures))
        (message "  idempotence: %s" f))
      (dolist (f (plist-get report :oracle-failures))
        (message "  oracle: %s" f))
      (dolist (pair (plist-get report :refusals))
        (dolist (reason (cdr pair))
          (message "  refused: %s: %s" (car pair) reason)))
      report)))

(defun org-fmt--run-ert-tests (prefix)
  "Run every ERT test whose name starts with PREFIX.
Returns (PASSED-COUNT . FAILED-TEST-SYMBOLS)."
  (let ((tests nil)
        (passed 0)
        (failed nil))
    (mapatoms
     (lambda (sym)
       (when (and (string-prefix-p prefix (symbol-name sym))
                  (get sym 'ert--test))
         (push sym tests))))
    (dolist (test (sort tests (lambda (a b) (string< (symbol-name a) (symbol-name b)))))
      (let ((result (ert-run-test (ert-get-test test))))
        (if (ert-test-result-type-p result :passed)
            (setq passed (1+ passed))
          (push test failed))))
    (cons passed (nreverse failed))))

(defun org-fmt-pipeline-run (&optional corpus-dir)
  "Run the full verification pipeline: G1 ERT tests, G2 fixtures, G3 corpus.
CORPUS-DIR defaults to ~/garden.  Prints a sectioned summary; in
batch mode exits via `kill-emacs' with 0 only when every gate
passed.  Returns a report plist (:g1 :g2 :g3)."
  (require 'ert)
  (require 'org-fmt-test)
  (let* ((corpus-dir (or corpus-dir "~/garden"))
         (g1 (org-fmt--run-ert-tests "org-fmt-test-"))
         (g2 (org-fmt-test-run-all-fixtures))
         (g3 (org-fmt-corpus-check corpus-dir
                                   (concat "\\`"
                                           (regexp-quote org-fmt-test-fixture-dir))))
         (g3-bad (or (plist-get g3 :idempotence-failures)
                     (plist-get g3 :oracle-failures)
                     (plist-get g3 :refusals)))
         (clean (and (null (cdr g1)) (null (cdr g2)) (null g3-bad))))
    (message "G1 ERT: %d passed, %d failed%s"
             (car g1) (length (cdr g1))
             (if (cdr g1) (format " %s" (cdr g1)) ""))
    (message "G2 fixtures: %d passed, %d failed%s"
             (car g2) (length (cdr g2))
             (if (cdr g2) (format " %s" (mapcar #'car (cdr g2))) ""))
    (message "G3 corpus: %s" (if g3-bad "FAILED" "clean"))
    (when noninteractive
      (kill-emacs (if clean 0 1)))
    (list :g1 g1 :g2 g2 :g3 g3)))

(provide 'org-fmt)
;;; org-fmt.el ends here
