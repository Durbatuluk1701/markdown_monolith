type config =
  { follow_remote : bool
  ; max_depth : int
  ; dedupe : bool
  ; adjust_anchors : bool
  ; preserve_frontmatter : bool
  ; score_threshold : float
  ; min_links : int
  ; replace_links : bool
  ; omit_anchors : bool
  }

val default_config : config

type link =
  { label : string
  ; destination : string
  }

type link_type =
  [ `ImportLink (** Links to be followed and inlined *)
  | `InternalRef (** Anchor references within document *)
  | `ExternalRef (** External URLs to keep as-is *)
  ]

(** Link categorization *)
type categorized_link =
  { ty : link_type
  ; link : link
  }

(** Categorize a link based on its destination *)
val categorize_link : follow_remote:bool -> link -> link_type

(** Extract and categorize all links from markdown content *)
val categorize_links_in_doc : follow_remote:bool -> Omd.doc -> categorized_link list

(** Produce a monolithic markdown string from a file path.
    Supports "-" for stdin.
    Returns [Ok output] or [Error msg]. *)
val monolith_of_file : ?config:config -> string -> (string, string) result
