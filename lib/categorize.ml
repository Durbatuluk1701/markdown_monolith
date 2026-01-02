type link_type =
  [ `ImportLink (** Links to be followed and inlined *)
  | `InternalRef (** Anchor references within document *)
  | `ExternalRef (** External URLs to keep as-is *)
  ]

(** Link categorization *)
type categorized_link =
  { ty : link_type
  ; link : Links.link
  }

(* Filter links by type *)
let get_import_links categorized =
  List.filter_map
    (function
      | { ty = `ImportLink; link } -> Some link
      | _ -> None)
    categorized
;;

(* Check if a destination is a remote URL *)
let is_remote_url dest =
  String.length dest >= 7
  && (String.sub dest 0 7 = "http://"
      || (String.length dest >= 8 && String.sub dest 0 8 = "https://"))
;;

(* Check if a destination is an anchor-only reference *)
let is_anchor_only dest = dest <> "" && dest.[0] = '#'

(* Categorize a link based on its destination and config *)
let categorize_link ~follow_remote Links.{ destination; _ } =
  if destination = ""
  then `ExternalRef
  else if is_anchor_only destination
  then `InternalRef
  else if is_remote_url destination
  then if follow_remote then `ImportLink else `ExternalRef
  else if
    (* Local file path - check if it's a markdown file *)
    Filename.check_suffix destination ".md"
    || Filename.check_suffix destination ".markdown"
  then `ImportLink
  else `ExternalRef
;;

(* Extract and categorize all links from a document *)
let categorize_links_in_doc ~follow_remote doc =
  let links = Omd_utils.extract_all_links doc in
  List.map (fun link -> { ty = categorize_link ~follow_remote link; link }) links
;;

(* Extract and categorize all links from a document *)
let categorize_links_in_file ~follow_remote ~path =
  Result.map (categorize_links_in_doc ~follow_remote) (Omd_utils.read_content path)
;;
