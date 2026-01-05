type config =
  { allow_remote : bool
    (** If [true], follow and inline remote links (i.e. HTTP/HTTPS). Be cautious when enabling this option as it may lead to security risks or excessive network usage. *)
  ; max_depth : int (** Maximum depth for inlining files. *)
  ; dedupe : bool (** If [true], do not inline the same file more than once. *)
  ; strict_commonmark : bool (** If [true], enforce strict CommonMark parsing rules. *)
  ; add_newlines : bool (** If [true], add newlines between inlined content. *)
  }

val default_config : config

(** [bullet_ish_prefix prefix] returns [true] if the prefix looks like a bullet point (i.e. *, -, +, some numbered bullet point 1.3, etc.). It returns [false] otherwise *)
val bullet_ish_prefix : string -> bool

val pp_block : Cmarkit.Block.t -> string

(** [monolith_of_file ?config filepath] 
    produces a monolithic markdown string from 
    interpreting the markdown at [filepath] with the given [config]. *)
val monolith_of_file : ?config:config -> string -> (Cmarkit.Doc.t, string) result
