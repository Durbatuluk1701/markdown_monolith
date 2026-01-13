open Cmdliner

let write_file file s =
  let write file s oc =
    try `Ok (Out_channel.output_string oc s) with
    | Sys_error e -> `Error (false, Printf.sprintf "%s: %s" file e)
  in
  let binary_stdout () = Out_channel.(set_binary_mode stdout true) in
  try
    match file with
    | "-" ->
      binary_stdout ();
      write file s Out_channel.stdout
    | file -> Out_channel.with_open_bin file (write file s)
  with
  | Sys_error e -> `Error (false, e)
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
  | Error e -> `Error (false, "monolith-ification failed: " ^ e)
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
  Cmd.v
    (Cmd.info
       "markdown_monolith"
       ~doc:"Produce a monolithic Markdown file by inlining linked files.")
    Term.(
      ret
        (const run
         $ infile
         $ outfile
         $ allow_remote_t
         $ max_depth_t
         $ dedupe_t
         $ strict_commonmark_t
         $ add_newlines_t
         $ force_reconciliation_t))
;;

let () = exit (Cmd.eval cmd)
