datatype packet = Packet of {
    data: string,
    offset: int
}

val packetList : (int * (packet list ref)) list ref = ref []

val listenOn = ref []

fun bindUDP port cbf = listenOn := (port, cbf) :: !listenOn 

fun addPacket p id = 
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
                        let val u = decode_UDP (#data p)
                        in (#data u) ^ init end
                    ) 
                    "" (!pl)
        |   _ => raise Fail "Unimplemented protocol."
    end

fun listen () = 
    let 
        val t = read_tap () 
        val s = String.extract (t, 4, NONE)
        val ethFrame = s |> decodeEthFrame 
        val {prot, dstMac, srcMac, payload} = ethFrame
        val mac = [123, 124, 125, 126, 127, 128]
    in
        (case prot of 
              ARP =>
                let val arp = SOME (String.extract (s, 14, NONE) |> decodeArp) handle _ => NONE
                in
                    case arp of
                        SOME s => 
                            let
                                val {hlen: int, htype: int, oper: ARP_OP, plen: int, ptype: int, sha: int list, spa: int list,  tha: int list, tpa: int list} = s
                                val send = (([0, 0, 8, 6] |> byteListToString) ^ 
                                (encodeArp 1 0x0800 6 4 Reply mac [10, 0, 0, 2] sha [10, 0, 0, 1, 0, 0]
                                |> encodeEthFrame srcMac mac ARP))
                            in
                                print "Recieved ARP packet\n";
                                write_tap (send |> toByteList)
                            end
                        | NONE => print "Was none"
                end
            | IPv4 => 
                (* let val ipv4 = String.extract (s, 14, NONE) |> decode_IPv4 |> verify_checksum_ipv4 *)
                let val ipv4 = String.extract (s, 14, NONE) |> decode_IPv4
                    val udp = (#payload ipv4) |> decode_UDP
                in  addPacket (Packet {data = #payload ipv4, offset = #fragment_offset ipv4}) (#identification ipv4);
                    printUDP udp;
                    if is_fragmented ipv4 then (print "Got fragmented packet\n")
                    else 
                    (let val dataGotten = assemblePacket (#identification ipv4) UDP 
                         val found = List.find (fn (port, cb) => (#dest_port udp) = port) (!listenOn)
                         fun send message = 
                            let val echo =
                                (message)
                                |> encodeUDP (#dest_port udp) (#source_port udp) (#UDP_length udp) (#checksum udp)
                                |> encodeIpv4 
                                    (#ihl ipv4)
                                    (#dscp ipv4)
                                    (#ecn ipv4)
                                    (#identification ipv4)
                                    (#flags ipv4)
                                    (#fragment_offset ipv4)
                                    (128)
                                    (#protocol ipv4)
                                    (#header_checksum ipv4)
                                    (#dest_addr ipv4)
                                    (#source_addr ipv4)
                                |> encodeEthFrame srcMac mac IPv4
                            val send2 = (([0, 0, 8, 0] |> byteListToString) ^ echo)
                            in 
                                print "Recieved IPv4 packet!!!\n";
                                dataGotten ^ "\n" |> print;
                                send2 |> toByteList |> write_tap 
                            end
                    in
                    print "Got to case\n";
                    (case found of
                          SOME (_, cb) => (print "here2\n"; cb dataGotten |> send)
                        | NONE => (print "here3\n"; "Port is not mapped to a function." |> send));
                    print "Case done\n"
                    end)
                end
            | _ => print "Recieved other packet\n"
        );
        listen ()
    end