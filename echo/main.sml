open Network

val _ = (
    bindUDP 8080 (fn data => data);
    listen ()
)
