;;; denote-menu.el --- A vui-based Denote browser -*- lexical-binding: t; -*-

;; Author: cashmere
;; Package-Requires: ((emacs "29.1") (denote "3.0.0"))

;;; Commentary:

;; A keyboard-first browser for Denote notes built on vui.el.
;; Lists notes from `denote-directory' (silo-aware) in a borderless table with
;; live filtering, column sorting, and one-key actions.  Ships its own
;; `denote-menu-mode' derived from `vui-mode' with Evil normal-state keys.

;;; Code:

(require 'vui)
(require 'vui-components)
(require 'denote)

(declare-function evil-define-key* "evil-core" (state keymap key def &rest bindings))
(declare-function evil-set-initial-state "evil-core" (mode state))

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

(defcustom denote-menu-wide-breakpoint 78
  "Minimum window width for the sticky table layout."
  :type 'integer)

(defcustom denote-menu-preview-width 0.38
  "Fractional width of the optional note preview side window."
  :type 'number)

(defvar-local denote-menu--dispatch nil
  "Alist of actions and visible paths for the current buffer.
Set during render; consumed by the mode's interactive commands.")

(defconst denote-menu--preview-buffer-name "*Denote Preview*")

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

(defun denote-menu--keywords-label (keywords)
  "Return a compact display label for KEYWORDS."
  (if keywords
      (format "#%s" (string-join keywords "  #"))
    "untagged"))

(defun denote-menu--sort-indicator (sort-key sort-desc)
  "Human-readable sort indicator for SORT-KEY and SORT-DESC."
  (format "%s %s" sort-key (if sort-desc "↓" "↑")))

(defun denote-menu--column-header (label sort-key current-key sort-desc)
  "Return LABEL with an arrow when SORT-KEY is the CURRENT-KEY."
  (if (eq sort-key current-key)
      (format "%s %s" label (if sort-desc "↓" "↑"))
    label))

(defun denote-menu--window-width ()
  "Return the live body width of the window displaying this menu."
  (if-let* ((window (get-buffer-window (current-buffer) t)))
      (window-body-width window)
    (window-width)))

(defun denote-menu--wide-table (visible sort-key sort-desc width)
  "Render VISIBLE as a sticky table using responsive WIDTH columns."
  (let* ((date-width (if (>= width 100) denote-menu-date-width 10))
         (keyword-width (max 14 (min denote-menu-keywords-width (/ width 4))))
         (title-width (max 18 (- width date-width keyword-width
                                 denote-menu-ext-width 5))))
    (vui-table
     :sticky-header t
     :columns (list
               (list :header (denote-menu--column-header
                              "Date" 'date sort-key sort-desc)
                     :width date-width :truncate t)
               (list :header "Type" :width denote-menu-ext-width
                     :truncate t)
               (list :header (denote-menu--column-header
                              "Keywords" 'keywords sort-key sort-desc)
                     :width keyword-width :truncate t)
               (list :header (denote-menu--column-header
                              "Title" 'title sort-key sort-desc)
                     :width title-width :grow t :truncate t))
     :rows
     (mapcar
      (lambda (note)
        (list
         (vui-text (plist-get note :date) :face 'shadow)
         (vui-text (if-let* ((ext (plist-get note :ext)))
                       (concat "." ext)
                     "—")
                   :face 'shadow)
         (vui-text (denote-menu--keywords-label (plist-get note :keywords))
                   :face 'font-lock-comment-face)
         (vui-button (plist-get note :title)
                     :key (plist-get note :path)
                     :no-decoration t :help-echo nil
                     :on-click (lambda ()
                                 (find-file (plist-get note :path))))))
      visible))))

(defun denote-menu--compact-card (note width)
  "Render NOTE as a two-line card fitting WIDTH."
  (let ((path (plist-get note :path)))
    (vui-vstack
     :spacing 0
     (vui-flex
      :width 'window :justify :space-between
      (vui-flex-item
       :grow 1
       (lambda (available)
         (vui-button (plist-get note :title)
                     :key path :no-decoration t :help-echo nil
                     :max-width (max 8 available)
                     :face '(:inherit bold)
                     :on-click (lambda () (find-file path)))))
      (vui-text (format "%s  .%s"
                        (substring (plist-get note :date) 0 10)
                        (or (plist-get note :ext) ""))
                :face 'shadow))
     (vui-box
      (vui-text (denote-menu--keywords-label (plist-get note :keywords))
                :face 'font-lock-comment-face)
      :width (max 12 (- width 2)) :padding-left 2))))

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
    (let ((width (denote-menu--window-width)))
     (vui-vstack
     :spacing 1
     (vui-flex
      :width 'window :justify :space-between
      (vui-hstack
       :spacing 2
       (vui-heading-2 "Denotes")
       (vui-text (format "▸ %s" silo)
                 :face '(:inherit success :weight bold)))
      (vui-text (format "%d%s notes"
                        (length visible)
                        (if filtering (format " / %d" (length notes)) ""))
                :face 'shadow))
     (vui-flex
      :width 'window :justify :space-between
      (vui-hstack
       :spacing 1
       (vui-text "filter" :face 'shadow)
       (vui-text (if filtering query "all notes")
                 :face (if filtering 'warning 'shadow)))
      (vui-hstack
       :spacing 1
       (vui-text (format "sort %s"
                         (denote-menu--sort-indicator sort-key sort-desc))
                 :face 'shadow)
       (vui-button "new" :on-click #'denote-menu-new-note)
       (vui-button "dired" :on-click #'denote-menu-export-to-dired)))
     (if (null visible)
         (vui-vstack
          :spacing 1
          (vui-box (vui-text "∅" :face '(:inherit shadow :height 2.0))
                   :width width :align :center)
          (vui-box (vui-text (if filtering
                                 (format "No notes matching \"%s\"" query)
                               "No notes here yet")
                             :face 'shadow)
                   :width width :align :center)
          (vui-box (vui-button "Create the first one"
                               :on-click (lambda () (call-interactively #'denote)))
                   :width width :align :center))
       (if (>= width denote-menu-wide-breakpoint)
           (denote-menu--wide-table visible sort-key sort-desc width)
         (vui-list visible
                   (lambda (note) (denote-menu--compact-card note width))
                   (lambda (note) (plist-get note :path))
                   :spacing 1)))
     (vui-flex
      :width 'window :justify :space-between
      (vui-text "j/k move · RET/l open · / filter · p preview"
                :face 'shadow)
      (vui-text "s/S sort · n new · g refresh · ? help · q close"
                :face 'shadow))))))

(defun denote-menu--action (name)
  "Return the buffer's dispatch action NAME, or signal an error."
  (or (plist-get denote-menu--dispatch name)
      (user-error "Denote-explorer is not ready in this buffer")))

(defun denote-menu--path-on-line ()
  "Return the note path keyed on the current visual row."
  (save-excursion
    (beginning-of-line)
    (let ((end (line-end-position)) path)
      (while (and (not path) (< (point) end))
        (setq path (vui-key-at))
        (forward-char 1))
      path)))

(defun denote-menu-open-at-point ()
  "Open the note at point."
  (interactive)
  (if-let* ((path (or (vui-key-at) (denote-menu--path-on-line))))
      (find-file path)
    (user-error "No note at point")))

(defun denote-menu-preview-at-point ()
  "Show the note at point in an opt-in right side window."
  (interactive)
  (if-let* ((path (or (vui-key-at) (denote-menu--path-on-line))))
      (let ((buffer (get-buffer-create denote-menu--preview-buffer-name)))
        (with-current-buffer buffer
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert-file-contents path)
            (org-mode)
            (setq-local buffer-file-name path)
            (setq-local mode-line-format nil)
            (goto-char (point-min))
            (view-mode 1)))
        (display-buffer-in-side-window
         buffer `((side . right)
                  (slot . 1)
                  (window-width . ,denote-menu-preview-width))))
    (user-error "No note at point")))

(defun denote-menu-help ()
  "Show the Denote Menu key summary."
  (interactive)
  (message "Denote Menu: j/k move, TAB/S-TAB widgets, RET/l open, / filter, p preview, n new, s/S sort, e Dired, g refresh, h/q close"))

(defun denote-menu-quit ()
  "Close the menu and its optional preview."
  (interactive)
  (when-let* ((preview (get-buffer denote-menu--preview-buffer-name))
              (window (get-buffer-window preview t)))
    (delete-window window))
  (when-let* ((preview (get-buffer denote-menu--preview-buffer-name)))
    (kill-buffer preview))
  (vui-quit))

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
    (set-keymap-parent map vui-mode-map)
    (define-key map (kbd "RET") #'denote-menu-open-at-point)
    (define-key map (kbd "l") #'denote-menu-open-at-point)
    (define-key map (kbd "j") #'next-line)
    (define-key map (kbd "k") #'previous-line)
    (define-key map (kbd "TAB") #'vui-forward)
    (define-key map (kbd "<backtab>") #'vui-backward)
    (define-key map (kbd "p") #'denote-menu-preview-at-point)
    (define-key map (kbd "n") #'denote-menu-new-note)
    (define-key map (kbd "e") #'denote-menu-export-to-dired)
    (define-key map (kbd "r") #'denote-menu-refresh)
    (define-key map (kbd "g") #'denote-menu-refresh)
    (define-key map (kbd "/") #'denote-menu-filter)
    (define-key map (kbd "c") #'denote-menu-clear-filter)
    (define-key map (kbd "s") #'denote-menu-cycle-sort)
    (define-key map (kbd "S") #'denote-menu-toggle-sort-direction)
    (define-key map (kbd "?") #'denote-menu-help)
    (define-key map (kbd "h") #'denote-menu-quit)
    (define-key map (kbd "q") #'denote-menu-quit)
    map)
  "Keymap for `denote-menu-mode'.")

(define-derived-mode denote-menu-mode vui-mode "Denote-Menu"
  "Major mode for the vui-based Denote browser.
Enable it before mounting `denote-menu-app' so vui preserves it
across re-renders.

\\{denote-menu-mode-map}"
  :group 'denote-menu
  (hl-line-mode 1))

(with-eval-after-load 'evil
  (evil-set-initial-state 'denote-menu-mode 'normal)
  (evil-define-key* '(normal motion) denote-menu-mode-map
    (kbd "j") #'next-line
    (kbd "k") #'previous-line
    (kbd "RET") #'denote-menu-open-at-point
    (kbd "l") #'denote-menu-open-at-point
    (kbd "h") #'denote-menu-quit
    (kbd "q") #'denote-menu-quit
    (kbd "g") #'denote-menu-refresh
    (kbd "/") #'denote-menu-filter
    (kbd "p") #'denote-menu-preview-at-point
    (kbd "?") #'denote-menu-help))


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
