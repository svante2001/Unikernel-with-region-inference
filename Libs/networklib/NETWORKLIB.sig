(* 
    The networlib structure provides functions to bind a callback function to a internet port and a 
    function to start the infinite listen. 
*)

signature NETWORK = sig
    val bindUDP : int -> (string -> string) -> unit
    val listen : unit -> unit
end

(*
[bindUDP] binds a port number to a callback function.

[listen] keeps the application listening for any and all network messages. It will only handle the 
ones that has been bound.  
*)