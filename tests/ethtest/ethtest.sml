val header = {
        et=Eth.ARP, 
        dstMac = [133, 134, 135, 136, 137, 138], 
        srcMac = [123, 124, 125, 126, 127, 128]
}

val payload = "test payload"

val testRaw = 
    (byteListToString (#dstMac header)) ^
    (byteListToString (#srcMac header)) ^
    (intToRawbyteString 0x0806 2) ^
    payload

val () = (
    setTestSuiteName "Eth";
    
    printStart ();

    assert  ("ethTypeToInt ARP",
            (fn () => Eth.ethTypeToInt Eth.ARP),
            0x0806,
            Int.toString         
    );
    assert  ("ethTypeToInt IPv4",
            (fn () => Eth.ethTypeToInt Eth.IPv4),
            0x0800,
            Int.toString         
    );
    assert  ("ethTypeToInt IPv6",
            (fn () => Eth.ethTypeToInt Eth.IPv6),
            0x86dd,
            Int.toString         
    );

    assert  ("ethTypeToString ARP",
            (fn () => Eth.ethTypeToString Eth.ARP),
            "ARP",
            (fn s => s)         
    );
    assert  ("ethTypeToString IPv4",
            (fn () => Eth.ethTypeToString Eth.IPv4),
            "IPv4",
            (fn s => s)         
    );
    assert  ("ethTypeToString IPv6",
            (fn () => Eth.ethTypeToString Eth.IPv6),
            "IPv6",
            (fn s => s)         
    );

    assert  ("bytesToEthType ARP",
            (fn () => Eth.bytesToEthType "\u0008\u0006"),
            SOME (Eth.ARP),
            (fn SOME et => "SOME " ^ (Eth.ethTypeToString et) | NONE => "NONE")         
    );
    assert  ("bytesToEthType IPv4",
            (fn () => Eth.bytesToEthType "\u0008\u0000"),
            SOME (Eth.IPv4),
            (fn SOME et => "SOME " ^ (Eth.ethTypeToString et) | NONE => "NONE")         
    );
    assert  ("bytesToEthType IPv6",
            (fn () => Eth.bytesToEthType "\u0086\u00dd"),
            SOME (Eth.IPv6),
            (fn SOME et => "SOME " ^ (Eth.ethTypeToString et) | NONE => "NONE")         
    );
    assert  ("bytesToEthType IPv6",
            (fn () => Eth.bytesToEthType "\u0000\u0000"),
            NONE,
            (fn SOME et => "SOME " ^ (Eth.ethTypeToString et) | NONE => "NONE")         
    );

    assert  ("toString", 
            (fn () => Eth.toString (Eth.Header header)),
            ("\n-- ETHERFRAME INFO --\nType: ARP\nDestination mac-address: [ 133 134 135 136 137 138 ]\nSource mac-address: [ 123 124 125 126 127 128 ]\n"),
            (fn s => s));

    assert  ("decode", 
            (fn () => Eth.decode testRaw), 
            (Eth.Header header, payload),
            (fn (h, p) => "(" ^ (Eth.toString h) ^ ", " ^ p ^ ")"));
    
    assert  ("encode", 
            (fn () => Eth.encode (Eth.Header header) payload), 
            testRaw, 
            (rawBytesString o toByteList));

   assert  ("decode |> encode", 
            (fn () => Eth.decode testRaw |> (fn (h, p) => Eth.encode h p)), 
            testRaw,
            (rawBytesString o toByteList));
    
    assert  ("encode |> decode", 
            (fn () => Eth.encode (Eth.Header header) payload |> Eth.decode), 
            (Eth.Header header, payload), 
            (fn (h, p) => "(" ^ (Eth.toString h) ^ ", " ^ p ^ ")"));
        
    printResult ()
)
