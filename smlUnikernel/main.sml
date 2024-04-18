fun l () =
    let 
        val t = read_tap () 
        val s = String.extract (t, 4, NONE)
        val ethFrame = s |> decodeEthFrame 
        val {prot, dstMac, srcMac, payload} = ethFrame
        val mac = [123, 124, 125, 126, 127, 128]
    in
        print "Initial packet\n";
        t |> printRawBytes;
        print "\n";
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
                        | NONE => (print "Was none"; l())
                end  
            | IPv4 => 
                let val ipv4 = String.extract (s, 14, NONE) |> decode_IPv4
                    val udp = (#payload ipv4) |> decode_UDP
                    val echo = 
                        (#data udp)
                        |> encodeUDP (#dest_port udp) (#source_port udp) (#UDP_length udp) (#checksum udp)
                        |> encodeIpv4 
                            (#ihl ipv4)
                            (#dscp ipv4)
                            (#ecn ipv4)
                            (#total_length ipv4)
                            (#identification ipv4)
                            (#flags ipv4)
                            (#fragment_offset ipv4)
                            (#protocol ipv4)
                            (#header_checksum ipv4)
                            (#dest_addr ipv4)
                            (#source_addr ipv4)
                    val send = (([0, 0, 8, 0] |> byteListToString) ^ (echo |> encodeEthFrame srcMac mac IPv4))
                in
                    print "\nSending echo back\n";
                    send
                    |> toByteList
                    |> write_tap
                end
            | _ => print "Recieved other packet\n");
        l ()
    end
    
val _ = (
    l ()
)
