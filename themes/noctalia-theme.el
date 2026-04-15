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

   ;; === Basic builtins (missing) ===
   `(bold ((t (:weight bold))))
   `(bold-italic ((t (:weight bold :slant italic))))
   `(italic ((t (:slant italic))))
   `(bookmark-face ((t (:foreground ,primary :weight bold :underline t))))
   `(nobreak-space ((t (:background ,bg :foreground ,fg))))
   `(tooltip ((t (:background ,surface-container-high :foreground ,on-surface))))
   `(trailing-whitespace ((t (:background ,err))))
   `(header-line ((t (:background ,surface-container-low :foreground ,on-surface))))
   `(window-divider ((t (:background ,outline-variant :foreground ,outline-variant))))
   `(window-divider-first-pixel ((t (:background ,outline-variant :foreground ,outline-variant))))
   `(window-divider-last-pixel ((t (:background ,outline-variant :foreground ,outline-variant))))

   ;; === Font-lock (missing) ===
   `(font-lock-preprocessor-char-face ((t (:foreground ,on-surface-variant :weight bold))))
   `(font-lock-regexp-grouping-backslash ((t (:foreground ,tertiary :weight bold))))
   `(font-lock-regexp-grouping-construct ((t (:foreground ,secondary :weight bold))))

   ;; === Isearch ===
   `(isearch ((t (:background ,tertiary-container :foreground ,on-tertiary-container :weight bold))))
   `(isearch-fail ((t (:background ,err-container :foreground ,on-err-container :weight bold))))

   ;; === HL-line ===
   `(hl-line ((t (:background ,surface-container-low :extend t))))

   ;; === HL-todo ===
   `(hl-todo ((t (:foreground ,err :weight bold))))

   ;; === Trailing whitespace & linum ===
   `(linum ((t (:foreground ,outline-variant))))
   `(linum-relative-current-face ((t (:background ,surface-container :foreground ,on-surface))))
   `(linum-highlight-face ((t (:foreground ,on-surface :weight normal))))

   ;; === Outline (non-org) ===
   `(outline-1 ((t (:foreground ,primary :weight ultra-bold))))
   `(outline-2 ((t (:foreground ,secondary :weight bold))))
   `(outline-3 ((t (:foreground ,tertiary :weight bold))))
   `(outline-4 ((t (:foreground ,err))))
   `(outline-5 ((t (:foreground ,primary-variant))))
   `(outline-6 ((t (:foreground ,secondary-variant))))
   `(outline-7 ((t (:foreground ,tertiary-variant))))
   `(outline-8 ((t (:foreground ,on-surface-variant))))
   `(outline-minor-1 ((t (:foreground ,primary :weight ultra-bold))))
   `(outline-minor-2 ((t (:foreground ,secondary :weight bold))))
   `(outline-minor-3 ((t (:foreground ,tertiary :weight bold))))
   `(outline-minor-4 ((t (:foreground ,err))))
   `(outline-minor-5 ((t (:foreground ,primary-variant))))
   `(outline-minor-6 ((t (:foreground ,secondary-variant))))
   `(outline-minor-7 ((t (:foreground ,tertiary-variant))))
   `(outline-minor-8 ((t (:foreground ,on-surface-variant))))

   ;; === Org (missing faces) ===
   `(org-archived ((t (:foreground ,outline-color))))
   `(org-block-background ((t (:background ,surface-container-low :extend t))))
   `(org-checkbox-statistics-done ((t (:foreground ,outline-color :weight bold))))
   `(org-checkbox-statistics-todo ((t (:foreground ,tertiary :weight bold))))
   `(org-default ((t (:background ,bg :foreground ,fg))))
   `(org-document-info-keyword ((t (:foreground ,outline-color))))
   `(org-footnote ((t (:foreground ,secondary :underline t))))
   `(org-latex-and-related ((t (:foreground ,on-surface-variant :weight bold))))
   `(org-link ((t (:foreground ,primary :underline t))))
   `(org-list-dt ((t (:foreground ,secondary :weight bold))))
   `(org-priority ((t (:foreground ,err))))
   `(org-property-value ((t (:foreground ,outline-color))))
   `(org-quote ((t (:background ,surface-container :slant italic :extend t))))
   `(org-warning ((t (:foreground ,secondary :weight bold))))

   ;; === Org agenda ===
   `(org-agenda-clocking ((t (:background ,secondary-container :foreground ,on-secondary-container))))
   `(org-agenda-current-time ((t (:foreground ,tertiary :weight bold))))
   `(org-agenda-date ((t (:foreground ,primary :weight ultra-bold))))
   `(org-agenda-date-today ((t (:foreground ,primary :weight ultra-bold))))
   `(org-agenda-date-weekend ((t (:foreground ,primary :weight ultra-bold))))
   `(org-agenda-dimmed-todo-face ((t (:foreground ,outline-color))))
   `(org-agenda-done ((t (:foreground ,tertiary))))
   `(org-agenda-structure ((t (:foreground ,on-surface :weight ultra-bold))))
   `(org-imminent-deadline ((t (:foreground ,err))))
   `(org-scheduled ((t (:foreground ,on-surface))))
   `(org-scheduled-previously ((t (:foreground ,on-surface-variant))))
   `(org-scheduled-today ((t (:foreground ,on-surface))))
   `(org-sexp-date ((t (:foreground ,on-surface))))
   `(org-time-grid ((t (:foreground ,outline-variant))))
   `(org-upcoming-deadline ((t (:foreground ,on-surface))))
   `(org-upcoming-distant-deadline ((t (:foreground ,on-surface))))
   `(org-agenda-structure-filter ((t (:foreground ,primary :weight bold))))

   ;; === Org habit ===
   `(org-habit-alert-face ((t (:weight bold :background ,secondary-container))))
   `(org-habit-alert-future-face ((t (:weight bold :background ,secondary-container))))
   `(org-habit-clear-face ((t (:weight bold :background ,surface-container-high))))
   `(org-habit-clear-future-face ((t (:weight bold :background ,surface-container))))
   `(org-habit-overdue-face ((t (:weight bold :background ,err-container))))
   `(org-habit-overdue-future-face ((t (:weight bold :background ,err-container))))
   `(org-habit-ready-face ((t (:weight bold :background ,tertiary-container))))
   `(org-habit-ready-future-face ((t (:weight bold :background ,tertiary-container))))

   ;; === Org journal ===
   `(org-journal-calendar-entry-face ((t (:foreground ,secondary :slant italic))))
   `(org-journal-calendar-scheduled-face ((t (:foreground ,err :slant italic))))
   `(org-journal-highlight ((t (:foreground ,tertiary))))

   ;; === Org pomodoro ===
   `(org-pomodoro-mode-line ((t (:foreground ,err))))
   `(org-pomodoro-mode-line-overtime ((t (:foreground ,secondary :weight bold))))

   ;; === Org ref ===
   `(org-ref-acronym-face ((t (:foreground ,primary))))
   `(org-ref-cite-face ((t (:foreground ,secondary :weight light :underline t))))
   `(org-ref-glossary-face ((t (:foreground ,tertiary))))
   `(org-ref-label-face ((t (:foreground ,primary))))
   `(org-ref-ref-face ((t (:foreground ,err :underline t :weight bold))))

   ;; === Ace-window ===
   `(aw-leading-char-face ((t (:foreground ,err :height 500 :weight bold))))
   `(aw-background-face ((t (:foreground ,outline-color))))

   ;; === Alert ===
   `(alert-high-face ((t (:foreground ,secondary :weight bold))))
   `(alert-low-face ((t (:foreground ,outline-color))))
   `(alert-moderate-face ((t (:foreground ,on-surface-variant :weight bold))))
   `(alert-trivial-face ((t (:foreground ,outline-variant))))
   `(alert-urgent-face ((t (:foreground ,err :weight bold))))

   ;; === ANSI colors ===
   `(ansi-color-black ((t (:foreground ,surface-container-lowest))))
   `(ansi-color-red ((t (:foreground ,err))))
   `(ansi-color-green ((t (:foreground ,tertiary))))
   `(ansi-color-yellow ((t (:foreground ,secondary))))
   `(ansi-color-blue ((t (:foreground ,primary))))
   `(ansi-color-magenta ((t (:foreground ,err-variant))))
   `(ansi-color-cyan ((t (:foreground ,primary-variant))))
   `(ansi-color-white ((t (:foreground ,on-surface))))
   `(ansi-color-bright-black ((t (:foreground ,surface-container-high))))
   `(ansi-color-bright-red ((t (:foreground ,err-variant))))
   `(ansi-color-bright-green ((t (:foreground ,tertiary-variant))))
   `(ansi-color-bright-yellow ((t (:foreground ,secondary-variant))))
   `(ansi-color-bright-blue ((t (:foreground ,primary-variant))))
   `(ansi-color-bright-magenta ((t (:foreground ,err))))
   `(ansi-color-bright-cyan ((t (:foreground ,tertiary))))
   `(ansi-color-bright-white ((t (:foreground ,fg))))

   ;; === Anzu ===
   `(anzu-replace-highlight ((t (:background ,surface-container :foreground ,err :weight bold :strike-through t))))
   `(anzu-replace-to ((t (:background ,surface-container :foreground ,tertiary :weight bold))))

   ;; === Avy ===
   `(avy-background-face ((t (:foreground ,outline-color))))
   `(avy-lead-face ((t (:background ,primary :foreground ,on-primary :weight bold))))
   `(avy-lead-face-0 ((t (:background ,primary :foreground ,on-primary :weight bold))))
   `(avy-lead-face-1 ((t (:background ,secondary :foreground ,on-secondary :weight bold))))
   `(avy-lead-face-2 ((t (:background ,tertiary :foreground ,on-tertiary :weight bold))))

   ;; === Compilation ===
   `(compilation-column-number ((t (:foreground ,outline-color))))
   `(compilation-error ((t (:foreground ,err :weight bold))))
   `(compilation-info ((t (:foreground ,tertiary))))
   `(compilation-line-number ((t (:foreground ,err))))
   `(compilation-mode-line-exit ((t (:foreground ,tertiary))))
   `(compilation-mode-line-fail ((t (:foreground ,err :weight bold))))
   `(compilation-warning ((t (:foreground ,secondary :slant italic))))

   ;; === Consult ===
   `(consult-file ((t (:foreground ,primary))))
   `(consult-separator ((t (:foreground ,outline-variant))))
   `(consult-notes-dir ((t (:foreground ,primary))))
   `(consult-notes-size ((t (:foreground ,secondary))))
   `(consult-notes-name ((t (:foreground ,primary))))
   `(consult-notes-time ((t (:foreground ,primary))))

   ;; === Counsel ===
   `(counsel-variable-documentation ((t (:foreground ,primary))))

   ;; === Custom widget ===
   `(custom-button ((t (:foreground ,on-surface :background ,surface-container :box (:line-width 3 :style released-button)))))
   `(custom-button-mouse ((t (:foreground ,secondary :background ,surface-container :box (:line-width 3 :style released-button)))))
   `(custom-button-pressed ((t (:foreground ,bg :background ,surface-container :box (:line-width 3 :style pressed-button)))))
   `(custom-button-pressed-unraised ((t (:foreground ,primary :background ,bg :box (:line-width 3 :style pressed-button)))))
   `(custom-button-unraised ((t (:foreground ,primary :background ,bg :box (:line-width 3 :style pressed-button)))))
   `(custom-changed ((t (:foreground ,primary :background ,bg))))
   `(custom-comment ((t (:foreground ,on-surface :background ,surface-container))))
   `(custom-comment-tag ((t (:foreground ,outline-color))))
   `(custom-documentation ((t (:foreground ,on-surface))))
   `(custom-face-tag ((t (:foreground ,primary :weight bold))))
   `(custom-group-subtitle ((t (:foreground ,secondary :weight bold))))
   `(custom-group-tag ((t (:foreground ,primary :weight bold))))
   `(custom-group-tag-1 ((t (:foreground ,primary))))
   `(custom-invalid ((t (:foreground ,err))))
   `(custom-link ((t (:foreground ,primary :underline t))))
   `(custom-modified ((t (:foreground ,primary))))
   `(custom-rogue ((t (:foreground ,primary :box (:line-width 3)))))
   `(custom-saved ((t (:foreground ,tertiary :weight bold))))
   `(custom-set ((t (:foreground ,secondary :background ,bg))))
   `(custom-state ((t (:foreground ,tertiary))))
   `(custom-themed ((t (:foreground ,secondary :background ,bg))))
   `(custom-variable-button ((t (:foreground ,tertiary :underline t))))
   `(custom-variable-obsolete ((t (:foreground ,outline-color :background ,bg))))
   `(custom-variable-tag ((t (:foreground ,primary :underline t :extend unspecified))))
   `(custom-visibility ((t (:foreground ,secondary :height 0.8 :underline t))))

   ;; === Diff ===
   `(diff-added ((t (:foreground ,on-tertiary-container :background ,tertiary-container :extend t))))
   `(diff-indicator-added ((t (:foreground ,on-tertiary-container :weight bold :background ,tertiary-container :extend t))))
   `(diff-refine-added ((t (:foreground ,on-tertiary-container :weight bold :background ,tertiary-container :extend t))))
   `(diff-changed ((t (:foreground ,on-secondary-container :background ,secondary-container :extend t))))
   `(diff-indicator-changed ((t (:foreground ,on-secondary-container :weight bold :background ,secondary-container :extend t))))
   `(diff-refine-changed ((t (:foreground ,on-secondary-container :weight bold :background ,secondary-container :extend t))))
   `(diff-removed ((t (:foreground ,on-err-container :background ,err-container :extend t))))
   `(diff-indicator-removed ((t (:foreground ,on-err-container :weight bold :background ,err-container :extend t))))
   `(diff-refine-removed ((t (:foreground ,on-err-container :weight bold :background ,err-container :extend t))))
   `(diff-header ((t (:foreground ,on-surface-variant))))
   `(diff-file-header ((t (:foreground ,primary :weight bold))))
   `(diff-hunk-header ((t (:foreground ,on-primary-container :background ,primary-container :extend t))))
   `(diff-function ((t (:foreground ,on-primary-container :background ,primary-container :extend t))))

   ;; === Diff-hl ===
   `(diff-hl-change ((t (:foreground ,secondary :background ,secondary-container))))
   `(diff-hl-delete ((t (:foreground ,err :background ,err-container))))
   `(diff-hl-insert ((t (:foreground ,tertiary :background ,tertiary-container))))

   ;; === Dired (missing faces) ===
   `(dired-mark ((t (:foreground ,secondary :weight bold))))
   `(dired-perm-write ((t (:foreground ,err :underline t))))
   `(dired-warning ((t (:foreground ,secondary))))

   ;; === Diredfl ===
   `(diredfl-autofile-name ((t (:foreground ,outline-variant))))
   `(diredfl-compressed-file-name ((t (:foreground ,primary))))
   `(diredfl-compressed-file-suffix ((t (:foreground ,secondary))))
   `(diredfl-date-time ((t (:foreground ,primary :weight light))))
   `(diredfl-deletion ((t (:foreground ,err :weight bold))))
   `(diredfl-deletion-file-name ((t (:foreground ,err))))
   `(diredfl-dir-heading ((t (:foreground ,primary :weight bold))))
   `(diredfl-dir-name ((t (:foreground ,primary))))
   `(diredfl-dir-priv ((t (:foreground ,primary))))
   `(diredfl-exec-priv ((t (:foreground ,err))))
   `(diredfl-executable-tag ((t (:foreground ,tertiary))))
   `(diredfl-file-name ((t (:foreground ,on-surface))))
   `(diredfl-file-suffix ((t (:foreground ,on-surface-variant))))
   `(diredfl-flag-mark ((t (:foreground ,on-secondary-container :background ,secondary-container :weight bold))))
   `(diredfl-flag-mark-line ((t (:background ,secondary-container))))
   `(diredfl-ignored-file-name ((t (:foreground ,outline-color))))
   `(diredfl-link-priv ((t (:foreground ,primary))))
   `(diredfl-no-priv ((t (:foreground ,on-surface))))
   `(diredfl-number ((t (:foreground ,primary))))
   `(diredfl-other-priv ((t (:foreground ,tertiary))))
   `(diredfl-rare-priv ((t (:foreground ,on-surface))))
   `(diredfl-read-priv ((t (:foreground ,secondary))))
   `(diredfl-symlink ((t (:foreground ,secondary))))
   `(diredfl-tagged-autofile-name ((t (:foreground ,outline-color))))
   `(diredfl-write-priv ((t (:foreground ,err))))

   ;; === Dired-subtree ===
   `(dired-subtree-depth-1-face ((t (:background ,surface-container-low))))
   `(dired-subtree-depth-2-face ((t (:background ,surface-container-low))))
   `(dired-subtree-depth-3-face ((t (:background ,surface-container-low))))
   `(dired-subtree-depth-4-face ((t (:background ,surface-container-low))))
   `(dired-subtree-depth-5-face ((t (:background ,surface-container-low))))
   `(dired-subtree-depth-6-face ((t (:background ,surface-container-low))))

   ;; === Dired-k ===
   `(dired-k-added ((t (:foreground ,tertiary :weight bold))))
   `(dired-k-commited ((t (:foreground ,tertiary :weight bold))))
   `(dired-k-directory ((t (:foreground ,primary :weight bold))))
   `(dired-k-ignored ((t (:foreground ,outline-color :weight bold))))
   `(dired-k-modified ((t (:foreground ,secondary :weight bold))))
   `(dired-k-untracked ((t (:foreground ,secondary :weight bold))))

   ;; === Doom-modeline ===
   `(doom-modeline-bar ((t (:foreground ,primary))))
   `(doom-modeline-buffer-major-mode ((t (:foreground ,primary))))
   `(doom-modeline-buffer-path ((t (:foreground ,primary))))
   `(doom-modeline-eldoc-bar ((t (:background ,tertiary))))
   `(doom-modeline-evil-emacs-state ((t (:foreground ,secondary :weight bold))))
   `(doom-modeline-evil-insert-state ((t (:foreground ,err :weight bold))))
   `(doom-modeline-evil-motion-state ((t (:foreground ,primary :weight bold))))
   `(doom-modeline-evil-normal-state ((t (:foreground ,tertiary :weight bold))))
   `(doom-modeline-evil-operator-state ((t (:foreground ,primary :weight bold))))
   `(doom-modeline-evil-replace-state ((t (:foreground ,secondary :weight bold))))
   `(doom-modeline-evil-visual-state ((t (:foreground ,secondary :weight bold))))
   `(doom-modeline-highlight ((t (:foreground ,primary))))
   `(doom-modeline-input-method ((t (:foreground ,primary))))
   `(doom-modeline-panel ((t (:foreground ,primary))))
   `(doom-modeline-project-dir ((t (:foreground ,primary :weight bold))))
   `(doom-modeline-project-root-dir ((t (:foreground ,primary))))

   ;; === Ediff ===
   `(ediff-current-diff-A ((t (:foreground ,on-err-container :background ,err-container :extend t))))
   `(ediff-current-diff-B ((t (:foreground ,on-tertiary-container :background ,tertiary-container :extend t))))
   `(ediff-current-diff-C ((t (:foreground ,on-secondary-container :background ,secondary-container :extend t))))
   `(ediff-even-diff-A ((t (:background ,surface-container-low :extend t))))
   `(ediff-even-diff-B ((t (:background ,surface-container-low :extend t))))
   `(ediff-even-diff-C ((t (:background ,surface-container-low :extend t))))
   `(ediff-fine-diff-A ((t (:background ,err-container :weight bold :underline t :extend t))))
   `(ediff-fine-diff-B ((t (:background ,tertiary-container :weight bold :underline t :extend t))))
   `(ediff-fine-diff-C ((t (:background ,secondary-container :weight bold :underline t :extend t))))
   `(ediff-odd-diff-A ((t (:background ,surface-container-low :extend t))))
   `(ediff-odd-diff-B ((t (:background ,surface-container-low :extend t))))
   `(ediff-odd-diff-C ((t (:background ,surface-container-low :extend t))))

   ;; === Eldoc ===
   `(eldoc-highlight-function-argument ((t (:foreground ,primary :weight bold))))

   ;; === Elfeed ===
   `(elfeed-log-debug-level-face ((t (:foreground ,outline-color))))
   `(elfeed-log-error-level-face ((t (:foreground ,err))))
   `(elfeed-log-info-level-face ((t (:foreground ,tertiary))))
   `(elfeed-log-warn-level-face ((t (:foreground ,secondary))))
   `(elfeed-search-date-face ((t (:foreground ,primary))))
   `(elfeed-search-feed-face ((t (:foreground ,primary))))
   `(elfeed-search-filter-face ((t (:foreground ,primary))))
   `(elfeed-search-tag-face ((t (:foreground ,outline-color))))
   `(elfeed-search-title-face ((t (:foreground ,outline-color))))
   `(elfeed-search-unread-count-face ((t (:foreground ,secondary))))
   `(elfeed-search-unread-title-face ((t (:foreground ,on-surface :weight bold))))

   ;; === Evil ===
   `(evil-ex-info ((t (:foreground ,err :slant italic))))
   `(evil-ex-search ((t (:background ,primary-container :foreground ,on-primary-container :weight bold))))
   `(evil-ex-substitute-matches ((t (:background ,surface-container :foreground ,err :weight bold :strike-through t))))
   `(evil-ex-substitute-replacement ((t (:background ,surface-container :foreground ,tertiary :weight bold))))
   `(evil-search-highlight-persist-highlight-face ((t (:background ,primary-container :foreground ,on-primary-container :weight bold))))

   ;; === Evil-goggles ===
   `(evil-goggles-default-face ((t (:background ,surface-container-high :distant-foreground ,bg :extend t))))

   ;; === Evil-mc ===
   `(evil-mc-cursor-bar-face ((t (:height 1 :background ,secondary :foreground ,on-secondary))))
   `(evil-mc-cursor-default-face ((t (:background ,secondary :foreground ,on-secondary :inverse-video unspecified))))
   `(evil-mc-cursor-hbar-face ((t (:underline (:color ,primary)))))
   `(evil-mc-region-face ((t (:background ,surface-container-high :distant-foreground ,bg :extend t))))

   ;; === Evil-snipe ===
   `(evil-snipe-first-match-face ((t (:foreground ,err :background ,primary-container :weight bold))))
   `(evil-snipe-matches-face ((t (:foreground ,err :underline t :weight bold))))

   ;; === Flycheck (missing) ===
   `(flycheck-error-list-filename ((t (:foreground ,primary))))
   `(flycheck-error-list-checker-name ((t (:foreground ,primary))))
   `(flycheck-error-list-warning ((t (:foreground ,secondary))))
   `(flycheck-posframe-background-face ((t (:background ,surface-container-low))))
   `(flycheck-posframe-error-face ((t (:background ,surface-container-low :foreground ,err))))
   `(flycheck-posframe-face ((t (:background ,surface-container-low :foreground ,on-surface))))
   `(flycheck-posframe-info-face ((t (:background ,surface-container-low :foreground ,tertiary))))
   `(flycheck-posframe-warning-face ((t (:background ,surface-container-low :foreground ,secondary))))

   ;; === Flymake ===
   `(flymake-error ((t (:underline (:style wave :color ,err)))))
   `(flymake-note ((t (:underline (:style wave :color ,tertiary)))))
   `(flymake-warning ((t (:underline (:style wave :color ,secondary)))))

   ;; === Flyspell ===
   `(flyspell-duplicate ((t (:underline (:style wave :color ,secondary)))))
   `(flyspell-incorrect ((t (:underline (:style wave :color ,err)))))

   ;; === Flx-ido ===
   `(flx-highlight-face ((t (:weight bold :foreground ,secondary :underline unspecified))))

   ;; === Forge ===
   `(forge-topic-closed ((t (:foreground ,outline-color :strike-through t))))
   `(forge-topic-label ((t (:box unspecified))))
   `(forge-issue-completed ((t (:foreground ,outline-color :strike-through t))))
   `(forge-pullreq-merged ((t (:foreground ,primary))))
   `(forge-pullreq-open ((t (:foreground ,tertiary))))
   `(forge-pullreq-rejected ((t (:foreground ,err :strike-through t))))

   ;; === Git-commit ===
   `(git-commit-comment-branch-local ((t (:foreground ,tertiary))))
   `(git-commit-comment-branch-remote ((t (:foreground ,tertiary))))
   `(git-commit-comment-detached ((t (:foreground ,primary))))
   `(git-commit-comment-file ((t (:foreground ,primary))))
   `(git-commit-comment-heading ((t (:foreground ,primary))))
   `(git-commit-keyword ((t (:foreground ,secondary :slant italic))))
   `(git-commit-known-pseudo-header ((t (:foreground ,outline-color :weight bold :slant italic))))
   `(git-commit-nonempty-second-line ((t (:foreground ,err))))
   `(git-commit-overlong-summary ((t (:foreground ,err :slant italic :weight bold))))
   `(git-commit-pseudo-header ((t (:foreground ,outline-color :slant italic))))
   `(git-commit-summary ((t (:foreground ,primary))))

   ;; === Git-gutter ===
   `(git-gutter:added ((t (:foreground ,tertiary))))
   `(git-gutter:deleted ((t (:foreground ,err))))
   `(git-gutter:modified ((t (:foreground ,secondary))))
   `(git-gutter+-added ((t (:foreground ,tertiary))))
   `(git-gutter+-deleted ((t (:foreground ,err))))
   `(git-gutter+-modified ((t (:foreground ,secondary))))
   `(git-gutter-fr:added ((t (:foreground ,tertiary))))
   `(git-gutter-fr:deleted ((t (:foreground ,err))))
   `(git-gutter-fr:modified ((t (:foreground ,secondary))))

   ;; === Goggles ===
   `(goggles-added ((t (:background ,tertiary-container))))
   `(goggles-changed ((t (:background ,secondary-container :distant-foreground ,bg :extend t))))
   `(goggles-removed ((t (:background ,err-container :extend t))))

   ;; === Helpful ===
   `(helpful-heading ((t (:foreground ,primary :weight bold :height 1.2))))

   ;; === Hi-lock ===
   `(hi-blue ((t (:background ,primary-container))))
   `(hi-blue-b ((t (:foreground ,primary :weight bold))))
   `(hi-green ((t (:background ,tertiary-container))))
   `(hi-green-b ((t (:foreground ,tertiary :weight bold))))
   `(hi-magenta ((t (:background ,secondary-container))))
   `(hi-red-b ((t (:foreground ,err :weight bold))))
   `(hi-yellow ((t (:background ,secondary-container))))

   ;; === Highlight-indentation ===
   `(highlight-indentation-current-column-face ((t (:background ,surface-container))))
   `(highlight-indentation-face ((t (:background ,surface-container-low :extend t))))
   `(highlight-indentation-guides-even-face ((t (:background ,surface-container-low :extend t))))
   `(highlight-indentation-guides-odd-face ((t (:background ,surface-container-low :extend t))))

   ;; === Highlight-numbers ===
   `(highlight-numbers-number ((t (:foreground ,primary :weight bold))))

   ;; === Highlight-quoted ===
   `(highlight-quoted-quote ((t (:foreground ,on-surface))))
   `(highlight-quoted-symbol ((t (:foreground ,secondary))))

   ;; === Hydra ===
   `(hydra-face-amaranth ((t (:foreground ,secondary :weight bold))))
   `(hydra-face-blue ((t (:foreground ,primary :weight bold))))
   `(hydra-face-magenta ((t (:foreground ,primary :weight bold))))
   `(hydra-face-red ((t (:foreground ,err :weight bold))))
   `(hydra-face-teal ((t (:foreground ,tertiary :weight bold))))

   ;; === Iedit ===
   `(iedit-occurrence ((t (:foreground ,on-secondary-container :weight bold :background ,secondary-container))))
   `(iedit-read-only-occurrence ((t (:background ,surface-container-high :distant-foreground ,bg :extend t))))

   ;; === Imenu-list ===
   `(imenu-list-entry-face-0 ((t (:foreground ,primary))))
   `(imenu-list-entry-face-1 ((t (:foreground ,secondary))))
   `(imenu-list-entry-face-2 ((t (:foreground ,tertiary))))
   `(imenu-list-entry-subalist-face-0 ((t (:foreground ,primary :weight bold))))
   `(imenu-list-entry-subalist-face-1 ((t (:foreground ,secondary :weight bold))))
   `(imenu-list-entry-subalist-face-2 ((t (:foreground ,tertiary :weight bold))))

   ;; === Indent-guide ===
   `(indent-guide-face ((t (:background ,surface-container-low :extend t))))

   ;; === Ivy (missing) ===
   `(ivy-confirm-face ((t (:foreground ,tertiary))))
   `(ivy-highlight-face ((t (:foreground ,primary))))
   `(ivy-match-required-face ((t (:foreground ,err))))
   `(ivy-minibuffer-match-face-1 ((t (:foreground ,primary :weight bold :underline t))))
   `(ivy-minibuffer-match-face-2 ((t (:foreground ,secondary :weight semi-bold))))
   `(ivy-minibuffer-match-face-3 ((t (:foreground ,tertiary :weight semi-bold))))
   `(ivy-minibuffer-match-face-4 ((t (:foreground ,secondary :weight semi-bold))))
   `(ivy-minibuffer-match-highlight ((t (:foreground ,primary))))
   `(ivy-modified-buffer ((t (:weight bold :foreground ,secondary))))
   `(ivy-virtual ((t (:slant italic :foreground ,on-surface))))
   `(ivy-posframe ((t (:background ,surface-container-low))))
   `(ivy-posframe-border ((t (:background ,err))))

   ;; === Keycast ===
   `(keycast-command ((t (:foreground ,err))))
   `(keycast-key ((t (:foreground ,err :weight bold))))

   ;; === LSP-UI ===
   `(lsp-headerline-breadcrumb-separator-face ((t (:foreground ,on-surface-variant))))
   `(lsp-ui-doc-background ((t (:background ,surface-container-low :foreground ,on-surface))))
   `(lsp-ui-peek-filename ((t (:weight bold))))
   `(lsp-ui-peek-header ((t (:foreground ,on-surface :background ,surface-container :weight bold))))
   `(lsp-ui-peek-highlight ((t (:background ,surface-container-high :foreground ,bg :box t))))
   `(lsp-ui-peek-line-number ((t (:foreground ,tertiary))))
   `(lsp-ui-peek-list ((t (:background ,surface-container-low))))
   `(lsp-ui-peek-peek ((t (:background ,surface-container-low))))
   `(lsp-ui-peek-selection ((t (:foreground ,on-primary-container :background ,primary-container :weight bold))))
   `(lsp-ui-sideline-code-action ((t (:foreground ,primary))))
   `(lsp-ui-sideline-current-symbol ((t (:foreground ,primary))))
   `(lsp-ui-sideline-symbol-info ((t (:foreground ,outline-color :background ,surface-container-low :extend t))))

   ;; === Magit (missing faces) ===
   `(magit-bisect-bad ((t (:foreground ,err))))
   `(magit-bisect-good ((t (:foreground ,tertiary))))
   `(magit-bisect-skip ((t (:foreground ,err))))
   `(magit-blame-date ((t (:foreground ,err))))
   `(magit-blame-heading ((t (:foreground ,primary :background ,surface-container :extend t))))
   `(magit-branch-current ((t (:foreground ,err))))
   `(magit-branch-remote-head ((t (:foreground ,tertiary))))
   `(magit-cherry-equivalent ((t (:foreground ,primary))))
   `(magit-cherry-unmatched ((t (:foreground ,secondary))))
   `(magit-diff-base ((t (:foreground ,on-secondary-container :background ,secondary-container :extend t))))
   `(magit-diff-base-highlight ((t (:foreground ,on-secondary-container :background ,secondary-container :weight bold :extend t))))
   `(magit-diff-file-heading ((t (:foreground ,on-surface :weight bold :extend t))))
   `(magit-diff-file-heading-selection ((t (:foreground ,on-secondary-container :background ,secondary-container :weight bold :extend t))))
   `(magit-diff-lines-heading ((t (:foreground ,on-primary-container :background ,primary-container :extend t))))
   `(magit-diff-revision-summary ((t (:foreground ,on-primary-container :background ,primary-container :extend t :weight bold))))
   `(magit-diffstat-added ((t (:foreground ,tertiary))))
   `(magit-diffstat-removed ((t (:foreground ,err))))
   `(magit-dimmed ((t (:foreground ,outline-color))))
   `(magit-filename ((t (:foreground ,primary))))
   `(magit-header-line ((t (:background ,surface-container-low :foreground ,primary :weight bold))))
   `(magit-log-author ((t (:foreground ,primary))))
   `(magit-log-date ((t (:foreground ,primary))))
   `(magit-log-graph ((t (:foreground ,outline-color))))
   `(magit-process-ng ((t (:foreground ,err))))
   `(magit-process-ok ((t (:foreground ,tertiary))))
   `(magit-reflog-amend ((t (:foreground ,secondary))))
   `(magit-reflog-checkout ((t (:foreground ,primary))))
   `(magit-reflog-cherry-pick ((t (:foreground ,tertiary))))
   `(magit-reflog-commit ((t (:foreground ,tertiary))))
   `(magit-reflog-merge ((t (:foreground ,tertiary))))
   `(magit-reflog-other ((t (:foreground ,secondary))))
   `(magit-reflog-rebase ((t (:foreground ,secondary))))
   `(magit-reflog-remote ((t (:foreground ,secondary))))
   `(magit-reflog-reset ((t (:foreground ,err))))
   `(magit-refname ((t (:foreground ,outline-color))))
   `(magit-section-heading ((t (:foreground ,primary :weight bold :extend t))))
   `(magit-section-heading-selection ((t (:foreground ,primary :weight bold :extend t))))
   `(magit-section-secondary-heading ((t (:foreground ,primary :weight bold :extend t))))
   `(magit-sequence-drop ((t (:foreground ,err))))
   `(magit-sequence-head ((t (:foreground ,primary))))
   `(magit-sequence-part ((t (:foreground ,primary))))
   `(magit-sequence-stop ((t (:foreground ,tertiary))))
   `(magit-signature-bad ((t (:foreground ,err))))
   `(magit-signature-error ((t (:foreground ,err))))
   `(magit-signature-expired ((t (:foreground ,secondary))))
   `(magit-signature-good ((t (:foreground ,tertiary))))
   `(magit-signature-revoked ((t (:foreground ,secondary))))
   `(magit-signature-untrusted ((t (:foreground ,secondary))))
   `(magit-tag ((t (:foreground ,secondary))))

   ;; === Make-mode ===
   `(makefile-targets ((t (:foreground ,primary))))

   ;; === Marginalia (missing) ===
   `(marginalia-documentation ((t (:foreground ,primary))))
   `(marginalia-file-name ((t (:foreground ,primary))))
   `(marginalia-size ((t (:foreground ,secondary))))
   `(marginalia-mode ((t (:foreground ,primary))))
   `(marginalia-modified ((t (:foreground ,err))))
   `(marginalia-file-priv-read ((t (:foreground ,tertiary))))
   `(marginalia-file-priv-write ((t (:foreground ,secondary))))
   `(marginalia-file-priv-exec ((t (:foreground ,err))))

   ;; === Markdown (missing faces) ===
   `(markdown-blockquote-face ((t (:foreground ,outline-color :slant italic))))
   `(markdown-bold-face ((t (:foreground ,on-surface :weight bold))))
   `(markdown-header-delimiter-face ((t (:foreground ,primary :weight bold))))
   `(markdown-header-face-5 ((t (:foreground ,primary-variant :weight bold))))
   `(markdown-header-face-6 ((t (:foreground ,secondary-variant :weight bold))))
   `(markdown-html-attr-name-face ((t (:foreground ,primary))))
   `(markdown-html-attr-value-face ((t (:foreground ,tertiary))))
   `(markdown-html-entity-face ((t (:foreground ,primary :slant italic))))
   `(markdown-html-tag-delimiter-face ((t (:foreground ,on-surface))))
   `(markdown-html-tag-name-face ((t (:foreground ,secondary))))
   `(markdown-italic-face ((t (:foreground ,primary :slant italic))))
   `(markdown-link-face ((t (:foreground ,primary :weight bold))))
   `(markdown-list-face ((t (:foreground ,primary))))
   `(markdown-markup-face ((t (:foreground ,on-surface))))
   `(markdown-metadata-key-face ((t (:foreground ,primary))))
   `(markdown-reference-face ((t (:foreground ,outline-color))))
   `(markdown-url-face ((t (:foreground ,tertiary))))

   ;; === Message ===
   `(message-cited-text-1 ((t (:foreground ,secondary))))
   `(message-cited-text-2 ((t (:foreground ,primary))))
   `(message-cited-text-3 ((t (:foreground ,tertiary))))
   `(message-header-cc ((t (:foreground ,err :weight bold))))
   `(message-header-name ((t (:foreground ,err))))
   `(message-header-newsgroups ((t (:foreground ,secondary))))
   `(message-header-other ((t (:foreground ,primary))))
   `(message-header-subject ((t (:foreground ,primary :weight bold))))
   `(message-header-to ((t (:foreground ,primary :weight bold))))
   `(message-header-xheader ((t (:foreground ,outline-color))))
   `(message-mml ((t (:foreground ,outline-color :slant italic))))
   `(message-separator ((t (:foreground ,outline-color))))

   ;; === Minimap ===
   `(minimap-active-region-background ((t (:background ,surface-container-low))))
   `(minimap-current-line-face ((t (:background ,surface-container-high))))

   ;; === Multiple-cursors ===
   `(mc/cursor-face ((t (:background ,secondary))))

   ;; === Neotree ===
   `(neo-dir-link-face ((t (:foreground ,primary))))
   `(neo-expand-btn-face ((t (:foreground ,primary))))
   `(neo-file-link-face ((t (:foreground ,on-surface))))
   `(neo-root-dir-face ((t (:foreground ,tertiary :background ,bg))))
   `(neo-vc-added-face ((t (:foreground ,tertiary))))
   `(neo-vc-conflict-face ((t (:foreground ,secondary :weight bold))))
   `(neo-vc-edited-face ((t (:foreground ,secondary))))
   `(neo-vc-ignored-face ((t (:foreground ,outline-color))))
   `(neo-vc-removed-face ((t (:foreground ,err :strike-through t))))

   ;; === Notmuch ===
   `(notmuch-message-summary-face ((t (:foreground ,outline-color))))
   `(notmuch-search-count ((t (:foreground ,outline-color))))
   `(notmuch-search-date ((t (:foreground ,primary))))
   `(notmuch-search-flagged-face ((t (:foreground ,err))))
   `(notmuch-search-matching-authors ((t (:foreground ,primary))))
   `(notmuch-search-non-matching-authors ((t (:foreground ,on-surface))))
   `(notmuch-search-subject ((t (:foreground ,on-surface))))
   `(notmuch-search-unread-face ((t (:weight bold))))
   `(notmuch-tag-added ((t (:foreground ,tertiary :weight normal))))
   `(notmuch-tag-deleted ((t (:foreground ,err :weight normal))))
   `(notmuch-tag-face ((t (:foreground ,secondary :weight normal))))
   `(notmuch-tag-flagged ((t (:foreground ,secondary :weight normal))))
   `(notmuch-tag-unread ((t (:foreground ,secondary :weight normal))))
   `(notmuch-tree-match-author-face ((t (:foreground ,primary :weight bold))))
   `(notmuch-tree-match-date-face ((t (:foreground ,primary :weight bold))))
   `(notmuch-tree-match-face ((t (:foreground ,on-surface))))
   `(notmuch-tree-match-subject-face ((t (:foreground ,on-surface))))
   `(notmuch-tree-match-tag-face ((t (:foreground ,secondary))))
   `(notmuch-tree-match-tree-face ((t (:foreground ,outline-color))))
   `(notmuch-tree-no-match-author-face ((t (:foreground ,primary))))
   `(notmuch-tree-no-match-date-face ((t (:foreground ,primary))))
   `(notmuch-tree-no-match-face ((t (:foreground ,outline-color))))
   `(notmuch-tree-no-match-subject-face ((t (:foreground ,outline-color))))
   `(notmuch-tree-no-match-tag-face ((t (:foreground ,secondary))))
   `(notmuch-tree-no-match-tree-face ((t (:foreground ,secondary))))
   `(notmuch-wash-cited-text ((t (:foreground ,outline-variant))))
   `(notmuch-wash-toggle-button ((t (:foreground ,on-surface))))

   ;; === Orderless ===
   `(orderless-match-face-0 ((t (:foreground ,primary :weight bold :underline t))))
   `(orderless-match-face-1 ((t (:foreground ,secondary :weight bold :underline t))))
   `(orderless-match-face-2 ((t (:foreground ,tertiary :weight bold :underline t))))
   `(orderless-match-face-3 ((t (:foreground ,primary-variant :weight bold :underline t))))

   ;; === Objed ===
   `(objed-hl ((t (:background ,surface-container-high :distant-foreground ,bg :extend t))))
   `(objed-mode-line ((t (:foreground ,secondary :weight bold))))

   ;; === Parenface ===
   `(paren-face ((t (:foreground ,outline-color))))

   ;; === Popup ===
   `(popup-face ((t (:background ,surface-container-low :foreground ,on-surface))))
   `(popup-selection-face ((t (:background ,primary-container :foreground ,on-primary-container))))
   `(popup-tip-face ((t (:foreground ,primary :background ,surface-container))))

   ;; === Re-builder ===
   `(reb-match-0 ((t (:foreground ,err :inverse-video t))))
   `(reb-match-1 ((t (:foreground ,tertiary :inverse-video t))))
   `(reb-match-2 ((t (:foreground ,secondary :inverse-video t))))
   `(reb-match-3 ((t (:foreground ,primary :inverse-video t))))

   ;; === Selectrum ===
   `(selectrum-current-candidate ((t (:background ,surface-container-high :distant-foreground unspecified :extend t))))

   ;; === Sh-script ===
   `(sh-heredoc ((t (:foreground ,primary))))
   `(sh-quoted-exec ((t (:foreground ,on-surface :weight bold))))

   ;; === Smerge ===
   `(smerge-base ((t (:background ,primary-container :foreground ,on-primary-container))))
   `(smerge-lower ((t (:background ,tertiary-container))))
   `(smerge-markers ((t (:background ,surface-container-high :foreground ,bg :distant-foreground ,on-surface :weight bold))))
   `(smerge-mine ((t (:background ,err-container :foreground ,on-err-container))))
   `(smerge-other ((t (:background ,tertiary-container :foreground ,on-tertiary-container))))
   `(smerge-refined-added ((t (:background ,tertiary-container :foreground ,on-tertiary-container))))
   `(smerge-refined-removed ((t (:background ,err-container :foreground ,on-err-container))))
   `(smerge-upper ((t (:background ,err-container))))

   ;; === Solaire-mode ===
   `(solaire-default-face ((t (:background ,surface-container-low))))
   `(solaire-hl-line-face ((t (:background ,surface-container-low :extend t))))
   `(solaire-mode-line-face ((t (:background ,surface-container-high :foreground ,on-surface))))
   `(solaire-mode-line-inactive-face ((t (:background ,surface-container-low :foreground ,on-surface-variant))))
   `(solaire-org-hide-face ((t (:foreground ,bg))))

   ;; === Swiper ===
   `(swiper-line-face ((t (:background ,primary-container :foreground ,on-primary-container))))
   `(swiper-match-face-1 ((t (:background ,surface-container :foreground ,outline-color))))
   `(swiper-match-face-2 ((t (:background ,primary-container :foreground ,on-primary-container :weight bold))))
   `(swiper-match-face-3 ((t (:background ,secondary-container :foreground ,on-secondary-container :weight bold))))
   `(swiper-match-face-4 ((t (:background ,tertiary-container :foreground ,on-tertiary-container :weight bold))))

   ;; === Term (extended) ===
   `(term ((t (:foreground ,on-surface))))
   `(term-bold ((t (:weight bold))))
   `(term-color-bright-black ((t (:foreground ,surface-container-high))))
   `(term-color-bright-red ((t (:foreground ,err-variant))))
   `(term-color-bright-green ((t (:foreground ,tertiary-variant))))
   `(term-color-bright-yellow ((t (:foreground ,secondary-variant))))
   `(term-color-bright-blue ((t (:foreground ,primary-variant))))
   `(term-color-bright-magenta ((t (:foreground ,err))))
   `(term-color-bright-cyan ((t (:foreground ,tertiary))))
   `(term-color-bright-white ((t (:foreground ,fg))))

   ;; === Transient ===
   `(transient-key ((t (:foreground ,primary :height 1.1))))
   `(transient-blue ((t (:foreground ,primary))))
   `(transient-pink ((t (:foreground ,primary))))
   `(transient-purple ((t (:foreground ,secondary))))
   `(transient-red ((t (:foreground ,err))))
   `(transient-teal ((t (:foreground ,tertiary))))

   ;; === Treemacs ===
   `(treemacs-directory-face ((t (:foreground ,on-surface))))
   `(treemacs-file-face ((t (:foreground ,on-surface))))
   `(treemacs-git-added-face ((t (:foreground ,tertiary))))
   `(treemacs-git-conflict-face ((t (:foreground ,err))))
   `(treemacs-git-modified-face ((t (:foreground ,primary))))
   `(treemacs-git-untracked-face ((t (:foreground ,outline-color))))
   `(treemacs-root-face ((t (:foreground ,primary :weight bold :height 1.2))))
   `(treemacs-tags-face ((t (:foreground ,err))))

   ;; === Tree-sitter-hl ===
   `(tree-sitter-hl-face:function ((t (:foreground ,primary))))
   `(tree-sitter-hl-face:function.call ((t (:foreground ,primary))))
   `(tree-sitter-hl-face:function.builtin ((t (:foreground ,err))))
   `(tree-sitter-hl-face:function.special ((t (:foreground ,on-surface :weight bold))))
   `(tree-sitter-hl-face:function.macro ((t (:foreground ,on-surface :weight bold))))
   `(tree-sitter-hl-face:method ((t (:foreground ,secondary))))
   `(tree-sitter-hl-face:method.call ((t (:foreground ,secondary))))
   `(tree-sitter-hl-face:type ((t (:foreground ,primary))))
   `(tree-sitter-hl-face:type.parameter ((t (:foreground ,on-surface-variant))))
   `(tree-sitter-hl-face:type.argument ((t (:foreground ,primary))))
   `(tree-sitter-hl-face:type.builtin ((t (:foreground ,err))))
   `(tree-sitter-hl-face:type.super ((t (:foreground ,primary))))
   `(tree-sitter-hl-face:constructor ((t (:foreground ,primary))))
   `(tree-sitter-hl-face:variable ((t (:foreground ,on-surface))))
   `(tree-sitter-hl-face:variable.parameter ((t (:foreground ,on-surface-variant))))
   `(tree-sitter-hl-face:variable.builtin ((t (:foreground ,err))))
   `(tree-sitter-hl-face:variable.special ((t (:foreground ,primary))))
   `(tree-sitter-hl-face:property ((t (:foreground ,primary))))
   `(tree-sitter-hl-face:property.definition ((t (:foreground ,on-surface-variant))))
   `(tree-sitter-hl-face:comment ((t (:foreground ,outline-color :slant italic))))
   `(tree-sitter-hl-face:doc ((t (:foreground ,on-surface-variant :slant italic))))
   `(tree-sitter-hl-face:string ((t (:foreground ,tertiary))))
   `(tree-sitter-hl-face:string.special ((t (:foreground ,tertiary))))
   `(tree-sitter-hl-face:escape ((t (:foreground ,err))))
   `(tree-sitter-hl-face:embedded ((t (:foreground ,on-surface))))
   `(tree-sitter-hl-face:keyword ((t (:foreground ,secondary :weight bold))))
   `(tree-sitter-hl-face:operator ((t (:foreground ,secondary))))
   `(tree-sitter-hl-face:label ((t (:foreground ,on-surface))))
   `(tree-sitter-hl-face:constant ((t (:foreground ,tertiary :weight bold))))
   `(tree-sitter-hl-face:constant.builtin ((t (:foreground ,err))))
   `(tree-sitter-hl-face:number ((t (:foreground ,primary))))
   `(tree-sitter-hl-face:punctuation ((t (:foreground ,on-surface))))
   `(tree-sitter-hl-face:punctuation.bracket ((t (:foreground ,on-surface))))
   `(tree-sitter-hl-face:punctuation.delimiter ((t (:foreground ,on-surface))))
   `(tree-sitter-hl-face:punctuation.special ((t (:foreground ,err))))
   `(tree-sitter-hl-face:tag ((t (:foreground ,err))))
   `(tree-sitter-hl-face:attribute ((t (:foreground ,on-surface))))

   ;; === Typescript-mode ===
   `(typescript-jsdoc-tag ((t (:foreground ,outline-color))))
   `(typescript-jsdoc-type ((t (:foreground ,outline-color))))
   `(typescript-jsdoc-value ((t (:foreground ,outline-color))))

   ;; === Undo-tree ===
   `(undo-tree-visualizer-active-branch-face ((t (:foreground ,primary))))
   `(undo-tree-visualizer-current-face ((t (:foreground ,tertiary :weight bold))))
   `(undo-tree-visualizer-default-face ((t (:foreground ,outline-color))))
   `(undo-tree-visualizer-register-face ((t (:foreground ,secondary))))
   `(undo-tree-visualizer-unmodified-face ((t (:foreground ,outline-color))))

   ;; === Volatile-highlights ===
   `(vhl/default-face ((t (:background ,surface-container-high))))

   ;; === Vterm ===
   `(vterm ((t (:foreground ,on-surface))))
   `(vterm-color-black ((t (:background ,surface-container-lowest :foreground ,surface-container-lowest))))
   `(vterm-color-blue ((t (:background ,primary :foreground ,primary))))
   `(vterm-color-cyan ((t (:background ,primary-variant :foreground ,primary-variant))))
   `(vterm-color-default ((t (:background ,on-surface :foreground ,on-surface))))
   `(vterm-color-green ((t (:background ,tertiary :foreground ,tertiary))))
   `(vterm-color-magenta ((t (:background ,err-variant :foreground ,err-variant))))
   `(vterm-color-purple ((t (:background ,primary :foreground ,primary))))
   `(vterm-color-red ((t (:background ,err :foreground ,err))))
   `(vterm-color-white ((t (:background ,on-surface :foreground ,on-surface))))
   `(vterm-color-yellow ((t (:background ,secondary :foreground ,secondary))))

   ;; === Web-mode (missing faces) ===
   `(web-mode-block-control-face ((t (:foreground ,err))))
   `(web-mode-block-delimiter-face ((t (:foreground ,err))))
   `(web-mode-doctype-face ((t (:foreground ,outline-color))))
   `(web-mode-html-entity-face ((t (:foreground ,secondary :slant italic))))
   `(web-mode-json-context-face ((t (:foreground ,tertiary))))
   `(web-mode-json-key-face ((t (:foreground ,tertiary))))
   `(web-mode-keyword-face ((t (:foreground ,primary))))
   `(web-mode-string-face ((t (:foreground ,tertiary))))
   `(web-mode-type-face ((t (:foreground ,primary))))

   ;; === Wgrep ===
   `(wgrep-delete-face ((t (:foreground ,on-err-container :background ,err-container))))
   `(wgrep-done-face ((t (:foreground ,tertiary))))
   `(wgrep-face ((t (:weight bold :foreground ,on-tertiary-container :background ,tertiary-container))))
   `(wgrep-file-face ((t (:foreground ,outline-color))))
   `(wgrep-reject-face ((t (:foreground ,err :weight bold))))

   ;; === Which-func ===
   `(which-func ((t (:foreground ,primary))))

   ;; === Which-key (missing) ===
   `(which-key-local-map-description-face ((t (:foreground ,secondary))))

   ;; === Whitespace ===
   `(whitespace-empty ((t (:background ,surface-container))))
   `(whitespace-indentation ((t (:foreground ,outline-variant :background ,surface-container))))
   `(whitespace-line ((t (:background ,surface-container-low :foreground ,err :weight bold))))
   `(whitespace-newline ((t (:foreground ,outline-variant))))
   `(whitespace-space ((t (:foreground ,outline-variant))))
   `(whitespace-tab ((t (:foreground ,outline-variant :background ,surface-container))))
   `(whitespace-trailing ((t (:background ,err-container))))

   ;; === Widget ===
   `(widget-button ((t (:foreground ,on-surface :weight bold))))
   `(widget-button-pressed ((t (:foreground ,err))))
   `(widget-documentation ((t (:foreground ,tertiary))))
   `(widget-field ((t (:foreground ,on-surface :background ,surface-container-lowest :extend unspecified))))
   `(widget-inactive ((t (:foreground ,outline-color :background ,surface-container-low))))
   `(widget-single-line-field ((t (:foreground ,on-surface :background ,surface-container-lowest))))

   ;; === Woman ===
   `(woman-bold ((t (:foreground ,on-surface :weight bold))))
   `(woman-italic ((t (:foreground ,primary :underline ,primary))))

   ;; === Yasnippet ===
   `(yas-field-highlight-face ((t (:foreground ,on-tertiary-container :background ,tertiary-container :weight bold))))

   ;; === Mu4e ===
   `(mu4e-forwarded-face ((t (:foreground ,primary))))
   `(mu4e-header-key-face ((t (:foreground ,primary :weight bold))))
   `(mu4e-header-title-face ((t (:foreground ,primary))))
   `(mu4e-highlight-face ((t (:foreground ,primary :weight bold))))
   `(mu4e-link-face ((t (:foreground ,primary :underline t))))
   `(mu4e-replied-face ((t (:foreground ,tertiary))))
   `(mu4e-title-face ((t (:foreground ,primary :weight bold))))
   `(mu4e-unread-face ((t (:foreground ,primary :weight bold))))
   `(mu4e-column-faces-date ((t (:foreground ,primary))))
   `(mu4e-column-faces-flags ((t (:foreground ,secondary))))
   `(mu4e-column-faces-to-from ((t (:foreground ,primary))))

   ;; === ERC ===
   `(erc-action-face ((t (:weight bold))))
   `(erc-button ((t (:weight bold :underline t))))
   `(erc-command-indicator-face ((t (:weight bold))))
   `(erc-current-nick-face ((t (:foreground ,tertiary :weight bold))))
   `(erc-default-face ((t (:background ,bg :foreground ,on-surface))))
   `(erc-direct-msg-face ((t (:foreground ,secondary))))
   `(erc-error-face ((t (:foreground ,err))))
   `(erc-header-line ((t (:background ,surface-container-low :foreground ,primary))))
   `(erc-input-face ((t (:foreground ,tertiary))))
   `(erc-my-nick-face ((t (:foreground ,tertiary :weight bold))))
   `(erc-my-nick-prefix-face ((t (:foreground ,tertiary :weight bold))))
   `(erc-nick-default-face ((t (:weight bold))))
   `(erc-nick-msg-face ((t (:foreground ,secondary))))
   `(erc-nick-prefix-face ((t (:background ,bg :foreground ,on-surface))))
   `(erc-notice-face ((t (:foreground ,outline-color))))
   `(erc-prompt-face ((t (:foreground ,primary :weight bold))))
   `(erc-timestamp-face ((t (:foreground ,primary :weight bold))))

   ;; === Nano-modeline ===
   `(nano-modeline-active-name ((t (:foreground ,on-surface :weight bold))))
   `(nano-modeline-inactive-name ((t (:foreground ,on-surface-variant :weight bold))))
   `(nano-modeline-active-primary ((t (:foreground ,primary))))
   `(nano-modeline-inactive-primary ((t (:foreground ,on-surface-variant))))
   `(nano-modeline-active-secondary ((t (:foreground ,primary :weight bold))))
   `(nano-modeline-inactive-secondary ((t (:foreground ,on-surface-variant :weight bold))))
   `(nano-modeline-active-status-RO ((t (:background ,secondary-container :foreground ,on-secondary-container :weight bold))))
   `(nano-modeline-inactive-status-RO ((t (:background ,surface-container :foreground ,on-surface-variant :weight bold))))
   `(nano-modeline-active-status-RW ((t (:background ,primary-container :foreground ,on-primary-container :weight bold))))
   `(nano-modeline-inactive-status-RW ((t (:background ,surface-container :foreground ,on-surface-variant :weight bold))))
   `(nano-modeline-active-status-** ((t (:background ,err-container :foreground ,on-err-container :weight bold))))
   `(nano-modeline-inactive-status-** ((t (:background ,surface-container :foreground ,on-surface-variant :weight bold))))

   ;; === Tab-line (missing) ===
   `(tab-line-close-highlight ((t (:foreground ,err))))

   ;; === Centaur-tabs (missing) ===
   `(centaur-tabs-close-mouse-face ((t (:foreground ,primary))))
   `(centaur-tabs-close-selected ((t (:background ,surface-container-high :foreground ,on-surface))))
   `(centaur-tabs-close-unselected ((t (:background ,surface-container-low :foreground ,outline-color))))
   `(centaur-tabs-modified-marker-selected ((t (:background ,surface-container-high :foreground ,primary))))
   `(centaur-tabs-modified-marker-unselected ((t (:background ,surface-container-low :foreground ,primary))))
   `(centaur-tabs-name-mouse-face ((t (:foreground ,primary :weight bold :underline t))))
   `(centaur-tabs-unselected-modified ((t (:background ,surface-container-low :foreground ,primary))))

   ;; === Powerline ===
   `(powerline-active0 ((t (:background ,surface-container-high :foreground ,on-surface))))
   `(powerline-active1 ((t (:background ,surface-container-high :foreground ,on-surface))))
   `(powerline-active2 ((t (:background ,surface-container-high :foreground ,on-surface))))
   `(powerline-inactive0 ((t (:background ,surface-container-low :foreground ,on-surface-variant))))
   `(powerline-inactive1 ((t (:background ,surface-container-low :foreground ,on-surface-variant))))
   `(powerline-inactive2 ((t (:background ,surface-container-low :foreground ,on-surface-variant))))

   ;; === Spaceline ===
   `(spaceline-evil-emacs ((t (:background ,secondary))))
   `(spaceline-evil-insert ((t (:background ,tertiary))))
   `(spaceline-evil-motion ((t (:background ,secondary))))
   `(spaceline-evil-normal ((t (:background ,primary))))
   `(spaceline-evil-replace ((t (:background ,err))))
   `(spaceline-evil-visual ((t (:background ,surface-container-high))))
   `(spaceline-flycheck-error ((t (:foreground ,err))))
   `(spaceline-flycheck-info ((t (:foreground ,tertiary))))
   `(spaceline-flycheck-warning ((t (:foreground ,secondary))))

   ;; === Smart-mode-line ===
   `(sml/charging ((t (:foreground ,tertiary))))
   `(sml/discharging ((t (:foreground ,secondary :weight bold))))
   `(sml/filename ((t (:foreground ,primary :weight bold))))
   `(sml/git ((t (:foreground ,primary))))
   `(sml/modified ((t (:foreground ,secondary))))
   `(sml/outside-modified ((t (:foreground ,secondary))))
   `(sml/process ((t (:weight bold))))
   `(sml/read-only ((t (:foreground ,secondary))))
   `(sml/sudo ((t (:foreground ,err :weight bold))))
   `(sml/vc-edited ((t (:foreground ,tertiary))))

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
