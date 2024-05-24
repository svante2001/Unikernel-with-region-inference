# Unikernel-with-region-inference
## SML unikernel
The SML unikernel can run on both UNIX and Xen (see below). The project includes four small examples of unikernels:
* Echo: a simple echo server that mirrors exactly what it receives
* Facfib: serves two ports with the factorial and fibonacci functions respectively
* MonteCarlo: estimates pi using the [sml-sobol library](https://github.com/diku-dk/sml-sobol) (run `smlpkg sync` before use). 
* Sort: sorts its given integers using mergesort

### Compilation and running a unikernel
In order for the network to be initialized run: <br />
`$ make setup`

#### UNIX
The `make` rule for compiling an application defaults to UNIX and is used with: <br />
`$ make <application name>-app` <br />

Run the application as an executable: <br />
`$ ./<application name>.exe`

#### XEN
In order to compile an application to Xen the target must be specified: <br />
`$ make t=xen <application name>-app` <br />

### Sending data to the unikernel
Once the unikernel is running one can send UDP packets to the unikernel via netcat: <br />
`$ echo -n “Hello, World!” | nc -u -nw1 127.0.0.2 8080`

### Creating your own application
To create an application make a new directory and include two files:
* `main.sml` which contains the code for the application 
* `main.mlb` which is the ML basis file containing the applications dependencies

### Monitor network interface (tap0)
`$ sudo tshark -i tap0` 