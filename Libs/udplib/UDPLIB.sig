(*
    The UDPLib structure provides to de- and encode UDP headers.
*)

signature UDPLIB = sig
    datatype header = Header of {
        source_port: int,
        dest_port: int,
        length : int,
        checksum: int
    } 

    val toString : header -> string
    val decode : string -> header * string
    val encode : header -> string -> string
end

(*
[header] contains the fields in a UDP header.

[toString] combines all the fields of a UDP header to easy printing. 

[decode] decodes a string as a UDP header.

[encode] encode the fields of a UDP header to a string.
*)