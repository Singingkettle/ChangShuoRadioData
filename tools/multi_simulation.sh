#! /bin/bash

# Store the script's directory path
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create log directory if it doesn't exist
mkdir -p "$SCRIPTDIR/logs"

# Get number of workers from user input
read -p "Enter number of workers: " numw

# Log start time
echo "Simulation started at $(date)" > "$SCRIPTDIR/logs/simulation.log"

# Initialize arrays for PIDs and start times
declare -A pids
declare -A start_times

# Run all MATLAB processes simultaneously
for ((i=1; i<=$numw; i++))
do
    # Record start time for this worker
    start_times[$i]=$(date +%H:%M:%S)
    echo "Starting worker $i of $numw" >> "$SCRIPTDIR/logs/simulation.log"
    
    # Start MATLAB process and capture its PID
    {
        scriptname=$(printf 'simulation(%d, %d)' "$i" "$numw")
        echo "run script: $scriptname"
        matlab -nodesktop -nosplash -r "cd('$SCRIPTDIR'); clc; clear; close all; $scriptname; exit;"
    } &
    
    # Store the PID
    pids[$i]=$!
    echo "Launch A Matlab Worker with PID ${pids[$i]}"
    echo "Worker $i started with PID ${pids[$i]} at ${start_times[$i]}" >> "$SCRIPTDIR/logs/simulation.log"
done

wait

# Monitor all processes
while true; do
    running=0
    for ((i=1; i<=$numw; i++))
    do
        if kill -0 ${pids[$i]} 2>/dev/null; then
            running=1
        else
            # Process has ended, record completion time
            if [ ! -z "${pids[$i]}" ]; then
                end_time=$(date +%H:%M:%S)
                echo "Worker $i (PID: ${pids[$i]}) completed at $end_time" >> "$SCRIPTDIR/logs/simulation.log"
                echo "Duration for Worker $i:" >> "$SCRIPTDIR/logs/simulation.log"
                echo "  Start: ${start_times[$i]}" >> "$SCRIPTDIR/logs/simulation.log"
                echo "  End  : $end_time" >> "$SCRIPTDIR/logs/simulation.log"
                echo "Matlab Worker with PID ${pids[$i]} Completed"
                pids[$i]=""
            fi
        fi
    done
    
    if [ $running -eq 0 ]; then
        break
    fi
    
    sleep 10
done

# Log completion time
echo "Simulation completed at $(date)" >> "$SCRIPTDIR/logs/simulation.log"
echo "All workers completed. Check logs/simulation.log for details."
