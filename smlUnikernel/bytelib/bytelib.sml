fun toByteList s = s |> explode |> map Char.ord 

fun rawBytesString (b: int list) = b |> foldl (fn (x, acc) => acc ^ " " ^ (Int.toString x)) ""

fun convertRawBytes s = 
    s
    |> toByteList 
    |> foldl (fn (c, acc) => acc*256+c) 0 

fun printRawBytes s =
    s
    |> toByteList
    |> map (fn x => (Int.toString x) ^ " ")
    |> app print 