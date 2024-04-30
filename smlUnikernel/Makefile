MLKIT_SOURCE_RUNTIME=~/mlkit/src/Runtime 

.PHONY: clean echo facfib

setup:
	sudo modprobe tun
	sudo tunctl -u $$USER -t tap0
	sudo ifconfig tap0 10.0.0.1 up
	(cd RuntimeMini; make)

echo:
	gcc -I $(MLKIT_SOURCE_RUNTIME) -o libtuntaplib.a -c Libs/netif-tuntaplib/netif-tuntaplib.c
	SML_LIB=$(shell pwd)/RuntimeMini mlkit -no_gc -o echo.exe -libdirs "." -libs "m,c,dl,tuntaplib" echo/main.mlb

facfib:
	gcc -I $(MLKIT_SOURCE_RUNTIME) -o libtuntaplib.a -c Libs/netif-tuntaplib/netif-tuntaplib.c
	SML_LIB=$(shell pwd)/RuntimeMini mlkit -no_gc -o facfib.exe -libdirs "." -libs "m,c,dl,tuntaplib" facfib/main.mlb

clean:
	-(cd RuntimeMini; make clean)
	-rm run
	-rm *.a 
	-rm -rf Libs/*lib/MLB MLB
	-rm -rf facfib/MLB
	-rm -rf echo/MLB
	-rm *.exe
