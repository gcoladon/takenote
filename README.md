# takenote

A Doom Emacs module for my way of taking notes

This module depends on your setting of these two variables, this is the way I do it in my config.el:

<pre>
(setq bibtex-completion-library-path "~/pdfs"
      bibtex-completion-bibliography (list "~/pdfs/references.bib"))
</pre>


My init file has this line in it:

<pre>
       (org +roam2 +noter)
</pre>



