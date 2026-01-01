(lang dune 3.20)

(name markdown_monolith)

(generate_opam_files true)

(source
 (github Durbatuluk1701/markdown_monolith))

(authors "Author Name <author@example.com>")

(maintainers "Maintainer Name <maintainer@example.com>")

(license LICENSE)

(documentation https://url/to/documentation)

(package
 (name markdown_monolith)
 (synopsis
  "Produce a single monolithic Markdown file by inlining linked files")
 (description
  "OCaml library + CLI to produce a single monolithic Markdown file by parsing with omd, detecting navigational TOC-like link lists, and inlining selected files. Remote inlining is opt-in.")
 (depends
  (ocaml
   (>= 4.14))
  (dune
   (>= 3.20))
  omd
  cmdliner
  lwt
  (cohttp-lwt-unix
   (>= 5.0)))
 (tags
  (markdown documentation tools)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
