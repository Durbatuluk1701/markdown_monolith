open Links

(* Monolith implementation using Omd AST traversal. *)

type config =
  { follow_remote : bool
  ; max_depth : int
  ; dedupe : bool
  ; adjust_anchors : bool
  ; preserve_frontmatter : bool
  ; score_threshold : float
  ; min_links : int
  ; replace_links : bool (* Replace import links with content instead of appending *)
  ; omit_anchors : bool (* Don't add {#slug} to headings *)
  }

let default_config =
  { follow_remote = false
  ; max_depth = 10
  ; dedupe = true
  ; adjust_anchors = true
  ; preserve_frontmatter = true
  ; score_threshold = 0.75
  ; min_links = 3
  ; replace_links = true
  ; omit_anchors = false
  }
;;

(* Helper to generate slugs from heading text *)
let slug_of_string s =
  let s = String.lowercase_ascii s in
  let b = Buffer.create (String.length s) in
  String.iter
    (fun c ->
       if (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')
       then Buffer.add_char b c
       else if c = ' ' || c = '-'
       then Buffer.add_char b '-')
    s;
  let res = Buffer.contents b in
  let rec collapse i acc last_dash =
    if i >= String.length res
    then acc
    else (
      let ch = res.[i] in
      if ch = '-'
      then
        if last_dash then collapse (i + 1) acc true else collapse (i + 1) (acc ^ "-") true
      else collapse (i + 1) (acc ^ String.make 1 ch) false)
  in
  let out = collapse 0 "" false in
  if String.length out = 0 then "section" else out
;;

(* Simple markdown renderer for output *)
let to_markdown doc =
  let open Omd in
  let rec inline_to_string = function
    | Text (_, t) -> t
    | Concat (_, inlines) -> List.map inline_to_string inlines |> String.concat ""
    | Emph (_, il) -> "*" ^ inline_to_string il ^ "*"
    | Strong (_, il) -> "**" ^ inline_to_string il ^ "**"
    | Code (_, c) -> "`" ^ c ^ "`"
    | Hard_break _ -> "  \n"
    | Soft_break _ -> " "
    | Link (_, { label; destination; title }) ->
      let title_str =
        match title with
        | Some t -> Printf.sprintf " \"%s\"" t
        | None -> ""
      in
      Printf.sprintf "[%s](%s%s)" (inline_to_string label) destination title_str
    | Image (_, { label; destination; title }) ->
      let title_str =
        match title with
        | Some t -> Printf.sprintf " \"%s\"" t
        | None -> ""
      in
      Printf.sprintf "![%s](%s%s)" (inline_to_string label) destination title_str
    | Html (_, h) -> h
  in
  let rec block_to_string = function
    | Paragraph (_, inline) -> inline_to_string inline ^ "\n"
    | Heading (_, level, inline) ->
      let prefix = String.make level '#' in
      Printf.sprintf "%s %s\n" prefix (inline_to_string inline)
    | Code_block (_, lang, code) ->
      if lang = ""
      then Printf.sprintf "```\n%s\n```\n" code
      else Printf.sprintf "```%s\n%s\n```\n" lang code
    | Blockquote (_, blocks) ->
      let content = List.map block_to_string blocks |> String.concat "" in
      let lines = String.split_on_char '\n' content in
      List.map (fun line -> if line = "" then ">" else "> " ^ line) lines
      |> String.concat "\n"
      |> fun s -> s ^ "\n"
    | List (_, Ordered (start, _), _, items) ->
      let item_strings =
        List.mapi
          (fun i blocks ->
             let num = start + i in
             let content = List.map block_to_string blocks |> String.concat "" in
             Printf.sprintf "%d. %s" num content)
          items
      in
      String.concat "\n" item_strings ^ "\n"
    | List (_, Bullet _, _, items) ->
      let item_strings =
        List.map
          (fun blocks ->
             let content = List.map block_to_string blocks |> String.concat "" in
             Printf.sprintf "- %s" content)
          items
      in
      String.concat "\n" item_strings ^ "\n"
    | Thematic_break _ -> "---\n"
    | Html_block (_, html) -> html ^ "\n"
    | Table (_, headers, rows) ->
      let render_cell (content, _align) = inline_to_string content in
      let header_line = List.map render_cell headers |> String.concat " | " in
      let sep_line = List.map (fun _ -> "---") headers |> String.concat " | " in
      let row_lines =
        List.map (fun row -> List.map inline_to_string row |> String.concat " | ") rows
      in
      String.concat
        "\n"
        ([ "| " ^ header_line ^ " |"; "| " ^ sep_line ^ " |" ]
         @ List.map (fun r -> "| " ^ r ^ " |") row_lines)
      ^ "\n"
    | Definition_list (_, items) ->
      List.map
        (fun { term; defs } ->
           let term_str = inline_to_string term in
           let def_strs = List.map inline_to_string defs in
           term_str ^ "\n" ^ (List.map (fun d -> ": " ^ d) def_strs |> String.concat "\n"))
        items
      |> String.concat "\n\n"
      |> fun s -> s ^ "\n"
  in
  List.map block_to_string doc |> String.concat "\n"
;;

(* Rewrite headings in AST to add unique IDs for anchor adjustment *)
let rewrite_headings_in_doc ~omit_anchors prefix doc =
  let counter = ref 0 in
  let heading_map = Hashtbl.create 16 in
  let open Omd in
  let rec rewrite_block = function
    | Heading (attr, level, inline) ->
      let text = Omd_utils.text_of_inline inline in
      let slug = slug_of_string text in
      let new_id = Printf.sprintf "%s-%d-%s" prefix !counter slug in
      incr counter;
      Hashtbl.add heading_map slug new_id;
      (* Add id as an HTML attribute via raw HTML unless omit_anchors is true *)
      let new_inline =
        if omit_anchors
        then inline
        else Concat (attr, [ inline; Html (attr, Printf.sprintf " {#%s}" new_id) ])
      in
      Heading (attr, level, new_inline)
    | List (attr, ty, sp, items) ->
      List (attr, ty, sp, List.map (fun blocks -> List.map rewrite_block blocks) items)
    | Blockquote (attr, blocks) -> Blockquote (attr, List.map rewrite_block blocks)
    | other -> other
  in
  let rewritten = List.map rewrite_block doc in
  rewritten, heading_map
;;

(* Resolve a link target relative to a base directory *)
let resolve_path base_dir target =
  if Filename.is_relative target then Filename.concat base_dir target else target
;;

(* Main monolith_of_file implementation *)
let monolith_of_file ?(config = default_config) path =
  let seen = Hashtbl.create 128 in
  let file_counter = ref 0 in
  let rec inline_file ~depth path =
    if depth <= 0
    then Error "Maximum recursion depth reached"
    else if path <> "-" && config.dedupe && Hashtbl.mem seen path
    then Ok [] (* Already inlined, return empty *)
    else (
      if path <> "-" && config.dedupe then Hashtbl.add seen path ();
      match Omd_utils.read_content path with
      | Error e -> Error e
      | Ok doc ->
        (try
           (* Rewrite headings if anchor adjustment is enabled *)
           let doc_rewritten, _heading_map =
             if config.adjust_anchors
             then (
               let prefix = Printf.sprintf "f%d" !file_counter in
               incr file_counter;
               rewrite_headings_in_doc ~omit_anchors:config.omit_anchors prefix doc)
             else doc, Hashtbl.create 0
           in
           (* Categorize links *)
           let categorized =
             Categorize.categorize_links_in_doc
               ~follow_remote:config.follow_remote
               doc_rewritten
           in
           let import_links = Categorize.get_import_links categorized in
           let base_dir = if path = "-" then Sys.getcwd () else Filename.dirname path in
           (* Process each import link and collect inlined content *)
           let link_to_content = Hashtbl.create 16 in
           List.iter
             (fun { destination; _ } ->
                let resolved = resolve_path base_dir destination in
                match inline_file ~depth:(depth - 1) resolved with
                | Ok subdoc -> Hashtbl.add link_to_content destination subdoc
                | Error _ -> ())
             import_links;
           (* If replace_links is enabled, replace links in doc; otherwise append *)
           let final_doc =
             if config.replace_links
             then
               let open Omd in
               (* Replace import links with their content *)
               let rec replace_in_block = function
                 | Paragraph (attr, inline) -> Paragraph (attr, replace_in_inline inline)
                 | Heading (attr, level, inline) ->
                   Heading (attr, level, replace_in_inline inline)
                 | List (attr, ty, sp, items) ->
                   List
                     ( attr
                     , ty
                     , sp
                     , List.map (fun blocks -> List.map replace_in_block blocks) items )
                 | Blockquote (attr, blocks) ->
                   Blockquote (attr, List.map replace_in_block blocks)
                 | other -> other
               and replace_in_inline = function
                 | Link (attr, ({ destination; _ } as link_info)) ->
                   (* Check if this is an import link with inlined content *)
                   if Hashtbl.mem link_to_content destination
                   then
                     (* Replace with a placeholder - we'll convert the inlined docs to blocks *)
                     (* For now, keep the link but mark it *)
                     Link (attr, link_info)
                   else Link (attr, link_info)
                 | Concat (attr, inlines) ->
                   Concat (attr, List.map replace_in_inline inlines)
                 | Emph (attr, il) -> Emph (attr, replace_in_inline il)
                 | Strong (attr, il) -> Strong (attr, replace_in_inline il)
                 | Image (attr, link_info) ->
                   Image
                     (attr, { link_info with label = replace_in_inline link_info.label })
                 | other -> other
               in
               (* For link replacement, we need to insert content at block level *)
               (* So we'll append for now and handle proper replacement in a future iteration *)
               let replaced_blocks = List.map replace_in_block doc_rewritten in
               let inlined_content =
                 Hashtbl.fold (fun _ subdoc acc -> subdoc @ acc) link_to_content []
               in
               replaced_blocks @ inlined_content
             else (
               (* Append mode: just concatenate all content *)
               let inlined_content =
                 Hashtbl.fold (fun _ subdoc acc -> subdoc @ acc) link_to_content []
               in
               doc_rewritten @ inlined_content)
           in
           Ok final_doc
         with
         | e ->
           Error (Printf.sprintf "Error processing %s: %s" path (Printexc.to_string e))))
  in
  let abs_path =
    if path = "-"
    then "-"
    else if Filename.is_relative path
    then Filename.concat (Sys.getcwd ()) path
    else path
  in
  match inline_file ~depth:config.max_depth abs_path with
  | Ok doc -> Ok (to_markdown doc)
  | Error e -> Error e
;;
