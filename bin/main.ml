open Cmdliner

let run input output follow_remote force_inline force_skip score_threshold min_links =
  let cfg = { Monolith.default_config with Monolith.follow_remote = follow_remote; score_threshold; min_links } in
  let read_input path =
    if path = "-" then Ok (let s = really_input_string stdin (in_channel_length stdin) in s)
    else (try let ic = open_in path in let s = really_input_string ic (in_channel_length ic) in close_in ic; Ok s with e -> Error (Printexc.to_string e))
  in
  match read_input input with
  | Error e -> `Error (false, "Error reading input: " ^ e)
  | Ok _content ->
    (* If input is '-', fall back to printing stdin content unchanged. *)
    if input = "-" then (print_endline _content; `Ok ()) else
    match Monolith.monolith_of_file ~config:cfg input with
    | Error e -> `Error (false, "monolith failed: " ^ e)
    | Ok out ->
      if force_inline then Printf.eprintf "Forcing inline\n";
      if force_skip then Printf.eprintf "Force skip enabled\n";
      (try if output = "-" then (print_endline out; `Ok ()) else (let oc = open_out output in output_string oc out; close_out oc; `Ok ()) with e -> `Error (false, Printexc.to_string e))

let input_t = Arg.(required & pos 0 (some string) None & info [] ~docv:"INPUT" ~doc:"Input markdown path")
let output_t = Arg.(value & opt string "-" & info ["o"; "output"] ~docv:"OUTPUT" ~doc:"Output path ('-' for stdout)")
let follow_remote_t = Arg.(value & flag & info ["follow-remote"] ~doc:"Enable fetching remote links")
let force_inline_t = Arg.(value & flag & info ["force-inline"] ~doc:"Force inline detected lists")
let force_skip_t = Arg.(value & flag & info ["force-skip"] ~doc:"Force skip inlining")
let score_t = Arg.(value & opt float 0.75 & info ["score-threshold"] ~doc:"Detection score threshold")
let min_links_t = Arg.(value & opt int 3 & info ["min-links"] ~doc:"Minimum links to consider as TOC")

let cmd = Cmd.v (Cmd.info "markdown_monolith" ~version:"0.1" ~doc:"Produce a monolithic Markdown file by inlining linked files.")
  Term.(ret (const run $ input_t $ output_t $ follow_remote_t $ force_inline_t $ force_skip_t $ score_t $ min_links_t))

let () = exit (Cmd.eval cmd)

