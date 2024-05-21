val header = {source_port=12345, dest_port=8080, length=20, checksum=0}

val wrongHeader = {source_port=12345, dest_port=8080, length=0, checksum=0}

val payload = "test payload"

val testRaw = 
    (intToRawbyteString (#source_port header) 2) ^
    (intToRawbyteString (#dest_port header) 2) ^
    (intToRawbyteString (#length header) 2) ^
    (intToRawbyteString (#checksum header) 2) ^ 
    payload

val () = (
    setTestSuiteName "UDP";
    
    printStart ();

    assert  ("UDP toString", 
            (fn () => UDP.toString (UDP.Header header)),
            ("\n--UDP INFO--\nSource port: 12345\nDestination port: 8080\nUDP length: 20\nChecksum: 0\n"),
            (fn s => s));

    assert  ("UDP decode", 
            (fn () => UDP.decode testRaw), 
            (UDP.Header header, payload),
            (fn (h, p) => "(" ^ (UDP.toString h) ^ ", " ^ p ^ ")"));
    
    assert  ("UDP encode", 
            (fn () => UDP.encode (UDP.Header header) payload), 
            testRaw, 
            (rawBytesString o toByteList));

    (* Length is calculated independent of length value in header *)
    assert  ("UDP encode with wrong header", 
            (fn () => UDP.encode (UDP.Header wrongHeader) payload), 
            testRaw, 
            (rawBytesString o toByteList));
    
    printResult ()
)
