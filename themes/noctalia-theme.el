;;; noctalia-theme.el --- Noctalia theme for Emacs -*- lexical-binding: t -*-

;; Copyright (C) 2025

;; Author: Noctalia User Template (Fixed)
;; Version: 2.0
;; Package-Requires: ((emacs "24.1"))
;; Keywords: faces

;;; Commentary:

;; Noctalia Emacs theme generated via user template.
;; Fixes the built-in template's misuse of MD3 container colors as foreground
;; text. All heading and text faces use surface-readable colors only.

;;; Code:

(deftheme noctalia "Noctalia theme with proper color contrast.")

(let* (;; Core surface colors
       (bg "#161616")
       (fg "#f2f4f8")
       (surface "#161616")
       (on-surface "#f2f4f8")
       (on-surface-variant "#b6b8bb")
       (surface-variant "#353535")
       (surface-container "#353535")
       (surface-container-low "#252525")
       (surface-container-lowest "#1c1c1c")
       (surface-container-high "#3f3f3f")
       (surface-container-highest "#494949")

       ;; Accent colors (always readable on surface)
       (primary "#78a9ff")
       (secondary "#25be6a")
       (tertiary "#be95ff")
       (err "#ee5396")

       ;; Container colors (for BACKGROUNDS only, never as foreground text)
       (primary-container "#0047c5")
       (secondary-container "#074623")
       (tertiary-container "#5700e2")
       (err-container "#8c023e")

       ;; On-color text (for text ON accent backgrounds)
       (on-primary "#161616")
       (on-secondary "#161616")
       (on-tertiary "#161616")
       (on-err "#161616")

       ;; On-container text (for text on container backgrounds)
       (on-primary-container "#ccdfff")
       (on-secondary-container "#d4f7e4")
       (on-tertiary-container "#e0ccff")
       (on-err-container "#fad1e3")

       ;; Outline colors
       (outline-color "#636363")
       (outline-variant "#3d3d3d")

       ;; Shadow
       (shadow "#000000")

       ;; Auto-lightness variants: lighten in dark mode, darken in light mode
       ;; Used for heading levels 5-7, rainbow delimiters 5-7, terminal variants
       (primary-variant "#2c78ff")
       (secondary-variant "#52dd91")
       (tertiary-variant "#8f48ff")
       (err-variant "#df166d"))

  (custom-theme-set-faces
   'noctalia

   ;; === Basic faces ===
   `(default ((t (:background ,bg :foreground ,fg))))
   `(cursor ((t (:background ,primary))))
   `(highlight ((t (:background ,surface-container-high))))
   `(region ((t (:background ,primary-container :foreground ,on-primary-container :extend t))))
   `(secondary-selection ((t (:background ,secondary-container :foreground ,on-secondary-container :extend t))))
   `(isearch ((t (:background ,tertiary-container :foreground ,on-tertiary-container :weight bold))))
   `(lazy-highlight ((t (:background ,secondary-container :foreground ,on-secondary-container))))
   `(vertical-border ((t (:foreground ,surface-variant))))
   `(border ((t (:background ,surface-variant :foreground ,surface-variant))))
   `(fringe ((t (:background ,surface :foreground ,outline-variant))))
   `(shadow ((t (:foreground ,outline-variant))))
   `(link ((t (:foreground ,primary :underline t))))
   `(link-visited ((t (:foreground ,tertiary :underline t))))
   `(success ((t (:foreground ,tertiary))))
   `(warning ((t (:foreground ,secondary))))
   `(error ((t (:foreground ,err))))
   `(match ((t (:background ,secondary-container :foreground ,on-secondary-container))))

   ;; === Font-lock ===
   `(font-lock-builtin-face ((t (:foreground ,primary))))
   `(font-lock-comment-face ((t (:foreground ,outline-color :slant italic))))
   `(font-lock-comment-delimiter-face ((t (:foreground ,outline-variant))))
   `(font-lock-constant-face ((t (:foreground ,tertiary :weight bold))))
   `(font-lock-doc-face ((t (:foreground ,on-surface-variant :slant italic))))
   `(font-lock-function-name-face ((t (:foreground ,primary :weight bold))))
   `(font-lock-keyword-face ((t (:foreground ,secondary :weight bold))))
   `(font-lock-string-face ((t (:foreground ,tertiary))))
   `(font-lock-type-face ((t (:foreground ,primary))))
   `(font-lock-variable-name-face ((t (:foreground ,on-surface))))
   `(font-lock-warning-face ((t (:foreground ,err :weight bold))))
   `(font-lock-preprocessor-face ((t (:foreground ,on-surface-variant))))   ;; FIX: was secondary_fixed_dim (invisible)
   `(font-lock-negation-char-face ((t (:foreground ,tertiary))))

   ;; === Show paren ===
   `(show-paren-match ((t (:background ,primary-container :foreground ,on-primary-container :weight bold))))
   `(show-paren-mismatch ((t (:background ,err-container :foreground ,on-err-container :weight bold))))

   ;; === Mode line ===
   `(mode-line ((t (:background ,surface-container-high :foreground ,on-surface :box nil))))
   `(mode-line-inactive ((t (:background ,surface :foreground ,on-surface-variant :box nil))))
   `(mode-line-buffer-id ((t (:foreground ,primary :weight bold))))
   `(mode-line-emphasis ((t (:foreground ,primary :weight bold))))
   `(mode-line-highlight ((t (:foreground ,primary :box nil))))

   ;; === Org source blocks ===
   `(org-block ((t (:background ,surface-container-low :extend t :inherit fixed-pitch))))
   `(org-block-begin-line ((t (:background ,surface-container-low :foreground ,outline-color :extend t :slant italic :inherit fixed-pitch))))  ;; FIX: was primary_fixed_dim
   `(org-block-end-line ((t (:background ,surface-container-low :foreground ,outline-color :extend t :slant italic :inherit fixed-pitch))))    ;; FIX: was primary_fixed_dim
   `(org-code ((t (:background ,surface-container-low :foreground ,tertiary :inherit fixed-pitch))))
   `(org-verbatim ((t (:background ,surface-container-low :foreground ,primary :inherit fixed-pitch))))
   `(org-meta-line ((t (:foreground ,outline-color :slant italic))))

   ;; === Org headings - FIXED: 4 distinct hues + variants, all surface-readable ===
   `(org-level-1 ((t (:foreground ,primary :weight bold :height 1.2))))
   `(org-level-2 ((t (:foreground ,secondary :weight bold :height 1.1))))          ;; FIX: was primary_container
   `(org-level-3 ((t (:foreground ,tertiary :weight bold))))                        ;; FIX: was secondary
   `(org-level-4 ((t (:foreground ,err :weight bold))))                             ;; FIX: was secondary_container
   `(org-level-5 ((t (:foreground ,primary-variant :weight bold))))                 ;; FIX: was tertiary
   `(org-level-6 ((t (:foreground ,secondary-variant :weight bold))))               ;; FIX: was tertiary_container
   `(org-level-7 ((t (:foreground ,tertiary-variant :weight bold))))                ;; FIX: was primary_fixed (= primary duplicate)
   `(org-level-8 ((t (:foreground ,on-surface-variant :weight bold))))              ;; FIX: was primary_fixed_dim
   `(org-document-title ((t (:foreground ,primary :weight bold :height 1.3))))
   `(org-document-info ((t (:foreground ,on-surface-variant))))                     ;; FIX: was primary_container
   `(org-todo ((t (:foreground ,err :weight bold))))
   `(org-done ((t (:foreground ,tertiary :weight bold))))
   `(org-headline-done ((t (:foreground ,on-surface-variant))))
   `(org-hide ((t (:foreground ,bg))))
   `(org-ellipsis ((t (:foreground ,tertiary :underline nil))))
   `(org-table ((t (:foreground ,secondary :inherit fixed-pitch))))
   `(org-formula ((t (:foreground ,tertiary :inherit fixed-pitch))))
   `(org-checkbox ((t (:foreground ,primary :weight bold :inherit fixed-pitch))))
   `(org-date ((t (:foreground ,secondary :underline t))))
   `(org-special-keyword ((t (:foreground ,on-surface-variant :slant italic))))
   `(org-tag ((t (:foreground ,outline-color :weight normal))))

   ;; === Magit ===
   `(magit-section-highlight ((t (:background ,surface-container-low))))
   `(magit-diff-hunk-heading ((t (:background ,surface-container :foreground ,on-surface-variant))))
   `(magit-diff-hunk-heading-highlight ((t (:background ,surface-container-high :foreground ,on-surface))))
   `(magit-diff-context ((t (:foreground ,on-surface-variant))))
   `(magit-diff-context-highlight ((t (:background ,surface-container-low :foreground ,on-surface))))
   `(magit-diff-added ((t (:background ,tertiary-container :foreground ,on-tertiary-container))))
   `(magit-diff-added-highlight ((t (:background ,tertiary-container :foreground ,on-tertiary-container :weight bold))))
   `(magit-diff-removed ((t (:background ,err-container :foreground ,on-err-container))))
   `(magit-diff-removed-highlight ((t (:background ,err-container :foreground ,on-err-container :weight bold))))
   `(magit-hash ((t (:foreground ,outline-color))))
   `(magit-branch-local ((t (:foreground ,tertiary :weight bold))))
   `(magit-branch-remote ((t (:foreground ,primary :weight bold))))

   ;; === Company ===
   `(company-tooltip ((t (:background ,surface-container :foreground ,on-surface))))
   `(company-tooltip-selection ((t (:background ,primary-container :foreground ,on-primary-container))))
   `(company-tooltip-common ((t (:foreground ,primary))))
   `(company-tooltip-common-selection ((t (:foreground ,on-primary-container :weight bold))))
   `(company-tooltip-annotation ((t (:foreground ,tertiary))))
   `(company-scrollbar-fg ((t (:background ,primary))))
   `(company-scrollbar-bg ((t (:background ,surface-variant))))
   `(company-preview ((t (:foreground ,on-surface-variant :slant italic))))
   `(company-preview-common ((t (:foreground ,primary :slant italic))))

   ;; === Ido ===
   `(ido-first-match ((t (:foreground ,primary :weight bold))))
   `(ido-only-match ((t (:foreground ,tertiary :weight bold))))
   `(ido-subdir ((t (:foreground ,secondary))))
   `(ido-indicator ((t (:foreground ,err))))
   `(ido-virtual ((t (:foreground ,outline-color))))

   ;; === Helm ===
   `(helm-selection ((t (:background ,primary-container :foreground ,on-primary-container))))
   `(helm-match ((t (:foreground ,primary :weight bold))))
   `(helm-source-header ((t (:background ,surface-container-high :foreground ,primary :weight bold :height 1.1))))
   `(helm-candidate-number ((t (:foreground ,tertiary :weight bold))))
   `(helm-ff-directory ((t (:foreground ,primary :weight bold))))
   `(helm-ff-file ((t (:foreground ,on-surface))))
   `(helm-ff-executable ((t (:foreground ,tertiary))))

   ;; === Corfu ===
   `(corfu-default ((t (:background ,surface-container :foreground ,on-surface))))
   `(corfu-current ((t (:background ,primary-container :foreground ,on-primary-container))))

   ;; === Which-key ===
   `(which-key-key-face ((t (:foreground ,primary :weight bold))))
   `(which-key-separator-face ((t (:foreground ,outline-variant))))
   `(which-key-command-description-face ((t (:foreground ,on-surface))))
   `(which-key-group-description-face ((t (:foreground ,secondary))))
   `(which-key-special-key-face ((t (:foreground ,tertiary :weight bold))))

   ;; === Line numbers ===
   `(line-number ((t (:foreground ,outline-variant :inherit fixed-pitch))))
   `(line-number-current-line ((t (:foreground ,primary :weight bold :inherit fixed-pitch))))

   ;; === Parenthesis matching ===
   `(sp-show-pair-match-face ((t (:background ,primary-container :foreground ,on-primary-container))))
   `(sp-show-pair-mismatch-face ((t (:background ,err-container :foreground ,on-err-container))))

   ;; === Rainbow delimiters - FIXED: all levels use readable colors ===
   `(rainbow-delimiters-depth-1-face ((t (:foreground ,primary))))
   `(rainbow-delimiters-depth-2-face ((t (:foreground ,secondary))))
   `(rainbow-delimiters-depth-3-face ((t (:foreground ,tertiary))))
   `(rainbow-delimiters-depth-4-face ((t (:foreground ,err))))
   `(rainbow-delimiters-depth-5-face ((t (:foreground ,primary-variant))))
   `(rainbow-delimiters-depth-6-face ((t (:foreground ,secondary-variant))))
   `(rainbow-delimiters-depth-7-face ((t (:foreground ,tertiary-variant))))          ;; FIX: was primary_fixed_dim
   `(rainbow-delimiters-depth-8-face ((t (:foreground ,on-surface-variant))))        ;; FIX: was secondary_fixed_dim
   `(rainbow-delimiters-depth-9-face ((t (:foreground ,outline-color))))             ;; FIX: was tertiary_fixed_dim
   `(rainbow-delimiters-mismatched-face ((t (:foreground ,err :weight bold))))
   `(rainbow-delimiters-unmatched-face ((t (:foreground ,err :weight bold))))

   ;; === Dired ===
   `(dired-directory ((t (:foreground ,primary :weight bold))))
   `(dired-ignored ((t (:foreground ,outline-variant))))
   `(dired-flagged ((t (:foreground ,err))))
   `(dired-marked ((t (:foreground ,tertiary :weight bold))))
   `(dired-symlink ((t (:foreground ,secondary :slant italic))))
   `(dired-header ((t (:foreground ,primary :weight bold :height 1.1))))

   ;; === Terminal colors - FIXED: no container colors as foreground ===
   `(term-color-black ((t (:foreground ,surface-container-lowest :background ,surface-container-lowest))))
   `(term-color-red ((t (:foreground ,err :background ,err))))
   `(term-color-green ((t (:foreground ,tertiary :background ,tertiary))))
   `(term-color-yellow ((t (:foreground ,secondary :background ,secondary))))
   `(term-color-blue ((t (:foreground ,primary :background ,primary))))
   `(term-color-magenta ((t (:foreground ,err-variant :background ,err-variant))))   ;; FIX: was tertiary_container
   `(term-color-cyan ((t (:foreground ,primary-variant :background ,primary-variant)))) ;; FIX: was secondary_container
   `(term-color-white ((t (:foreground ,on-surface :background ,on-surface))))

   ;; === EShell ===
   `(eshell-prompt ((t (:foreground ,primary :weight bold))))
   `(eshell-ls-directory ((t (:foreground ,primary :weight bold))))
   `(eshell-ls-symlink ((t (:foreground ,secondary :slant italic))))
   `(eshell-ls-executable ((t (:foreground ,tertiary))))
   `(eshell-ls-archive ((t (:foreground ,on-tertiary-container))))
   `(eshell-ls-backup ((t (:foreground ,outline-variant))))
   `(eshell-ls-clutter ((t (:foreground ,err))))
   `(eshell-ls-missing ((t (:foreground ,err))))
   `(eshell-ls-product ((t (:foreground ,on-surface-variant))))
   `(eshell-ls-readonly ((t (:foreground ,on-surface-variant))))
   `(eshell-ls-special ((t (:foreground ,secondary))))
   `(eshell-ls-unreadable ((t (:foreground ,outline-variant))))

   ;; === Markdown - FIXED: same heading fix as org ===
   `(markdown-header-face ((t (:foreground ,primary :weight bold))))
   `(markdown-header-face-1 ((t (:foreground ,primary :weight bold :height 1.2))))
   `(markdown-header-face-2 ((t (:foreground ,secondary :weight bold :height 1.1))))  ;; FIX: was primary_container
   `(markdown-header-face-3 ((t (:foreground ,tertiary :weight bold))))                ;; FIX: was secondary
   `(markdown-header-face-4 ((t (:foreground ,err :weight bold))))                     ;; FIX: was secondary_container
   `(markdown-inline-code-face ((t (:foreground ,tertiary :background ,surface-container-low :inherit fixed-pitch))))
   `(markdown-code-face ((t (:background ,surface-container-low :extend t :inherit fixed-pitch))))
   `(markdown-pre-face ((t (:background ,surface-container-low :inherit fixed-pitch))))
   `(markdown-table-face ((t (:foreground ,secondary :inherit fixed-pitch))))

   ;; === Web mode ===
   `(web-mode-html-tag-face ((t (:foreground ,primary))))
   `(web-mode-html-tag-bracket-face ((t (:foreground ,on-surface-variant))))
   `(web-mode-html-attr-name-face ((t (:foreground ,secondary))))
   `(web-mode-html-attr-value-face ((t (:foreground ,tertiary))))
   `(web-mode-css-selector-face ((t (:foreground ,primary))))
   `(web-mode-css-property-name-face ((t (:foreground ,secondary))))
   `(web-mode-css-string-face ((t (:foreground ,tertiary))))

   ;; === Flycheck ===
   `(flycheck-error ((t (:underline (:style wave :color ,err)))))
   `(flycheck-warning ((t (:underline (:style wave :color ,secondary)))))
   `(flycheck-info ((t (:underline (:style wave :color ,tertiary)))))
   `(flycheck-fringe-error ((t (:foreground ,err))))
   `(flycheck-fringe-warning ((t (:foreground ,secondary))))
   `(flycheck-fringe-info ((t (:foreground ,tertiary))))

   ;; === Minibuffer ===
   `(minibuffer-prompt ((t (:foreground ,primary :weight bold))))

   ;; === LSP ===
   `(lsp-face-highlight-textual ((t (:background ,primary-container :foreground ,on-primary-container :weight bold))))
   `(lsp-face-highlight-read ((t (:background ,secondary-container :foreground ,on-secondary-container :weight bold))))
   `(lsp-face-highlight-write ((t (:background ,tertiary-container :foreground ,on-tertiary-container :weight bold))))

   ;; === Info titles - FIXED: same heading fix ===
   `(info-title-1 ((t (:foreground ,primary :weight bold :height 1.3))))
   `(info-title-2 ((t (:foreground ,secondary :weight bold :height 1.2))))   ;; FIX: was primary_container
   `(info-title-3 ((t (:foreground ,tertiary :weight bold :height 1.1))))    ;; FIX: was secondary
   `(info-title-4 ((t (:foreground ,err :weight bold))))                     ;; FIX: was secondary_container
   `(Info-quoted ((t (:foreground ,tertiary))))
   `(info-menu-header ((t (:foreground ,primary :weight bold))))
   `(info-menu-star ((t (:foreground ,primary))))
   `(info-node ((t (:foreground ,tertiary :weight bold))))

   ;; === Tabs ===
   `(tab-bar ((t (:background ,surface-container-high :foreground ,on-surface :box nil))))
   `(tab-bar-tab ((t (:background ,surface-container-high :foreground ,on-surface :weight bold :box nil))))
   `(tab-bar-tab-inactive ((t (:background ,surface :foreground ,on-surface-variant :box nil))))
   `(tab-line ((t (:background ,surface-container-high :foreground ,on-surface :box nil))))
   `(tab-line-tab ((t (:background ,surface :foreground ,on-surface-variant :box nil))))
   `(tab-line-tab-current ((t (:background ,surface-container-high :foreground ,on-surface :weight bold :box nil))))
   `(tab-line-tab-inactive ((t (:background ,surface :foreground ,on-surface-variant :box nil))))
   `(tab-line-highlight ((t (:background ,surface-container-highest :foreground ,on-surface))))
   `(centaur-tabs-default ((t (:background ,surface-container-high :foreground ,on-surface))))
   `(centaur-tabs-selected ((t (:background ,surface-container-high :foreground ,on-surface :weight bold))))
   `(centaur-tabs-unselected ((t (:background ,surface :foreground ,on-surface-variant))))
   `(centaur-tabs-selected-modified ((t (:background ,surface-container-high :foreground ,tertiary :weight bold))))
   `(centaur-tabs-unselected-modified ((t (:background ,surface :foreground ,tertiary))))
   `(centaur-tabs-active-bar-face ((t (:background ,primary))))

   ;; === Fixed/variable pitch ===
   `(fixed-pitch ((t (:family "monospace"))))
   `(fixed-pitch-serif ((t (:family "monospace serif"))))
   `(variable-pitch ((t (:family "sans serif"))))
   ))

;; Org-mode settings
(with-eval-after-load 'org
  (setq org-hide-leading-stars t)
  (setq org-startup-indented t))

;;;###autoload
(when load-file-name
  (add-to-list 'custom-theme-load-path
               (file-name-as-directory (file-name-directory load-file-name))))

(provide-theme 'noctalia)
;;; noctalia-theme.el ends here
