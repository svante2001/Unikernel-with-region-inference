open Lwt.Infix
(* based on ISC-licensed mirage-tcpip module *)

module Main
    (N : Mirage_net.S)
    (E : Ethernet.S)
    (I : Tcpip.Ip.S with type ipaddr = Ipaddr.V6.t)
    (A : Arp.S) =
struct
  let cs2b b =
    Cstruct.to_bytes b
    |> Bytes.fold_left
         (fun acc b -> acc ^ Printf.sprintf "%d " (Char.code b))
         ""

  let start n _ _ _ =
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
                    let eth_hdr : Ethernet.Packet.t =
                      {
                        source = N.mac n;
                        destination = ap.source_mac;
                        ethertype = `ARP;
                      }
                    in
                    let eth_pay b =
                      Arp_packet.encode_into sap b;
                      Arp_packet.size
                    in
                    let eth_fil frame =
                      match Ethernet.Packet.into_cstruct eth_hdr frame with
                      | Error msg ->
                          Logs.err (fun m ->
                              m
                                "error %s while marshalling ethernet header \
                                 into allocated buffer"
                                msg);
                          0
                      | Ok () ->
                          let len =
                            eth_pay
                              (Cstruct.shift frame
                                 Ethernet.Packet.sizeof_ethernet)
                          in
                          Ethernet.Packet.sizeof_ethernet + len
                    in
                    (* Lwt.return_unit *)
                    N.write n ~size:(N.mtu n) eth_fil >|= function
                    | Ok () -> Logs.info (fun f -> f "Success write!")
                    | Error _ -> Logs.info (fun f -> f "Error when writing"))
                | Error _ ->
                    Logs.info (fun f ->
                        f "Got an error while decoding arp_packet");
                    Lwt.return_unit)
            | `IPv4 ->
                Logs.info (fun f -> f "YES 4! %s" (Cstruct.to_string payload));
                Lwt.return_unit
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
