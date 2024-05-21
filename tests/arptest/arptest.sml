val header = {
        htype = 1, 
        ptype = 0x0800, 
        hlen = 6, 
        plen = 4, 
        oper = ARP.Reply, 
        sha = [123, 124, 125, 126, 127, 128], 
        spa = [10, 0, 0, 2], 
        tha = [123, 124, 125, 126, 127, 128], 
        tpa = [10, 0, 0, 2]
    }

val testRaw = 
    (intToRawbyteString (#htype header) 2) ^
    (intToRawbyteString (#ptype header) 2) ^
    (intToRawbyteString (#hlen header) 1) ^
    (intToRawbyteString (#plen header) 1) ^
    (intToRawbyteString 2 2) ^
    byteListToString (#sha header) ^
    byteListToString (#spa header) ^
    byteListToString (#tha header) ^
    byteListToString (#tpa header)

val () = (
    setTestSuiteName "ARP";
    
    printStart ();

    assert ("toArpOperation request",
        (fn () => ARP.toArpOperation 1),
        (ARP.Request),
        (fn x => ARP.arpOperationToString x)
    );

    assert ("toArpOperation reply",
        (fn () => ARP.toArpOperation 2),
        (ARP.Reply),
        (fn x => ARP.arpOperationToString x)
    );

    assert ("arpOperationToString request",
        (fn () => ARP.arpOperationToString ARP.Request),
        ("Request"),
        (fn s => s)
    );

    assert ("arpOperationToString reply",
        (fn () => ARP.arpOperationToString ARP.Reply),
        ("Reply"),
        (fn s => s)
    );

    assert ("arpOperationToInt request",
        (fn () => ARP.arpOperationToInt ARP.Request),
        (1),
        (fn x => x |> ARP.toArpOperation |> ARP.arpOperationToString)
    );

    assert ("arpOperationToInt reply",
        (fn () => ARP.arpOperationToInt ARP.Reply),
        (2),
        (fn x => x |> ARP.toArpOperation |> ARP.arpOperationToString)
    );

    assert ("toString",
        (fn () => ARP.toString (ARP.Header header)),
        ("\n-- ARP-packet --\nHardware type: 1\nProtocol type: 2048\nHardware address length: 6\nProtocol address length: 4\nOperation: Reply\nSender hardware address: [123 124 125 126 127 128]\nSender protocol address: [10 0 0 2]\nTarget hardware adress: [123 124 125 126 127 128]\nTarget protocol address: [10 0 0 2]\n\n"),
        (fn s => s)
    );

    assert ("decode",
        (fn () => ARP.decode testRaw),
        (ARP.Header header),
        (fn (h) => ARP.toString h)
    );

    assert ("encode",
        (fn () => ARP.encode (ARP.Header header)),
        testRaw,
        (rawBytesString o toByteList)
    );

    printResult ()
)
