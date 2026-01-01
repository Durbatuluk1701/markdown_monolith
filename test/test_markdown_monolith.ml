let () =
  let sample = "# Table of Contents\n\n- [Intro](intro.md)\n- [Usage](usage.md)\n- [Contrib](contrib.md)\n" in
  let is_toc = Monolith.detect_toc sample in
  if not is_toc then (prerr_endline "detect_toc failed on sample"; exit 1) else print_endline "detect_toc OK";

  (* Anchor rewrite test: create a temporary file with headings and ensure inlining rewrites anchors *)
  let tmp = "test_tmp.md" in
  let oc = open_out tmp in
  output_string oc "# Intro\n\nSome text\n"; close_out oc;
  match Monolith.monolith_of_file ~config:Monolith.default_config tmp with
  | Error e -> prerr_endline ("monolith_of_file error: " ^ e); exit 1
  | Ok out ->
    if String.contains out '{' then print_endline "anchor rewrite OK" else (prerr_endline "anchor rewrite missing"; exit 1)
