(* Geneated by functoria_test *)

let (>>=) x f = f x
let return x = x
let run x = x

module App_make__4 = App.Make(Key_gen)(Info_gen)

let sys__1 = lazy (
  return Sys.argv
  )

let key_gen__2 = lazy (
  let __sys__1 = Lazy.force sys__1 in
  __sys__1 >>= fun _sys__1 ->
  return (Functoria_runtime.with_argv (List.map fst Key_gen.runtime_keys) "foo" _sys__1)
  )

let info_gen__3 = lazy (
  return Info_gen.info
  )

let app_make__4 = lazy (
  let __key_gen__2 = Lazy.force key_gen__2 in
  let __info_gen__3 = Lazy.force info_gen__3 in
  __key_gen__2 >>= fun _key_gen__2 ->
  __info_gen__3 >>= fun _info_gen__3 ->
  App_make__4.start _key_gen__2 _info_gen__3
  )

let () =
  let t =
  Lazy.force app_make__4
  in run t
