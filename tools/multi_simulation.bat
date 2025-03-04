@echo off
setlocal enabledelayedexpansion

:: Store the script's directory path
set "SCRIPTDIR=%~dp0"

:: Create log directory if it doesn't exist
if not exist "%SCRIPTDIR%logs" mkdir "%SCRIPTDIR%logs"

:: Get number of workers from user input
set /p numw="Enter number of workers: "

:: Log start time
echo Simulation started at %date% %time% > "%SCRIPTDIR%logs\simulation.log"

:: Initialize arrays for PIDs and start times
for /l %%i in (1,1,%numw%) do (
    set "pid_%%i="
    set "start_time_%%i=%time%"
)

:: Run all MATLAB processes simultaneously
for /l %%i in (1,1,%numw%) do (
    :: Start MATLAB process for this worker
    echo Starting worker %%i of %numw% >> "%SCRIPTDIR%logs\simulation.log"
    
    :: Start MATLAB and get its PID
    start "Worker %%i" /D "%SCRIPTDIR%" matlab -nodesktop -nosplash -r "cd('%SCRIPTDIR%'); clc; clear; close all; simulation(%%i,%numw%);exit;"
    
    :: Wait briefly for the process to start
    timeout /t 10 /nobreak > nul
    
    :: Get the PID of the newly started MATLAB process
    for /f "skip=1 delims=" %%p in ('wmic process where "name='matlab.exe'" get ProcessId^,CommandLine') do (
        echo %%p | findstr /i "simulation(%%i,%numw%)" >nul
        if not errorlevel 1 (
            for %%m in (%%p) do set "last=%%m"
            set "pid_%%i=!last!"    
            echo Launch A Matlab Worker with PID !pid_%%i!
        )
    )
)

:: Monitor MATLAB processes
:wait
timeout /t 1 /nobreak > nul
set "running=0"

:: Check each worker's process
for /l %%k   in (1,1,%numw%) do (
    if defined pid_%%k (
        :: Check if process still exists
        wmic process where ProcessId^=!pid_%%k! get ProcessId 2>nul | find "!pid_%%k!" >nul

        if not errorlevel 1 (
            set "running=1"
        ) else (
            :: Process has ended, record completion time
            if defined pid_%%k (
                set "end_time=%time%"
                echo Worker %%k ^(PID: !pid_%%k!^) completed at !end_time! >> "%SCRIPTDIR%logs\simulation.log"
                echo Duration for Worker %%k: >> "%SCRIPTDIR%logs\simulation.log"
                echo   Start: !start_time_%%k! >> "%SCRIPTDIR%logs\simulation.log"
                echo   End  : !end_time! >> "%SCRIPTDIR%logs\simulation.log"
                echo Matlab Worker with PID !pid_%%k! Completed
                set "pid_%%k="
            )
        )
    )
)
if !running!==1 goto wait

:: Log completion time
echo Simulation completed at %date% %time% >> "%SCRIPTDIR%logs\simulation.log"
echo All workers completed. Check logs\simulation.log for details.
pause