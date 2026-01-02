(** Read content from a path (supporting stdin via "-") *)
let read_content path =
  if path = "-"
  then (
    (* Read from stdin *)
    let buf = Buffer.create 4096 in
    try
      while true do
        Buffer.add_channel buf stdin 4096
      done;
      assert false
    with
    | End_of_file -> Ok (Omd.of_string (Buffer.contents buf)))
  else (
    try
      let ic = open_in path in
      let content = really_input_string ic (in_channel_length ic) in
      close_in ic;
      Ok (Omd.of_string content)
    with
    | e -> Error (Printf.sprintf "Error reading %s: %s" path (Printexc.to_string e)))
;;

(* Extract text from inline elements *)
let rec text_of_inline =
  Omd.(
    function
    | Concat (_, il) -> List.map text_of_inline il |> String.concat ""
    | Text (_, t) -> t
    | Emph (_, il) | Strong (_, il) -> text_of_inline il
    | Link (_, { label; _ }) | Image (_, { label; _ }) -> text_of_inline label
    | Code (_, c) -> c
    | Hard_break _ | Soft_break _ -> " "
    | Html (_, h) -> h)
;;
