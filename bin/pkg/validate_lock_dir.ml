open! Import
module Package_universe = Dune_pkg.Package_universe
module Lock_dir = Dune_pkg.Lock_dir
module Opam_repo = Dune_pkg.Opam_repo
module Package_version = Dune_pkg.Package_version
module Opam_solver = Dune_pkg.Opam_solver

let info =
  let doc = "Validate that a lockdir contains a solution for local packages" in
  let man = [ `S "DESCRIPTION"; `P doc ] in
  Cmd.info "validate-lockdir" ~doc ~man
;;

let enumerate_lock_dirs_by_path () =
  let open Fiber.O in
  let+ per_contexts =
    Memo.run (Workspace.workspace ()) >>| Pkg_common.lock_dirs_of_workspace
  in
  List.filter_map per_contexts ~f:(fun lock_dir_path ->
    if Path.exists (Path.source lock_dir_path)
    then (
      try Some (Ok (lock_dir_path, Lock_dir.read_disk lock_dir_path)) with
      | User_error.E e -> Some (Error (lock_dir_path, `Parse_error e)))
    else None)
;;

let validate_lock_dirs () =
  let open Fiber.O in
  let+ lock_dirs_by_path = enumerate_lock_dirs_by_path ()
  and+ local_packages = Pkg_common.find_local_packages in
  if List.is_empty lock_dirs_by_path
  then Console.print [ Pp.text "No lockdirs to validate." ]
  else (
    match
      List.filter_map lock_dirs_by_path ~f:(function
        | Error e -> Some e
        | Ok (path, lock_dir) ->
          (match Package_universe.create local_packages lock_dir with
           | Ok _ -> None
           | Error e -> Some (path, `Lock_dir_out_of_sync e)))
    with
    | [] -> ()
    | errors_by_path ->
      List.iter errors_by_path ~f:(fun (path, error) ->
        match error with
        | `Parse_error error ->
          User_message.prerr
            (User_message.make
               [ Pp.textf
                   "Failed to parse lockdir %s:"
                   (Path.Source.to_string_maybe_quoted path)
               ; User_message.pp error
               ])
        | `Lock_dir_out_of_sync error ->
          User_message.prerr
            (User_message.make
               [ Pp.textf
                   "Lockdir %s does not contain a solution for local packages:"
                   (Path.Source.to_string path)
               ]);
          User_message.prerr error);
      User_error.raise
        [ Pp.text "Some lockdirs do not contain solutions for local packages:"
        ; Pp.enumerate errors_by_path ~f:(fun (path, _) ->
            Pp.text (Path.Source.to_string path))
        ])
;;

let term =
  let+ builder = Common.Builder.term in
  let builder = Common.Builder.forbid_builds builder in
  let common, config = Common.init builder in
  Scheduler.go ~common ~config validate_lock_dirs
;;

let command = Cmd.v info term
