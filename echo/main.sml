open Network

val _ = (
    logOn ();
    bindUDP 8080 (fn data => data);
    listen ()
)
