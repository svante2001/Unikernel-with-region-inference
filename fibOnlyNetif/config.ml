open Mirage

let main =
  foreign
    ~packages:
      [
        package ~min:"3.0.0" "ethernet";
        package ~min:"7.0.0" "tcpip";
        package ~min:"3.1.0" "arp";
      ]
    "Unikernel.Main"
    (network @-> ethernet @-> ipv6 @-> arpv4 @-> job)

let net = default_network
let ethif = etif net
let ipv6 = create_ipv6 net ethif
let arpv4 = arp ethif
let () = register "ping" [ main $ default_network $ ethif $ ipv6 $ arpv4 ]
