datatype packet = Packet of {
    data: string,
    offset: int
}

val mac = [123, 124, 125, 126, 127, 128]

val packetList : (int * (packet list ref)) list ref = ref []

val listenOn = ref []

fun bindUDP port cbf = listenOn := (port, cbf) :: !listenOn 

fun addPacket p id  = 
    case List.find (fn (id2, _) => id = id2) (!packetList) of 
        SOME (_, l) => l := p :: (!l)
    |   NONE => packetList := (id, ref [p]) :: (!packetList)

fun assemblePacket id prot =
    let fun findPacket [] _ = raise Fail "An error occured while assembling an IPv4 packet."
          | findPacket ((id2, l)::t) i = if id = id2 then (i, l) else findPacket t (i+1)
        val (index, pl) = findPacket (!packetList) 0
    in
        packetList := List.drop (!packetList, index);
        case prot of 
            UDP => 
                List.foldl 
                    (fn (Packet p, init) => 
                        let val (_, udpPay) = decodeUDP (#data p)
                        in udpPay ^ init end
                    ) 
                    "" (!pl)
        |   _ => raise Fail "Unimplemented protocol."
    end

fun handleArp ethFrame (Header_Eth ethHeader) =
    let val arp = SOME (String.extract (ethFrame, 14, NONE) |> decodeArp) handle _ => NONE
    in  case arp of
            SOME (Header_ARP arpHeader) => 
                let val arpPay = encodeArp (Header_ARP {
                        htype = 1, 
                        ptype = 0x0800,
                        hlen = 6,
                        plen = 4,
                        oper = Reply,
                        sha = mac, 
                        spa = [10, 0, 0, 2],
                        tha = (#sha arpHeader),
                        tpa = [10, 0, 0, 1, 0, 0]
                    })  
                    val ethPay = encodeEthFrame (Header_Eth { 
                        et = ARP,
                        dstMac = #srcMac ethHeader,
                        srcMac = mac
                    }) arpPay
                in
                    print "Recieved ARP packet\n";
                    byteListToString [0, 0, 8, 6] ^ ethPay
                    |> toByteList 
                    |> write_tap
                end
            | NONE => print "Was none"
    end

fun handleIPv4 ethFrame (Header_Eth ethHeader) = 
    (* let val ipv4 = String.extract (s, 14, NONE) |> decode_IPv4 |> verifyChecksumIPv4 *)
    let val (Header_IPv4 ipv4Header, ipv4Pay) = String.extract (ethFrame, 14, NONE) |> decodeIPv4
        val (Header_UDP udpHeader, udpPay) = ipv4Pay |> decodeUDP
    in  addPacket (Packet {data = ipv4Pay, offset = #fragment_offset ipv4Header}) (#identification ipv4Header);
        printUDPHeader (Header_UDP udpHeader);
        if isFragmented (Header_IPv4 ipv4Header) then (print "Got fragmented packet\n")
        else 
        (let val dataGotten = assemblePacket (#identification ipv4Header) UDP 
             val found = List.find (fn (port, cb) => (#dest_port udpHeader) = port) (!listenOn)
             fun send payload = 
                (let 
                    val udpPay =
                        encodeUDP 
                           (Header_UDP {
                                source_port = (#dest_port udpHeader),
                                dest_port = (#source_port udpHeader),
                                length = (#length udpHeader),
                                checksum = (#checksum udpHeader)
                            })
                            payload 
                    val ipv4Pay =
                        encodeIpv4
                            (Header_IPv4 {
                                version = (#version ipv4Header),
                                ihl = (#ihl ipv4Header),
                                dscp = (#dscp ipv4Header),
                                ecn = (#ecn ipv4Header),
                                total_length = (#total_length ipv4Header),
                                identification = (#identification ipv4Header),
                                flags = (#flags ipv4Header),
                                fragment_offset = (#fragment_offset ipv4Header),
                                time_to_live = (#time_to_live ipv4Header),
                                protocol = (#protocol ipv4Header),
                                header_checksum = (#header_checksum ipv4Header),
                                source_addr = (#dest_addr ipv4Header),
                                dest_addr = (#source_addr ipv4Header) 
                            })
                            udpPay
                    val ethPay =
                        encodeEthFrame 
                            (Header_Eth {et = IPv4, dstMac = #srcMac ethHeader, srcMac = mac}) 
                            ipv4Pay
                in 
                    print "Recieved IPv4 packet\n";
                    dataGotten ^ "\n" |> print;
                    ([0, 0, 8, 0] |> byteListToString) ^ ethPay
                    |> toByteList 
                    |> write_tap 
                end)
            in
                (case found of
                      SOME (_, cb) => cb dataGotten |> send
                    | NONE => "Port is not mapped to a function." |> send)
            end)
    end

fun listen () = 
    let 
        val rawTap = read_tap () 
        val ethFrame = String.extract (rawTap, 4, NONE)
        val (ethHeader, ethPayload) = ethFrame |> decodeEthFrame 
        val Header_Eth {et, dstMac, srcMac} = ethHeader
    in
        (case et of 
              ARP => handleArp ethFrame ethHeader
            | IPv4 => handleIPv4 ethFrame ethHeader
            | _ => print "Recieved other packet\n"
        );
        listen ()
    end