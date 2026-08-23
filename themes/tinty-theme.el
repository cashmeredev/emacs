;;; tinty-theme.el --- Noctalia theme for Emacs -*- lexical-binding: t -*-


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

(defgroup tinty nil
  "Tinty theme."
  :group 'faces
  :prefix "tinty-"
  :tag "Tinty")

(defcustom tinty-scale-headings t
  "Whether to scale document and outline headings."
  :type 'boolean
  :group 'tinty)

(defcustom tinty-height-document-title 1.4
  "Height multiplier for document titles."
  :type 'number
  :group 'tinty)

(defcustom tinty-height-1 1.3
  "Height multiplier for level-one headings."
  :type 'number
  :group 'tinty)

(defcustom tinty-height-2 1.2
  "Height multiplier for level-two headings."
  :type 'number
  :group 'tinty)

(defcustom tinty-height-3 1.1
  "Height multiplier for level-three headings."
  :type 'number
  :group 'tinty)

(defcustom tinty-italic-comments t
  "Whether to render comments in italic."
  :type 'boolean
  :group 'tinty)

(defcustom tinty-flat-mode-line nil
  "Whether to render the mode line without a surrounding box."
  :type 'boolean
  :group 'tinty)

(defcustom tinty-use-variable-pitch nil
  "Whether to render headings in a variable-pitch font."
  :type 'boolean
  :group 'tinty)

(deftheme tinty "Noctalia theme with proper color contrast.")

(let* (;; Tinted8 UI surface colors
       (ui-bg "#282a36")
       (ui-fg "#f8f8f2")
       (ui-fg-dim "#6272a4")
       ;; Use dim foreground for borders/muted chrome so they stay visible in
       ;; light variants (the raw border color is nearly white on latte).
       (ui-border "#6272a4")
       (ui-line-highlight "#353747")
       (ui-bg-dark "#191a21")
       (ui-bg-light "#343746")

       ;; Tinted8 UI accent/status colors
       (ui-accent "#bd93f9")
       (ui-link "#8be9fd")
       (ui-info "#8be9fd")
       (ui-error "#ff5555")
       (ui-success "#50fa7b")
       (ui-warning "#ffb86c")

       ;; Tinted8 UI container colors (for BACKGROUNDS only)
       (ui-selection-bg "#44475a")
       (ui-selection-fg "#f8f8f2")
       (ui-button-bg "#343746")
       (ui-button-fg "#f8f8f2")
       (ui-tooltip-bg "#343746")
       (ui-tooltip-fg "#f8f8f2")
       (ui-active-text-bg "#44475a")
       (ui-active-text-fg "#ffffff")
       (ui-search-bg "#ffb86c")
       (ui-search-fg "#282a36")

       ;; Tinted8 syntax colors
       ;; Comments use dim foreground instead of the raw syntax-comment gray,
       ;; which becomes almost invisible in light variants.
       (syntax-comment "#6272a4")
       (syntax-constant "#ffb86c")
       (syntax-function "#50fa7b")
       (syntax-keyword "#ff79c6")
       (syntax-string "#f1fa8c")
       (syntax-type "#8be9fd")
       ;; Give variables/imported names a distinct hue instead of blending into
       ;; the default foreground.
       (syntax-variable "#f8f8f2")
       (syntax-warning "#ff6e6e")
       (syntax-preprocessor "#9954fb")
       (syntax-annotation "#f1fa8c")
       (syntax-attribute "#8be9fd")
       (syntax-number "#ffb86c")
       (syntax-operator "#8be9fd")

       ;; Raw palette colors for rainbow headings, delimiters, terminal faces,
       ;; and anywhere else we need a predictable hue cycle.
       (pal-red "#ff5555")
       (pal-orange "#ffb86c")
       (pal-yellow "#f1fa8c")
       (pal-green "#50fa7b")
       (pal-cyan "#8be9fd")
       (pal-blue "#bd93f9")
       (pal-magenta "#ff79c6")
       (pal-gray "#6272a4")
       (pal-white "#f8f8f2")
       (pal-black "#21222c")
       (h1 (if tinty-scale-headings tinty-height-1 1.0))
       (h2 (if tinty-scale-headings tinty-height-2 1.0))
       (h3 (if tinty-scale-headings tinty-height-3 1.0))
       (h-doc (if tinty-scale-headings tinty-height-document-title 1.0))
       (comment-slant (if tinty-italic-comments 'italic 'normal))
       (mode-line-box (unless tinty-flat-mode-line
                        (list :line-width -1 :color ui-border)))
       (vpitch (if tinty-use-variable-pitch 'variable-pitch 'default)))

  (custom-theme-set-faces
   'tinty

   ;; === Basic faces ===
   `(default ((t (:background ,ui-bg :foreground ,ui-fg))))
   `(cursor ((t (:background ,ui-accent))))
   `(highlight ((t (:background ,ui-bg-light))))
   `(region ((t (:background ,ui-selection-bg :foreground ,ui-selection-fg :extend t))))
   `(secondary-selection ((t (:background ,ui-button-bg :foreground ,ui-button-fg :extend t))))
   `(isearch ((t (:background ,ui-search-bg :foreground ,ui-search-fg :weight bold))))
   `(lazy-highlight ((t (:background ,ui-button-bg :foreground ,ui-button-fg))))
   `(vertical-border ((t (:foreground ,ui-border))))
   `(border ((t (:background ,ui-border :foreground ,ui-border))))
   `(fringe ((t (:background ,ui-bg :foreground ,ui-border))))
   `(shadow ((t (:foreground ,ui-border))))
   `(link ((t (:foreground ,ui-link :underline t))))
   `(link-visited ((t (:foreground ,ui-info :underline t))))
   `(button ((t (:foreground ,ui-link :underline t))))
   `(success ((t (:foreground ,ui-success))))
   `(warning ((t (:foreground ,ui-warning))))
   `(error ((t (:foreground ,ui-error))))
   `(match ((t (:background ,ui-search-bg :foreground ,ui-search-fg :weight bold))))
   `(escape-glyph ((t (:foreground ,syntax-keyword))))
   `(homoglyph ((t (:foreground ,syntax-keyword))))
   `(fill-column-indicator ((t (:foreground ,ui-bg-light :weight normal))))
   `(minibuffer-nonselected ((t (:foreground ,ui-fg-dim :background ,ui-bg))))

   ;; === Font-lock (driven by Tinted8 syntax properties) ===
   `(font-lock-builtin-face ((t (:foreground ,syntax-constant))))
   `(font-lock-comment-face ((t (:foreground ,syntax-comment :slant ,comment-slant))))
   `(font-lock-comment-delimiter-face ((t (:foreground ,syntax-comment :slant ,comment-slant))))
   `(font-lock-constant-face ((t (:foreground ,syntax-constant :weight bold))))
   `(font-lock-doc-face ((t (:foreground ,syntax-comment :slant ,comment-slant))))
   `(font-lock-doc-markup-face ((t (:foreground ,syntax-annotation))))
   `(font-lock-function-name-face ((t (:foreground ,syntax-function :weight bold))))
   `(font-lock-function-call-face ((t (:foreground ,syntax-function))))
   `(font-lock-keyword-face ((t (:foreground ,syntax-keyword :weight bold))))
   `(font-lock-string-face ((t (:foreground ,syntax-string))))
   `(font-lock-type-face ((t (:foreground ,syntax-type))))
   `(font-lock-variable-name-face ((t (:foreground ,syntax-variable))))
   `(font-lock-variable-use-face ((t (:foreground ,ui-fg))))
   `(font-lock-warning-face ((t (:foreground ,syntax-warning :weight bold))))
   `(font-lock-preprocessor-face ((t (:foreground ,syntax-preprocessor))))
   `(font-lock-preprocessor-char-face ((t (:foreground ,syntax-keyword :weight bold))))
   `(font-lock-negation-char-face ((t (:foreground ,syntax-constant))))
   `(font-lock-number-face ((t (:foreground ,syntax-number :weight bold))))
   `(font-lock-operator-face ((t (:foreground ,syntax-operator))))
   `(font-lock-property-name-face ((t (:foreground ,syntax-attribute))))
   `(font-lock-property-use-face ((t (:foreground ,syntax-attribute))))
   `(font-lock-bracket-face ((t (:foreground ,ui-fg-dim))))
   `(font-lock-delimiter-face ((t (:foreground ,ui-fg-dim))))
   `(font-lock-escape-face ((t (:foreground ,syntax-keyword))))
   `(font-lock-misc-punctuation-face ((t (:foreground ,ui-fg-dim))))
   `(font-lock-regexp-grouping-backslash ((t (:foreground ,syntax-keyword :weight bold))))
   `(font-lock-regexp-grouping-construct ((t (:foreground ,syntax-function :weight bold))))

   ;; === Show paren ===
   `(show-paren-match ((t (:background ,ui-bg-light :foreground ,ui-accent :weight bold))))
   `(show-paren-match-expression ((t (:background ,ui-button-bg))))
   `(show-paren-mismatch ((t (:background ,ui-active-text-bg :foreground ,ui-error :weight bold :underline t))))

   ;; === Mode line ===
   `(mode-line ((t (:background ,ui-line-highlight :foreground ,ui-fg :box ,mode-line-box))))
   `(mode-line-inactive ((t (:background ,ui-bg-dark :foreground ,ui-fg-dim :box ,mode-line-box))))
   `(mode-line-buffer-id ((t (:foreground ,ui-accent :weight bold))))
   `(mode-line-emphasis ((t (:foreground ,ui-fg :weight bold))))
   `(mode-line-highlight ((t (:foreground ,ui-accent :box nil))))

   ;; === Org source blocks ===
   `(org-block ((t (:background ,ui-bg-dark :extend t :inherit fixed-pitch))))
   `(org-block-begin-line ((t (:background ,ui-bg-dark :foreground ,ui-border :extend t :slant italic :inherit fixed-pitch))))  ;; FIX: was primary_fixed_dim
   `(org-block-end-line ((t (:background ,ui-bg-dark :foreground ,ui-border :extend t :slant italic :inherit fixed-pitch))))    ;; FIX: was primary_fixed_dim
   `(org-code ((t (:background ,ui-bg-dark :foreground ,ui-info :inherit fixed-pitch))))
   `(org-verbatim ((t (:background ,ui-bg-dark :foreground ,ui-accent :inherit fixed-pitch))))
   `(org-meta-line ((t (:foreground ,ui-border :slant italic))))

   ;; === Org headings - rainbow cycle across the available palette ===
   `(org-level-1 ((t (:inherit ,vpitch :foreground ,ui-accent :weight bold :height ,h1))))
   `(org-level-2 ((t (:inherit ,vpitch :foreground ,pal-orange :weight bold :height ,h2))))
   `(org-level-3 ((t (:inherit ,vpitch :foreground ,pal-yellow :weight bold :height ,h3))))
   `(org-level-4 ((t (:inherit ,vpitch :foreground ,pal-green :weight bold))))
   `(org-level-5 ((t (:inherit ,vpitch :foreground ,pal-cyan :weight bold))))
   `(org-level-6 ((t (:inherit ,vpitch :foreground ,pal-blue :weight bold))))
   `(org-level-7 ((t (:inherit ,vpitch :foreground ,pal-magenta :weight bold))))
   `(org-level-8 ((t (:inherit ,vpitch :foreground ,pal-gray :weight bold))))
   `(org-document-title ((t (:inherit ,vpitch :foreground ,ui-accent :weight bold :height ,h-doc))))
   `(org-document-info ((t (:foreground ,ui-fg-dim))))
   `(org-todo ((t (:foreground ,ui-warning :weight bold))))
   `(org-done ((t (:foreground ,ui-success :weight bold))))
   `(org-headline-done ((t (:foreground ,ui-fg-dim))))
   `(org-hide ((t (:foreground ,ui-bg))))
   `(org-ellipsis ((t (:foreground ,ui-info :underline nil))))
   `(org-table ((t (:foreground ,ui-link :inherit fixed-pitch))))
   `(org-formula ((t (:foreground ,syntax-constant :inherit fixed-pitch))))
   `(org-checkbox ((t (:foreground ,ui-accent :weight bold :inherit fixed-pitch))))
   `(org-date ((t (:foreground ,ui-info :underline t))))
   `(org-special-keyword ((t (:foreground ,ui-fg-dim :slant italic))))
   `(org-tag ((t (:foreground ,ui-border :weight normal))))

   ;; === Magit ===
   `(magit-section-highlight ((t (:background ,ui-bg-dark))))
   `(magit-diff-hunk-heading ((t (:background ,ui-line-highlight :foreground ,ui-fg-dim))))
   `(magit-diff-hunk-heading-highlight ((t (:background ,ui-bg-light :foreground ,ui-fg))))
   `(magit-diff-context ((t (:foreground ,ui-fg-dim :extend t))))
   `(magit-diff-context-highlight ((t (:background ,ui-bg-dark :foreground ,ui-fg :extend t))))
   `(magit-diff-added ((t (:background ,ui-tooltip-bg :foreground ,ui-success :extend t))))
   `(magit-diff-added-highlight ((t (:background ,ui-tooltip-bg :foreground ,ui-success :weight bold :extend t))))
   `(magit-diff-removed ((t (:background ,ui-active-text-bg :foreground ,ui-error :extend t))))
   `(magit-diff-removed-highlight ((t (:background ,ui-active-text-bg :foreground ,ui-error :weight bold :extend t))))
   `(magit-diff-base ((t (:background ,ui-button-bg :foreground ,ui-link :extend t))))
   `(magit-diff-base-highlight ((t (:background ,ui-button-bg :foreground ,ui-link :weight bold :extend t))))
   `(magit-hash ((t (:foreground ,ui-border))))
   `(magit-branch-local ((t (:foreground ,ui-accent :weight bold))))
   `(magit-branch-remote ((t (:foreground ,ui-success :weight bold))))

   ;; === Company ===
   `(company-tooltip ((t (:background ,ui-line-highlight :foreground ,ui-fg))))
   `(company-tooltip-selection ((t (:background ,ui-selection-bg :foreground ,ui-selection-fg))))
   `(company-tooltip-deprecated ((t (:foreground ,ui-fg-dim :strike-through t))))
   `(company-tooltip-search ((t (:foreground ,ui-accent :weight bold))))
   `(company-tooltip-search-selection ((t (:foreground ,ui-accent :background ,ui-selection-bg :weight bold))))
   `(company-tooltip-mouse ((t (:background ,ui-bg-light))))
   `(company-tooltip-common ((t (:foreground ,ui-link :weight bold))))
   `(company-tooltip-common-selection ((t (:foreground ,ui-link :weight bold))))
   `(company-tooltip-annotation ((t (:foreground ,ui-fg-dim))))
   `(company-tooltip-annotation-selection ((t (:foreground ,ui-fg-dim))))
   `(company-scrollbar-fg ((t (:background ,ui-border))))
   `(company-scrollbar-bg ((t (:background ,ui-bg-dark))))
   `(company-preview ((t (:foreground ,ui-fg-dim :slant italic))))
   `(company-preview-common ((t (:foreground ,ui-link :weight bold :slant italic))))

   ;; === Ido ===
   `(ido-first-match ((t (:foreground ,ui-success :weight bold))))
   `(ido-only-match ((t (:foreground ,ui-info :weight bold))))
   `(ido-subdir ((t (:foreground ,ui-accent))))
   `(ido-incomplete-regexp ((t (:foreground ,ui-error))))
   `(ido-indicator ((t (:foreground ,ui-warning :background ,ui-bg))))
   `(ido-virtual ((t (:foreground ,ui-border))))

   ;; === Completions (built-in) ===
   `(completions-annotations ((t (:foreground ,ui-fg-dim))))
   `(completions-common-part ((t (:foreground ,ui-link :weight bold))))
   `(completions-first-difference ((t (:foreground ,ui-warning))))
   `(completions-highlight ((t (:background ,ui-bg-light))))
   `(completions-group-title ((t (:foreground ,ui-accent :weight bold :slant italic))))
   `(completions-group-separator ((t (:foreground ,ui-border :strike-through t))))

   ;; === Icomplete ===
   `(icomplete-first-match ((t (:foreground ,ui-success :weight bold))))
   `(icomplete-selected-match ((t (:background ,ui-bg-light))))

   ;; === Helm ===
   `(helm-selection ((t (:background ,ui-selection-bg :foreground ,ui-selection-fg))))
   `(helm-match ((t (:foreground ,ui-accent :weight bold))))
   `(helm-source-header ((t (:background ,ui-bg-light :foreground ,ui-accent :weight bold :height 1.1))))
   `(helm-candidate-number ((t (:foreground ,ui-info :weight bold))))
   `(helm-ff-directory ((t (:foreground ,ui-accent :weight bold))))
   `(helm-ff-file ((t (:foreground ,ui-fg))))
   `(helm-ff-executable ((t (:foreground ,ui-info))))

   ;; === Corfu ===
   `(corfu-default ((t (:background ,ui-line-highlight :foreground ,ui-fg))))
   `(corfu-current ((t (:background ,ui-selection-bg :foreground ,ui-selection-fg))))
   `(corfu-bar ((t (:background ,ui-border))))
   `(corfu-border ((t (:background ,ui-bg-dark))))
   `(corfu-annotations ((t (:foreground ,ui-fg-dim))))
   `(corfu-deprecated ((t (:foreground ,ui-fg-dim :strike-through t))))

   ;; === Which-key ===
   `(which-key-key-face ((t (:foreground ,syntax-keyword :weight bold))))
   `(which-key-separator-face ((t (:foreground ,ui-border))))
   `(which-key-note-face ((t (:foreground ,ui-fg-dim))))
   `(which-key-command-description-face ((t (:foreground ,ui-fg))))
   `(which-key-group-description-face ((t (:foreground ,ui-accent))))
   `(which-key-local-map-description-face ((t (:foreground ,ui-info))))
   `(which-key-special-key-face ((t (:foreground ,ui-warning :weight bold))))

   ;; === Line numbers ===
   `(line-number ((t (:foreground ,ui-border :inherit fixed-pitch))))
   `(line-number-current-line ((t (:foreground ,ui-accent :weight bold :inherit fixed-pitch))))

   ;; === Parenthesis matching ===
   `(sp-show-pair-match-face ((t (:background ,ui-selection-bg :foreground ,ui-selection-fg))))
   `(sp-show-pair-mismatch-face ((t (:background ,ui-active-text-bg :foreground ,ui-active-text-fg))))

   ;; === Rainbow delimiters - rainbow cycle, mismatches highlighted ===
   `(rainbow-delimiters-depth-1-face ((t (:foreground ,pal-red))))
   `(rainbow-delimiters-depth-2-face ((t (:foreground ,pal-orange))))
   `(rainbow-delimiters-depth-3-face ((t (:foreground ,pal-yellow))))
   `(rainbow-delimiters-depth-4-face ((t (:foreground ,pal-green))))
   `(rainbow-delimiters-depth-5-face ((t (:foreground ,pal-cyan))))
   `(rainbow-delimiters-depth-6-face ((t (:foreground ,pal-blue))))
   `(rainbow-delimiters-depth-7-face ((t (:foreground ,pal-magenta))))
   `(rainbow-delimiters-depth-8-face ((t (:foreground ,pal-gray))))
   `(rainbow-delimiters-depth-9-face ((t (:foreground ,ui-fg-dim))))
   `(rainbow-delimiters-mismatched-face ((t (:box (:line-width -1 :color ,ui-error) :weight bold))))
   `(rainbow-delimiters-unmatched-face ((t (:box (:line-width -1 :color ,ui-error) :weight bold))))
   `(rainbow-delimiters-base-error-face ((t (:box (:line-width -1 :color ,ui-error) :weight bold))))

   ;; === Dired ===
   `(dired-directory ((t (:foreground ,ui-accent :weight bold))))
   `(dired-ignored ((t (:foreground ,ui-border))))
   `(dired-flagged ((t (:foreground ,ui-error))))
   `(dired-marked ((t (:foreground ,ui-info :weight bold))))
   `(dired-symlink ((t (:foreground ,ui-link :slant italic))))
   `(dired-header ((t (:foreground ,ui-accent :weight bold :height 1.1))))

   ;; === Terminal colors - mapped to the palette so they stay correct in both variants ===
   `(term-color-black ((t (:foreground ,ui-bg-dark :background ,ui-bg-dark))))
   `(term-color-red ((t (:foreground "#ff5555" :background "#ff5555"))))
   `(term-color-green ((t (:foreground "#50fa7b" :background "#50fa7b"))))
   `(term-color-yellow ((t (:foreground "#f1fa8c" :background "#f1fa8c"))))
   `(term-color-blue ((t (:foreground "#bd93f9" :background "#bd93f9"))))
   `(term-color-magenta ((t (:foreground "#ff79c6" :background "#ff79c6"))))
   `(term-color-cyan ((t (:foreground "#8be9fd" :background "#8be9fd"))))
   `(term-color-white ((t (:foreground "#f8f8f2" :background "#f8f8f2"))))

   ;; === EShell ===
   `(eshell-prompt ((t (:foreground ,ui-accent :weight bold))))
   `(eshell-ls-directory ((t (:foreground ,ui-accent :weight bold))))
   `(eshell-ls-symlink ((t (:foreground ,ui-link :slant italic))))
   `(eshell-ls-executable ((t (:foreground ,ui-info))))
   `(eshell-ls-archive ((t (:foreground ,ui-tooltip-fg))))
   `(eshell-ls-backup ((t (:foreground ,ui-border))))
   `(eshell-ls-clutter ((t (:foreground ,ui-error))))
   `(eshell-ls-missing ((t (:foreground ,ui-error))))
   `(eshell-ls-product ((t (:foreground ,ui-fg-dim))))
   `(eshell-ls-readonly ((t (:foreground ,ui-fg-dim))))
   `(eshell-ls-special ((t (:foreground ,ui-link))))
   `(eshell-ls-unreadable ((t (:foreground ,ui-border))))

   ;; === Markdown - rainbow heading cycle ===
   `(markdown-header-face ((t (:foreground ,ui-accent :weight bold))))
   `(markdown-header-face-1 ((t (:inherit ,vpitch :foreground ,ui-accent :weight bold :height ,h1))))
   `(markdown-header-face-2 ((t (:inherit ,vpitch :foreground ,pal-orange :weight bold :height ,h2))))
   `(markdown-header-face-3 ((t (:inherit ,vpitch :foreground ,pal-yellow :weight bold :height ,h3))))
   `(markdown-header-face-4 ((t (:inherit ,vpitch :foreground ,pal-green :weight bold))))
   `(markdown-header-face-5 ((t (:inherit ,vpitch :foreground ,pal-cyan :weight bold))))
   `(markdown-header-face-6 ((t (:inherit ,vpitch :foreground ,pal-blue :weight bold))))
   `(markdown-inline-code-face ((t (:foreground ,ui-info :background ,ui-bg-dark :inherit fixed-pitch))))
   `(markdown-code-face ((t (:background ,ui-bg-dark :extend t :inherit fixed-pitch))))
   `(markdown-pre-face ((t (:background ,ui-bg-dark :inherit fixed-pitch))))
   `(markdown-table-face ((t (:foreground ,ui-link :inherit fixed-pitch))))

   ;; === Web mode ===

   ;; === Flycheck ===
   `(flycheck-error ((t (:underline (:style wave :color ,ui-error)))))
   `(flycheck-warning ((t (:underline (:style wave :color ,ui-warning)))))
   `(flycheck-info ((t (:underline (:style wave :color ,ui-info)))))
   `(flycheck-fringe-error ((t (:foreground ,ui-error))))
   `(flycheck-fringe-warning ((t (:foreground ,ui-warning))))
   `(flycheck-fringe-info ((t (:foreground ,ui-info))))

   ;; === Minibuffer ===
   `(minibuffer-prompt ((t (:foreground ,ui-accent :weight bold))))

   ;; === LSP ===
   `(lsp-face-highlight-textual ((t (:background ,ui-selection-bg :foreground ,ui-selection-fg :weight bold))))
   `(lsp-face-highlight-read ((t (:background ,ui-button-bg :foreground ,ui-button-fg :weight bold))))
   `(lsp-face-highlight-write ((t (:background ,ui-tooltip-bg :foreground ,ui-tooltip-fg :weight bold))))

   ;; === Info titles - rainbow heading cycle ===
   `(info-title-1 ((t (:inherit ,vpitch :foreground ,ui-accent :weight bold :height ,h1))))
   `(info-title-2 ((t (:inherit ,vpitch :foreground ,pal-orange :weight bold :height ,h2))))
   `(info-title-3 ((t (:inherit ,vpitch :foreground ,pal-yellow :weight bold :height ,h3))))
   `(info-title-4 ((t (:inherit ,vpitch :foreground ,pal-green :weight bold))))
   `(Info-quoted ((t (:foreground ,ui-info))))
   `(info-menu-header ((t (:foreground ,ui-accent :weight bold))))
   `(info-menu-star ((t (:foreground ,ui-accent))))
   `(info-node ((t (:foreground ,ui-info :weight bold))))

   ;; === Tabs ===
   `(tab-bar ((t (:background ,ui-bg-light :foreground ,ui-fg :box nil))))
   `(tab-bar-tab ((t (:background ,ui-bg-light :foreground ,ui-fg :weight bold :box nil))))
   `(tab-bar-tab-inactive ((t (:background ,ui-bg :foreground ,ui-fg-dim :box nil))))
   `(tab-line ((t (:background ,ui-bg-light :foreground ,ui-fg :box nil))))
   `(tab-line-tab ((t (:background ,ui-bg :foreground ,ui-fg-dim :box nil))))
   `(tab-line-tab-current ((t (:background ,ui-bg-light :foreground ,ui-fg :weight bold :box nil))))
   `(tab-line-tab-inactive ((t (:background ,ui-bg :foreground ,ui-fg-dim :box nil))))
   `(tab-line-highlight ((t (:background ,ui-bg-light :foreground ,ui-fg))))
   `(centaur-tabs-default ((t (:background ,ui-bg-light :foreground ,ui-fg))))
   `(centaur-tabs-selected ((t (:background ,ui-bg-light :foreground ,ui-fg :weight bold))))
   `(centaur-tabs-unselected ((t (:background ,ui-bg :foreground ,ui-fg-dim))))
   `(centaur-tabs-selected-modified ((t (:background ,ui-bg-light :foreground ,ui-warning :weight bold))))
   `(centaur-tabs-unselected-modified ((t (:background ,ui-bg :foreground ,ui-warning))))
   `(centaur-tabs-active-bar-face ((t (:background ,ui-accent))))

   ;; === Fixed/variable pitch ===
   `(fixed-pitch ((t (:family "monospace"))))
   `(fixed-pitch-serif ((t (:family "monospace serif"))))
   `(variable-pitch ((t (:family "sans serif"))))

   ;; === Basic builtins (missing) ===
   `(bold ((t (:weight bold))))
   `(bold-italic ((t (:weight bold :slant italic))))
   `(italic ((t (:slant italic))))
   `(bookmark-face ((t (:foreground ,ui-accent :weight bold :underline t))))
   `(nobreak-space ((t (:background ,ui-bg :foreground ,ui-fg))))
   `(tooltip ((t (:background ,ui-bg-light :foreground ,ui-fg))))
   `(trailing-whitespace ((t (:background ,ui-error))))
   `(header-line ((t (:background ,ui-bg-dark :foreground ,ui-fg))))
   `(window-divider ((t (:background ,ui-border :foreground ,ui-border))))
   `(window-divider-first-pixel ((t (:background ,ui-border :foreground ,ui-border))))
   `(window-divider-last-pixel ((t (:background ,ui-border :foreground ,ui-border))))

   ;; === Isearch (additional states) ===
   `(isearch-fail ((t (:background ,ui-active-text-bg :foreground ,ui-error :weight bold))))
   `(isearch-group-1 ((t (:background ,ui-accent :foreground ,ui-bg :weight bold))))
   `(isearch-group-2 ((t (:background ,ui-link :foreground ,ui-bg :weight bold))))

   ;; === HL-line ===
   `(hl-line ((t (:background ,ui-bg-dark :extend t))))

   ;; === HL-todo ===
   `(hl-todo ((t (:foreground ,ui-warning :weight bold))))

   ;; === Trailing whitespace & linum ===
   `(linum ((t (:foreground ,ui-border))))
   `(linum-relative-current-face ((t (:background ,ui-line-highlight :foreground ,ui-fg))))
   `(linum-highlight-face ((t (:foreground ,ui-fg :weight normal))))

   ;; === Outline (non-org) - rainbow cycle ===
   `(outline-1 ((t (:inherit ,vpitch :foreground ,ui-accent :weight ultra-bold :height ,h1))))
   `(outline-2 ((t (:inherit ,vpitch :foreground ,pal-orange :weight bold :height ,h2))))
   `(outline-3 ((t (:inherit ,vpitch :foreground ,pal-yellow :weight bold :height ,h3))))
   `(outline-4 ((t (:inherit ,vpitch :foreground ,pal-green))))
   `(outline-5 ((t (:inherit ,vpitch :foreground ,pal-cyan))))
   `(outline-6 ((t (:inherit ,vpitch :foreground ,pal-blue))))
   `(outline-7 ((t (:inherit ,vpitch :foreground ,pal-magenta))))
   `(outline-8 ((t (:inherit ,vpitch :foreground ,pal-gray))))
   `(outline-minor-1 ((t (:inherit ,vpitch :foreground ,ui-accent :weight ultra-bold :height ,h1))))
   `(outline-minor-2 ((t (:inherit ,vpitch :foreground ,pal-orange :weight bold :height ,h2))))
   `(outline-minor-3 ((t (:inherit ,vpitch :foreground ,pal-yellow :weight bold :height ,h3))))
   `(outline-minor-4 ((t (:inherit ,vpitch :foreground ,pal-green))))
   `(outline-minor-5 ((t (:inherit ,vpitch :foreground ,pal-cyan))))
   `(outline-minor-6 ((t (:inherit ,vpitch :foreground ,pal-blue))))
   `(outline-minor-7 ((t (:inherit ,vpitch :foreground ,pal-magenta))))
   `(outline-minor-8 ((t (:inherit ,vpitch :foreground ,pal-gray))))

   ;; === Org (missing faces) ===
   `(org-archived ((t (:foreground ,ui-border))))
   `(org-block-background ((t (:background ,ui-bg-dark :extend t))))
   `(org-checkbox-statistics-done ((t (:foreground ,ui-success :weight bold))))
   `(org-checkbox-statistics-todo ((t (:foreground ,ui-warning :weight bold))))
   `(org-default ((t (:background ,ui-bg :foreground ,ui-fg))))
   `(org-document-info-keyword ((t (:foreground ,ui-border))))
   `(org-footnote ((t (:foreground ,ui-link :underline t))))
   `(org-latex-and-related ((t (:foreground ,ui-fg-dim :weight bold))))
   `(org-link ((t (:foreground ,ui-accent :underline t))))
   `(org-list-dt ((t (:foreground ,ui-link :weight bold))))
   `(org-priority ((t (:foreground ,ui-error))))
   `(org-property-value ((t (:foreground ,ui-border))))
   `(org-quote ((t (:background ,ui-line-highlight :slant italic :extend t))))
   `(org-warning ((t (:foreground ,ui-warning :weight bold))))

   ;; === Org agenda ===
   `(org-agenda-clocking ((t (:background ,ui-button-bg :foreground ,ui-button-fg))))
   `(org-agenda-current-time ((t (:foreground ,ui-info :weight bold))))
   `(org-agenda-date ((t (:foreground ,ui-accent :weight ultra-bold))))
   `(org-agenda-date-today ((t (:foreground ,ui-accent :weight ultra-bold))))
   `(org-agenda-date-weekend ((t (:foreground ,ui-accent :weight ultra-bold))))
   `(org-agenda-dimmed-todo-face ((t (:foreground ,ui-border))))
   `(org-agenda-done ((t (:foreground ,ui-success))))
   `(org-agenda-structure ((t (:foreground ,ui-fg :weight ultra-bold))))
   `(org-imminent-deadline ((t (:foreground ,ui-error))))
   `(org-scheduled ((t (:foreground ,ui-fg))))
   `(org-scheduled-previously ((t (:foreground ,ui-fg-dim))))
   `(org-scheduled-today ((t (:foreground ,ui-fg))))
   `(org-sexp-date ((t (:foreground ,ui-fg))))
   `(org-time-grid ((t (:foreground ,ui-border))))
   `(org-upcoming-deadline ((t (:foreground ,ui-fg))))
   `(org-upcoming-distant-deadline ((t (:foreground ,ui-fg))))
   `(org-agenda-structure-filter ((t (:foreground ,ui-accent :weight bold))))

   ;; === Org habit ===
   `(org-habit-alert-face ((t (:weight bold :background ,ui-button-bg))))
   `(org-habit-alert-future-face ((t (:weight bold :background ,ui-button-bg))))
   `(org-habit-clear-face ((t (:weight bold :background ,ui-bg-light))))
   `(org-habit-clear-future-face ((t (:weight bold :background ,ui-line-highlight))))
   `(org-habit-overdue-face ((t (:weight bold :background ,ui-active-text-bg))))
   `(org-habit-overdue-future-face ((t (:weight bold :background ,ui-active-text-bg))))
   `(org-habit-ready-face ((t (:weight bold :background ,ui-tooltip-bg))))
   `(org-habit-ready-future-face ((t (:weight bold :background ,ui-tooltip-bg))))

   ;; === Org journal ===
   `(org-journal-calendar-entry-face ((t (:foreground ,ui-link :slant italic))))
   `(org-journal-calendar-scheduled-face ((t (:foreground ,ui-warning :slant italic))))
   `(org-journal-highlight ((t (:foreground ,ui-info))))

   ;; === Org pomodoro ===
   `(org-pomodoro-mode-line ((t (:foreground ,ui-accent))))
   `(org-pomodoro-mode-line-overtime ((t (:foreground ,ui-warning :weight bold))))

   ;; === Org ref ===
   `(org-ref-acronym-face ((t (:foreground ,ui-accent))))
   `(org-ref-cite-face ((t (:foreground ,ui-link :weight light :underline t))))
   `(org-ref-glossary-face ((t (:foreground ,ui-info))))
   `(org-ref-label-face ((t (:foreground ,ui-accent))))
   `(org-ref-ref-face ((t (:foreground ,ui-link :underline t :weight bold))))

   ;; === Ace-window ===
   `(aw-leading-char-face ((t (:foreground ,ui-accent :height 500 :weight bold))))
   `(aw-background-face ((t (:foreground ,ui-border))))

   ;; === Alert ===
   `(alert-high-face ((t (:foreground ,ui-link :weight bold))))
   `(alert-low-face ((t (:foreground ,ui-border))))
   `(alert-moderate-face ((t (:foreground ,ui-fg-dim :weight bold))))
   `(alert-trivial-face ((t (:foreground ,ui-border))))
   `(alert-urgent-face ((t (:foreground ,ui-error :weight bold))))

   ;; === ANSI colors - mapped to the palette so they stay correct in both variants ===
   `(ansi-color-black ((t (:foreground ,pal-black :background ,pal-black))))
   `(ansi-color-red ((t (:foreground ,pal-red :background ,pal-red))))
   `(ansi-color-green ((t (:foreground ,pal-green :background ,pal-green))))
   `(ansi-color-yellow ((t (:foreground ,pal-yellow :background ,pal-yellow))))
   `(ansi-color-blue ((t (:foreground ,pal-blue :background ,pal-blue))))
   `(ansi-color-magenta ((t (:foreground ,pal-magenta :background ,pal-magenta))))
   `(ansi-color-cyan ((t (:foreground ,pal-cyan :background ,pal-cyan))))
   `(ansi-color-white ((t (:foreground ,pal-white :background ,pal-white))))
   `(ansi-color-bright-black ((t (:foreground "#6272a4" :background "#6272a4"))))
   `(ansi-color-bright-red ((t (:foreground "#ff6e6e" :background "#ff6e6e"))))
   `(ansi-color-bright-green ((t (:foreground "#69ff94" :background "#69ff94"))))
   `(ansi-color-bright-yellow ((t (:foreground "#ffffa5" :background "#ffffa5"))))
   `(ansi-color-bright-blue ((t (:foreground "#d6acff" :background "#d6acff"))))
   `(ansi-color-bright-magenta ((t (:foreground "#ff92df" :background "#ff92df"))))
   `(ansi-color-bright-cyan ((t (:foreground "#a4ffff" :background "#a4ffff"))))
   `(ansi-color-bright-white ((t (:foreground "#ffffff" :background "#ffffff"))))

   ;; === Anzu ===
   `(anzu-replace-highlight ((t (:background ,ui-line-highlight :foreground ,ui-error :weight bold :strike-through t))))
   `(anzu-replace-to ((t (:background ,ui-line-highlight :foreground ,ui-info :weight bold))))

   ;; === Avy ===
   `(avy-background-face ((t (:foreground ,ui-border))))
   `(avy-lead-face ((t (:background ,ui-accent :foreground ,ui-bg :weight bold))))
   `(avy-lead-face-0 ((t (:background ,ui-accent :foreground ,ui-bg :weight bold))))
   `(avy-lead-face-1 ((t (:background ,ui-link :foreground ,ui-bg :weight bold))))
   `(avy-lead-face-2 ((t (:background ,ui-info :foreground ,ui-bg :weight bold))))

   ;; === Compilation ===
   `(compilation-column-number ((t (:foreground ,ui-border))))
   `(compilation-error ((t (:foreground ,ui-error :weight bold))))
   `(compilation-info ((t (:foreground ,ui-info))))
   `(compilation-line-number ((t (:foreground ,ui-accent))))
   `(compilation-mode-line-exit ((t (:foreground ,ui-success))))
   `(compilation-mode-line-fail ((t (:foreground ,ui-error :weight bold))))
   `(compilation-warning ((t (:foreground ,ui-warning :slant italic))))

   ;; === Consult ===
   `(consult-file ((t (:foreground ,ui-fg-dim))))
   `(consult-bookmark ((t (:foreground ,ui-accent))))
   `(consult-buffer ((t (:foreground ,ui-fg))))
   `(consult-line-number ((t (:foreground ,ui-fg-dim))))
   `(consult-line-number-prefix ((t (:foreground ,ui-border))))
   `(consult-separator ((t (:foreground ,ui-border))))
   `(consult-highlight-match ((t (:foreground ,ui-warning :weight bold))))
   `(consult-preview-match ((t (:background ,ui-bg-light))))
   `(consult-async-split ((t (:foreground ,syntax-keyword))))
   `(consult-key ((t (:foreground ,syntax-keyword))))
   `(consult-imenu-prefix ((t (:foreground ,ui-fg-dim))))
   `(consult-notes-dir ((t (:foreground ,ui-accent))))
   `(consult-notes-size ((t (:foreground ,ui-link))))
   `(consult-notes-name ((t (:foreground ,ui-accent))))
   `(consult-notes-time ((t (:foreground ,ui-accent))))

   ;; === Counsel ===
   `(counsel-variable-documentation ((t (:foreground ,ui-accent))))

   ;; === Custom widget ===
   `(custom-button ((t (:foreground ,ui-fg :background ,ui-line-highlight :box (:line-width 3 :style released-button)))))
   `(custom-button-mouse ((t (:foreground ,ui-link :background ,ui-line-highlight :box (:line-width 3 :style released-button)))))
   `(custom-button-pressed ((t (:foreground ,ui-bg :background ,ui-line-highlight :box (:line-width 3 :style pressed-button)))))
   `(custom-button-pressed-unraised ((t (:foreground ,ui-accent :background ,ui-bg :box (:line-width 3 :style pressed-button)))))
   `(custom-button-unraised ((t (:foreground ,ui-accent :background ,ui-bg :box (:line-width 3 :style pressed-button)))))
   `(custom-changed ((t (:foreground ,ui-accent :background ,ui-bg))))
   `(custom-comment ((t (:foreground ,ui-fg :background ,ui-line-highlight))))
   `(custom-comment-tag ((t (:foreground ,ui-border))))
   `(custom-documentation ((t (:foreground ,ui-fg))))
   `(custom-face-tag ((t (:foreground ,ui-accent :weight bold))))
   `(custom-group-subtitle ((t (:foreground ,ui-link :weight bold))))
   `(custom-group-tag ((t (:foreground ,ui-accent :weight bold))))
   `(custom-group-tag-1 ((t (:foreground ,ui-accent))))
   `(custom-invalid ((t (:foreground ,ui-error))))
   `(custom-link ((t (:foreground ,ui-accent :underline t))))
   `(custom-modified ((t (:foreground ,ui-accent))))
   `(custom-rogue ((t (:foreground ,ui-accent :box (:line-width 3)))))
   `(custom-saved ((t (:foreground ,ui-success :weight bold))))
   `(custom-set ((t (:foreground ,ui-link :background ,ui-bg))))
   `(custom-state ((t (:foreground ,ui-info))))
   `(custom-themed ((t (:foreground ,ui-link :background ,ui-bg))))
   `(custom-variable-button ((t (:foreground ,ui-info :underline t))))
   `(custom-variable-obsolete ((t (:foreground ,ui-border :background ,ui-bg))))
   `(custom-variable-tag ((t (:foreground ,ui-accent :underline t :extend unspecified))))
   `(custom-visibility ((t (:foreground ,ui-link :height 0.8 :underline t))))

   ;; === Built-in packages (batppuccin-inspired additions) ===
   `(anzu-match-1 ((t (:foreground ,ui-bg :background ,pal-blue))))
   `(anzu-match-2 ((t (:foreground ,ui-bg :background ,pal-cyan))))
   `(anzu-match-3 ((t (:foreground ,ui-bg :background ,pal-orange))))
   `(anzu-mode-line ((t (:foreground ,ui-info :weight bold))))
   `(anzu-mode-line-no-match ((t (:foreground ,ui-error :weight bold))))
   `(asciidoc-admonition-caution-face ((t (:background ,ui-bg-dark :extend t))))
   `(asciidoc-admonition-caution-label-face ((t (:foreground ,ui-warning :weight bold))))
   `(asciidoc-admonition-important-face ((t (:background ,ui-bg-dark :extend t))))
   `(asciidoc-admonition-important-label-face ((t (:foreground ,syntax-keyword :weight bold))))
   `(asciidoc-admonition-note-face ((t (:background ,ui-button-bg :extend t))))
   `(asciidoc-admonition-note-label-face ((t (:foreground ,ui-info :weight bold))))
   `(asciidoc-admonition-tip-face ((t (:background ,ui-tooltip-bg :extend t))))
   `(asciidoc-admonition-tip-label-face ((t (:foreground ,ui-success :weight bold))))
   `(asciidoc-admonition-warning-face ((t (:background ,ui-active-text-bg :extend t))))
   `(asciidoc-admonition-warning-label-face ((t (:foreground ,ui-warning :weight bold))))
   `(asciidoc-anchor-face ((t (:foreground ,ui-link))))
   `(asciidoc-code-face ((t (:foreground ,ui-info :background ,ui-bg-dark :extend t))))
   `(asciidoc-cross-reference-face ((t (:foreground ,ui-link :underline t))))
   `(asciidoc-document-title-face ((t (:inherit ,vpitch :foreground ,ui-accent :weight bold :height ,h-doc))))
   `(asciidoc-footnote-marker-face ((t (:foreground ,ui-info))))
   `(asciidoc-footnote-text-face ((t (:foreground ,ui-fg-dim))))
   `(asciidoc-highlight-face ((t (:foreground ,ui-search-fg :background ,ui-search-bg))))
   `(asciidoc-link-face ((t (:foreground ,ui-link :underline t))))
   `(asciidoc-link-mouse-face ((t (:foreground ,ui-link :background ,ui-bg-light :underline t))))
   `(asciidoc-markup-face ((t (:foreground ,ui-fg-dim))))
   `(asciidoc-metadata-key-face ((t (:foreground ,ui-fg-dim))))
   `(asciidoc-metadata-value-face ((t (:foreground ,ui-fg-dim))))
   `(asciidoc-overline-face ((t (:overline t))))
   `(asciidoc-strike-through-face ((t (:foreground ,ui-fg-dim :strike-through t))))
   `(asciidoc-subscript-face ((t (:foreground ,ui-fg :height 0.8))))
   `(asciidoc-superscript-face ((t (:foreground ,ui-fg :height 0.8))))
   `(asciidoc-title-1-face ((t (:inherit ,vpitch :foreground ,ui-accent :weight bold :height ,h1))))
   `(asciidoc-title-2-face ((t (:inherit ,vpitch :foreground ,pal-orange :weight bold :height ,h2))))
   `(asciidoc-title-3-face ((t (:inherit ,vpitch :foreground ,pal-yellow :weight bold :height ,h3))))
   `(asciidoc-title-4-face ((t (:inherit ,vpitch :foreground ,pal-green :weight bold))))
   `(asciidoc-title-5-face ((t (:inherit ,vpitch :foreground ,pal-cyan :weight bold))))
   `(asciidoc-underline-face ((t (:underline t))))
   `(asciidoc-url-face ((t (:foreground ,ui-link :underline t))))
   `(breadcrumb-face ((t (:foreground ,ui-fg-dim))))
   `(breadcrumb-imenu-base-face ((t (:foreground ,ui-fg-dim :weight bold))))
   `(breadcrumb-imenu-crumbs-face ((t (:foreground ,ui-fg-dim))))
   `(breadcrumb-imenu-leaf-face ((t (:foreground ,ui-accent :weight bold))))
   `(breadcrumb-project-base-face ((t (:foreground ,ui-fg-dim :weight bold))))
   `(breadcrumb-project-crumbs-face ((t (:foreground ,ui-fg-dim))))
   `(breadcrumb-project-leaf-face ((t (:foreground ,ui-fg :weight bold))))
   `(cider-debug-prompt-face ((t (:foreground ,syntax-keyword :weight bold))))
   `(cider-fringe-bad-face ((t (:foreground ,ui-error))))
   `(cider-fringe-stale-face ((t (:foreground ,ui-warning))))
   `(cider-reader-conditional-face ((t (:foreground ,ui-fg-dim))))
   `(cider-repl-result-face ((t (:foreground ,ui-info))))
   `(clojure-character-face ((t (:foreground ,ui-success))))
   `(clojure-discard-face ((t (:foreground ,ui-fg-dim :slant italic))))
   `(clojure-keyword-face ((t (:foreground ,syntax-keyword))))
   `(completion-preview ((t (:foreground ,ui-fg-dim))))
   `(completion-preview-common ((t (:foreground ,ui-fg-dim))))
   `(completion-preview-exact ((t (:foreground ,ui-fg-dim :underline t))))
   `(copilot-overlay-face ((t (:foreground ,ui-fg-dim :slant italic))))
   `(corfu-popupinfo ((t (:foreground ,ui-fg :background ,ui-bg-dark))))
   `(dictionary-button-face ((t (:foreground ,ui-link :underline t :weight bold))))
   `(dictionary-reference-face ((t (:foreground ,ui-link :underline t))))
   `(dictionary-word-definition-face ((t (:foreground ,ui-fg))))
   `(dictionary-word-entry-face ((t (:foreground ,ui-accent :weight bold))))
   `(easy-kill-origin ((t (:foreground ,ui-bg :background ,ui-error))))
   `(easy-kill-selection ((t (:background ,ui-selection-bg :extend t))))
   `(erlang-edoc-heading ((t (:foreground ,syntax-keyword :weight bold))))
   `(erlang-edoc-macro ((t (:foreground ,syntax-preprocessor))))
   `(erlang-edoc-tag ((t (:foreground ,ui-fg-dim))))
   `(erlang-edoc-todo ((t (:foreground ,ui-error :weight bold))))
   `(erlang-edoc-verbatim ((t (:foreground ,ui-info))))
   `(erlang-font-lock-exported-function-name-face ((t (:foreground ,syntax-function :weight bold))))
   `(font-latex-bold-face ((t (:foreground ,ui-fg :weight bold))))
   `(font-latex-italic-face ((t (:foreground ,ui-fg :slant italic))))
   `(font-latex-math-face ((t (:foreground ,ui-info))))
   `(font-latex-script-char-face ((t (:foreground ,ui-warning))))
   `(font-latex-sectioning-0-face ((t (:inherit ,vpitch :foreground ,ui-accent :height ,h1 :weight bold))))
   `(font-latex-sectioning-1-face ((t (:inherit ,vpitch :foreground ,pal-orange :height ,h2 :weight bold))))
   `(font-latex-sectioning-2-face ((t (:inherit ,vpitch :foreground ,pal-yellow :height ,h3 :weight bold))))
   `(font-latex-sectioning-3-face ((t (:inherit ,vpitch :foreground ,pal-green :weight bold))))
   `(font-latex-sectioning-4-face ((t (:inherit ,vpitch :foreground ,pal-cyan :weight bold))))
   `(font-latex-sectioning-5-face ((t (:inherit ,vpitch :foreground ,pal-blue :weight bold))))
   `(font-latex-sedate-face ((t (:foreground ,ui-fg-dim))))
   `(font-latex-slide-title-face ((t (:inherit ,vpitch :foreground ,ui-accent :weight bold :height ,h1))))
   `(font-latex-string-face ((t (:foreground ,ui-success))))
   `(font-latex-subscript-face ((t (:height 0.9))))
   `(font-latex-superscript-face ((t (:height 0.9))))
   `(font-latex-verbatim-face ((t (:foreground ,ui-info :inherit fixed-pitch))))
   `(font-latex-warning-face ((t (:foreground ,ui-warning :weight bold))))
   `(font-latex-doctex-documentation-face ((t (:background ,ui-bg-dark))))
   `(font-latex-doctex-preprocessor-face ((t (:foreground ,syntax-keyword))))
   `(git-timemachine-commit ((t (:foreground ,ui-warning :weight bold))))
   `(git-timemachine-minibuffer-author-face ((t (:foreground ,ui-accent))))
   `(git-timemachine-minibuffer-detail-face ((t (:foreground ,ui-info))))
   `(gptel-context-deletion-face ((t (:background ,ui-active-text-bg :extend t))))
   `(gptel-context-highlight-face ((t (:background ,ui-bg-light :extend t))))
   `(gptel-response-fringe-highlight ((t (:foreground ,ui-accent))))
   `(gptel-response-highlight ((t (:background ,ui-bg-dark :extend t))))
   `(gptel-rewrite-highlight-face ((t (:background ,ui-button-bg :extend t))))
   `(haskell-constructor-face ((t (:foreground ,syntax-type))))
   `(haskell-definition-face ((t (:foreground ,syntax-function))))
   `(haskell-error-face ((t (:underline (:style wave :color ,ui-error)))))
   `(haskell-hole-face ((t (:foreground ,ui-warning :weight bold))))
   `(haskell-interactive-face-compile-error ((t (:foreground ,ui-error :weight bold))))
   `(haskell-interactive-face-compile-warning ((t (:foreground ,ui-warning :weight bold))))
   `(haskell-interactive-face-garbage ((t (:foreground ,ui-fg-dim))))
   `(haskell-interactive-face-prompt ((t (:foreground ,ui-accent :weight bold))))
   `(haskell-interactive-face-prompt-cont ((t (:foreground ,ui-link))))
   `(haskell-interactive-face-result ((t (:foreground ,ui-success))))
   `(haskell-keyword-face ((t (:foreground ,syntax-keyword))))
   `(haskell-literate-comment-face ((t (:foreground ,ui-fg-dim :slant italic))))
   `(haskell-operator-face ((t (:foreground ,syntax-operator))))
   `(haskell-pragma-face ((t (:foreground ,syntax-annotation))))
   `(haskell-quasi-quote-face ((t (:foreground ,ui-success))))
   `(haskell-type-face ((t (:foreground ,syntax-type))))
   `(haskell-warning-face ((t (:underline (:style wave :color ,ui-warning)))))
   `(inf-ruby-result-overlay-face ((t (:foreground ,ui-success :background ,ui-bg-dark :box (:line-width -1 :color ,ui-bg-light)))))
   `(jinx-annotation ((t (:foreground ,ui-fg-dim))))
   `(jinx-highlight ((t (:foreground ,ui-bg :background ,ui-error :weight bold))))
   `(jinx-key ((t (:foreground ,syntax-keyword :weight bold))))
   `(jinx-misspelled ((t (:underline (:style wave :color ,ui-error)))))
   `(jinx-save ((t (:foreground ,ui-warning :weight bold))))
   `(mistty-fringe-face ((t (:foreground ,ui-border))))
   `(nrepl-message-1-face ((t (:foreground ,ui-error))))
   `(nrepl-message-2-face ((t (:foreground ,pal-orange))))
   `(nrepl-message-3-face ((t (:foreground ,pal-yellow))))
   `(nrepl-message-4-face ((t (:foreground ,ui-success))))
   `(nrepl-message-5-face ((t (:foreground ,pal-cyan))))
   `(nrepl-message-6-face ((t (:foreground ,ui-link))))
   `(nrepl-message-7-face ((t (:foreground ,pal-blue))))
   `(nrepl-message-8-face ((t (:foreground ,pal-magenta))))
   `(shr-h1 ((t (:inherit ,vpitch :foreground ,ui-accent :weight bold :height ,h1))))
   `(shr-h2 ((t (:inherit ,vpitch :foreground ,pal-orange :weight bold :height ,h2))))
   `(shr-h3 ((t (:inherit ,vpitch :foreground ,pal-yellow :weight bold :height ,h3))))
   `(shr-h4 ((t (:inherit ,vpitch :foreground ,pal-green :weight bold))))
   `(shr-h5 ((t (:inherit ,vpitch :foreground ,pal-cyan :weight bold))))
   `(shr-h6 ((t (:inherit ,vpitch :foreground ,pal-blue :weight bold))))
   `(shr-link ((t (:foreground ,ui-link :underline t))))
   `(shr-selected-link ((t (:foreground ,ui-warning :underline t))))
   `(shr-code ((t (:foreground ,ui-info :background ,ui-bg-dark))))
   `(shr-mark ((t (:foreground ,ui-search-fg :background ,ui-search-bg))))
   `(vundo-branch-stem ((t (:foreground ,ui-border))))
   `(vundo-diff-highlight ((t (:foreground ,ui-warning :weight bold))))
   `(vundo-highlight ((t (:foreground ,ui-accent :weight bold))))
   `(vundo-last-saved ((t (:foreground ,ui-success :weight bold))))
   `(vundo-node ((t (:foreground ,ui-fg-dim))))
   `(vundo-saved ((t (:foreground ,ui-success))))
   `(vundo-stem ((t (:foreground ,ui-border))))
   ;; === Calendar ===
   `(calendar-today ((t (:foreground ,ui-accent :weight bold :underline t))))
   `(calendar-weekend-header ((t (:foreground ,ui-warning))))
   `(calendar-weekday-header ((t (:foreground ,ui-info))))
   `(calendar-month-header ((t (:foreground ,syntax-keyword :weight bold))))
   `(holiday ((t (:foreground ,ui-warning))))
   `(diary ((t (:foreground ,ui-info))))

   ;; === Eglot ===
   `(eglot-highlight-symbol-face ((t (:background ,ui-bg-light :weight bold))))
   `(eglot-diagnostic-tag-unnecessary-face ((t (:foreground ,ui-fg-dim :underline (:style wave :color ,ui-border)))))
   `(eglot-diagnostic-tag-deprecated-face ((t (:foreground ,ui-fg-dim :strike-through ,ui-border))))
   `(eglot-inlay-hint-face ((t (:foreground ,ui-fg-dim :height 0.9))))

   ;; === EPA (EasyPG) ===
   `(epa-field-body ((t (:foreground ,ui-fg-dim :slant italic))))
   `(epa-field-name ((t (:foreground ,ui-accent :weight bold))))
   `(epa-mark ((t (:foreground ,ui-warning :weight bold))))
   `(epa-string ((t (:foreground ,syntax-string))))
   `(epa-validity-disabled ((t (:foreground ,ui-error :slant italic))))
   `(epa-validity-high ((t (:foreground ,ui-success :weight bold))))
   `(epa-validity-low ((t (:foreground ,ui-fg-dim))))
   `(epa-validity-medium ((t (:foreground ,ui-warning))))

   ;; === Proced ===
   `(proced-mark ((t (:foreground ,ui-warning :weight bold))))
   `(proced-marked ((t (:foreground ,syntax-keyword :weight bold))))
   `(proced-sort-header ((t (:foreground ,ui-accent :weight bold :underline t))))

   ;; === Speedbar ===
   `(speedbar-button-face ((t (:foreground ,ui-success))))
   `(speedbar-directory-face ((t (:foreground ,ui-accent :weight bold))))
   `(speedbar-file-face ((t (:foreground ,ui-fg))))
   `(speedbar-highlight-face ((t (:background ,ui-bg-light))))
   `(speedbar-selected-face ((t (:foreground ,ui-warning :weight bold))))
   `(speedbar-separator-face ((t (:foreground ,ui-border :background ,ui-bg-dark))))
   `(speedbar-tag-face ((t (:foreground ,ui-info))))

   ;; === VC ===
   `(vc-state-base ((t (:foreground ,ui-success))))
   `(vc-conflict-state ((t (:foreground ,ui-error :weight bold))))
   `(vc-edited-state ((t (:foreground ,ui-warning))))
   `(vc-locally-added-state ((t (:foreground ,ui-success))))
   `(vc-locked-state ((t (:foreground ,ui-warning :weight bold))))
   `(vc-missing-state ((t (:foreground ,ui-error))))
   `(vc-needs-update-state ((t (:foreground ,ui-warning))))
   `(vc-removed-state ((t (:foreground ,ui-error))))
   `(vc-up-to-date-state ((t (:foreground ,ui-success))))

   ;; === Xref ===
   `(xref-file-header ((t (:foreground ,ui-accent :weight bold))))
   `(xref-line-number ((t (:foreground ,ui-fg-dim))))
   `(xref-match ((t (:foreground ,ui-warning :weight bold))))

   ;; === Man / Woman ===
   `(Man-overstrike ((t (:foreground ,ui-accent :weight bold))))
   `(Man-underline ((t (:foreground ,ui-info :underline t))))
   `(Man-reverse ((t (:foreground ,ui-bg :background ,ui-fg))))
   `(woman-bold ((t (:foreground ,ui-accent :weight bold))))
   `(woman-italic ((t (:foreground ,syntax-keyword :slant italic))))

   ;; === Pulse ===
   `(pulse-highlight-start-face ((t (:background ,ui-bg-light))))

   ;; === Diff ===
   `(diff-added ((t (:foreground ,ui-success :background ,ui-tooltip-bg :extend t))))
   `(diff-indicator-added ((t (:foreground ,ui-success :weight bold :background ,ui-tooltip-bg :extend t))))
   `(diff-refine-added ((t (:foreground ,ui-success :weight bold :background ,ui-tooltip-bg :extend t))))
   `(diff-changed ((t (:foreground ,ui-warning :background ,ui-button-bg :extend t))))
   `(diff-indicator-changed ((t (:foreground ,ui-warning :weight bold :background ,ui-button-bg :extend t))))
   `(diff-refine-changed ((t (:foreground ,ui-warning :weight bold :background ,ui-button-bg :extend t))))
   `(diff-removed ((t (:foreground ,ui-error :background ,ui-active-text-bg :extend t))))
   `(diff-indicator-removed ((t (:foreground ,ui-error :weight bold :background ,ui-active-text-bg :extend t))))
   `(diff-refine-removed ((t (:foreground ,ui-error :weight bold :background ,ui-active-text-bg :extend t))))
   `(diff-header ((t (:foreground ,ui-fg-dim :background ,ui-bg-dark :extend t))))
   `(diff-file-header ((t (:foreground ,ui-accent :background ,ui-bg-dark :weight bold :extend t))))
   `(diff-hunk-header ((t (:foreground ,ui-warning :background ,ui-bg-dark :extend t))))
   `(diff-function ((t (:foreground ,ui-selection-fg :background ,ui-selection-bg :extend t))))

   ;; === Diff-hl ===
   `(diff-hl-change ((t (:foreground ,ui-warning :background ,ui-button-bg))))
   `(diff-hl-delete ((t (:foreground ,ui-error :background ,ui-active-text-bg))))
   `(diff-hl-insert ((t (:foreground ,ui-success :background ,ui-tooltip-bg))))

   ;; === Dired (missing faces) ===
   `(dired-mark ((t (:foreground ,ui-link :weight bold))))
   `(dired-perm-write ((t (:foreground ,ui-warning :underline t))))
   `(dired-warning ((t (:foreground ,ui-warning))))

   ;; === Diredfl ===
   `(diredfl-file-name ((t (:inherit default))))
   `(diredfl-file-suffix ((t (:inherit default))))
   `(diredfl-autofile-name ((t (:foreground ,ui-border))))
   `(diredfl-compressed-file-name ((t (:foreground ,ui-success))))
   `(diredfl-compressed-file-suffix ((t (:foreground ,ui-success))))
   `(diredfl-date-time ((t (:foreground ,ui-fg-dim :weight light))))
   `(diredfl-deletion ((t (:foreground ,ui-error :weight bold))))
   `(diredfl-deletion-file-name ((t (:foreground ,ui-error))))
   `(diredfl-dir-heading ((t (:inherit dired-header))))
   `(diredfl-dir-name ((t (:inherit dired-directory))))
   `(diredfl-dir-priv ((t (:inherit dired-directory))))
   `(diredfl-exec-priv ((t (:foreground ,ui-accent))))
   `(diredfl-executable-tag ((t (:foreground ,ui-accent))))
   `(diredfl-flag-mark ((t (:inherit dired-mark))))
   `(diredfl-flag-mark-line ((t (:inherit dired-marked))))
   `(diredfl-ignored-file-name ((t (:inherit dired-ignored))))
   `(diredfl-link-priv ((t (:inherit dired-symlink))))
   `(diredfl-no-priv ((t (:foreground ,ui-fg-dim))))
   `(diredfl-number ((t (:foreground ,syntax-number))))
   `(diredfl-other-priv ((t (:inherit diredfl-exec-priv))))
   `(diredfl-rare-priv ((t (:inherit diredfl-exec-priv))))
   `(diredfl-read-priv ((t (:foreground ,ui-info))))
   `(diredfl-symlink ((t (:inherit dired-symlink))))
   `(diredfl-tagged-autofile-name ((t (:foreground ,syntax-annotation))))
   `(diredfl-write-priv ((t (:foreground ,ui-error))))

   ;; === Dired-subtree ===
   `(dired-subtree-depth-1-face ((t (:background ,ui-bg-dark))))
   `(dired-subtree-depth-2-face ((t (:background ,ui-bg-dark))))
   `(dired-subtree-depth-3-face ((t (:background ,ui-bg-dark))))
   `(dired-subtree-depth-4-face ((t (:background ,ui-bg-dark))))
   `(dired-subtree-depth-5-face ((t (:background ,ui-bg-dark))))
   `(dired-subtree-depth-6-face ((t (:background ,ui-bg-dark))))

   ;; === Dired-k ===
   `(dired-k-added ((t (:foreground ,ui-success :weight bold))))
   `(dired-k-commited ((t (:foreground ,ui-success :weight bold))))
   `(dired-k-directory ((t (:foreground ,ui-accent :weight bold))))
   `(dired-k-ignored ((t (:foreground ,ui-border :weight bold))))
   `(dired-k-modified ((t (:foreground ,ui-warning :weight bold))))
   `(dired-k-untracked ((t (:foreground ,ui-info :weight bold))))

   ;; === Doom-modeline ===
   `(doom-modeline-bar ((t (:foreground ,ui-accent))))
   `(doom-modeline-buffer-major-mode ((t (:foreground ,ui-accent))))
   `(doom-modeline-buffer-path ((t (:foreground ,ui-accent))))
   `(doom-modeline-eldoc-bar ((t (:background ,ui-info))))
   `(doom-modeline-evil-emacs-state ((t (:foreground ,ui-link :weight bold))))
   `(doom-modeline-evil-insert-state ((t (:foreground ,ui-success :weight bold))))
   `(doom-modeline-evil-motion-state ((t (:foreground ,ui-info :weight bold))))
   `(doom-modeline-evil-normal-state ((t (:foreground ,ui-accent :weight bold))))
   `(doom-modeline-evil-operator-state ((t (:foreground ,ui-warning :weight bold))))
   `(doom-modeline-evil-replace-state ((t (:foreground ,ui-error :weight bold))))
   `(doom-modeline-evil-visual-state ((t (:foreground ,ui-link :weight bold))))
   `(doom-modeline-highlight ((t (:foreground ,ui-accent))))
   `(doom-modeline-input-method ((t (:foreground ,ui-accent))))
   `(doom-modeline-panel ((t (:foreground ,ui-accent))))
   `(doom-modeline-project-dir ((t (:foreground ,ui-accent :weight bold))))
   `(doom-modeline-project-root-dir ((t (:foreground ,ui-accent))))

   ;; === Ediff ===
   `(ediff-current-diff-A ((t (:foreground ,ui-active-text-fg :background ,ui-active-text-bg :extend t))))
   `(ediff-current-diff-B ((t (:foreground ,ui-tooltip-fg :background ,ui-tooltip-bg :extend t))))
   `(ediff-current-diff-C ((t (:foreground ,ui-button-fg :background ,ui-button-bg :extend t))))
   `(ediff-even-diff-A ((t (:background ,ui-bg-dark :extend t))))
   `(ediff-even-diff-B ((t (:background ,ui-bg-dark :extend t))))
   `(ediff-even-diff-C ((t (:background ,ui-bg-dark :extend t))))
   `(ediff-fine-diff-A ((t (:background ,ui-active-text-bg :weight bold :underline t :extend t))))
   `(ediff-fine-diff-B ((t (:background ,ui-tooltip-bg :weight bold :underline t :extend t))))
   `(ediff-fine-diff-C ((t (:background ,ui-button-bg :weight bold :underline t :extend t))))
   `(ediff-odd-diff-A ((t (:background ,ui-bg-dark :extend t))))
   `(ediff-odd-diff-B ((t (:background ,ui-bg-dark :extend t))))
   `(ediff-odd-diff-C ((t (:background ,ui-bg-dark :extend t))))

   ;; === Eldoc ===
   `(eldoc-highlight-function-argument ((t (:foreground ,ui-accent :weight bold))))

   ;; === Elfeed ===
   `(elfeed-log-debug-level-face ((t (:foreground ,syntax-keyword))))
   `(elfeed-log-error-level-face ((t (:foreground ,ui-error))))
   `(elfeed-log-info-level-face ((t (:foreground ,ui-info))))
   `(elfeed-log-warn-level-face ((t (:foreground ,ui-warning))))
   `(elfeed-search-date-face ((t (:foreground ,ui-info))))
   `(elfeed-search-feed-face ((t (:foreground ,ui-accent))))
   `(elfeed-search-filter-face ((t (:foreground ,syntax-keyword))))
   `(elfeed-search-tag-face ((t (:foreground ,ui-info))))
   `(elfeed-search-title-face ((t (:foreground ,ui-fg-dim))))
   `(elfeed-search-unread-count-face ((t (:foreground ,ui-accent :weight bold))))
   `(elfeed-search-unread-title-face ((t (:foreground ,ui-fg :weight bold))))

   ;; === Cider ===
   `(cider-result-overlay-face ((t (:foreground ,ui-success :background ,ui-bg-dark :box (:line-width -1 :color ,ui-border)))))
   `(cider-deprecated-face ((t (:foreground ,ui-fg-dim :strike-through ,ui-border))))
   `(cider-enlightened-face ((t (:foreground ,ui-warning :weight bold))))
   `(cider-error-highlight-face ((t (:underline (:style wave :color ,ui-error)))))
   `(cider-warning-highlight-face ((t (:underline (:style wave :color ,ui-warning)))))
   `(cider-fringe-good-face ((t (:foreground ,ui-success))))
   `(cider-repl-prompt-face ((t (:foreground ,ui-accent :weight bold))))
   `(cider-repl-stderr-face ((t (:foreground ,ui-error))))
   `(cider-repl-stdout-face ((t (:foreground ,ui-success))))
   `(cider-test-failure-face ((t (:foreground ,ui-error :weight bold))))
   `(cider-test-success-face ((t (:foreground ,ui-success :weight bold))))

   ;; === Evil ===
   `(evil-ex-info ((t (:foreground ,ui-info :slant italic))))
   `(evil-ex-search ((t (:background ,ui-search-bg :foreground ,ui-search-fg :weight bold))))
   `(evil-ex-lazy-highlight ((t (:background ,ui-bg-light :foreground ,ui-fg))))
   `(evil-ex-substitute-matches ((t (:background ,ui-bg-light :foreground ,ui-error :weight bold :strike-through t))))
   `(evil-ex-substitute-replacement ((t (:background ,ui-bg-light :foreground ,ui-warning :weight bold))))
   `(evil-search-highlight-persist-highlight-face ((t (:background ,ui-search-bg :foreground ,ui-search-fg :weight bold))))

   ;; === Evil-goggles ===
   `(evil-goggles-default-face ((t (:background ,ui-bg-light :distant-foreground ,ui-bg :extend t))))

   ;; === Evil-mc ===
   `(evil-mc-cursor-bar-face ((t (:height 1 :background ,ui-link :foreground ,ui-bg))))
   `(evil-mc-cursor-default-face ((t (:background ,ui-link :foreground ,ui-bg :inverse-video unspecified))))
   `(evil-mc-cursor-hbar-face ((t (:underline (:color ,ui-accent)))))
   `(evil-mc-region-face ((t (:background ,ui-bg-light :distant-foreground ,ui-bg :extend t))))

   ;; === Evil-snipe ===
   `(evil-snipe-first-match-face ((t (:foreground ,ui-accent :background ,ui-selection-bg :weight bold))))
   `(evil-snipe-matches-face ((t (:foreground ,ui-accent :underline t :weight bold))))

   ;; === Flycheck (missing) ===
   `(flycheck-error-list-filename ((t (:foreground ,ui-accent))))
   `(flycheck-error-list-checker-name ((t (:foreground ,ui-accent))))
   `(flycheck-error-list-warning ((t (:foreground ,ui-warning))))
   `(flycheck-posframe-background-face ((t (:background ,ui-bg-dark))))
   `(flycheck-posframe-error-face ((t (:background ,ui-bg-dark :foreground ,ui-error))))
   `(flycheck-posframe-face ((t (:background ,ui-bg-dark :foreground ,ui-fg))))
   `(flycheck-posframe-info-face ((t (:background ,ui-bg-dark :foreground ,ui-info))))
   `(flycheck-posframe-warning-face ((t (:background ,ui-bg-dark :foreground ,ui-warning))))

   ;; === Flymake ===
   `(flymake-error ((t (:underline (:style wave :color ,ui-error)))))
   `(flymake-note ((t (:underline (:style wave :color ,ui-info)))))
   `(flymake-warning ((t (:underline (:style wave :color ,ui-warning)))))

   ;; === Flyspell ===
   `(flyspell-duplicate ((t (:underline (:style wave :color ,ui-warning)))))
   `(flyspell-incorrect ((t (:underline (:style wave :color ,ui-error)))))

   ;; === Flx-ido ===
   `(flx-highlight-face ((t (:weight bold :foreground ,ui-link :underline unspecified))))

   ;; === Forge ===
   `(forge-topic-closed ((t (:foreground ,ui-border :strike-through t))))
   `(forge-topic-label ((t (:box unspecified))))
   `(forge-issue-completed ((t (:foreground ,ui-border :strike-through t))))
   `(forge-pullreq-merged ((t (:foreground ,ui-accent))))
   `(forge-pullreq-open ((t (:foreground ,ui-info))))
   `(forge-pullreq-rejected ((t (:foreground ,ui-error :strike-through t))))

   ;; === Git-commit ===
   `(git-commit-comment-branch-local ((t (:foreground ,ui-info))))
   `(git-commit-comment-branch-remote ((t (:foreground ,ui-info))))
   `(git-commit-comment-detached ((t (:foreground ,ui-accent))))
   `(git-commit-comment-file ((t (:foreground ,ui-accent))))
   `(git-commit-comment-heading ((t (:foreground ,ui-accent))))
   `(git-commit-keyword ((t (:foreground ,ui-link :slant italic))))
   `(git-commit-known-pseudo-header ((t (:foreground ,ui-border :weight bold :slant italic))))
   `(git-commit-nonempty-second-line ((t (:foreground ,ui-error))))
   `(git-commit-overlong-summary ((t (:foreground ,ui-error :slant italic :weight bold))))
   `(git-commit-pseudo-header ((t (:foreground ,ui-border :slant italic))))
   `(git-commit-summary ((t (:foreground ,ui-accent))))

   ;; === Git-gutter ===
   `(git-gutter:added ((t (:foreground ,ui-success))))
   `(git-gutter:deleted ((t (:foreground ,ui-error))))
   `(git-gutter:modified ((t (:foreground ,ui-warning))))
   `(git-gutter+-added ((t (:foreground ,ui-success))))
   `(git-gutter+-deleted ((t (:foreground ,ui-error))))
   `(git-gutter+-modified ((t (:foreground ,ui-warning))))
   `(git-gutter-fr:added ((t (:foreground ,ui-success))))
   `(git-gutter-fr:deleted ((t (:foreground ,ui-error))))
   `(git-gutter-fr:modified ((t (:foreground ,ui-warning))))

   ;; === Goggles ===
   `(goggles-added ((t (:background ,ui-tooltip-bg))))
   `(goggles-changed ((t (:background ,ui-button-bg :distant-foreground ,ui-bg :extend t))))
   `(goggles-removed ((t (:background ,ui-active-text-bg :extend t))))

   ;; === Helpful ===
   `(helpful-heading ((t (:foreground ,ui-accent :weight bold :height 1.2))))

   ;; === Hi-lock ===
   `(hi-blue ((t (:background ,ui-selection-bg))))
   `(hi-blue-b ((t (:foreground ,ui-accent :weight bold))))
   `(hi-green ((t (:background ,ui-tooltip-bg))))
   `(hi-green-b ((t (:foreground ,ui-info :weight bold))))
   `(hi-magenta ((t (:background ,ui-button-bg))))
   `(hi-red-b ((t (:foreground ,ui-error :weight bold))))
   `(hi-yellow ((t (:background ,ui-button-bg))))

   ;; === Highlight-indentation ===
   `(highlight-indentation-current-column-face ((t (:background ,ui-line-highlight))))
   `(highlight-indentation-face ((t (:background ,ui-bg-dark :extend t))))
   `(highlight-indentation-guides-even-face ((t (:background ,ui-bg-dark :extend t))))
   `(highlight-indentation-guides-odd-face ((t (:background ,ui-bg-dark :extend t))))

   ;; === Highlight-numbers ===
   `(highlight-numbers-number ((t (:foreground ,ui-accent :weight bold))))

   ;; === Highlight-quoted ===
   `(highlight-quoted-quote ((t (:foreground ,ui-fg))))
   `(highlight-quoted-symbol ((t (:foreground ,ui-link))))

   ;; === Hydra ===
   `(hydra-face-amaranth ((t (:foreground ,ui-link :weight bold))))
   `(hydra-face-blue ((t (:foreground ,ui-accent :weight bold))))
   `(hydra-face-magenta ((t (:foreground ,ui-accent :weight bold))))
   `(hydra-face-red ((t (:foreground ,ui-error :weight bold))))
   `(hydra-face-teal ((t (:foreground ,ui-info :weight bold))))

   ;; === Iedit ===
   `(iedit-occurrence ((t (:foreground ,ui-button-fg :weight bold :background ,ui-button-bg))))
   `(iedit-read-only-occurrence ((t (:background ,ui-bg-light :distant-foreground ,ui-bg :extend t))))

   ;; === Imenu-list ===
   `(imenu-list-entry-face-0 ((t (:foreground ,ui-accent))))
   `(imenu-list-entry-face-1 ((t (:foreground ,ui-link))))
   `(imenu-list-entry-face-2 ((t (:foreground ,ui-info))))
   `(imenu-list-entry-subalist-face-0 ((t (:foreground ,ui-accent :weight bold))))
   `(imenu-list-entry-subalist-face-1 ((t (:foreground ,ui-link :weight bold))))
   `(imenu-list-entry-subalist-face-2 ((t (:foreground ,ui-info :weight bold))))

   ;; === Indent-guide ===
   `(indent-guide-face ((t (:background ,ui-bg-dark :extend t))))

   ;; === Ivy (missing) ===
   `(ivy-confirm-face ((t (:foreground ,ui-info))))
   `(ivy-highlight-face ((t (:foreground ,ui-accent))))
   `(ivy-match-required-face ((t (:foreground ,ui-error))))
   `(ivy-minibuffer-match-face-1 ((t (:foreground ,ui-accent :weight bold :underline t))))
   `(ivy-minibuffer-match-face-2 ((t (:foreground ,ui-link :weight semi-bold))))
   `(ivy-minibuffer-match-face-3 ((t (:foreground ,ui-info :weight semi-bold))))
   `(ivy-minibuffer-match-face-4 ((t (:foreground ,ui-link :weight semi-bold))))
   `(ivy-minibuffer-match-highlight ((t (:foreground ,ui-accent))))
   `(ivy-modified-buffer ((t (:weight bold :foreground ,ui-warning))))
   `(ivy-virtual ((t (:slant italic :foreground ,ui-fg))))
   `(ivy-posframe ((t (:background ,ui-bg-dark))))
   `(ivy-posframe-border ((t (:background ,ui-border))))

   ;; === Keycast ===
   `(keycast-command ((t (:foreground ,ui-fg))))
   `(keycast-key ((t (:foreground ,ui-accent :weight bold))))

   ;; === LSP ===

   ;; === LSP-UI ===
   `(lsp-headerline-breadcrumb-separator-face ((t (:foreground ,ui-fg-dim))))
   `(lsp-ui-doc-background ((t (:background ,ui-bg-dark :foreground ,ui-fg))))
   `(lsp-ui-doc-header ((t (:foreground ,ui-fg :background ,ui-line-highlight :weight bold))))
   `(lsp-ui-doc-highlight-hover ((t (:background ,ui-bg-light))))
   `(lsp-ui-doc-url ((t (:foreground ,ui-link :underline t))))
   `(lsp-ui-peek-filename ((t (:foreground ,ui-accent :weight bold))))
   `(lsp-ui-peek-header ((t (:foreground ,ui-fg :background ,ui-line-highlight :weight bold))))
   `(lsp-ui-peek-highlight ((t (:background ,ui-bg-light :foreground ,ui-bg :box t))))
   `(lsp-ui-peek-line-number ((t (:foreground ,ui-fg-dim))))
   `(lsp-ui-peek-list ((t (:background ,ui-bg-dark))))
   `(lsp-ui-peek-peek ((t (:background ,ui-bg-dark))))
   `(lsp-ui-peek-selection ((t (:foreground ,ui-selection-fg :background ,ui-selection-bg :weight bold))))
   `(lsp-ui-sideline-code-action ((t (:foreground ,ui-warning))))
   `(lsp-ui-sideline-current-symbol ((t (:foreground ,ui-fg :weight bold :box (:line-width -1 :color ,ui-fg)))))
   `(lsp-ui-sideline-symbol ((t (:foreground ,ui-fg-dim :box (:line-width -1 :color ,ui-fg-dim)))))
   `(lsp-ui-sideline-symbol-info ((t (:foreground ,ui-border :background ,ui-bg-dark :extend t))))
   `(lsp-ui-sideline-global ((t (:foreground ,ui-border))))

   ;; === Magit (missing faces) ===
   `(magit-bisect-bad ((t (:foreground ,ui-error))))
   `(magit-bisect-good ((t (:foreground ,ui-success))))
   `(magit-bisect-skip ((t (:foreground ,ui-warning))))
   `(magit-blame-date ((t (:foreground ,ui-fg-dim))))
   `(magit-blame-heading ((t (:foreground ,ui-accent :background ,ui-line-highlight :extend t))))
   `(magit-branch-current ((t (:foreground ,ui-accent :weight bold))))
   `(magit-branch-remote-head ((t (:foreground ,ui-success))))
   `(magit-cherry-equivalent ((t (:foreground ,ui-accent))))
   `(magit-cherry-unmatched ((t (:foreground ,ui-link))))
   `(magit-diff-file-heading ((t (:foreground ,ui-fg :weight bold :extend t))))
   `(magit-diff-file-heading-selection ((t (:foreground ,ui-button-fg :background ,ui-button-bg :weight bold :extend t))))
   `(magit-diff-lines-heading ((t (:foreground ,ui-selection-fg :background ,ui-selection-bg :extend t))))
   `(magit-diff-revision-summary ((t (:foreground ,ui-selection-fg :background ,ui-selection-bg :extend t :weight bold))))
   `(magit-diffstat-added ((t (:foreground ,ui-success))))
   `(magit-diffstat-removed ((t (:foreground ,ui-error))))
   `(magit-dimmed ((t (:foreground ,ui-border))))
   `(magit-filename ((t (:foreground ,ui-accent))))
   `(magit-header-line ((t (:background ,ui-bg-dark :foreground ,ui-accent :weight bold))))
   `(magit-log-author ((t (:foreground ,ui-accent))))
   `(magit-log-date ((t (:foreground ,ui-accent))))
   `(magit-log-graph ((t (:foreground ,ui-border))))
   `(magit-process-ng ((t (:foreground ,ui-error))))
   `(magit-process-ok ((t (:foreground ,ui-success))))
   `(magit-reflog-amend ((t (:foreground ,ui-link))))
   `(magit-reflog-checkout ((t (:foreground ,ui-accent))))
   `(magit-reflog-cherry-pick ((t (:foreground ,ui-info))))
   `(magit-reflog-commit ((t (:foreground ,ui-info))))
   `(magit-reflog-merge ((t (:foreground ,ui-info))))
   `(magit-reflog-other ((t (:foreground ,ui-link))))
   `(magit-reflog-rebase ((t (:foreground ,ui-link))))
   `(magit-reflog-remote ((t (:foreground ,ui-link))))
   `(magit-reflog-reset ((t (:foreground ,ui-error))))
   `(magit-refname ((t (:foreground ,ui-border))))
   `(magit-section-heading ((t (:foreground ,ui-accent :weight bold :extend t))))
   `(magit-section-heading-selection ((t (:foreground ,ui-accent :weight bold :extend t))))
   `(magit-section-secondary-heading ((t (:foreground ,ui-accent :weight bold :extend t))))
   `(magit-sequence-drop ((t (:foreground ,ui-error))))
   `(magit-sequence-head ((t (:foreground ,ui-accent))))
   `(magit-sequence-part ((t (:foreground ,ui-accent))))
   `(magit-sequence-stop ((t (:foreground ,ui-warning))))
   `(magit-signature-bad ((t (:foreground ,ui-error))))
   `(magit-signature-error ((t (:foreground ,ui-error))))
   `(magit-signature-expired ((t (:foreground ,ui-warning))))
   `(magit-signature-good ((t (:foreground ,ui-success))))
   `(magit-signature-revoked ((t (:foreground ,ui-error))))
   `(magit-signature-untrusted ((t (:foreground ,ui-warning))))
   `(magit-tag ((t (:foreground ,ui-link))))

   ;; === Make-mode ===
   `(makefile-targets ((t (:foreground ,ui-accent))))

   ;; === Marginalia (missing) ===
   `(marginalia-documentation ((t (:foreground ,ui-accent))))
   `(marginalia-file-name ((t (:foreground ,ui-accent))))
   `(marginalia-size ((t (:foreground ,ui-link))))
   `(marginalia-mode ((t (:foreground ,ui-accent))))
   `(marginalia-modified ((t (:foreground ,ui-warning))))
   `(marginalia-file-priv-read ((t (:foreground ,ui-info))))
   `(marginalia-file-priv-write ((t (:foreground ,ui-link))))
   `(marginalia-file-priv-exec ((t (:foreground ,ui-error))))

   ;; === Markdown (missing faces) ===
   `(markdown-blockquote-face ((t (:foreground ,ui-border :slant italic))))
   `(markdown-bold-face ((t (:foreground ,ui-fg :weight bold))))
   `(markdown-header-delimiter-face ((t (:foreground ,ui-accent :weight bold))))
   `(markdown-html-attr-name-face ((t (:foreground ,ui-accent))))
   `(markdown-html-attr-value-face ((t (:foreground ,ui-info))))
   `(markdown-html-entity-face ((t (:foreground ,ui-accent :slant italic))))
   `(markdown-html-tag-delimiter-face ((t (:foreground ,ui-fg))))
   `(markdown-html-tag-name-face ((t (:foreground ,ui-link))))
   `(markdown-italic-face ((t (:foreground ,ui-accent :slant italic))))
   `(markdown-link-face ((t (:foreground ,ui-accent :weight bold))))
   `(markdown-list-face ((t (:foreground ,ui-accent))))
   `(markdown-markup-face ((t (:foreground ,ui-fg))))
   `(markdown-metadata-key-face ((t (:foreground ,ui-accent))))
   `(markdown-reference-face ((t (:foreground ,ui-border))))
   `(markdown-url-face ((t (:foreground ,ui-info))))

   ;; === Message ===
   `(message-cited-text-1 ((t (:foreground ,ui-link))))
   `(message-cited-text-2 ((t (:foreground ,ui-accent))))
   `(message-cited-text-3 ((t (:foreground ,ui-info))))
   `(message-header-cc ((t (:foreground ,ui-link :weight bold))))
   `(message-header-name ((t (:foreground ,ui-accent))))
   `(message-header-newsgroups ((t (:foreground ,ui-link))))
   `(message-header-other ((t (:foreground ,ui-accent))))
   `(message-header-subject ((t (:foreground ,ui-accent :weight bold))))
   `(message-header-to ((t (:foreground ,ui-accent :weight bold))))
   `(message-header-xheader ((t (:foreground ,ui-border))))
   `(message-mml ((t (:foreground ,ui-border :slant italic))))
   `(message-separator ((t (:foreground ,ui-border))))

   ;; === Minimap ===
   `(minimap-active-region-background ((t (:background ,ui-bg-dark))))
   `(minimap-current-line-face ((t (:background ,ui-bg-light))))

   ;; === Multiple-cursors ===
   `(mc/cursor-face ((t (:background ,ui-link))))

   ;; === Neotree ===
   `(neo-dir-link-face ((t (:foreground ,ui-accent))))
   `(neo-expand-btn-face ((t (:foreground ,ui-accent))))
   `(neo-file-link-face ((t (:foreground ,ui-fg))))
   `(neo-root-dir-face ((t (:foreground ,ui-accent :background ,ui-bg))))
   `(neo-vc-added-face ((t (:foreground ,ui-success))))
   `(neo-vc-conflict-face ((t (:foreground ,ui-error :weight bold))))
   `(neo-vc-edited-face ((t (:foreground ,ui-warning))))
   `(neo-vc-ignored-face ((t (:foreground ,ui-border))))
   `(neo-vc-removed-face ((t (:foreground ,ui-error :strike-through t))))

   ;; === Nerd-icons ===
   `(nerd-icons-red ((t (:foreground ,ui-error))))
   `(nerd-icons-green ((t (:foreground ,ui-success))))
   `(nerd-icons-yellow ((t (:foreground ,ui-warning))))
   `(nerd-icons-blue ((t (:foreground ,pal-blue))))
   `(nerd-icons-purple ((t (:foreground ,syntax-keyword))))
   `(nerd-icons-orange ((t (:foreground ,pal-orange))))
   `(nerd-icons-cyan ((t (:foreground ,pal-cyan))))
   `(nerd-icons-pink ((t (:foreground ,pal-magenta))))
   `(nerd-icons-silver ((t (:foreground ,ui-fg-dim))))

   ;; === Notmuch ===
   `(notmuch-message-summary-face ((t (:foreground ,ui-border))))
   `(notmuch-search-count ((t (:foreground ,ui-border))))
   `(notmuch-search-date ((t (:foreground ,ui-accent))))
   `(notmuch-search-flagged-face ((t (:foreground ,ui-warning))))
   `(notmuch-search-matching-authors ((t (:foreground ,ui-accent))))
   `(notmuch-search-non-matching-authors ((t (:foreground ,ui-fg))))
   `(notmuch-search-subject ((t (:foreground ,ui-fg))))
   `(notmuch-search-unread-face ((t (:weight bold))))
   `(notmuch-tag-added ((t (:foreground ,ui-success :weight normal))))
   `(notmuch-tag-deleted ((t (:foreground ,ui-error :weight normal))))
   `(notmuch-tag-face ((t (:foreground ,ui-link :weight normal))))
   `(notmuch-tag-flagged ((t (:foreground ,ui-link :weight normal))))
   `(notmuch-tag-unread ((t (:foreground ,ui-link :weight normal))))
   `(notmuch-tree-match-author-face ((t (:foreground ,ui-accent :weight bold))))
   `(notmuch-tree-match-date-face ((t (:foreground ,ui-accent :weight bold))))
   `(notmuch-tree-match-face ((t (:foreground ,ui-fg))))
   `(notmuch-tree-match-subject-face ((t (:foreground ,ui-fg))))
   `(notmuch-tree-match-tag-face ((t (:foreground ,ui-link))))
   `(notmuch-tree-match-tree-face ((t (:foreground ,ui-border))))
   `(notmuch-tree-no-match-author-face ((t (:foreground ,ui-accent))))
   `(notmuch-tree-no-match-date-face ((t (:foreground ,ui-accent))))
   `(notmuch-tree-no-match-face ((t (:foreground ,ui-border))))
   `(notmuch-tree-no-match-subject-face ((t (:foreground ,ui-border))))
   `(notmuch-tree-no-match-tag-face ((t (:foreground ,ui-link))))
   `(notmuch-tree-no-match-tree-face ((t (:foreground ,ui-link))))
   `(notmuch-wash-cited-text ((t (:foreground ,ui-border))))
   `(notmuch-wash-toggle-button ((t (:foreground ,ui-fg))))

   ;; === Orderless ===
   `(orderless-match-face-0 ((t (:foreground ,ui-accent :weight bold :underline t))))
   `(orderless-match-face-1 ((t (:foreground ,syntax-keyword :weight bold :underline t))))
   `(orderless-match-face-2 ((t (:foreground ,ui-info :weight bold :underline t))))
   `(orderless-match-face-3 ((t (:foreground ,ui-warning :weight bold :underline t))))

   ;; === Vertico ===
   `(vertico-current ((t (:background ,ui-bg-light :extend t))))
   `(vertico-group-title ((t (:foreground ,ui-accent :weight bold :slant italic))))
   `(vertico-group-separator ((t (:foreground ,ui-border :strike-through t))))
   `(vertico-multiline ((t (:foreground ,ui-fg-dim))))

   ;; === Objed ===
   `(objed-hl ((t (:background ,ui-bg-light :distant-foreground ,ui-bg :extend t))))
   `(objed-mode-line ((t (:foreground ,ui-link :weight bold))))

   ;; === Parenface ===
   `(paren-face ((t (:foreground ,ui-border))))

   ;; === Popup ===
   `(popup-face ((t (:background ,ui-bg-dark :foreground ,ui-fg))))
   `(popup-selection-face ((t (:background ,ui-selection-bg :foreground ,ui-selection-fg))))
   `(popup-tip-face ((t (:foreground ,ui-accent :background ,ui-line-highlight))))

   ;; === Re-builder ===
   `(reb-match-0 ((t (:foreground ,ui-error :inverse-video t))))
   `(reb-match-1 ((t (:foreground ,ui-info :inverse-video t))))
   `(reb-match-2 ((t (:foreground ,ui-link :inverse-video t))))
   `(reb-match-3 ((t (:foreground ,ui-accent :inverse-video t))))

   ;; === Selectrum ===
   `(selectrum-current-candidate ((t (:background ,ui-bg-light :distant-foreground unspecified :extend t))))

   ;; === Sh-script ===
   `(sh-heredoc ((t (:foreground ,ui-accent))))
   `(sh-quoted-exec ((t (:foreground ,ui-fg :weight bold))))

   ;; === Smerge ===
   `(smerge-base ((t (:background ,ui-selection-bg :foreground ,ui-selection-fg))))
   `(smerge-lower ((t (:background ,ui-tooltip-bg))))
   `(smerge-markers ((t (:background ,ui-bg-light :foreground ,ui-bg :distant-foreground ,ui-fg :weight bold))))
   `(smerge-mine ((t (:background ,ui-active-text-bg :foreground ,ui-active-text-fg))))
   `(smerge-other ((t (:background ,ui-tooltip-bg :foreground ,ui-tooltip-fg))))
   `(smerge-refined-added ((t (:background ,ui-tooltip-bg :foreground ,ui-tooltip-fg))))
   `(smerge-refined-removed ((t (:background ,ui-active-text-bg :foreground ,ui-active-text-fg))))
   `(smerge-upper ((t (:background ,ui-active-text-bg))))

   ;; === Solaire-mode ===
   `(solaire-default-face ((t (:background ,ui-bg-dark))))
   `(solaire-hl-line-face ((t (:background ,ui-bg-dark :extend t))))
   `(solaire-mode-line-face ((t (:background ,ui-bg-light :foreground ,ui-fg))))
   `(solaire-mode-line-inactive-face ((t (:background ,ui-bg-dark :foreground ,ui-fg-dim))))
   `(solaire-org-hide-face ((t (:foreground ,ui-bg))))

   ;; === Swiper ===
   `(swiper-line-face ((t (:background ,ui-bg-light :foreground ,ui-fg))))
   `(swiper-match-face-1 ((t (:background ,ui-line-highlight :foreground ,ui-fg-dim))))
   `(swiper-match-face-2 ((t (:background ,ui-search-bg :foreground ,ui-search-fg :weight bold))))
   `(swiper-match-face-3 ((t (:background ,ui-button-bg :foreground ,ui-button-fg :weight bold))))
   `(swiper-match-face-4 ((t (:background ,ui-tooltip-bg :foreground ,ui-tooltip-fg :weight bold))))

   ;; === Term (extended) ===
   `(term ((t (:foreground ,ui-fg :background ,ui-bg))))
   `(term-bold ((t (:weight bold))))
   `(term-color-bright-black ((t (:foreground "#6272a4" :background "#6272a4"))))
   `(term-color-bright-red ((t (:foreground "#ff6e6e" :background "#ff6e6e"))))
   `(term-color-bright-green ((t (:foreground "#69ff94" :background "#69ff94"))))
   `(term-color-bright-yellow ((t (:foreground "#ffffa5" :background "#ffffa5"))))
   `(term-color-bright-blue ((t (:foreground "#d6acff" :background "#d6acff"))))
   `(term-color-bright-magenta ((t (:foreground "#ff92df" :background "#ff92df"))))
   `(term-color-bright-cyan ((t (:foreground "#a4ffff" :background "#a4ffff"))))
   `(term-color-bright-white ((t (:foreground "#ffffff" :background "#ffffff"))))

   ;; === Transient ===
   `(transient-heading ((t (:foreground ,ui-accent :weight bold))))
   `(transient-key ((t (:foreground ,ui-link :weight bold :height 1.1))))
   `(transient-argument ((t (:foreground ,ui-success))))
   `(transient-value ((t (:foreground ,ui-success))))
   `(transient-inactive-argument ((t (:foreground ,ui-fg-dim))))
   `(transient-inactive-value ((t (:foreground ,ui-fg-dim))))
   `(transient-unreachable ((t (:foreground ,ui-border))))
   `(transient-unreachable-key ((t (:foreground ,ui-border))))
   `(transient-enabled-suffix ((t (:foreground ,ui-success :background ,ui-tooltip-bg))))
   `(transient-disabled-suffix ((t (:foreground ,ui-error :background ,ui-active-text-bg))))
   `(transient-separator ((t (:background ,ui-bg-dark :extend t))))
   `(transient-amaranth ((t (:foreground ,pal-orange :weight bold))))
   `(transient-blue ((t (:foreground ,pal-blue :weight bold))))
   `(transient-pink ((t (:foreground ,pal-magenta :weight bold))))
   `(transient-purple ((t (:foreground ,pal-magenta :weight bold))))
   `(transient-red ((t (:foreground ,ui-error :weight bold))))
   `(transient-teal ((t (:foreground ,pal-cyan :weight bold))))

   ;; === Treemacs ===
   `(treemacs-directory-face ((t (:foreground ,ui-fg))))
   `(treemacs-directory-collapsed-face ((t (:foreground ,ui-fg))))
   `(treemacs-file-face ((t (:foreground ,ui-fg))))
   `(treemacs-window-background-face ((t (:background ,ui-bg-dark))))
   `(treemacs-hl-line-face ((t (:background ,ui-bg-light :extend t))))
   `(treemacs-git-added-face ((t (:foreground ,ui-success))))
   `(treemacs-git-conflict-face ((t (:foreground ,ui-error))))
   `(treemacs-git-modified-face ((t (:foreground ,ui-warning))))
   `(treemacs-git-untracked-face ((t (:foreground ,ui-border))))
   `(treemacs-git-ignored-face ((t (:foreground ,ui-border))))
   `(treemacs-root-face ((t (:foreground ,ui-accent :weight bold :height 1.2))))
   `(treemacs-tags-face ((t (:foreground ,ui-info))))
   `(treemacs-help-title-face ((t (:foreground ,syntax-keyword :weight bold))))
   `(treemacs-help-column-face ((t (:foreground ,ui-accent))))
   `(treemacs-on-success-pulse-face ((t (:background ,ui-tooltip-bg))))
   `(treemacs-on-failure-pulse-face ((t (:background ,ui-active-text-bg))))

   ;; === Tree-sitter-hl ===
   `(tree-sitter-hl-face:function ((t (:foreground ,syntax-function))))
   `(tree-sitter-hl-face:function.call ((t (:foreground ,syntax-function))))
   `(tree-sitter-hl-face:function.builtin ((t (:foreground ,syntax-function))))
   `(tree-sitter-hl-face:function.special ((t (:foreground ,syntax-keyword :weight bold))))
   `(tree-sitter-hl-face:function.macro ((t (:foreground ,syntax-keyword :weight bold))))
   `(tree-sitter-hl-face:method ((t (:foreground ,syntax-function))))
   `(tree-sitter-hl-face:method.call ((t (:foreground ,syntax-function))))
   `(tree-sitter-hl-face:type ((t (:foreground ,syntax-type))))
   `(tree-sitter-hl-face:type.parameter ((t (:foreground ,ui-fg-dim))))
   `(tree-sitter-hl-face:type.argument ((t (:foreground ,syntax-type))))
   `(tree-sitter-hl-face:type.builtin ((t (:foreground ,syntax-type))))
   `(tree-sitter-hl-face:type.super ((t (:foreground ,syntax-type))))
   `(tree-sitter-hl-face:constructor ((t (:foreground ,syntax-function))))
   `(tree-sitter-hl-face:variable ((t (:foreground ,syntax-variable))))
   `(tree-sitter-hl-face:variable.parameter ((t (:foreground ,ui-fg-dim))))
   `(tree-sitter-hl-face:variable.builtin ((t (:foreground ,syntax-variable))))
   `(tree-sitter-hl-face:variable.special ((t (:foreground ,syntax-keyword))))
   `(tree-sitter-hl-face:property ((t (:foreground ,syntax-attribute))))
   `(tree-sitter-hl-face:property.definition ((t (:foreground ,ui-fg-dim))))
   `(tree-sitter-hl-face:comment ((t (:foreground ,syntax-comment :slant italic))))
   `(tree-sitter-hl-face:doc ((t (:foreground ,syntax-comment :slant italic))))
   `(tree-sitter-hl-face:string ((t (:foreground ,syntax-string))))
   `(tree-sitter-hl-face:string.special ((t (:foreground ,syntax-string))))
   `(tree-sitter-hl-face:escape ((t (:foreground ,syntax-keyword))))
   `(tree-sitter-hl-face:embedded ((t (:foreground ,ui-fg))))
   `(tree-sitter-hl-face:keyword ((t (:foreground ,syntax-keyword :weight bold))))
   `(tree-sitter-hl-face:operator ((t (:foreground ,syntax-operator))))
   `(tree-sitter-hl-face:label ((t (:foreground ,ui-fg))))
   `(tree-sitter-hl-face:constant ((t (:foreground ,syntax-constant :weight bold))))
   `(tree-sitter-hl-face:constant.builtin ((t (:foreground ,syntax-constant))))
   `(tree-sitter-hl-face:number ((t (:foreground ,syntax-number))))
   `(tree-sitter-hl-face:punctuation ((t (:foreground ,ui-fg-dim))))
   `(tree-sitter-hl-face:punctuation.bracket ((t (:foreground ,ui-fg-dim))))
   `(tree-sitter-hl-face:punctuation.delimiter ((t (:foreground ,ui-fg-dim))))
   `(tree-sitter-hl-face:punctuation.special ((t (:foreground ,syntax-keyword))))
   `(tree-sitter-hl-face:tag ((t (:foreground ,syntax-type))))
   `(tree-sitter-hl-face:attribute ((t (:foreground ,syntax-attribute))))

   ;; === Typescript-mode ===
   `(typescript-jsdoc-tag ((t (:foreground ,ui-border))))
   `(typescript-jsdoc-type ((t (:foreground ,ui-border))))
   `(typescript-jsdoc-value ((t (:foreground ,ui-border))))

   ;; === Undo-tree ===
   `(undo-tree-visualizer-active-branch-face ((t (:foreground ,ui-accent))))
   `(undo-tree-visualizer-current-face ((t (:foreground ,ui-info :weight bold))))
   `(undo-tree-visualizer-default-face ((t (:foreground ,ui-border))))
   `(undo-tree-visualizer-register-face ((t (:foreground ,ui-link))))
   `(undo-tree-visualizer-unmodified-face ((t (:foreground ,ui-border))))

   ;; === Volatile-highlights ===
   `(vhl/default-face ((t (:background ,ui-bg-light))))

   ;; === Vterm ===
   `(vterm ((t (:foreground ,ui-fg :background ,ui-bg))))
   `(vterm-color-black ((t (:background ,pal-black :foreground ,pal-black))))
   `(vterm-color-blue ((t (:background ,pal-blue :foreground ,pal-blue))))
   `(vterm-color-cyan ((t (:background ,pal-cyan :foreground ,pal-cyan))))
   `(vterm-color-default ((t (:background ,ui-fg :foreground ,ui-fg))))
   `(vterm-color-green ((t (:background ,pal-green :foreground ,pal-green))))
   `(vterm-color-magenta ((t (:background ,pal-magenta :foreground ,pal-magenta))))
   `(vterm-color-purple ((t (:background ,pal-magenta :foreground ,pal-magenta))))
   `(vterm-color-red ((t (:background ,pal-red :foreground ,pal-red))))
   `(vterm-color-white ((t (:background ,pal-white :foreground ,pal-white))))
   `(vterm-color-yellow ((t (:background ,pal-yellow :foreground ,pal-yellow))))

   ;; === Web-mode ===
   `(web-mode-error-face ((t (:foreground ,ui-error :underline t))))
   `(web-mode-warning-face ((t (:foreground ,ui-warning :underline t))))
   `(web-mode-preprocessor-face ((t (:foreground ,syntax-keyword))))
   `(web-mode-block-delimiter-face ((t (:foreground ,ui-fg-dim))))
   `(web-mode-block-control-face ((t (:foreground ,syntax-keyword))))
   `(web-mode-builtin-face ((t (:foreground ,syntax-function))))
   `(web-mode-symbol-face ((t (:foreground ,syntax-constant))))
   `(web-mode-doctype-face ((t (:foreground ,syntax-comment))))
   `(web-mode-html-tag-face ((t (:foreground ,syntax-type))))
   `(web-mode-html-tag-custom-face ((t (:foreground ,syntax-type))))
   `(web-mode-html-tag-unclosed-face ((t (:foreground ,ui-error :underline t))))
   `(web-mode-html-tag-namespaced-face ((t (:foreground ,syntax-type))))
   `(web-mode-html-tag-bracket-face ((t (:foreground ,ui-fg-dim))))
   `(web-mode-html-attr-name-face ((t (:foreground ,syntax-attribute))))
   `(web-mode-html-attr-custom-face ((t (:foreground ,syntax-attribute :slant italic))))
   `(web-mode-html-attr-engine-face ((t (:foreground ,syntax-attribute))))
   `(web-mode-html-attr-equal-face ((t (:foreground ,ui-fg-dim))))
   `(web-mode-html-attr-value-face ((t (:foreground ,syntax-string))))
   `(web-mode-block-attr-name-face ((t (:foreground ,syntax-attribute))))
   `(web-mode-block-attr-value-face ((t (:foreground ,syntax-string))))
   `(web-mode-variable-name-face ((t (:foreground ,syntax-variable))))
   `(web-mode-css-selector-face ((t (:foreground ,syntax-function))))
   `(web-mode-css-selector-class-face ((t (:foreground ,syntax-type))))
   `(web-mode-css-selector-tag-face ((t (:foreground ,syntax-function))))
   `(web-mode-css-pseudo-class-face ((t (:foreground ,syntax-keyword))))
   `(web-mode-css-at-rule-face ((t (:foreground ,syntax-keyword))))
   `(web-mode-css-property-name-face ((t (:foreground ,syntax-attribute))))
   `(web-mode-css-color-face ((t (:foreground ,syntax-constant))))
   `(web-mode-css-priority-face ((t (:foreground ,syntax-constant :weight bold))))
   `(web-mode-css-function-face ((t (:foreground ,syntax-function))))
   `(web-mode-css-variable-face ((t (:foreground ,syntax-variable))))
   `(web-mode-function-name-face ((t (:foreground ,syntax-function))))
   `(web-mode-filter-face ((t (:foreground ,syntax-function))))
   `(web-mode-function-call-face ((t (:foreground ,syntax-function))))
   `(web-mode-string-face ((t (:foreground ,syntax-string))))
   `(web-mode-block-string-face ((t (:inherit web-mode-string-face))))
   `(web-mode-part-string-face ((t (:inherit web-mode-string-face))))
   `(web-mode-javascript-string-face ((t (:inherit web-mode-string-face))))
   `(web-mode-css-string-face ((t (:inherit web-mode-string-face))))
   `(web-mode-json-key-face ((t (:foreground ,syntax-attribute))))
   `(web-mode-json-context-face ((t (:foreground ,syntax-keyword))))
   `(web-mode-json-string-face ((t (:inherit web-mode-string-face))))
   `(web-mode-comment-face ((t (:foreground ,syntax-comment :slant italic))))
   `(web-mode-block-comment-face ((t (:inherit web-mode-comment-face))))
   `(web-mode-part-comment-face ((t (:inherit web-mode-comment-face))))
   `(web-mode-json-comment-face ((t (:inherit web-mode-comment-face))))
   `(web-mode-javascript-comment-face ((t (:inherit web-mode-comment-face))))
   `(web-mode-css-comment-face ((t (:inherit web-mode-comment-face))))
   `(web-mode-annotation-face ((t (:foreground ,syntax-comment))))
   `(web-mode-annotation-tag-face ((t (:foreground ,ui-fg-dim))))
   `(web-mode-annotation-type-face ((t (:foreground ,syntax-type))))
   `(web-mode-annotation-value-face ((t (:foreground ,syntax-string))))
   `(web-mode-annotation-html-face ((t (:foreground ,syntax-comment))))
   `(web-mode-constant-face ((t (:foreground ,syntax-constant))))
   `(web-mode-type-face ((t (:foreground ,syntax-type))))
   `(web-mode-keyword-face ((t (:foreground ,syntax-keyword :weight bold))))
   `(web-mode-param-name-face ((t (:foreground ,syntax-variable))))
   `(web-mode-whitespace-face ((t (:foreground ,ui-error :background ,ui-active-text-bg))))
   `(web-mode-inlay-face ((t (:background ,ui-bg-dark))))
   `(web-mode-block-face ((t (:inherit web-mode-inlay-face))))
   `(web-mode-part-face ((t (:inherit web-mode-inlay-face))))
   `(web-mode-script-face ((t (:inherit web-mode-inlay-face))))
   `(web-mode-style-face ((t (:inherit web-mode-inlay-face))))
   `(web-mode-folded-face ((t (:foreground ,ui-fg-dim :underline t))))
   `(web-mode-current-element-highlight-face ((t (:background ,ui-bg-light))))
   `(web-mode-current-column-highlight-face ((t (:background ,ui-line-highlight))))
   `(web-mode-comment-keyword-face ((t (:foreground ,syntax-keyword :weight bold))))
   `(web-mode-sql-keyword-face ((t (:foreground ,syntax-keyword))))
   `(web-mode-html-entity-face ((t (:foreground ,syntax-constant :slant italic))))

   ;; === Wgrep ===
   `(wgrep-delete-face ((t (:foreground ,ui-active-text-fg :background ,ui-active-text-bg))))
   `(wgrep-done-face ((t (:foreground ,ui-success))))
   `(wgrep-face ((t (:weight bold :foreground ,ui-tooltip-fg :background ,ui-tooltip-bg))))
   `(wgrep-file-face ((t (:foreground ,ui-border))))
   `(wgrep-reject-face ((t (:foreground ,ui-error :weight bold))))

   ;; === Which-func ===
   `(which-func ((t (:foreground ,ui-accent))))

   ;; === Which-key (missing) ===

   ;; === Whitespace ===
   `(whitespace-empty ((t (:background ,ui-line-highlight))))
   `(whitespace-indentation ((t (:foreground ,ui-border :background ,ui-line-highlight))))
   `(whitespace-line ((t (:background ,ui-bg-dark :foreground ,ui-error :weight bold))))
   `(whitespace-newline ((t (:foreground ,ui-border))))
   `(whitespace-space ((t (:foreground ,ui-border))))
   `(whitespace-tab ((t (:foreground ,ui-border :background ,ui-line-highlight))))
   `(whitespace-trailing ((t (:background ,ui-active-text-bg))))

   ;; === Widget ===
   `(widget-button ((t (:foreground ,ui-fg :weight bold))))
   `(widget-button-pressed ((t (:foreground ,ui-accent))))
   `(widget-documentation ((t (:foreground ,ui-info))))
   `(widget-field ((t (:foreground ,ui-fg :background ,ui-bg-dark :extend unspecified))))
   `(widget-inactive ((t (:foreground ,ui-border :background ,ui-bg-dark))))
   `(widget-single-line-field ((t (:foreground ,ui-fg :background ,ui-bg-dark))))

   ;; === Yasnippet ===
   `(yas-field-highlight-face ((t (:foreground ,ui-tooltip-fg :background ,ui-tooltip-bg :weight bold))))

   ;; === Mu4e ===
   `(mu4e-forwarded-face ((t (:foreground ,ui-accent))))
   `(mu4e-header-key-face ((t (:foreground ,ui-accent :weight bold))))
   `(mu4e-header-title-face ((t (:foreground ,ui-accent))))
   `(mu4e-highlight-face ((t (:foreground ,ui-accent :weight bold))))
   `(mu4e-link-face ((t (:foreground ,ui-accent :underline t))))
   `(mu4e-replied-face ((t (:foreground ,ui-info))))
   `(mu4e-title-face ((t (:foreground ,ui-accent :weight bold))))
   `(mu4e-unread-face ((t (:foreground ,ui-accent :weight bold))))
   `(mu4e-column-faces-date ((t (:foreground ,ui-accent))))
   `(mu4e-column-faces-flags ((t (:foreground ,ui-link))))
   `(mu4e-column-faces-to-from ((t (:foreground ,ui-accent))))

   ;; === ERC ===
   `(erc-action-face ((t (:weight bold))))
   `(erc-button ((t (:weight bold :underline t))))
   `(erc-command-indicator-face ((t (:weight bold))))
   `(erc-current-nick-face ((t (:foreground ,ui-info :weight bold))))
   `(erc-default-face ((t (:background ,ui-bg :foreground ,ui-fg))))
   `(erc-direct-msg-face ((t (:foreground ,ui-link))))
   `(erc-error-face ((t (:foreground ,ui-error))))
   `(erc-header-line ((t (:background ,ui-bg-dark :foreground ,ui-accent))))
   `(erc-input-face ((t (:foreground ,ui-info))))
   `(erc-my-nick-face ((t (:foreground ,ui-info :weight bold))))
   `(erc-my-nick-prefix-face ((t (:foreground ,ui-info :weight bold))))
   `(erc-nick-default-face ((t (:weight bold))))
   `(erc-nick-msg-face ((t (:foreground ,ui-link))))
   `(erc-nick-prefix-face ((t (:background ,ui-bg :foreground ,ui-fg))))
   `(erc-notice-face ((t (:foreground ,ui-border))))
   `(erc-prompt-face ((t (:foreground ,ui-accent :weight bold))))
   `(erc-timestamp-face ((t (:foreground ,ui-accent :weight bold))))

   ;; === Nano-modeline ===
   `(nano-modeline-active-name ((t (:foreground ,ui-fg :weight bold))))
   `(nano-modeline-inactive-name ((t (:foreground ,ui-fg-dim :weight bold))))
   `(nano-modeline-active-primary ((t (:foreground ,ui-accent))))
   `(nano-modeline-inactive-primary ((t (:foreground ,ui-fg-dim))))
   `(nano-modeline-active-secondary ((t (:foreground ,ui-accent :weight bold))))
   `(nano-modeline-inactive-secondary ((t (:foreground ,ui-fg-dim :weight bold))))
   `(nano-modeline-active-status-RO ((t (:background ,ui-button-bg :foreground ,ui-button-fg :weight bold))))
   `(nano-modeline-inactive-status-RO ((t (:background ,ui-line-highlight :foreground ,ui-fg-dim :weight bold))))
   `(nano-modeline-active-status-RW ((t (:background ,ui-selection-bg :foreground ,ui-selection-fg :weight bold))))
   `(nano-modeline-inactive-status-RW ((t (:background ,ui-line-highlight :foreground ,ui-fg-dim :weight bold))))
   `(nano-modeline-active-status-** ((t (:background ,ui-active-text-bg :foreground ,ui-active-text-fg :weight bold))))
   `(nano-modeline-inactive-status-** ((t (:background ,ui-line-highlight :foreground ,ui-fg-dim :weight bold))))

   ;; === Tab-line (missing) ===
   `(tab-line-close-highlight ((t (:foreground ,ui-error))))

   ;; === Centaur-tabs (missing) ===
   `(centaur-tabs-close-mouse-face ((t (:foreground ,ui-accent))))
   `(centaur-tabs-close-selected ((t (:background ,ui-bg-light :foreground ,ui-fg))))
   `(centaur-tabs-close-unselected ((t (:background ,ui-bg-dark :foreground ,ui-border))))
   `(centaur-tabs-modified-marker-selected ((t (:background ,ui-bg-light :foreground ,ui-accent))))
   `(centaur-tabs-modified-marker-unselected ((t (:background ,ui-bg-dark :foreground ,ui-accent))))
   `(centaur-tabs-name-mouse-face ((t (:foreground ,ui-accent :weight bold :underline t))))

   ;; === Powerline ===
   `(powerline-active0 ((t (:background ,ui-bg-light :foreground ,ui-fg))))
   `(powerline-active1 ((t (:background ,ui-bg-light :foreground ,ui-fg))))
   `(powerline-active2 ((t (:background ,ui-bg-light :foreground ,ui-fg))))
   `(powerline-inactive0 ((t (:background ,ui-bg-dark :foreground ,ui-fg-dim))))
   `(powerline-inactive1 ((t (:background ,ui-bg-dark :foreground ,ui-fg-dim))))
   `(powerline-inactive2 ((t (:background ,ui-bg-dark :foreground ,ui-fg-dim))))

   ;; === Spaceline ===
   `(spaceline-evil-emacs ((t (:background ,ui-link))))
   `(spaceline-evil-insert ((t (:background ,ui-success))))
   `(spaceline-evil-motion ((t (:background ,ui-link))))
   `(spaceline-evil-normal ((t (:background ,ui-accent))))
   `(spaceline-evil-replace ((t (:background ,ui-error))))
   `(spaceline-evil-visual ((t (:background ,ui-bg-light))))
   `(spaceline-flycheck-error ((t (:foreground ,ui-error))))
   `(spaceline-flycheck-info ((t (:foreground ,ui-info))))
   `(spaceline-flycheck-warning ((t (:foreground ,ui-warning))))

   ;; === Smart-mode-line ===
   `(sml/charging ((t (:foreground ,ui-info))))
   `(sml/discharging ((t (:foreground ,ui-link :weight bold))))
   `(sml/filename ((t (:foreground ,ui-accent :weight bold))))
   `(sml/git ((t (:foreground ,ui-accent))))
   `(sml/modified ((t (:foreground ,ui-warning))))
   `(sml/outside-modified ((t (:foreground ,ui-warning))))
   `(sml/process ((t (:weight bold))))
   `(sml/read-only ((t (:foreground ,ui-link))))
   `(sml/sudo ((t (:foreground ,ui-error :weight bold))))
   `(sml/vc-edited ((t (:foreground ,ui-warning))))

   )

  ;; === Theme variables ===
  (custom-theme-set-variables
   'tinty
   `(ansi-color-names-vector [,ui-button-bg ,pal-red ,pal-green ,pal-yellow ,pal-blue ,pal-magenta ,pal-cyan ,ui-fg-dim])
   `(pdf-view-midnight-colors '(,ui-fg . ,ui-bg)))
  )

;; Org-mode settings
(with-eval-after-load 'org
  (setq org-hide-leading-stars t)
  (setq org-startup-indented t))

;;;###autoload
(when load-file-name
  (add-to-list 'custom-theme-load-path
               (file-name-as-directory (file-name-directory load-file-name))))

(provide-theme 'tinty)
;;; tinty-theme.el ends here
