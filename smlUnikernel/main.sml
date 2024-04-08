fun l () =
    let 
        val s = read_tap ()
        val ethFrame = String.extract (s, 4, NONE) |> decodeEthFrame 
        val {prot, dstMac, srcMac, payload} = ethFrame
    in
        printEtherFrame ethFrame;
        printRawBytes (String.extract (s, 18, NONE));
        (case prot of 
        ARP => print "Found arp\n"
        | _ => print "Found other packet\n");
        l ()
    end

val _ = (
    print ("Starting tap\n");
    l ()
)
