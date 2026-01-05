(lang dune 3.20)

(name markdown_monolith)

(generate_opam_files true)

(source
 (github Durbatuluk1701/markdown_monolith))

(authors "Will Thomas <30wthomas@gmail.com>")

(maintainers "Will Thomas <30wthomas@gmail.com>")

(license LICENSE)

(documentation https://url/to/documentation)

(package
 (name markdown_monolith)
 (synopsis
  "Produce a single monolithic Markdown file by inlining linked files")
 (description
  "OCaml library + CLI to produce a single monolithic Markdown file by parsing with cmarkit, and inlining selected files.")
 (depends
  (lwt_ssl
   (>= 1.2.0))
  (ocaml
   (>= 4.14))
  (dune
   (>= 3.20))
  cmarkit
  cmdliner
  lwt
  (ounit2 :with-test)
  (cohttp-lwt-unix
   (>= 5.0)))
 (tags
  (markdown documentation tools)))