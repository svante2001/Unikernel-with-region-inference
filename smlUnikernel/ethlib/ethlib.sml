datatype ethType = ARP | IPv4 | IPv6 

fun ethTypeToString ethType =
    case ethType of
      ARP => "ARP"
    | IPv4 => "IPv4"
    | IPv6 => "IPv6"

fun ethTypeToInt ethType = 
    case ethType of
      ARP => 0x0806
    | IPv4 => 0x0800
    | IPv6 => 0x86dd

fun printEtherFrame({prot : ethType, dstMac : int list, srcMac : int list, payload : string}) =
    "\n-- ETHERFRAME --\n" ^
    "Type: " ^ (ethTypeToString prot) ^ "\n" ^
    "Source mac-addreess: [" ^ (rawBytesString srcMac) ^ " ]\n" ^
    "Destination mac-address: [" ^ (rawBytesString dstMac) ^ " ]\n" ^
    "Length of payload: " ^ (String.size payload |> Int.toString) ^ "\n\n" 
    |> print

fun convertToEthType s =
    case convertRawBytes s of
      0x0806 => SOME ARP
    | 0x0800 => SOME IPv4
    | 0x86dd => SOME IPv6
    | _ => NONE

fun decodeEthFrame s = 
    let 
        val prot = String.substring (s, 12, 2) |> convertToEthType
        val dstMac = String.substring (s, 0, 6) |> toByteList
        val srcMac = String.substring (s, 6, 6) |> toByteList 
        val payload = String.extract (s, 14, NONE)
    in
        case prot of 
          SOME p => {prot = p, dstMac = dstMac, srcMac = srcMac, payload = payload}
        | NONE => raise Fail "Protocol not found."
    end

fun encodeEthFrame dst_macaddr src_macaddr eth_type payload = 
  byteListToString dst_macaddr ^ 
  byteListToString src_macaddr ^
  (eth_type |> ethTypeToInt |> intToRawbyteString 2) ^ 
  payload
