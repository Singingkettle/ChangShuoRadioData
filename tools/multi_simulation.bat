@echo off
setlocal enabledelayedexpansion

:: Parallel multi-worker CSRD data generation.
::
:: Every worker shares ONE session directory via CSRD_SESSION_ID, so a parallel
:: run fills a single data\<Dataset>\session_<ID>\ tree instead of scattering
:: scenarios across one session_* folder per worker. Launch and wait are handled
:: by PowerShell (reliable process IDs) rather than staggered starts + wmic.

set "SCRIPTDIR=%~dp0"
if not exist "%SCRIPTDIR%logs" mkdir "%SCRIPTDIR%logs"

:: Number of workers (must be a positive integer).
set /p numw="Enter number of workers: "
echo(!numw!| findstr /r "^[1-9][0-9]*$" >nul
if errorlevel 1 (
    echo Error: number of workers must be a positive integer.
    exit /b 1
)

:: One shared session id for every worker; exported so each MATLAB process
:: inherits it and writes into the same session directory.
for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "CSRD_SESSION_ID=%%t"
set "CSRD_DIR=%SCRIPTDIR%"
set "CSRD_NUMW=!numw!"
set "LOGFILE=%SCRIPTDIR%logs\simulation_!CSRD_SESSION_ID!.log"

echo Simulation started at %date% %time% ^| session !CSRD_SESSION_ID! ^| !numw! workers > "!LOGFILE!"
echo Launching !numw! workers into shared session !CSRD_SESSION_ID! ...

:: Launch all workers in parallel and wait for every one to exit. The MATLAB -r
:: string is built with single quotes only, so no inner double quotes fight the
:: batch command wrapper.
powershell -NoProfile -Command "$dir=$env:CSRD_DIR; $n=[int]$env:CSRD_NUMW; $procs=1..$n | ForEach-Object { Start-Process -FilePath 'matlab' -WorkingDirectory $dir -PassThru -ArgumentList @('-nodesktop','-nosplash','-r',('cd(''' + $dir + '''); clc; clear; close all; simulation(' + $_ + ', ' + $n + '); exit;')) }; Write-Host ('Launched workers: ' + ($procs.Id -join ', ')); $procs | Wait-Process; Write-Host 'All workers completed.'"

echo Simulation completed at %date% %time% >> "!LOGFILE!"
echo All workers completed. Session: !CSRD_SESSION_ID!. See "!LOGFILE!".
pause
