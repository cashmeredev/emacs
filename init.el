;; -*- lexical-binding: t; -*-

;; Pre-set elpaca-core-date for dev Emacs builds (31.x) where the
;; release table has no entry and emacs-build-time may be nil at load time.
(defvar elpaca-core-date
  (list (string-to-number (format-time-string "%Y%m%d" (or emacs-build-time (current-time))))))

(defvar elpaca-queue-limit 4)

;; Elpaca bootstrap
(defvar elpaca-installer-version 0.12)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-sources-directory (expand-file-name "sources/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1 :inherit ignore
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca-activate)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-sources-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (<= emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let* ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                  ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                  ,@(when-let* ((depth (plist-get order :depth)))
                                                      (list (format "--depth=%d" depth) "--no-single-branch"))
                                                  ,(plist-get order :repo) ,repo))))
                  ((zerop (call-process "git" nil buffer t "checkout"
                                        (or (plist-get order :ref) "--"))))
                  (emacs (concat invocation-directory invocation-name))
                  ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                        "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                  ((require 'elpaca))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (let ((load-source-file-function nil)) (load "./elpaca-autoloads"))))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

;; Install use-package support
(elpaca (elpaca-use-package :wait t)
  (elpaca-use-package-mode)
  (setq elpaca-use-package-by-default t
        use-package-compute-statistics t))

;; Install org before tangling config.org
(elpaca (org :ref "release_9.8.5" :depth nil :wait t))

;; Shadow built-in transient with newer version before magit loads
(elpaca (transient :wait t))

;; Startup profiling: benchmark-init records require/load wallclock so the
;; tangled config.el load below is fully measured. Inspect afterwards with
;; M-x benchmark-init/show-durations-tree (or use-package-report for use-package).
(elpaca (benchmark-init :wait t)
  (require 'benchmark-init)
  (benchmark-init/activate))
(add-hook 'elpaca-after-init-hook #'benchmark-init/deactivate)

;; Load config: tangle only when org is newer than the tangled .el.
;; Saves the entire org parse on hot starts.
(let* ((dir user-emacs-directory)
       (org-file (expand-file-name "config.org" dir))
       (el-file  (expand-file-name "config.el"  dir)))
  (when (or (not (file-exists-p el-file))
            (file-newer-than-file-p org-file el-file))
    (require 'org)
    (require 'ob-tangle)
    (let ((gc-cons-threshold most-positive-fixnum))
      (org-babel-tangle-file org-file el-file "emacs-lisp")))
  ;; Prefer .elc when present; native-compile asynchronously in the background.
  (load (file-name-sans-extension el-file) nil 'nomessage)
  (when (and (featurep 'native-compile)
             (fboundp 'native-comp-available-p)
             (native-comp-available-p))
    ;; Defer until elpaca finishes building all packages so macro-providing
    ;; libraries (e.g. general.el / my-leader) are on load-path when the
    ;; subprocess re-evaluates config.el.
    (add-hook 'elpaca-after-init-hook
              (lambda () (native-compile-async el-file nil t)))))
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("d43860349c9f7a5b96a090ecf5f698ff23a8eb49cd1e5c8a83bb2068f24ea563"
	 default))
 '(zoom-size '(0.382 . 0.618)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(org-document-title ((t (:height 1.6))))
 '(outline-1 ((t (:height 1.25))))
 '(outline-2 ((t (:height 1.2))))
 '(outline-3 ((t (:height 1.2))))
 '(outline-4 ((t (:height 1.2))))
 '(outline-5 ((t (:height 1.2))))
 '(outline-6 ((t (:height 1.2))))
 '(outline-7 ((t (:height 1.2))))
 '(outline-8 ((t (:height 1.2))))
 '(outline-9 ((t (:height 1.2)))))
