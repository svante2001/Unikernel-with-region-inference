<!-- # Unikernel-with-region-inference

## MirageOS guides
[Installation](https://mirage.io/docs/install) <br />
[Hello MirageOS World](https://mirage.io/docs/hello-world) <br />

## Unikernel 
[Functors](https://dev.realworldocaml.org/functors.html) <br />
[First-class modules](https://dev.realworldocaml.org/first-class-modules.html) <br />
[Unikernels: Rise of the Virtual Library Operating System](https://queue.acm.org/detail.cfm?id=2566628) <br />

## Notes
`mirage configure -t unix` <br />
`echo -n hello tcp world | nc -nw1 127.0.0.1 8080` <br />

### Setting up tuntap
`sudo modprobe tun`
`sudo tunctl -u $USER -t tap0`
`sudo ifconfig tap0 10.0.0.1 up`

### Monitor network interface (tap0)
`sudo tshark -i tap0` -->

# Unikernel-with-region-inference
## SML unikernel
The SML unikernel can run on both UNIX and Xen (see below). The project includes four small examples of unikernels:
* Echo: a simple echo server that mirrors exactly what it receives
* Facfib: serves two ports with the factorial and fibonacci functions respectively
* MonteCarlo: estimates pi using the [sml-sobol library](https://github.com/diku-dk/sml-sobol) (run `smlpkg sync` before use). 
* Sort: sorts its given integers using mergesort

In order for the network to be initialized use: <br />
`$ make setup`

Once the unikernel is running one can send UDP packets to the unikernel via netcat: <br />
`$ echo -n “Hello, World!” | nc -u -nw1 127.0.0.2 8080`

### UNIX

### XEN