;;; garden-icons.el --- nerd-font icon glyphs for the garden UIs -*- lexical-binding: t; -*-

;;; Commentary:

;; One place for every pictogram the garden dashboards use.  When
;; nerd-icons is available (and `garden-use-nerd-icons' is non-nil)
;; the UIs render single-width nerd-font glyphs, which align cleanly
;; in a monospace buffer; otherwise they fall back to the original
;; emoji.

;;; Code:

(require 'nerd-icons nil t)

(declare-function nerd-icons-mdicon "nerd-icons")

(defcustom garden-use-nerd-icons t
  "Whether garden UIs render nerd-font glyphs instead of emoji."
  :type 'boolean :group 'garden)

(defconst garden-icon-alist
  '((garden   "nf-md-flower_outline"    "✦")
    (fleet    "nf-md-ferry"             "🚢")
    (inbox    "nf-md-inbox_arrow_down"  "📥")
    (import   "nf-md-import"            "⇨")
    (classify "nf-md-tag_outline"       "🏷")
    (graduate "nf-md-school"            "✓")
    (delete   "nf-md-trash_can_outline" "🗑")
    (return   "nf-md-undo_variant"      "↩")
    (preview  "nf-md-eye_outline"       "👁")
    (refresh  "nf-md-refresh"           "↻")
    (cog      "nf-md-cog_outline"       "⚙")
    (tools    "nf-md-hammer_wrench"     "🛠")
    (link     "nf-md-link_variant"      "🔗")
    (web      "nf-md-spider_web"        "🕸")
    (dice     "nf-md-dice_multiple"     "✦")
    (sprout   "nf-md-sprout"            "🌱")
    (leaf     "nf-md-leaf"              "🌿")
    (grass    "nf-md-grass"             "🌾")
    (tree     "nf-md-tree"              "🌳")
    (fallen   "nf-md-leaf_maple"        "🍂")
    (note     "nf-md-note_text_outline" "📝")
    (search   "nf-md-magnify"           "🔍")
    (grep     "nf-md-text_search"       "🔎")
    (publish  "nf-md-publish"           "🚀")
    (sparkle  "nf-md-shimmer"           "✨")
    (star     "nf-md-star_four_points"  "✦")
    (up       "nf-md-arrow_up_bold"     "▲")
    (down     "nf-md-arrow_down_bold"   "▼"))
  "Mapping of semantic icon names to (NERD-GLYPH EMOJI-FALLBACK).")

(defun garden-icon (name)
  "Return the glyph string for the semantic icon NAME.
NAME is a key of `garden-icon-alist'.  Returns a propertized
nerd-font glyph when available, the emoji fallback otherwise."
  (let ((entry (alist-get name garden-icon-alist)))
    (unless entry (error "garden: unknown icon %s" name))
    (if (and garden-use-nerd-icons (fboundp 'nerd-icons-mdicon))
        (or (nerd-icons-mdicon (car entry))
            (cadr entry))
      (cadr entry))))

(provide 'garden-icons)
;;; garden-icons.el ends here
