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
    listen ()
)
