open Import
open Fiber.O

module Paths = struct
  let packages = Path.Local.of_string "packages"

  let package_root package_name =
    OpamPackage.Name.to_string package_name |> Path.Local.relative packages
  ;;

  let package_dir package =
    Path.Local.relative
      (package_root (OpamPackage.name package))
      (OpamPackage.to_string package)
  ;;

  let files_dir package = Path.Local.relative (package_dir package) "files"
  let opam_file package = Path.Local.relative (package_dir package) "opam"
end

module Source = struct
  module Commitish = struct
    type t =
      | Commit of string
      | Branch of string
      | Tag of string

    let to_dyn = function
      | Commit c -> Dyn.variant "Commit" [ Dyn.string c ]
      | Branch b -> Dyn.variant "Branch" [ Dyn.string b ]
      | Tag t -> Dyn.variant "Tag" [ Dyn.string t ]
    ;;

    let equal a b =
      match a, b with
      | Commit x, Commit x' | Branch x, Branch x' | Tag x, Tag x' -> String.equal x x'
      | _, _ -> false
    ;;
  end

  type t =
    { url : string
    ; commit : Commitish.t option
    ; loc : Loc.t
    }

  let url t = t.url
  let commit t = t.commit

  module Private = struct
    let of_opam_url rev_store loc opam_url =
      let url = OpamUrl.base_url opam_url in
      let+ commit =
        match OpamUrl.rev opam_url with
        | None -> Fiber.return None
        | Some ref ->
          (* OpamUrl doesn't distinguish between branches/tags and commits, so
             we need to look up *)
          Rev_store.mem rev_store ~rev:ref
          >>= (function
           | true ->
             (* CR-Leonidas-from-XIV is this always a commit? *)
             Fiber.return @@ Some (Commitish.Commit ref)
           | false ->
             Rev_store.ref_type rev_store ~source:url ~ref
             >>= (function
              | Some `Tag -> Fiber.return @@ Some (Commitish.Tag ref)
              | Some `Head -> Fiber.return @@ Some (Commitish.Branch ref)
              | None ->
                (* we have to update the local repo as a side-effect and see if
                   the commit exists *)
                let* (_ : Rev_store.Remote.t) =
                  Rev_store.add_repo rev_store ~source:url ~branch:None
                  >>= Rev_store.Remote.update
                in
                Rev_store.mem rev_store ~rev:ref
                >>= (function
                 | true -> Fiber.return @@ Some (Commitish.Commit ref)
                 | false ->
                   User_error.raise
                     ~loc
                     ~hints:
                       [ Pp.text
                           "Make sure the URL is correct and the repository contains the \
                            branch/tag"
                       ]
                     [ Pp.textf
                         "Opam repository at '%s' does not have a reference '%s'"
                         url
                         ref
                     ])))
      in
      { commit; url; loc }
    ;;
  end

  let of_opam_url loc opam_url =
    (* fairly ugly to pull the rev-store out of thin air *)
    let* rev_store = Rev_store.get in
    Private.of_opam_url rev_store loc opam_url
  ;;

  let to_dyn { url; commit; loc = _ } =
    Dyn.record [ "url", Dyn.string url; "commit", Dyn.option Commitish.to_dyn commit ]
  ;;

  let equal { url; commit; loc } t =
    String.equal url t.url
    && Option.equal Commitish.equal commit t.commit
    && Loc.equal loc t.loc
  ;;
end

module Serializable = struct
  type t = string

  let equal = String.equal

  let to_dyn source =
    let open Dyn in
    variant "opam_repo_serializable" [ string source ]
  ;;

  let encode source =
    let open Encoder in
    record_fields [ field "source" string source ]
  ;;

  let decode =
    let open Decoder in
    fields
      (let+ source = field "source" string in
       source)
  ;;
end

type t =
  { source : Source_backend.t
  ; loc : Loc.t
  ; serializable : Serializable.t option
  }

let equal { source; serializable; loc } t =
  Source_backend.equal source t.source
  && Option.equal Serializable.equal serializable t.serializable
  && Loc.equal loc t.loc
;;

let serializable { serializable; _ } = serializable

let of_opam_repo_dir_path loc opam_repo_dir_path =
  (match Path.stat opam_repo_dir_path with
   | Error (Unix.ENOENT, _, _) ->
     User_error.raise
       ~loc
       [ Pp.textf "%s does not exist" (Path.to_string_maybe_quoted opam_repo_dir_path) ]
   | Error _ ->
     User_error.raise
       ~loc
       [ Pp.textf "could not read %s" (Path.to_string_maybe_quoted opam_repo_dir_path) ]
   | Ok { Unix.st_kind = S_DIR; _ } -> ()
   | Ok _ ->
     User_error.raise
       ~loc
       [ Pp.textf "%s is not a directory" (Path.to_string_maybe_quoted opam_repo_dir_path)
       ]);
  (let packages = Path.append_local opam_repo_dir_path Paths.packages in
   match Path.stat packages with
   | Ok { Unix.st_kind = S_DIR; _ } -> ()
   | Ok _ ->
     User_error.raise
       ~loc
       [ Pp.textf "%s is not a directory" (Path.to_string_maybe_quoted packages) ]
   | Error (Unix.ENOENT, _, _) ->
     User_error.raise
       ~loc
       [ Pp.textf
           "%s doesn't look like a path to an opam repository as it lacks a subdirectory \
            named \"packages\""
           (Path.to_string_maybe_quoted opam_repo_dir_path)
       ]
   | Error _ ->
     User_error.raise
       ~loc
       [ Pp.textf "could not read %s" (Path.to_string_maybe_quoted opam_repo_dir_path) ]);
  { source = Directory opam_repo_dir_path; serializable = None; loc }
;;

let of_git_repo (source : Source.t) =
  let+ at_rev =
    let* remote =
      let* repo = Rev_store.get in
      let branch =
        match source.commit with
        | Some (Branch b) -> Some b
        | _ -> None
      in
      let* remote = Rev_store.add_repo repo ~source:source.url ~branch in
      match source.commit with
      | Some (Commit rev) ->
        let* exists = Rev_store.mem repo ~rev in
        (match exists with
         | true -> Fiber.return @@ Rev_store.Remote.don't_update remote
         | false -> Rev_store.Remote.update remote)
      | Some (Branch _) | Some (Tag _) | None -> Rev_store.Remote.update remote
    in
    match source.commit with
    | Some (Commit ref) -> Rev_store.Remote.rev_of_ref remote ~ref
    | Some (Branch name) | Some (Tag name) -> Rev_store.Remote.rev_of_name remote ~name
    | None ->
      let name = Rev_store.Remote.default_branch remote in
      Rev_store.Remote.rev_of_name remote ~name
  in
  match at_rev with
  | None ->
    User_error.raise
      ~loc:source.loc
      ~hints:[ Pp.text "Double check that the revision is included in the repository" ]
      [ Pp.textf "Could not find revision in repository %s" source.url ]
  | Some at_rev ->
    let serializable = Some (at_rev |> Rev_store.At_rev.opam_url |> OpamUrl.to_string) in
    { source = Repo at_rev; serializable; loc = source.loc }
;;

let load_opam_package_from_dir ~(dir : Path.t) package =
  let opam_file_path = Paths.opam_file package in
  match Path.exists (Path.append_local dir opam_file_path) with
  | false -> None
  | true ->
    let files_dir = Paths.files_dir package in
    Some (Resolved_package.local_fs package ~dir ~opam_file_path ~files_dir)
;;

let load_packages_from_git rev_store opam_packages =
  let+ contents =
    List.map opam_packages ~f:(fun (file, _, _, _) -> file)
    |> Rev_store.content_of_files rev_store
  in
  List.map2
    opam_packages
    contents
    ~f:(fun (opam_file, package, rev, files_dir) opam_file_contents ->
      Resolved_package.git_repo package ~opam_file ~opam_file_contents rev ~files_dir)
;;

let all_packages_versions_in_dir loc ~dir opam_package_name =
  let dir = Path.append_local dir (Paths.package_root opam_package_name) in
  match Path.readdir_unsorted dir with
  | Ok version_dirs -> List.map version_dirs ~f:OpamPackage.of_string
  | Error (Unix.ENOENT, _, _) -> []
  | Error e ->
    User_error.raise
      ~loc
      [ Pp.textf
          "Unable to read package versions from %s: %s"
          (Path.to_string_maybe_quoted dir)
          (Dune_filesystem_stubs.Unix_error.Detailed.to_string_hum e)
      ]
;;

let all_packages_versions_at_rev rev opam_package_name =
  Paths.package_root opam_package_name
  |> Rev_store.At_rev.directory_entries rev
  |> Rev_store.File.Set.to_list
  |> List.filter_map ~f:(fun file ->
    let path = Rev_store.File.path file in
    let open Option.O in
    Path.Local.basename_opt path
    >>= function
    | "opam" ->
      let+ package =
        Path.Local.parent path >>| Path.Local.basename >>| OpamPackage.of_string
      in
      file, package
    | _ -> None)
;;

let all_package_versions t opam_package_name =
  match t.source with
  | Directory dir ->
    all_packages_versions_in_dir t.loc ~dir opam_package_name
    |> List.map ~f:(fun pkg -> `Directory pkg)
  | Repo rev ->
    all_packages_versions_at_rev rev opam_package_name
    |> List.map ~f:(fun (file, pkg) ->
      let files_dir = Paths.files_dir pkg in
      `Git (file, pkg, rev, files_dir))
;;

let load_all_versions ts opam_package_name =
  let from_git, from_dirs =
    List.map ts ~f:(fun t ->
      all_package_versions t opam_package_name |> List.rev_map ~f:(fun pkg -> t, pkg))
    |> List.concat
    |> List.fold_left ~init:OpamPackage.Version.Map.empty ~f:(fun acc (repo, pkg) ->
      let version =
        let pkg =
          match pkg with
          | `Directory pkg -> pkg
          | `Git (_, pkg, _, _) -> pkg
        in
        OpamPackage.version pkg
      in
      if OpamPackage.Version.Map.mem version acc
      then acc
      else OpamPackage.Version.Map.add version (repo, pkg) acc)
    |> OpamPackage.Version.Map.values
    |> List.partition_map ~f:(fun (repo, pkg) ->
      match pkg with
      | `Git (file, pkg, rev, files_dir) -> Left (file, pkg, rev, files_dir)
      | `Directory pkg -> Right (repo, pkg))
  in
  let from_dirs =
    List.filter_map from_dirs ~f:(fun (repo, pkg) ->
      match repo.source with
      | Repo _ ->
        Code_error.raise
          "impossible because all elements in from_dirs are from a directory"
          []
      | Directory dir ->
        load_opam_package_from_dir ~dir pkg
        |> Option.map ~f:(fun resolved_package -> pkg, resolved_package))
  in
  let+ from_git =
    match from_git with
    | [] -> Fiber.return []
    | packages ->
      let* rev_store = Rev_store.get in
      let+ resolved_packages = load_packages_from_git rev_store packages in
      List.map2 resolved_packages packages ~f:(fun resolved_package (_, pkg, _, _) ->
        pkg, resolved_package)
  in
  from_dirs @ from_git
  |> List.rev_map ~f:(fun (opam_package, resolved_package) ->
    OpamPackage.version opam_package, resolved_package)
  |> OpamPackage.Version.Map.of_list
;;

module Private = struct
  let create ~source:serializable =
    let packages_dir_path = Path.of_string "/" in
    { source = Directory packages_dir_path; serializable; loc = Loc.none }
  ;;
end
