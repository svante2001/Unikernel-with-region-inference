(*
    The Utils structure provides useful infix extenstions to SML as well as 
    useful helper functions. 
*)

signature UTILSLIB = 
    sig
        (* val |> : 'a -> ('a -> 'b) -> 'b *)
        (* val ** : int -> int -> int *)
        val findi  : ('a -> bool) -> 'a list -> (int * 'a) option
    end

(*
[infix |>] is a pipe operator.

[infix **] is a power operator.

[findi] finds the the element that matches the predicate function.
*)