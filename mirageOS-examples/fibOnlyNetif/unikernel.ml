open Lwt.Infix
(* based on ISC-licensed mirage-tcpip module *)

module Main
    (N : Mirage_net.S)
    (E : Ethernet.S)
    (I : Tcpip.Ip.S with type ipaddr = Ipaddr.V6.t)
    (A : Arp.S) 
    (Ipv4 : Tcpip.Ip.S ) =
struct
let cs2b b =
  Cstruct.to_bytes b
  |> Bytes.fold_left
        (fun acc b -> acc ^ Printf.sprintf "%d " (Char.code b))
        ""

let udp_fill pseudoheader up_pkt payload buf =
  let _ = Udp_packet.Marshal.into_cstruct ~pseudoheader ~payload up_pkt buf in
  Cstruct.blit payload 0 (Cstruct.shift buf Udp_wire.sizeof_udp) 0 (Cstruct.length payload)


let ip_fill ip_pkt payload_len pay_fill buf = 
  match Ipv4_packet.Marshal.into_cstruct ~payload_len ip_pkt buf with
  | Error _ -> (Logs.err (fun f -> f "Error while marshalling ippacket"); 0)
  | Ok () -> 
    pay_fill (Cstruct.shift buf Ipv4_wire.sizeof_ipv4);
    Ipv4_wire.sizeof_ipv4 + payload_len

let ethernet_fill eth_pkt pay_fill frame =
  match Ethernet.Packet.into_cstruct eth_pkt frame with
  | Error msg ->
      Logs.err (fun m ->
          m
            "error %s while marshalling ethernet header \
             into allocated buffer"
            msg);
      0
  | Ok () ->
      let len =
        pay_fill
          (Cstruct.shift frame
             Ethernet.Packet.sizeof_ethernet)
      in
      Logs.info (fun f -> f "Final frame: %s" (Cstruct.to_string frame));
      Ethernet.Packet.sizeof_ethernet + len

let rec fib n =
  if n < 3 then 1
  else (fib (n - 1)) + (fib (n - 2))

  let start n _ _ _ _ =
    N.listen n ~header_size:Ethernet.Packet.sizeof_ethernet (fun b ->
        let s = cs2b b in
        Logs.info (fun f -> f "%s" s);
        let ep = Ethernet.Packet.of_cstruct b in
        match ep with
        | Ok ({ destination; source; ethertype }, payload) -> (
            match ethertype with
            | `ARP -> (
                Logs.info (fun f ->
                    f "payload: %s, from: %s, to: %s" (cs2b payload)
                      (Macaddr.to_string source)
                      (Macaddr.to_string destination));
                match Arp_packet.decode payload with
                | Ok ap -> (
                    Logs.info (fun f ->
                        f "Succesfully decoded source mac: %s"
                          (Macaddr.to_string ap.source_mac));
                    Logs.info (fun f ->
                        f "Will now try to send own mac: %s"
                          (Macaddr.to_string (N.mac n)));
                    let sap : Arp_packet.t =
                      {
                        operation = Reply;
                        source_mac = N.mac n;
                        source_ip = ap.target_ip;
                        target_mac = source;
                        target_ip = ap.source_ip;
                      }
                    in
                    let eth_pkt : Ethernet.Packet.t =
                      {
                        source = N.mac n;
                        destination = ap.source_mac;
                        ethertype = `ARP;
                      }
                    in
                    let pay_fill b =
                      Arp_packet.encode_into sap b;
                      Arp_packet.size
                    in
                    (* Lwt.return_unit *)
                    N.write n ~size:(N.mtu n) (ethernet_fill eth_pkt pay_fill) >|= function
                    | Ok () -> Logs.info (fun f -> f "Success write!")
                    | Error _ -> Logs.info (fun f -> f "Error when writing"))
                | Error _ ->
                    Logs.info (fun f ->
                        f "Got an error while decoding arp_packet");
                    Lwt.return_unit)
            | `IPv4 ->
                Logs.info (fun f -> f "YES 4! %s" (Cstruct.to_string payload));
                (match Ipv4_packet.Unmarshal.of_cstruct payload with 
                | Ok(hd, payload) -> (
                  Logs.info (fun f -> f "proto: %d, payload: %s, ip: %s" hd.proto (cs2b payload) (Ipaddr.V4.to_string hd.src));
                  match Ipv4_packet.Unmarshal.int_to_protocol hd.proto with 
                  | Some(`ICMP) -> Logs.info (fun f -> f "ICMP!"); Lwt.return_unit
                  | Some(`TCP) -> Logs.info (fun f -> f "TCP!"); Lwt.return_unit
                  | Some(`UDP) -> (
                    match Udp_packet.Unmarshal.of_cstruct payload with
                    | Ok ({ src_port; dst_port }, payload) -> (
                      Logs.info (fun f -> f "Got message from port: %d to port: %d with payload: %s" src_port dst_port (Cstruct.to_string payload));
                      let u_hd : Udp_packet.t = {
                        src_port = dst_port;
                        dst_port = src_port
                      } in
                      let i_hd : Ipv4_packet.t = {
                        src = hd.dst;
                        dst = hd.src;
                        id = 0;
                        off = 0;
                        ttl = 256;
                        proto = 17;
                        options = Cstruct.create 0;
                      } in
                      let e_hd : Ethernet.Packet.t = {
                        source = N.mac n;
                        destination = source;
                        ethertype = `IPv4
                      } in 
                      let mes = Cstruct.of_string (Printf.sprintf "%d" ((fib (int_of_string(Cstruct.to_string payload))))) in
                      let ph =
                        Ipv4_packet.Marshal.pseudoheader ~src:(i_hd.src) ~dst:(i_hd.dst) ~proto:`UDP ((Cstruct.length mes) + Udp_wire.sizeof_udp)
                      in
                      let upay buf = udp_fill ph u_hd mes buf in 
                      let ipay buf = ip_fill i_hd ((Cstruct.length mes) + Udp_wire.sizeof_udp) upay buf in
                      N.write n ~size:(N.mtu n) (ethernet_fill e_hd ipay) >|= function
                      | Ok () -> Logs.info (fun f -> f "Success ip write!")
                      | Error _ -> Logs.info (fun f -> f "Error when ip writing"))
                    | Error s -> Logs.info (fun f -> f "Got error : %s" s); Lwt.return_unit 
                  )
                  | None -> Logs.info (fun f -> f "Uknown protocol"); Lwt.return_unit
                  )
                | Error _ -> Logs.info (fun f -> f "Error parsing Ipv4 packet"); Lwt.return_unit)
                
            | `IPv6 ->
                Logs.info (fun f -> f "YES 6! %s" (Cstruct.to_string payload));
                Lwt.return_unit)
        | Error _ ->
            Logs.info (fun f -> f "Got an error");
            Lwt.return_unit)
    (* N.write *)
    >|= function
    | Result.Ok () -> Logs.info (fun m -> m "done!")
    | Result.Error _ -> Logs.err (fun m -> m "ipv6 ping failed!")
end