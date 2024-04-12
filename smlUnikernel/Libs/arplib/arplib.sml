datatype ARP_OP = Request | Reply

fun toArpOperation i =
    case i of 
      1 => Request
    | 2 => Reply
    | _ => raise Fail "Could not determine arp operation"

(* fun arpOperationToInt op =
    case op of 
      Request => 1
    | Reply => 2 *)

fun arpOperationToString arp =
    case arp of
      Request => "Request"
    | Reply => "Reply"

fun decodeArp s =
    {   htype = String.substring (s, 0, 2) |> convertRawBytes,
        ptype = String.substring (s, 2, 2) |> convertRawBytes,
        hlen = String.substring (s, 4, 1) |> convertRawBytes,
        plen = String.substring (s, 5, 1) |> convertRawBytes,
        oper = String.substring (s, 6, 2) |> convertRawBytes |> toArpOperation,
        sha = String.substring (s, 8, 6) |> toByteList,
        spa = String.substring (s, 14, 4) |> toByteList, 
        tha = String.substring (s, 18, 6) |> toByteList,
        tpa = String.substring (s, 24, 4) |> toByteList 
    }

fun printArp {
        htype, 
        ptype, 
        hlen, 
        plen, 
        oper, 
        sha, 
        spa, 
        tha, 
        tpa
    } =
    "\n-- ARP-packet --\n" ^
    "Hardware type: " ^ Int.toString htype ^ "\n" ^
    "Protocol type: " ^ Int.toString ptype ^ "\n" ^
    "Hardware address length: " ^ Int.toString hlen ^ "\n" ^
    "Protocol address length: " ^ Int.toString plen ^ "\n" ^
    "Operation: " ^ arpOperationToString oper ^ "\n" ^
    "Sender hardware address: [" ^ rawBytesString sha ^ "]\n" ^
    "Sender protocol address: [" ^ rawBytesString spa ^ "]\n" ^
    "Target hardware adress: [" ^ rawBytesString tha ^ "]\n" ^
    "Target protocol address: [" ^ rawBytesString tpa ^ "]\n\n" 
    |> print

fun encodeArp Htyp Ptype Hlen Plen Oper Sha Spa Tha Tpa =
    (intToRawbyteString Htyp 2) ^
    (intToRawbyteString Ptype 2) ^
    (intToRawbyteString Hlen 1) ^
    (intToRawbyteString Plen 1) ^
    (intToRawbyteString 2 2) ^
    byteListToString Sha ^
    byteListToString Spa ^
    byteListToString Tha ^
    byteListToString Tpa
