type config =
  { follow_remote : bool
  ; max_depth : int
  ; dedupe : bool
  ; adjust_anchors : bool
  ; preserve_frontmatter : bool
  ; replace_links : bool
  ; omit_anchors : bool
  }

val default_config : config

(** [monolith_of_file ?config filepath] 
    produces a monolithic markdown string from 
    interpreting the markdown at [filepath] with the given [config].

    If [filepath] is "-", reads from stdin.
    Returns [Ok output] or [Error msg]. *)
val monolith_of_file : ?config:config -> string -> (Cmarkit.Doc.t, string) result
