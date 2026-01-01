(* Monolith implementation using Omd AST traversal. *)

open Omd

type config = {
  follow_remote : bool;
  max_depth : int;
  dedupe : bool;
  adjust_anchors : bool;
  preserve_frontmatter : bool;
  score_threshold : float;
  min_links : int;
}

let default_config = {
  follow_remote = false;
  max_depth = 10;
  dedupe = true;
  adjust_anchors = true;
  preserve_frontmatter = true;
  score_threshold = 0.75;
  min_links = 3;
}

(* Helper to generate slugs from heading text *)
let slug_of_string s =
  let s = String.lowercase_ascii s in
  let b = Buffer.create (String.length s) in
  String.iter (fun c -> 
    if (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') then 
      Buffer.add_char b c 
    else if c = ' ' || c = '-' then 
      Buffer.add_char b '-'
  ) s;
  let res = Buffer.contents b in
  let rec collapse i acc last_dash =
    if i >= String.length res then acc else
    let ch = res.[i] in
    if ch = '-' then 
      if last_dash then collapse (i+1) acc true 
      else collapse (i+1) (acc ^ "-") true
    else collapse (i+1) (acc ^ (String.make 1 ch)) false
  in
  let out = collapse 0 "" false in
  if String.length out = 0 then "section" else out

(* Extract text from inline elements *)
let rec text_of_inline = function
  | Concat (_, il) -> List.map text_of_inline il |> String.concat ""
  | Text (_, t) -> t
  | Emph (_, il) | Strong (_, il) -> text_of_inline il
  | Link (_, { label; _ }) | Image (_, { label; _ }) -> text_of_inline label
  | Code (_, c) -> c
  | Hard_break _ | Soft_break _ -> " "
  | Html (_, h) -> h

(* Extract all links from a block or list of blocks *)
let rec extract_links_from_inline = function
  | Link (_, { destination; label; _ }) -> 
      [(text_of_inline label, destination)]
  | Concat (_, inlines) ->
      List.concat_map extract_links_from_inline inlines
  | Emph (_, il) | Strong (_, il) -> 
      extract_links_from_inline il
  | Image (_, { label; _ }) -> 
      extract_links_from_inline label
  | _ -> []

let rec extract_links_from_block = function
  | Paragraph (_, inline) | Heading (_, _, inline) ->
      extract_links_from_inline inline
  | List (_, _, _, items) ->
      List.concat_map (fun blocks -> 
        List.concat_map extract_links_from_block blocks
      ) items
  | Blockquote (_, blocks) ->
      List.concat_map extract_links_from_block blocks
  | _ -> []

let extract_all_links doc =
  List.concat_map extract_links_from_block doc

(* TOC detection using Omd AST *)
let detect_toc ?(config=default_config) content =
  let doc = Omd.of_string content in
  
  (* Check for deterministic indicators *)
  let has_toc_heading blocks =
    List.exists (function
      | Heading (_, _, inline) ->
          let text = String.lowercase_ascii (text_of_inline inline) in
          List.mem text ["table of contents"; "contents"; "toc"; "navigation"]
      | _ -> false
    ) blocks
  in
  
  (* Find contiguous list blocks *)
  let rec find_list_blocks acc current = function
    | [] -> if current = [] then List.rev acc else List.rev (List.rev current :: acc)
    | (List _ as l) :: rest -> find_list_blocks acc (l :: current) rest
    | _ :: rest -> 
        if current = [] then find_list_blocks acc [] rest
        else find_list_blocks (List.rev current :: acc) [] rest
  in
  
  let list_groups = find_list_blocks [] [] doc in
  
  (* Score each list group *)
  let score_list_group blocks =
    let links = List.concat_map extract_links_from_block blocks in
    let link_count = List.length links in
    if link_count < config.min_links then 0.0 else
    
    (* Calculate metrics *)
    let internal_count = List.fold_left (fun acc (_, dest) ->
      if dest = "" then acc
      else if dest.[0] = '#' then acc + 1
      else if String.length dest >= 4 && String.sub dest 0 4 = "http" then acc
      else acc + 1
    ) 0 links in
    
    let short_label_count = List.fold_left (fun acc (label, _) ->
      if String.length label <= 40 then acc + 1 else acc
    ) 0 links in
    
    let link_ratio = float_of_int link_count in
    let internal_ratio = if link_count = 0 then 0.0 else float_of_int internal_count /. float_of_int link_count in
    let short_ratio = if link_count = 0 then 0.0 else float_of_int short_label_count /. float_of_int link_count in
    
    (* Weighted scoring *)
    let w_contig = 30.0 and w_linkitem = 20.0 and w_internal = 15.0 and w_short = 5.0 in
    let contig_score = if link_count >= config.min_links then 1.0 else 0.0 in
    let linkitem_score = min 1.0 (link_ratio /. float_of_int config.min_links) in
    let internal_score = internal_ratio in
    let short_score = short_ratio in
    
    let total_weight = w_contig +. w_linkitem +. w_internal +. w_short in
    let raw = (w_contig *. contig_score) +. (w_linkitem *. linkitem_score) +. 
              (w_internal *. internal_score) +. (w_short *. short_score) in
    raw /. total_weight
  in
  
  (* Check for TOC heading bonus *)
  let heading_bonus = if has_toc_heading doc then 0.25 else 0.0 in
  
  (* Find best scoring list group *)
  let best_score = List.fold_left (fun acc group ->
    max acc (score_list_group group)
  ) 0.0 list_groups in
  
  let final_score = best_score +. heading_bonus in
  final_score >= config.score_threshold

(* Simple markdown renderer for output *)
let to_markdown doc =
  let rec inline_to_string = function
    | Text (_, t) -> t
    | Concat (_, inlines) -> List.map inline_to_string inlines |> String.concat ""
    | Emph (_, il) -> "*" ^ inline_to_string il ^ "*"
    | Strong (_, il) -> "**" ^ inline_to_string il ^ "**"
    | Code (_, c) -> "`" ^ c ^ "`"
    | Hard_break _ -> "  \n"
    | Soft_break _ -> " "
    | Link (_, { label; destination; title }) ->
        let title_str = match title with Some t -> Printf.sprintf " \"%s\"" t | None -> "" in
        Printf.sprintf "[%s](%s%s)" (inline_to_string label) destination title_str
    | Image (_, { label; destination; title }) ->
        let title_str = match title with Some t -> Printf.sprintf " \"%s\"" t | None -> "" in
        Printf.sprintf "![%s](%s%s)" (inline_to_string label) destination title_str
    | Html (_, h) -> h
  in
  
  let rec block_to_string = function
    | Paragraph (_, inline) -> inline_to_string inline ^ "\n"
    | Heading (_, level, inline) ->
        let prefix = String.make level '#' in
        Printf.sprintf "%s %s\n" prefix (inline_to_string inline)
    | Code_block (_, lang, code) ->
        if lang = "" then
          Printf.sprintf "```\n%s\n```\n" code
        else
          Printf.sprintf "```%s\n%s\n```\n" lang code
    | Blockquote (_, blocks) ->
        let content = List.map block_to_string blocks |> String.concat "" in
        let lines = String.split_on_char '\n' content in
        List.map (fun line -> if line = "" then ">" else "> " ^ line) lines
        |> String.concat "\n" |> fun s -> s ^ "\n"
    | List (_, Ordered (start, _), _, items) ->
        let item_strings = List.mapi (fun i blocks ->
          let num = start + i in
          let content = List.map block_to_string blocks |> String.concat "" in
          Printf.sprintf "%d. %s" num content
        ) items in
        String.concat "\n" item_strings ^ "\n"
    | List (_, Bullet _, _, items) ->
        let item_strings = List.map (fun blocks ->
          let content = List.map block_to_string blocks |> String.concat "" in
          Printf.sprintf "- %s" content
        ) items in
        String.concat "\n" item_strings ^ "\n"
    | Thematic_break _ -> "---\n"
    | Html_block (_, html) -> html ^ "\n"
    | Table (_, headers, rows) ->
        let render_cell (content, _align) = inline_to_string content in
        let header_line = List.map render_cell headers |> String.concat " | " in
        let sep_line = List.map (fun _ -> "---") headers |> String.concat " | " in
        let row_lines = List.map (fun row ->
          List.map inline_to_string row |> String.concat " | "
        ) rows in
        String.concat "\n" (["| " ^ header_line ^ " |"; "| " ^ sep_line ^ " |"] @ 
          List.map (fun r -> "| " ^ r ^ " |") row_lines) ^ "\n"
    | Definition_list (_, items) ->
        List.map (fun { term; defs } ->
          let term_str = inline_to_string term in
          let def_strs = List.map inline_to_string defs in
          term_str ^ "\n" ^ (List.map (fun d -> ": " ^ d) def_strs |> String.concat "\n")
        ) items |> String.concat "\n\n" |> fun s -> s ^ "\n"
  in
  
  List.map block_to_string doc |> String.concat "\n"

(* Rewrite headings in AST to add unique IDs for anchor adjustment *)
let rewrite_headings_in_doc prefix doc =
  let counter = ref 0 in
  let heading_map = Hashtbl.create 16 in
  
  let rec rewrite_block = function
    | Heading (attr, level, inline) ->
        let text = text_of_inline inline in
        let slug = slug_of_string text in
        let new_id = Printf.sprintf "%s-%d-%s" prefix !counter slug in
        incr counter;
        Hashtbl.add heading_map slug new_id;
        (* Add id as an HTML attribute via raw HTML *)
        (* We need to append HTML to the inline element *)
        let new_inline = Concat (attr, [inline; Html (attr, Printf.sprintf " {#%s}" new_id)]) in
        Heading (attr, level, new_inline)
    | List (attr, ty, sp, items) ->
        List (attr, ty, sp, List.map (fun blocks -> 
          List.map rewrite_block blocks
        ) items)
    | Blockquote (attr, blocks) ->
        Blockquote (attr, List.map rewrite_block blocks)
    | other -> other
  in
  
  let rewritten = List.map rewrite_block doc in
  (rewritten, heading_map)

(* Check if a destination is a remote URL *)
let is_remote_url dest =
  String.length dest >= 7 && 
  (String.sub dest 0 7 = "http://" || 
   (String.length dest >= 8 && String.sub dest 0 8 = "https://"))

(* Resolve a link target relative to a base directory *)
let resolve_path base_dir target =
  if Filename.is_relative target then
    Filename.concat base_dir target
  else target

(* Main monolith_of_file implementation *)
let monolith_of_file ?(config=default_config) path =
  let seen = Hashtbl.create 128 in
  let file_counter = ref 0 in
  
  let rec inline_file ~depth path =
    if depth <= 0 then 
      Error "Maximum recursion depth reached"
    else if config.dedupe && Hashtbl.mem seen path then
      Ok [] (* Already inlined, return empty *)
    else begin
      if config.dedupe then Hashtbl.add seen path ();
      
      try
        (* Read and parse the file *)
        let ic = open_in path in
        let content = really_input_string ic (in_channel_length ic) in
        close_in ic;
        
        let doc = Omd.of_string content in
        
        (* Rewrite headings if anchor adjustment is enabled *)
        let (doc_rewritten, _heading_map) = 
          if config.adjust_anchors then
            let prefix = Printf.sprintf "f%d" !file_counter in
            incr file_counter;
            rewrite_headings_in_doc prefix doc
          else
            (doc, Hashtbl.create 0)
        in
        
        (* Extract links and inline them *)
        let links = extract_all_links doc_rewritten in
        let base_dir = Filename.dirname path in
        
        (* Recursively inline linked files *)
        let inlined_docs = List.filter_map (fun (_label, dest) ->
          (* Skip anchors and non-markdown links *)
          if dest = "" || dest.[0] = '#' then None
          else if is_remote_url dest then
            if config.follow_remote then
              match Fetch.fetch_uri_sync dest with
              | Ok body -> 
                  let remote_doc = Omd.of_string body in
                  Some remote_doc
              | Error _ -> None
            else None
          else
            (* Local file *)
            let resolved = resolve_path base_dir dest in
            (* Only inline .md files *)
            if Filename.check_suffix resolved ".md" then
              match inline_file ~depth:(depth - 1) resolved with
              | Ok subdoc -> Some subdoc
              | Error _ -> None
            else None
        ) links in
        
        (* Concatenate: original doc + inlined subdocs *)
        let combined = doc_rewritten :: inlined_docs |> List.concat in
        Ok combined
        
      with e -> 
        Error (Printf.sprintf "Error reading %s: %s" path (Printexc.to_string e))
    end
  in
  
  let abs_path = 
    if Filename.is_relative path then
      Filename.concat (Sys.getcwd ()) path
    else path
  in
  
  match inline_file ~depth:config.max_depth abs_path with
  | Ok doc -> Ok (to_markdown doc)
  | Error e -> Error e


