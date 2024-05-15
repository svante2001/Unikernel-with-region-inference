
MLKIT=SML_LIB=. mlkit -no_gc

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
	- (cd src/RuntimeMini; make clean)
	- (cd basis; -rm -rf MLB *~ run)
	- rm -rf MLB *~ lib/runtimeSystem.a run *.exe
