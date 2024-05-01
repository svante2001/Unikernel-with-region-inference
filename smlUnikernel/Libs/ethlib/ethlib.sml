datatype ethType = ARP | IPv4 | IPv6 

datatype header_eth = Header_Eth of { 
  et : ethType, 
  dstMac : int list, 
  srcMac : int list
}

fun ethTypeToString ethType =
    (case ethType of
      ARP => "ARP"
    | IPv4 => "IPv4"
    | IPv6 => "IPv6")

fun ethTypeToInt ethType = 
    (case ethType of
      ARP => 0x0806
    | IPv4 => 0x0800
    | IPv6 => 0x86dd)

fun convertToEthType s =
    (case convertRawBytes s of
      0x0806 => SOME ARP
    | 0x0800 => SOME IPv4
    | 0x86dd => SOME IPv6
    | _ => NONE)

fun printEtherFrame (Header_Eth {et, dstMac, srcMac}) =
    "\n-- ETHERFRAME --\n" ^
    "Type: " ^ (ethTypeToString et) ^ "\n" ^
    "Source mac-addreess: [" ^ (rawBytesString srcMac) ^ " ]\n" ^
    "Destination mac-address: [" ^ (rawBytesString dstMac) ^ " ]\n"
    |> print

fun decodeEthFrame s = 
    (case String.substring (s, 12, 2) |> convertToEthType of 
          SOME p => (Header_Eth {
              et = p, 
              dstMac = String.substring (s, 0, 6) |> toByteList, 
              srcMac = String.substring (s, 6, 6) |> toByteList
            }, String.extract (s, 14, NONE))
        | NONE => raise Fail "Protocol not found.")

fun encodeEthFrame (Header_Eth {et, dstMac, srcMac}) payload = 
  byteListToString dstMac ^ 
  byteListToString srcMac ^
  (intToRawbyteString (et |> ethTypeToInt) 2) ^ 
  payload
