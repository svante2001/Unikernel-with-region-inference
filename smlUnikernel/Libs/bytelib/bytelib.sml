fun toByteList s = s |> explode |> map Char.ord 

fun rawBytesString (b: int list) = b |> foldl (fn (x, acc) => acc ^ " " ^ (Int.toString x)) ""

fun byteListToString b = (b |> map Char.chr |> implode)

fun intToRawbyteString i nb = 
    let fun h_intToRawbyteString i 1 acc = Char.chr i :: acc |> implode
          | h_intToRawbyteString i nb acc = 
            if nb <= 0 then ""
            else Char.chr (i mod 256) :: acc |> h_intToRawbyteString (i div 256) (nb-1)
    in 
        h_intToRawbyteString i nb []
    end

fun getLBits octet nb = octet div (2**(8-nb))

fun getRBits octet nb = octet mod (2**nb)

fun setLBits num nb = num * (2**(8-nb))

fun printCharsOfRawbytes s =
    s 
    |> map (fn x => (Char.chr x |> Char.toString) ^ " ") 
    |> app print

fun convertRawBytes s = 
    s
    |> toByteList 
    |> foldl (fn (c, acc) => acc*256+c) 0 

fun printRawBytes s =
    s
    |> toByteList
    |> map (fn x => (Int.toString x) ^ " ")
    |> app print 