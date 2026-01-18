(defvar modus-duskfox-palette
  (modus-themes-generate-palette
   '((bg-main "#232136")
     (fg-main "#e0def4")
     (red "#eb6f92")
     (green "#a3be8c")
     (yellow "#f6c177")
     (blue "#569fba")
     (magenta "#c4a7e7")
     (cyan "#9ccfd8"))
   nil
   nil
   '((cursor magenta)
     (bg-hl-line bg-cyan-nuanced)
     (bg-paren-match bg-magenta-subtle)
     (bg-region bg-blue-intense)
     (fg-region fg-dim)
     (bg-mode-line-active bg-blue-nuanced)
     (fg-mode-line-active blue-warmer)
     (border-mode-line-active blue-cooler))))

(modus-themes-theme
 'modus-duskfox
 'modus-duskfox-themes
 "Duskfox color scheme as Modus theme."
 'dark
 'modus-duskfox-palette
 nil
 nil)

(provide-theme 'modus-duskfox)
