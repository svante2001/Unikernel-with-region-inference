(* 
    The ARPlib structure provides de- and encode functions of an ARP header.
*)

signature ARPLIB = sig
    datatype ARP_OP = Request | Reply 

    datatype header = Header of {
        htype : int,
        ptype : int, 
        hlen : int, 
        plen : int, 
        oper : ARP_OP, 
        sha : int list, 
        spa : int list, 
        tha : int list, 
        tpa : int list 
    }

    val toArpOperation : int -> ARP_OP 
    val arpOperationToString : ARP_OP -> string
    val arpOperationToInt : ARP_OP -> int

    val toString : header -> string
    val decode : string -> header
    val encode : header -> string
end

(*
[header] contains the fields in an ARP header.

[toArpOperation] converts an integer to an ARP operation e.g. reply.

[arpOperationToString] converts an ARP operation to a string so it can be printed.

[arpOperationToInt] converts an ARP operation to an integer.

[toString] combines all the fields of an ARP header to easy printing.

[decode] decodes a string as an ARP header.

[encode] encode the fields of a UDP header to a string.
*)