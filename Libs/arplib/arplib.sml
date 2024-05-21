structure ARP : ARPLIB = struct 

    datatype ARP_OP = Request | Reply

    datatype header = Header of {
        htype : int, 
        ptype : int, 
        hlen : int, 
        plen : int, 
        oper : ARP_OP, 
        sha : int list, 
        spa : int list, 
        tha : int list, 
        tpa : int list 
    }

    fun toArpOperation i =
        (case i of 
          1 => Request
        | 2 => Reply
        | _ => raise Fail "Could not determine arp operation")

    fun arpOperationToString arp =
        (case arp of
          Request => "Request"
        | Reply => "Reply")

    (* For some reason 'case of' cannot be used here??*)
    fun arpOperationToInt Request = 1
    | arpOperationToInt Reply = 2 

    fun toString (Header { htype, ptype, hlen, plen, oper, sha, spa, tha, tpa }) =
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

    fun encode (Header { htype, ptype, hlen, plen, oper, sha, spa, tha, tpa }) =
        (intToRawbyteString htype 2) ^
        (intToRawbyteString ptype 2) ^
        (intToRawbyteString hlen 1) ^
        (intToRawbyteString plen 1) ^
        (intToRawbyteString 2 2) ^
        byteListToString sha ^
        byteListToString spa ^
        byteListToString tha ^
        byteListToString tpa
    
    fun decode s =
        Header {   
            htype = String.substring (s, 0, 2) |> convertRawBytes,
            ptype = String.substring (s, 2, 2) |> convertRawBytes,
            hlen = String.substring (s, 4, 1) |> convertRawBytes,
            plen = String.substring (s, 5, 1) |> convertRawBytes,
            oper = String.substring (s, 6, 2) |> convertRawBytes |> toArpOperation,
            sha = String.substring (s, 8, 6) |> toByteList,
            spa = String.substring (s, 14, 4) |> toByteList, 
            tha = String.substring (s, 18, 6) |> toByteList,
            tpa = String.substring (s, 24, 4) |> toByteList 
        }
end 

