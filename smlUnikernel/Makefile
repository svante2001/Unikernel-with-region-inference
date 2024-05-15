MLKIT_SOURCE_RUNTIME=/home/axel/mlkit/src/Runtime 

SL=$(shell pwd)/UnixRuntimeMini

ifndef t 
t=unix
endif

.PHONY: clean echo facfib

FLAGS=

ifeq ($(t), xen)
SL=$(shell pwd)/XenRuntimeMini
FLAGS=-objs -no_delete_target_files
endif

setup:
	sudo modprobe tun
	sudo tunctl -u $$USER -t tap0
	sudo ifconfig tap0 10.0.0.1 up
	(cd UnixRuntimeMini; make)

echo: $(t)
	SML_LIB=$(SL) mlkit $(FLAGS) -no_gc -o echo.exe -libdirs "." -libs "m,c,dl,tuntaplib" $(shell pwd)/echo/main.mlb

facfib: $(t)
	SML_LIB=$(SL) mlkit $(FLAGS) -no_gc -o facfib.exe -libdirs "." -libs "m,c,dl,tuntaplib" $(shell pwd)/facfib/main.mlb

unix:
	(cd UnixRuntimeMini; make)
	gcc -I $(MLKIT_SOURCE_RUNTIME) -o libtuntaplib.a -c Libs/netiflib/netif-tuntap.c

xen:
	(cd XenRuntimeMini; make)
	gcc -fno-builtin -Wall -Werror -Wredundant-decls -Wno-format -Wno-redundant-decls -Wformat -fno-stack-protector -fgnu89-inline -Wstrict-prototypes -Wnested-externs -Wpointer-arith -Winline -g -D__INSIDE_MINIOS__ -m64 -mno-red-zone -fno-reorder-blocks -fno-asynchronous-unwind-tables -DCONFIG_START_NETWORK -DCONFIG_SPARSE_BSS -DCONFIG_BLKFRONT -DCONFIG_NETFRONT -DCONFIG_FBFRONT -DCONFIG_KBDFRONT -DCONFIG_CONSFRONT -DCONFIG_XENBUS -DCONFIG_PARAVIRT -DCONFIG_LIBXS -D__XEN_INTERFACE_VERSION__=0x00030205 -isystem $(shell pwd)/XenRuntimeMini/src/RuntimeMini -isystem $(shell pwd)/XenRuntimeMini/include -isystem $(shell pwd)/XenRuntimeMini/include/x86 -isystem $(shell pwd)/XenRuntimeMini/include/x86/x86_64 -o libtuntaplib.a -c Libs/netiflib/netif-miniOS.c

clean:
	-(cd XenRuntimeMini; make clean)
	-(cd UnixRuntimeMini; make clean)
	-rm run
	-rm *.a 
	-rm -rf Libs/*lib/MLB MLB
	-rm -rf facfib/MLB
	-rm -rf echo/MLB
	-rm *.exe
