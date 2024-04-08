fun l () =
    let 
        val s = String.extract (read_tap (), 4, NONE)
        val ethFrame = s |> decodeEthFrame 
        val {prot, dstMac, srcMac, payload} = ethFrame
        val arp = SOME (String.extract (s, 12, NONE) |> decodeArp) handle _ => NONE
    in
        print "Before\n";
        s |> printRawBytes;
        print "\n";
        print "After\n";
        encodeEthFrame dstMac srcMac prot payload |> printRawBytes;
        print "\n";
        (case (prot, arp) of 
          (ARP, SOME a) => printArp a
        | _ => print "Found other packet\n");
        l ()
    end

val _ = (
    print ("Starting tap\n");
    l ()
)
