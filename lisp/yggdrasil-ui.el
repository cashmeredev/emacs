;;; yggdrasil-ui.el --- TextUI dashboard for Yggdrasil -*- lexical-binding: t -*-

;; Copyright (C) 2026 cashmere

;; Author: cashmere
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (textui "0.5.1"))
;; Keywords: comm, tools

;;; Commentary:

;; A small TextUI dashboard for the local Yggdrasil node.  It reads
;; `yggdrasilctl -json getSelf' and `getPeers', shows the known .ygg
;; hosts from the personal mesh, and offers one-key refresh plus async
;; ping checks.

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'subr-x)
(require 'textui)
(require 'textui-widgets)

(declare-function evil-local-set-key "evil-core" (state key def))

(defgroup yggdrasil-ui nil
  "TextUI dashboard for the Yggdrasil mesh."
  :group 'applications
  :prefix "yggdrasil-ui-")

(defcustom yggdrasil-ui-control-program "yggdrasilctl"
  "Program used to query the Yggdrasil admin API."
  :type 'string
  :group 'yggdrasil-ui)

(defcustom yggdrasil-ui-service-program "systemctl"
  "Program used to query the Yggdrasil service state."
  :type 'string
  :group 'yggdrasil-ui)

(defcustom yggdrasil-ui-service-name "yggdrasil"
  "System service name for Yggdrasil."
  :type 'string
  :group 'yggdrasil-ui)

(defcustom yggdrasil-ui-known-hosts
  '(("chiefsosa" . "201:6904:7fcb:6fa6:b869:48cc:a863:e9a6")
    ("md" . "202:5e97:a5ba:a207:ce38:ac4a:ca3:8f86")
    ("sportmacher" . "200:aa5e:2bcd:b7b3:7852:a02f:77bc:658a")
    ("moneyspread" . "200:1c8c:1f5:f25d:1a9f:c191:e656:9636"))
  "Known hosts in the private Yggdrasil mesh."
  :type '(alist :key-type string :value-type string)
  :group 'yggdrasil-ui)

(defcustom yggdrasil-ui-reference-file
  (expand-file-name "~/nix/docs/yggdrasil-vpn.org")
  "Org reference file for the local Yggdrasil mesh."
  :type 'file
  :group 'yggdrasil-ui)

(defface yggdrasil-ui-strong '((t :inherit bold))
  "Structural text."
  :group 'yggdrasil-ui)

(defface yggdrasil-ui-faded '((t :inherit shadow))
  "Secondary text."
  :group 'yggdrasil-ui)

(defface yggdrasil-ui-salient '((t :inherit link))
  "Healthy or actionable text."
  :group 'yggdrasil-ui)

(defface yggdrasil-ui-warning '((t :inherit font-lock-warning-face))
  "Degraded status text."
  :group 'yggdrasil-ui)

(defface yggdrasil-ui-critical '((t :inherit error))
  "Failed status text."
  :group 'yggdrasil-ui)

(defconst yggdrasil-ui--buffer-name "*yggdrasil*")

(defvar yggdrasil-ui--buffer nil
  "Live Yggdrasil TextUI buffer.")

(defun yggdrasil-ui--item (value &optional face)
  "Return a single-line item element for VALUE with optional FACE."
  `(:type item
    :format "%v"
    :value ,(if face (propertize value 'face face) value)))

(defun yggdrasil-ui--fixed-item (value width &optional face)
  "Return an item fitted to WIDTH cells."
  `(:type item
    :format "%v"
    :value ,(yggdrasil-ui--fit value width face)
    :layout (:width ,width)))

(defun yggdrasil-ui--text (value &optional layout)
  "Return a wrapping text element for VALUE."
  `(:type :text
    :value ,value
    :layout ,(or layout '(:min-width 24 :grow 1))))

(defun yggdrasil-ui--button (label action focus-id &optional variant)
  "Return a TextUI button LABEL calling ACTION."
  `(:type textui-button
    :value ,label
    :variant ,variant
    :layout (:focus-id ,focus-id)
    :action ,(lambda (&rest _) (funcall action))))

(defun yggdrasil-ui--fit (string width &optional face)
  "Return STRING truncated or padded to WIDTH cells, with optional FACE."
  (let* ((width (max 0 width))
         (value (truncate-string-to-width (format "%s" (or string ""))
                                          width nil nil "..."))
         (padded (concat value
                         (make-string (max 0 (- width (string-width value)))
                                      ?\s))))
    (if face (propertize padded 'face face) padded)))

(defun yggdrasil-ui--plain-fit (string width)
  "Return unpropertized STRING fitted to WIDTH cells."
  (substring-no-properties (yggdrasil-ui--fit string width)))

(defun yggdrasil-ui--cells (&rest cells)
  "Return a row from CELLS.
Each cell is (VALUE WIDTH &optional FACE)."
  (mapconcat (lambda (cell)
               (apply #'yggdrasil-ui--fit cell))
             cells
             "  "))

(defun yggdrasil-ui--rule (width)
  "Return a quiet horizontal rule fitted to WIDTH."
  (yggdrasil-ui--item
   (make-string (max 12 (min width 140)) ?-)
   'yggdrasil-ui-faded))

(defun yggdrasil-ui--run (&rest args)
  "Run `yggdrasilctl -json' with ARGS.
Return (EXIT OUTPUT)."
  (with-temp-buffer
    (list (condition-case nil
              (apply #'call-process yggdrasil-ui-control-program nil t nil
                     (cons "-json" args))
            (error 127))
          (string-trim (buffer-string)))))

(defun yggdrasil-ui--json (&rest args)
  "Run yggdrasilctl ARGS and decode JSON.
Return (ok VALUE) or (error MESSAGE)."
  (pcase-let ((`(,code ,out) (apply #'yggdrasil-ui--run args)))
    (if (zerop code)
        (condition-case err
            (list 'ok (json-parse-string out
                                         :object-type 'alist
                                         :array-type 'list
                                         :null-object nil
                                         :false-object nil))
          (error (list 'error (error-message-string err))))
      (list 'error (if (string-empty-p out)
                       (format "%s exited %s" yggdrasil-ui-control-program code)
                     out)))))

(defun yggdrasil-ui--service-state ()
  "Return the local service state as a string."
  (with-temp-buffer
    (let ((code (condition-case nil
                    (call-process yggdrasil-ui-service-program nil t nil
                                  "is-active" yggdrasil-ui-service-name)
                  (error 127)))
          (out (string-trim (buffer-string))))
      (cond ((zerop code) out)
            ((string-empty-p out) "unknown")
            (t out)))))

(defun yggdrasil-ui--snapshot ()
  "Collect current Yggdrasil status."
  (let ((self (yggdrasil-ui--json "getSelf"))
        (peers (yggdrasil-ui--json "getPeers")))
    (list :updated (format-time-string "%Y-%m-%d %H:%M:%S")
          :service (yggdrasil-ui--service-state)
          :self (and (eq (car self) 'ok) (cadr self))
          :self-error (and (eq (car self) 'error) (cadr self))
          :peers (and (eq (car peers) 'ok) (alist-get 'peers (cadr peers)))
          :peers-error (and (eq (car peers) 'error) (cadr peers))
          :pings nil)))

(defun yggdrasil-ui--format-bytes (bytes)
  "Format BYTES as a compact byte count."
  (let ((n (float (or bytes 0)))
        (units '("B" "KB" "MB" "GB" "TB")))
    (while (and (>= n 1024.0) (cdr units))
      (setq n (/ n 1024.0)
            units (cdr units)))
    (if (string= (car units) "B")
        (format "%dB" (truncate n))
      (format "%.1f%s" n (car units)))))

(defun yggdrasil-ui--format-seconds (seconds)
  "Format SECONDS as uptime."
  (let* ((n (truncate (or seconds 0)))
         (days (/ n 86400))
         (hours (/ (% n 86400) 3600))
         (mins (/ (% n 3600) 60)))
    (cond ((> days 0) (format "%dd %dh" days hours))
          ((> hours 0) (format "%dh %dm" hours mins))
          (t (format "%dm" mins)))))

(defun yggdrasil-ui--format-latency (nsec)
  "Format nanosecond latency NSEC as milliseconds."
  (if nsec
      (format "%.2fms" (/ (float nsec) 1000000.0))
    "-"))

(defun yggdrasil-ui--short-key (key)
  "Return a compact display form for public KEY."
  (cond ((not (stringp key)) "-")
        ((string-empty-p key) "-")
        ((<= (length key) 20) key)
        (t (format "%s...%s"
                   (substring key 0 12)
                   (substring key -8)))))

(defun yggdrasil-ui--up-peers (peers)
  "Count peers with an active connection in PEERS."
  (cl-count-if (lambda (peer) (alist-get 'up peer)) peers))

(defun yggdrasil-ui--state-face (state)
  "Return a face for STATE."
  (cond ((or (eq state t)
             (eq state 'up)
             (member state '("active" "Up")))
         'yggdrasil-ui-salient)
        ((or (null state)
             (eq state 'down)
             (member state '("inactive" "Down")))
         'yggdrasil-ui-critical)
        (t 'yggdrasil-ui-warning)))

(defun yggdrasil-ui--host-ping-state (host)
  "Return latest ping state for HOST."
  (or (cdr (assoc host (plist-get textui-state :pings))) "idle"))

(defun yggdrasil-ui--set-ping (buffer host value)
  "Store ping VALUE for HOST in BUFFER."
  (textui-update
   buffer
   (lambda (state)
     (let* ((next (copy-sequence state))
            (pings (copy-tree (plist-get next :pings))))
       (setf (alist-get host pings nil nil #'equal) value)
       (plist-put next :pings pings)))))

(defun yggdrasil-ui--ping-host (host)
  "Ping HOST.ygg asynchronously and update the dashboard."
  (let* ((buffer (current-buffer))
         (target (concat host ".ygg"))
         (process-buffer (generate-new-buffer (format " *yggdrasil-ping:%s*" host))))
    (yggdrasil-ui--set-ping buffer host "checking")
    (make-process
     :name (format "yggdrasil-ping:%s" host)
     :buffer process-buffer
     :command (list "ping" "-6" "-c" "2" target)
     :noquery t
     :sentinel
     (lambda (proc _event)
       (when (memq (process-status proc) '(exit signal))
         (let ((code (process-exit-status proc))
               (out (when (buffer-live-p (process-buffer proc))
                      (with-current-buffer (process-buffer proc)
                        (buffer-string)))))
           (when (buffer-live-p process-buffer)
             (kill-buffer process-buffer))
           (when (buffer-live-p buffer)
             (with-current-buffer buffer
               (yggdrasil-ui--set-ping
                buffer host
                (if (zerop code)
                    (if (and out (string-match "time=\\([0-9.]+ ms\\)" out))
                        (concat "ok " (match-string 1 out))
                      "ok")
                  "failed"))))))))))

(defun yggdrasil-ui-ping-all ()
  "Ping every known Yggdrasil host."
  (interactive)
  (dolist (host yggdrasil-ui-known-hosts)
    (yggdrasil-ui--ping-host (car host))))

(defun yggdrasil-ui-copy-host ()
  "Copy a known .ygg hostname."
  (interactive)
  (let* ((host (completing-read "Copy host: "
                                (mapcar #'car yggdrasil-ui-known-hosts)
                                nil t))
         (name (concat host ".ygg")))
    (kill-new name)
    (message "Copied %s" name)))

(defun yggdrasil-ui--copy-value (label value)
  "Copy VALUE to the kill ring and report LABEL."
  (kill-new value)
  (message "Copied %s" label))

(defun yggdrasil-ui-refresh ()
  "Refresh the Yggdrasil dashboard."
  (interactive)
  (let ((buffer (or (and (derived-mode-p 'textui-mode) (current-buffer))
                    yggdrasil-ui--buffer)))
    (unless (buffer-live-p buffer)
      (user-error "No live yggdrasil-ui buffer"))
    (textui-update buffer (lambda (_state) (yggdrasil-ui--snapshot)))))

(defun yggdrasil-ui-open-reference ()
  "Open the local Yggdrasil reference file."
  (interactive)
  (find-file yggdrasil-ui-reference-file))

(defun yggdrasil-ui--install-keys ()
  "Install dashboard-local keys."
  (let ((map (copy-keymap textui-mode-map)))
    (define-key map (kbd "r") #'yggdrasil-ui-refresh)
    (define-key map (kbd "p") #'yggdrasil-ui-ping-all)
    (define-key map (kbd "c") #'yggdrasil-ui-copy-host)
    (define-key map (kbd "d") #'yggdrasil-ui-open-reference)
    (define-key map (kbd "q") #'quit-window)
    (use-local-map map)
    (when (featurep 'evil)
      (dolist (state '(normal motion))
        (evil-local-set-key state (kbd "r") #'yggdrasil-ui-refresh)
        (evil-local-set-key state (kbd "p") #'yggdrasil-ui-ping-all)
        (evil-local-set-key state (kbd "c") #'yggdrasil-ui-copy-host)
        (evil-local-set-key state (kbd "d") #'yggdrasil-ui-open-reference)
        (evil-local-set-key state (kbd "q") #'quit-window)))))

(defun yggdrasil-ui--toolbar (state width)
  "Render dashboard toolbar for STATE at WIDTH."
  (let* ((service (plist-get state :service))
         (peers (plist-get state :peers))
         (self (plist-get state :self))
         (up (yggdrasil-ui--up-peers peers))
         (summary
          (format "yggdrasil  service %s  peers %d/%d  routes %s  addr %s"
                  service up (length peers)
                  (or (alist-get 'routing_entries self) "-")
                  (or (alist-get 'address self) "-"))))
    (if (< width 96)
        `(:type :flex
          :direction :column
          :gap 0
          :children
          ((:type item
            :format "%v"
            :value ,(yggdrasil-ui--fit summary width
                                      (yggdrasil-ui--state-face service)))
           (:type :flex
            :direction :row
            :gap 2
            :children
            (,(yggdrasil-ui--button "Refresh" #'yggdrasil-ui-refresh
                                     'refresh 'primary)
             ,(yggdrasil-ui--button "Ping all" #'yggdrasil-ui-ping-all
                                     'ping-all 'primary)
             ,(yggdrasil-ui--button "Docs" #'yggdrasil-ui-open-reference
                                     'docs 'muted)))))
      `(:type :flex
        :direction :row
        :gap 2
        :children
        ((:type item
          :format "%v"
          :value ,(yggdrasil-ui--fit summary
                                    (max 32 (- width 48))
                                    (yggdrasil-ui--state-face service))
          :layout (:width ,(max 32 (- width 48)) :grow 1))
         ,(yggdrasil-ui--button "Refresh" #'yggdrasil-ui-refresh
                                 'refresh 'primary)
         ,(yggdrasil-ui--button "Ping all" #'yggdrasil-ui-ping-all
                                 'ping-all 'primary)
         ,(yggdrasil-ui--button "Docs" #'yggdrasil-ui-open-reference
                                 'docs 'muted))))))

(defun yggdrasil-ui--self-lines (state width)
  "Render local node detail lines for STATE at WIDTH."
  (let ((self (plist-get state :self))
        (error (plist-get state :self-error)))
    (if error
        (list (yggdrasil-ui--item "SELF" 'yggdrasil-ui-strong)
              (yggdrasil-ui--text error '(:min-width 36 :grow 1)))
      (let ((left (if (>= width 100) 54 width))
            (right (max 20 (- width 58))))
        (list
         (yggdrasil-ui--item "SELF" 'yggdrasil-ui-strong)
         (yggdrasil-ui--item
          (if (>= width 100)
              (concat
               (yggdrasil-ui--cells
                (list "address" 8 'yggdrasil-ui-faded)
                (list (alist-get 'address self) (- left 10)))
               "  "
               (yggdrasil-ui--cells
                (list "subnet" 7 'yggdrasil-ui-faded)
                (list (alist-get 'subnet self) right)))
            (yggdrasil-ui--cells
             (list "address" 8 'yggdrasil-ui-faded)
             (list (alist-get 'address self) (- width 10)))))
         (yggdrasil-ui--item
          (if (>= width 100)
              (concat
               (yggdrasil-ui--cells
                (list "version" 8 'yggdrasil-ui-faded)
                (list (alist-get 'build_version self) (- left 10)))
               "  "
               (yggdrasil-ui--cells
                (list "updated" 7 'yggdrasil-ui-faded)
                (list (plist-get state :updated) right)))
            (yggdrasil-ui--cells
             (list "updated" 8 'yggdrasil-ui-faded)
             (list (plist-get state :updated) (- width 10))))))))))

(defun yggdrasil-ui--peer-line (peer width)
  "Return a rendered peer row for PEER at WIDTH."
  (let* ((up (alist-get 'up peer))
         (face (yggdrasil-ui--state-face up))
         (state (if up "up" "down"))
         (remote (alist-get 'remote peer))
         (note (if up
                   (format "up %s" (yggdrasil-ui--format-seconds
                                    (alist-get 'uptime peer)))
                 (or (alist-get 'last_error peer) "-"))))
    (if (< width 92)
        (let ((meta (format "%s  rtt %s  cost %s  rx %s  tx %s"
                            note
                            (yggdrasil-ui--format-latency
                             (alist-get 'latency peer))
                            (or (alist-get 'cost peer) "-")
                            (yggdrasil-ui--format-bytes
                             (alist-get 'bytes_recvd peer))
                            (yggdrasil-ui--format-bytes
                             (alist-get 'bytes_sent peer)))))
          (list
           (yggdrasil-ui--item
            (yggdrasil-ui--cells
             (list state 5 face)
             (list remote (- width 7) face)))
           (yggdrasil-ui--item
            (yggdrasil-ui--cells
             (list "" 5)
             (list meta (- width 7)
                   (if up 'yggdrasil-ui-faded 'yggdrasil-ui-critical))))))
      (list
       (yggdrasil-ui--item
        (yggdrasil-ui--cells
         (list state 5 face)
         (list remote 28 face)
         (list (yggdrasil-ui--format-latency (alist-get 'latency peer)) 8)
         (list (or (alist-get 'cost peer) "-") 5)
         (list (yggdrasil-ui--format-bytes (alist-get 'bytes_recvd peer)) 8)
         (list (yggdrasil-ui--format-bytes (alist-get 'bytes_sent peer)) 8)
         (list (or (alist-get 'address peer) "-") 39 'yggdrasil-ui-faded)
         (list note (max 12 (- width 119))
               (if up 'yggdrasil-ui-faded 'yggdrasil-ui-critical))))))))

(defun yggdrasil-ui--peer-lines (state width)
  "Render peer table lines for STATE at WIDTH."
  (let ((peers (plist-get state :peers))
        (error (plist-get state :peers-error)))
    (append
     (list (yggdrasil-ui--item "PEERS" 'yggdrasil-ui-strong))
     (if error
         (list (yggdrasil-ui--text error '(:min-width 36 :grow 1)))
       (if (< width 92)
           (list (yggdrasil-ui--item
                  (yggdrasil-ui--cells
                   (list "state" 5 'yggdrasil-ui-faded)
                   (list "remote / note" (- width 7) 'yggdrasil-ui-faded))))
         (list (yggdrasil-ui--item
                (yggdrasil-ui--cells
                 (list "state" 5 'yggdrasil-ui-faded)
                 (list "remote" 28 'yggdrasil-ui-faded)
                 (list "rtt" 8 'yggdrasil-ui-faded)
                 (list "cost" 5 'yggdrasil-ui-faded)
                 (list "rx" 8 'yggdrasil-ui-faded)
                 (list "tx" 8 'yggdrasil-ui-faded)
                 (list "address" 39 'yggdrasil-ui-faded)
                 (list "note" (max 12 (- width 119)) 'yggdrasil-ui-faded)))))
       (mapcan (lambda (peer) (yggdrasil-ui--peer-line peer width)) peers)))))

(defun yggdrasil-ui--host-line (host width)
  "Return a rendered host row for HOST at WIDTH."
  (let* ((name (car host))
         (address (cdr host))
         (ping (yggdrasil-ui--host-ping-state name))
         (face (cond ((string-prefix-p "ok" ping) 'yggdrasil-ui-salient)
                     ((string= ping "failed") 'yggdrasil-ui-critical)
                     ((string= ping "checking") 'yggdrasil-ui-warning)
                     (t 'yggdrasil-ui-faded))))
    (yggdrasil-ui--item
     (if (< width 82)
         (yggdrasil-ui--cells
          (list name 13 'yggdrasil-ui-strong)
          (list (concat name ".ygg") 22 'yggdrasil-ui-faded)
          (list ping (max 10 (- width 39)) face))
       (yggdrasil-ui--cells
        (list name 13 'yggdrasil-ui-strong)
        (list (concat name ".ygg") 22 'yggdrasil-ui-faded)
        (list address 39)
        (list ping (max 10 (- width 80)) face))))))

(defun yggdrasil-ui--host-lines (width)
  "Render known host table lines at WIDTH."
  (append
   (list (yggdrasil-ui--item "HOSTS" 'yggdrasil-ui-strong)
         (if (< width 82)
             (yggdrasil-ui--item
              (yggdrasil-ui--cells
               (list "host" 13 'yggdrasil-ui-faded)
               (list "name" 22 'yggdrasil-ui-faded)
               (list "ping" (max 10 (- width 39)) 'yggdrasil-ui-faded)))
           (yggdrasil-ui--item
            (yggdrasil-ui--cells
             (list "host" 13 'yggdrasil-ui-faded)
             (list "name" 22 'yggdrasil-ui-faded)
             (list "address" 39 'yggdrasil-ui-faded)
             (list "ping" (max 10 (- width 80)) 'yggdrasil-ui-faded)))))
   (mapcar (lambda (host) (yggdrasil-ui--host-line host width))
           yggdrasil-ui-known-hosts)))

(defun yggdrasil-ui--card (title children &optional width min-width)
  "Return a compact bordered card named TITLE containing CHILDREN."
  (let* ((outer (or width 34))
         (inner (max 1 (- outer 4))))
    `(:type :flex
      :direction :column
      :border t
      :padding 1
      :gap 0
      :layout (:width ,outer
               :min-width ,(or min-width 24)
               :grow 0)
      :children
      (,(yggdrasil-ui--fixed-item title inner 'yggdrasil-ui-strong)
       ,@children))))

(defun yggdrasil-ui--summary-card (state)
  "Render the main status card for STATE."
  (let* ((service (plist-get state :service))
         (peers (plist-get state :peers))
         (self (plist-get state :self))
         (up (yggdrasil-ui--up-peers peers))
         (inner 34))
    (yggdrasil-ui--card
     "yggdrasil"
     (list
      (yggdrasil-ui--fixed-item
       (format "service  %s" service)
       inner
       (yggdrasil-ui--state-face service))
      (yggdrasil-ui--fixed-item
       (format "peers    %d/%d up" up (length peers))
       inner
       (if (> up 0) 'yggdrasil-ui-salient 'yggdrasil-ui-critical))
      (yggdrasil-ui--fixed-item
       (format "routes   %s" (or (alist-get 'routing_entries self) "-"))
       inner)
      (yggdrasil-ui--fixed-item
       (format "updated  %s" (plist-get state :updated))
       inner
       'yggdrasil-ui-faded)
      `(:type :flex
        :direction :row
        :gap 1
        :children
        (,(yggdrasil-ui--button "Refresh" #'yggdrasil-ui-refresh
                                 'refresh 'primary)
         ,(yggdrasil-ui--button "Ping all" #'yggdrasil-ui-ping-all
                                 'ping-all 'primary)
         ,(yggdrasil-ui--button "Docs" #'yggdrasil-ui-open-reference
                                 'docs 'muted))))
     38 28)))

(defun yggdrasil-ui--self-card (state)
  "Render the local node card for STATE."
  (let ((self (plist-get state :self))
        (error (plist-get state :self-error)))
    (if error
        (yggdrasil-ui--card
         "self"
         (list (yggdrasil-ui--text error '(:min-width 26 :grow 1)))
         48 30)
      (yggdrasil-ui--card
       "self"
       (list
        (yggdrasil-ui--fixed-item
         (format "address  %s" (or (alist-get 'address self) "-"))
         50)
        (yggdrasil-ui--fixed-item
         (format "subnet   %s" (or (alist-get 'subnet self) "-"))
         50)
        (yggdrasil-ui--fixed-item
         (format "key      %s" (yggdrasil-ui--short-key
                                (alist-get 'key self)))
         50
         'yggdrasil-ui-faded)
        (when-let* ((key (alist-get 'key self)))
          (yggdrasil-ui--button
           "Copy key"
           (lambda () (yggdrasil-ui--copy-value "self public key" key))
           'copy-self-key
           'muted))
        (yggdrasil-ui--fixed-item
         (format "version  %s" (or (alist-get 'build_version self) "-"))
         50
         'yggdrasil-ui-faded))
       54 34))))

(defun yggdrasil-ui--peer-card (peer)
  "Render PEER as a compact card."
  (let* ((up (alist-get 'up peer))
         (state (if up "Up" "Down"))
         (remote (or (alist-get 'remote peer) "-"))
         (key (alist-get 'key peer))
         (note (if up
                   (format "uptime %s" (yggdrasil-ui--format-seconds
                                        (alist-get 'uptime peer)))
                 (or (alist-get 'last_error peer) "-")))
         (inner 38))
    (yggdrasil-ui--card
     (concat state "  " remote)
     (list
      (yggdrasil-ui--fixed-item
       (format "addr  %s" (or (alist-get 'address peer) "-"))
       inner
       'yggdrasil-ui-faded)
      (yggdrasil-ui--fixed-item
       (format "rtt   %s  cost %s"
               (yggdrasil-ui--format-latency (alist-get 'latency peer))
               (or (alist-get 'cost peer) "-"))
       inner)
      (yggdrasil-ui--fixed-item
       (format "rx    %s  tx %s"
               (yggdrasil-ui--format-bytes (alist-get 'bytes_recvd peer))
               (yggdrasil-ui--format-bytes (alist-get 'bytes_sent peer)))
       inner)
      (yggdrasil-ui--fixed-item
       (format "key   %s" (yggdrasil-ui--short-key
                           (alist-get 'key peer)))
       inner
       'yggdrasil-ui-faded)
      (when (and (stringp key) (not (string-empty-p key)))
        (yggdrasil-ui--button
         "Copy key"
         (lambda () (yggdrasil-ui--copy-value "peer public key" key))
         (intern (format "copy-peer-key-%s" (sxhash key)))
         'muted))
      (yggdrasil-ui--fixed-item
       note
       inner
       (if up 'yggdrasil-ui-faded 'yggdrasil-ui-critical)))
     42 30)))

(defun yggdrasil-ui--host-card (host)
  "Render known HOST as a compact card."
  (let* ((name (car host))
         (address (cdr host))
         (ping (yggdrasil-ui--host-ping-state name))
         (face (cond ((string-prefix-p "ok" ping) 'yggdrasil-ui-salient)
                     ((string= ping "failed") 'yggdrasil-ui-critical)
                     ((string= ping "checking") 'yggdrasil-ui-warning)
                     (t 'yggdrasil-ui-faded)))
         (inner 32))
    (yggdrasil-ui--card
     name
     (list
      (yggdrasil-ui--fixed-item (concat name ".ygg") inner 'yggdrasil-ui-faded)
      (yggdrasil-ui--fixed-item address inner)
      (yggdrasil-ui--fixed-item (format "ping  %s" ping) inner face)
      `(:type :flex
        :direction :row
        :gap 1
        :children
        (,(yggdrasil-ui--button
           "Ping"
           (lambda () (yggdrasil-ui--ping-host name))
           (intern (format "ping-%s" name))
           'primary)
         ,(yggdrasil-ui--button
           "Copy"
           (lambda ()
             (kill-new (concat name ".ygg"))
             (message "Copied %s.ygg" name))
           (intern (format "copy-%s" name))
           'muted))))
     36 28)))

(defun yggdrasil-ui--cards-frame (width)
  "Render the card-based Yggdrasil dashboard."
  (let ((peer-columns (if (< width 90) 1 2))
        (host-columns (cond ((< width 86) 1)
                            (t 2))))
    (append
     (list
      `(:type :flex
        :direction :row
        :gap 1
        :children
        (,(yggdrasil-ui--summary-card textui-state)
         ,(yggdrasil-ui--self-card textui-state)))
      (yggdrasil-ui--item "peers" 'yggdrasil-ui-strong))
   (if (plist-get textui-state :peers-error)
       (list (yggdrasil-ui--text (plist-get textui-state :peers-error)))
     (list
      `(:type :grid
        :columns ,peer-columns
        :min-column-width 30
        :gap 1
        :children ,(mapcar #'yggdrasil-ui--peer-card
                            (plist-get textui-state :peers)))))
   (list
    (yggdrasil-ui--item "hosts" 'yggdrasil-ui-strong)
    `(:type :grid
      :columns ,host-columns
      :min-column-width 28
      :gap 1
      :children ,(mapcar #'yggdrasil-ui--host-card
                          yggdrasil-ui-known-hosts))
    (yggdrasil-ui--item "keys: r refresh  p ping all  c copy host  d docs  q quit"
                        'yggdrasil-ui-faded)))))

(defun yggdrasil-ui--frame (width)
  "Render the Yggdrasil dashboard."
  (list
   `(:type :flex
     :direction :column
     :gap 1
     :children ,(yggdrasil-ui--cards-frame width))))

;;;###autoload
(defun yggdrasil-ui ()
  "Open the Yggdrasil TextUI dashboard."
  (interactive)
  (setq yggdrasil-ui--buffer
        (textui-open yggdrasil-ui--buffer-name
                     #'yggdrasil-ui--frame
                     (yggdrasil-ui--snapshot)))
  (with-current-buffer yggdrasil-ui--buffer
    (yggdrasil-ui--install-keys))
  yggdrasil-ui--buffer)

(provide 'yggdrasil-ui)
;;; yggdrasil-ui.el ends here
