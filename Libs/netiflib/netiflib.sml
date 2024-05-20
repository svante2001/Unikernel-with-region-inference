structure Netif : NETIFLIB = struct 
  fun readTap() : string =
    prim ("read_tap", ())

  fun writeTap(byte_list : int list) : unit =
    prim ("write_tap", byte_list)
end 