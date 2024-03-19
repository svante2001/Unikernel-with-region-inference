(* val _ = print (read_fd "test.txt") *) 
(* val _ = print (Int.toString(write_fd ("test2.txt", "I just wrote this!"))) *)

fun l () =
    let val s = read_tap () 
    in 
        (app print o map (fn x => (Int.toString x) ^ " ") o map Char.ord o explode) s;
        print "\n";
        l ()
    end

val _ = (
    print ("Starting tap\n");
    (* open_tap (); 
    print ("opened tap\n"); *)
    l ()
)