open Network

structure Sobol = Sobol(val D = 2
                        structure SobolDir = SobolDir50)

fun monteCarlo n =
    let
        fun loop 0 UC x y = UC
          | loop i UC x y =
                let
                    val v = Sobol.independent i

                    val new_x = Sobol.frac(Array.sub(v,0))
                    val new_y = Sobol.frac(Array.sub(v,1))

                    val new_UC = if (new_x * new_x + new_y * new_y <= 1.0) then UC + 1 else UC
                in
                    loop (i - 1) new_UC new_x new_y
                end
        val UC = loop n 0 0.5 0.5
    in
        4.0 * (Real.fromInt UC) / (Real.fromInt n)
    end

val _ = (
    bindUDP 8080 (
        fn data => 
            let val n = data |> Int.fromString |> valOf
            in monteCarlo n |> Real.toString
            end
    );
    listen ()
)