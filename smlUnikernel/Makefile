MLKIT_SOURCE_RUNTIME=~/mlkit/src/Runtime 

all:
	(cd RuntimeMini; make)
	gcc -I $(MLKIT_SOURCE_RUNTIME) -o libtuntaplib.a -c Libs/netif-tuntaplib/netif-tuntaplib.c
	SML_LIB=$(shell pwd)/RuntimeMini mlkit -no_gc -o main -libdirs "." -libs "m,c,dl,tuntaplib" main.mlb

setup:
	sudo modprobe tun
	sudo tunctl -u $$USER -t tap0
	sudo ifconfig tap0 10.0.0.1 up

clean:
	-(cd RuntimeMini; make clean)
	-rm run
	-rm *.a 
	-rm -rf Libs/*lib/MLB MLB
	-rm main
