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
    if String.contains out 'L' && String.contains out 'i' && String.contains out 'n'
    then print_endline "✓ Inlining test passed"
    else (
      prerr_endline "inlining failed - linked content not found";
      exit 1);
    Sys.remove main_file;
    Sys.remove linked_file
;;

(* Test link categorization *)
let test_link_categorization () =
  (* Test local markdown file - should be ImportLink *)
  assert (
    Categorize.categorize_link
      ~follow_remote:false
      { destination = "intro.md"; label = "Intro" }
    = `ImportLink);
  (* Test anchor link - should be InternalRef *)
  assert (
    Categorize.categorize_link
      ~follow_remote:false
      { destination = "#section"; label = "Section" }
    = `InternalRef);
  (* Test remote URL without follow_remote - should be ExternalRef *)
  assert (
    Categorize.categorize_link
      ~follow_remote:false
      { destination = "https://example.com/doc.md"; label = "Doc" }
    = `ExternalRef);
  (* Test remote URL with follow_remote - should be ImportLink *)
  assert (
    Categorize.categorize_link
      ~follow_remote:true
      { destination = "https://example.com/doc.md"; label = "Doc" }
    = `ImportLink);
  (* Test non-markdown file - should be ExternalRef *)
  assert (
    Categorize.categorize_link
      ~follow_remote:false
      { destination = "image.png"; label = "Image" }
    = `ExternalRef);
  print_endline "✓ Link categorization test passed"
;;

let test_omit_anchors () =
  let tmp = "test_omit.md" in
  let oc = open_out tmp in
  output_string oc "# Header\n\nContent\n";
  close_out oc;
  let cfg = { Monolith.default_config with omit_anchors = true } in
  match Monolith.monolith_of_file ~config:cfg tmp with
  | Error e ->
    prerr_endline ("omit anchors test error: " ^ e);
    exit 1
  | Ok out ->
    if String.contains out '{'
    then (
      prerr_endline "Failed: output should not contain {#...} when omit_anchors=true";
      exit 1);
    print_endline "✓ Omit anchors test passed";
    Sys.remove tmp
;;

let () =
  test_anchor_rewrite ();
  test_inlining ();
  test_link_categorization ();
  test_omit_anchors ();
  print_endline "\nAll tests passed!"
;;
