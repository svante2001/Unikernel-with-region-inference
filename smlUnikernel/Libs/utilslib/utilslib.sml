infix 3 |> fun x |> f = f x

infix 8 ** fun x ** y = Math.pow (Real.fromInt x, Real.fromInt y) |> round 