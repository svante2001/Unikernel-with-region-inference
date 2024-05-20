signature NETIFLIB = sig 
    val readTap : unit -> string 
    val writeTap : int list -> unit
end 