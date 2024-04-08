infix 3 |> fun x |> f = f x 

datatype ethType = ARP | IPv4 | IPv6 

fun toByteList s = s |> explode |> map Char.ord 

fun ethTypeToString ethType =
    case ethType of
      ARP => "ARP"
    | IPv4 => "IPv4"
    | IPv6 => "IPv6"

fun rawBytesString (b: int list) = b |> foldl (fn (x, acc) => acc ^ " " ^ (Int.toString x)) ""

fun printEtherFrame({prot : ethType, dstMac : int list, srcMac : int list, payload : string}) = (
    print "ETHERFRAME:\n";
    "Type: " ^ (ethTypeToString prot) ^ "\n" |> print;
    "Source mac-addreess: [" ^ (rawBytesString srcMac) ^ " ]\n" |> print;
    "Destination mac-address: [" ^ (rawBytesString dstMac) ^ " ]\n" |> print;
    "Length of payload: " ^ (String.size payload |> Int.toString) ^ "\n" |> print; 
    print "\n"
)

fun convertRawBytes s = 
    s
    |> toByteList 
    |> foldl (fn (c, acc) => acc*256+c) 0 

fun printRawBytes s =
    s
    |> toByteList
    |> map (fn x => (Int.toString x) ^ " ")
    |> app print 

(* fun getMac (s) = *)
fun convertToEthType s =
    case convertRawBytes s of
      0x0806 => SOME ARP
    | 0x0800 => SOME IPv4
    | 0x86dd => SOME IPv6
    | _ => NONE

fun decodeEthFrame s = 
    let 
        val prot = String.substring (s, 12, 2) |> convertToEthType
        val dstMac = String.substring (s, 0, 6) |> toByteList
        val srcMac = String.substring (s, 6, 6) |> toByteList 
        val payload = String.extract (s, 14, NONE)
    in
        case prot of 
          SOME p => {prot = p, dstMac = dstMac, srcMac = srcMac, payload = payload}
        | NONE => raise Fail "Protocol not found."
    end

fun l () =
    let 
        val s = read_tap ()
    in
        printEtherFrame (String.extract (s, 4, NONE) |> decodeEthFrame);
        l ()
    end

val _ = (
    print ("Starting tap\n");
    l ()
)
