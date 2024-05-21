val tests = ref 0
val successes = ref 0

val name = ref "TESTS"

fun printGreen str = "\u001b[32m" ^ str ^ "\u001b[0m" |> print

fun printRed str = "\u001b[31m" ^ str ^ "\u001b[0m" |> print

fun printGrey str = "\u001b[30m" ^ str ^ "\u001b[0m" |> print

fun setTestSuiteName str = name := str

fun assert(name, f, expected, toString) =
    (tests := !tests + 1;
    name ^ " - " |> print;
    (if f() = expected 
     then (successes := !successes + 1; printGreen "Success!\n") 
     else (printRed "Failed: \n  "; "  Expected: " ^ (toString expected) ^ 
                                    "\n    Got:      " ^ (toString (f())) ^ 
                                    "\n" |> printGrey)) 
                                    handle _ => printRed "Error occurred in test\n")

fun printStart () = "\n-- Testsuite: " ^ (!name) ^ " --\n" |> print

(* val () = assert("integer equality1", (fn () => 6 div 0), 1, Int.toString)
val () = assert("equality2", (fn () => 1), 1, Int.toString)

val () = (if {hello = 1, t = 2} = {hello = 1, t = 2} then print "Hello" else print "Nope") *)

fun printResult () = "\n" ^ (!successes |> Int.toString) ^ " out of " ^ (!tests |> Int.toString) ^ " tests passed\n" |> (if (!successes) = (!tests) then printGreen else printRed)
