open Printf
open Cmarkit

type config =
  { allow_remote : bool
    (** If [true], follow and inline remote links (i.e. HTTP/HTTPS). Be cautious when enabling this option as it may lead to security risks or excessive network usage. *)
  ; max_depth : int (** Maximum depth for inlining files. *)
  ; dedupe : bool (** If [true], do not inline the same file more than once. *)
  ; strict_commonmark : bool (** If [true], enforce strict CommonMark parsing rules. *)
  ; add_newlines : bool (** If [true], add newlines between inlined content. *)
  ; force_reconciliation : bool
    (** If [true], force link reconciliation even if no header is found in the inlined document. *)
  }

let default_config =
  { allow_remote = false
  ; max_depth = 10
  ; dedupe = true
  ; strict_commonmark = false
  ; add_newlines = true
  ; force_reconciliation = false
  }
;;

let numbered_prefix = Re.Str.regexp {|^\([0-9]\(\.\|)\)*\)+$|}
let bullet_prefix = Re.Str.regexp {|^\(\*+\|-+\|\++\)$|}

(** [bullet_ish_prefix prefix] returns [true] if the prefix looks like a bullet point (i.e. *, -, +, some numbered bullet point 1.3, etc.). It returns [false] otherwise *)
let bullet_ish_prefix prefix =
  let prefix = String.trim prefix in
  Re.Str.string_match numbered_prefix prefix 0
  || Re.Str.string_match bullet_prefix prefix 0
;;

(** [normalize_uri uri] normalizes a URI by resolving dot segments in its path,
    ensuring consistent representation for comparison and deduplication.
    e.g. [./<file>.md] and [<file>.md] are normalized to the same URI. *)
let normalize_uri uri = Uri.resolve "" (Uri.of_string ".") uri

let resolve_path top_path next_path = Uri.resolve "" top_path next_path |> normalize_uri

let get_first_header doc =
  let get_inline_id hding = Block.Heading.inline hding |> Inline.id in
  match Doc.block doc with
  | Block.Blocks (blocks, _) ->
    (match blocks with
     | Block.Heading (hding, _) :: _ -> Some (get_inline_id hding)
     | _ -> None)
  | Block.Heading (hding, _) -> Some (get_inline_id hding)
  | _ -> None
;;

module PathMap = Hashtbl.Make (struct
    include Uri

    let hash = Stdlib.Hashtbl.hash
  end)

let link_dest_uri doc link =
  let dest = Inline.Link.reference_definition (Doc.defs doc) link in
  match dest with
  | None -> Error "Link has no reference definition"
  | Some ld ->
    (match ld with
     | Link_definition.Def (link_def, _) ->
       (match Link_definition.dest link_def with
        | Some (dest_str, _) -> Ok (Uri.of_string dest_str)
        | None -> Error "Link definition has no destination")
     | _ -> Error "Expected a link definition but found a different reference type")
;;

let monolithize_doc_internal
      ~path_header_map
      ~path_path_map
      ~config:
        { strict_commonmark
        ; add_newlines
        ; max_depth
        ; allow_remote
        ; dedupe
        ; force_reconciliation
        }
      ~path
  =
  let exception Bad_case of string in
  let rec aux ~depth ~path =
    if depth > max_depth
    then
      Error
        (sprintf "Maximum depth %d exceeded at path %s" max_depth (Uri.to_string path))
    else (
      (* TODO: Need to pre-validate ~path to make sure it is an actual foreign link (not #<header>) *)
      match Fetch.fetch_uri_sync ~allow_remote path with
      | Error err -> Error (sprintf "Error fetching %s: %s" (Uri.to_string path) err)
      | Ok file_str ->
        let doc = Doc.of_string ~strict:strict_commonmark file_str in
        (match get_first_header doc with
         | None ->
           (* Print a warning, but proceed - links may be broken *)
           let msg =
             sprintf
               "Warning: No header found in document at path %s."
               (Uri.to_string path)
           in
           if force_reconciliation
           then raise (Bad_case msg)
           else eprintf "%s Inlining will proceed without link reconciliation.\n" msg
           (* use the path as the header *)
         | Some top_header -> PathMap.add path_header_map path top_header);
        PathMap.add path_path_map path path;
        let process_definition link =
          match link_dest_uri doc link with
          | Error e -> raise (Bad_case e)
          | Ok dest_uri ->
            let resolved = resolve_path path dest_uri in
            (* Store mapping for link reconciliation *)
            PathMap.replace path_path_map (normalize_uri dest_uri) resolved;
            if dedupe && PathMap.mem path_header_map resolved
            then (
              (* already inlined, skip *)
              let ref_text = Inline.Text ("Duplicate Reference to: ", Meta.none) in
              let reference_link = Inline.Link (link, Meta.none) in
              let inlines = Inline.Inlines ([ ref_text; reference_link ], Meta.none) in
              Block.Paragraph (Block.Paragraph.make inlines, Meta.none))
            else (
              match aux ~depth:(depth + 1) ~path:resolved with
              | Error e -> raise (Bad_case e)
              | Ok new_doc ->
                if add_newlines
                then (
                  let newline = Block.Blank_line ("", Meta.none) in
                  Block.Blocks ([ Doc.block new_doc; newline ], Meta.none))
                else Block.Blocks ([ Doc.block new_doc ], Meta.none))
        in
        let in_list = ref false in
        let converted_stack = ref 0 in
        let inline _m = function
          | Inline.Link (link, _mta) ->
            (match link_dest_uri doc link with
             | Error _ -> Mapper.default
             | Ok orig_uri ->
               let dest_uri = resolve_path path orig_uri in
               PathMap.replace path_path_map (normalize_uri orig_uri) dest_uri;
               Mapper.default)
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
            let ret =
              List.map (fun item -> Mapper.map_block m item |> Option.get) items
            in
            in_list := orig_in_list;
            if !converted_stack > 0
            then (
              decr converted_stack;
              Mapper.ret (Block.Blocks (ret, Meta.none)))
            else Mapper.default
          | _ -> Mapper.default
        in
        let mapper = Mapper.make ~inline ~block () in
        let result_doc = Mapper.map_doc mapper doc in
        Ok result_doc)
  in
  try aux ~depth:0 ~path with
  | Bad_case e -> Error e
;;

let relative_path ~from ~target =
  (* Extract paths, which should be relative since URIs are normalized *)
  let from_path = Uri.path from in
  let target_path = Uri.path target in
  (* Split on '/', filtering empty segments (from leading/trailing slashes or //) *)
  let split_path p = String.split_on_char '/' p |> List.filter (fun s -> s <> "") in
  let from_parts = split_path from_path in
  let target_parts = split_path target_path in
  (* Get directory of 'from' by dropping the filename (last component) *)
  let from_dir =
    match List.rev from_parts with
    | [] -> []
    | _ :: rest -> List.rev rest
  in
  (* Find longest common prefix between directories *)
  let rec find_common acc from_list target_list =
    match from_list, target_list with
    | f :: fs, t :: ts when String.equal f t -> find_common (f :: acc) fs ts
    | _ -> List.rev acc, from_list, target_list
  in
  let _common_prefix, from_remaining, target_remaining =
    find_common [] from_dir target_parts
  in
  (* Build relative path: 
     - "../" for each remaining 'from' directory component
     - then append remaining target path components *)
  let up_parts = List.map (fun _ -> "..") from_remaining in
  let rel_parts = up_parts @ target_remaining in
  match rel_parts with
  | [] -> "." (* Same directory *)
  | parts ->
    let rel_path = String.concat "/" parts in
    (* Add "./" prefix for forward-relative paths (not needed for "../" paths) *)
    if String.starts_with ~prefix:".." rel_path then rel_path else "./" ^ rel_path
;;

let reconcile_pathes base_path path_header_map path_path_map doc =
  let inline _m = function
    | Inline.Link (link, mta) ->
      let make_new_link new_dest =
        let open Inline in
        let new_link =
          Link.make
            (Link.text link)
            (`Inline (Link_definition.make ~dest:(new_dest, Meta.none) (), Meta.none))
        in
        Link (new_link, mta)
      in
      (match link_dest_uri doc link with
       | Error _ -> Mapper.default
       | Ok dest_uri ->
         let dest_uri = normalize_uri dest_uri in
         (* first, find the link in the path_path_map *)
         (match PathMap.find_opt path_path_map dest_uri with
          | None -> Mapper.default
          | Some resolved_uri ->
            (* if the link is in the path-map, convert it *)
            (match PathMap.find_opt path_header_map resolved_uri with
             | Some new_path ->
               (* the new path is a reference to a header *)
               let new_path = "#" ^ new_path in
               Mapper.ret (make_new_link new_path)
             | None ->
               (* Not an inlined file, but its relative path may have shifted
                  due to inlining. Rewrite the link to the resolved path. *)
               if Uri.equal dest_uri resolved_uri
               then Mapper.default
               else (
                 let new_dest =
                   match Uri.scheme resolved_uri with
                   | Some _ -> Uri.to_string resolved_uri (* absolute URI, keep as-is *)
                   | None ->
                     (* Compute relative path from base document to resolved target *)
                     relative_path ~from:base_path ~target:resolved_uri
                 in
                 Mapper.ret (make_new_link new_dest)))))
    | _ -> Mapper.default
  in
  let mapper = Mapper.make ~inline () in
  Mapper.map_doc mapper doc
;;

let monolith_of_file ?(config = default_config) path =
  let path = Uri.of_string path |> normalize_uri in
  let path_header_map = PathMap.create 16 in
  let path_path_map = PathMap.create 16 in
  match monolithize_doc_internal ~path_header_map ~path_path_map ~config ~path with
  | Error e -> Error e
  | Ok doc ->
    (* now, we reconcile the pathes if they have been re-mapped *)
    let doc = reconcile_pathes path path_header_map path_path_map doc in
    Ok doc
;;
