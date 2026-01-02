open Printf

let read_file path =
  let ic = open_in path in
  let content = really_input_string ic (in_channel_length ic) in
  close_in ic;
  content
;;

let get_all_list_links file_path =
  let lines = read_file file_path in
  let doc = Cmarkit.Doc.of_string lines in
  let module String_Set = Set.Make (String) in
  let inline _m (in_list, acc_set) = function
    | Cmarkit.Inline.Link (link, _) when in_list ->
      Cmarkit.Folder.ret
        ( in_list
        , String_Set.add
            (Cmarkit.Inline.Link.text link
             |> Cmarkit.Inline.to_plain_text ~break_on_soft:false
             |> fun r -> String.concat "\n" (List.map (String.concat "") r))
            acc_set )
    | _ -> Cmarkit.Folder.default
  in
  let block m (in_list, acc_set) = function
    | Cmarkit.Block.Paragraph (inls, _) when in_list ->
      (* okay, we are in the list, then see a paragraph: try to check if its links *)
      Cmarkit.Folder.ret
        (Cmarkit.Folder.fold_inline
           m
           (in_list, acc_set)
           (Cmarkit.Block.Paragraph.inline inls))
    | Cmarkit.Block.List (l', _) ->
      let items =
        Cmarkit.Block.List'.items l'
        |> List.map (fun x -> fst x |> Cmarkit.Block.List_item.block)
      in
      Cmarkit.Folder.ret
        ( in_list
        , List.fold_left
            (fun acc_set_int item ->
               Cmarkit.Folder.fold_block m (true, acc_set_int) item |> snd)
            acc_set
            items )
    | _ -> Cmarkit.Folder.default
  in
  let folder = Cmarkit.Folder.make ~inline ~block () in
  let link_names = Cmarkit.Folder.fold_doc folder (false, String_Set.empty) doc in
  String_Set.iter print_endline (snd link_names);
  ()
;;

let rec monolithize_doc ~path =
  let open Cmarkit in
  let lines = read_file path in
  let doc = Doc.of_string lines in
  let process_definition link =
    (* need to do something remote here *)
    let dest = Inline.Link.reference_definition (Doc.defs doc) link in
    match dest with
    | None -> failwith (sprintf "What the heck happened")
    | Some ld ->
      (match ld with
       | Link_definition.Def (link_def, _) ->
         let dest_path = Link_definition.dest link_def |> Option.get |> fst in
         let new_doc =
           monolithize_doc ~path:(Filename.concat (Filename.dirname path) dest_path)
         in
         Block.Blocks ([ Doc.block new_doc ], Meta.none)
       | _ -> failwith "Cannot not be a link_definition")
  in
  let in_list = ref false in
  let converted = ref false in
  let block m b =
    match b with
    | Block.Paragraph (inls, _) when !in_list ->
      (* okay, we are in the list, then see a paragraph: try to check if its links *)
      (match Block.Paragraph.inline inls with
       | Inline.Link (link, _) ->
         (* list > paragraph > link ==> process *)
         converted := true;
         Mapper.ret (process_definition link)
       | _ -> Mapper.default)
    | Block.List (l', _) ->
      let orig_in_list = !in_list in
      (* set in_list to true *)
      in_list := true;
      let items =
        Block.List'.items l' |> List.map (fun x -> fst x |> Block.List_item.block)
      in
      let ret = List.map (fun item -> Mapper.map_block m item |> Option.get) items in
      in_list := orig_in_list;
      if !converted
      then (
        converted := false;
        Mapper.ret (Block.Blocks (ret, Meta.none)))
      else Mapper.default
    | _ -> Mapper.default
  in
  let mapper = Mapper.make ~block () in
  Mapper.map_doc mapper doc
;;

let () =
  let path = Sys.argv.(1) in
  print_endline ("Processing file: " ^ path);
  let orig_doc = Cmarkit.Doc.of_string (read_file path) in
  print_endline "Original document:";
  Cmarkit_commonmark.of_doc orig_doc |> print_endline;
  let mono_doc = monolithize_doc ~path in
  print_endline "Done monolithizing";
  Cmarkit_commonmark.of_doc mono_doc |> print_endline;
  ()
;;
