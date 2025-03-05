let ( let* ) = Result.bind

open Bos
open Rresult
module Repos = Map.Make (String)

let get_branch_head repo branch =
  let module Store = Git.Mem.Store in
  let module Sync = Git.Mem.Sync (Store) in
  let er f e =
    match e with Ok x -> x | Error e -> invalid_arg (Fmt.str "error: %a" f e)
  in
  let* endpoint =
    Fmt.str "https://github.com/%s.git" repo |> Smart_git.Endpoint.of_string
  in
  let ref_name = Fmt.str "refs/heads/%s" branch in
  let* ref = Git.Reference.of_string ref_name in
  let path = Fpath.v "/tmp/" in
  let refs =
    Lwt_main.run
      (let ( let** ) = Lwt.bind in
       let** store = Store.v path in
       let store = er Store.pp_error store in
       let happy_eyeballs = Happy_eyeballs_lwt.create () in
       let** ctx = Git_unix.ctx happy_eyeballs in
       let** refs =
         Sync.fetch ~deepen:(`Depth 1) ~ctx endpoint store
           (`Some [ (ref, ref) ])
       in
       Lwt.return (er Sync.pp_error refs))
  in
  let* _, refs =
    Option.to_result refs
      ~none:(`Msg (Fmt.str "didn't find a %s branch in repo %s" branch repo))
  in
  let branch_hash =
    List.find_map
      (fun (ref', hash) ->
        if Git.Reference.equal ref ref' then Some hash else None)
      refs
  in
  let* branch_hash =
    Option.to_result branch_hash
      ~none:(`Msg (Fmt.str "didn't find a %s branch in repo %s" branch repo))
  in
  Logs.info (fun f -> f "%s#%s: %a" repo branch Store.Hash.pp branch_hash);
  Ok (Fmt.str "%a" Store.Hash.pp branch_hash)

let update_url repos url =
  let* () =
    match Uri.host url with
    | Some "github.com" -> Ok ()
    | Some _ | None -> R.error_msgf "host in %a is not github.com" Uri.pp url
  in
  let segments = Uri.path url |> String.split_on_char '/' in
  let* repo =
    match segments with
    | "" :: user :: repo :: _ -> Ok (user ^ "/" ^ repo)
    | _ -> R.error_msgf "%a does not refer to a Github repo" Uri.pp url
  in
  Logs.debug (fun f -> f "repo: %s" repo);
  match Repos.find_opt repo repos with
  | None ->
      Logs.warn (fun f ->
          f "repo %s is not in the branches file, skipping" repo);
      Ok None
  | Some hash ->
      let path = Fmt.str "/%s/archive/%s.tar.gz" repo hash in
      let uri = Uri.make ~scheme:"https" ~host:"github.com" ~path () in
      Ok (Some uri)

let update_one repos target =
  let seems_opam = String.ends_with ~suffix:"opam" (Fpath.to_string target) in
  if not seems_opam then (
    Logs.debug (fun f -> f "skipping %a: not an opam file" Fpath.pp target);
    Ok ())
  else (
    Logs.info (fun f -> f "updating file %a" Fpath.pp target);
    let* t =
      OS.File.with_ic target
        (fun ic () -> OpamFile.OPAM.read_from_channel ic)
        ()
    in
    match OpamFile.OPAM.get_url t with
    | None ->
        Logs.debug (fun f -> f "file has no url field, skipping");
        Ok ()
    | Some url -> (
        let* uri = update_url repos (OpamUrl.base_url url |> Uri.of_string) in
        match uri with
        | None ->
            Logs.debug (fun f -> f "repo not in branches file, skipping");
            Ok ()
        | Some uri ->
            let opam_url =
              OpamFile.URL.create (OpamUrl.of_string (Uri.to_string uri))
            in
            let output_file = OpamFile.OPAM.with_url opam_url t in
            let output = OpamFile.OPAM.write_to_string output_file in
            (*Logs.info (fun f -> f "%s" output);*)
            OS.File.write target output))

let rec update_all repos root =
  let* contents = OS.Dir.contents root in
  List.fold_left
    (fun acc file ->
      match acc with
      | Error _ -> acc
      | Ok () ->
          let* is_dir = OS.Dir.exists file in
          if is_dir then update_all repos file else update_one repos file)
    (Ok ()) contents

let read_repos file =
  Logs.info (fun f -> f "Reading branches file...");
  let* lines = OS.File.read_lines (Fpath.v file) in
  let* parsed =
    try
      List.map
        (fun line ->
          match String.split_on_char ' ' line with
          | [ repo; branch ] -> (repo, branch)
          | _ -> invalid_arg (Fmt.str "invalid line in repos file: '%s'" line))
        lines
      |> Result.ok
    with Invalid_argument msg -> R.error_msg msg
  in
  Logs.info (fun f -> f "Fetching all branches heads...");
  let fetched =
    List.map
      (fun (repo, branch) ->
        let hash = R.error_msg_to_invalid_arg (get_branch_head repo branch) in
        (repo, hash))
      parsed
  in
  Ok (Repos.of_list fetched)

let update repos target recurse =
  let target = Fpath.v target in
  let res =
    let* repos = read_repos repos in
    if recurse then
      let* target = OS.Dir.must_exist target in
      update_all repos target
    else update_one repos target
  in
  Result.map_error (function `Msg m -> m | _ -> "unknown error") res

open Cmdliner

let repos =
  let doc = "File containing branches to use per repo" in
  Arg.(value & opt file "branches" & info [ "repos" ] ~doc)

let target =
  let doc = "The file or directory (in case of -r) to update" in
  Arg.(value & pos 0 file "." & info [] ~doc)

let recurse =
  let doc =
    "Whether to look for 'opam' recursively and update them all, instead of \
     targeting a single file."
  in
  Arg.(value & flag & info [ "r"; "recursive" ] ~doc)

let update_t = Term.(const update $ repos $ target $ recurse)

let cmd =
  let doc =
    "update opam file's source url so it points to the head commit of branches \
     specified by a repos.json file"
  in
  Cmd.v (Cmd.info "update" ~doc) update_t

let () =
  Mirage_crypto_rng_unix.use_default ();
  Logs.set_reporter (Logs_fmt.reporter ());
  Logs.set_level (Some Logs.Info);
  exit (Cmd.eval_result cmd)
