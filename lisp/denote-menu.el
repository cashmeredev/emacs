;;; denote-menu.el --- A vui-based Denote browser -*- lexical-binding: t; -*-

;; Author: cashmere
;; Package-Requires: ((emacs "29.1") (denote "3.0.0"))

;;; Commentary:

;; A keyboard-first browser for Denote notes built on vui.el.
;; Lists notes from `denote-directory' (silo-aware) in a borderless table with
;; live filtering, column sorting, and one-key actions.  Ships its own
;; `denote-menu-mode' derived from `vui-mode' and registers normal-state
;; keys with helix when it is available.

;;; Code:

(require 'vui)
(require 'vui-components)
(require 'denote)

(defgroup denote-menu nil
  "A vui-based browser for Denote notes."
  :group 'denote
  :prefix "denote-menu-")

(defcustom denote-menu-keywords-width 28
  "Width of the keywords column."
  :type 'integer)

(defcustom denote-menu-date-width 16
  "Width of the date column."
  :type 'integer)

(defcustom denote-menu-ext-width 5
  "Width of the file extension column."
  :type 'integer)

(defvar-local denote-menu--dispatch nil
  "Alist of actions and visible paths for the current buffer.
Set during render; consumed by the mode's interactive commands.")

(defun denote-menu--format-date (identifier)
  "Format a Denote IDENTIFIER (20260315T120000) as \"2026-03-15 12:00\"."
  (if (and identifier (string-match "\\`\\([0-9]\\{4\\}\\)\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)T\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)" identifier))
      (format "%s-%s-%s %s:%s"
              (match-string 1 identifier)
              (match-string 2 identifier)
              (match-string 3 identifier)
              (match-string 4 identifier)
              (match-string 5 identifier))
    (or identifier "")))

(defun denote-menu--note-from-path (path)
  "Build a note plist from PATH using only filename components."
  (let* ((id (denote-retrieve-filename-identifier path))
         (title (denote-retrieve-filename-title path))
         (keywords (denote-retrieve-filename-keywords path))
         (kw-list (and keywords (split-string keywords "_" t))))
    (list :path path
          :id (or id "")
          :date (denote-menu--format-date id)
          :title (if title
                     (string-replace "-" " " title)
                   (file-name-base path))
          :ext (file-name-extension path)
          :keywords (or kw-list '()))))

(defun denote-menu--collect-notes ()
  "Return all notes in `denote-directory' as a list of plists."
  (mapcar #'denote-menu--note-from-path (denote-directory-files)))

(defun denote-menu--note-matches-p (note query)
  "Non-nil when NOTE matches QUERY (title, keywords, or date)."
  (let ((haystack (string-join
                   (list (plist-get note :title)
                         (string-join (plist-get note :keywords) " ")
                         (plist-get note :date)
                         (plist-get note :ext)
                         (plist-get note :id))
                   " ")))
    (string-match-p (regexp-quote query) (downcase haystack))))

(defun denote-menu--visible-notes (notes query sort-key sort-desc)
  "Filter NOTES by QUERY and sort by SORT-KEY, descending when SORT-DESC."
  (let* ((filtered (if (string-empty-p query)
                       (copy-sequence notes)
                     (seq-filter (lambda (note)
                                   (denote-menu--note-matches-p note (downcase query)))
                                 notes)))
         (key-fn (pcase sort-key
                   ('title (lambda (note) (downcase (plist-get note :title))))
                   ('keywords (lambda (note) (downcase (string-join (plist-get note :keywords) " "))))
                   (_ (lambda (note) (plist-get note :id)))))
         (sorted (sort filtered (lambda (a b)
                                  (string< (funcall key-fn a) (funcall key-fn b))))))
    (if sort-desc (nreverse sorted) sorted)))

(defun denote-menu--format-keywords (keywords width)
  "Format KEYWORDS as [a,b] fitting WIDTH, collapsing overflow to ,+N."
  (let ((parts '())
        (used 0)
        (idx 0)
        (total (length keywords))
        (done nil))
    (while (and (< idx total) (not done))
      (let* ((kw (nth idx keywords))
             (remaining (- total idx 1))
             (suffix (if (> remaining 0)
                         (+ 2 (length (number-to-string remaining)))
                       0))
             (cost (+ (if parts 1 0) (length kw))))
        (if (<= (+ used cost suffix 2) width)
            (setq parts (cons kw parts)
                  used (+ used cost)
                  idx (1+ idx))
          (setq done t))))
    (let ((remaining (- total idx)))
      (cond
       ((> remaining 0)
        (if parts
            (format "[%s,+%d]" (string-join (nreverse parts) ",") remaining)
          (format "[%s...]" (substring (car keywords) 0 (max 1 (- width 5))))))
       (t (format "[%s]" (string-join (nreverse parts) ",")))))))

(defun denote-menu--sort-indicator (sort-key sort-desc)
  "Human-readable sort indicator for SORT-KEY and SORT-DESC."
  (format "%s %s" sort-key (if sort-desc "↓" "↑")))

(defun denote-menu--column-header (label sort-key current-key sort-desc)
  "Return LABEL with an arrow when SORT-KEY is the CURRENT-KEY."
  (if (eq sort-key current-key)
      (format "%s %s" label (if sort-desc "↓" "↑"))
    label))

(vui-defcomponent denote-menu-app ()
  :state ((query "")
          (sort-key 'date)
          (sort-desc t)
          (notes (denote-menu--collect-notes))
          (silo (file-name-nondirectory
                 (directory-file-name (car (denote-directories))))))
  :render
  (let* ((visible (denote-menu--visible-notes notes query sort-key sort-desc))
         (filtering (not (string-empty-p query))))
    (setq denote-menu--dispatch
          (list :visible-paths (mapcar (lambda (note) (plist-get note :path)) visible)
                :refresh (vui-with-async-context
                          (vui-batch
                           (vui-set-state :notes (denote-menu--collect-notes))
                           (vui-set-state :silo (file-name-nondirectory
                                                 (directory-file-name (car (denote-directories)))))))
                :set-query (vui-async-callback (q)
                            (vui-set-state :query q))
                :cycle-sort (vui-with-async-context
                             (vui-set-state :sort-key
                                            (pcase sort-key
                                              ('date 'title)
                                              ('title 'keywords)
                                              (_ 'date))))
                :toggle-direction (vui-with-async-context
                                   (vui-set-state :sort-desc (not sort-desc)))))
    (vui-vstack
     :spacing 1
     (vui-hstack
      :spacing 2
      (vui-heading-2 "Denotes")
      (vui-text (format "▸ %s" silo) :face '(:inherit success :weight bold))
      (vui-text (format "%d%s notes"
                        (length visible)
                        (if filtering
                            (format " of %d" (length notes))
                          ""))
                :face 'shadow)
      (vui-button "new" :on-click (lambda ()
                                    (let ((file (call-interactively #'denote)))
                                      (when file (funcall (plist-get denote-menu--dispatch :refresh)))))
                  :help-echo "Create a new note")
      (vui-button "export" :on-click #'denote-menu-export-to-dired
                  :help-echo "Open the visible notes in Dired"))
     (vui-text "RET open · / filter · s/S sort · e export · n new · q quit"
               :face 'shadow)
     (vui-hstack
      :spacing 2
      (vui-hstack
       :spacing 1
       (vui-text "filter:" :face 'shadow)
       (if filtering
           (vui-text query :face '(:inherit warning :weight bold))
         (vui-text "none  (press / to filter)" :face 'shadow)))
      (vui-text (format "sort: %s" (denote-menu--sort-indicator sort-key sort-desc))
                :face 'shadow))
     (if (null visible)
         (vui-vstack
          :spacing 1
          (vui-box (vui-text "∅" :face '(:inherit shadow :height 2.0))
                   :width fill-column :align :center)
          (vui-box (vui-text (if filtering
                                 (format "No notes matching \"%s\"" query)
                               "No notes here yet")
                             :face 'shadow)
                   :width fill-column :align :center)
          (vui-box (vui-button "Create the first one"
                               :on-click (lambda () (call-interactively #'denote)))
                   :width fill-column :align :center))
       (let* ((win (or (get-buffer-window (current-buffer)) (selected-window)))
              (title-width (max 10 (- (window-width win)
                                      denote-menu-date-width
                                      denote-menu-ext-width
                                      denote-menu-keywords-width
                                      4))))
         (vui-table
          :columns (list (list :header (denote-menu--column-header "Date" 'date sort-key sort-desc)
                               :width denote-menu-date-width)
                         (list :header ""
                               :width denote-menu-ext-width)
                         (list :header (denote-menu--column-header "Keywords" 'keywords sort-key sort-desc)
                               :width denote-menu-keywords-width :truncate t)
                         (list :header (denote-menu--column-header "Title" 'title sort-key sort-desc)
                               :width title-width :truncate t))
          :rows (mapcar
                 (lambda (note)
                   (list (vui-text (plist-get note :date) :face 'shadow)
                         (vui-text (if-let* ((ext (plist-get note :ext)))
                                       (concat "." ext)
                                     "")
                                   :face 'shadow)
                         (if (plist-get note :keywords)
                             (vui-text (denote-menu--format-keywords
                                        (plist-get note :keywords)
                                        denote-menu-keywords-width)
                                       :face 'font-lock-comment-face)
                           (vui-text "·" :face 'shadow))
                         (vui-button (plist-get note :title)
                                     :key (plist-get note :path)
                                     :no-decoration t
                                     :help-echo nil
                                     :on-click (lambda () (find-file (plist-get note :path))))))
                 visible)))))))

(defun denote-menu--action (name)
  "Return the buffer's dispatch action NAME, or signal an error."
  (or (plist-get denote-menu--dispatch name)
      (user-error "Denote-explorer is not ready in this buffer")))

(defun denote-menu-open-at-point ()
  "Open the note at point."
  (interactive)
  (if-let* ((path (vui-key-at)))
      (find-file path)
    (user-error "No note at point")))

(defun denote-menu-filter ()
  "Prompt for a filter query."
  (interactive)
  (funcall (denote-menu--action :set-query)
           (read-string "Filter notes: ")))

(defun denote-menu-clear-filter ()
  "Clear the current filter."
  (interactive)
  (funcall (denote-menu--action :set-query) ""))

(defun denote-menu-cycle-sort ()
  "Cycle the sort column: date → title → keywords."
  (interactive)
  (funcall (denote-menu--action :cycle-sort)))

(defun denote-menu-toggle-sort-direction ()
  "Toggle between ascending and descending sort."
  (interactive)
  (funcall (denote-menu--action :toggle-direction)))

(defun denote-menu-refresh ()
  "Re-scan `denote-directory'."
  (interactive)
  (funcall (denote-menu--action :refresh)))

(defun denote-menu-new-note ()
  "Create a new note with `denote' and refresh afterwards."
  (interactive)
  (call-interactively #'denote)
  (funcall (denote-menu--action :refresh)))

(defun denote-menu-export-to-dired ()
  "Switch to a plain Dired buffer listing the currently visible notes.
Bypasses dirvish's `dired-noselect' advice: dirvish keys session
buffers by directory only, so it would reuse the existing buffer
for `denote-directory' and silently drop the file-list filter."
  (interactive)
  (if-let* ((paths (plist-get denote-menu--dispatch :visible-paths))
            (default-directory (car (denote-directories))))
      (pop-to-buffer-same-window
       (unwind-protect
           (progn
             (advice-remove 'dired-noselect 'dirvish-dired-noselect-a)
             (dired-noselect (cons default-directory paths)))
         (when (bound-and-true-p dirvish-override-dired-mode)
           (advice-add 'dired-noselect :around 'dirvish-dired-noselect-a))))
    (user-error "No files to export")))

(defvar denote-menu-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'denote-menu-open-at-point)
    (define-key map (kbd "n") #'denote-menu-new-note)
    (define-key map (kbd "e") #'denote-menu-export-to-dired)
    (define-key map (kbd "r") #'denote-menu-refresh)
    (define-key map (kbd "/") #'denote-menu-filter)
    (define-key map (kbd "c") #'denote-menu-clear-filter)
    (define-key map (kbd "s") #'denote-menu-cycle-sort)
    (define-key map (kbd "S") #'denote-menu-toggle-sort-direction)
    map)
  "Keymap for `denote-menu-mode'.")

(define-derived-mode denote-menu-mode vui-mode "Denote-Menu"
  "Major mode for the vui-based Denote browser.
Enable it before mounting `denote-menu-app' so vui preserves it
across re-renders.

\\{denote-menu-mode-map}"
  :group 'denote-menu
  (hl-line-mode 1))


(with-eval-after-load 'helix
  (helix-define-key 'normal "RET" #'denote-menu-open-at-point 'denote-menu-mode)
  (helix-define-key 'normal "o" #'denote-menu-open-at-point 'denote-menu-mode)
  (helix-define-key 'normal "/" #'denote-menu-filter 'denote-menu-mode)
  (helix-define-key 'normal "c" #'denote-menu-clear-filter 'denote-menu-mode)
  (helix-define-key 'normal "s" #'denote-menu-cycle-sort 'denote-menu-mode)
  (helix-define-key 'normal "S" #'denote-menu-toggle-sort-direction 'denote-menu-mode)
  (helix-define-key 'normal "e" #'denote-menu-export-to-dired 'denote-menu-mode)
  (helix-define-key 'normal "n" #'denote-menu-new-note 'denote-menu-mode)
  (helix-define-key 'normal "r" #'denote-menu-refresh 'denote-menu-mode)
  (helix-define-key 'normal "q" #'vui-quit 'denote-menu-mode))

;;;###autoload
(defun denote-menu ()
  "Browse Denote notes in the current silo."
  (interactive)
  (let ((buffer (get-buffer-create "*Denotes*")))
    (with-current-buffer buffer
      (unless (derived-mode-p 'denote-menu-mode)
        (denote-menu-mode))
      (vui-mount (vui-component 'denote-menu-app) buffer)
      (vui-rerender-on-resize))
    (pop-to-buffer-same-window buffer)))

(provide 'denote-menu)
;;; denote-menu.el ends here
