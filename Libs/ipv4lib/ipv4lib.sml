structure IPv4 : IPV4 = struct 
    datatype protocol = ICMP | TCP | UDP | UNKNOWN

    datatype header = Header of {
        version : int,
        ihl : int,
        dscp : int,
        ecn : int,
        total_length : int,
        identification : int,
        flags : int,
        fragment_offset : int,
        time_to_live : int,
        protocol : protocol,
        header_checksum : int,
        source_addr : int list,
        dest_addr : int list
    }

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
            val sumWithoutCarry = sum - (sum - getRBits sum 16) 
        in sumWithoutCarry + carry |> Word.fromInt |> Word.notb |> (fn w => Word.andb (Word.fromInt 0xFFFF, w)) |> Word.toInt
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

    fun isFragmented (Header r) = if (#flags r) = 1 then true else false

    fun verifyChecksumIPv4 header payload =
        let val (Header {
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
                dest_addr
            }) = header
            val checksumHeader = 
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
            val checkSum = checksumHeader |> toByteList |> toHextets |> ipv4Checksum
        in  if checkSum = header_checksum then (header, payload) 
            else raise Fail "Bad checksum in incomming IPv4 packet."
        end

    (* TODO: Does not handle options, ignores ihl *)
    fun decode s = (Header {
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
            dest_addr = String.substring (s, 16, 4) |> toByteList
        }, String.extract (s, 20, NONE))

    fun toString (Header {
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
        dest_addr
    }) =
        "\n-- IPV4 INFO --\n" ^
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

    fun encode (Header {
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
        dest_addr
    }) payload =
        let val checksumHeader = 
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
            val checkSum = checksumHeader |> toByteList |> toHextets |> ipv4Checksum
            val header = String.substring (checksumHeader, 0, 10) ^ intToRawbyteString checkSum 2 ^ String.extract (checksumHeader, 12, NONE)
        in  header ^ payload
        end
end