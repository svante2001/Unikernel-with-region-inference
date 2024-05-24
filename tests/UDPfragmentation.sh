#!/bin/bash

# Make setup and echo
make setup
make echo-app

# Run echo
nohup ./echo.exe 2>&1 &
echo $! > PID.txt

# Send Hamlet.txt
cat tests/hamlet.txt | nc -u -nw1 10.0.0.2 8080 > tests/out.txt

# Close echo
kill $(cat PID.txt)

# Compare
if diff tests/hamlet.txt tests/out.txt > /dev/null; then
    echo "Files are the same."
else
    echo "Error: Files are different!"
    exit 1
fi

# Clean
rm PID.txt
rm nohup.out
rm tests/out.txt