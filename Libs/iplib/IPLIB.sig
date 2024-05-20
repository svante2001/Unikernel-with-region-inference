signature IPLIB = sig 
    datatype protocol = ICMP | TCP | UDP | UNKNOWN

    datatype headerIPv4 = HeaderIPv4 of {
        version : int,
        ihl : int,
        dscp : int,
        ecn : int,
        total_length : int,
        identification : int,
        flags : int,
        fragment_offset : int,
        time_to_live : int,
        protocol : protocol,
        header_checksum : int,
        source_addr : int list,
        dest_addr : int list
    }

    val intToProt : int -> protocol
    val protToInt : protocol -> int
    val protToString : protocol -> string 

    val isFragmented : headerIPv4 -> bool

    val printIPv4 : headerIPv4 -> unit
    val decodeIPv4 : string -> headerIPv4 * string
    val encodeIPv4 : headerIPv4 -> string -> string
end 