MLKIT_SOURCE_RUNTIME=~/mlkit/src/Runtime 

MINIOS_PATH=/home/axel/Projects/mini-os-HEAD-b6a5b4d

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

APP_OBJS=

setup:
	sudo modprobe tun
	sudo tunctl -u $$USER -t tap0
	sudo ifconfig tap0 10.0.0.1 up
	(cd UnixRuntimeMini; make)

tests/%test: FORCE
	(cd tests; SML_LIB=$(SL) mlkit --no_messages $(FLAGS) -no_gc -o $*test.exe $*test/$*test.mlb)
	./tests/$*test.exe

FORCE: ;

tests: unix tests/*test 

%-app: $(t)
	SML_LIB=$(SL) mlkit $(FLAGS) -no_gc -o $*.exe -libdirs "." -libs "m,c,dl,tuntaplib" $(shell pwd)/$*/main.mlb

unix:
	(cd UnixRuntimeMini; make)
	gcc -I $(SL) -o libtuntaplib.a -c Libs/netiflib/netif-tuntap.c

xen-runtime:
	(cd XenRuntimeMini; make)
	gcc -fno-builtin -Wall -Wredundant-decls -Wno-format -Wno-redundant-decls -Wformat -fno-stack-protector -fgnu89-inline -Wstrict-prototypes -Wnested-externs -Wpointer-arith -Winline -g -D__INSIDE_MINIOS__ -m64 -mno-red-zone -fno-reorder-blocks -fno-asynchronous-unwind-tables -DCONFIG_START_NETWORK -DCONFIG_SPARSE_BSS -DCONFIG_BLKFRONT -DCONFIG_NETFRONT -DCONFIG_FBFRONT -DCONFIG_KBDFRONT -DCONFIG_CONSFRONT -DCONFIG_XENBUS -DCONFIG_PARAVIRT -DCONFIG_LIBXS -D__XEN_INTERFACE_VERSION__=0x00030205 -isystem XenRuntimeMini/src/RuntimeMini -isystem XenRuntimeMini/include -isystem XenRuntimeMini/include/x86 -isystem XenRuntimeMini/include/x86/x86_64 -o libtuntaplib.a -c Libs/netiflib/netif-miniOS.c
	
# ar $(shell cat echo.exe | cut -d " " -f2-) $(shell cat echo.exe | cut -d " " -f1) libtuntaplib.a

$(OBJ_DIR)/$(TARGET)-kern.o: $(OBJS) arch_lib $(OBJ_DIR)/$(TARGET_ARCH_DIR)/minios-$(MINIOS_TARGET_ARCH).lds
	echo "hello"

clean:
	-(cd XenRuntimeMini; make clean)
	-(cd UnixRuntimeMini; make clean)
	-rm run
	-rm *.a 
	-rm -rf Libs/*lib/MLB MLB
	-rm -rf facfib/MLB
	-rm -rf echo/MLB
	-rm -rf monteCarlo/MLB
	-rm -rf sort/MLB
	-rm -r *.exe
	-rm -r tests/*.exe
