type config = {
  follow_remote : bool;
  max_depth : int;
  dedupe : bool;
  adjust_anchors : bool;
  preserve_frontmatter : bool;
  score_threshold : float;
  min_links : int;
}

val default_config : config

(** Produce a monolithic markdown string from a file path.
    Returns [Ok output] or [Error msg]. This is a simple synchronous API
    for the initial implementation; it will be extended to Lwt later. *)
val monolith_of_file : ?config:config -> string -> (string, string) result

(** Detect whether the given markdown content looks like a TOC/navigation list
    according to the detection heuristics (stubbed for now). *)
val detect_toc : ?config:config -> string -> bool
