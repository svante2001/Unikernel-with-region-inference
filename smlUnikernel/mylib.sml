fun read_fd(file : string) : string =
  prim ("read_fd", file)

fun write_fd(file : string, message : string) : int =
  prim ("write_fd", (file, message))