open Printf

type config =
  { follow_remote : bool
    (** If [true], follow and inline remote links (i.e. HTTP/HTTPS). Be cautious when enabling this option as it may lead to security risks or excessive network usage. (NOTE!!! This is not fully implemented yet) *)
  ; max_depth : int
    (** Maximum depth for inlining files. (NOTE!!! This is not fully implemented yet) *)
  ; dedupe : bool
    (** If [true], do not inline the same file more than once. (NOTE!!! This is not fully implemented yet) *)
  ; strict_commonmark : bool (** If [true], enforce strict CommonMark parsing rules. *)
  ; add_newlines : bool (** If [true], add newlines between inlined content. *)
  }

let default_config =
  { follow_remote = false
  ; max_depth = 10
  ; dedupe = true
  ; strict_commonmark = false
  ; add_newlines = true
  }
;;

let numbered_prefix = Re.Str.regexp {|^\([0-9]\(\.\|)\)*\)+$|}
let bullet_prefix = Re.Str.regexp {|^\(\*\|-\|\+\)$|}

(** [bullet_ish_prefix prefix] returns [true] if the prefix looks like a bullet point (i.e. *, -, +, some numbered bullet point 1.3, etc.). It returns [false] otherwise *)
let bullet_ish_prefix prefix =
  let prefix = String.trim prefix in
  Re.Str.string_match numbered_prefix prefix 0
  || Re.Str.string_match bullet_prefix prefix 0
;;

let pp_block block =
  let open Cmarkit in
  let doc = Doc.make block in
  Cmarkit_commonmark.of_doc doc
;;

let resolve_path top_path next_path = Uri.resolve "" top_path next_path

let get_first_header doc =
  let open Cmarkit in
  (match Doc.block doc with
   | Block.Blocks (blocks, _) ->
     (match blocks with
      | Block.Heading (hding, _) :: _ -> hding
      | _ -> raise Not_found)
   | Block.Heading (hding, _) -> hding
   | _ -> raise Not_found)
  |> Block.Heading.inline
  |> Inline.id
;;

module PathMap = Hashtbl.Make (struct
    include Uri

    let hash = Stdlib.Hashtbl.hash
  end)

let link_dest_uri doc link =
  let open Cmarkit in
  let dest = Inline.Link.reference_definition (Doc.defs doc) link in
  match dest with
  | None -> failwith (sprintf "What the heck happened")
  | Some ld ->
    (match ld with
     | Link_definition.Def (link_def, _) ->
       Link_definition.dest link_def |> Option.get |> fst |> Uri.of_string
     | _ -> failwith "Cannot not be a link_definition")
;;

let rec monolithize_doc_internal ~config ~top_path ~path =
  let strict = config.strict_commonmark in
  ignore top_path;
  let top_path = Uri.of_string "." in
  (* printf "Monolithizing path: %s >> %s\n%!" (Uri.to_string top_path) (Uri.to_string path); *)
  let open Cmarkit in
  let new_path = resolve_path top_path path in
  (* printf "Monolithizing %s\n%!" (Uri.to_string new_path); *)
  let file_str = Fetch.fetch_uri_sync new_path |> Result.get_ok' in
  let doc = Doc.of_string ~strict file_str in
  let top_header = get_first_header doc in
  let path_header_map = PathMap.create 16 in
  (* path_path_map translates paths to canonical paths *)
  let path_path_map = PathMap.create 16 in
  PathMap.add path_header_map new_path top_header;
  PathMap.add path_path_map new_path new_path;
  let process_definition link =
    (* need to do something remote here *)
    let dest_uri = link_dest_uri doc link in
    let rec_path_h_map, rec_path_p_map, new_doc =
      monolithize_doc_internal
        ~config
        ~top_path:new_path
        ~path:(resolve_path new_path dest_uri)
    in
    PathMap.add_seq path_header_map (PathMap.to_seq rec_path_h_map);
    PathMap.add_seq path_path_map (PathMap.to_seq rec_path_p_map);
    (* printf "Imported doc first header id: %s\n%!" hding_id; *)
    if config.add_newlines
    then (
      let newline = Block.Blank_line ("", Meta.none) in
      Block.Blocks ([ Doc.block new_doc; newline ], Meta.none))
    else Block.Blocks ([ Doc.block new_doc ], Meta.none)
  in
  let in_list = ref false in
  let converted_stack = ref 0 in
  let inline _m = function
    | Inline.Link (link, _mta) ->
      let orig_uri = link_dest_uri doc link in
      let dest_uri = resolve_path new_path orig_uri in
      PathMap.add path_path_map orig_uri dest_uri;
      Mapper.default
    | _ -> Mapper.default
  in
  let block m b =
    match b with
    | Block.Paragraph (inls, _) when !in_list ->
      (* okay, we are in the list, then see a paragraph: try to check if its links *)
      (match Block.Paragraph.inline inls with
       | Inline.Inlines ([ Inline.Text (prefix, _); Inline.Link (link, _) ], _)
         when bullet_ish_prefix prefix ->
         (* list > paragraph > link ==> process *)
         incr converted_stack;
         Mapper.ret (process_definition link)
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
  let mapper = Mapper.make ~inline ~block () in
  path_header_map, path_path_map, Mapper.map_doc mapper doc
;;

let reconcile_pathes path_header_map path_path_map doc =
  let open Cmarkit in
  let inline _m = function
    | Inline.Link (link, mta) ->
      let dest_uri = link_dest_uri doc link in
      let dest_uri = resolve_path (Uri.of_string ".") dest_uri in
      (* first, find the link in the path_path_map *)
      let dest_uri = PathMap.find path_path_map dest_uri in
      (* if the link is in the path-map, convert it *)
      (match PathMap.find_opt path_header_map dest_uri with
       | None -> (* default, must not've been mapped *) Mapper.default
       | Some new_path ->
         let open Inline in
         (* the new path is a reference to a header *)
         let new_path = "#" ^ new_path in
         let link_ref : Link.reference =
           `Inline (Link_definition.make ~dest:(new_path, Meta.none) (), Meta.none)
         in
         let new_link : Link.t = Link.make (Link.text link) link_ref in
         Mapper.ret (Link (new_link, mta)))
    | _ -> Mapper.default
  in
  let mapper = Mapper.make ~inline () in
  Mapper.map_doc mapper doc
;;

let monolith_of_file ?(config = default_config) path =
  let top_path = Uri.of_string "." in
  let path = Uri.of_string path in
  let path_header_map, path_path_map, doc =
    monolithize_doc_internal ~config ~top_path ~path
  in
  (* now, we reconcile the pathes if they have been re-mapped *)
  let doc = reconcile_pathes path_header_map path_path_map doc in
  (* TODO: Actually use result type to propagate errors!! *)
  Ok doc
;;
