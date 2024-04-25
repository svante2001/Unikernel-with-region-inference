datatype prot = ICMP | TCP | UDP | UNKNOWN

fun toHextets [] = []
  | toHextets [x] = [x]
  | toHextets (x::y::t) = x * (2 ** 8) + y :: toHextets t

fun hextetIsNeg ht = ht -  0x7FFF = 0x8000

fun hextetToOC ht = 
    if hextetIsNeg ht then 0xFFFF - ht - 1
    else ht

fun ipv4Checksum l = 
  let val sum = List.foldl (op +) 0 l 
      val carry = (sum - getRBits sum 16) div (2 ** 16) 
      val sum_withoutcarry = sum - (sum - getRBits sum 16) 
  in sum_withoutcarry + carry |> Word.fromInt |> Word.notb |> (fn w => Word.andb (Word.fromInt 0xFFFF, w)) |> Word.toInt
  end

fun intToProt i =
    case i of 
      0x01 => ICMP
    | 0x06 => TCP
    | 0x11 => UDP 
    | _ => UNKNOWN

fun protToInt i =
    case i of 
      ICMP => 0x01 
    | TCP => 0x06 
    | UDP => 0x11 
    | _ => raise Fail "Unknown protocol." 

fun protToString p =
    case p of 
      ICMP => "ICMP"
    | TCP => "TCP"
    | UDP => "UDP"
    | _ => "Uknown protocol"

fun decode_IPv4 s =
    {
        version = getLBits (String.substring (s, 0, 1) |> convertRawBytes) 4,
        ihl = getRBits (String.substring (s, 0, 1) |> convertRawBytes) 4,
        dscp = getLBits (String.substring (s, 1, 1) |> convertRawBytes) 6, 
        ecn = getRBits (String.substring (s, 1, 1) |> convertRawBytes) 2,
        total_length = String.substring (s, 2, 2) |> convertRawBytes,
        identification = String.substring (s, 4, 2) |> convertRawBytes,
        flags = getLBits (String.substring (s, 6, 1) |> convertRawBytes) 3,
        fragment_offset = getRBits (String.substring (s, 6, 2) |> convertRawBytes) 13, 
        time_to_live = String.substring (s, 8, 1) |> convertRawBytes,
        protocol = String.substring (s, 9, 1) |> convertRawBytes |> intToProt,
        header_checksum = String.substring (s, 10, 2) |> convertRawBytes,
        source_addr = String.substring (s, 12, 4) |> toByteList,
        dest_addr = String.substring (s, 16, 4) |> toByteList,
        payload = String.extract (s, 20, NONE)
    }

fun verify_checksum_ipv4 r =
    let val ({
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
    }) = r
    val checksum_header = 
        intToRawbyteString (setLBits 4 4 + ihl) 1 ^ 
        intToRawbyteString (setLBits dscp 6 + ecn) 1 ^ 
        intToRawbyteString (20 + String.size payload) 2 ^
        intToRawbyteString identification 2 ^
        intToRawbyteString ((setLBits flags 3 * (2 ** 8)) + fragment_offset) 2 ^
        intToRawbyteString time_to_live 1 ^
        intToRawbyteString (protocol |> protToInt) 1 ^ 
        intToRawbyteString 0 2 ^
        byteListToString source_addr ^
        byteListToString dest_addr
      val checkSum = checksum_header |> toByteList |> toHextets |> ipv4Checksum
    in 
      if checkSum = header_checksum then r else raise Fail "Bad checksum in incomming IPv4 packet."
    end

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


fun encodeIpv4  (* Version : This is always ipv4 *) 
                Ihl 
                Dscp 
                Ecn 
                (* Total_length  *)
                Identification 
                Flags 
                Fragment_offset 
                Time_to_live
                Protocol 
                Header_checksum 
                Source_addr 
                Dest_addr 
                Payload =
    let val checksum_header = 
          intToRawbyteString (setLBits 4 4 + Ihl) 1 ^ 
          intToRawbyteString (setLBits Dscp 6 + Ecn) 1 ^ 
          intToRawbyteString (20 + String.size Payload) 2 ^
          intToRawbyteString Identification 2 ^
          intToRawbyteString ((setLBits Flags 3 * (2 ** 8)) + Fragment_offset) 2 ^
          intToRawbyteString Time_to_live 1 ^
          intToRawbyteString (Protocol |> protToInt) 1 ^ 
          intToRawbyteString 0 2 ^
          byteListToString Source_addr ^
          byteListToString Dest_addr
        val checkSum = checksum_header |> toByteList |> toHextets |> ipv4Checksum
        val header = String.substring (checksum_header, 0, 10) ^ intToRawbyteString checkSum 2 ^ String.extract (checksum_header, 12, NONE)
    in
      (* print "Length:\n";
      Int.toString (20 + String.size Payload) |> print;
      print "\nChecksum cal:\n";
      Int.fmt StringCvt.HEX (checkSum) |> print;
      print "\n"; *)
      header ^ Payload
    end