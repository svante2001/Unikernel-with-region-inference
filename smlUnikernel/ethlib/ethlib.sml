datatype ethType = ARP | IPv4 | IPv6 

fun ethTypeToString ethType =
    case ethType of
      ARP => "ARP"
    | IPv4 => "IPv4"
    | IPv6 => "IPv6"

fun printEtherFrame({prot : ethType, dstMac : int list, srcMac : int list, payload : string}) = (
    print "ETHERFRAME:\n";
    "Type: " ^ (ethTypeToString prot) ^ "\n" |> print;
    "Source mac-addreess: [" ^ (rawBytesString srcMac) ^ " ]\n" |> print;
    "Destination mac-address: [" ^ (rawBytesString dstMac) ^ " ]\n" |> print;
    "Length of payload: " ^ (String.size payload |> Int.toString) ^ "\n" |> print; 
    print "\n"
)

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
