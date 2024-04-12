
fun decode_UDP s = {
    source_port = String.substring (s, 0, 2) |> convertRawBytes,
    dest_port = String.substring (s, 2, 2) |> convertRawBytes,
    UPD_length = String.substring (s, 4, 2) |> convertRawBytes,
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