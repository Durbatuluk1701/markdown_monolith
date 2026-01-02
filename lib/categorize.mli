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

val get_import_links : categorized_link list -> Links.link list

(** Categorize a link based on its destination *)
val categorize_link : follow_remote:bool -> Links.link -> link_type

(** Extract and categorize all links from an Omd doc *)
val categorize_links_in_doc : follow_remote:bool -> Omd.doc -> categorized_link list

(** Extract and categorize all links from markdown content *)
val categorize_links_in_file
  :  follow_remote:bool
  -> path:string
  -> (categorized_link list, string) result
