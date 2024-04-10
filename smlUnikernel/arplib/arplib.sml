datatype ARP_OP = Request | Reply

fun toArpOperation i =
    case i of 
      1 => Request
    | 2 => Reply
    | _ => raise Fail "Could not determine arp"

(* fun arpOperationToInt op =
    case op of 
      Request => 1
    | Reply => 2 *)

fun arpOperationToString arp =
    case arp of
      Request => "Request"
    | Reply => "Reply"

fun decodeArp s =
    let
        val htype = String.substring (s, 0, 2) |> convertRawBytes
        val ptype = String.substring (s, 2, 2) |> convertRawBytes
        val hlen = String.substring (s, 4, 1) |> convertRawBytes
        val plen = String.substring (s, 5, 1) |> convertRawBytes
        val oper = String.substring (s, 6, 2) |> convertRawBytes |> toArpOperation
        val sha = String.substring (s, 8, 6) |> toByteList 
        val spa = String.substring (s, 14, 4) |> toByteList 
        val tha = String.substring (s, 18, 6) |> toByteList
        val tpa = String.substring (s, 24, 4) |> toByteList 
    in 
        {   htype = htype,
            ptype = ptype, 
            hlen = hlen, 
            plen = plen,
            oper = oper, 
            sha = sha, 
            spa = spa, 
            tha = tha, 
            tpa = tpa
        }
    end

fun printArp {
        htype = htype, 
        ptype = ptype, 
        hlen = hlen, 
        plen = plen, 
        oper = oper, 
        sha = sha, 
        spa = spa, 
        tha = tha, 
        tpa = tpa
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
