open Cmdliner
open Cmdliner.Term.Syntax

let exit_success = 0
let exit_write_failed = 1
let exit_monolith_failed = 2

let write_file file s =
  let write s oc =
    Out_channel.output_string oc s;
    exit_success
  in
  let binary_stdout () = Out_channel.(set_binary_mode stdout true) in
  try
    match file with
    | "-" ->
      binary_stdout ();
      write s Out_channel.stdout
    | file -> Out_channel.with_open_bin file (write s)
  with
  | Sys_error e ->
    Printf.printf "Writing to file %s failed with msg '%s'" file e;
    exit_write_failed
;;

let run
      input
      output
      allow_remote
      max_depth
      dedupe
      strict_commonmark
      add_newlines
      force_reconciliation
  =
  let cfg =
    Monolith.
      { allow_remote
      ; max_depth
      ; dedupe
      ; strict_commonmark
      ; add_newlines
      ; force_reconciliation
      }
  in
  match Monolith.monolith_of_file ~config:cfg input with
  | Error e ->
    Printf.printf "monolith-ification failed: %s\n" e;
    exit_monolith_failed
  | Ok out ->
    let out = Cmarkit_commonmark.of_doc out in
    write_file output out
;;

let infile =
  let doc =
    "$(docv) is the file to read from. (Note a remote file (i.e. \"https://...\" can be \
     provided here as well assuming `--allow-remote` is enabled.)"
  in
  Arg.(required & pos 0 (some string) None & info [] ~doc ~docv:"FILE")
;;

let outfile =
  let doc = "$(docv) is the file to write to. Use $(b,-) for $(b,stdout)" in
  Arg.(value & opt filepath "-" & info [ "o"; "output" ] ~doc ~docv:"FILE")
;;

let allow_remote_t =
  Arg.(value & flag & info [ "allow-remote" ] ~doc:"Enable fetching remote links")
;;

let max_depth_t =
  Arg.(
    value & opt int 10 & info [ "max-depth" ] ~doc:"Maximum recursion depth (default: 10)")
;;

let dedupe_t =
  Arg.(value & opt bool true & info [ "dedupe" ] ~doc:"Enable deduplication of files")
;;

let strict_commonmark_t =
  Arg.(
    value & flag & info [ "strict-commonmark" ] ~doc:"Enable strict CommonMark parsing")
;;

let add_newlines_t =
  Arg.(
    value
    & opt bool true
    & info [ "add-newlines" ] ~doc:"Add newlines between inlined content")
;;

let force_reconciliation_t =
  Arg.(
    value
    & flag
    & info
        [ "force-reconciliation" ]
        ~doc:"Force link reconciliation; error if headers missing")
;;

let cmd =
  let doc =
    "Produce a monolithic Markdown file by inlining linked files and reconciling paths."
  in
  let exits =
    Cmd.Exit.(
      info exit_write_failed ~doc:"Writing output file failed."
      :: info exit_monolith_failed ~doc:"Monolithification failed."
      :: defaults)
  in
  Cmd.make (Cmd.info "markdown_monolith" ~doc ~exits)
  @@
  let+ infile = infile
  and+ outfile = outfile
  and+ allow_remote_t = allow_remote_t
  and+ max_depth_t = max_depth_t
  and+ dedupe_t = dedupe_t
  and+ strict_commonmark_t = strict_commonmark_t
  and+ add_newlines_t = add_newlines_t
  and+ force_reconciliation_t = force_reconciliation_t in
  run
    infile
    outfile
    allow_remote_t
    max_depth_t
    dedupe_t
    strict_commonmark_t
    add_newlines_t
    force_reconciliation_t
;;

let main () = Cmd.eval' cmd
let () = if !Sys.interactive then () else exit (main ())
