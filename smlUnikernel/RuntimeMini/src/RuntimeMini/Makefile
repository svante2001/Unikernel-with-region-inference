# Makefile for the MLKit runtime system.

SYSNAME=$(shell uname -s)
CC=gcc
CFLAGS=-g -O2
INSTALL=/usr/bin/install -c
INSTALLDATA=${INSTALL} -m 644
INSTALLPROGRAM=${INSTALL}
ARGOBOTS_ROOT=

BINDIR=../../bin
LIBDIR=../../lib

OFILES=Runtime.o String.o Math.o Region.o Table.o CommandLine.o
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
	$(AR) $@ $(OFILES)
	$(INSTALLDATA)  $@ $(LIBDIR)

depend:
	mv Makefile Makefile.bak
	(sed -n -e '1,/^### DO NOT DELETE THIS LINE/p' Makefile.bak;	 \
         $(CC) -MM $(CFILES)) > Makefile
	rm Makefile.bak

clean:
	rm -f $(OFILES)
	rm -f core a.out *~ *.bak gen_syserror SysErrTable.h
	rm -f runtimeSystem.a

### DO NOT DELETE THIS LINE
Runtime.o: Runtime.c CommandLine.h Flags.h String.h Region.h Tagging.h \
 Runtime.h Math.h Exception.h Table.h
String.o: String.c String.h Flags.h Region.h Tagging.h List.h Exception.h
Math.o: Math.c Math.h Flags.h Tagging.h Region.h String.h Exception.h
Region.o: Region.c Flags.h Region.h Math.h Tagging.h String.h Runtime.h
Table.o: Table.c Table.h Region.h Flags.h Tagging.h
CommandLine.o: CommandLine.c CommandLine.h Flags.h String.h Region.h \
 Tagging.h List.h
