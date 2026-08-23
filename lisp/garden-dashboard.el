;;; garden-dashboard.el --- cute garden explorer -*- lexical-binding: t; -*-

(require 'garden-core)
(require 'garden-icons)
(require 'garden-preview)
(require 'garden-connect)
(require 'garden-fleet)
(require 'garden-publish)
(require 'vui)
(require 'vui-components)

(declare-function evil-define-key* "evil-core" (state keymap key def &rest bindings))
(declare-function evil-set-initial-state "evil-core" (mode state))

(defface garden-star '((t :inherit shadow)) "Face for the decorative star sprinkles." :group 'garden)
(defface garden-meta '((t :inherit shadow :height 0.9)) "Face for muted helper text." :group 'garden)
(defface garden-rule '((t :inherit shadow)) "Face for decorative rule lines." :group 'garden)
(defface garden-tag-xl '((t :weight bold :height 1.7)) "Face for the most frequent topic tags." :group 'garden)
(defface garden-tag-l '((t :weight bold :height 1.4)) "Face for very frequent topic tags." :group 'garden)
(defface garden-tag-m '((t :height 1.2)) "Face for moderately frequent topic tags." :group 'garden)
(defface garden-tag-s '((t :height 1.05)) "Face for less frequent topic tags." :group 'garden)
(defface garden-tag-xs '((t :inherit shadow :height 0.95)) "Face for rare topic tags." :group 'garden)
(defface garden-card-num '((t :weight bold :inherit success)) "Face for the stat card numbers." :group 'garden)
(defface garden-card-frame '((t :inherit shadow)) "Face for the stat card rules." :group 'garden)

(defcustom garden-content-width 66
  "Maximum width in columns of decorative rule lines in the dashboard.
This variable no longer forces centering; it only caps the length
of banners and separators."
  :type 'integer :group 'garden)
(defcustom garden-sidecar-width 34
  "Width in columns of the compact sidecar window."
  :type 'integer :group 'garden)

(defvar-local garden--compact nil
  "Whether this dashboard buffer renders the compact view.")

(defun garden--window-width ()
  "Return the live body width of the Garden window."
  (if-let* ((window (get-buffer-window (current-buffer) t)))
      (window-body-width window)
    (window-width)))

(defun garden--tag-face (count maxc)
  "Return the meadow face for a tag with COUNT uses out of MAXC."
  (let ((r (/ (float count) (max 1 maxc))))
    (cond ((>= r 0.75) 'garden-tag-xl)
          ((>= r 0.50) 'garden-tag-l)
          ((>= r 0.28) 'garden-tag-m)
          ((>= r 0.12) 'garden-tag-s)
          (t 'garden-tag-xs))))

(defun garden--chunk (list n)
  "Partition LIST into consecutive chunks of N elements."
  (let (rows)
    (while list (push (seq-take list n) rows) (setq list (nthcdr n list)))
    (nreverse rows)))

(defun garden-browse-keyword (keyword)
  "Pick one of the notes tagged with KEYWORD and visit it."
  (let* ((notes (garden-notes-with-keyword keyword))
         (table (mapcar (lambda (n) (cons (garden-note-title n) n)) notes))
         (annotate (lambda (title)
                     (when-let* ((note (cdr (assoc title table))))
                       (garden-note-annotation note))))
         (choice (completing-read (format "%s %s (%d): " (garden-icon 'leaf) keyword (length notes))
                                  (garden-completion-table (mapcar #'car table) annotate) nil t)))
    (find-file (garden-note-file (cdr (assoc choice table))))))

(defun garden-search ()
  "Pick any garden note by title and visit it."
  (interactive)
  (let* ((ids (garden-all-ids))
         (table (mapcar (lambda (id) (cons (garden-note-title (garden-note id)) id)) ids))
         (annotate (lambda (title)
                     (when-let* ((id (cdr (assoc title table))))
                       (garden-note-annotation (garden-note id)))))
         (choice (completing-read (format "%s garden (%d): " (garden-icon 'search) (length ids))
                                  (garden-completion-table (mapcar #'car table) annotate) nil t)))
    (find-file (garden-note-file (garden-note (cdr (assoc choice table)))))))

(defun garden-search-text ()
  "Full-text search across all garden notes."
  (interactive)
  (if (fboundp 'consult-ripgrep)
      (consult-ripgrep garden-directory)
    (rgrep (read-string "Search garden: ") "*.org" garden-directory)))

(defun garden-visit-random ()
  "Visit a random garden note."
  (interactive)
  (let ((ids (garden-all-ids)))
    (when ids (find-file (garden-note-file (garden-note (nth (random (length ids)) ids)))))))

(defun garden-reclassify-tag ()
  "Toggle a keyword between topic and meta."
  (interactive)
  (let ((k (completing-read "Toggle topic/meta: " (mapcar #'car (garden-keywords-sorted)) nil t)))
    (garden-toggle-meta k)
    (when (derived-mode-p 'vui-mode) (vui-refresh))))

(defun garden--id-time (id)
  "Return the creation time encoded in the Denote ID."
  (encode-time (list (string-to-number (substring id 13 15))
                     (string-to-number (substring id 11 13))
                     (string-to-number (substring id 9 11))
                     (string-to-number (substring id 6 8))
                     (string-to-number (substring id 4 6))
                     (string-to-number (substring id 0 4))
                     nil -1 nil)))

(defun garden--age-suffix (id)
  "Return a growth-stage age label for note ID, nil when older than a month."
  (let ((days (/ (float-time (time-subtract (current-time) (garden--id-time id))) 86400)))
    (cond ((< days 1) (format "%s just now" (garden-icon 'sprout)))
          ((<= days 7) (format "%s this week" (garden-icon 'leaf)))
          ((<= days 31) (format "%s last month" (garden-icon 'grass))))))

(defun garden--hub-suffix (id maxd)
  "Return height dots and the degree of note ID scaled against MAXD."
  (let* ((degree (garden-degree id))
         (dots (max 1 (ceiling (* 4 (/ (float degree) (max 1 maxd)))))))
    (format "·%s %d" (make-string dots ?•) degree)))

(defun garden--note-button (id &optional suffix width suffix-width)
  "Render a row for note ID with optional SUFFIX.
When WIDTH is given, the title and suffix sit in fixed-width
columns so the action icons line up across rows; otherwise the
row flows.  SUFFIX-WIDTH defaults to 12 columns."
  (let* ((note (garden-note id))
         (file (garden-note-file note))
         (suffix-node (vui-muted (or suffix "")))
         (actions (vui-hstack :spacing 1
                    (vui-button (garden-icon 'preview)
                      :no-decoration t
                      :help-echo "peek in the side window"
                      :on-click (lambda () (garden-preview-show file)))
                    (vui-button (garden-icon 'delete)
                      :no-decoration t
                      :help-echo "move to the trash"
                      :on-click (lambda () (unwind-protect (garden-delete-note id) (garden-fleet--refresh))))))
         (row-width (or width 'fill-column)))
    (vui-flex
     :width row-width :justify :space-between
     (vui-flex-item
      :grow 1
      (lambda (available)
        (vui-button (garden-note-title note)
                    :key id :no-decoration t :help-echo file
                    :max-width available
                    :on-click (lambda () (find-file file)))))
     (when suffix
       (if suffix-width
           (vui-box suffix-node :width suffix-width :align :right)
         suffix-node))
     actions)))

(defun garden--tag-button (k count maxc)
  "Render the meadow button for keyword K used COUNT times out of MAXC."
  (vui-button (format "%s" k)
    :no-decoration t
    :face (garden--tag-face count maxc)
    :help-echo (format "%d notes — click to wander" count)
    :on-click (lambda () (garden-browse-keyword k))))

(defun garden--rule (&optional width)
  "Return a decorative horizontal rule WIDTH columns wide."
  (vui-box (vui-text (format "%s  ·  %s  ·  %s"
                              (garden-icon 'leaf)
                              (garden-icon 'star)
                              (garden-icon 'leaf))
                     :face 'garden-rule)
           :width (max 1 (or width garden-content-width))
           :align :center :face 'fringe))

(defun garden--header ()
  "Render the left-aligned dashboard banner."
  (let ((s (garden-icon 'star))
        (g (garden-icon 'garden)))
    (let ((width (min garden-content-width (garden--window-width))))
      (vui-vstack
       (vui-flex :width 'window :justify :space-between
                 (vui-text (format "%s · %s" s (garden-icon 'leaf))
                           :face 'garden-star)
                 (vui-text (format "%s · %s" (garden-icon 'leaf) s)
                           :face 'garden-star))
       (vui-box (vui-heading-1 (format "%s  cashmere's garden" g))
                :width width :align :center)
       (vui-box (vui-muted "a little constellation of notes — wander slowly")
                :width width :align :center)
       (garden--rule width)))))

(defun garden--toolbar ()
  "Render the dashboard action buttons as responsive toolbars."
  (let ((primary
         (list
          (vui-button (concat (garden-icon 'refresh) " refresh")
            :on-click (lambda () (garden-refresh) (garden-fleet--refresh)))
          (vui-button (concat (garden-icon 'search) " search") :on-click #'garden-search)
          (vui-button (concat (garden-icon 'grep) " grep") :on-click #'garden-search-text)
          (vui-button (concat (garden-icon 'dice) " surprise me") :on-click #'garden-visit-random)
          (vui-button (concat (garden-icon 'publish) " publish…") :on-click #'garden-publish-one)))
        (secondary
         (list
          (vui-button (concat (garden-icon 'cog) " classify tag") :on-click #'garden-reclassify-tag)
          (vui-button (concat (garden-icon 'link) " connect…") :on-click #'garden-connect-pick)
          (vui-button (concat (garden-icon 'fleet) " fleet") :on-click #'garden-fleet)
          (vui-button (concat (garden-icon 'preview) " preview")
            :on-click (lambda () (garden-preview-mode 'toggle) (garden-fleet--refresh)))
          (vui-button (concat (garden-icon 'leaf) " rebuild indexes")
            :on-click (lambda () (garden-update-indexes) (garden-refresh) (garden-fleet--refresh))))))
    (vui-vstack
     (vui-flex :width 'window :justify :start :spacing 1 :indent 2
       (apply #'vui-hstack :spacing 1 primary))
     (vui-flex :width 'window :justify :space-between :spacing 1 :indent 2
       (apply #'vui-hstack :spacing 1 secondary)
       (vui-muted "q quit")))))

(defun garden--health-line ()
  "Return a one-line mood describing the garden's link density."
  (let ((density (/ (float (garden-link-count)) (max 1 (garden-note-count)))))
    (cond ((< density 0.5)
           (format "%s quietly rooting — every link helps it grow" (garden-icon 'web)))
          ((< density 1.2)
           (format "%s a cozy web is forming" (garden-icon 'link)))
          (t
           (format "%s %.1f links per note — a thriving web!" (garden-icon 'sparkle) density)))))

(defun garden--cards ()
  "Render the stat cards and the health line using `vui-table'."
  (let* ((cells (list (cons (concat (garden-icon 'note) " notes") (garden-note-count))
                      (cons (concat (garden-icon 'leaf) " topics") (length (garden-topic-keywords)))
                      (cons (concat (garden-icon 'link) " links") (garden-link-count))
                      (cons (concat (garden-icon 'sprout) " seeds") (length (garden-orphans)))))
         (cols (mapcar (lambda (_) '(:width 14 :align :center)) cells)))
    (vui-vstack
     (vui-table
      :columns cols
      :rows (list
             (mapcar (lambda (c) (vui-text (number-to-string (cdr c)) :face 'garden-card-num)) cells)
             (mapcar (lambda (c) (vui-text (car c) :face 'garden-meta)) cells))
      :border :ascii
      :border-face 'garden-card-frame)
     (vui-text (garden--health-line) :face 'vui-success))))

(defun garden--tag-rows (cols &optional max)
  "Render the topic keywords in COLS columns, MAX tags at most."
  (let* ((all (garden-topic-keywords))
         (topics (if max (seq-take all max) all))
         (maxc (if all (cdar all) 1)))
    (apply #'vui-vstack :indent 1 :spacing 0
           (mapcar (lambda (row)
                     (apply #'vui-hstack :spacing 2
                            (mapcar (lambda (kc) (garden--tag-button (car kc) (cdr kc) maxc)) row)))
                   (garden--chunk topics cols)))))

(defun garden--meadow ()
  "Render the topic meadow tag cloud."
  (vui-vstack
   (vui-heading-2 (concat (garden-icon 'grass) " topic meadow"))
   (garden--tag-rows 6)))

(defun garden--hubs (&optional width)
  "Render the best-connected notes."
  (let* ((hubs (garden-hubs 6))
         (maxd (if hubs (garden-degree (car hubs)) 1)))
    (vui-vstack
     (vui-heading-3 (concat (garden-icon 'tree) " tallest trees"))
     (apply #'vui-vstack :indent 2
            (mapcar (lambda (id) (garden--note-button id (garden--hub-suffix id maxd) width)) hubs)))))

(defun garden--recent (&optional width)
  "Render the most recent notes with their age labels."
  (let ((recent (garden-recent 6)))
    (vui-vstack
     (vui-heading-3 (concat (garden-icon 'sprout) " just sprouted"))
     (apply #'vui-vstack :indent 2
            (mapcar (lambda (id) (garden--note-button id (garden--age-suffix id) width)) recent)))))

(defun garden--orphans ()
  "Render the collapsible list of unlinked notes."
  (let* ((orphans (seq-sort #'string> (garden-orphans)))
         (shown (seq-take orphans 60)))
    (vui-collapsible
     :title (format "%s %d unlinked notes — no links in or out yet"
                    (garden-icon 'fallen) (length orphans))
     :initially-expanded nil
     :title-face 'vui-heading-3
     :expanded-indicator (format "%s " (garden-icon 'down))
     :collapsed-indicator (format "%s " (garden-icon 'up))
     (apply #'vui-vstack :indent 2
            (mapcar (lambda (id) (garden--note-button id)) shown)))))

(defun garden--meta-strip ()
  "Render the strip of meta keywords with toggle buttons."
  (let ((metas (garden-meta-keywords)))
    (when metas
      (vui-vstack
       (vui-heading-3 (concat (garden-icon 'cog) " provenance & status"))
       (apply #'vui-hstack :spacing 2 :indent 2
              (mapcar (lambda (kc)
                        (let ((k (car kc)))
                          (vui-button (format "%s·%d" k (cdr kc))
                            :no-decoration t :face 'garden-meta
                            :help-echo "click → make it a topic"
                            :on-click (lambda () (garden-toggle-meta k) (vui-refresh)))))
                      metas))))))

(defun garden--view-full ()
  "Render the full dashboard view."
  (let* ((width (garden--window-width))
         (wide (>= width 110))
         (panel-width (if wide (max 44 (/ (- width 8) 2)) width)))
    (vui-vstack :spacing 1 :indent 2
      (garden--header)
      (garden--toolbar)
      (garden--cards)
      (if wide
          (vui-hstack
           :spacing 4
           (vui-vstack :spacing 1
                       (garden--meadow)
                       (garden--meta-strip))
           (vui-vstack :spacing 1
                       (garden--hubs panel-width)
                       (garden--recent panel-width)))
        (vui-vstack :spacing 1
                    (garden--meadow)
                    (garden--hubs panel-width)
                    (garden--recent panel-width)
                    (garden--meta-strip)))
      (garden--orphans)
      (vui-flex :width 'window :justify :space-between
                (vui-muted "j/k move · TAB/S-TAB elements · RET/l activate")
                (vui-muted "g refresh · / search · ? help · h/q close")))))

(defun garden--view-compact ()
  "Render the compact sidecar view."
  (let* ((indent 1)
         (width (max 24 (min garden-sidecar-width (garden--window-width))))
         (suffix-w 9)
         (col-w (floor (- width 5) 2))
         (hubs (garden-hubs 6))
         (maxd (if hubs (garden-degree (car hubs)) 1)))
    (vui-vstack :spacing 0 :indent indent
      (vui-flex :width width :justify :space-between :indent indent
        (vui-heading-2 (format "%s garden" (garden-icon 'garden)))
        (vui-text (garden-icon 'star) :face 'garden-star))
      (garden--rule width)
      (vui-table
       :columns `((:width ,col-w :align :center)
                  (:width ,col-w :align :center))
       :rows (list
              (list (vui-text (number-to-string (garden-note-count)) :face 'garden-card-num)
                    (vui-text (number-to-string (length (garden-topic-keywords))) :face 'garden-card-num))
              (list (vui-text (concat (garden-icon 'note) " notes") :face 'garden-meta)
                    (vui-text (concat (garden-icon 'leaf) " topics") :face 'garden-meta))
              (list (vui-text (number-to-string (garden-link-count)) :face 'garden-card-num)
                    (vui-text (number-to-string (length (garden-orphans))) :face 'garden-card-num))
              (list (vui-text (concat (garden-icon 'link) " links") :face 'garden-meta)
                    (vui-text (concat (garden-icon 'sprout) " seeds") :face 'garden-meta)))
       :border :ascii
       :border-face 'garden-card-frame)
      (vui-flex :width width :justify :start :spacing 1 :indent indent
        (vui-button (garden-icon 'refresh)
          :on-click (lambda () (garden-refresh) (garden-fleet--refresh)))
        (vui-button (garden-icon 'search) :on-click #'garden-search)
        (vui-button (garden-icon 'dice) :on-click #'garden-visit-random)
        (vui-button (garden-icon 'publish) :on-click #'garden-publish-one)
        (vui-muted "q"))
      (vui-heading-3 (concat (garden-icon 'grass) " top topics"))
      (garden--tag-rows 2 16)
      (vui-heading-3 (concat (garden-icon 'tree) " hubs"))
      (apply #'vui-vstack
             (mapcar (lambda (id) (garden--note-button id (garden--hub-suffix id maxd) width suffix-w)) hubs))
      (vui-heading-3 (concat (garden-icon 'sprout) " recent"))
      (apply #'vui-vstack
             (mapcar (lambda (id) (garden--note-button id (garden--age-suffix id) width suffix-w)) (garden-recent 6))))))

(defun garden--view ()
  "Render the view matching this buffer's compact flag."
  (if garden--compact (garden--view-compact) (garden--view-full)))

(vui-defcomponent garden-dashboard ()
  :render (garden--view))

(defun garden-dashboard-refresh ()
  "Rebuild the Garden index and redraw the dashboard."
  (interactive)
  (garden-refresh)
  (garden-fleet--refresh))

(defun garden-dashboard-help ()
  "Show Garden dashboard keyboard help."
  (interactive)
  (message "Garden: j/k move, TAB/S-TAB elements, RET/l activate, g refresh, / note search, s text search, h/q close"))

(defvar garden-dashboard-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map vui-mode-map)
    (define-key map (kbd "/") #'garden-search)
    (define-key map (kbd "s") #'garden-search-text)
    (define-key map (kbd "P") #'garden-publish-one)
    (define-key map (kbd "j") #'next-line)
    (define-key map (kbd "k") #'previous-line)
    (define-key map (kbd "TAB") #'vui-forward)
    (define-key map (kbd "<backtab>") #'vui-backward)
    (define-key map (kbd "RET") #'vui-activate)
    (define-key map (kbd "l") #'vui-activate)
    (define-key map (kbd "g") #'garden-dashboard-refresh)
    (define-key map (kbd "?") #'garden-dashboard-help)
    (define-key map (kbd "h") #'vui-quit)
    (define-key map (kbd "q") #'vui-quit)
    map)
  "Keymap for `garden-dashboard-mode'.")

(define-derived-mode garden-dashboard-mode vui-mode "Garden"
  "Explore the Denote garden dashboard."
  (hl-line-mode 1))

(with-eval-after-load 'evil
  (evil-set-initial-state 'garden-dashboard-mode 'normal)
  (evil-define-key* '(normal motion) garden-dashboard-mode-map
    (kbd "j") #'next-line (kbd "k") #'previous-line
    (kbd "RET") #'vui-activate (kbd "l") #'vui-activate
    (kbd "g") #'garden-dashboard-refresh
    (kbd "/") #'garden-search (kbd "s") #'garden-search-text
    (kbd "?") #'garden-dashboard-help
    (kbd "h") #'vui-quit (kbd "q") #'vui-quit))

(defun garden--prepare (compact)
  "Build the index and mount the dashboard, COMPACT when non-nil."
  (garden-build)
  (let ((buffer (get-buffer-create "*garden*")))
    (with-current-buffer buffer
      (garden-dashboard-mode)
      (setq-local garden--compact compact)
      (vui-mount (vui-component 'garden-dashboard) buffer)
      (vui-rerender-on-resize))))

;;;###autoload
(defun garden ()
  "Open the garden dashboard."
  (interactive)
  (garden--prepare nil)
  (switch-to-buffer "*garden*")
  (vui-refresh))

;;;###autoload
(defun garden-sidecar ()
  "Open the compact garden dashboard in a left side window."
  (interactive)
  (garden--prepare t)
  (let ((win (display-buffer-in-side-window
              (get-buffer "*garden*")
              `((side . left) (slot . 0) (window-width . ,garden-sidecar-width)
                (window-parameters . ((no-delete-other-windows . t)))))))
    (when win (select-window win) (vui-refresh))))

(provide 'garden-dashboard)
;;; garden-dashboard.el ends here
