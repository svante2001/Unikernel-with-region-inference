#!/bin/bash
PID=$(pgrep facfib.exe)
rm stats.txt

for arg; do
    IFS=' ' read -r -a nums <<< "$arg"
    
    for num in "${nums[@]}"; do
        echo -n $num | nc -u -nw1 10.0.0.2 8081
        pidstat -r -p $PID | awk -v num="$num" 'NR==4 {print num " " $8}' >> stats.txt
    done
done

gnuplot -p graph.gp