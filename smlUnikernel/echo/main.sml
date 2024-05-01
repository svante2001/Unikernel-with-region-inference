val _ = (
    bindUDP 8080 (fn data => (print "hello 2\n"; String.sub (data, ((String.size data) - 1)) |> Char.toString));
    listen ()
)
