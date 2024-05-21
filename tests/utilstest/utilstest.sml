val () = (
    setTestSuiteName "Utils";
    
    printStart ();

    assert("toByteList", fn () => toByteList "\u0000\u00FF", [0, 255], rawBytesString);

    assert("rawByteString", fn () => rawBytesString [0, 255], "0 255", (byteListToString o toByteList));

    assert("byteListToString", fn () => byteListToString [0, 255], "\u0000\u00FF", rawBytesString o toByteList);

    assert("intToRawbyteString 1 zero byte", fn () => intToRawbyteString 0 1, "\u0000", rawBytesString o toByteList);

    assert("intToRawbyteString 2 zero bytes", fn () => intToRawbyteString 0 2, "\u0000\u0000", rawBytesString o toByteList);

    assert("intToRawbyteString 4 zero bytes", fn () => intToRawbyteString 0 4, "\u0000\u0000\u0000\u0000", rawBytesString o toByteList);

    assert("intToRawbyteString 8 zero bytes", fn () => intToRawbyteString 0 8, "\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000", rawBytesString o toByteList);

    assert("intToRawbyteString highest int", fn () => intToRawbyteString 0x7FFFFFFFFFFFFFFF 8, "\u007f\u00ff\u00ff\u00ff\u00ff\u00ff\u00ff\u00ff", rawBytesString o toByteList);

    assert("intToRawbyteString all digit values", fn () => intToRawbyteString 0x123456789ABCDEF0 8, "\u0012\u0034\u0056\u0078\u009A\u00BC\u00DE\u00F0", rawBytesString o toByteList);

    assert("convertRawBytes 0xFFFF", fn () => convertRawBytes "\u00FF\u00FF", 0xFFFF, Int.toString);

    assert("convertRawBytes highest int", fn () => convertRawBytes "\u007f\u00ff\u00ff\u00ff\u00ff\u00ff\u00ff\u00ff", 0x7FFFFFFFFFFFFFFF, Int.toString);

    assert("getLBits 8 left-most bits", fn () => getLBits 0x55 8, 0x55, Int.toString);

    assert("getLBits 7 left-most bits", fn () => getLBits 0x55 7, 0x2A, Int.toString);

    assert("getLBits 2 left-most bits", fn () => getLBits 0x55 2, 0x1, Int.toString);

    assert("getLBits 1 left-most bits", fn () => getLBits 0x55 1, 0x0, Int.toString);

    assert("getRBits 8 right-most bits", fn () => getRBits 0x55 8, 0x55, Int.toString);

    assert("getRBits 7 right-most bits", fn () => getRBits 0x55 7, 0x55, Int.toString);

    assert("getRBits 2 right-most bits", fn () => getRBits 0x55 2, 0x1, Int.toString);

    assert("getRBits 1 right-most bits", fn () => getRBits 0x55 1, 0x1, Int.toString);

    assert("setLBits 4 left-most bits", fn () => setLBits 0x2 4, 0x20, Int.toString);

    assert("setLBits 2 left-most bits", fn () => setLBits 0x3 2, 0xC0, Int.toString);

    printResult ()
)
