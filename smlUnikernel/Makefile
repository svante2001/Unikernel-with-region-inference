MLKIT_SOURCE_RUNTIME=~/mlkit/src/Runtime 

all:
	gcc -I $(MLKIT_SOURCE_RUNTIME) -o libtuntaplib.a -c netif-tuntaplib/netif-tuntaplib.c
	SML_LIB=/usr/local/lib/mlkit mlkit -no_gc -o main -libdirs "." -libs "m,c,dl,tuntaplib" main.mlb

clean:
	rm *.a 
	rm -rf */MLB MLB
	rm main