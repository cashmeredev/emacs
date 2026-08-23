;;; garden-core.el --- garden model -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defvar denote-directory)
(declare-function org-update-all-dblocks "org")

(defgroup garden nil "A cute Denote-based digital garden." :group 'denote)

(defcustom garden-directory (expand-file-name "~/garden/")
  "Directory holding the garden's Denote notes."
  :type 'directory :group 'garden)

(defcustom garden-data-file (expand-file-name ".garden/tags.eld" garden-directory)
  "File persisting the topic/meta overrides for keywords."
  :type 'file :group 'garden)

(defcustom garden-meta-frequency 0.30
  "Fraction of notes a keyword must reach to count as a meta tag."
  :type 'number :group 'garden)

(defcustom garden-suggest-excluded-tags '("fleet" "capture")
  "Status tags never offered by `garden-suggest-tags'."
  :type '(repeat string) :group 'garden)

(cl-defstruct garden-note
  "A garden note parsed from a Denote file." id title keywords file links)

(defvar garden--notes nil
  "Hash table of note id to `garden-note', or nil before the first build.")
(defvar garden--backlinks nil
  "Hash table of note id to the ids linking to it.")
(defvar garden--keyword-counts nil
  "Cached hash table of keyword to number of notes carrying it.")
(defvar garden--meta-overrides nil
  "Alist of keyword to explicit meta flag, loaded from `garden-data-file'.")
(defvar garden--suggest-cache (make-hash-table :test 'equal)
  "Cache of file to (MTIME . SUGGESTIONS) for `garden-suggest-tags'.")

(defconst garden--id-regexp "\\`\\([0-9]\\{8\\}T[0-9]\\{6\\}\\)"
  "Regexp matching the Denote identifier at the start of a file name.")
(defconst garden--link-regexp "\\[\\[denote:\\([0-9]\\{8\\}T[0-9]\\{6\\}\\)"
  "Regexp matching the target id of a denote link.")

(defun garden--note-files ()
  "Return all Denote-named org files in `garden-directory'."
  (directory-files garden-directory t "\\`[0-9]\\{8\\}T[0-9]\\{6\\}.*\\.org\\'"))

(defun garden--file-id (file)
  "Return the Denote identifier of FILE, or nil."
  (let ((base (file-name-nondirectory file)))
    (when (string-match garden--id-regexp base) (match-string 1 base))))

(defun garden--file-keywords (file)
  "Return the keywords encoded in FILE's name, minus provenance tags."
  (let ((base (file-name-nondirectory file)))
    (when (string-match "__\\([a-zA-Z0-9_-]+\\)\\.org\\'" base)
      (seq-remove (lambda (k) (member k '("wiki" "")))
                  (split-string (match-string 1 base) "_" t)))))

(defun garden--file-title (file)
  "Return the #+title of FILE, falling back to its base name."
  (with-temp-buffer
    (insert-file-contents file nil 0 2000)
    (goto-char (point-min))
    (if (re-search-forward "^#\\+title:[ \t]*\\(.*\\)$" nil t)
        (string-trim (match-string 1))
      (file-name-base file))))

(defun garden--file-links (file id)
  "Return the ids FILE links to, excluding ID itself."
  (let ((links '()))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (while (re-search-forward garden--link-regexp nil t)
        (let ((target (match-string 1)))
          (unless (equal target id) (push target links)))))
    (delete-dups (nreverse links))))

(defun garden-build ()
  "Rebuild the in-memory note index from `garden-directory'."
  (let ((notes (make-hash-table :test 'equal)))
    (dolist (file (garden--note-files))
      (let ((id (garden--file-id file)))
        (when id
          (puthash id (make-garden-note :id id
                                        :title (garden--file-title file)
                                        :keywords (garden--file-keywords file)
                                        :file file
                                        :links (garden--file-links file id))
                   notes))))
    (let ((backlinks (make-hash-table :test 'equal)))
      (maphash (lambda (id note)
                 (dolist (target (garden-note-links note))
                   (when (gethash target notes)
                     (push id (gethash target backlinks)))))
               notes)
      (setq garden--notes notes
            garden--backlinks backlinks
            garden--keyword-counts nil))
    (clrhash garden--suggest-cache)
    (garden--load-overrides)
    garden--notes))

(defun garden-notes ()
  "Return the note index, building it on first use."
  (or garden--notes (garden-build)))

(defun garden-note (id)
  "Return the `garden-note' with ID, or nil."
  (gethash id (garden-notes)))

(defun garden-backlinks (id)
  "Return the ids of notes linking to ID."
  (garden-notes)
  (gethash id garden--backlinks))

(defun garden-internal-links (note)
  "Return NOTE's outgoing links that resolve to garden notes."
  (seq-filter #'garden-note (garden-note-links note)))

(defun garden-degree (id)
  "Return the total number of links in and out of note ID."
  (let ((note (garden-note id)))
    (+ (length (garden-internal-links note))
       (length (garden-backlinks id)))))

(defun garden-all-ids ()
  "Return the ids of all notes in the garden."
  (let (ids) (maphash (lambda (id _n) (push id ids)) (garden-notes)) ids))

(defun garden-note-count ()
  "Return the number of notes in the garden."
  (hash-table-count (garden-notes)))

(defun garden-link-count ()
  "Return the number of internal links across all notes."
  (let ((s 0))
    (maphash (lambda (_id note) (setq s (+ s (length (garden-internal-links note))))) (garden-notes))
    s))

(defun garden-orphans ()
  "Return the ids of notes with no links in or out."
  (seq-filter (lambda (id) (zerop (garden-degree id))) (garden-all-ids)))

(defun garden-hubs (&optional n)
  "Return the N (default 6) best-connected note ids, descending."
  (seq-take (seq-sort-by #'garden-degree #'>
                         (seq-filter (lambda (id) (> (garden-degree id) 0)) (garden-all-ids)))
            (or n 6)))

(defun garden-recent (&optional n)
  "Return the N (default 6) most recent note ids."
  (seq-take (seq-sort #'string> (garden-all-ids)) (or n 6)))

(defun garden-keyword-counts ()
  "Return a hash table of keyword to note count, cached per build."
  (or garden--keyword-counts
      (let ((counts (make-hash-table :test 'equal)))
        (maphash (lambda (_id note)
                   (dolist (k (garden-note-keywords note))
                     (puthash k (1+ (gethash k counts 0)) counts)))
                 (garden-notes))
        (setq garden--keyword-counts counts))))

(defun garden-keywords-sorted ()
  "Return an alist of (KEYWORD . COUNT) sorted by descending count."
  (let (alist)
    (maphash (lambda (k c) (push (cons k c) alist)) (garden-keyword-counts))
    (seq-sort-by #'cdr #'> alist)))

(defun garden-meta-tag-p (keyword)
  "Return non-nil when KEYWORD is a meta tag rather than a topic.
Overrides in `garden--meta-overrides' win; otherwise a keyword is
meta when it appears in at least `garden-meta-frequency' of notes."
  (let ((ov (assoc keyword garden--meta-overrides)))
    (if ov (cdr ov)
      (>= (/ (float (gethash keyword (garden-keyword-counts) 0))
             (max 1 (garden-note-count)))
          garden-meta-frequency))))

(defun garden-topic-keywords ()
  "Return the (KEYWORD . COUNT) alist of topic keywords."
  (seq-remove (lambda (kc) (garden-meta-tag-p (car kc))) (garden-keywords-sorted)))

(defun garden-meta-keywords ()
  "Return the (KEYWORD . COUNT) alist of meta keywords."
  (seq-filter (lambda (kc) (garden-meta-tag-p (car kc))) (garden-keywords-sorted)))

(defun garden-notes-with-keyword (keyword)
  "Return the notes tagged with KEYWORD, sorted by title."
  (let (acc)
    (maphash (lambda (_id note)
               (when (member keyword (garden-note-keywords note)) (push note acc)))
             (garden-notes))
    (seq-sort-by #'garden-note-title #'string< acc)))

(defun garden--suggest-candidates (current)
  "Return suggestible keywords: all topics not in CURRENT."
  (seq-remove (lambda (k)
                (or (member k current)
                    (member k garden-suggest-excluded-tags)
                    (garden-meta-tag-p k)))
              (mapcar #'car (garden-keywords-sorted))))

(defun garden--count-matches (regexp text cap)
  "Count occurrences of REGEXP in TEXT, stopping at CAP."
  (let ((start 0) (hits 0))
    (while (and (< hits cap) (string-match regexp text start))
      (setq hits (1+ hits))
      (setq start (match-end 0)))
    hits))

(defun garden--cooccurrence-counts (topics id)
  "Tally keywords of notes other than ID that share a tag in TOPICS."
  (let ((counts (make-hash-table :test 'equal)))
    (when topics
      (maphash (lambda (other-id note)
                 (unless (equal other-id id)
                   (let ((kws (garden-note-keywords note)))
                     (when (seq-intersection topics kws)
                       (dolist (k kws)
                         (puthash k (1+ (gethash k counts 0)) counts))))))
               (garden-notes)))
    counts))

(defun garden--suggest-score (keyword title content linked cooc)
  "Score KEYWORD against TITLE, CONTENT, LINKED keywords and COOC tallies."
  (let ((regexp (concat "\\b" (regexp-quote keyword) "\\b")))
    (+ (if (string-match-p regexp title) 3 0)
       (garden--count-matches regexp content 5)
       (* 2 (seq-count (lambda (k) (equal k keyword)) linked))
       (min 3 (gethash keyword cooc 0)))))

(defun garden--compute-suggestions (file limit)
  "Compute up to LIMIT suggested tags for FILE, best first."
  (let* ((id (garden--file-id file))
         (note (and id (garden-note id)))
         (current (garden--file-keywords file))
         (topics (seq-difference current garden-suggest-excluded-tags))
         (title (downcase (garden--file-title file)))
         (content (downcase (with-temp-buffer (insert-file-contents file) (buffer-string))))
         (linked (and note
                      (seq-mapcat (lambda (target)
                                    (let ((n (garden-note target)))
                                      (and n (garden-note-keywords n))))
                                  (garden-note-links note))))
         (cooc (garden--cooccurrence-counts topics id))
         (scored (seq-keep (lambda (k)
                             (let ((score (garden--suggest-score k title content linked cooc)))
                               (when (> score 0) (cons k score))))
                           (garden--suggest-candidates current))))
    (mapcar #'car (seq-take (seq-sort-by #'cdr #'> scored) limit))))

(defun garden-suggest-tags (file &optional limit)
  "Return up to LIMIT (default 3) suggested topic tags for FILE.
Results are cached per file modification time."
  (let ((mtime (file-attribute-modification-time (file-attributes file)))
        (cached (gethash file garden--suggest-cache)))
    (if (and cached (equal (car cached) mtime))
        (cdr cached)
      (let ((tags (garden--compute-suggestions file (or limit 3))))
        (puthash file (cons mtime tags) garden--suggest-cache)
        tags))))

(defun garden--load-overrides ()
  "Load keyword meta overrides from `garden-data-file'."
  (setq garden--meta-overrides
        (when (file-exists-p garden-data-file)
          (with-temp-buffer
            (insert-file-contents garden-data-file)
            (ignore-errors (read (current-buffer)))))))

(defun garden--save-overrides ()
  "Persist keyword meta overrides to `garden-data-file'."
  (make-directory (file-name-directory garden-data-file) t)
  (with-temp-file garden-data-file (prin1 garden--meta-overrides (current-buffer))))

(defun garden-toggle-meta (keyword)
  "Flip KEYWORD between topic and meta, persisting the override."
  (setf (alist-get keyword garden--meta-overrides nil nil #'equal)
        (not (garden-meta-tag-p keyword)))
  (garden--save-overrides))

(defun garden-refresh ()
  "Rebuild the garden index."
  (interactive)
  (garden-build))

(defun garden-delete-note (id)
  "Move the note with ID to the system trash after confirmation.
Kills any buffer visiting it and rebuilds the index.  Returns
non-nil when the note was actually deleted."
  (let* ((note (garden-note id))
         (file (garden-note-file note)))
    (when (yes-or-no-p (format "Move “%s” to the trash? " (garden-note-title note)))
      (when-let* ((buf (find-buffer-visiting file)))
        (kill-buffer buf))
      (let ((delete-by-moving-to-trash t))
        (delete-file file t))
      (garden-build)
      (message "garden: trashed %s" (garden-note-title note))
      t)))

(defun garden-completion-table (candidates annotate)
  "Build a completion table over CANDIDATES with annotations.
ANNOTATE is called with a candidate string and returns the
annotation suffix.  Candidate order is preserved in completion
UIs that honor `display-sort-function'."
  (lambda (string pred action)
    (if (eq action 'metadata)
        `(metadata (annotation-function . ,annotate)
                   (display-sort-function . identity)
                   (cycle-sort-function . identity))
      (complete-with-action action candidates string pred))))

(defun garden-note-annotation (note)
  "Return a completion annotation for NOTE: its date and keywords."
  (let ((id (garden-note-id note)))
    (propertize (format "  %s-%s-%s · %s"
                        (substring id 0 4) (substring id 4 6) (substring id 6 8)
                        (string-join (garden-note-keywords note) " "))
                'face 'completions-annotations)))

(defun garden--dblock-files ()
  "Return the note files containing denote dynamic blocks."
  (seq-filter (lambda (f)
                (with-temp-buffer
                  (insert-file-contents f)
                  (goto-char (point-min))
                  (re-search-forward "^#\\+BEGIN: denote" nil t)))
              (garden--note-files)))

(defun garden-update-indexes ()
  "Refresh the denote dynamic blocks in every note that has one."
  (interactive)
  (require 'denote)
  (require 'denote-org)
  (let ((denote-directory (file-name-as-directory (expand-file-name garden-directory)))
        (updated 0))
    (dolist (file (garden--dblock-files))
      (with-current-buffer (find-file-noselect file)
        (org-update-all-dblocks)
        (when (buffer-modified-p) (save-buffer) (setq updated (1+ updated)))))
    (when (called-interactively-p 'interactive)
      (message "garden: refreshed link indexes in %d note(s)" updated))
    updated))

(defun garden--before-save-update-dblocks ()
  "Update denote dynamic blocks before saving a garden note."
  (when (and (derived-mode-p 'org-mode)
             buffer-file-name
             (string-prefix-p (file-name-as-directory (expand-file-name garden-directory))
                              (expand-file-name buffer-file-name))
             (save-excursion (goto-char (point-min))
                             (re-search-forward "^#\\+BEGIN: denote" nil t)))
    (require 'denote-org)
    (let ((denote-directory (file-name-as-directory (expand-file-name garden-directory))))
      (org-update-all-dblocks))))

(define-minor-mode garden-auto-index-mode
  "Keep denote dynamic blocks in garden notes fresh on save."
  :global t
  (if garden-auto-index-mode
      (add-hook 'before-save-hook #'garden--before-save-update-dblocks)
    (remove-hook 'before-save-hook #'garden--before-save-update-dblocks)))

(provide 'garden-core)
;;; garden-core.el ends here
