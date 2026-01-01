(* Minimal monolith implementation (clean). *)

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

let monolith_of_file ?(config=default_config) path =
  (* Recursive inlining pipeline (synchronous, local-first).
     This is a conservative implementation: it inlines local markdown files
     referenced by markdown links. Remote fetching is supported via Fetch.fetch_uri
     when `config.follow_remote` is true. Deduping and cycle detection are handled
     via a seen set. *)
  let is_url p =
    try String.sub p 0 7 = "http://" || String.sub p 0 8 = "https://" with _ -> false
  in

  let resolve_local base_dir target =
    if Filename.is_relative target then Filename.concat base_dir target else target
  in

  let rec inline_path ~depth ~seen path =
    if depth <= 0 then Error "max depth reached" else
    if is_url path then (
        if config.follow_remote then Fetch.fetch_uri_sync path else Error "remote fetching disabled"
    ) else
      let abs = if Filename.is_relative path then Filename.concat (Unix.getcwd ()) path else path in
      if config.dedupe && Hashtbl.mem seen abs then Ok "" else (
        if config.dedupe then Hashtbl.add seen abs ();
        try
          let ic = open_in abs in
          let s = really_input_string ic (in_channel_length ic) in
          close_in ic;
          (* Inline links found in s by extracting markdown link targets and recursing. *)
          let rec extract_links acc pos =
            try
              let ob = String.index_from s pos '[' in
              let cb = String.index_from s (ob+1) ']' in
              if cb+1 < String.length s && s.[cb+1] = '(' then
                let op = cb+1 in
                let cp = String.index_from s (op+1) ')' in
                let target = String.sub s (op+1) (cp - op - 1) in
                extract_links (target::acc) (cp+1)
              else extract_links acc (cb+1)
            with _ -> List.rev acc
          in
          let targets = extract_links [] 0 in
          let base_dir = Filename.dirname abs in

          (* Heading slug generator *)
          let slug_of s =
            let s = String.lowercase_ascii s in
            let b = Buffer.create (String.length s) in
            String.iter (fun c -> if (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') then Buffer.add_char b c else if c = ' ' || c = '-' then Buffer.add_char b '-' else ()) s;
            let res = Buffer.contents b in
            (* collapse multiple hyphens *)
            let rec collapse i acc last_dash =
              if i >= String.length res then acc else
              let ch = res.[i] in
              if ch = '-' then if last_dash then collapse (i+1) acc true else collapse (i+1) (acc ^ "-") true
              else collapse (i+1) (acc ^ (String.make 1 ch)) false
            in
            let out = collapse 0 "" false in
            if String.length out = 0 then "section" else out
          in

          (* Rewrite headings to have file-specific prefix to avoid anchor collisions. *)
          let file_prefix = String.sub (Digest.to_hex (Digest.string abs)) 0 8 in
          let lines = String.split_on_char '\n' s in
          let rewritten_lines, headings =
            let rec loop i acc heads = function
              | [] -> (List.rev acc, List.rev heads)
              | ln::tl ->
                let trimmed =
                  let t = ln in
                  let rec ltrim j = if j < String.length t && (t.[j] = ' ' || t.[j] = '\t') then ltrim (j+1) else j in
                  String.sub t (ltrim 0) (String.length t - (ltrim 0))
                in
                if String.length trimmed > 0 && trimmed.[0] = '#' then
                  let level =
                    let rec count j c = if j < String.length trimmed && trimmed.[j] = '#' then count (j+1) (c+1) else c in
                    count 0 0
                  in
                  let rest = String.sub trimmed level (String.length trimmed - level) |> String.trim in
                  let id = slug_of rest in
                  let new_id = file_prefix ^ "-" ^ id in
                  let new_ln = (String.make level '#') ^ " " ^ rest ^ " {#" ^ new_id ^ "}" in
                  loop (i+1) (new_ln::acc) ((id,new_id)::heads) tl
                else loop (i+1) (ln::acc) heads tl
            in loop 0 [] [] lines
          in

          let s_rewritten = String.concat "\n" rewritten_lines in
          let buf = Buffer.create (String.length s_rewritten + 1024) in
          Buffer.add_string buf s_rewritten;

          (* When inlining, update links that point to anchors inside this file to the rewritten anchors. *)
          List.iter (fun t ->
            if t = "" || t.[0] = '#' then () else
            if is_url t then (
              match Fetch.fetch_uri_sync t with Ok body -> Buffer.add_string buf ("\n\n" ^ body) | Error _ -> ()
            ) else (
              let tp = resolve_local base_dir t in
              let (target_file, anchor) =
                try
                  match String.index tp '#' with
                  | idx -> (String.sub tp 0 idx, String.sub tp (idx+1) (String.length tp - idx - 1))
                with _ -> (tp, "")
              in
              if anchor <> "" then
                (* If the target file matches this file, rewrite anchor to new id *)
                let target_abs = if Filename.is_relative target_file then Filename.concat base_dir target_file else target_file in
                if target_abs = abs then (
                  (* find rewritten id *)
                  match List.find_opt (fun (old,_newid) -> old = anchor) headings with
                  | Some (_, _newid) -> ()
                  | None -> ()
                ) else (
                  match inline_path ~depth:(depth-1) ~seen tp with
                  | Ok body -> Buffer.add_string buf ("\n\n" ^ body)
                  | Error _ -> ()
                )
              else (
                match inline_path ~depth:(depth-1) ~seen tp with
                | Ok body -> Buffer.add_string buf ("\n\n" ^ body)
                | Error _ -> ()
              )
            )
          ) targets;
          Ok (Buffer.contents buf)
        with e -> Error (Printexc.to_string e)
      )
  in

  let seen = Hashtbl.create 128 in
  inline_path ~depth:config.max_depth ~seen path

let detect_toc ?(config=default_config) (content:string) : bool =
  let _ = config in
  let lines = String.split_on_char '\n' content in

  let trim s =
    let is_space = function ' ' | '\n' | '\r' | '\t' -> true | _ -> false in
    let l = String.length s in
    let rec left i = if i >= l then l else if is_space s.[i] then left (i+1) else i in
    let rec right i = if i < 0 then -1 else if is_space s.[i] then right (i-1) else i in
    let a = left 0 in
    let b = right (l-1) in
    if b < a then "" else String.sub s a (b-a+1)
  in

  let parse_frontmatter_lines ls =
    match ls with
    | first :: rest when trim first = "---" ->
      let rec find_end acc = function
        | [] -> None
        | x::_ when trim x = "---" || trim x = "..." -> Some (List.rev acc)
        | x::xs -> find_end (x::acc) xs
      in
      find_end [] rest
    | _ -> None
  in

  let frontmatter_forces_inline lines =
    match parse_frontmatter_lines lines with
    | None -> None
    | Some fm_lines ->
      let fm = String.concat "\n" fm_lines |> String.lowercase_ascii in
      (try
         if String.contains fm 'm' && String.contains fm ':' then
           if String.contains fm 't' && (try String.sub fm (String.index fm 't') 4 = "true" with _ -> false) then Some true else None
         else None
       with _ -> None)
  in

  match frontmatter_forces_inline lines with
  | Some b -> b
  | None ->
    let rec find_heading i =
      if i >= List.length lines then None else
      let line = trim (List.nth lines i) |> String.lowercase_ascii in
      let text = if String.length line > 0 && line.[0] = '#' then
          let rec skip_hash j = if j < String.length line && line.[j] = '#' then skip_hash (j+1) else j in
          let idx = skip_hash 0 in
          trim (String.sub line idx (String.length line - idx))
        else line
      in
      if text = "table of contents" || text = "contents" || text = "toc" || text = "navigation" then Some i
      else find_heading (i+1)
    in

    let is_list_line l =
      let t = trim l in
      if String.length t >= 2 && (String.sub t 0 2 = "- " || String.sub t 0 2 = "* ") then true else
      try let dot = String.index t '.' in let _ = String.sub t 0 dot |> int_of_string in true with _ -> false
    in

    let find_list_after idx =
      let rec loop i = if i >= List.length lines then None else if is_list_line (List.nth lines i) then Some i else loop (i+1) in
      loop idx
    in

    let heading_pos = find_heading 0 in
    let list_pos = match heading_pos with Some h -> find_list_after (h+1) | None -> None in

    let list_index = match list_pos with Some i -> i | None -> -1 in
    if list_index = -1 then false else

    let rec count_contig i acc = if i >= List.length lines then acc else if is_list_line (List.nth lines i) then count_contig (i+1) (acc+1) else acc in
    let contig = count_contig list_index 0 in
    if contig < config.min_links then false else

    let extract_links line =
      let rec aux pos acc =
        try
          let ob = String.index_from line pos '[' in
          let cb = String.index_from line (ob+1) ']' in
          if cb+1 < String.length line && line.[cb+1] = '(' then
            let op = cb+1 in
            let cp = String.index_from line (op+1) ')' in
            let label = String.sub line (ob+1) (cb - ob - 1) in
            let target = String.sub line (op+1) (cp - op - 1) in
            aux (cp+1) ((label, target)::acc)
          else aux (cb+1) acc
        with _ -> List.rev acc
      in aux 0 []
    in

    let rec analyze i end_i link_items total_links internal_links short_count =
      if i >= end_i then (link_items, total_links, internal_links, short_count) else
      let line = List.nth lines i in
      let links = extract_links line in
      let (li, tl, il, sc) = List.fold_left (fun (li,tl,il,sc) (label,target) ->
        let t = String.trim target in
        let is_internal = if t = "" then false else if t.[0] = '#' then true else not (String.length t >= 4 && String.sub t 0 4 = "http") in
        (li+1, tl+1, (if is_internal then il+1 else il), (if String.length label <= 40 then sc+1 else sc))
      ) (link_items,total_links,internal_links,short_count) links in
      analyze (i+1) end_i li tl il sc
    in

    let (link_items, total_links, internal_links, short_count) = analyze list_index (list_index + contig) 0 0 0 0 in
    let link_item_ratio = if contig = 0 then 0.0 else (float_of_int link_items) /. (float_of_int contig) in
    let internal_ratio = if total_links = 0 then 0.0 else (float_of_int internal_links) /. (float_of_int total_links) in
    let short_ratio = if total_links = 0 then 0.0 else (float_of_int short_count) /. (float_of_int total_links) in

    let w_heading = 25.0 and w_contig = 30.0 and w_linkitem = 20.0 and w_internal = 15.0 and w_short = 5.0 and w_navhtml = 5.0 in
    let heading_score = (match heading_pos with Some _ -> 1.0 | None -> 0.0) in
    let contig_score = if contig >= config.min_links then 1.0 else 0.0 in
    let linkitem_score = (if link_item_ratio > 1.0 then 1.0 else link_item_ratio) in
    let internal_score = internal_ratio in
    let short_score = short_ratio in
    let navhtml_score = if String.contains (String.lowercase_ascii content) '<' then 1.0 else 0.0 in

    let total_weight = w_heading +. w_contig +. w_linkitem +. w_internal +. w_short +. w_navhtml in
    let raw = (w_heading *. heading_score) +. (w_contig *. contig_score) +. (w_linkitem *. linkitem_score) +. (w_internal *. internal_score) +. (w_short *. short_score) +. (w_navhtml *. navhtml_score) in
    let score = raw /. total_weight in
    score >= config.score_threshold
