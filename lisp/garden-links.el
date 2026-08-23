;;; garden-links.el --- Denote links dynamic block helpers -*- lexical-binding: t; -*-

;; Thin wrappers around `denote-org' dynamic blocks.

;;; Code:

(require 'garden-core)

(declare-function denote-org-dblock-insert-links "denote-org")

;;;###autoload
(defun garden-insert-denote-links ()
  "Insert a `denote-links' dynamic block at point.
Prompts for a regexp and inserts a block that lists all Denote
notes whose file name matches it.  Use `org-update-dblock' or
`C-c C-c' on the block to refresh it later."
  (interactive)
  (require 'denote-org)
  (call-interactively #'denote-org-dblock-insert-links))

;;;###autoload
(defun garden-update-denote-links ()
  "Refresh every `denote-links' dynamic block in the current buffer."
  (interactive)
  (require 'denote-org)
  (org-update-all-dblocks))

(provide 'garden-links)
;;; garden-links.el ends here
