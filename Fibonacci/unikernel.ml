open Lwt.Infix

let fibs : (int, int) Hashtbl.t = Hashtbl.create 10

let rec fib n =
  if n < 3 then 1
  else fib (n - 1) + fib (n - 2)

module Main (S : Tcpip.Stack.V4V6) = struct
  let r = ref 0
  let start s =
    let port = Key_gen.port () in
    S.TCP.listen (S.tcp s) ~port (fun flow ->
        let dst, dst_port = S.TCP.dst flow in
        Logs.info (fun f ->
            f "new tcp connection from IP %s on port %d" (Ipaddr.to_string dst)
              dst_port);
        S.TCP.read flow >>= function
        | Ok `Eof ->
            Logs.info (fun f -> f "Closing connection!");
            Lwt.return_unit
        | Error e ->
            Logs.warn (fun f ->
                f "Error reading data from established connection: %a"
                  S.TCP.pp_error e);
            Lwt.return_unit
        | Ok (`Data b) ->
            Logs.debug (fun f ->
                f "read: %d bytes:\n%s" (Cstruct.length b) (Cstruct.to_string b));

            (
              if Hashtbl.mem fibs (int_of_string (Cstruct.to_string b))
              then r := Hashtbl.find fibs (int_of_string (Cstruct.to_string b))
              else 
                r := (fib (int_of_string (Cstruct.to_string b)));
                Hashtbl.add fibs (int_of_string (Cstruct.to_string b)) !r
            );

            S.TCP.write flow (Cstruct.of_string (Printf.sprintf "%d" !r)) >>= function

            | _ -> S.TCP.close flow); 
    S.listen s
end
