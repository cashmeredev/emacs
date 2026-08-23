;;; garden-publish.el --- publish the garden to the zola site -*- lexical-binding: t; -*-

(require 'garden-core)
(require 'subr-x)

(declare-function denote-publish-to-md "denote-publish")
(declare-function org-publish "ox-publish")

(defvar denote-directory)
(defvar org-export-with-broken-links)
(defvar org-export-use-babel)
(defvar org-publish-project-alist)

(defcustom garden-publish-site-directory (expand-file-name "~/cashmere.rs/") "Root directory of the Zola site checkout." :type 'directory :group 'garden)
(defcustom garden-publish-wiki-subdir "content/wiki" "Wiki output directory relative to the site root." :type 'string :group 'garden)

(defun garden-publish--clean-generated (dir)
  "Delete all generated Markdown files in DIR except _index.md."
  (dolist (old (directory-files dir t "\\.md\\'"))
    (unless (equal (file-name-nondirectory old) "_index.md") (delete-file old))))

(defun garden-publish--ensure-index (dir title)
  "Create an _index.md with TITLE in DIR unless one already exists."
  (let ((idx (expand-file-name "_index.md" dir)))
    (unless (file-exists-p idx)
      (with-temp-file idx (insert (format "+++\ntitle = %S\nsort_by = \"date\"\n+++\n" title))))))

(defun garden-publish--filename-slug (file)
  "Return the slug part of the denote FILE name, or nil."
  (let ((base (file-name-nondirectory file)))
    (when (string-match "\\`[0-9]\\{8\\}T[0-9]\\{6\\}--\\([a-z0-9-]+\\)\\(?:__[a-z0-9_-]+\\)?\\.org\\'" base)
      (match-string 1 base))))

(defun garden-publish--slug-map ()
  "Return a hash table mapping note ids to unique URL slugs."
  (let ((map (make-hash-table :test 'equal))
        (seen (make-hash-table :test 'equal)))
    (dolist (file (sort (garden--note-files) #'string<))
      (let* ((id (garden--file-id file))
             (base (garden-publish--filename-slug file))
             (kw (car (garden--file-keywords file))))
        (when (and id base)
          (let ((slug base))
            (when (gethash slug seen)
              (setq slug (if (and kw (not (gethash (concat base "-" kw) seen)))
                             (concat base "-" kw)
                           (let ((n 2))
                             (while (gethash (format "%s-%d" base n) seen) (setq n (1+ n)))
                             (format "%s-%d" base n)))))
            (puthash slug t seen)
            (puthash id slug map)))))
    map))

(defcustom garden-publish-exclude-keywords '("draft" "private" "noexport") "File keywords that exclude a note from publishing." :type '(repeat string) :group 'garden)

(defun garden-publish--exclude-ids ()
  "Return a hash table of note ids that must not be published."
  (let ((ex (make-hash-table :test 'equal)))
    (dolist (file (garden--note-files))
      (when (seq-intersection garden-publish-exclude-keywords (garden--file-keywords file))
        (puthash (garden--file-id file) t ex)))
    ex))

(defun garden-publish--rewrite-denote-links (map)
  "Rewrite exported denote links in the current buffer using MAP.
MAP maps note ids to wiki slugs; links to unknown ids are reduced
to their description."
  (goto-char (point-min))
  (while (re-search-forward
          "<a href=\"denote:\\([0-9]\\{8\\}T[0-9]\\{6\\}\\)\\(?:::[^\"]*\\)?\\(?:\\.html\\)?\"[^>]*>\\(\\(?:.\\|\n\\)*?\\)</a>"
          nil t)
    (let* ((tid (match-string 1))
           (desc (match-string 2))
           (tslug (gethash tid map)))
      (replace-match (if tslug (format "<a href=\"/wiki/%s/\">%s</a>" tslug desc) desc) t t)))
  (goto-char (point-min))
  (while (re-search-forward
          "\\[\\([^]]*\\)\\](denote:\\([0-9]\\{8\\}T[0-9]\\{6\\}\\)[^)]*)"
          nil t)
    (let* ((desc (match-string 1))
           (tslug (gethash (match-string 2) map)))
      (replace-match (if tslug (format "[%s](/wiki/%s/)" desc tslug) desc) t t))))

(defun garden-publish--fix-wiki-frontmatter ()
  "Move top-level tags/category in YAML front matter into a Zola taxonomies block.
This is done in the current buffer."
  (save-excursion
    (goto-char (point-min))
    (when (looking-at "^---$")
      (let ((start (point)))
        (forward-line)
        (when (re-search-forward "^---$" nil t)
          (let ((end (point)))
            (save-restriction
              (narrow-to-region start end)
              (goto-char (point-min))
              (when (re-search-forward "^\\(tags:\\|category:\\)" nil t)
                (beginning-of-line)
                (insert "taxonomies:\n")
                (goto-char (point-min))
                (while (re-search-forward "^tags:" nil t)
                  (replace-match "  tags:"))
                (goto-char (point-min))
                (while (re-search-forward "^category:" nil t)
                  (replace-match "  categories:"))))))))))

(defun garden-publish--fix-wiki (dir map exclude)
  "Post-process exported wiki files in DIR.
Rewrite denote links using the id-to-slug table MAP, delete files
whose id is in the EXCLUDE table, strip PGP blocks and TODO
keywords, fix front matter taxonomies, and rename each file to its slug."
  (dolist (md (directory-files dir t "\\.md\\'"))
    (let* ((base (file-name-nondirectory md))
           (id (and (string-match "\\`\\([0-9]\\{8\\}T[0-9]\\{6\\}\\)" base) (match-string 1 base)))
           (slug (and id (gethash id map))))
      (cond
       ((and id (gethash id exclude)) (delete-file md))
       ((null slug) nil)
       (t
        (with-temp-buffer
          (insert-file-contents md)
          (garden-publish--fix-wiki-frontmatter)
          (goto-char (point-min))
          (while (re-search-forward "\\(?:-----\\|&ndash;&mdash;\\)?BEGIN PGP\\(?:.\\|\n\\)*?END PGP[^&\n-]*\\(?:-----\\|&ndash;&mdash;\\)?" nil t)
            (replace-match ""))
          (goto-char (point-min))
          (while (re-search-forward "^\\(#+\\)[ \t]+\\(?:TODO\\|DONE\\|NEXT\\|WAIT[A-Z]*\\|CANCELL?ED\\|HOLD\\|STRT\\)[ \t]+" nil t)
            (replace-match "\\1 "))
          (garden-publish--rewrite-denote-links map)
          (write-region (point-min) (point-max) md nil 'silent))
        (unless (equal base (concat slug ".md"))
          (rename-file md (expand-file-name (concat slug ".md") dir) t)))))))

;;;###autoload
(defun garden-publish-wiki ()
  "Export all garden notes to Markdown in the site wiki directory."
  (interactive)
  (require 'denote)
  (require 'ox-gfm)
  (require 'denote-publish)
  (let* ((out (expand-file-name garden-publish-wiki-subdir garden-publish-site-directory))
         (denote-directory (expand-file-name garden-directory))
         (org-export-with-broken-links t)
         (org-export-use-babel nil)
         (make-backup-files nil)
         (org-publish-project-alist
          `(("garden-wiki"
             :base-directory ,(expand-file-name garden-directory)
             :publishing-directory ,out
             :publishing-function denote-publish-to-md
             :recursive nil
             :exclude-tags ("noexport" "draft")
             :with-toc nil))))
    (make-directory out t)
    (garden-publish--clean-generated out)
    (garden-publish--ensure-index out "Wiki")
    (garden-build)
    (org-publish "garden-wiki" t)
    (garden-publish--fix-wiki out (garden-publish--slug-map) (garden-publish--exclude-ids))
    (message "garden: published wiki to %s" out)))

(defcustom garden-publish-blog-source (expand-file-name "~/garden/posts/")
  "Directory holding the Org source files for blog posts."
  :type 'directory :group 'garden)

(defcustom garden-publish-pages-source (expand-file-name "~/garden/pages/")
  "Directory holding the Org source files for standalone pages."
  :type 'directory :group 'garden)

(defcustom garden-publish-images-source (expand-file-name "~/garden/posts/images/")
  "Directory holding images referenced by blog posts."
  :type 'directory :group 'garden)

(defcustom garden-publish-blog-subdir "content/blog" "Blog output directory relative to the site root." :type 'string :group 'garden)

(declare-function org-export-as "ox")

(defun garden-publish--parse-post (file)
  "Parse the Org post FILE into a (PROPERTIES . BODY) pair."
  (let ((props nil) (body-start 0) (i 0)
        (lines (with-temp-buffer (insert-file-contents file) (split-string (buffer-string) "\n"))))
    (catch 'done
      (dolist (line lines)
        (cond
         ((string-match "\\`#\\+\\([A-Za-z_]+\\):[ \t]*\\(.*\\)\\'" line)
          (push (cons (downcase (match-string 1 line)) (string-trim (match-string 2 line))) props))
         ((string-empty-p (string-trim line)) nil)
         (t (setq body-start i) (throw 'done nil)))
        (setq i (1+ i))))
    (cons props (string-join (nthcdr body-start lines) "\n"))))

(defun garden-publish--strip-toc (body)
  "Return BODY with any Table of Contents section removed."
  (let ((out '()) (skip nil))
    (dolist (line (split-string body "\n"))
      (cond
       ((string-match-p "\\`\\*+ +Table of Contents[ \t]*\\'" line) (setq skip t))
       ((and skip (string-match-p "\\`\\*+ " line)) (setq skip nil) (push line out))
       (skip nil)
       (t (push line out))))
    (string-join (nreverse out) "\n")))

(defun garden-publish--clean-slug (s)
  "Normalize string S into a lowercase URL slug."
  (let ((x (replace-regexp-in-string "[^a-z0-9]+" "-" (downcase (string-trim s)))))
    (replace-regexp-in-string "\\(?:\\`-+\\|-+\\'\\)" "" x)))

(defun garden-publish--org-to-gfm (body)
  "Export the Org string BODY to GitHub-flavored Markdown."
  (require 'ox-gfm)
  (with-temp-buffer
    (insert body)
    (org-mode)
    (let ((org-export-with-broken-links t)
          (org-export-use-babel nil))
      (org-export-as 'gfm nil nil t '(:with-toc nil :with-section-numbers nil)))))

(defun garden-publish--blog-one (file out-dir)
  "Convert the blog post FILE to Markdown in OUT-DIR unless drafted."
  (let* ((parsed (garden-publish--parse-post file))
         (props (car parsed))
         (body (cdr parsed)))
    (unless (equal (cdr (assoc "status" props)) "draft")
      (let* ((title (or (cdr (assoc "title" props)) (file-name-base file)))
             (slug (garden-publish--clean-slug (or (cdr (assoc "slug" props)) (file-name-base file))))
             (date (let ((d (cdr (assoc "date" props)))) (and d (substring d 0 (min 10 (length d))))))
             (tags (let ((tg (cdr (assoc "tags" props)))) (and tg (split-string tg "[ ,]+" t))))
             (desc (cdr (assoc "description" props)))
             (md (garden-publish--org-to-gfm
                  (garden-publish--strip-toc
                   (replace-regexp-in-string "/content/images/" "/images/" body))))
             (fm (concat "+++\n"
                         (format "title = %S\n" title)
                         (or (when date (format "date = \"%s\"\n" date)) "")
                         (or (when (and desc (not (string-empty-p desc)))
                               (format "description = %S\n" desc))
                             "")
                         (or (when tags
                               (concat "[taxonomies]\n"
                                       (format "tags = [%s]\n"
                                               (mapconcat (lambda (x) (format "%S" x)) tags ", "))))
                             "")
                         "+++\n\n")))
        (with-temp-file (expand-file-name (concat slug ".md") out-dir)
          (insert fm md))))))

;;;###autoload
(defun garden-publish-blog ()
  "Export all blog posts and images to the site blog directory."
  (interactive)
  (let ((out (expand-file-name garden-publish-blog-subdir garden-publish-site-directory))
        (postsrc garden-publish-blog-source)
        (imgsrc garden-publish-images-source)
        (imgdst (expand-file-name "static/images" garden-publish-site-directory)))
    (make-directory out t)
    (garden-publish--clean-generated out)
    (garden-publish--ensure-index out "Blog")
    (if (file-directory-p postsrc)
        (dolist (f (directory-files postsrc t "\\.org\\'"))
          (garden-publish--blog-one f out))
      (message "garden: blog source missing, skipping posts"))
    (when (file-directory-p imgsrc)
      (make-directory imgdst t)
      (copy-directory imgsrc imgdst t t t))
    (message "garden: published blog to %s" out)))

(defcustom garden-publish-pages-skip '("wiki-archive") "Page slugs that are never published." :type '(repeat string) :group 'garden)

(defcustom garden-publish-pages-manifest (expand-file-name ".garden/pages.eld" garden-directory) "File recording the page files written by the last publish run." :type 'file :group 'garden)

(defun garden-publish--load-pages-manifest ()
  "Read the pages manifest file and return its entries, or nil."
  (when (file-exists-p garden-publish-pages-manifest)
    (with-temp-buffer
      (insert-file-contents garden-publish-pages-manifest)
      (ignore-errors (read (current-buffer))))))

(defun garden-publish--save-pages-manifest (entries)
  "Write ENTRIES to the pages manifest file."
  (make-directory (file-name-directory garden-publish-pages-manifest) t)
  (with-temp-file garden-publish-pages-manifest (prin1 entries (current-buffer))))

(defun garden-publish--page-one (file out-dir)
  "Convert the page FILE to Markdown in OUT-DIR and return its name."
  (let* ((parsed (garden-publish--parse-post file))
         (props (car parsed))
         (body (cdr parsed))
         (slug (garden-publish--clean-slug (or (cdr (assoc "slug" props)) (file-name-base file)))))
    (unless (or (equal (cdr (assoc "status" props)) "draft")
                (member slug garden-publish-pages-skip))
      (let* ((title (or (cdr (assoc "title" props)) (file-name-base file)))
             (desc (cdr (assoc "description" props)))
             (md (garden-publish--org-to-gfm
                  (garden-publish--strip-toc
                   (replace-regexp-in-string "/content/images/" "/images/" body))))
             (fm (concat "+++\n"
                         (format "title = %S\n" title)
                         (or (when (and desc (not (string-empty-p desc)))
                               (format "description = %S\n" desc))
                             "")
                         "+++\n\n")))
        (with-temp-file (expand-file-name (concat slug ".md") out-dir)
          (insert fm md))
        (concat slug ".md")))))

;;;###autoload
(defun garden-publish-pages ()
  "Export all standalone pages and remove stale ones from the site."
  (interactive)
  (let ((out (expand-file-name "content" garden-publish-site-directory))
        (src garden-publish-pages-source)
        (written '()))
    (make-directory out t)
    (if (file-directory-p src)
        (dolist (f (directory-files src t "\\.org\\'"))
          (let ((name (garden-publish--page-one f out)))
            (when name (push name written))))
      (message "garden: pages source missing, skipping pages"))
    (let ((stale (seq-difference (garden-publish--load-pages-manifest) written)))
      (dolist (name stale)
        (let ((md (expand-file-name name out)))
          (when (file-exists-p md) (delete-file md))))
      (garden-publish--save-pages-manifest written)
      (if stale
          (message "garden: published pages to %s (removed %d stale)" out (length stale))
        (message "garden: published pages to %s" out)))))

(defcustom garden-publish-deploy-command "just publish"
  "Shell command that deploys the generated site."
  :type 'string :group 'garden)

(defun garden-publish--post-files ()
  "Return the Org files of all blog posts, or nil if the source is missing."
  (when (file-directory-p garden-publish-blog-source)
    (directory-files garden-publish-blog-source t "\\.org\\'")))

(defun garden-publish--page-files ()
  "Return the Org files of all standalone pages, or nil if the source is missing."
  (when (file-directory-p garden-publish-pages-source)
    (directory-files garden-publish-pages-source t "\\.org\\'")))

(defun garden-publish--pick-file (prompt files)
  "Pick one of FILES by base name with PROMPT."
  (if (null files)
      (user-error "No source files available")
    (let ((table (mapcar (lambda (f) (cons (file-name-nondirectory f) f)) files)))
      (cdr (assoc (completing-read prompt table nil t) table)))))

;;;###autoload
(defun garden-publish-post (file)
  "Export the single blog post FILE to the site blog directory."
  (interactive (list (garden-publish--pick-file "Publish post: " (garden-publish--post-files))))
  (let ((out (expand-file-name garden-publish-blog-subdir garden-publish-site-directory))
        (props (car (garden-publish--parse-post file))))
    (if (equal (cdr (assoc "status" props)) "draft")
        (message "garden: %s is a draft, not published" (file-name-base file))
      (make-directory out t)
      (garden-publish--ensure-index out "Blog")
      (garden-publish--blog-one file out)
      (message "garden: published post %s → %s" (file-name-base file) out))))

;;;###autoload
(defun garden-publish-page (file)
  "Export the single standalone page FILE to the site content directory."
  (interactive (list (garden-publish--pick-file "Publish page: " (garden-publish--page-files))))
  (let* ((out (expand-file-name "content" garden-publish-site-directory))
         (name (progn (make-directory out t) (garden-publish--page-one file out))))
    (if (null name)
        (message "garden: %s is a draft or skipped, not published" (file-name-base file))
      (let ((manifest (garden-publish--load-pages-manifest)))
        (unless (member name manifest)
          (garden-publish--save-pages-manifest (cons name manifest))))
      (message "garden: published page %s" name))))

;;;###autoload
(defun garden-publish-note-as-page (&optional file slug)
  "Export the garden note FILE as the standalone page SLUG on the site.
Interactively, offers the current buffer's note when visiting one,
and prompts for the slug.  The note file itself stays untouched;
tag it noexport if it should not also appear under /wiki/."
  (interactive)
  (let* ((current (buffer-file-name))
         (file (or file
                   (if (and current
                            (string-prefix-p (expand-file-name garden-directory)
                                             (expand-file-name current))
                            (y-or-n-p (format "Publish %s as a page? "
                                              (file-name-nondirectory current))))
                       current
                     (garden-publish--pick-file "Publish note as page: " (garden--note-files)))))
         (parsed (garden-publish--parse-post file))
         (props (car parsed))
         (title (or (cdr (assoc "title" props)) (file-name-base file)))
         (slug (garden-publish--clean-slug
                (or slug
                    (read-string "Page slug: " (or (garden-publish--filename-slug file)
                                                   (garden-publish--clean-slug title))))))
         (md (garden-publish--org-to-gfm
              (garden-publish--strip-toc
               (replace-regexp-in-string "/content/images/" "/images/" (cdr parsed)))))
         (out (expand-file-name "content" garden-publish-site-directory))
         (map (garden-publish--slug-map)))
    (make-directory out t)
    (with-temp-file (expand-file-name (concat slug ".md") out)
      (insert (format "+++\ntitle = %S\n+++\n\n" title) md)
      (garden-publish--rewrite-denote-links map))
    (message "garden: published note as page /%s" slug)))

;;;###autoload
(defun garden-publish-one ()
  "Publish a single post, page or note, then offer to deploy."
  (interactive)
  (let* ((candidates
          (append
           (mapcar (lambda (f) (cons (concat "post: " (file-name-base f)) (cons #'garden-publish-post f)))
                   (garden-publish--post-files))
           (mapcar (lambda (f) (cons (concat "page: " (file-name-base f)) (cons #'garden-publish-page f)))
                   (garden-publish--page-files))
           (mapcar (lambda (f) (cons (concat "note: " (file-name-nondirectory f)) (cons #'garden-publish-note-as-page f)))
                   (garden--note-files))))
         (choice (cdr (assoc (completing-read "Publish one: " candidates nil t) candidates))))
    (funcall (car choice) (cdr choice))
    (when (y-or-n-p (format "Deploy now (%s)? " garden-publish-deploy-command))
      (garden-publish-deploy))))

;;;###autoload
(defun garden-publish ()
  "Publish the wiki, the blog and the pages to the site directory."
  (interactive)
  (garden-publish-wiki)
  (garden-publish-blog)
  (garden-publish-pages)
  (message "garden: published wiki + blog + pages → %s" garden-publish-site-directory))

;;;###autoload
(defun garden-publish-deploy ()
  "Run the deploy command asynchronously in the site directory."
  (interactive)
  (let ((default-directory (expand-file-name garden-publish-site-directory)))
    (async-shell-command garden-publish-deploy-command "*garden-deploy*")))

;;;###autoload
(defun garden-publish-all ()
  "Publish the whole site and then deploy it."
  (interactive)
  (garden-publish)
  (garden-publish-deploy))

(provide 'garden-publish)
;;; garden-publish.el ends here
