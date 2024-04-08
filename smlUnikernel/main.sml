fun l () =
    let 
        val s = read_tap ()
        val ethFrame = String.extract (s, 4, NONE) |> decodeEthFrame 
        val {prot, dstMac, srcMac, payload} = ethFrame
        val arp = String.extract (s, 18, NONE) |> decodeArp
    in
        printEtherFrame ethFrame;
        (case prot of 
          ARP => printArp arp
        | _ => print "Found other packet\n");
        l ()
    end

val _ = (
    print ("Starting tap\n");
    l ()
)
