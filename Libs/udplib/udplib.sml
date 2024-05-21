structure UDP: UDPLIB = struct

    datatype header = Header of {
        source_port: int,
        dest_port: int,
        length : int,
        checksum: int
    } 

    fun toString (Header {
        source_port,
        dest_port,
        length,
        checksum
    }) = 
        "\n-- UDP INFO --\n" ^
        "Source port: " ^ Int.toString source_port ^ "\n" ^
        "Destination port: " ^ Int.toString dest_port ^ "\n" ^
        "UDP length: " ^ Int.toString length ^ "\n" ^
        "Checksum: " ^ Int.toString checksum ^ "\n"
    
    fun decode s = (Header {
        source_port = String.substring (s, 0, 2) |> convertRawBytes,
        dest_port = String.substring (s, 2, 2) |> convertRawBytes,
        length = String.substring (s, 4, 2) |> convertRawBytes,
        checksum = String.substring (s, 6, 2) |> convertRawBytes
    }, String.extract (s, 8, NONE))

    fun encode (Header { length, source_port, dest_port, checksum}) data =
        (intToRawbyteString source_port 2) ^
        (intToRawbyteString dest_port 2) ^
        (intToRawbyteString (String.size data + 8) 2) ^ (* Fix this *)
        (intToRawbyteString 0 2) ^
        data

end
