
MLKIT=SML_LIB=. mlkit -no_gc
LINKS=/home/axel/Projects/miniOS/mini-os/arch/x86/x86_64.o /home/axel/Projects/miniOS/mini-os/blkfront.o /home/axel/Projects/miniOS/mini-os/consfront.o /home/axel/Projects/miniOS/mini-os/console.o /home/axel/Projects/miniOS/mini-os/e820.o /home/axel/Projects/miniOS/mini-os/events.o /home/axel/Projects/miniOS/mini-os/fbfront.o /home/axel/Projects/miniOS/mini-os/gntmap.o /home/axel/Projects/miniOS/mini-os/gnttab.o /home/axel/Projects/miniOS/mini-os/hypervisor.o /home/axel/Projects/miniOS/mini-os/kernel.o /home/axel/Projects/miniOS/mini-os/lock.o /home/axel/Projects/miniOS/mini-os/mm.o /home/axel/Projects/miniOS/mini-os/netfront.o /home/axel/Projects/miniOS/mini-os/sched.o /home/axel/Projects/miniOS/mini-os/shutdown.o /home/axel/Projects/miniOS/mini-os/xenbus.o /home/axel/Projects/miniOS/mini-os/lib/ctype.o /home/axel/Projects/miniOS/mini-os/lib/math.o /home/axel/Projects/miniOS/mini-os/lib/printf.o /home/axel/Projects/miniOS/mini-os/lib/stack_chk_fail.o /home/axel/Projects/miniOS/mini-os/lib/string.o /home/axel/Projects/miniOS/mini-os/lib/sys.o /home/axel/Projects/miniOS/mini-os/lib/xmalloc.o /home/axel/Projects/miniOS/mini-os/lib/xs.o

.PHONY: all
all: lib/runtimeSystem.a basis

test.exe: lib/runtimeSystem.a
	$(MLKIT) -objs -no_delete_target_files -verbose -o $@ test.sml

test.o: lib/runtimeSystem.a
	$(MLKIT) -c test.mlb

lib/runtimeSystem.a:
	(cd src/RuntimeMini; make)

.PHONY: basis
basis: lib/runtimeSystem.a
	$(MLKIT) -c basis/basis.mlb

.PHONY: clean
clean:
	(cd src/RuntimeMini; make clean)
	(cd basis; -rm -rf MLB *~ run)
	-rm -rf MLB *~ lib/runtimeSystem.a run *.exe
