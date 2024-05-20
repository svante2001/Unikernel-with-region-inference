open Network

val facTbl = ref (Vector.fromList [])

fun fac n : IntInf.int = (
    if IntInf.fromInt (Vector.length (!facTbl)) >= n then Vector.sub (!facTbl, IntInf.toInt n-1)
    else 
        let val x = if n <= 1 then 1 else fac(n-1) * n in 
            facTbl := Vector.concat [!facTbl, (Vector.fromList [x])];
            x
        end
)

val fibTbl = ref (Vector.fromList [])

fun fib n : IntInf.int = (
    if IntInf.fromInt (Vector.length (!fibTbl)) > n then Vector.sub (!fibTbl, IntInf.toInt n)
    else 
        let val x = if n < 2 then n else (fib(n-2) + fib(n-1)) in 
            fibTbl := Vector.concat [!fibTbl, (Vector.fromList [x])];
            x
        end
)

fun fastFib n : IntInf.int =
    if n < 0 then raise Fail "Negative arguments not implemented"
    else #1 (fastFibH n)

and fastFibH 0 : IntInf.int * IntInf.int = (IntInf.fromInt 0, IntInf.fromInt 1)
  | fastFibH n : IntInf.int * IntInf.int =
    let
        val (a, b) = fastFibH (n div 2)
        val c = a * (b * 2 - a)
        val d = a * a + b * b
    in
        if n mod 2 = 0 then (c, d)
        else (d, c + d)
    end

val _ = (
    bindUDP 8080 (
        fn data => 
            let val n = data |> IntInf.fromString |> valOf
            in  fac n |> IntInf.toString
            end
    );
    bindUDP 8081 (
        fn data => 
            let val n = data |> IntInf.fromString |> valOf
            in  fib n |> IntInf.toString
            end
    );
    bindUDP 8082 (
        fn data =>
            let val n = data |> Int.fromString |> valOf
            in fastFib n |> IntInf.toString
            end
    );

    listen ()
)
