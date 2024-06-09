open Network 

fun intListToString l =
    let
        val strL = map (Int.toString) l
        val str = String.concatWith " " strL
    in
        str
    end

fun stringToIntList s =
    let
        val l = String.tokens (fn c => c = #" ") s
        
        fun stringToInt str =
            case Int.fromString str of
                SOME i => SOME i
              | NONE => NONE
        
        fun intList lst =
            case lst of
                [] => SOME []
              | x::xs =>
                    (case stringToInt x of
                        SOME i =>
                            (case intList xs of
                                SOME ys => SOME (i::ys)
                              | NONE => NONE)
                      | NONE => NONE)
    in
        intList l
    end


fun merge ([], l) = l
  | merge (l, []) = l 
  | merge ((h1::t1), (h2::t2)) = if h1 < h2 then h1 :: merge (t1, (h2::t2))
                                else h2 :: merge ((h1::t1), t2)

fun split l = 
    let fun split [] xs ys = (xs, ys)
          | split (x::[]) xs ys = (x::xs, ys) 
          | split (x::y::t) xs ys = split t (x::xs) (y::ys)
    in split l [] [] end

fun mergesort [] = []
  | mergesort [x] = [x] 
  | mergesort l = split l |> (fn (x, y) => (mergesort x, mergesort y)) |> merge

val _ = (
    bindUDP 8080 (
        fn data =>
            case data |> stringToIntList of
                SOME n => mergesort n |> intListToString
                | NONE => "Invalid input"
    );
    listen ()
)
