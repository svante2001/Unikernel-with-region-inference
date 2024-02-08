(* An http server which serves the contents of a given file a single time and then terminates *)

module Args = struct
  type t =
    { content_file : string
    ; port_file : string
    ; simulate_not_found : bool
    }

  let parse () =
    let content_file = ref "" in
    let port_file = ref "" in
    let simulate_not_found = ref false in
    let specs =
      [ "--content-file", Arg.Set_string content_file, "File to serve"
      ; ( "--port-file"
        , Arg.Set_string port_file
        , "The server will write its port number to this file" )
      ; "--simulate-not-found", Arg.Set simulate_not_found, "Return a 404 page"
      ]
    in
    Arg.parse
      specs
      (fun _anon_arg -> failwith "unexpected anonymous argument")
      "Run a webserver on a random port which serves the contents of a  single file a \
       single time, then terminates.";
    { content_file = !content_file
    ; port_file = !port_file
    ; simulate_not_found = !simulate_not_found
    }
  ;;
end

let main content_file port_file ~simulate_not_found =
  let host = Unix.inet_addr_loopback in
  let addr = Unix.ADDR_INET (host, 0) in
  let sock = Unix.socket ~cloexec:true Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.setsockopt sock Unix.SO_REUSEADDR true;
  Unix.bind sock addr;
  Unix.listen sock 1;
  let port =
    match Unix.getsockname sock with
    | Unix.ADDR_INET (_, port) -> port
    | ADDR_UNIX _ -> failwith "unreachable"
  in
  (* Create the port file immediately before starting the server. This way
     clients can use the existance of the port file to know roughly when the
     server is ready to accept connections. Note that there is technically a
     small delay between creating the port file and the server being ready
     which we can remove if it ends up causing us problems. *)
  Out_channel.with_open_text port_file (fun out_channel ->
    Out_channel.output_string out_channel (Printf.sprintf "%d\n" port));
  let descr, _sockaddr = Unix.accept sock in
  let content = In_channel.with_open_bin content_file In_channel.input_all in
  let content_length = String.length content in
  let out_channel = Unix.out_channel_of_descr descr in
  let status = if simulate_not_found then "404 Not Found" else "200 Ok" in
  Printf.fprintf out_channel "HTTP/1.1 %s\nContent-Length: %d\n\n" status content_length;
  Out_channel.output_string out_channel content;
  close_out out_channel
;;

let () =
  let { Args.content_file; port_file; simulate_not_found } = Args.parse () in
  main content_file port_file ~simulate_not_found
;;
