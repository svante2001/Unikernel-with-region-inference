open Lwt.Infix

let rec fib n map =
  if n < 3 then 1
  else if Hashtbl.mem map n then Hashtbl.find map n
  else
    let r = ((fib (n - 1) map) + (fib (n - 2) map)) in
    (
    Hashtbl.add map n r;
    r
    );
  
module Main (S : Tcpip.Stack.V4V6) = struct
  (* The number 10 is the initial size - can be any positive integer.. *)
  let fibs : (int, int) Hashtbl.t = Hashtbl.create 10
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
            Logs.info (fun f ->
                f "\nread: %d\nbytes:%s\nhash size:%d" (Cstruct.length b) (Cstruct.to_string b) (Hashtbl.length fibs));

            fibs |> fib (int_of_string (Cstruct.to_string b)) 
               |> Printf.sprintf "%d" 
               |> Cstruct.of_string 
               |> S.TCP.write flow >>= function

                  | _ -> S.TCP.close flow);
    S.listen s
end
