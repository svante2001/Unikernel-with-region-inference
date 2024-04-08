fun read_fd(file : string) : string =
  prim ("read_fd", file)

fun write_fd(file : string, message : string) : int =
  prim ("write_fd", (file, message))

fun open_tap() : unit =
  prim ("open_tap", ())

fun read_tap() : string =
  prim ("read_tap", ())