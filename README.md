# Unikernel-with-region-inference
Bachelor thesis in Computer Science at the University of Copenhagen.

## Thesis
Using region-based memory management with region inference is a feasible approach for developing unikernels that do not rely on dynamic garbage collectors, which may introduce interruptions and unnecessary memory traversals. Subsequently, the approach does not compromise memory safety or developer productivity and thus maintains the possibility of using higher-order programming languages for programming unikernels in a cloud computing setting.

## Simple example
Here is a small example of a Unikernel service. The port `8080` is bound to a callback function which
here is the identity function i.e. an echo service. It then listens for any incomming messages.
```ml
open Network

val _ = (
    bindUDP 8080 (fn data => data);
    listen ()
)
```
Logging can be turned on with the `logOn()` function and the service will print and log useful information
as seen below.
```sh
==== FROM: 74 212 82 133 150 162 ====

-- ETHERFRAME INFO --
Type: IPv4
Destination mac-address: [ 123 124 125 126 127 128 ]
Source mac-address: [ 74 212 82 133 150 162 ]

-- IPV4 INFO --
Version: 4
IHL: 5
DSCP: 0
ECN: 0
Total length: 34
Identification: 43066
Flags: 2
Fragment offset: 0
Time to live: 64
Protocol: UDP
Header checksum: 32398
SRC-ADDRESS: 10 0 0 1
DST-ADDRESS: 10 0 0 2

-- UDP INFO --
Source port: 50083
Destination port: 8080
UDP length: 14
Checksum: 30513

==== END: 74 212 82 133 150 162 ====
```

### Further examples
The project include four small examples (these run on both Unix and Xen - see below):
* Echo: a simple echo server that mirrors exactly what it receives
* Facfib: serves two ports with the factorial and fibonacci functions respectively
* MonteCarlo: estimates pi using the [sml-sobol library](https://github.com/diku-dk/sml-sobol) (run `smlpkg sync` before use).
* Sort: sorts its given integers using mergesort

## Sending data to the unikernel
Once the unikernel is running one can send UDP packets to the unikernel via netcat: <br />
```sh
$ echo -n “Hello, World!” | nc -u -nw1 127.0.0.2 8080
```

## Compilation and running a unikernel
In order for the network to be initialized run:
```sh
$ make setup
```

### UNIX
The `make` rule for compiling an application defaults to UNIX and is run with:
```sh
$ make <application name>-app
```
or specified with
```sh
$ make t=unix <application name>-app
```

Run the application as an executable:
```sh
$ ./<application name>.exe
```

### XEN
In order to compile an application to Xen the target must be specified:
```sh
$ make t=xen <application name>-app
```

## Creating your own application
To create an application create a new directory and include two files:
* `main.sml` which contains the code for the application
* `main.mlb` which is the ML basis file containing the applications dependencies

## Monitor network interface (tap0)
```sh
$ sudo tshark -i tap0
```