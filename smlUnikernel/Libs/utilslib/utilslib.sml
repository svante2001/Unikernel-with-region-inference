infix 3 |> fun x |> f = f x

infix 8 ** fun x ** y = Math.pow (Real.fromInt x, Real.fromInt y) |> round 

fun findi f l =
    let fun findi_ [] _ = NONE
          | findi_ (h::t) i = if f h then SOME (i, h) else findi_ t (i+1)
    in  findi_ l 0
    end 