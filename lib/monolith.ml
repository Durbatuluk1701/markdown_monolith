open Printf
(* Monolith implementation using Omd AST traversal. *)

type config =
  { follow_remote : bool
  ; max_depth : int
  ; dedupe : bool
  ; adjust_anchors : bool
  ; preserve_frontmatter : bool
  ; replace_links : bool (* Replace import links with content instead of appending *)
  ; omit_anchors : bool (* Don't add {#slug} to headings *)
  }

let default_config =
  { follow_remote = false
  ; max_depth = 10
  ; dedupe = true
  ; adjust_anchors = true
  ; preserve_frontmatter = true
  ; replace_links = true
  ; omit_anchors = false
  }
;;

let resolve_path top_path next_path = Uri.resolve "" top_path next_path

let rec monolithize_doc_internal ~top_path ~path =
  ignore top_path;
  let top_path = Uri.of_string "." in
  printf "Monolithizing path: %s >> %s\n%!" (Uri.to_string top_path) (Uri.to_string path);
  let open Cmarkit in
  let new_path = resolve_path top_path path in
  printf "Monolithizing %s\n%!" (Uri.to_string new_path);
  let file_str = Fetch.fetch_uri_sync new_path |> Result.get_ok' in
  let doc = Doc.of_string file_str in
  let process_definition link =
    (* need to do something remote here *)
    let dest = Inline.Link.reference_definition (Doc.defs doc) link in
    match dest with
    | None -> failwith (sprintf "What the heck happened")
    | Some ld ->
      (match ld with
       | Link_definition.Def (link_def, _) ->
         let dest_uri =
           Link_definition.dest link_def |> Option.get |> fst |> Uri.of_string
         in
         let new_doc =
           monolithize_doc_internal
             ~top_path:new_path
             ~path:(resolve_path new_path dest_uri)
         in
         Block.Blocks ([ Doc.block new_doc ], Meta.none)
       | _ -> failwith "Cannot not be a link_definition")
  in
  let in_list = ref false in
  let converted_stack = ref 0 in
  let block m b =
    match b with
    | Block.Paragraph (inls, _) when !in_list ->
      (* okay, we are in the list, then see a paragraph: try to check if its links *)
      (match Block.Paragraph.inline inls with
       | Inline.Link (link, _) ->
         (* list > paragraph > link ==> process *)
         incr converted_stack;
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
      if !converted_stack > 0
      then (
        decr converted_stack;
        Mapper.ret (Block.Blocks (ret, Meta.none)))
      else Mapper.default
    | _ -> Mapper.default
  in
  let mapper = Mapper.make ~block () in
  Mapper.map_doc mapper doc
;;

let monolith_of_file ?(config = default_config) path =
  let top_path = Uri.of_string "." in
  let path = Uri.of_string path in
  (* TODO: use the config *)
  ignore config;
  (* TODO: Actually use result type to propagate errors!! *)
  Ok (monolithize_doc_internal ~top_path ~path)
;;
