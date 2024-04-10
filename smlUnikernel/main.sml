fun l () =
    let 
        val s = String.extract (read_tap (), 4, NONE)
        val ethFrame = s |> decodeEthFrame 
        val {prot, dstMac, srcMac, payload} = ethFrame
    in
        (* print "Before\n";
        s |> printRawBytes;
        print "\n";
        print "After\n"; *)
        (* encodeEthFrame dstMac srcMac prot payload |> printRawBytes; *)
        (case prot of 
            ARP =>
                let
                    val arp = SOME (String.extract (s, 14, NONE) |> decodeArp) handle _ => NONE
                in
                    (* String.substring (s, 18, 2) |> printRawBytes; *)
                    case arp of
                        SOME s => 
                            let
                                val {hlen: int, htype: int, oper: ARP_OP, plen: int, ptype: int, sha: int list, spa: int list, tha: int list, tpa: int list} = s
                            in
                                printArp s;
                                print "encoded arp: ";
                                encodeArp htype ptype hlen plen tha tpa sha spa |> printRawBytes
                            end
                        | NONE => (print "Was none"; l())
                end
            | _ => print "Found other packet\n");
        l ()
    end

val _ = (
    print ("Starting tap\n");
    l ()
)
