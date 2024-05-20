open Network

val digits = ref 10000.0

(* https://en.wikipedia.org/wiki/Lehmer_random_number_generator *)
fun lehmer s = 
    let
        val n = (s * 48271 mod 2147483647)
        val lg =  Math.log10 (Real.fromInt n)
        val ceiled = Real.ceil lg
        val pwr = Math.pow(10.0, Real.fromInt (ceiled))
    in
        digits := pwr;
        (Real.fromInt n) / !digits
    end

fun monteCarlo n =
    let
        fun loop 0 UC x y = UC
          | loop i UC x y =
                let
                    val new_x = lehmer (Real.floor (x * !digits))
                    val new_y = lehmer (Real.floor (y * !digits))
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
            in  print "monte carlo running\n";
                monteCarlo n |> Real.toString
            end
    );
    listen ()
)