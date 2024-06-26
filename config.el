;;; workflow.el -*- lexical-binding: t; -*-

(map! :leader
      :desc "Search on arXiv"             "s a" #'takenote-search-on-arxiv
      :desc "Search on scopus"            "s C" #'scopus-basic-search
      :desc "takenote-get-arxiv"          "r x" #'takenote-get-arxiv
      :desc "doi-utils-get-bibtex-pdf"    "r d" #'doi-utils-get-bibtex-entry-pdf
      :desc "orb-note-actions"            "r a" #'orb-note-actions
      :desc "org-noter-create-skeleton"   "r k" #'org-noter-create-skeleton
      :desc "org-noter"                   "r n" #'org-noter
      :desc "helm-bibtex"                 "r h" #'helm-bibtex)

(defun takenote-orb-my-slug (orig-fn title)
  "My version of Roam's title-to-slug to prefix data and chop legth"
  (let* ((today (format-time-string "%y%m%d"))
         (prefix (substring title 0 (min 6 (length title))))
         (prefixed_title (if (equal today prefix)
                             title
                           (concat today " " title)))
         (result (apply orig-fn (list prefixed_title)))
         (subs (substring result 0 (min 30 (length result)))))
    subs))
(advice-add 'org-roam--title-to-slug :around #'takenote-orb-my-slug)

(defun takenote-trim-slug (orig-fun &rest args)
  "Trim the slug to 23 characters"
  (let ((full-slug (apply orig-fun args)))
         (substring full-slug 0 (min 23 (length full-slug)))))

(advice-add 'org-roam-node-slug :around #'takenote-trim-slug)

(defun takenote-search-on-arxiv (start end)
  "Get the region, add arxiv to it, and search for it"
  (interactive "r")
  (+lookup/online (concat "arxiv " (buffer-substring-no-properties start end)) "Google"))

(defun takenote-capture-noter-file (key)
  (setq takenote-save-templates org-roam-capture-templates)
  (setq takenote-temp org-roam-capture-templates)
  ;; Does this logic only work as long as the desired template
  ;; is the last one in the list? If so, I may need to enhance this
  ;; logic at some point if that ever fails to hold true.
  (while
      (and (not (eq nil takenote-temp))
           (not (equal "n" (caar takenote-temp))))
    (setq takenote-temp (cdr takenote-temp)))
  (setq org-roam-capture-templates takenote-temp)
  (bibtex-completion-edit-notes (list key))
  (setq org-roam-capture-templates takenote-save-templates))

(defun takenote-get-arxiv ()
  "Use the defaults for all three variables, don't ask me!!"
  (interactive)
  (require 'org-ref)
  (bibtex-set-dialect 'BibTeX)
  (arxiv-get-pdf-add-bibtex-entry (arxiv-maybe-arxiv-id-from-current-kill)
                                  bibtex-completion-bibliography
                                  (concat bibtex-completion-library-path "/"))
  (takenote-capture-noter-file
   (save-window-excursion
     (find-file "~/org/roam/roam-pdfs/references.bib")
     (goto-char (point-max))
     (bibtex-beginning-of-entry)
     (re-search-forward bibtex-entry-maybe-empty-head)
     (if (match-beginning bibtex-key-in-head)
         (buffer-substring-no-properties
          (match-beginning bibtex-key-in-head)
          (match-end bibtex-key-in-head)))))
  (org-capture-finalize t)
  (end-of-buffer)
  (org-noter)
  ;; (other-window)
  ;; (org-noter-create-skeleton)
  )

(defun bibtex-autokey-wrapper (orig-fun &rest args)
  "Dynamically bind `bibtex-autokey-prefix-string' to current date."
  (let ((result
         (let ((bibtex-autokey-prefix-string (format-time-string "%y%m%d_")))
           (apply orig-fun args))))
    (substring result 0 (min 31 (length result)))))
  ;; (let* ((result
  ;;         (let ((bibtex-autokey-prefix-string (format-time-string "%y%m%d_")))
  ;;           (apply orig-fun args)))
  ;;        (draft
  ;;         (substring result 0 (min 31 (length result))))
  ;;        (len (length draft))
  ;;        (final (if (eq (substring draft (- len 1) len) "_")
  ;;                   (substring draft 0 (- len 1))
  ;;                 draft)))))

(advice-add 'bibtex-generate-autokey :around #'bibtex-autokey-wrapper)

(defun takenote-org-roam-protocol-get-pdf (info)
  "Process an org-protocol://roam-pdf?ref= style url with INFO.

It saves the PDF at the target location into ~/org/roam/roam-pdfs and also
creates a corresponding org-noter file

  javascript:location.href = \\='org-protocol://roam-pdf?template=r&url=\\='+ \\
        encodeURIComponent(location.href))"

  (interactive)
  (let ((url (plist-get info :url)))
    (unless url
      (user-error "No url provided"))
    (if (string-match-p "arxiv.org" url)
        (progn
          (kill-new url)
          (takenote-get-arxiv))
      (takenote-move-pdf-from-url-to-bibtex-standalone (plist-get info :url)))))

(after! org-protocol
  (use-package! org-roam-protocol)

  ;; This is my attempt at making a capture-PDF-into-org-roam utility,
  ;; to make it easier to capture research papers that I've been given a URL to

  (push '("org-roam-pdf"
          :protocol "roam-pdf"
          :function takenote-org-roam-protocol-get-pdf)
        org-protocol-protocol-alist))

(defun takenote-move-pdf-from-url-to-bibtex-standalone (pdf-url)
  "Try to simplify the incorporation of pdfs from a class into org-roam"
  (let* ((pdf-author (read-string "Author: "))
         (pdf-title (read-string "Title: "))
         (pdf-year (read-string "Year: "))
         (prefixed-fn (concat (format-time-string "%y%m%d_")
                              (downcase pdf-author)
                              (substring pdf-year 2)
                              ".pdf"))
         (bibtex-key (substring prefixed-fn 0 (- (length prefixed-fn) 4)))
         (dest-fn (concat bibtex-completion-library-path "/" prefixed-fn)))
    (url-copy-file pdf-url dest-fn)
    (save-window-excursion
      (find-file bibtex-completion-bibliography)
      (goto-char (point-max))
      (when (not (looking-at "^")) (insert "\n"))
      (insert (concat "@misc{" bibtex-key ",\n"
                      "  author          = {" pdf-author "},\n"
                      "  title           = {{" pdf-title "}},\n"
                      "  year            = {" pdf-year "},\n"
                      "  url             = {" pdf-url "}\n"
                      "}\n"))
      (save-buffer))
    (takenote-capture-noter-file bibtex-key)))

(defun takenote-move-pdf-from-file-to-bibtex-standalone (filename)
  "Try to simplify the incorporation of multiple articles by different authors into org-roam"
  (let* ((basename (car (reverse (split-string filename "/"))))
         (prompt (concat "Author(s) (last, first) for " basename ": "))
         (pdf-author (read-string prompt))
         (pdf-title (read-string "Article title: "))
         (pdf-year (read-string "Year: "))
         (pdf-journal (read-string "Journal: "))
         (key-slug (read-string "Key slug: "))
         (pref-key (concat (format-time-string "%y%m%d_")
                           (downcase (car (split-string pdf-author ",")))
                           (substring pdf-year 2)
                           "_" key-slug))
         (bibtex-key (substring pref-key 0 (min 30 (length pref-key))))
         (dest-fn (concat bibtex-completion-library-path "/" bibtex-key ".pdf")))
    (dired-create-files #'dired-rename-file "Move" (list filename)
                        (lambda (_from) dest-fn) t)
    (save-window-excursion
      (find-file bibtex-completion-bibliography)
      (goto-char (point-max))
      (when (not (looking-at "^")) (insert "\n"))
      (insert (concat "@article{" bibtex-key ",\n"
                      "  author          = {" pdf-author "},\n"
                      (unless (equal pdf-journal "") (concat "  journal            = {" pdf-journal "},\n"))
                      (when pdf-year (concat "  year            = {" pdf-year "},\n"))
                      "  title           = \"{{" pdf-title "}}\"\n"
                      "}\n"))
      (save-buffer))
    (takenote-capture-noter-file bibtex-key)))


(use-package! org-noter
  :after pdf-view
  :config
  (add-hook 'pdf-view-mode-hook 'pdf-view-fit-width-to-window))

(after! org-roam
  (org-roam-bibtex-mode))

(use-package! helm-bibtex)

;; following instructions from https://github.com/org-roam/org-roam-bibtex
(use-package! org-roam-bibtex
  :after org-roam
  ;; :hook (org-roam-mode . org-roam-bibtex-mode)
  :config
  (require 'org-ref)
  (require 'helm-bibtex)
  (bibtex-set-dialect 'BibTeX)
  (helm-add-action-to-source
   "Edit org-noter Notes"
   'helm-bibtex-edit-notes
   helm-source-bibtex
   0)
)

(define-key dired-mode-map "b" 'takenote-dispatch-pdf-capture)

(defun takenote-dispatch-pdf-capture (type)
  "Find out whether we're capturing a PDF that's distributed with a course
or a chapter of a book"
  (interactive
   (list
    (completing-read "What are these PDFs part of?: "
                     '("new book" "existing class" "existing key" "new articles"))))
  (cond ((equal type "existing class")
         (takenote-move-pdfs-into-existing-class))
        ((equal type "new book")
         (takenote-move-pdfs-into-new-book))
        ((equal type "new articles")
         (takenote-move-pdfs-from-files-into-new-articles))
        ((equal type "existing key")
         (takenote-move-pdfs-into-existing-key))))

(defun takenote-move-pdfs-into-existing-key ()
  "Ask which key to move this PDF into as a chapter"
  (let ((key-author-title (completing-read
                           "Which book shall this PDF be a chapter of? "
                           (mapcar
                            (lambda (elt)
                              (concat
                               (cdr (assoc "=key=" (cdr elt)))
                               ": "
                               (cdr (assoc "author" (cdr elt)))
                               " - "
                               (cdr (assoc "title" (cdr elt)))))
                            (seq-filter
                             (lambda (elt) (equal "book" (cdr (assoc "=type=" (cdr elt)))))
                             (bibtex-completion-candidates))))))
    (setq org-capture-link-is-already-stored t)
    (seq-do
     (lambda (file) (takenote-move-pdf-to-bibtex-crossref file (car (split-string key-author-title ":"))))
     ;; I reverse so that when helm-bibtex loads them all up,
     ;; they are in the right order
     (reverse (dired-get-marked-files nil nil nil nil t)))))


(defun takenote-move-pdfs-into-new-book ()
  "Inquire for the values that go into a book's bibtex entry, create the bibtex
entry, and pass that key into move-pdf-to-bibtex-crossref along with each of the
marked files"
  (let* ((author (read-string "Author(s) (last, first): "))
         (title (read-string "Book title: "))
         (year (read-string "Year: "))
         (pub (read-string "Publisher: "))
         (address (read-string "Publisher address or city: "))
         (isbn (read-string "ISBN: "))
         (pref-key (read-string "Bibtex key root: "))
         (trunc-key (substring pref-key 0 (min 23 (length pref-key))))
         (key (concat (format-time-string "%y%m%d_") trunc-key)))
    (save-window-excursion
      (find-file bibtex-completion-bibliography)
      (goto-char (point-max))
      (when (not (looking-at "^")) (insert "\n"))
      (insert (concat "@book{" key ",\n"
                      ;; If you try to get away with a single {}, the caps get messed up
                      "  author          = {" author "},\n"
                      "  title           = {" title "},\n"
                      "  year            = " year ",\n"
                      "  publisher       = {" pub "},\n"
                      "  address         = {" address "},\n"
                      "  isbn            = {" isbn "}\n"
                      "}\n"))
      (save-buffer))
    (setq org-capture-link-is-already-stored t)
    (let ((result (seq-map
                   (lambda (file) (takenote-move-pdf-to-bibtex-crossref file key))
                   ;; I reverse so that when helm-bibtex loads them all up,
                   ;; they are in the right order
                   (reverse (dired-get-marked-files nil nil nil nil t))) ))
      (message (concat  "Result from seq-map was " result)))))


(defun takenote-move-pdfs-from-files-into-new-articles ()
  (seq-do
   (lambda (file) (takenote-move-pdf-from-file-to-bibtex-standalone file))
   ;; I reverse so that when helm-bibtex loads them all up,
   ;; they are in the right order
   (reverse (dired-get-marked-files nil nil nil nil t))))


(defun takenote-move-pdfs-into-existing-class ()
  "Choose a _gatech_cs_ or _stan_cs_ bibtex entry for which to add one or more
inbook entries via takenote-move-pdf-to-bibtex-crossref"
  (let ((key (completing-read
              "Which class is this document for? "
              (seq-filter
               (lambda (elt) (or (string-match-p "_gatech_cs_" elt)
                                 ;; I would have used stanford but tag got too long
                                 (string-match-p "_stan_cs_" elt)))
               (mapcar
                (lambda (elt) (cdr (assoc "=key=" (cdr elt))))
                (seq-filter
                 (lambda (elt) (equal "book" (cdr (assoc "=type=" (cdr elt)))))
                 (bibtex-completion-candidates)))))))
    (setq org-capture-link-is-already-stored t)
    (seq-do
     (lambda (file) (takenote-move-pdf-to-bibtex-crossref file key))
     ;; I reverse so that when helm-bibtex loads them all up,
     ;; they are in the right order
     (reverse (dired-get-marked-files nil nil nil nil t)))))


(defun takenote-move-pdf-to-bibtex-crossref (file crossref)
  "Try to simplify the incorporation of pdfs from a class into org-roam"
  (let* ((basename (file-name-nondirectory file))
         (suffixless (substring basename 0 (- (length basename) 4)))
         (title-guess (mapconcat 'identity
                                 (mapcar (lambda (word) (if (< (length word) 4)
                                                            (upcase word)
                                                          (capitalize word)))
                                         (split-string suffixless "_")) " "))
         (title (read-string "Preferred title for this document: " title-guess))
         (pref-basename (read-string "Preferred base filename: " suffixless))
         (trunc-basename (substring pref-basename 0 (min 23 (length pref-basename))))
         ;; I kind of would like to trim off trailing _ for aesthetic reasons
         (prefixed-fn (concat (format-time-string "%y%m%d_") trunc-basename ".pdf"))
         (key (substring prefixed-fn 0 (- (length prefixed-fn) 4)))
         (dest-fn (concat bibtex-completion-library-path "/" prefixed-fn)))
    (dired-create-files #'dired-rename-file "Move" (list file)
                        (lambda (_from) dest-fn) t)
    (save-window-excursion
      (find-file bibtex-completion-bibliography)
      (goto-char (point-max))
      (when (not (looking-at "^")) (insert "\n"))
      (insert (concat "@inbook{" key ",\n"
                      ;; If you try to get away with a single {}, the caps get messed up
                      "  title           = \"{{" title "}}\",\n"
                      "  crossref        = {" crossref "}\n"
                      "}\n"))
      (save-buffer))
    (takenote-capture-noter-file key)))

;; Until I get it to work via org-protocol, use this!
;; (takenote-move-pdf-from-url-to-bibtex-standalone "https://jmlr.csail.mit.edu/papers/volume13/bergstra12a/bergstra12a.pdf")

;; I think this may be more complicated than I hoped it would be
;;
;; (setq org-id-method 'ts
;;       orb-preformat-keywords
;;       '(("citekey" . "=key=")
;;         "url" "file" "author-or-editor-abbrev" "keywords" "abstract" "author" "year")
;;       org-id-link-to-org-use-id t
;;       org-id-ts-format "%y%m%d_%H%M%S")

;; (add-to-list 'org-roam-capture-templates '(("n" "ref+noter" plain "%?" :if-new
;;       (file+head "roam-stem/${citekey}.org" "#+TITLE: %(car (split-string \"${author}\" \",\")) '%(substring \"${year}\" 2 4) - ${title}
;; #+ROAM_KEY: cite:${citekey}
;; #+ROAM_TAGS:

;; * %(car (split-string \"${author}\" \",\")) '%(substring \"${year}\" 2 4) - ${title}
;; :PROPERTIES:
;; :URL: ${url}
;; :AUTHOR: ${author-or-editor-abbrev}
;; :NOTER_DOCUMENT: ${file}
;; :NOTER_PAGE:
;; :END:
;; ** Abstract
;; ${abstract}
;; ") :unnarrowed t)))

(map! :leader
      :desc "Insert Anki note"            "i a" #'takenote-insert-anki-basic-note
      :desc "Push simple Anki notes"      "n p" #'takenote-push-to-anki
      :desc "Push complex Anki notes"     "n P" #'anki-editor-push-notes
      )

(defun takenote-insert-anki-basic-note ()
  "Insert an Anki 'Basic' note at point,
relying on deck and tags to be set at a higher heading"
  (interactive)
  (let* ((card-front (read-string "Front: "))
         (card-back (read-string "Back: ")))
    (org-insert-heading)
    (org-cycle)
    (insert (concat card-front
                    " "
                    card-back
                    "\n:PROPERTIES:\n"
                    ":ANKI_NOTE_TYPE: Basic\n"
                    ":CREATED: "
                    (format-time-string (org-time-stamp-format 'long 'inactive)
                                        (org-current-effective-time))
                    "\n:END:\n"))
    (org-insert-heading)
    (org-cycle)
    (insert "Front\n")
    (insert card-front)
    (org-insert-heading)
    (insert "Back\n")
    (insert card-back)
    (outline-up-heading 1)))

(defun takenote-push-to-anki ()
  "Process each line in the buffer one by one looking for Q&A of the simple form [WHI]...? ....,
that can be pushed to Anki without needing a tree of headings."
  (interactive)
  (anki-editor-mode)
  (save-excursion
    (let* ((acc 0))
      (goto-char (point-min))
      (while (not (eobp))
        (let* ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
          (if (string-match "^\\([WIH].*\\?\\) \\(.*\\)\." line)
              (let* ((front (match-string-no-properties 1 line))
                     (back (match-string-no-properties 2 line))
                     (org-trust-scanner-tags t)
                     (deck (org-entry-get-with-inheritance anki-editor-prop-deck))
                     (note-id "-1")
                     (note-type (org-entry-get-with-inheritance anki-editor-prop-note-type))
                     (tags (anki-editor--get-tags))
                     (fields `(("Front" . ,front) ("Back" . ,back))))
                ;; (defun anki-editor--set-note-id () nil)
                (unless deck (error "Deck property not found"))
                (unless note-type (error "Note type property not found"))
                (unless fields (error "Card fields not found"))
                (message (concat "Pushing note #" (cl-incf acc) ": " front))
                (anki-editor--create-note
                 `((deck . ,deck)
                   (note-id . "-1")
                   (note-type . ,note-type)
                   (tags . ,tags)
                   (fields . ,fields)))
                (insert "ANKIFIED "))))
        (forward-line 1))))
  (message (concat "Pushed " acc " notes to Anki.")))
