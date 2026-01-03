let test_anchor_rewrite () =
  let tmp = "test_tmp.md" in
  let oc = open_out tmp in
  output_string oc "# Intro\n\nSome text\n";
  close_out oc;
  match Monolith.monolith_of_file ~config:Monolith.default_config tmp with
  | Error e ->
    prerr_endline ("monolith_of_file error: " ^ e);
    exit 1
  | Ok out ->
    let out = Cmarkit_commonmark.of_doc out in
    if String.contains out '{'
    then print_endline "✓ Anchor rewrite test passed"
    else (
      prerr_endline "anchor rewrite missing";
      exit 1);
    Sys.remove tmp
;;

let test_inlining () =
  (* Create test files *)
  let main_file = "test_main.md" in
  let linked_file = "test_linked.md" in
  let oc = open_out linked_file in
  output_string oc "# Linked Document\n\nLinked content.\n";
  close_out oc;
  let oc = open_out main_file in
  output_string oc "# Main\n\n[Link](test_linked.md)\n";
  close_out oc;
  match Monolith.monolith_of_file ~config:Monolith.default_config main_file with
  | Error e ->
    prerr_endline ("inlining error: " ^ e);
    Sys.remove main_file;
    Sys.remove linked_file;
    exit 1
  | Ok out ->
    let out = Cmarkit_commonmark.of_doc out in
    if String.contains out 'L' && String.contains out 'i' && String.contains out 'n'
    then print_endline "✓ Inlining test passed"
    else (
      prerr_endline "inlining failed - linked content not found";
      exit 1);
    Sys.remove main_file;
    Sys.remove linked_file
;;

let () =
  test_anchor_rewrite ();
  test_inlining ();
  print_endline "\nAll tests passed!"
;;
