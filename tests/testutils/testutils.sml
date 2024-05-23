val tests = ref 0
val successes = ref 0

val name = ref "TESTS"

fun printGreen str = "\u001b[32m" ^ str ^ "\u001b[0m" |> print

fun printRed str = "\u001b[31m" ^ str ^ "\u001b[0m" |> print

fun printYellow str = "\u001b[33m" ^ str ^ "\u001b[0m" |> print

fun printGrey str = "\u001b[30m" ^ str ^ "\u001b[0m" |> print

fun setTestSuiteName str = name := str

fun assert(name, f, expected, toString) =
    (tests := !tests + 1;
    name ^ " - " |> print;
    (if f() = expected 
     then (successes := !successes + 1; printGreen "Success!\n") 
     else (printRed "Failed: \n  "; "  Expected: " |> printYellow; (toString expected) |> printGrey; 
                                    "\n    Got:      " |> printYellow; (toString (f())) ^ 
                                    "\n" |> printGrey)) 
                                    handle _ => printRed "Error occurred in test\n")

fun printStart () = "\n-- Testsuite: " ^ (!name) ^ " --\n" |> print
fun printResult () = "\n" ^ (!successes |> Int.toString) ^ " out of " ^ (!tests |> Int.toString) ^ " tests passed\n" |> (if (!successes) = (!tests) then printGreen else (fn s => (printRed s; raise Fail "Test failed.")))
