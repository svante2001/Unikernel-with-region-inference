(*
    The IPv4lib structure provides useful functions for a ipv4 header.
*)

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

(*
[header] contains the fields in a UDP header.

[intToProt] converts an integer to a protocol e.g. ICMP.

[protToInt] converts a protocol to an integer.

[protToString] converts a protocol to a string for easy printing.

[isFragmented] detects if a ipv4 header is a fragmented a returns an appropiate boolean.

[toString] combines all the fields of a UDP header to easy printing. 

[decode] decodes a string as a UDP header.

[encode] encode the fields of a UDP header to a string.
*)