open Lwt.Infix
open Cohttp_lwt_unix

let default_cache_dir () =
  try Sys.getenv "XDG_CACHE_HOME" with
  | _ -> Filename.concat (Sys.getenv "HOME") ".cache/markdown_monolith"
;;

let ensure_dir d =
  if not (Sys.file_exists d)
  then (
    try Unix.mkdir d 0o755 with
    | _ -> ())
;;

let sha s = Digest.to_hex (Digest.string s)
let read_file_lwt path = Lwt_io.with_file ~mode:Lwt_io.Input path Lwt_io.read

let write_file_lwt path body =
  Lwt_io.with_file ~mode:Lwt_io.Output path (fun oc -> Lwt_io.write oc body)
;;

let fetch_uri_lwt ?cache_dir ?(use_cache = true) uri =
  let cache_dir =
    match cache_dir with
    | Some d -> d
    | None -> default_cache_dir ()
  in
  if use_cache then ensure_dir cache_dir;
  let key = sha uri in
  let cached = Filename.concat cache_dir key in
  if use_cache && Sys.file_exists cached
  then
    Lwt.catch
      (fun () -> read_file_lwt cached >|= fun s -> Ok s)
      (fun e -> Lwt.return (Error (Printexc.to_string e)))
  else (
    let uri_parsed = Uri.of_string uri in
    Client.get uri_parsed
    >>= fun (resp, body) ->
    let code = Cohttp.Response.status resp |> Cohttp.Code.code_of_status in
    Cohttp_lwt.Body.to_string body
    >>= fun body_str ->
    if code >= 200 && code < 300
    then (
      if use_cache
      then (
        try Lwt_main.run (write_file_lwt cached body_str) with
        | _ -> ());
      Lwt.return (Ok body_str))
    else Lwt.return (Error (Printf.sprintf "HTTP %d" code)))
;;

let fetch_uri_sync ?cache_dir ?use_cache uri =
  Lwt_main.run (fetch_uri_lwt ?cache_dir ?use_cache uri)
;;
