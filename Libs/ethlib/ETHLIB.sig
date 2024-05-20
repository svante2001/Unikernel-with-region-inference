signature ETH = sig 
    datatype ethType = ARP | IPv4 | IPv6 

    datatype header = Header of { 
        et : ethType, 
        dstMac : int list, 
        srcMac : int list
    }

    val bytesToEthType : string -> (ethType option)
    val ethTypeToInt : ethType -> int 
    val ethTypeToString : ethType -> string

    val printHeader : header -> unit 
    val decode : string -> header * string
    val encode : header -> string -> string
end 