structure Eth : ETH = struct
  datatype ethType = ARP | IPv4 | IPv6 

  datatype header = Header of { 
    et : ethType, 
    dstMac : int list, 
    srcMac : int list
  }

  fun bytesToEthType s =
      (case convertRawBytes s of
        0x0806 => SOME ARP
      | 0x0800 => SOME IPv4
      | 0x86dd => SOME IPv6
      | _ => NONE)

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

  fun toString (Header {et, dstMac, srcMac}) =
      "\n-- ETHERFRAME INFO --\n" ^
      "Type: " ^ (ethTypeToString et) ^ "\n" ^
      "Destination mac-address: [ " ^ (rawBytesString dstMac) ^ " ]\n" ^
      "Source mac-address: [ " ^ (rawBytesString srcMac) ^ " ]\n" 

  fun decode s = 
      (case String.substring (s, 12, 2) |> bytesToEthType of 
            SOME p => (Header {
                et = p, 
                dstMac = String.substring (s, 0, 6) |> toByteList, 
                srcMac = String.substring (s, 6, 6) |> toByteList
              }, String.extract (s, 14, NONE))
          | NONE => raise Fail "Protocol not found.")

  fun encode (Header {et, dstMac, srcMac}) payload = 
    byteListToString dstMac ^ 
    byteListToString srcMac ^
    (intToRawbyteString (et |> ethTypeToInt) 2) ^ 
    payload
end 