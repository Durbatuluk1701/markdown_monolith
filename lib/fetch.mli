(** {1 URI Fetching}

    This module provides functions to fetch content from URIs, supporting both
    local file paths and remote HTTP/HTTPS URLs.

    @since 0.1.0
*)

(** {2 Local File Fetching} *)

(** [fetch_local_uri uri] reads the content of a local file.

    @param uri A URI with a [file://] scheme or no scheme (treated as a local path)
    @return [Ok content] with the file contents as a string, or 
            [Error msg] if the file cannot be read
    
    @since 0.1.0
*)
val fetch_local_uri : Uri.t -> (string, string) result

(** {2 Remote and Local Fetching} *)

(** [fetch_uri_lwt ?debug ~allow_remote uri] asynchronously fetches content from a URI.

    Supports the following URI schemes:
    {ul
      {- No scheme: Treated as a local file path}
      {- [file://]: Local file access}
      {- [http://] and [https://]: Remote HTTP fetching (requires [allow_remote = true])}
    }

    @param debug If [true], print debug information to stdout (default: [false])
    @param allow_remote If [true], permit fetching from HTTP/HTTPS URLs. 
           If [false], remote URLs return an error.
    @param uri The URI to fetch content from
    @return An Lwt promise resolving to [Ok content] or [Error msg]
    
    {b Note}: Remote fetches have no built-in timeout. Consider using 
    [Lwt.pick] with [Lwt_unix.timeout] for timeout control.

    @since 0.1.0
*)
val fetch_uri_lwt
  :  ?debug:bool
  -> allow_remote:bool
  -> Uri.t
  -> (string, string) result Lwt.t

(** [fetch_uri_sync ?debug ~allow_remote uri] synchronously fetches content from a URI.

    This is a blocking wrapper around {!fetch_uri_lwt} that runs the Lwt event loop
    until the fetch completes.

    @param debug If [true], print debug information to stdout (default: [false])
    @param allow_remote If [true], permit fetching from HTTP/HTTPS URLs
    @param uri The URI to fetch content from
    @return [Ok content] with the fetched content, or [Error msg] on failure

    {b Warning}: This function blocks the current thread. For concurrent fetching,
    use {!fetch_uri_lwt} directly.

    @since 0.1.0
*)
val fetch_uri_sync : ?debug:bool -> allow_remote:bool -> Uri.t -> (string, string) result
