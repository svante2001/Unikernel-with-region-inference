val mac = [123, 124, 125, 126, 127, 128]

val ipAddress = [10, 0, 0, 2]

datatype packetID = PktID of {
    ipaddr: int list,
    id: int,
    prot: protocol,
    length: int,
    fragmentSum: int ref
}

datatype packet = Packet of { data: string, offset: int} 

fun pktIDCmp (PktID pktID1) (PktID pktID2) = 
    let fun ipCmp [] [] = true
          | ipCmp (hd1::tl1) (hd2::tl2) = if hd1 = hd2 then ipCmp tl1 tl2 else false
          | ipCmp _ _ = false
    in ipCmp (#ipaddr pktID1) (#ipaddr pktID2) andalso (#id pktID1) = (#id pktID2) andalso (#prot pktID1) = (#prot pktID2)
    end  

val packetList : (packetID * (char array)) list ref = ref []

val listenOn = ref []

fun bindUDP (port : int) (cbf : string -> string) = listenOn := (port, cbf) :: !listenOn 

fun initPktID (Header_IPv4 ipv4Hdr) = PktID {
    ipaddr = (#source_addr ipv4Hdr), 
    id = (#identification ipv4Hdr), 
    prot = (#protocol ipv4Hdr), 
    length = #total_length ipv4Hdr, 
    fragmentSum = ref 0
}

fun getPacket (Header_IPv4 ipv4Hdr) =
    let val pktID1 = initPktID (Header_IPv4 ipv4Hdr)
    in  List.find (fn (pktID2, _) => pktIDCmp pktID1 pktID2) (!packetList)
    end

fun addPacket (Header_IPv4 ipv4Hdr) payload = 
    let fun updatePacket arr pli arri = 
            if pli < String.size payload then 
                (Array.update (arr, arri, String.sub (payload, pli));
                updatePacket arr (pli+1) (arri+1))
            else ()
    in  print "Adding packet\n";
        case getPacket (Header_IPv4 ipv4Hdr) of 
            SOME (PktID pktID, arr) =>
                (#fragmentSum pktID := !(#fragmentSum pktID) + String.size payload;
                updatePacket arr 0 (#fragment_offset ipv4Hdr))
        |   NONE => 
            let val PktID pktID = initPktID (Header_IPv4 ipv4Hdr) 
                val arr = Array.array (#total_length ipv4Hdr, #"\000")
            in  (#fragmentSum pktID) := 20 + (String.size payload);
                updatePacket arr 0 (#fragment_offset ipv4Hdr);
                packetList := (PktID pktID, arr) :: (!packetList)
            end
    end

fun assemblePacket ipv4Hdr = 
    let val pktID = initPktID ipv4Hdr
        fun findPacket [] _ = raise Fail "An error occured while assembling an IPv4 packet."
          | findPacket ((pktID2, arr)::t) i = if pktIDCmp pktID pktID2 then (i, arr) else findPacket t (i+1)
        val (index, arr) = findPacket (!packetList) 0
    in  packetList := List.drop (!packetList, index);
        Array.foldr (op ::) [] arr |> String.implode
    end

fun ethSend et dstMac payload = 
    let val ethHeader = encodeEthFrame (Header_Eth { 
                et = et,
                dstMac = dstMac,
                srcMac = mac
            }) payload
    in  intToRawbyteString (ethTypeToInt et) 4 ^
        ethHeader
        |> toByteList
        |> write_tap
    end 

fun ipv4Send ({identification, protocol, dest_addr, dstMac}) payload = 
    let val ipv4Header = 
            encodeIpv4 (Header_IPv4 {
                version = 4,            (* This is only for version 4 (ipv4) *)
                ihl = 5,                (* Options are not allowed *)
                dscp = 0,               (* Service class is standard *)
                ecn = 0,                (* Not ECN capable *)
                total_length = 20 + (String.size payload),
                identification = identification,
                flags = 0,
                fragment_offset = 0,
                time_to_live = 128,     (* Hard-coded time_to_live *)
                protocol = protocol,
                header_checksum = 0,    (* Will be calculated in encode *)  
                source_addr = ipAddress,
                dest_addr = dest_addr 
            }) payload
    in  ethSend IPv4 dstMac ipv4Header
    end

fun handleArp (Header_Eth ethHeader) ethFrame =
    let val arp = SOME (String.extract (ethFrame, 14, NONE) |> decodeArp) handle _ => NONE
    in  case arp of
            SOME (Header_ARP arpHeader) => 
                encodeArp (Header_ARP {
                    htype = 1, 
                    ptype = 0x0800,
                    hlen = 6,
                    plen = 4,
                    oper = Reply,
                    sha = mac, 
                    spa = ipAddress,
                    tha = (#sha arpHeader),
                    tpa = List.concat [(#spa arpHeader), [0, 0]] (* TODO: Why is the zeros needed *)
                }) 
                |> ethSend ARP (#dstMac ethHeader)
        |   NONE => print "Arp packet could not be decoded"
    end

fun handleUDP dstMac (Header_IPv4 ipv4Header) payload =
    let 
        val (Header_UDP udpHeader, udpPayload) = payload |> decodeUDP
        val found = List.find (fn (port, cb) => (#dest_port udpHeader) = port) (!listenOn)
    in
        printUDPHeader (Header_UDP udpHeader);
        case found of 
          SOME (_, cb) => 
            let val payload = cb udpPayload 
            in  encodeUDP (Header_UDP {length = 20 + String.size payload , source_port = (#dest_port udpHeader), dest_port = (#source_port udpHeader), checksum = 0}) payload
                |> ipv4Send ({identification = (#identification ipv4Header), dstMac = dstMac, protocol = UDP, dest_addr = #source_addr ipv4Header})
            end
        | NONE =>  encodeUDP (Header_UDP {  length = 20 + String.size payload, 
                                            source_port = (#dest_port udpHeader), 
                                            dest_port = (#source_port udpHeader), 
                                            checksum = 0}) 
                                            "Port is not mapped to a function."
                                            |> ipv4Send ({identification = (#identification ipv4Header), dstMac = dstMac, protocol = UDP, dest_addr = #source_addr ipv4Header})
    end

fun handleIPv4 (Header_Eth ethHeader) ethFrame = 
    let val (ipv4Header, ipv4Pay) = String.extract (ethFrame, 14, NONE) |> decodeIPv4
    in  addPacket ipv4Header ipv4Pay;
        printIPv4 ipv4Header;
        case getPacket ipv4Header of
            SOME (PktID pktID, _) => 
                (print "Fragmentsum: ";
                Int.toString (!(#fragmentSum pktID)) |> print;
                print "\nLength: ";
                Int.toString (#length pktID) |> print;
                print "\n";
                if !(#fragmentSum pktID) = (#length pktID) then 
                    let val pkt = assemblePacket ipv4Header
                        val Header_IPv4 ipv4Header2 = ipv4Header
                    in  case (#protocol ipv4Header2) of 
                          UDP => handleUDP (#srcMac ethHeader) ipv4Header pkt
                        | _ => ()
                    end
                else ())
        |   NONE => ()
    end

fun listen () = 
    let 
        val rawTap = read_tap () 
        val ethFrame = String.extract (rawTap, 4, NONE)
        val (ethHeader, ethPayload) = ethFrame |> decodeEthFrame 
        val Header_Eth {et, dstMac, srcMac} = ethHeader
    in
        (case et of 
              ARP => handleArp ethHeader ethFrame
            | IPv4 => handleIPv4 ethHeader ethFrame
            | _ => print "Recieved other packet\n"
        );
        listen ()
    end