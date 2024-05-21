(*
    The netiflib structure provides useful functions for a reading and writing to a 'tap'.
*)


signature NETIF = sig 
    val readTap : unit -> string 
    val writeTap : int list -> unit
end 

(*
[readTap] reads from the 'tap' and returns what was read as a string.

[writeTap] writes a bytelist to a 'tap'.
*)