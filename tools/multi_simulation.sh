#!/bin/bash
#
# Parallel multi-worker CSRD data generation.
#
# Every worker shares ONE session directory via CSRD_SESSION_ID, so a parallel
# run fills a single data/<Dataset>/session_<ID>/ tree instead of scattering
# scenarios across one session_* folder per worker.

set -u

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
mkdir -p "$SCRIPTDIR/logs"

# Number of workers (must be a positive integer).
read -p "Enter number of workers: " numw
if ! [[ "$numw" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: number of workers must be a positive integer (got '$numw')." >&2
    exit 1
fi

# One shared session id for every worker; exported so each MATLAB process
# inherits it and writes into the same session directory.
export CSRD_SESSION_ID="$(date +%Y%m%d_%H%M%S)"
LOGFILE="$SCRIPTDIR/logs/simulation_${CSRD_SESSION_ID}.log"

echo "Simulation started at $(date) | session ${CSRD_SESSION_ID} | ${numw} workers" | tee "$LOGFILE"

# Launch all workers concurrently.
declare -A pids
for ((i=1; i<=numw; i++)); do
    matlab -nodesktop -nosplash -r "cd('$SCRIPTDIR'); clc; clear; close all; simulation($i, $numw); exit;" &
    pids[$i]=$!
    echo "Launched worker $i of $numw (PID ${pids[$i]})" | tee -a "$LOGFILE"
done

# Wait for each worker and log completion. `wait <pid>` blocks on that worker
# and reaps it, so there is no busy-poll and no defunct-process false "running".
rc=0
for ((i=1; i<=numw; i++)); do
    if wait "${pids[$i]}"; then
        echo "Worker $i (PID ${pids[$i]}) completed at $(date +%H:%M:%S)" | tee -a "$LOGFILE"
    else
        status=$?
        rc=1
        echo "Worker $i (PID ${pids[$i]}) FAILED (exit $status) at $(date +%H:%M:%S)" | tee -a "$LOGFILE"
    fi
done

echo "Simulation completed at $(date) | session ${CSRD_SESSION_ID}" | tee -a "$LOGFILE"
if [ "$rc" -ne 0 ]; then
    echo "One or more workers failed. See $LOGFILE." >&2
fi
exit $rc
