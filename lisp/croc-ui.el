;;; croc-ui.el --- -*- lexical-binding: t -*-

;; Copyright (C) 2026 cashmere

;; Author: cashmere
;; Version: 0.2.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: comm, tools

;;; Commentary:

;; A keyboard-first, Rougier-style front-end for croc(1), the
;; peer-to-peer file transfer tool.  The `*croc*' dashboard shows the
;; current share code as a hero, a link-farm of key hints, and a
;; hairline feed of transfers with live progress chips.  Each
;; transfer is a real croc process; its raw log is one RET away.
;;
;; Archetype: hero + link farm + hairline feed (mu4e-dashboard /
;; mastodon-alt idioms).  Faces are theme-agnostic: `link' = salient,
;; `shadow' = faded, `bold' = strong, `error' = critical, inverse
;; video = chips and selection.  No color is ever computed at load
;; time, so the UI tracks live theme switches.
;;
;; When a send waits, its code also shows as a QR card the official
;; croc app can scan.  The QR encoder is pure Elisp (no qrencode(1))
;; and renders as half-block text, so it works identically in a GUI
;; and in `emacs -nw'.
;;
;; Keys (dashboard):
;;   s send file(s)   d send folder   t send text   r receive
;;   RET log          w copy code     Q qr          x kill
;;   X clear done     n/p next/prev   g refresh     q quit
;;
;; Evil: normal state gets j/k plus the same one-key actions.

;;; Code:

(require 'cl-lib)
(require 'ansi-color)

;;; § 1 Faces (theme-agnostic, recipe 0)

(defface croc-ui-strong '((t :inherit bold))
  "Structural text: title, file names."
  :group 'croc-ui)

(defface croc-ui-faded '((t :inherit shadow))
  "Secondary text: hints, metadata, placeholders."
  :group 'croc-ui)

(defface croc-ui-salient '((t :inherit link))
  "Attention: share codes, direction glyphs."
  :group 'croc-ui)

(defface croc-ui-critical '((t :inherit (error bold)))
  "Failed transfers.  Used scarcely."
  :group 'croc-ui)

(defface croc-ui-chip '((t :inherit bold :inverse-video t))
  "Active state chip."
  :group 'croc-ui)

(defface croc-ui-chip-i '((t :inherit shadow :inverse-video t))
  "Inactive state chip."
  :group 'croc-ui)

(defface croc-ui-chip-active '((t :inherit link :inverse-video t))
  "In-progress state chip: the salient accent, inverted."
  :group 'croc-ui)

(defface croc-ui-chip-critical '((t :inherit (error bold) :inverse-video t))
  "Failed state chip."
  :group 'croc-ui)

(defface croc-ui-selected '((t :inherit bold :inverse-video t))
  "Selected row (hl-line remap target).  Pure inverse: always theme-fresh."
  :group 'croc-ui)

(defface croc-ui-hairline
  '((t :inherit default :strike-through t :overline nil :underline nil
       :height 1.0 :extend t))
  "Full-width rule drawn by a strike-through newline."
  :group 'croc-ui)

;;; § 2 Customs

(defgroup croc-ui nil
  "Dashboard for the croc file transfer CLI."
  :group 'applications
  :prefix "croc-ui-")

(defcustom croc-ui-program "croc"
  "Path to the croc executable."
  :type 'string
  :group 'croc-ui)

(defcustom croc-ui-receive-directory
  (let ((dl (expand-file-name "~/Downloads/")))
    (if (file-directory-p dl) dl (expand-file-name "~/")))
  "Default folder offered when receiving files."
  :type 'directory
  :group 'croc-ui)

(defcustom croc-ui-extra-arguments nil
  "Extra global flags appended to every croc invocation (e.g. relay options)."
  :type '(repeat string)
  :group 'croc-ui)

(defcustom croc-ui-show-qr t
  "When non-nil, show a QR card of the waiting share code in the dashboard."
  :type 'boolean
  :group 'croc-ui)

;;; § 3 Data layer

(cl-defstruct (croc-ui--transfer (:constructor croc-ui--transfer-create))
  id direction label code (state 'starting) (progress 0)
  process buffer started)

(defvar croc-ui--transfers nil
  "Live list of `croc-ui--transfer' structs, newest first.")

(defvar croc-ui--counter 0
  "Monotonic transfer id source.")

(defconst croc-ui--buffer-name "*croc*"
  "Dashboard buffer name.")

(defconst croc-ui--symbols
  '((send . ("^" . "↑"))
    (recv . ("v" . "↓")))
  "Direction glyphs: (ASCII-fallback . preferred).")

(defun croc-ui--symbol (name)
  "Glyph for NAME, degrading to ASCII when undisplayable."
  (let ((pair (alist-get name croc-ui--symbols)))
    (if (and (cdr pair) (char-displayable-p (aref (cdr pair) 0)))
        (cdr pair)
      (car pair))))

(defun croc-ui--find (id)
  "Transfer struct with ID."
  (cl-find id croc-ui--transfers :key #'croc-ui--transfer-id))

(defun croc-ui--live-p (tr)
  "Non-nil when TR's process is still running."
  (and (croc-ui--transfer-process tr)
       (process-live-p (croc-ui--transfer-process tr))))

(defun croc-ui--hero-transfer ()
  "The transfer whose code deserves the hero slot: newest waiting send."
  (cl-find-if (lambda (tr)
                (and (eq (croc-ui--transfer-direction tr) 'send)
                     (eq (croc-ui--transfer-state tr) 'waiting)
                     (croc-ui--transfer-code tr)))
              croc-ui--transfers))

;;; § 4 Process layer

(defvar-local croc-ui--log-transfer nil
  "Back-reference from a log buffer to its transfer struct.")

(define-derived-mode croc-ui-log-mode special-mode "croc-log"
  "Mode for raw croc process logs."
  (setq-local truncate-lines t)
  (local-set-key (kbd "w") #'croc-ui-copy-code)
  (local-set-key (kbd "x") #'croc-ui-kill))

(defun croc-ui--filter (proc chunk)
  "Append CHUNK to PROC's log and fold its state into the transfer struct."
  (let ((tr (process-get proc 'croc-ui-transfer)))
    (when (buffer-live-p (process-buffer proc))
      (with-current-buffer (process-buffer proc)
        (let ((inhibit-read-only t))
          (goto-char (point-max))
          (let ((beg (point)))
            (insert chunk)
            (ansi-color-apply-on-region beg (point-max))))))
    (when tr
      (let ((state (croc-ui--transfer-state tr))
            refresh)
        ;; Share code: scan the tail so a chunk split cannot hide it.
        (when (and (not (croc-ui--transfer-code tr))
                   (buffer-live-p (process-buffer proc)))
          (with-current-buffer (process-buffer proc)
            (save-excursion
              (goto-char (point-max))
              (when (re-search-backward "Code is: \\([^ \t\n]+\\)"
                                        (max (point-min) (- (point) 1024)) t)
                (setf (croc-ui--transfer-code tr) (match-string 1))
                (setq refresh t)))))
        (when (string-match "\\([0-9]+\\(?:\\.[0-9]+\\)?\\)%" chunk)
          (let ((p (min 100 (truncate (string-to-number (match-string 1 chunk))))))
            (when (> p (croc-ui--transfer-progress tr))
              (setf (croc-ui--transfer-progress tr) p))
            (unless (eq state 'active)
              (setf (croc-ui--transfer-state tr) 'active)
              (setq refresh t))
            (croc-ui--update-chip tr)))
        (when (and (eq (croc-ui--transfer-state tr) 'starting)
                   (croc-ui--transfer-code tr))
          (setf (croc-ui--transfer-state tr) 'waiting)
          (setq refresh t))
        (when refresh (croc-ui-refresh))))))

(defun croc-ui--sentinel (proc _event)
  "Fold PROC's exit into its transfer struct.
croc prints no completion message: success means exit 0 AND a 100%
progress line in the log.  croc also exits 0 after printing mere usage
text (e.g. a rejected code argument) — that path has no progress line
and MUST read as failed, not done."
  (when-let* ((tr (process-get proc 'croc-ui-transfer)))
    (unless (memq (croc-ui--transfer-state tr) '(done failed cancelled))
      (setf (croc-ui--transfer-state tr)
            (if (and (zerop (process-exit-status proc))
                     (buffer-live-p (process-buffer proc))
                     (with-current-buffer (process-buffer proc)
                       (save-excursion
                         (goto-char (point-min))
                         (search-forward "100%" nil t))))
                (progn (setf (croc-ui--transfer-progress tr) 100) 'done)
              'failed)))
    (croc-ui-refresh)))

(defun croc-ui--spawn (direction label args &optional env)
  "Start a croc transfer in DIRECTION (`send' or `recv') labelled LABEL.
ARGS are the croc command line (global flags must precede any subcommand).
ENV is a list of \"KEY=VALUE\" strings visible only to the child process
\(used for CROC_SECRET, so the code never appears in the process list).
Returns the new transfer struct."
  (unless (executable-find croc-ui-program)
    (user-error "croc executable not found (croc-ui-program)"))
  (let* ((id (cl-incf croc-ui--counter))
         (buf (get-buffer-create (format "*croc#%d %s*" id label)))
         (tr (croc-ui--transfer-create
              :id id :direction direction :label label
              :state (if (eq direction 'send) 'starting 'waiting)
              :buffer buf :started (current-time))))
    (with-current-buffer buf
      (let ((inhibit-read-only t)) (erase-buffer))
      (croc-ui-log-mode)
      (setq-local croc-ui--log-transfer tr))
    (setf (croc-ui--transfer-process tr)
          (let ((process-environment (append env process-environment)))
            (make-process :name (format "croc#%d" id)
                          :buffer buf
                          :command (append (list croc-ui-program)
                                           croc-ui-extra-arguments
                                           args)
                          :filter #'croc-ui--filter
                          :sentinel #'croc-ui--sentinel
                          :noquery t)))
    (process-put (croc-ui--transfer-process tr) 'croc-ui-transfer tr)
    (push tr croc-ui--transfers)
    (croc-ui-refresh)
    tr))

;;; § 5 Layout primitives

(defun croc-ui--width ()
  "Render width: the dashboard window when visible, else 80."
  (if-let* ((win (get-buffer-window croc-ui--buffer-name)))
      (window-width win)
    80))

(defun croc-ui--justify (left right)
  "Join LEFT and RIGHT with elastic space; truncate LEFT with an ellipsis."
  (let* ((width (croc-ui--width))
         (left (truncate-string-to-width
                left (max 8 (- width (length right) 2)) nil nil "…"))
         (pad (propertize " " 'display
                          `(space :align-to (- right ,(+ (length right) 1))))))
    (concat left pad right)))

(defun croc-ui--hairline ()
  "A full-width rule that doubles as a section anchor."
  (propertize "\n" 'face 'croc-ui-hairline 'croc-ui-hairline t))

(defun croc-ui--chip (tr)
  "Fixed-width (6) state chip for TR."
  (pcase (croc-ui--transfer-state tr)
    ('starting  (propertize " PREP " 'face 'croc-ui-chip-i))
    ('waiting   (propertize " WAIT " 'face 'croc-ui-chip-i))
    ('active    (propertize (format " %3d%% " (croc-ui--transfer-progress tr))
                            'face 'croc-ui-chip-active))
    ('done      (propertize " DONE " 'face 'croc-ui-chip))
    ('failed    (propertize " FAIL " 'face 'croc-ui-chip-critical))
    ('cancelled (propertize " STOP " 'face 'croc-ui-chip-i))
    (_          (propertize "  ??  " 'face 'croc-ui-chip-i))))

(defun croc-ui--button (text action help)
  "Clickable TEXT running ACTION, with HELP echo."
  (propertize text 'pointer 'hand 'mouse-face 'highlight 'follow-link t
              'help-echo help
              'keymap (let ((map (make-sparse-keymap)))
                        (define-key map [mouse-2] action)
                        (define-key map (kbd "RET") action)
                        map)))

;;; § 6 QR layer (pure Elisp, no dependencies)

;; A self-contained QR encoder: byte mode, EC level L, versions 1-10
;; (up to 271 bytes — a croc code is ~25).  No qrencode(1), no C
;; module, so the card works identically in a GUI and in `emacs -nw'.
;; Rendering pairs two module rows per glyph with UPPER HALF BLOCK,
;; which makes every module a perfect square in any fixed-pitch font.
;; Colors are explicit black/white — the one place we do NOT inherit
;; the theme: a QR only scans with guaranteed contrast, whatever the
;; theme says.

(defconst croc-ui--qr-capacity [17 32 53 78 106 134 154 192 230 271]
  "Byte-mode payload (characters) for versions 1-10, EC level L.")

(defconst croc-ui--qr-data-codewords [19 34 55 80 108 136 156 194 232 274]
  "Data codewords for versions 1-10, EC level L.")

(defconst croc-ui--qr-block-spec
  '((7  (1 . 19))             ; v1
    (10 (1 . 34))             ; v2
    (15 (1 . 55))             ; v3
    (20 (1 . 80))             ; v4
    (26 (1 . 108))            ; v5
    (18 (2 . 68))             ; v6
    (20 (2 . 78))             ; v7
    (24 (2 . 97))             ; v8
    (30 (2 . 116))            ; v9
    (18 (2 . 68) (2 . 69)))   ; v10
  "(EC-PER-BLOCK (BLOCKS . DATA-CW) [(BLOCKS . DATA-CW)]) per version 1-10, L.")

(defconst croc-ui--qr-alignment
  [nil nil (6 18) (6 22) (6 26) (6 30) (6 34) (6 22 38) (6 24 42) (6 26 46) (6 28 50)]
  "Alignment pattern centers, indexed by version (v1 has none).")

;; GF(2^8) arithmetic for Reed-Solomon, primitive polynomial x^8+x^4+x^3+x^2+1.

(defvar croc-ui--qr-gf-exp (make-vector 512 0))
(defvar croc-ui--qr-gf-log (make-vector 256 0))

(defun croc-ui--qr-gf-init ()
  "Fill the GF(2^8) log/exp tables."
  (let ((x 1))
    (dotimes (i 255)
      (aset croc-ui--qr-gf-exp i x)
      (aset croc-ui--qr-gf-log x i)
      (setq x (ash x 1))
      (when (>= x 256)
        (setq x (logxor x #x11d))))
    (dotimes (i 255)
      (aset croc-ui--qr-gf-exp (+ i 255) (aref croc-ui--qr-gf-exp i)))))
(croc-ui--qr-gf-init)

(defun croc-ui--qr-gf-mul (a b)
  "Multiply A and B in GF(2^8)."
  (if (or (zerop a) (zerop b))
      0
    (aref croc-ui--qr-gf-exp
          (+ (aref croc-ui--qr-gf-log a) (aref croc-ui--qr-gf-log b)))))

(defvar croc-ui--qr-rs-poly-cache nil
  "Memoized Reed-Solomon generator polynomials, (DEGREE . COEFFS).")

(defun croc-ui--qr-rs-poly (n)
  "RS generator polynomial of degree N, coefficients highest-degree first."
  (or (cdr (assq n croc-ui--qr-rs-poly-cache))
      (let ((poly (list 1)))
        (dotimes (i n)
          (let ((root (aref croc-ui--qr-gf-exp i))
                (next (make-list (1+ (length poly)) 0)))
            (dotimes (j (length poly))
              (setf (nth j next) (logxor (nth j next) (nth j poly)))
              (setf (nth (1+ j) next)
                    (logxor (nth (1+ j) next)
                            (croc-ui--qr-gf-mul (nth j poly) root))))
            (setq poly next)))
        (push (cons n poly) croc-ui--qr-rs-poly-cache)
        poly)))

(defun croc-ui--qr-rs-ec (data n poly)
  "N Reed-Solomon check bytes for DATA (list of bytes) using POLY."
  (let ((res (append data (make-list n 0))))
    (dotimes (i (length data))
      (let ((coef (nth i res)))
        (unless (zerop coef)
          (dotimes (j (1+ n))
            (setf (nth (+ i j) res)
                  (logxor (nth (+ i j) res)
                          (croc-ui--qr-gf-mul (nth j poly) coef)))))))
    (nthcdr (length data) res)))

(defun croc-ui--qr-data-codewords (bytes version)
  "Mode header + BYTES + terminator + padding, as a list of codewords."
  (let* ((total (aref croc-ui--qr-data-codewords (1- version)))
         (count-bits (if (>= version 10) 16 8))
         (bits nil))
    (cl-flet ((emit (value width)
                (dotimes (i width)
                  (push (logand (ash value (- i (1- width))) 1) bits))))
      (emit 4 4)                       ; 0100 = byte mode
      (emit (length bytes) count-bits)
      (dolist (b bytes) (emit b 8)))
    (setq bits (nreverse bits))
    (let ((capacity (* total 8)))
      (setq bits (append bits (make-list (min 4 (- capacity (length bits))) 0)))
      (let ((rem (% (length bits) 8)))
        (unless (zerop rem)
          (setq bits (append bits (make-list (- 8 rem) 0))))))
    (let ((out nil))
      (while bits
        (let ((byte 0))
          (dotimes (_ 8)
            (setq byte (logior (ash byte 1) (pop bits))))
          (push byte out)))
      (setq out (nreverse out))
      (let ((pad #xec))
        (while (< (length out) total)
          (setq out (append out (list pad)))
          (setq pad (if (= pad #xec) #x11 #xec))))
      out)))

(defun croc-ui--qr-interleave (data version)
  "Split DATA into RS blocks, ECC each, interleave; return a vector."
  (pcase-let ((`(,ec ,g1 ,g2) (nth (1- version) croc-ui--qr-block-spec)))
    (let ((poly (croc-ui--qr-rs-poly ec))
          (blocks nil)
          (offset 0))
      (dolist (group (if g2 (list g1 g2) (list g1)))
        (dotimes (_ (car group))
          (let* ((len (cdr group))
                 (chunk (cl-subseq data offset (+ offset len))))
            (push (cons chunk (croc-ui--qr-rs-ec chunk ec poly)) blocks)
            (setq offset (+ offset len)))))
      (setq blocks (nreverse blocks))
      (let ((out nil)
            (maxlen (apply #'max (mapcar (lambda (b) (length (car b))) blocks))))
        (dotimes (i maxlen)
          (dolist (b blocks)
            (when (< i (length (car b)))
              (push (nth i (car b)) out))))
        (dotimes (i ec)
          (dolist (b blocks)
            (push (nth i (cdr b)) out)))
        (vconcat (nreverse out))))))

(defun croc-ui--qr-bch-digit (n)
  "Bit length of N."
  (let ((d 0))
    (while (> n 0)
      (setq n (ash n -1))
      (cl-incf d))
    d))

(defun croc-ui--qr-format-bits (mask)
  "15 format bits for EC level L and MASK: BCH(15,5) masked with 0x5412."
  (let* ((data (logior (ash #b01 3) mask)) ; L = 01
         (rem (ash data 10))
         (div (croc-ui--qr-bch-digit #x537)))
    (while (>= (- (croc-ui--qr-bch-digit rem) div) 0)
      (setq rem (logxor rem (ash #x537 (- (croc-ui--qr-bch-digit rem) div)))))
    (logxor (logior (ash data 10) rem) #x5412)))

(defun croc-ui--qr-version-bits (version)
  "18 version bits for VERSION (7+ only): BCH(18,6)."
  (let ((rem (ash version 12))
        (div (croc-ui--qr-bch-digit #x1f25)))
    (while (>= (- (croc-ui--qr-bch-digit rem) div) 0)
      (setq rem (logxor rem (ash #x1f25 (- (croc-ui--qr-bch-digit rem) div)))))
    (logior (ash version 12) rem)))

(defun croc-ui--qr-mask-p (mask r c)
  "Non-nil when MASK flips the module at row R, column C."
  (pcase mask
    (0 (zerop (% (+ r c) 2)))
    (1 (zerop (% r 2)))
    (2 (zerop (% c 3)))
    (3 (zerop (% (+ r c) 3)))
    (4 (zerop (% (+ (/ r 2) (/ c 3)) 2)))
    (5 (zerop (+ (% (* r c) 2) (% (* r c) 3))))
    (6 (zerop (% (+ (% (* r c) 2) (% (* r c) 3)) 2)))
    (7 (zerop (% (+ (% (+ r c) 2) (% (* r c) 3)) 2)))))

(defun croc-ui--qr-reserve-format (fn)
  "Flag the format cells in FN so data placement skips them."
  (let ((size (length fn)))
    (dotimes (i 9)
      (unless (aref (aref fn 8) i) (aset (aref fn 8) i 'format))
      (unless (aref (aref fn i) 8) (aset (aref fn i) 8 'format)))
    (dotimes (i 8)
      (aset (aref fn 8) (- size i 1) 'format)
      (aset (aref fn (- size i 1)) 8 'format))))

(defun croc-ui--qr-write-format (m bits)
  "Write the 15 format BITS into M (both copies) plus the dark module."
  (let ((size (length m)))
    (dotimes (i 15)
      (let ((bit (logand (ash bits (- i)) 1)))
        (aset (aref m (cond ((< i 6) i)
                            ((< i 8) (1+ i))
                            (t (+ size i -15))))
              8 bit)
        (aset (aref m 8)
              (cond ((< i 8) (- size i 1))
                    ((= i 8) 7)
                    (t (- 14 i)))
              bit)))
    (aset (aref m (- size 8)) 8 1)))

(defun croc-ui--qr-build (version codewords mask)
  "Assemble the module matrix for VERSION around CODEWORDS, applying MASK."
  (let* ((size (+ 17 (* 4 version)))
         (m (make-vector size nil))
         (fn (make-vector size nil)))
    (dotimes (r size)
      (aset m r (make-vector size 0))
      (aset fn r (make-vector size nil)))
    ;; Finder patterns with their one-module separators.
    (dolist (corner (list (list 0 0) (list 0 (- size 7)) (list (- size 7) 0)))
      (pcase-let ((`(,r0 ,c0) corner))
        (dotimes (dr 9)
          (dotimes (dc 9)
            (let ((r (+ r0 dr -1)) (c (+ c0 dc -1))
                  (off-r (1- dr)) (off-c (1- dc)))
              (when (and (>= r 0) (< r size) (>= c 0) (< c size))
                (aset (aref m r) c
                      (if (and (<= 0 off-r 6) (<= 0 off-c 6)
                               (or (= off-r 0) (= off-r 6) (= off-c 0) (= off-c 6)
                                   (and (<= 2 off-r 4) (<= 2 off-c 4))))
                          1 0))
                (aset (aref fn r) c t)))))))
    ;; Alignment patterns, BEFORE timing: their centers legitimately sit
    ;; on the timing row/column (v7+), so the only pairs to skip are the
    ;; three that overlap a finder — exactly the cells already flagged.
    (dolist (r (aref croc-ui--qr-alignment version))
      (dolist (c (aref croc-ui--qr-alignment version))
        (unless (aref (aref fn r) c)
          (dotimes (dr 5)
            (dotimes (dc 5)
              (let ((dark (or (= dr 0) (= dr 4) (= dc 0) (= dc 4)
                              (and (= dr 2) (= dc 2)))))
                (aset (aref m (+ r dr -2)) (+ c dc -2) (if dark 1 0))
                (aset (aref fn (+ r dr -2)) (+ c dc -2) t)))))))
    ;; Timing patterns (filling only what finders/alignment left open).
    (dotimes (i size)
      (unless (aref (aref fn 6) i)
        (aset (aref m 6) i (if (zerop (% i 2)) 1 0))
        (aset (aref fn 6) i t))
      (unless (aref (aref fn i) 6)
        (aset (aref m i) 6 (if (zerop (% i 2)) 1 0))
        (aset (aref fn i) 6 t)))
    ;; Version information (v7+ only).
    (when (>= version 7)
      (let ((bits (croc-ui--qr-version-bits version)))
        (dotimes (i 18)
          (let ((bit (logand (ash bits (- i)) 1)))
            (aset (aref m (/ i 3)) (+ (% i 3) size -11) bit)
            (aset (aref fn (/ i 3)) (+ (% i 3) size -11) t)
            (aset (aref m (+ (% i 3) size -11)) (/ i 3) bit)
            (aset (aref fn (+ (% i 3) size -11)) (/ i 3) t)))))
    ;; Reserve format cells, then place the data in the zigzag sweep.
    (croc-ui--qr-reserve-format fn)
    (let ((col (1- size)) (row (1- size)) (inc -1)
          (idx 0) (bit 7) (total (length codewords)))
      (while (> col 0)
        (when (= col 6) (cl-decf col))
        (let ((sweep-done nil))
          (while (not sweep-done)
            (dotimes (k 2)
              (unless (aref (aref fn row) (- col k))
                (let ((dark (and (< idx total)
                                 (= 1 (logand (ash (aref codewords idx) (- bit)) 1)))))
                  (when (croc-ui--qr-mask-p mask row (- col k))
                    (setq dark (not dark)))
                  (aset (aref m row) (- col k) (if dark 1 0))
                  (if (= bit 0)
                      (setq bit 7 idx (1+ idx))
                    (cl-decf bit)))))
            (setq row (+ row inc))
            (when (or (< row 0) (>= row size))
              (setq row (- row inc) inc (- inc) sweep-done t))))
        (setq col (- col 2))))
    (croc-ui--qr-write-format m (croc-ui--qr-format-bits mask))
    m))

(defun croc-ui--qr-penalty (m)
  "Spec N1-N4 penalty for matrix M; lower picks the more scannable mask."
  (let* ((size (length m))
         (penalty 0))
    ;; N1: runs of 5+ same-color modules in rows and columns.
    (dotimes (axis 2)
      (dotimes (fixed size)
        (let ((prev -1) (run 0))
          (dotimes (i size)
            (let ((v (if (zerop axis)
                         (aref (aref m fixed) i)
                       (aref (aref m i) fixed))))
              (if (= v prev)
                  (cl-incf run)
                (when (>= run 5) (cl-incf penalty (+ 3 run -5)))
                (setq prev v run 1))))
          (when (>= run 5) (cl-incf penalty (+ 3 run -5))))))
    ;; N2: same-color 2x2 blocks.
    (dotimes (r (1- size))
      (dotimes (c (1- size))
        (let ((v (aref (aref m r) c)))
          (when (and (= v (aref (aref m r) (1+ c)))
                     (= v (aref (aref m (1+ r)) c))
                     (= v (aref (aref m (1+ r)) (1+ c))))
            (cl-incf penalty 3)))))
    ;; N3: finder-like 1011101 with a 4-module light guard on either side.
    (dotimes (axis 2)
      (dotimes (fixed size)
        (dotimes (i size)
          (cl-flet ((at (off)
                      (if (zerop axis)
                          (aref (aref m fixed) off)
                        (aref (aref m off) fixed))))
            (when (and (<= (+ i 6) (1- size))
                       (= 1 (at i)) (= 0 (at (+ i 1)))
                       (= 1 (at (+ i 2))) (= 1 (at (+ i 3))) (= 1 (at (+ i 4)))
                       (= 0 (at (+ i 5))) (= 1 (at (+ i 6)))
                       (or (and (>= i 4)
                                (= 0 (at (- i 1))) (= 0 (at (- i 2)))
                                (= 0 (at (- i 3))) (= 0 (at (- i 4))))
                           (and (<= (+ i 10) (1- size))
                                (= 0 (at (+ i 7))) (= 0 (at (+ i 8)))
                                (= 0 (at (+ i 9))) (= 0 (at (+ i 10))))))
              (cl-incf penalty 40))))))
    ;; N4: deviation from a 50% dark ratio.
    (let ((dark 0))
      (dotimes (r size)
        (dotimes (c size)
          (when (= 1 (aref (aref m r) c)) (cl-incf dark))))
      (cl-incf penalty (* 10 (floor (abs (- (/ (* 100.0 dark) (* size size)) 50)) 5))))
    penalty))

(defun croc-ui--qr-encode (text)
  "Encode TEXT as a QR matrix: a vector of row vectors, 1 = dark, 0 = light.
Byte mode, EC level L, smallest version in 1-10 that fits."
  (let* ((bytes (append (encode-coding-string text 'utf-8) nil))
         (n (length bytes))
         (version (cl-loop for v from 1 to 10
                           when (<= n (aref croc-ui--qr-capacity (1- v)))
                           return v)))
    (unless version
      (error "Payload too long for QR (%d > %d bytes)"
             n (aref croc-ui--qr-capacity 9)))
    (let ((codewords (croc-ui--qr-interleave
                      (croc-ui--qr-data-codewords bytes version) version))
          (best nil)
          (best-penalty most-positive-fixnum))
      (dotimes (mask 8)
        (let* ((m (croc-ui--qr-build version codewords mask))
               (penalty (croc-ui--qr-penalty m)))
          (when (< penalty best-penalty)
            (setq best m best-penalty penalty))))
      best)))

(defun croc-ui--qr-module (matrix size margin row col)
  "Non-nil when the module at ROW COL (with MARGIN offset) is dark."
  (let ((r (- row margin)) (c (- col margin)))
    (and (>= r 0) (< r size) (>= c 0) (< c size)
         (= 1 (aref (aref matrix r) c)))))

(defun croc-ui--qr-render (matrix &optional margin)
  "Render QR MATRIX as a list of propertized strings, one per text line.
Two module rows are combined per glyph via UPPER HALF BLOCK, so modules
stay square; MARGIN (default 4) modules of quiet zone wrap the code."
  (let* ((size (length matrix))
         (margin (or margin 4))
         (total (+ size (* 2 margin))))
    (if (char-displayable-p ?▀)
        (cl-loop for row below total by 2
                 collect
                 (concat "  "
                         (mapconcat
                          (lambda (col)
                            (propertize "▀" 'face
                                        (list :foreground
                                              (if (croc-ui--qr-module matrix size margin row col)
                                                  "black" "white")
                                              :background
                                              (if (croc-ui--qr-module matrix size margin (1+ row) col)
                                                  "black" "white"))))
                          (number-sequence 0 (1- total)))))
      ;; No UPPER HALF BLOCK (non-UTF-8 terminal): two spaces per module.
      (cl-loop for row below total
               collect
               (concat "  "
                       (mapconcat
                        (lambda (col)
                          (propertize "  " 'face
                                      (list :background
                                            (if (croc-ui--qr-module matrix size margin row col)
                                                "black" "white"))))
                        (number-sequence 0 (1- total))))))))

(defvar-local croc-ui--qr-hidden nil
  "Non-nil hides the QR card in this dashboard buffer.")

(defvar croc-ui--qr-cache nil
  "Alist of (CODE . rendered-lines), capped at 8 entries.")

(defun croc-ui--qr-render-code (code)
  "Cached QR lines for CODE, or nil when CODE cannot be encoded."
  (or (cdr (assoc code croc-ui--qr-cache))
      (let ((lines (condition-case nil
                       (croc-ui--qr-render (croc-ui--qr-encode code))
                     (error nil))))
        (push (cons code lines) croc-ui--qr-cache)
        (when (> (length croc-ui--qr-cache) 8)
          (setq croc-ui--qr-cache (cl-subseq croc-ui--qr-cache 0 8)))
        lines)))

(defun croc-ui--insert-qr ()
  "QR card for the hero code, so the croc app can scan to receive."
  (when (and croc-ui-show-qr (not croc-ui--qr-hidden))
    (when-let* ((hero (croc-ui--hero-transfer))
                (code (croc-ui--transfer-code hero))
                (lines (croc-ui--qr-render-code code)))
      (dolist (line lines)
        (insert line "\n"))
      (insert (propertize "  scan with the croc app — Q hides" 'face 'croc-ui-faded)
              "\n\n"))))

(defun croc-ui-toggle-qr ()
  "Toggle the QR card in the dashboard."
  (interactive)
  (setq croc-ui--qr-hidden (not croc-ui--qr-hidden))
  (croc-ui-refresh)
  (message "QR card %s" (if croc-ui--qr-hidden "hidden" "shown")))

;;; § 7 Dashboard rendering

(defun croc-ui--insert-hero ()
  "Title line plus, when a send is waiting, the share code hero."
  (insert (propertize " croc" 'face 'croc-ui-strong)
          (propertize "  peer-to-peer transfer" 'face 'croc-ui-faded)
          "\n\n")
  (when-let* ((hero (croc-ui--hero-transfer)))
    (let ((code (croc-ui--transfer-code hero)))
      (insert (propertize "  share this code" 'face 'croc-ui-faded) "\n")
      (insert "  "
              (croc-ui--button
               (propertize code 'face
                           (if (display-graphic-p)
                               '(:inherit (croc-ui-strong croc-ui-salient)
                                          :height 1.25)
                             '(:inherit (croc-ui-strong croc-ui-salient))))
               (lambda (&rest _) (interactive)
                 (kill-new code)
                 (message "copied: %s" code))
               "mouse-2 / RET: copy code")
              "\n"
              (propertize "  waiting for the other side — w copies, x cancels"
                          'face 'croc-ui-faded)
              "\n\n"))))

(defun croc-ui--hint (key label)
  "One link-farm hint: bracketed KEY in faded, LABEL in default."
  (concat (propertize "[" 'face 'croc-ui-faded)
          (propertize key 'face 'croc-ui-strong)
          (propertize "]" 'face 'croc-ui-faded)
          " " label))

(defun croc-ui--insert-hints ()
  "The link farm: literal key hints, maintained with the keymap."
  (insert "  "
          (mapconcat #'identity
                     (list (croc-ui--hint "s" "send file")
                           (croc-ui--hint "d" "send folder")
                           (croc-ui--hint "t" "send text")
                           (croc-ui--hint "r" "receive"))
                     "    ")
          "\n  "
          (mapconcat #'identity
                     (list (croc-ui--hint "RET" "log")
                           (croc-ui--hint "w" "copy code")
                           (croc-ui--hint "Q" "qr")
                           (croc-ui--hint "x" "kill")
                           (croc-ui--hint "X" "clear done")
                           (croc-ui--hint "g" "refresh")
                           (croc-ui--hint "q" "quit"))
                     "    ")
          "\n"))

(defun croc-ui--insert-transfer (tr)
  "One feed row for TR: glyph + label left, code + chip + time right."
  (let* ((id (croc-ui--transfer-id tr))
         (done-p (memq (croc-ui--transfer-state tr) '(done failed cancelled)))
         (glyph (propertize (croc-ui--symbol (croc-ui--transfer-direction tr))
                            'face (if done-p 'croc-ui-faded 'croc-ui-salient)))
         (label (propertize (croc-ui--transfer-label tr)
                            'face (if done-p 'default 'croc-ui-strong)))
         (code-text (or (croc-ui--transfer-code tr) "…"))
         (code (croc-ui--button
                (propertize (format "%-28s" (truncate-string-to-width code-text 28))
                            'face (if done-p 'croc-ui-faded 'croc-ui-salient))
                (lambda (&rest _) (interactive)
                  (when-let* ((c (croc-ui--transfer-code tr)))
                    (kill-new c)
                    (message "copied: %s" c)))
                "mouse-2 / RET: copy code"))
         (chip (propertize (croc-ui--chip tr) 'croc-ui-chip id))
         (time (propertize (format-time-string "%H:%M" (croc-ui--transfer-started tr))
                           'face 'croc-ui-faded))
         (row (croc-ui--justify (concat glyph " " label)
                                (concat code " " chip " " time))))
    (insert (propertize (concat "  " row) 'croc-ui-id id) "\n")))

(defun croc-ui--insert-transfers ()
  "The transfer feed, separated by hairlines."
  (insert (croc-ui--hairline))
  (if (null croc-ui--transfers)
      (insert (propertize "  no transfers yet — s sends something" 'face 'croc-ui-faded)
              "\n")
    (dolist (tr croc-ui--transfers)
      (croc-ui--insert-transfer tr))))

(defun croc-ui--header-line ()
  "Four-slot status bar: [ STATUS | name (primary) ... right ]."
  (let* ((active (cl-count-if #'croc-ui--live-p croc-ui--transfers))
         (status (if (> active 0)
                     (propertize (format " %d " active) 'face 'croc-ui-chip)
                   (propertize " 0 " 'face 'croc-ui-chip-i)))
         (name (propertize " croc " 'face 'croc-ui-strong))
         (prim (propertize (format "(%d transfer%s active)"
                                   active (if (= active 1) "" "s"))
                           'face 'croc-ui-faded))
         (right (propertize (format "%s total " (length croc-ui--transfers))
                            'face 'croc-ui-faded)))
    (concat (propertize " " 'display '(raise 0.15))
            status name
            (propertize " " 'display '(raise -0.20))
            prim
            (propertize " " 'display `(space :align-to (- right ,(length right))))
            right)))

(defun croc-ui-refresh ()
  "Re-render the dashboard, restoring point by transfer id."
  (interactive)
  (when-let* ((buf (get-buffer croc-ui--buffer-name)))
    (with-current-buffer buf
      (when (eq major-mode 'croc-ui-mode)
        (let ((id (get-text-property (point) 'croc-ui-id))
              (inhibit-read-only t))
          (erase-buffer)
          (croc-ui--insert-hero)
          (croc-ui--insert-qr)
          (croc-ui--insert-hints)
          (croc-ui--insert-transfers)
          (if-let* ((match (and id
                                (progn (goto-char (point-min))
                                       (text-property-search-forward
                                        'croc-ui-id id #'eq)))))
              (goto-char (prop-match-beginning match))
            (goto-char (point-min))
            (croc-ui-next)))))))

(defun croc-ui--update-chip (tr)
  "In-place rewrite of TR's progress chip; the row never reflows."
  (when-let* ((buf (get-buffer croc-ui--buffer-name)))
    (when (get-buffer-window buf)
      (with-current-buffer buf
        (when (eq major-mode 'croc-ui-mode)
          (save-excursion
            (goto-char (point-min))
            (when-let* ((match (text-property-search-forward
                                'croc-ui-chip (croc-ui--transfer-id tr) #'eq)))
              (let ((inhibit-read-only t)
                    (chip (propertize
                           (format " %3d%% " (croc-ui--transfer-progress tr))
                           'face 'croc-ui-chip-active
                           'croc-ui-chip (croc-ui--transfer-id tr))))
                (delete-region (prop-match-beginning match) (prop-match-end match))
                (goto-char (prop-match-beginning match))
                (insert chip)))))))))

;;; § 8 Mode and navigation

(defun croc-ui--transfer-at-point ()
  "Transfer struct for the row at point."
  (when-let* ((id (get-text-property (point) 'croc-ui-id)))
    (croc-ui--find id)))

(defun croc-ui-next ()
  "Move to the next transfer row."
  (interactive)
  (let ((match (text-property-search-forward 'croc-ui-id nil nil t)))
    (if match
        (goto-char (prop-match-beginning match))
      (goto-char (point-min))
      (when-let* ((first (text-property-search-forward 'croc-ui-id nil nil)))
        (goto-char (prop-match-beginning first))))))

(defun croc-ui-previous ()
  "Move to the previous transfer row."
  (interactive)
  (let* ((here (point))
         (starts (save-excursion
                   (goto-char (point-min))
                   (cl-loop for m = (text-property-search-forward 'croc-ui-id nil nil)
                            while m
                            collect (prop-match-beginning m)
                            do (goto-char (prop-match-end m))))))
    (goto-char (or (car (last (cl-remove-if-not (lambda (p) (< p here)) starts)))
                   (car (last starts))
                   here))))

(defun croc-ui-open-log ()
  "Pop the raw croc log for the transfer at point."
  (interactive)
  (if-let* ((tr (croc-ui--transfer-at-point)))
      (pop-to-buffer (croc-ui--transfer-buffer tr))
    (user-error "No transfer on this row")))

(defun croc-ui-copy-code ()
  "Copy the code of the transfer at point (or in this log, or the hero)."
  (interactive)
  (when-let* ((tr (or (croc-ui--transfer-at-point)
                      croc-ui--log-transfer
                      (croc-ui--hero-transfer)
                      (car croc-ui--transfers)))
              (code (croc-ui--transfer-code tr)))
    (kill-new code)
    (message "copied: %s" code)))

(defun croc-ui-kill ()
  "Cancel the transfer at point (or this log's transfer)."
  (interactive)
  (if-let* ((tr (or (croc-ui--transfer-at-point) croc-ui--log-transfer)))
      (if (croc-ui--live-p tr)
          (progn
            (setf (croc-ui--transfer-state tr) 'cancelled)
            (delete-process (croc-ui--transfer-process tr))
            (croc-ui-refresh))
        (user-error "Transfer already finished"))
    (user-error "No transfer here")))

(defun croc-ui-clear-done ()
  "Drop every finished transfer from the feed (logs are kept)."
  (interactive)
  (setq croc-ui--transfers
        (cl-remove-if-not #'croc-ui--live-p croc-ui--transfers))
  (croc-ui-refresh))

(defvar croc-ui-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "s") #'croc-ui-send-files)
    (define-key map (kbd "d") #'croc-ui-send-directory)
    (define-key map (kbd "t") #'croc-ui-send-text)
    (define-key map (kbd "r") #'croc-ui-receive)
    (define-key map (kbd "RET") #'croc-ui-open-log)
    (define-key map (kbd "w") #'croc-ui-copy-code)
    (define-key map (kbd "Q") #'croc-ui-toggle-qr)
    (define-key map (kbd "x") #'croc-ui-kill)
    (define-key map (kbd "X") #'croc-ui-clear-done)
    (define-key map (kbd "g") #'croc-ui-refresh)
    (define-key map (kbd "n") #'croc-ui-next)
    (define-key map (kbd "p") #'croc-ui-previous)
    (define-key map (kbd "q") #'quit-window)
    map)
  "Keymap for `croc-ui-mode'.")

(define-derived-mode croc-ui-mode special-mode "croc"
  "NΛNO-style dashboard for croc transfers."
  (setq-local cursor-type nil
              truncate-lines t
              left-fringe-width 8
              right-fringe-width 8
              header-line-format '(:eval (croc-ui--header-line))
              mode-line-format "")
  (face-remap-set-base 'hl-line 'croc-ui-selected)
  (hl-line-mode 1))

(declare-function evil-set-initial-state "evil")
(declare-function evil-define-key* "evil-core")

(with-eval-after-load 'evil
  (evil-set-initial-state 'croc-ui-mode 'normal)
  ;; `evil-define-key' is a macro: calling it from a file byte-compiled
  ;; without evil loaded yields (invalid-function evil-define-key).
  ;; `evil-define-key*' is the function underneath and is always safe.
  (evil-define-key* 'normal croc-ui-mode-map
    (kbd "j") #'croc-ui-next
    (kbd "k") #'croc-ui-previous
    (kbd "RET") #'croc-ui-open-log
    (kbd "s") #'croc-ui-send-files
    (kbd "d") #'croc-ui-send-directory
    (kbd "t") #'croc-ui-send-text
    (kbd "r") #'croc-ui-receive
    (kbd "w") #'croc-ui-copy-code
    (kbd "Q") #'croc-ui-toggle-qr
    (kbd "x") #'croc-ui-kill
    (kbd "X") #'croc-ui-clear-done
    (kbd "g") #'croc-ui-refresh
    (kbd "q") #'quit-window))

;;; § 9 Entry points

;;;###autoload
(defun croc-ui ()
  "Pop the croc dashboard."
  (interactive)
  (pop-to-buffer (get-buffer-create croc-ui--buffer-name))
  (unless (eq major-mode 'croc-ui-mode)
    (croc-ui-mode))
  (croc-ui-refresh)
  ;; Point sits on the first row; keep the hero in view regardless.
  (set-window-start (selected-window) (point-min)))

(declare-function dired-get-marked-files "dired")

;;;###autoload
(defun croc-ui-send-files (files)
  "Send FILES with croc.  In dired, sends the marked files."
  (interactive
   (list (if (derived-mode-p 'dired-mode)
             (or (dired-get-marked-files) (user-error "No files marked"))
           (list (read-file-name "Send file: " nil nil t)))))
  (let ((label (if (= 1 (length files))
                   (file-name-nondirectory (directory-file-name (car files)))
                 (format "%d files" (length files)))))
    (croc-ui--spawn 'send label (append '("--ignore-stdin" "send") files))
    (croc-ui)))

;;;###autoload
(defun croc-ui-send-directory (directory)
  "Send DIRECTORY with croc."
  (interactive "DSend folder: ")
    (croc-ui--spawn 'send
                  (concat (file-name-nondirectory
                           (directory-file-name directory)) "/")
                  (list "--ignore-stdin" "send" directory))
  (croc-ui))

;;;###autoload
(defun croc-ui-send-text (text)
  "Send TEXT (the region when active) as a croc text payload."
  (interactive
   (list (if (use-region-p)
             (buffer-substring-no-properties (region-beginning) (region-end))
           (read-string "Send text: "))))
  (croc-ui--spawn 'send
                  (concat "“" (truncate-string-to-width
                               (string-trim text) 24 nil nil "…") "”")
                  (list "--ignore-stdin" "send" "--text" text))
  (croc-ui))

(defun croc-ui--code-from-kill-ring ()
  "Latest kill when it smells like a croc code, else nil."
  (let ((top (ignore-errors (current-kill 0 t))))
    (when (and top (string-match-p "\\`[a-z0-9]+-[a-z0-9-]+\\'" top))
      top)))

;;;###autoload
(defun croc-ui-receive (code directory)
  "Receive whatever CODE points to into DIRECTORY."
  (interactive
   (list (read-string "Croc code: " nil nil (croc-ui--code-from-kill-ring))
         (read-directory-name "Save into: " croc-ui-receive-directory nil nil)))
  (unless (file-directory-p directory)
    (make-directory directory t))
  (let ((tr (croc-ui--spawn
             'recv (file-name-nondirectory (directory-file-name directory))
             (list "--yes" "--overwrite" "--ignore-stdin"
                   "--out" directory)
             ;; New (secure) mode: the code travels in CROC_SECRET,
             ;; never as a visible command-line argument.
             (list (format "CROC_SECRET=%s" code)))))
    ;; The receiver knows its code from the start (no "Code is:" line).
    (setf (croc-ui--transfer-code tr) code)
    (croc-ui-refresh))
  (croc-ui))

(provide 'croc-ui)
;;; croc-ui.el ends here
