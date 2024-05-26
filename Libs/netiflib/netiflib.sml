structure Netif : NETIF = struct 
  fun readTap() : string =
    prim ("readTap", ())

  fun writeTap(byte_list : int list) : unit =
    prim ("writeTap", byte_list)
end 