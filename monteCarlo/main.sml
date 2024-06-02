open Network

structure Sobol = Sobol(val D = 2
                        structure SobolDir = SobolDir50)

fun monteCarlo n =
    let
        fun loop 0 UC = UC
          | loop i UC =
                let
                    val v = Sobol.independent i
                    val x = Sobol.frac(Array.sub(v,0))
                    val y = Sobol.frac(Array.sub(v,1))
                    val new_UC = if (x * x + y * y <= 1.0) then UC + 1 else UC
                in
                    loop (i - 1) new_UC
                end
        val UC = loop n 0
    in
        4.0 * (Real.fromInt UC) / (Real.fromInt n)
    end

val _ = (
    bindUDP 8080 (
        fn data =>
            case Int.fromString data of
                SOME n => monteCarlo n |> Real.toString
                | NONE => "Invalid input"
    );


    listen ()
)