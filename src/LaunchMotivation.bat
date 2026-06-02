@echo off
REM ============================================================
REM  LaunchMotivation.bat  — Bulletproof Task Scheduler wrapper
REM  Place this file at: C:\login\daily_moti\LaunchMotivation.bat
REM  Register the scheduled task to run THIS file via cmd.exe,
REM  NOT powershell.exe directly.
REM ============================================================
setlocal enabledelayedexpansion

set SCRIPT_DIR=C:\login\daily_moti
set LAUNCH_LOG=%SCRIPT_DIR%\launch_log.txt
set PS_LOG=%SCRIPT_DIR%\ps_output.log

REM Original -   set PS_SCRIPT=%SCRIPT_DIR%\DailyMotivation.ps1
set PS_SCRIPT=%SCRIPT_DIR%\DailyMotivation.ps1



set PS_EXE=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe

REM --- Step 1: Prove the batch ran (pure echo, no PowerShell needed) ---
echo. >> "%LAUNCH_LOG%"
echo [%date% %time%] ====== BATCH LAUNCHER STARTED ====== >> "%LAUNCH_LOG%"
echo [%date% %time%] User=%USERNAME% >> "%LAUNCH_LOG%"
echo [%date% %time%] TEMP=%TEMP% >> "%LAUNCH_LOG%"

REM --- Step 2: Verify the script file exists ---
if not exist "%PS_SCRIPT%" (
    echo [%date% %time%] ERROR: Script not found at %PS_SCRIPT% >> "%LAUNCH_LOG%"
    exit /b 1
)
echo [%date% %time%] Script found OK. Launching PowerShell... >> "%LAUNCH_LOG%"

REM --- Step 3: Launch PowerShell with ALL defensive flags ---
REM   -NoProfile      : Skip profile scripts (profile crash = no log written at all)
REM   -NonInteractive : Suppress interactive prompts that hang in Task Scheduler
REM   -STA            : Required for WPF (single-threaded apartment)
REM   -WindowStyle Hidden : No console window visible
REM   -ExecutionPolicy Bypass : Skip execution policy checks
REM   stdout+stderr redirected to ps_output.log so errors are never lost
"%PS_EXE%" -NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%PS_SCRIPT%" >> "%PS_LOG%" 2>&1

REM --- Step 4: Log the exit code ---
set EXIT_CODE=!errorlevel!
echo [%date% %time%] PowerShell exited with code !EXIT_CODE! >> "%LAUNCH_LOG%"

endlocal
exit /b !EXIT_CODE!
