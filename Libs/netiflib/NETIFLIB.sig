signature NETIF = sig 
    val readTap : unit -> string 
    val writeTap : int list -> unit
end 