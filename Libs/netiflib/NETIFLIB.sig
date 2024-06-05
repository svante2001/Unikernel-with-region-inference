(*
    The netiflib structure provides useful functions for a reading and writing to a 'tap'.
*)


signature NETIF = sig 
    val receive : unit -> string 
    val send : int list -> unit
end 

(*
[receive] reads from the 'tap' and returns what was read as a string.

[send] writes a bytelist to a 'tap'.
*)