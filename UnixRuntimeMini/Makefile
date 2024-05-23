
MLKIT=SML_LIB=. mlkit -no_gc

.PHONY: all
all: lib/runtimeSystem.a basis

lib/runtimeSystem.a:
	(cd src/RuntimeMini; make)

.PHONY: basis
basis: lib/runtimeSystem.a
	- mkdir lib
	$(MLKIT) -c basis/basis.mlb

.PHONY: clean
clean:
	(cd src/RuntimeMini; make clean)
	(cd basis; rm -rf MLB *~ run)
	rm -rf MLB *~ lib/runtimeSystem.a run *.exe
