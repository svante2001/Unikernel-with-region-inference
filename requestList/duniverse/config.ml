open Mirage

let main =
  main ~packages:[ package "cohttp-mirage" ] "Unikernel.Main" (conduit @-> job)

let () =
  register "conduit_server"
    [ main $ conduit_direct (generic_stackv4v6 default_network) ]
