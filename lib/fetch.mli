val fetch_uri_lwt : ?cache_dir:string -> ?use_cache:bool -> string -> (string, string) result Lwt.t

val fetch_uri_sync : ?cache_dir:string -> ?use_cache:bool -> string -> (string, string) result

(** Async fetch using `cohttp-lwt-unix` returning an Lwt-wrapped result. *)
