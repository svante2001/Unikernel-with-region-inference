#!/bin/bash

# Make setup and echo
make setup
make echo-app

# Run echo
nohup ./echo.exe 2>&1 &
echo $! > PID.txt

# Send pi.txt
sleep 1
cat tests/pi.txt | nc -u -nw1 10.0.0.2 8080 > tests/out.txt
sleep 1

# Close echo
kill $(cat PID.txt)

# Compare
if diff tests/pi.txt tests/out.txt > /dev/null; then
    echo "Files are the same."
else
    echo "Error: Files are different!"
    diff tests/pi.txt tests/out.txt
    exit 1
fi

# Clean
rm PID.txt
rm nohup.out
rm tests/out.txt