signature ARPLIB = sig
    datatype ARP_OP = Request | Reply 
    
    datatype HeaderARP = HeaderARP of {
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

    val printArp : HeaderARP -> unit
    val decodeArp : string -> HeaderARP
    val encodeArp : HeaderARP -> string
end