signature IPV4 = sig 
    datatype protocol = ICMP | TCP | UDP | UNKNOWN

    datatype header = Header of {
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

    val isFragmented : header -> bool

    val toString : header -> string
    val decode : string -> header * string
    val encode : header -> string -> string
end 