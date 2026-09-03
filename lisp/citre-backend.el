;;; citre-backend.el --- Live and persistent tags through Citre -*- lexical-binding: t; -*-

(require 'citre)
(require 'citre-tags)
(require 'citre-index)

(defvar company--capf-cache)
(defvar-local my/citre-backend--completion-cache nil)

;; Retire the popup restart timer when reloading an earlier version of this module.
(when (boundp 'my/citre-backend--company-timer)
  (my/citre-index--cancel-timer (symbol-value 'my/citre-backend--company-timer))
  (set 'my/citre-backend--company-timer nil))

(defun my/citre-backend--sources ()
  "Return (TAGS-FILE . LIVE-SOURCE) pairs in priority order."
  (if-let* ((state my/citre-index--state))
      (let* ((entries (my/citre-index-live-entries state))
             (current (my/citre-index--path))
             (live (sort entries (lambda (a b) (and (equal (car a) current) (not (equal (car b) current)))))))
        (append
         (mapcar (lambda (entry) (cons (plist-get (cdr entry) :file) (car entry))) live)
         (let ((project (expand-file-name "project.tags" (my/citre-index-state-cache state))))
           (if (file-readable-p project)
               (list (cons project nil))
             (when-let* ((legacy (citre-tags-file-path))) (list (cons legacy nil)))))
         (let ((dependencies (expand-file-name "dependencies.tags" (my/citre-index-state-cache state))))
           (when (file-readable-p dependencies) (list (cons dependencies nil))))))
    (when-let* ((file (citre-tags-file-path))) (list (cons file nil)))))

(defun my/citre-backend--query (operation &optional identifier)
  "Merge tags for OPERATION, optionally using IDENTIFIER, while masking superseded files."
  (let* ((sources (my/citre-backend--sources))
         (masked (delq nil (mapcar #'cdr sources)))
         (seen (make-hash-table :test #'equal))
         result)
    (dolist (source sources)
      (let* ((file (car source))
             (symbol (or (and identifier
                              (citre-put-property (copy-sequence identifier)
                                                  'file-path buffer-file-name 'tags-file file))
                         (and (not (memq operation '(identifiers imenu)))
                              (citre-tags-get-symbol file))))
             (filter
              (pcase operation
                ('completion (when symbol (or (citre-tags--get-value-in-language-alist :completion-filter symbol)
                                              (citre-tags-completion-default-filter symbol))))
                ('definition (when symbol (or (citre-tags--get-value-in-language-alist :definition-filter symbol)
                                              (citre-tags-definition-default-filter symbol))))
                ('imenu (list 'and (citre-readtags-filter-input (my/citre-index--path) file)
                              (list 'not citre-tags-filter-file-tags)))
                (_ (list 'not citre-tags-filter-file-tags))))
             (sorter
              (pcase operation
                ('completion (when symbol (or (citre-tags--get-value-in-language-alist :completion-sorter symbol)
                                              citre-tags-completion-default-sorter)))
                ('imenu (citre-readtags-sorter 'line))
                (_ citre-tags-definition-default-sorter)))
             (tags (when (or symbol (memq operation '(identifiers imenu)))
                     (citre-tags-get-tags
                      file symbol (if (eq operation 'completion) (if citre-tags-substr-completion 'substr 'prefix) 'exact)
                      :filter filter :sorter sorter
                      :require '(name ext-abspath)
                      :optional '(pattern line end ext-kind-full signature scope typeref extras language)))))
        (dolist (tag tags)
          (let* ((path (citre-get-tag-field 'ext-abspath tag))
                 (key (mapcar (lambda (field) (citre-get-tag-field field tag))
                              '(name ext-abspath line scope ext-kind-full))))
            (unless (or (and (not (cdr source)) (member path masked)) (gethash key seen))
              (puthash key t seen)
              (push tag result))))))
    (nreverse result)))

(defun my/citre-backend-completions ()
  "Return current Citre completion bounds and tags, reusing a narrowing prefix."
  (when-let* ((source (car (my/citre-backend--sources)))
              (symbol (citre-tags-get-symbol (car source)))
              (bounds (citre-get-property 'bounds symbol)))
    (let* ((revision (and my/citre-index--state (my/citre-index-state-revision my/citre-index--state)))
           (context (list revision (car bounds) major-mode citre-tags-substr-completion
                          (buffer-substring-no-properties (line-beginning-position) (car bounds))))
           (cache my/citre-backend--completion-cache)
           (tags (if (and revision (equal context (plist-get cache :context))
                          (string-prefix-p (plist-get cache :prefix) symbol))
                     (plist-get cache :tags)
                   (let ((tags (my/citre-backend--query 'completion)))
                     (setq my/citre-backend--completion-cache
                           (list :context context :prefix (substring-no-properties symbol) :tags tags))
                     tags))))
      (when tags (list (car bounds) (cdr bounds) tags)))))

(defun my/citre-backend-definitions ()
  "Find definitions in the current live and persistent indexes."
  (my/citre-backend--query 'definition))

(defun my/citre-backend-definitions-of-id (identifier)
  "Find definitions of IDENTIFIER in the current project."
  (my/citre-backend--query 'definition identifier))

(defun my/citre-backend-identifiers ()
  "Return all current identifiers for Citre's query UI."
  (delete-dups (mapcar (lambda (tag) (citre-get-tag-field 'name tag))
                      (my/citre-backend--query 'identifiers))))

(defun my/citre-backend-imenu ()
  "Return the current file's symbols for Imenu, including unsaved changes."
  (my/citre-backend--query 'imenu))

(defun my/citre-backend-usable-p ()
  "Whether the current buffer has an automatic or conventional tags index."
  (or my/citre-index--state (citre-tags-usable-p)))

(defun my/citre-backend--updated (state)
  "Invalidate data for STATE without restarting or rearranging an open Company menu."
  (dolist (buffer (my/citre-index--buffers state))
    (with-current-buffer buffer
      (setq my/citre-backend--completion-cache nil)
      (when (boundp 'imenu--index-alist) (setq imenu--index-alist nil))
      ;; Fresh data is consumed on the next edit or completion request. Navigation keeps its current candidates and selection.
      (when (and (boundp 'company--capf-cache)
                 (eq (car company--capf-cache) buffer))
        (setq company--capf-cache nil)))))

(citre-register-backend
 'my-index
 (citre-backend-create :usable-probe #'my/citre-backend-usable-p
                      :symbol-at-point-fn #'citre-tags-symbol-at-point
                      :completions-fn #'my/citre-backend-completions
                      :defs-fn #'my/citre-backend-definitions
                      :defs-of-id-fn #'my/citre-backend-definitions-of-id
                      :id-list-fn #'my/citre-backend-identifiers
                      :tags-in-buffer-fn #'my/citre-backend-imenu
                      :after-jump-fn #'my/citre-index-attach))

(add-hook 'my/citre-index-updated-hook #'my/citre-backend--updated)

(provide 'citre-backend)
;;; citre-backend.el ends here
