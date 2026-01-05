type config =
  { follow_remote : bool
  ; max_depth : int
  ; dedupe : bool
  ; strict_commonmark : bool
  ; add_newlines : bool
  }

val default_config : config

(** [bullet_ish_prefix prefix] returns [true] if the prefix looks like a bullet point (i.e. *, -, +, some numbered bullet point 1.3, etc.). It returns [false] otherwise *)
val bullet_ish_prefix : string -> bool

val pp_block : Cmarkit.Block.t -> string

(** [monolith_of_file ?config filepath] 
    produces a monolithic markdown string from 
    interpreting the markdown at [filepath] with the given [config].

    If [filepath] is "-", reads from stdin.
    Returns [Ok output] or [Error msg]. *)
val monolith_of_file : ?config:config -> string -> (Cmarkit.Doc.t, string) result
