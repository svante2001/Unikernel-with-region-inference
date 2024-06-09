
val mac = [123, 124, 125, 126, 127, 128] (* hard-coded *)

val ipAddress = [10, 0, 0, 2] (* also hard-coded *)

val mtu = 1500

val port = ref 8080

(* Extra data to simulate networking request*)
fun conEth et dstMac payload = 
    (Eth.encode (Eth.Header { 
        et = et,
        dstMac = dstMac,
        srcMac = mac
    }) payload)


fun conIpv4({identification, protocol, dest_addr, dstMac}) payload = 
    let val nfb = (mtu - 20) div 8
        fun sendFragments offset payload l = 
            if String.size payload + 20 <= mtu 
            then 
                ((conEth Eth.IPv4 dstMac (IPv4.encode (IPv4.Header {
                        version = 4,                
                        ihl = 5,                
                        dscp = 0,                  
                        ecn = 0,                    
                        total_length = 20 + (String.size payload),
                        identification = identification,
                        flags = 0,                                 
                        fragment_offset = offset,
                        time_to_live = 128,         
                        protocol = protocol,
                        header_checksum = 0,        
                        source_addr = ipAddress,
                        dest_addr = dest_addr 
                    }) payload)) :: l)
            else 
                sendFragments (offset + nfb) (String.extract (payload, nfb*8, NONE)) ((conEth Eth.IPv4 dstMac (IPv4.encode (IPv4.Header {
                    version = 4,              
                    ihl = 5,                   
                    dscp = 0,                  
                    ecn = 0,                   
                    total_length = 20 + (nfb * 8),
                    identification = identification,
                    flags = 1,                                   
                    fragment_offset = offset,
                    time_to_live = 128,         
                    protocol = protocol,
                    header_checksum = 0,        
                    source_addr = ipAddress,
                    dest_addr = dest_addr 
                }) (String.substring (payload, 0, nfb * 8)))) :: l)
    in  sendFragments 0 payload []
    end

fun conUDP payload =
    (UDP.encode (UDP.Header {length = 0, 
                            source_port = 9000, 
                            dest_port = !port, 
                            checksum = 0}) payload
    |> conIpv4 ({identification =  1234, 
                                    dstMac = mac, 
                                    protocol = IPv4.UDP, 
                                    dest_addr = ipAddress}))

val simPktArr = ref (Array.array (0, ""))

val len = ref 0

val curIdx = ref 0

val times = ref 0

fun addSimPkts [] = ()
  | addSimPkts (h::t) = (
    Array.update (!simPktArr, !curIdx, h); 
    curIdx := ((!curIdx) + 1) mod (!len); 
    addSimPkts t
)

fun constructSim l = (
    len := List.length l;
    simPktArr := Array.array (!len, "");
    addSimPkts l
)

fun receive () =
    let val el = Array.sub (!simPktArr, !curIdx)
    in curIdx := ((!curIdx) + 1) mod (!len); el 
    end

val profData = ref NONE

val runs = ref 1000

structure Network : NETWORK = struct

    val log = ref false

    fun logPrint str = if !log then print str else ()

    fun setProfData d = profData := SOME d

    fun setPort n = port := n

    fun setRuns n = runs := n

    fun generateProfData () = (
        let val data = 
            (case !profData of
            SOME d => d
            | NONE => (print "Missing profiling data!\n"; ""))
        in
            data 
            |> conUDP
            |> List.rev
            |> constructSim
        end
    )

    fun logOn () = log := true 

    fun logOff () = log := false

    datatype packetID = PktID of {
        ipaddr: int list,
        id: int,
        prot: IPv4.protocol
    }

    datatype fragment = Fragment of { data: string, offset: int} 

    fun pktIDCmp (PktID pktID1) (PktID pktID2) = 
        let fun ipCmp [] [] = true
            | ipCmp (hd1::tl1) (hd2::tl2) = if hd1 = hd2 then ipCmp tl1 tl2 else false
            | ipCmp _ _ = false
        in ipCmp (#ipaddr pktID1) (#ipaddr pktID2) andalso (#id pktID1) = (#id pktID2) andalso (#prot pktID1) = (#prot pktID2)
        end  

    val fragmentBuffer : (packetID * (fragment list ref)) list ref = ref []

    val assemblingList : (packetID * (char array)) list ref = ref []

    val listenOn = ref []

    fun bindUDP (port : int) (cbf : string -> string) = listenOn := (port, cbf) :: !listenOn 

    (* We assume that destination is the same. *)
    fun initPktID (IPv4.Header ipv4Hdr) = PktID {
        ipaddr = #source_addr ipv4Hdr, 
        id = #identification ipv4Hdr, 
        prot = #protocol ipv4Hdr
    }

    fun updatePacketArray pli arri arr payload = 
        if pli < String.size payload then 
            (Array.update (arr, arri, String.sub (payload, pli));
            updatePacketArray (pli+1) (arri+1) arr payload)
        else ()

    fun initAssembling (IPv4.Header ipv4Hdr) payload = 
        let val pktID = initPktID (IPv4.Header ipv4Hdr) 
            val arr = Array.array ((#fragment_offset ipv4Hdr) * 8 + String.size payload, #"\000")
        in
            (case findi (fn (pktID2, _) => pktIDCmp pktID pktID2) (!fragmentBuffer) of 
                SOME (i, (_, l)) => (
                    List.app (fn (Fragment f) => updatePacketArray 0 (if (#offset f) = 0 then 0 else (#offset f) * 8) arr (#data f)) (!l);
                    fragmentBuffer := List.drop (!fragmentBuffer, i))
            |   NONE => ());
            assemblingList := (pktID, arr) :: (!assemblingList)
        end

    fun addFragment (IPv4.Header ipv4Hdr) payload = 
        let val pktID = initPktID (IPv4.Header ipv4Hdr)
        in  case List.find (fn (pktID2, _) => pktIDCmp pktID pktID2) (!fragmentBuffer) of 
                SOME (_, l) => l := (Fragment {data = payload, offset = #fragment_offset ipv4Hdr}) :: (!l)
            |   NONE => (
                case List.find (fn (pktID2, _) => pktIDCmp pktID pktID2) (!assemblingList) of 
                    SOME (_, a) => updatePacketArray 0 (#fragment_offset ipv4Hdr) a payload
                |   NONE => fragmentBuffer := (pktID, ref [Fragment {data = payload, offset = #fragment_offset ipv4Hdr}]) :: (!fragmentBuffer)
            ) 
        end

    fun assemblePacket ipv4Hdr = 
        let val pktID = initPktID ipv4Hdr
        in  case findi (fn (pktID2, _) => pktIDCmp pktID pktID2) (!assemblingList) of 
                SOME (i, (_, a)) => (
                    assemblingList := List.drop (!assemblingList, i);
                    Array.foldr (op ::) [] a |> String.implode
                )
            |   NONE => raise Fail "Could not assemble packet."
        end

    fun ethSend et dstMac payload = 
        let val ethHeader = Eth.encode (Eth.Header { 
                    et = et,
                    dstMac = dstMac,
                    srcMac = mac
                }) payload
        in  print ""
            (* ethHeader *)
            (* |> print Side effect just so it is not optimized away *)
        end 

    (* Uses same identification as sender *)
    fun ipv4Send ({identification, protocol, dest_addr, dstMac}) payload = 
        let val nfb = (mtu - 20) div 8
            fun sendFragments offset payload = 
                if String.size payload + 20 <= mtu 
                then 
                    ethSend Eth.IPv4 dstMac (IPv4.encode (IPv4.Header {
                            version = 4,                (* This is only for version 4 (ipv4) *)
                            ihl = 5,                    (* Options are not allowed *)
                            dscp = 0,                   (* Service class is standard *)
                            ecn = 0,                    (* Not ECN capable *)
                            total_length = 20 + (String.size payload),
                            identification = identification,
                            flags = 0,                  (* No more fragments *)                  
                            fragment_offset = offset,
                            time_to_live = 128,         (* Hard-coded time_to_live *)
                            protocol = protocol,
                            header_checksum = 0,        (* Will be calculated in encode *)  
                            source_addr = ipAddress,
                            dest_addr = dest_addr 
                        }) payload)
                else 
                    (ethSend Eth.IPv4 dstMac (IPv4.encode (IPv4.Header {
                        version = 4,                (* This is only for version 4 (ipv4) *)
                        ihl = 5,                    (* Options are not allowed *)
                        dscp = 0,                   (* Service class is standard *)
                        ecn = 0,                    (* Not ECN capable *)
                        total_length = 20 + (nfb * 8),
                        identification = identification,
                        flags = 1,                  (* More fragments *)                  
                        fragment_offset = offset,
                        time_to_live = 128,         (* Hard-coded time_to_live *)
                        protocol = protocol,
                        header_checksum = 0,        (* Will be calculated in encode *)  
                        source_addr = ipAddress,
                        dest_addr = dest_addr 
                    }) (String.substring (payload, 0, nfb * 8)));
                    sendFragments (offset + nfb) (String.extract (payload, nfb*8, NONE)))
        in  sendFragments 0 payload
        end

    fun handleArp (Eth.Header ethHeader) ethFrame =
        let val arp = SOME (String.extract (ethFrame, 14, NONE) |> ARP.decode) handle _ => NONE
        in
            case arp of
                SOME (ARP.Header arpHeader) => 
                    (ARP.toString (ARP.Header arpHeader) |> logPrint;
                    ARP.encode (ARP.Header {
                        htype = 1, 
                        ptype = 0x0800,
                        hlen = 6,
                        plen = 4,
                        oper = ARP.Reply,
                        sha = mac, 
                        spa = ipAddress,
                        tha = (#sha arpHeader),
                        tpa = List.concat [(#spa arpHeader), [0, 0]]
                    }) 
                    |> ethSend Eth.ARP (#dstMac ethHeader))
            |   NONE => logPrint "Arp packet could not be decoded.\n"
        end

    fun handleUDP dstMac (IPv4.Header ipv4Header) payload =
        let 
            val (UDP.Header udpHeader, udpPayload) = payload |> UDP.decode
            val found = List.find (fn (port, cb) => (#dest_port udpHeader) = port) (!listenOn)
        in
            UDP.toString (UDP.Header udpHeader) |> logPrint;
            case found of 
            SOME (_, cb) => 
                let val payload = cb udpPayload 
                in  UDP.encode (UDP.Header {length = 0, 
                                            source_port = (#dest_port udpHeader), 
                                            dest_port = (#source_port udpHeader), 
                                            checksum = 0}) payload
                    |> ipv4Send ({identification = (#identification ipv4Header), 
                                                    dstMac = dstMac, 
                                                    protocol = IPv4.UDP, 
                                                    dest_addr = (#source_addr ipv4Header)})
                end
            | NONE =>  UDP.encode (UDP.Header {length = 8 + String.size payload, 
                                               source_port = (#dest_port udpHeader), 
                                               dest_port = (#source_port udpHeader), 
                                               checksum = 0}) 
                                               "Port is not mapped to a function."
                                               |> ipv4Send ({identification = (#identification ipv4Header), dstMac = dstMac, protocol = IPv4.UDP, dest_addr = #source_addr ipv4Header})
        end

    fun handleIPv4 (Eth.Header ethHeader) ethFrame = 
        let val (IPv4.Header ipv4Header, ipv4Pay) = String.extract (ethFrame, 14, NONE) |> IPv4.decode
            val payloadOpt = 
                if (#fragment_offset ipv4Header) = 0 andalso (#flags ipv4Header) = 2 
                then SOME ipv4Pay
                else (addFragment (IPv4.Header ipv4Header) ipv4Pay; (* Assumes packets arrive in order *)
                    if (#flags ipv4Header) = 0 
                    then ( 
                        initAssembling (IPv4.Header ipv4Header) ipv4Pay;
                        SOME (assemblePacket (IPv4.Header ipv4Header)))
                    else 
                        NONE)
        in
            IPv4.toString (IPv4.Header ipv4Header) |> logPrint;
            case payloadOpt of 
            SOME payload => (
                case (#protocol ipv4Header) of 
                  IPv4.UDP => handleUDP (#dstMac ethHeader) (IPv4.Header ipv4Header) payload
                | _ => logPrint "IPv4 Handler: Protocol is not supported.\n"
            )
            | NONE => ()
        end

    fun listen () = 
        if !times < !runs then (
            let 
            val rawTap = receive () 
            val ethFrame = String.extract (rawTap, 0, NONE)
            val (ethHeader, ethPayload) = ethFrame |> Eth.decode 
            val Eth.Header {et, dstMac, srcMac} = ethHeader
        in  
            "\n==== FROM: " ^ (rawBytesString srcMac) ^ " ====\n" |> logPrint;
            Eth.toString ethHeader |> logPrint;
            (case et of 
                  Eth.ARP => handleArp ethHeader ethFrame
                | Eth.IPv4 => handleIPv4 ethHeader ethFrame
                | _ => logPrint "\nlisten: Protocol not supported.\n"
            );
            "\n==== END: " ^ (rawBytesString srcMac) ^ " ====\n" |> logPrint;
            times := !times + 1;
            listen ()
        end) handle _ => (logPrint "Encountered an error in handling!\n"; listen ())
        else ()
end
