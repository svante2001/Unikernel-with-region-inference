fun fac n : IntInf.int = 
    if n <= 1 then 1
    else fac(n-1) * n

fun fib n : IntInf.int = 
    if n < 2 then n
    else fib(n - 1) + fib(n - 2)

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
