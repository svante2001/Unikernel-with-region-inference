
fun decode_UDP s = {
    source_port = String.substring (s, 0, 2) |> convertRawBytes,
    dest_port = String.substring (s, 2, 2) |> convertRawBytes,
    UDP_length = String.substring (s, 4, 2) |> convertRawBytes,
    checksum = String.substring (s, 6, 2) |> convertRawBytes,
    data = String.extract (s, 8, NONE)
}

fun printUPD ({
    UPD_length,
    source_port,
    dest_port,
    checksum,
    data
}) = 
    "\n--UDP INFO--\n" ^
    "Source port: " ^ Int.toString source_port ^ "\n" ^
    "Destination port: " ^ Int.toString dest_port ^ "\n" ^
    "UDP length: " ^ Int.toString UPD_length ^ "\n" ^
    "Checksum: " ^ Int.toString checksum ^ "\n" ^
    "Data: " ^ data ^ "\n"
    |> print

fun encodeUDP Source_port Dest_port UDP_Length Checksum Data =
    (intToRawbyteString Source_port 2) ^
    (intToRawbyteString Dest_port 2) ^
    (intToRawbyteString (8 + String.size Data) 2) ^
    (intToRawbyteString 0 2) ^
    Data
