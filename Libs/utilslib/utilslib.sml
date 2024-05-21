(* structure Utils : UTILSLIB = 
      struct  *)
infix 3 |> fun x |> f = f x

infix 8 ** fun x ** y = Math.pow (Real.fromInt x, Real.fromInt y) |> round 

fun findi f l =
      let fun findi_ [] _ = NONE
            | findi_ (h::t) i = if f h then SOME (i, h) else findi_ t (i+1)
      in  findi_ l 0
      end

fun toByteList s = s |> explode |> map Char.ord 

fun rawBytesString (b: int list) = b |> foldl (fn (x, acc) => if acc = "" then (Int.toString x) else acc ^ " " ^ (Int.toString x)) ""

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

fun convertRawBytes s : int = 
    s
    |> toByteList 
    |> foldl (fn (c, acc) => acc*256+c) 0 

fun printRawBytes s =
    s
    |> toByteList
    |> map (fn x => (Int.toString x) ^ " ")
    |> app print 
      (* end  *)
