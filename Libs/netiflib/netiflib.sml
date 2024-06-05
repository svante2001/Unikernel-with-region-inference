structure Netif : NETIF = struct 
  fun receive() : string =
    prim ("Receive", ())

  fun send(byte_list : int list) : unit =
    prim ("Send", byte_list)
end 