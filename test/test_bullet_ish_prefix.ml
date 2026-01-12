open OUnit2

let cases =
  [ "star", "*", true
  ; "star-star", "**", true
  ; "star-space", "* ", true
  ; "space-star", " *", true
  ; "star-star-space", "** ", true
  ; "dash", "-", true
  ; "dash-dash", "--", true
  ; "space-dash", " -", true
  ; "dash-space", "- ", true
  ; "dash-dash-space", "-- ", true
  ; "plus", "+", true
  ; "plus-plus", "++", true
  ; "space-plus", " +", true
  ; "plus-space", "+ ", true
  ; "plus-plus-space", "++ ", true
  ; "num-dot", "1.", true
  ; "num-paren", "1)", true
  ; "num-dot-space", "1. ", true
  ; "num-paren-space", "1) ", true
  ; "num-dot-dot", "1.2.", true
  ; "num-dot-paren", "1.2)", true
  ; "num-dot-dot-space", "1.2. ", true
  ; "multi-num", "10.3.4.", true
  ; "empty", "", false
  ; "dot-only", ".", false
  ; "alpha-dot", "a.", false
  ; "num-letter", "1a.", false
  ]
;;

let tests =
  "bullet_ish_prefix"
  >::: List.map
         (fun (name, input, expected) ->
            name
            >:: fun _ ->
            assert_equal
              ~printer:string_of_bool
              expected
              (Monolith.bullet_ish_prefix input))
         cases
;;

let () = run_test_tt_main tests
