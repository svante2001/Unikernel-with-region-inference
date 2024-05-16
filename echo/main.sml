val _ = (
    (* bindUDP 8080 (fn data => (print "hello 2\n"; #"h") |> Char.toString); *)
    bindUDP 8080 (fn data => data);
    listen ()
)
