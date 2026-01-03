open Cmdliner

let run
      input
      output
      follow_remote
      force_inline
      force_skip
      max_depth
      no_dedupe
      no_adjust_anchors
      replace_links
      omit_anchors
  =
  let cfg =
    { Monolith.follow_remote
    ; max_depth
    ; dedupe = not no_dedupe
    ; adjust_anchors = not no_adjust_anchors
    ; preserve_frontmatter = true
    ; replace_links
    ; omit_anchors
    }
  in
  match Monolith.monolith_of_file ~config:cfg input with
  | Error e -> `Error (false, "monolith failed: " ^ e)
  | Ok out ->
    let out = Cmarkit_commonmark.of_doc out in
    if force_inline then Printf.eprintf "Forcing inline\n";
    if force_skip then Printf.eprintf "Force skip enabled\n";
    (try
       if output = "-"
       then (
         print_endline out;
         `Ok ())
       else (
         let oc = open_out output in
         output_string oc out;
         close_out oc;
         `Ok ())
     with
     | e -> `Error (false, Printexc.to_string e))
;;

let input_t =
  Arg.(
    value
    & pos 0 string "-"
    & info [] ~docv:"INPUT" ~doc:"Input markdown path (use '-' for stdin)")
;;

let output_t =
  Arg.(
    value
    & opt string "-"
    & info [ "o"; "output" ] ~docv:"OUTPUT" ~doc:"Output path ('-' for stdout)")
;;

let follow_remote_t =
  Arg.(value & flag & info [ "follow-remote" ] ~doc:"Enable fetching remote links")
;;

let force_inline_t =
  Arg.(value & flag & info [ "force-inline" ] ~doc:"Force inline detected lists")
;;

let force_skip_t = Arg.(value & flag & info [ "force-skip" ] ~doc:"Force skip inlining")

let max_depth_t =
  Arg.(
    value & opt int 10 & info [ "max-depth" ] ~doc:"Maximum recursion depth (default: 10)")
;;

let no_dedupe_t =
  Arg.(value & flag & info [ "no-dedupe" ] ~doc:"Disable deduplication of files")
;;

let no_adjust_anchors_t =
  Arg.(value & flag & info [ "no-adjust-anchors" ] ~doc:"Disable anchor adjustment")
;;

let replace_links_t =
  Arg.(
    value
    & flag
    & info
        [ "replace-links" ]
        ~doc:"Replace import links with content instead of appending")
;;

let omit_anchors_t =
  Arg.(
    value & flag & info [ "omit-anchors" ] ~doc:"Don't add {#slug} anchors to headings")
;;

let cmd =
  Cmd.v
    (Cmd.info
       "markdown_monolith"
       ~version:"0.1"
       ~doc:"Produce a monolithic Markdown file by inlining linked files.")
    Term.(
      ret
        (const run
         $ input_t
         $ output_t
         $ follow_remote_t
         $ force_inline_t
         $ force_skip_t
         $ max_depth_t
         $ no_dedupe_t
         $ no_adjust_anchors_t
         $ replace_links_t
         $ omit_anchors_t))
;;

let () = exit (Cmd.eval cmd)
