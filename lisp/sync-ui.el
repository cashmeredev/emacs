;;; sync-ui.el --- Rougier-style git sync dashboard -*- lexical-binding: t -*-

;; Copyright (C) 2026 cashmere

;; Author: cashmere
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: vc, tools

;;; Commentary:

;; A keyboard-first, Rougier-style dashboard for keeping a set of git
;; repos committed, rebased and pushed to all of their (redundant)
;; remotes.  Sync is manual: `s' runs one cycle.
;;
;; AUTO repos commit everything dirty with a "host: ISO8601" message
;; and push without asking.  ASK repos prompt once per cycle; a yes
;; zaps you to magit, and `r' in the dashboard resumes (push) once a
;; new commit exists.  Pulls are `git rebase --autostash'; a conflict
;; aborts the rebase, marks the repo CONFLICTED and leaves it alone.
;;
;; Archetype: flat stream with per-item state -> state-glyph rail
;; over two-line cards (framework S3 + S5 + S10).  The rail owns the
;; left edge: filled chips carry the dirty count and the state, the
;; `┊' gutter keeps it unbroken between cards.  Faces are
;; theme-agnostic (recipe 0); the only fixed hues are the AUTO/ASK
;; category pills, which are brand colors by design.
;;
;; Keys (dashboard):
;;   s sync all     RET magit     r resume     x skip
;;   t auto/ask     a add repo    d remove     g refresh
;;   n/p next/prev  q quit
;;
;; Evil: normal state gets j/k plus the same one-key actions.

;;; Code:

(require 'cl-lib)

;;; § 1 Faces (theme-agnostic, recipe 0)

(defface sync-ui-strong '((t :inherit bold))
  "Structural text: repo names, title."
  :group 'sync-ui)

(defface sync-ui-faded '((t :inherit shadow))
  "Secondary text: paths, metadata, hints."
  :group 'sync-ui)

(defface sync-ui-salient '((t :inherit link))
  "Attention: repo names, unpushed counts."
  :group 'sync-ui)

(defface sync-ui-popout '((t :inherit (font-lock-warning-face bold)))
  "The second hue: repos that need a decision, incoming commits."
  :group 'sync-ui)

(defface sync-ui-critical '((t :inherit (error bold)))
  "Conflicts and errors.  Used scarcely."
  :group 'sync-ui)

(defface sync-ui-chip '((t :inherit bold :inverse-video t))
  "Rail chip, structural dark: dirty auto repo, freshly synced."
  :group 'sync-ui)

(defface sync-ui-chip-i '((t :inherit shadow :inverse-video t))
  "Rail chip, quiet: clean repo."
  :group 'sync-ui)

(defface sync-ui-chip-active '((t :inherit link :inverse-video t))
  "Rail chip while a sync step runs."
  :group 'sync-ui)

(defface sync-ui-chip-popout '((t :inherit (font-lock-warning-face bold) :inverse-video t))
  "Rail chip for a repo that needs a decision (dirty ask repo, waiting)."
  :group 'sync-ui)

(defface sync-ui-chip-critical '((t :inherit (error bold) :inverse-video t))
  "Rail chip for conflict/error."
  :group 'sync-ui)

(defface sync-ui-pill-auto '((t :background "#3a7d5d" :foreground "#ffffff"))
  "Category pill for AUTO mode.  Brand hue, white text, theme-stable."
  :group 'sync-ui)

(defface sync-ui-pill-ask '((t :background "#7451a6" :foreground "#ffffff"))
  "Category pill for ASK mode.  Brand hue, white text, theme-stable."
  :group 'sync-ui)

(defface sync-ui-selected '((t :inherit bold :inverse-video t))
  "Selected card (hl-line remap target).  Pure inverse: always theme-fresh."
  :group 'sync-ui)

(defface sync-ui-hairline
  '((t :inherit default :strike-through t :overline nil :underline nil
       :height 1.0 :extend t))
  "Full-width rule drawn by a strike-through newline."
  :group 'sync-ui)

;;; § 2 Customs

(defgroup sync-ui nil
  "Dashboard for manual autosync/autopush of git repos."
  :group 'applications
  :prefix "sync-ui-")

(defcustom sync-ui-repos
  '(("~/org" . auto)
    ("~/.claude/skills" . auto)
    ("~/pass" . auto)
    ("~/nix" . ask)
    ("~/.emacs.d" . ask))
  "Alist of (PATH . MODE) for managed repos.
MODE `auto' commits and pushes without prompting; MODE `ask' offers a
magit detour first.  Edit from the dashboard with `a', `d' and `t'."
  :type '(alist :key-type directory
                :value-type (choice (const auto) (const ask)))
  :group 'sync-ui)

(defcustom sync-ui-hostname
  (car (split-string (system-name) "\\."))
  "Host label used in auto-commit messages."
  :type 'string
  :group 'sync-ui)

;;; § 3 Data layer

(cl-defstruct (sync-ui--repo (:constructor sync-ui--repo-create))
  id path mode (state 'clean) (dirty 0) branch head head-at-wait upstream
  remotes last-sync message process)

(defvar sync-ui--repos nil
  "Live list of `sync-ui--repo' structs, in display order.")

(defconst sync-ui--buffer-name "*sync*")

(defun sync-ui--load-registry ()
  "Build `sync-ui--repos' from `sync-ui-repos'."
  (setq sync-ui--repos
        (mapcar (lambda (entry)
                  (sync-ui--repo-create
                   :id (expand-file-name (car entry))
                   :path (abbreviate-file-name (expand-file-name (car entry)))
                   :mode (cdr entry)))
                sync-ui-repos)))

(defun sync-ui--find (id)
  "Repo struct with ID, or nil."
  (cl-find id sync-ui--repos :key #'sync-ui--repo-id :test #'equal))

(defun sync-ui--save-repos ()
  "Persist the live registry back to `sync-ui-repos' via customize."
  (customize-save-variable
   'sync-ui-repos
   (mapcar (lambda (repo)
             (cons (sync-ui--repo-path repo) (sync-ui--repo-mode repo)))
           sync-ui--repos)))

;;; § 4 Git engine

;; Local operations (status, rev-parse, commit) run synchronously —
;; they are sub-second.  Network operations (fetch, rebase onto a
;; fetched ref, push) run as async process chains so the dashboard
;; stays live and shows per-step states.

(defun sync-ui--git (repo args)
  "Run git ARGS synchronously in REPO's directory.
Return (EXIT-CODE OUTPUT).  Never signals: a missing directory or a
missing git binary becomes a non-zero exit code."
  (with-temp-buffer
    (list (condition-case nil
              (apply #'call-process "git" nil t nil
                     "-C" (sync-ui--repo-id repo) args)
            (error 127))
          (buffer-string))))

(defun sync-ui--git-async (repo args on-done)
  "Run git ARGS asynchronously in REPO's directory.
ON-DONE is called with (EXIT-CODE OUTPUT).  One process per repo at a
time; the caller's state machine guarantees that."
  (let ((buf (generate-new-buffer
              (format " *sync-ui:%s*" (sync-ui--repo-path repo)))))
    (setf (sync-ui--repo-process repo)
          (make-process
           :name (format "sync-ui:%s" (sync-ui--repo-path repo))
           :buffer buf
           :command (append (list "git" "-C" (sync-ui--repo-id repo)) args)
           :noquery t
           :sentinel
           (lambda (proc _event)
             (when (memq (process-status proc) '(exit signal))
               (let ((code (process-exit-status proc))
                     (out (with-current-buffer (process-buffer proc)
                            (buffer-string))))
                 (kill-buffer (process-buffer proc))
                 (setf (sync-ui--repo-process repo) nil)
                 (funcall on-done code out))))))))

(defun sync-ui--trim (string)
  (if (stringp string) (string-trim string) ""))

(defun sync-ui--remote-names (repo)
  "Names of REPO's configured remotes that actually have a URL.
A bare [remote \"x\"] section in any config file (e.g. global gcrypt
keys) makes `git remote' list x in every repository; get-url filters
those phantoms out."
  (pcase-let ((`(,code ,out) (sync-ui--git repo '("remote"))))
    (if (zerop code)
        (cl-remove-if-not
         (lambda (name)
           (zerop (car (sync-ui--git repo (list "remote" "get-url" name)))))
         (cl-remove-if #'string-empty-p (split-string out "\n")))
      nil)))

(defun sync-ui--primary-remote (repo)
  "\"origin\" when present, else the first remote."
  (let ((names (mapcar #'car (sync-ui--repo-remotes repo))))
    (if (member "origin" names) "origin" (car names))))

(defun sync-ui--ref-exists-p (repo ref)
  "Non-nil when REF resolves in REPO."
  (zerop (car (sync-ui--git repo (list "rev-parse" "--verify" "--quiet" ref)))))

(defun sync-ui--probe-remotes (repo names)
  "Per-remote (NAME AHEAD BEHIND) triples against the current branch.
AHEAD/BEHIND are nil when the remote has no branch to compare with."
  (let ((branch (sync-ui--repo-branch repo)))
    (mapcar
     (lambda (name)
       (if (and branch
                (not (string= branch "HEAD"))
                (sync-ui--ref-exists-p repo (concat name "/" branch)))
           (pcase-let ((`(,code ,out)
                        (sync-ui--git repo
                                      (list "rev-list" "--left-right" "--count"
                                            (format "%s/%s...HEAD" name branch)))))
             (if (zerop code)
                 (pcase-let ((`(,left ,right) (split-string out)))
                   (list name (string-to-number right) (string-to-number left)))
               (list name nil nil)))
         (list name nil nil)))
     names)))

(defun sync-ui--probe (repo &optional force)
  "Local-only refresh of REPO: dirty count, branch, head, upstream, remotes.
State is recomputed only when FORCE, or when the repo is not waiting
and no sync step is running."
  (cond
   ((not (file-directory-p (sync-ui--repo-id repo)))
    (setf (sync-ui--repo-state repo) 'missing
          (sync-ui--repo-message repo) "directory gone"))
   ((not (sync-ui--ref-exists-p repo "HEAD"))
    (pcase-let ((`(,code ,_out) (sync-ui--git repo '("rev-parse" "--git-dir"))))
      (if (not (zerop code))
          (setf (sync-ui--repo-state repo) 'missing
                (sync-ui--repo-message repo) "not a git repository")
        (setf (sync-ui--repo-state repo) 'missing
              (sync-ui--repo-message repo) "no commits yet"))))
   (t
    (setf (sync-ui--repo-branch repo)
          (sync-ui--trim (cadr (sync-ui--git repo '("rev-parse" "--abbrev-ref" "HEAD"))))
          (sync-ui--repo-head repo)
          (sync-ui--trim (cadr (sync-ui--git repo '("rev-parse" "HEAD"))))
          (sync-ui--repo-dirty repo)
          (length (cl-remove-if #'string-empty-p
                                (split-string
                                 (cadr (sync-ui--git repo '("status" "--porcelain")))
                                 "\n")))
          (sync-ui--repo-upstream repo)
          (pcase-let ((`(,code ,out)
                       (sync-ui--git repo '("rev-parse" "--abbrev-ref"
                                            "--symbolic-full-name" "@{u}"))))
            (and (zerop code) (sync-ui--trim out)))
          (sync-ui--repo-remotes repo)
          (sync-ui--probe-remotes repo (sync-ui--remote-names repo)))
    (when (or force
              (not (memq (sync-ui--repo-state repo)
                         '(waiting committing fetching rebasing pushing))))
      (setf (sync-ui--repo-state repo)
            (if (> (sync-ui--repo-dirty repo) 0) 'dirty 'clean)
            (sync-ui--repo-message repo) nil)))))

(defun sync-ui--set-state (repo state &optional message)
  "Move REPO to STATE with MESSAGE and repaint its card."
  (setf (sync-ui--repo-state repo) state
        (sync-ui--repo-message repo) message)
  (sync-ui--update-card repo))

(defun sync-ui--fail (repo step out)
  "Mark REPO as failed during STEP; OUT is git's output."
  (let* ((lines (cl-remove-if #'string-empty-p (split-string out "\n")))
         (line (or (cl-find-if (lambda (l) (string-match-p "error:\|fatal:\|! \\[" l))
                               lines)
                   (car lines))))
    (sync-ui--set-state
     repo 'error
     (truncate-string-to-width
      (format "%s: %s" step
              (replace-regexp-in-string
               "\\`\\(fatal\\|error\\): *" "" (or line "failed")))
      60 nil nil "…"))))

(defun sync-ui--commit-message ()
  "Auto-commit message: \"host: ISO8601 with colon zone\"."
  (format "%s: %s" sync-ui-hostname
          (format-time-string "%Y-%m-%dT%H:%M:%S%:z")))

(defun sync-ui--commit-all (repo)
  "Stage everything in REPO and commit.  Return non-nil on success."
  (sync-ui--set-state repo 'committing)
  (sync-ui--git repo '("add" "-A"))
  (pcase-let ((`(,code ,out)
               (sync-ui--git repo (list "commit" "-m" (sync-ui--commit-message)))))
    (if (or (zerop code) (string-match-p "nothing to commit" out))
        (progn
          (setf (sync-ui--repo-head repo)
                (sync-ui--trim (cadr (sync-ui--git repo '("rev-parse" "HEAD")))))
          t)
      (sync-ui--fail repo "commit" out)
      nil)))

(defun sync-ui--behind-count (repo onto)
  "Commits in ONTO that are not in HEAD."
  (pcase-let ((`(,code ,out)
               (sync-ui--git repo (list "rev-list" "--count"
                                        (format "HEAD..%s" onto)))))
    (if (zerop code) (string-to-number (sync-ui--trim out)) 0)))

(defun sync-ui--fetch-step (repo remotes on-done &optional quiet)
  "Fetch each of REMOTES in turn, then call ON-DONE.
Fetching explicitly by name (never `fetch --all') keeps phantom
remotes from global config out of the cycle.  In QUIET mode a failed
fetch is skipped instead of failing the repo."
  (if (null remotes)
      (funcall on-done)
    (unless quiet
      (sync-ui--set-state repo 'fetching (format "fetching %s…" (car remotes))))
    (sync-ui--git-async
     repo (list "fetch" "--quiet" (car remotes))
     (lambda (code out)
       (if (and (not quiet) (not (zerop code)))
           (sync-ui--fail repo "fetch" out)
         (sync-ui--fetch-step repo (cdr remotes) on-done quiet))))))

(defun sync-ui--network-sync (repo)
  "Fetch, rebase if behind, then push every remote of REPO."
  (cond
   ((or (null (sync-ui--repo-branch repo))
        (string= (sync-ui--repo-branch repo) "HEAD"))
    (sync-ui--set-state repo 'error "detached HEAD — push skipped"))
   ((null (sync-ui--repo-remotes repo))
    (sync-ui--set-state repo 'clean "no remotes — nothing to push"))
   (t
    (sync-ui--fetch-step repo (mapcar #'car (sync-ui--repo-remotes repo))
                         (lambda ()
                           (sync-ui--probe repo)
                           (sync-ui--update-card repo)
                           (sync-ui--rebase-step repo))))))

(defun sync-ui--rebase-step (repo)
  "Rebase REPO onto its upstream (or primary remote branch) when behind.
A conflict aborts the rebase and marks the repo conflicted; the
working tree is left exactly as the fetch found it."
  (let* ((branch (sync-ui--repo-branch repo))
         (primary (sync-ui--primary-remote repo))
         (onto (or (sync-ui--repo-upstream repo)
                   (and primary
                        (sync-ui--ref-exists-p repo (concat primary "/" branch))
                        (concat primary "/" branch))))
         (behind (and onto (sync-ui--behind-count repo onto))))
    (if (and onto (> behind 0))
        (progn
          (sync-ui--set-state repo 'rebasing (format "rebasing onto %s…" onto))
          (sync-ui--git-async
           repo (list "rebase" "--autostash" onto)
           (lambda (code out)
             (if (not (zerop code))
                 (progn
                   (sync-ui--git repo '("rebase" "--abort"))
                   (if (string-match-p "[Cc]onflict" out)
                       (sync-ui--set-state
                        repo 'conflicted
                        (format "conflict onto %s — resolve in magit, then s" onto))
                     (sync-ui--fail repo "rebase" out)))
               (sync-ui--probe repo)
               (sync-ui--push-step repo (mapcar #'car (sync-ui--repo-remotes repo)))))))
      (sync-ui--push-step repo (mapcar #'car (sync-ui--repo-remotes repo))))))

(defun sync-ui--push-step (repo remotes)
  "Push the current branch to each of REMOTES, in order.
A repo without upstream gets `push --set-upstream' on the primary
remote first.  A rejection stops the chain; nothing is forced."
  (if (null remotes)
      (sync-ui--finish repo)
    (let* ((remote (car remotes))
           (branch (sync-ui--repo-branch repo))
           (args (if (and (null (sync-ui--repo-upstream repo))
                          (string= remote (sync-ui--primary-remote repo)))
                     (list "push" "--set-upstream" remote (format "HEAD:%s" branch))
                   (list "push" remote (format "HEAD:%s" branch)))))
      (sync-ui--set-state repo 'pushing (format "pushing %s…" remote))
      (sync-ui--git-async
       repo args
       (lambda (code out)
         (if (not (zerop code))
             (sync-ui--fail repo (format "push %s" remote) out)
           (sync-ui--probe repo)
           (sync-ui--push-step repo (cdr remotes))))))))

(defun sync-ui--finish (repo)
  "End of a sync cycle for REPO: re-probe and mark the outcome."
  (sync-ui--probe repo t)
  (when (eq (sync-ui--repo-state repo) 'clean)
    (setf (sync-ui--repo-state repo) 'synced
          (sync-ui--repo-last-sync repo) (current-time)))
  (sync-ui--update-card repo))

(defun sync-ui--sync-one (repo)
  "One sync cycle for REPO, honouring its mode."
  (cond
   ((or (sync-ui--repo-process repo)
        (memq (sync-ui--repo-state repo) '(waiting missing)))
    nil)
   ((and (eq (sync-ui--repo-mode repo) 'ask)
         (> (sync-ui--repo-dirty repo) 0))
    (if (y-or-n-p (format "%s: %d unstaged — commit something in magit? "
                          (sync-ui--repo-path repo)
                          (sync-ui--repo-dirty repo)))
        (progn
          (setf (sync-ui--repo-head-at-wait repo) (sync-ui--repo-head repo))
          (sync-ui--set-state repo 'waiting "commit in magit — r resumes · x skips")
          (sync-ui--open-magit repo))
      (sync-ui--set-state repo 'dirty "skipped this cycle")))
   ((and (> (sync-ui--repo-dirty repo) 0)
         (not (sync-ui--commit-all repo)))
    nil)
   (t
    (sync-ui--network-sync repo))))

(defun sync-ui-sync-all ()
  "Run one sync cycle over every repo."
  (interactive)
  (unless sync-ui--repos (sync-ui--load-registry))
  (mapc #'sync-ui--probe sync-ui--repos)
  (mapc #'sync-ui--update-card sync-ui--repos)
  (mapc #'sync-ui--sync-one sync-ui--repos))

(defun sync-ui-resume ()
  "Resume the waiting repo at point: push once a new commit exists."
  (interactive)
  (let ((repo (sync-ui--repo-at-point)))
    (cond
     ((null repo)
      (user-error "No repo at point"))
     ((not (eq (sync-ui--repo-state repo) 'waiting))
      (user-error "%s is not waiting" (sync-ui--repo-path repo)))
     (t
      (sync-ui--probe repo)
      (sync-ui--update-card repo)
      (if (equal (sync-ui--repo-head repo) (sync-ui--repo-head-at-wait repo))
          (message "%s: no new commit yet — commit in magit, then r"
                   (sync-ui--repo-path repo))
        (sync-ui--network-sync repo))))))

(defun sync-ui-skip ()
  "Take the waiting repo at point out of the cycle; it will ask again."
  (interactive)
  (let ((repo (sync-ui--repo-at-point)))
    (cond
     ((null repo)
      (user-error "No repo at point"))
     ((not (eq (sync-ui--repo-state repo) 'waiting))
      (user-error "%s is not waiting" (sync-ui--repo-path repo)))
     (t
      (sync-ui--set-state
       repo (if (> (sync-ui--repo-dirty repo) 0) 'dirty 'clean)
       "skipped — asks again next sync")))))

(defun sync-ui-refresh ()
  "Re-probe every repo and fetch in the background to update ↑/↓ counts."
  (interactive)
  (unless sync-ui--repos (sync-ui--load-registry))
  (mapc #'sync-ui--probe sync-ui--repos)
  (sync-ui--render)
  (dolist (repo sync-ui--repos)
    (when (and (not (sync-ui--repo-process repo))
               (not (eq (sync-ui--repo-state repo) 'missing)))
      (sync-ui--fetch-step repo (mapcar #'car (sync-ui--repo-remotes repo))
                           (lambda ()
                             (sync-ui--probe repo)
                             (sync-ui--update-card repo))
                           t))))

;;; § 5 Layout primitives

(defconst sync-ui--symbols
  '((ok . ("ok" . "✓"))
    (bad . ("XX" . "✗"))
    (void . ("--" . "∅"))
    (gutter . ("|" . "┊"))
    (up . ("^" . "↑"))
    (down . ("v" . "↓"))
    (new . ("+" . "⁺"))
    (busy . ("~" . "…")))
  "State glyphs: (ASCII-fallback . preferred).")

(defun sync-ui--symbol (name)
  "Glyph for NAME, degrading to ASCII when undisplayable."
  (let ((pair (alist-get name sync-ui--symbols)))
    (if (and (cdr pair) (char-displayable-p (aref (cdr pair) 0)))
        (cdr pair)
      (car pair))))

(defun sync-ui--width ()
  "Render width: the dashboard window when visible, else 80."
  (if-let* ((win (get-buffer-window sync-ui--buffer-name)))
      (window-width win)
    80))

(defun sync-ui--justify-space (right-width &optional face)
  "Elastic space aligning the next RIGHT-WIDTH columns to the right edge."
  (propertize " " 'display `(space :align-to (- right ,(+ right-width 1)))
              'face (or face 'default)))

(defun sync-ui--hairline ()
  "A full-width rule."
  (propertize "\n" 'face 'sync-ui-hairline))

(defun sync-ui--button (text action help)
  "Clickable TEXT running ACTION, with HELP echo."
  (propertize text 'pointer 'hand 'mouse-face 'highlight 'follow-link t
              'help-echo help
              'keymap (let ((map (make-sparse-keymap)))
                        (define-key map [mouse-2] action)
                        (define-key map (kbd "RET") action)
                        map)))

(defun sync-ui--chip (repo)
  "The rail chip for REPO: fixed width 6, face computed from state."
  (pcase (sync-ui--repo-state repo)
    ('clean
     (propertize (format " %-4s " (sync-ui--symbol 'ok)) 'face 'sync-ui-chip-i))
    ('synced
     (propertize (format " %-4s " (sync-ui--symbol 'ok)) 'face 'sync-ui-chip))
    ('dirty
     (propertize (format " %-4s " (format "%02d" (sync-ui--repo-dirty repo)))
                 'face (if (eq (sync-ui--repo-mode repo) 'ask)
                           'sync-ui-chip-popout
                         'sync-ui-chip)))
    ('waiting
     (propertize (format " %-4s " "??") 'face 'sync-ui-chip-popout))
    ((or 'committing 'fetching 'rebasing 'pushing)
     (propertize (format " %-4s " (sync-ui--symbol 'busy)) 'face 'sync-ui-chip-active))
    ('conflicted
     (propertize (format " %-4s " (sync-ui--symbol 'bad)) 'face 'sync-ui-chip-critical))
    ('error
     (propertize (format " %-4s " "!!") 'face 'sync-ui-chip-critical))
    ('missing
     (propertize (format " %-4s " (sync-ui--symbol 'void)) 'face 'sync-ui-chip-i))
    (_
     (propertize (format " %-4s " "?") 'face 'sync-ui-chip-i))))

(defun sync-ui--state-word (repo)
  "The faded status text beside REPO's name."
  (pcase (sync-ui--repo-state repo)
    ('clean "clean")
    ('synced (format "synced · %s"
                     (format-time-string "%H:%M" (sync-ui--repo-last-sync repo))))
    ('dirty (if (eq (sync-ui--repo-mode repo) 'ask)
                "unstaged — s asks"
              "unstaged"))
    ('waiting (or (sync-ui--repo-message repo) "waiting"))
    ('committing "committing…")
    ('fetching "fetching…")
    ('rebasing (or (sync-ui--repo-message repo) "rebasing…"))
    ('pushing (or (sync-ui--repo-message repo) "pushing…"))
    ('conflicted (or (sync-ui--repo-message repo) "conflicted"))
    ('error (or (sync-ui--repo-message repo) "error"))
    ('missing (or (sync-ui--repo-message repo) "missing"))
    (_ "?")))

(defun sync-ui--pill (repo)
  "The AUTO/ASK category pill for REPO (click toggles the mode).
On rows where the rail chip is already loud (dirty ask, waiting,
conflict, error) the pill drops to the inactive chip face: one
saturated fill per row."
  (let* ((auto-p (eq (sync-ui--repo-mode repo) 'auto))
         (loud-p (or (memq (sync-ui--repo-state repo) '(waiting conflicted error))
                     (and (eq (sync-ui--repo-state repo) 'dirty) (not auto-p))))
         (face (cond (loud-p 'sync-ui-chip-i)
                     (auto-p 'sync-ui-pill-auto)
                     (t 'sync-ui-pill-ask))))
    (sync-ui--button
     (propertize (if auto-p " AUTO " " ASK  ") 'face face)
     (lambda (&rest _)
       (interactive)
       (sync-ui--toggle repo))
     "mouse-2 / RET: toggle auto/ask")))

;;; § 6 Dashboard rendering

(defun sync-ui--insert-title ()
  "Title line."
  (insert (propertize " sync"
                      'face (if (display-graphic-p)
                                '(:inherit sync-ui-strong :height 1.25)
                              'sync-ui-strong))
          (propertize "  local & redundant repos" 'face 'sync-ui-faded)
          "\n"))

(defun sync-ui--hint (key label)
  "One hint: bracketed KEY in faded, LABEL in default."
  (concat (propertize "[" 'face 'sync-ui-faded)
          (propertize key 'face 'sync-ui-strong)
          (propertize "]" 'face 'sync-ui-faded)
          " " label))

(defun sync-ui--insert-hints ()
  "Literal key hints, maintained with the keymap."
  (insert "\n  "
          (mapconcat #'identity
                     (list (sync-ui--hint "s" "sync")
                           (sync-ui--hint "RET" "magit")
                           (sync-ui--hint "r" "resume")
                           (sync-ui--hint "x" "skip")
                           (sync-ui--hint "t" "auto/ask"))
                     "    ")
          "\n  "
          (mapconcat #'identity
                     (list (sync-ui--hint "a" "add")
                           (sync-ui--hint "d" "remove")
                           (sync-ui--hint "g" "fetch")
                           (sync-ui--hint "n/p" "move")
                           (sync-ui--hint "q" "quit"))
                     "    ")
          "\n"))

(defun sync-ui--insert-card (repo)
  "One two-line card for REPO: rail chip + name + pill on top,
gutter + path + per-remote ↑/↓ counts below.  One logical line, so
navigation and hl-line treat the card as a unit."
  (let* ((id (sync-ui--repo-id repo))
         (band (face-background 'highlight nil t))
         (top `(:background ,band))
         (name-face `(:inherit (sync-ui-strong sync-ui-salient) :background ,band))
         (faded-band `(:inherit sync-ui-faded :background ,band))
         (pill (sync-ui--pill repo))
         (left (concat (propertize "  " 'face top)
                       (sync-ui--chip repo)
                       (propertize " " 'face top)
                       (sync-ui--button
                        (propertize (sync-ui--repo-path repo) 'face name-face)
                        (lambda (&rest _)
                          (interactive)
                          (sync-ui--open-magit repo))
                        "mouse-2 / RET: magit")
                       (propertize (concat "  " (sync-ui--state-word repo))
                                   'face faded-band)))
         (remotes (sync-ui--remotes-summary repo band))
         (bottom (concat (propertize "   " 'face top)
                         (propertize (sync-ui--symbol 'gutter) 'face faded-band)
                         (propertize "     " 'face top)
                         (propertize (format "%s · %s"
                                             (sync-ui--repo-path repo)
                                             (or (sync-ui--repo-branch repo) "?"))
                                     'face faded-band)))
         (left-width (string-width left))
         (budget (- (sync-ui--width) (string-width pill) 3))
         (left (if (> left-width budget)
                   (concat (truncate-string-to-width left (max 8 budget) nil nil "…"))
                 left)))
    (insert
     (propertize
      (concat left
              (sync-ui--justify-space (string-width pill) top)
              pill
              (propertize " " 'face top)
              (propertize " " 'face top 'display "\n")
              bottom
              (sync-ui--justify-space (string-width remotes) top)
              remotes
              (propertize " " 'face top))
      'sync-ui-id id)
     "\n")))

(defun sync-ui--remotes-summary (repo band)
  "Faded per-remote status: \"origin ↑2 · backup\", arrows only when non-zero.
A ⁺ marks a remote that has no copy of the branch yet."
  (let ((faded-band `(:inherit sync-ui-faded :background ,band))
        (salient-band `(:inherit sync-ui-salient :background ,band))
        (popout-band `(:inherit sync-ui-popout :background ,band)))
    (if (null (sync-ui--repo-remotes repo))
        (propertize "no remotes" 'face faded-band)
      (mapconcat
       (lambda (status)
         (pcase-let ((`(,name ,ahead ,behind) status))
           (concat (propertize name 'face faded-band)
                   (cond
                    ((null ahead)
                     (propertize (concat " " (sync-ui--symbol 'new)) 'face salient-band))
                    ((> ahead 0)
                     (propertize (format " %s%d" (sync-ui--symbol 'up) ahead) 'face salient-band))
                    (t ""))
                   (if (and behind (> behind 0))
                       (propertize (format " %s%d" (sync-ui--symbol 'down) behind) 'face popout-band)
                     ""))))
       (sync-ui--repo-remotes repo)
       (propertize "  " 'face faded-band)))))

(defun sync-ui--header-line ()
  "Four-slot status bar: [ SYNC | repos (n) ... counts ]."
  (let* ((total (length sync-ui--repos))
         (clean (cl-count-if (lambda (r)
                               (memq (sync-ui--repo-state r) '(clean synced)))
                             sync-ui--repos))
         (dirty (cl-count-if (lambda (r) (eq (sync-ui--repo-state r) 'dirty))
                             sync-ui--repos))
         (waiting (cl-count-if (lambda (r) (eq (sync-ui--repo-state r) 'waiting))
                               sync-ui--repos))
         (busy (cl-count-if (lambda (r)
                              (memq (sync-ui--repo-state r)
                                    '(committing fetching rebasing pushing)))
                            sync-ui--repos))
         (attention (cl-count-if (lambda (r)
                                   (memq (sync-ui--repo-state r) '(conflicted error missing)))
                                 sync-ui--repos))
         (chip (propertize " SYNC " 'face (if (> busy 0)
                                              'sync-ui-chip-active
                                            'sync-ui-chip)))
         (name (propertize " repos " 'face 'sync-ui-strong))
         (prim (propertize (format "(%d repo%s)" total (if (= total 1) "" "s"))
                           'face 'sync-ui-faded))
         (parts (delq nil
                      (list (format "%d/%d clean" clean total)
                            (and (> dirty 0) (format "%d dirty" dirty))
                            (and (> waiting 0) (format "%d waiting" waiting))
                            (and (> attention 0) (format "%d ⚠" attention)))))
         (right (propertize (concat (mapconcat #'identity parts " · ") " ")
                            'face 'sync-ui-faded)))
    (concat (propertize " " 'display '(raise 0.15))
            chip name
            (propertize " " 'display '(raise -0.20))
            prim
            (propertize " " 'display `(space :align-to (- right ,(string-width right))))
            right)))

(defun sync-ui--render ()
  "Re-render the dashboard, restoring point by repo id."
  (when-let* ((buf (get-buffer sync-ui--buffer-name)))
    (with-current-buffer buf
      (when (eq major-mode 'sync-ui-mode)
        (let ((id (get-text-property (point) 'sync-ui-id))
              (inhibit-read-only t))
          (erase-buffer)
          (sync-ui--insert-title)
          (sync-ui--insert-hints)
          (insert (sync-ui--hairline) "\n")
          (if (null sync-ui--repos)
              (insert (propertize "  no repos — a adds one" 'face 'sync-ui-faded)
                      "\n")
            (dolist (repo sync-ui--repos)
              (sync-ui--insert-card repo)
              (unless (eq repo (car (last sync-ui--repos)))
                (insert (propertize (concat "   " (sync-ui--symbol 'gutter))
                                    'face 'sync-ui-faded)
                        "\n"))))
          (if-let* ((match (and id
                                (progn (goto-char (point-min))
                                       (text-property-search-forward
                                        'sync-ui-id id #'equal)))))
              (goto-char (prop-match-beginning match))
            (goto-char (point-min))
            (sync-ui-next)))))))

(defun sync-ui--update-card (repo)
  "In-place rewrite of REPO's card; the buffer never reflows."
  (when-let* ((buf (get-buffer sync-ui--buffer-name)))
    (with-current-buffer buf
      (when (eq major-mode 'sync-ui-mode)
        (save-excursion
          (goto-char (point-min))
          (when-let* ((match (text-property-search-forward
                              'sync-ui-id (sync-ui--repo-id repo) #'equal)))
            (let ((inhibit-read-only t)
                  (beg (prop-match-beginning match)))
              (goto-char beg)
              (let ((end (min (point-max) (1+ (line-end-position)))))
                (delete-region beg end)
                (goto-char beg)
                (sync-ui--insert-card repo)))))))))

;;; § 7 Mode and navigation

(defun sync-ui--repo-at-point ()
  "Repo struct for the card at point."
  (when-let* ((id (get-text-property (point) 'sync-ui-id)))
    (sync-ui--find id)))

(defun sync-ui-next ()
  "Move to the next card."
  (interactive)
  (let ((match (text-property-search-forward 'sync-ui-id nil nil t)))
    (if match
        (goto-char (prop-match-beginning match))
      (goto-char (point-min))
      (when-let* ((first (text-property-search-forward 'sync-ui-id nil nil)))
        (goto-char (prop-match-beginning first))))))

(defun sync-ui-previous ()
  "Move to the previous card, wrapping to the last."
  (interactive)
  (let ((starts nil))
    (save-excursion
      (goto-char (point-min))
      (cl-loop for m = (text-property-search-forward 'sync-ui-id nil nil)
               while m
               do (push (prop-match-beginning m) starts)
                  (goto-char (prop-match-end m))))
    (let ((target (or (car (cl-remove-if-not (lambda (s) (< s (point))) starts))
                      (car starts))))
      (if target
          (goto-char target)
        (message "sync-ui: no cards")))))

(defun sync-ui--card-range ()
  "hl-line range: the whole card (both visual lines), or nothing."
  (if (get-text-property (point) 'sync-ui-id)
      (cons (line-beginning-position)
            (min (point-max) (1+ (line-end-position))))
    (cons (point) (point))))

(defun sync-ui--open-magit (repo)
  "Open REPO in magit, falling back to dired when magit is absent."
  (if (require 'magit nil t)
      (progn
        (declare-function magit-status "magit")
        (magit-status (sync-ui--repo-id repo)))
    (dired (sync-ui--repo-id repo))))

(defun sync-ui-magit ()
  "Open the repo at point in magit."
  (interactive)
  (if-let* ((repo (sync-ui--repo-at-point)))
      (sync-ui--open-magit repo)
    (user-error "No repo at point")))

(defun sync-ui--toggle (repo)
  "Flip REPO between auto and ask, persist, repaint."
  (setf (sync-ui--repo-mode repo)
        (if (eq (sync-ui--repo-mode repo) 'auto) 'ask 'auto))
  (sync-ui--save-repos)
  (sync-ui--update-card repo)
  (message "%s: %s" (sync-ui--repo-path repo) (sync-ui--repo-mode repo)))

(defun sync-ui-toggle ()
  "Toggle auto/ask for the repo at point."
  (interactive)
  (when-let* ((repo (sync-ui--repo-at-point)))
    (sync-ui--toggle repo)))

(defun sync-ui-add-repo (dir mode)
  "Register DIR as a managed repo with MODE (`auto' or `ask')."
  (interactive
   (list (read-directory-name "Repo: ")
         (intern (completing-read "Mode: " '("ask" "auto") nil t nil nil "ask"))))
  (unless sync-ui--repos (sync-ui--load-registry))
  (let* ((id (expand-file-name dir))
         (repo (sync-ui--repo-create
                :id id
                :path (abbreviate-file-name id)
                :mode mode)))
    (sync-ui--probe repo)
    (if (eq (sync-ui--repo-state repo) 'missing)
        (user-error "%s: %s" (sync-ui--repo-path repo)
                    (sync-ui--repo-message repo))
      (when (sync-ui--find id)
        (user-error "%s is already managed" (sync-ui--repo-path repo)))
      (setq sync-ui--repos (append sync-ui--repos (list repo)))
      (sync-ui--save-repos)
      (sync-ui--render)
      (message "%s added (%s)" (sync-ui--repo-path repo) mode))))

(defun sync-ui-remove-repo ()
  "Remove the repo at point from the managed set (the repo stays on disk)."
  (interactive)
  (when-let* ((repo (sync-ui--repo-at-point)))
    (when (y-or-n-p (format "Stop managing %s? " (sync-ui--repo-path repo)))
      (setq sync-ui--repos (delq repo sync-ui--repos))
      (sync-ui--save-repos)
      (sync-ui--render))))

(defvar sync-ui-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "s") #'sync-ui-sync-all)
    (define-key map (kbd "RET") #'sync-ui-magit)
    (define-key map (kbd "r") #'sync-ui-resume)
    (define-key map (kbd "x") #'sync-ui-skip)
    (define-key map (kbd "t") #'sync-ui-toggle)
    (define-key map (kbd "a") #'sync-ui-add-repo)
    (define-key map (kbd "d") #'sync-ui-remove-repo)
    (define-key map (kbd "g") #'sync-ui-refresh)
    (define-key map (kbd "n") #'sync-ui-next)
    (define-key map (kbd "p") #'sync-ui-previous)
    map)
  "Keymap for `sync-ui-mode'.")

(define-derived-mode sync-ui-mode special-mode "sync"
  "NΛNO-style dashboard for git repo sync."
  (setq-local cursor-type nil
              truncate-lines t
              left-fringe-width 1
              right-fringe-width 8
              header-line-format '(:eval (sync-ui--header-line))
              mode-line-format ""
              hl-line-range-function #'sync-ui--card-range)
  (face-remap-set-base 'hl-line 'sync-ui-selected)
  (hl-line-mode 1))

(declare-function evil-set-initial-state "evil")
(declare-function evil-define-key* "evil-core")

(with-eval-after-load 'evil
  (evil-set-initial-state 'sync-ui-mode 'normal)
  ;; `evil-define-key' is a macro: calling it from a file byte-compiled
  ;; without evil loaded yields (invalid-function evil-define-key).
  ;; `evil-define-key*' is the function underneath and is always safe.
  (evil-define-key* 'normal sync-ui-mode-map
    (kbd "j") #'sync-ui-next
    (kbd "k") #'sync-ui-previous
    (kbd "RET") #'sync-ui-magit))

;;; § 8 Entry points

;;;###autoload
(defun sync-ui ()
  "Open the sync dashboard."
  (interactive)
  (unless sync-ui--repos (sync-ui--load-registry))
  (mapc #'sync-ui--probe sync-ui--repos)
  (let ((buf (get-buffer-create sync-ui--buffer-name)))
    (with-current-buffer buf
      (unless (eq major-mode 'sync-ui-mode)
        (sync-ui-mode))
      (sync-ui--render))
    (pop-to-buffer buf)))

(provide 'sync-ui)
;;; sync-ui.el ends here
