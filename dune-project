(lang dune 3.20)

(name markdown_monolith)

(generate_opam_files true)

(source
 (github Durbatuluk1701/markdown_monolith))

(authors "Will Thomas <30wthomas@gmail.com>")

(maintainers "Will Thomas <30wthomas@gmail.com>")

(license MIT)

(version 0.1.1)

(documentation https://durbatuluk1701.github.io/markdown_monolith/)

(package
 (name markdown_monolith)
 (synopsis
  "Produce a single monolithic Markdown file by inlining linked files")
 (description
  "OCaml library and CLI to produce a single monolithic Markdown file by parsing with Cmarkit, detecting link lists, and recursively inlining referenced files. Supports local and remote (HTTP/HTTPS) sources with configurable depth limits and deduplication.")
 (depends
  (lwt_ssl
   (>= 1.2.0))
  (ocaml
   (>= 4.14))
  cmarkit
  (cmdliner
   (>= 2.0.0))
  lwt
  (ounit2 :with-test)
  (cohttp-lwt-unix
   (>= 5.0)))
 (tags
  (markdown documentation tools)))
