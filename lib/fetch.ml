open Lwt
open Cohttp
open Printf

let fetch_local_uri uri =
  let path = Uri.path uri in
  try
    let ic = open_in path in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    Ok content
  with
  | Sys_error err -> Error (Printf.sprintf "Error reading local file %s: %s" path err)
;;

let fetch_uri_lwt ?(debug = false) uri =
  match Uri.scheme uri with
  | None ->
    (* okay, probably local!? *)
    printf "Error: URI %s has no scheme\n" (Uri.to_string uri);
    Lwt.return (fetch_local_uri uri)
  | Some "file" -> Lwt.return (fetch_local_uri uri)
  | Some "http" | Some "https" ->
    Cohttp_lwt_unix.Client.get uri
    >>= fun (resp, body) ->
    let code = resp |> Response.status |> Code.code_of_status in
    if debug then printf "Response code: %d\n" code;
    if debug then printf "Headers: %s\n" (resp |> Response.headers |> Header.to_string);
    body
    |> Cohttp_lwt.Body.to_string
    >|= fun body ->
    if debug then printf "Body of length: %d\n" (String.length body);
    if code >= 200 && code < 300
    then Ok body
    else Error (Printf.sprintf "HTTP %d: %s" code body)
  | Some scheme ->
    printf "Error: Unsupported URI scheme %s in URI %s\n" scheme (Uri.to_string uri);
    Lwt.return (Error "Unsupported URI scheme")
;;

let fetch_uri_sync ?(debug = false) uri = Lwt_main.run (fetch_uri_lwt ~debug uri)
