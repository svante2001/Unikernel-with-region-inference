datatype prot = ICMP | TCP | UDP | UNKNOWN

fun intToProt i =
    case i of 
      0x01 => ICMP
    | 0x06 => TCP
    | 0x11 => UDP 
    | _ => UNKNOWN

fun protToString p =
    case p of 
      ICMP => "ICMP"
    | TCP => "TCP"
    | UDP => "UDP"
    | _ => "Uknown protocol"

fun decode_IPv4 s =
    {
        version = (String.substring (s, 0, 1) |> convertRawBytes) div 16,
        ihl = (String.substring (s, 0, 1) |> convertRawBytes) mod 16,
        dscp = (String.substring (s, 0, 1) |> convertRawBytes) div 4, 
        ecn = (String.substring (s, 1, 1) |> convertRawBytes) mod 4,
        total_length = String.substring (s, 2, 2) |> convertRawBytes,
        identification = String.substring (s, 4, 2) |> convertRawBytes,
        flags = (String.substring (s, 6, 2) |> convertRawBytes) div 8192,
        fragment_offset = (String.substring (s, 6, 2) |> convertRawBytes) mod 8192, 
        time_to_live = String.substring (s, 8, 1) |> convertRawBytes,
        protocol = String.substring (s, 9, 1) |> convertRawBytes |> intToProt,
        header_checksum = String.substring (s, 10, 2) |> convertRawBytes,
        source_addr = String.substring (s, 12, 4) |> toByteList,
        dest_addr = String.substring (s, 16, 4) |> toByteList,
        payload = String.extract (s, 20, NONE)
    }

fun printIPv4 ({
    version,
    ihl,
    dscp,
    ecn,
    total_length,
    identification,
    flags,
    fragment_offset,
    time_to_live,
    protocol,
    header_checksum,
    source_addr,
    dest_addr,
    payload
}) =
    "\n\n-- IPv4 packet --\n" ^
    "Version: " ^ Int.toString version  ^ "\n" ^
    "IHL: " ^ Int.toString ihl  ^ "\n" ^
    "DSCP: " ^ Int.toString dscp  ^ "\n" ^
    "ECN: " ^ Int.toString ecn  ^ "\n" ^
    "Total length: " ^ Int.toString total_length  ^ "\n" ^
    "Identification: " ^ Int.toString identification  ^ "\n" ^
    "Flags: " ^ Int.toString flags  ^ "\n" ^
    "Fragment offset: " ^ Int.toString fragment_offset  ^ "\n" ^
    "Time to live: " ^ Int.toString time_to_live ^ "\n" ^
    "Protocol: " ^ (protocol |> protToString) ^ "\n" ^
    "Header checksum: " ^ Int.toString header_checksum  ^ "\n" ^
    "SRC-ADDRESS: " ^ rawBytesString source_addr  ^ "\n" ^
    "DST-ADDRESS: " ^ rawBytesString dest_addr  ^ "\n"
    |> print
