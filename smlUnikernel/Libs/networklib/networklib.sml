val mac = [123, 124, 125, 126, 127, 128]

datatype packetId = PktId of {
    ipaddr: int list,
    id: int
}

datatype packet = Packet of { data: string, offset: int} 

fun pktIDCmp (PktId pktID1) (PktId pktID2) = 
    let fun ipCmp [] [] = true
          | ipCmp (hd1::tl1) (hd2::tl2) = if hd1 = hd2 then ipCmp tl1 tl2 else false
          | ipCmp _ _ = false
    in ipCmp (#ipaddr pktID1) (#ipaddr pktID2) andalso (#id pktID1) = (#id pktID2)
    end 

val packetList : (packetId * (packet list ref)) list ref = ref []

val listenOn = ref []

fun bindUDP port cbf = listenOn := (port, cbf) :: !listenOn 

(* TODO: what if the first added packet is not the first packet *)
fun addPacket p pktID = 
    case List.find (fn (pktID2, _) => pktIDCmp pktID pktID2) (!packetList) of 
        SOME (_, l) => l := p :: (!l)
    |   NONE => packetList := (pktID, ref [p]) :: (!packetList)

fun assemblePacket pktID prot = 
    let fun findPacket [] _ = raise Fail "An error occured while assembling an IPv4 packet."
          | findPacket ((pktID2, l)::t) i = if pktIDCmp pktID pktID2 then (i, l) else findPacket t (i+1)
        val (index, pl) = findPacket (!packetList) 0
        fun sortFragments [] accl = accl
          | sortFragments (h::t) [] = sortFragments t [h]
          | sortFragments (h1::t1) (h2::t2) = 
                let val (Packet p1, Packet p2) = (h1, h2)
                in  if (#offset p1) <= (#offset p2) 
                    then sortFragments t1 (h1::h2::t2)
                    else sortFragments t1 (h2::(sortFragments [h1] t2))
                end  
    in  packetList := List.drop (!packetList, index);
        sortFragments (!pl) [] |> List.foldl (fn (Packet p, init) => init ^(#data p)) ""
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
    let val (Header_IPv4 ipv4Header, ipv4Pay) = String.extract (ethFrame, 14, NONE) |> decodeIPv4
        val (Header_UDP udpHeader, udpPay) = ipv4Pay |> decodeUDP
    in  
        addPacket (Packet {data = ipv4Pay, offset = #fragment_offset ipv4Header}) (PktId {ipaddr = #dest_addr ipv4Header, id = #identification ipv4Header});
        printUDPHeader (Header_UDP udpHeader);
        if isFragmented (Header_IPv4 ipv4Header) then (print "Got fragmented packet\n")
        else 
            let 
                val dataGotten = assemblePacket (PktId {ipaddr = #dest_addr ipv4Header, id = #identification ipv4Header}) UDP 
                val found = List.find (fn (port, cb) => (#dest_port udpHeader) = port) (!listenOn)
                
                fun send payload =
                    let  
                        val size = String.size payload
                        val numOfFrags = Real.ceil(Real.fromInt size / Real.fromInt 1500)
                        val fragments = List.tabulate (numOfFrags, fn i =>
                            let 
                                (* val fragPay = Substring.full (Substring.full (i * 1500) payload) *)
                                val fragPay = String.substring (payload, (i*1500), (Int.min(1500, size-(i*1500))))
                                val header =
                                    Header_UDP {
                                        source_port = (#dest_port udpHeader),
                                        dest_port = (#source_port udpHeader),
                                        length = 
                                            if i = numOfFrags-1 then 
                                                size - (i * 1500) + 8
                                            else
                                                1500,
                                        checksum = (#checksum udpHeader)
                                    }
                                val udpPay = encodeUDP header fragPay
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
                                ([0, 0, 8, 0] |> byteListToString) ^ ethPay
                                |> toByteList 
                                |> write_tap 
                            end
                        )
                    in
                        fragments
                    end
            in 
                print "hej"
            end
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