(*
    The UDPLib structure provides to de- and encode UDP headers.
*)

signature UDPLIB = sig
    datatype headerUDP = HeaderUDP of {
        source_port: int,
        dest_port: int,
        length : int,
        checksum: int
    } 

    val printUDPHeader : headerUDP -> unit
    val decodeUDP : string -> headerUDP * string
    val encodeUDP : headerUDP -> string -> string
end

(*
[headerUDP] contains the fields in a UDP header.

[decodeUDP] decodes a string as a UDP header.

[printUDPHeader] pretty prints the fields of a UDP header. 

[encodeUDP] encode the fields of a UDP header to a string.
*)