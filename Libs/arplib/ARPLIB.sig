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

    val printHeader : header -> unit
    val decode : string -> header
    val encode : header -> string
end