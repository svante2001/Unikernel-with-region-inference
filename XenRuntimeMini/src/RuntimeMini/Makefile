# Makefile for the MLKit runtime system.

SYSNAME=$(shell uname -s)
CC=gcc -fno-builtin -Wall -Wredundant-decls -Wno-format -Wno-redundant-decls -Wformat -fno-stack-protector -fgnu89-inline -Wstrict-prototypes -Wnested-externs -Wpointer-arith -Winline -g -D__INSIDE_MINIOS__ -m64 -mno-red-zone -fno-reorder-blocks -fno-asynchronous-unwind-tables -DCONFIG_START_NETWORK -DCONFIG_SPARSE_BSS -DCONFIG_BLKFRONT -DCONFIG_NETFRONT -DCONFIG_FBFRONT -DCONFIG_KBDFRONT -DCONFIG_CONSFRONT -DCONFIG_XENBUS -DCONFIG_PARAVIRT -DCONFIG_LIBXS -D__XEN_INTERFACE_VERSION__=0x00030205 -isystem $(shell pwd)/../../include -D__MINIOS__  -isystem $(shell pwd)/../../include/x86 -isystem $(shell pwd)/../../include/x86/x86_64 -isystem $(shell pwd)/include
CFLAGS=-g -O2 -fno-builtin -Wall -Wredundant-decls -Wno-format -Wno-redundant-decls -Wformat -fno-stack-protector -fgnu89-inline -Wstrict-prototypes -Wnested-externs -Wpointer-arith -Winline -g -D__INSIDE_MINIOS__ -m64 -mno-red-zone -fno-reorder-blocks -fno-asynchronous-unwind-tables
INSTALL=/usr/bin/install -c
INSTALLDATA=${INSTALL} -m 644
INSTALLPROGRAM=${INSTALL}
ARGOBOTS_ROOT=

BINDIR=../../bin
LIBDIR=../../lib

OFILES=Runtime.o String.o Math.o Region.o Table.o
CFILES = $(OFILES:%.o=%.c)

OPT:=-Wall -std=gnu99 -fPIC
OPT:=$(OPT) $(CFLAGS)

AR=ar rc

.PHONY: depend clean runtime all

all: runtimeSystem.a
	cp -a $< ../../lib/

%.o: %.c Makefile
#	$(CC) -c $(OPT) -DDEBUG -o $*.o $<
	$(CC) -c $(OPT) -o $*.o $<

runtimeSystem.a: $(OFILES) Makefile
	$(AR) $@ $(OFILES) libm.a
	$(INSTALLDATA)  $@ $(LIBDIR)

depend:
	mv Makefile Makefile.bak
	(sed -n -e '1,/^### DO NOT DELETE THIS LINE/p' Makefile.bak;	 \
         $(CC) -MM $(CFILES)) > Makefile
	rm Makefile.bak

clean:
	- rm -f $(OFILES)
	- rm -f core a.out *~ *.bak gen_syserror SysErrTable.h
	- rm -f runtimeSystem.a

### DO NOT DELETE THIS LINE
Runtime.o: Runtime.c Flags.h String.h Region.h Tagging.h \
 Runtime.h Math.h Exception.h Table.h
String.o: String.c String.h Flags.h Region.h Tagging.h List.h Exception.h
Math.o: Math.c Math.h Flags.h Tagging.h Region.h String.h Exception.h
Region.o: Region.c Flags.h Region.h Math.h Tagging.h String.h Runtime.h
Table.o: Table.c Table.h Region.h Flags.h Tagging.h
