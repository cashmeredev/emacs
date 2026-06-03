;; -*- lexical-binding: t; -*-

;; ---- Startup perf knobs ----
;; Suppress GC and file-name-handlers during init; restored in after-init.
(defvar my/file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;; Skip site-start.el on NixOS — it loads /etc/emacs and slows boot.
(setq site-run-file nil)

;; Don't let Emacs parse customizations affecting frame on first GUI frame.
(setq frame-inhibit-implied-resize t)

;; Suppress redisplay during heavy init.
(setq inhibit-compacting-font-caches t
      idle-update-delay 1.0
      redisplay-skip-fontification-on-input t)

;; Restore after init.
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist my/file-name-handler-alist
                  gc-cons-threshold (* 64 1024 1024)
                  gc-cons-percentage 0.1)))

;; ---- Package manager hands-off until init.el ----
(setq package-enable-at-startup nil)

;; ---- UI chrome off pre-frame ----
(push '(left-fringe . 0) default-frame-alist)
(push '(right-fringe . 0) default-frame-alist)
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(fringe-mode 0)
(setq-default overflow-newline-into-fringe nil)

(provide 'early-init)
