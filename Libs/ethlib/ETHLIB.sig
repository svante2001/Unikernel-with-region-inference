signature ETHLIB = sig 
    datatype ethType = ARP | IPv4 | IPv6 

    datatype headerEth = HeaderEth of { 
        et : ethType, 
        dstMac : int list, 
        srcMac : int list
    }

    val bytesToEthType : string -> (ethType option)
    val ethTypeToInt : ethType -> int 
    val ethTypeToString : ethType -> string

    val printEthFrame : headerEth -> unit 
    val decodeEthFrame : string -> headerEth * string
    val encodeEthFrame : headerEth -> string -> string
end 