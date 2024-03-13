all:
	gcc -o libmylib.a -c fileDescriptor.c
	gcc -DPROFILING -o fileDescriptor-p.a -c fileDescriptor.c
	SML_LIB=/usr/local/lib/mlkit mlkit -no_gc -o FD_test -libdirs "." -libs "m,c,dl,mylib" mylib.mlb

clean:
	rm *.a 
	rm -rf MLB/
	rm FD_test