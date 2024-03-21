open Word;

(* Function to decode ARP packet *)
fun decodeARP packetData =
    let

        (* 1. substring af packetdata,
            2. convert to list of words, 
            3. brug fold på første word, shift til venstre 8 bits, læg den næste til, fortsæt hele listen igennem *)

        (* val bytes = (concat o map Int.toString o map Char.ord o explode) packetData *)


        val BL = List.map Char.ord (explode (Word.fromString packetData))

        (* orb is binary or from MLKIT *)
        val BL2 = List.foldl(fn (x, acc) => acc orb (x<<8)) 0 BL

        val etherType = Option.valOf(Word.fromString (String.substring (packetData, 14, 2)))

        val htype = Option.valOf(Word.fromString (String.substring (packetData, 0, 2)))
        val ptype = Option.valOf(Word.fromString (String.substring (packetData, 2, 4)))
        (* val hlen = Word.fromString (String.sub (packetData, 4))
        val plen = Word.fromString (String.sub (packetData, 5))
        val opcode = Word.fromString (String.sub (packetData, 6))
        val opcodeStr = if Word8.toInt opcode = 1 then "Request" else "Reply"
        val sha = String.substring (packetData, 8, 6)
        val spa = String.substring (packetData, 14, 4)
        val tha = if Word8.toInt opcode = 1 then "Unknown" else String.substring (packetData, 18, 6)
        val tpa = String.substring (packetData, 24, 4) *)
    in
        if etherType = Word.fromInt 0x0806 then 
            "--ARP Packet--\n" ^
            "HTYPE: " ^ Int.toString (Word.toInt htype) ^ "\n" ^
            "PTYPE: " ^ Int.toString (Word.toInt ptype) ^ "\n" 
            (*"HLEN: " ^ Int.toString (Word8.toInt hlen) ^ ", " ^
            "PLEN: " ^ Int.toString (Word8.toInt plen) ^ ", " ^
            "OPCODE: " ^ opcodeStr ^ ", " ^
            "SHA: " ^ sha ^ ", " ^
            "SPA: " ^ spa ^ ", " ^
            "THA: " ^ tha ^ ", " ^
            "TPA: " ^ tpa ^ "\n" *)
        else
            "Recieved a non-ARP package"
    end 

fun l () =
    let 
        val s = read_tap ()
    in
        print (decodeARP s);
        print "\n";
        (* (app print o map (fn x => (Int.toString x) ^ " ") o map Char.ord o explode) s; *)
        l ()
    end

val _ = (
    print ("Starting tap\n");
    l ()
)
