;; -*- no-byte-compile: t; -*-
;;; app/takenote/packages.el

(package! anki-editor)
(package! org-roam-bibtex)
(package! citeproc)
(package! helm-bibtex)
(package! websocket)
(package! org-roam-ui
  :recipe (:host github :repo "org-roam/org-roam-ui" :files ("*.el" "out")))
