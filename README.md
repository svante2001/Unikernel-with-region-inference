# Unikernel-with-region-inference

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
`sudo tshark -i tap0`
