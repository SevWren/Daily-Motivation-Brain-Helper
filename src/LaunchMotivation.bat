@echo off
REM ============================================================
REM  LaunchMotivation.bat -- Daily Motivation Brain Helper
REM  Launched by Windows Task Scheduler to show the popup.
REM  Config read from: %APPDATA%\DailyMotivationBrainHelper\
REM  Log written to:   %APPDATA%\DailyMotivationBrainHelper\launch_log.txt
REM ============================================================
setlocal enabledelayedexpansion

REM Resolve app install directory from this batch file's location
set APP_DIR=%~dp0
set APP_DIR=%APP_DIR:~0,-1%

REM App data directory (config lives here -- user never edits these)
set APP_DATA_DIR=%APPDATA%\DailyMotivationBrainHelper

set LAUNCH_LOG=%APP_DATA_DIR%\launch_log.txt
set PS_LOG=%APP_DATA_DIR%\launch_ps.log
set PS_SCRIPT=%APP_DIR%\DailyMotivation.ps1
REM GAP-001: use %SystemRoot%-relative path instead of hard-coded C:\Windows
set PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
if not exist "%PS_EXE%" (
    for /f "delims=" %%i in ('where powershell 2^>nul') do set PS_EXE=%%i
)
if not exist "%PS_EXE%" (
    echo [%date% %time%] ERROR: powershell.exe not found >> "%LAUNCH_LOG%"
    exit /b 1
)

REM Ensure app data dir exists
if not exist "%APP_DATA_DIR%" mkdir "%APP_DATA_DIR%"

REM Log launch
echo. >> "%LAUNCH_LOG%"
echo [%date% %time%] ====== LAUNCHER STARTED ====== >> "%LAUNCH_LOG%"
echo [%date% %time%] User=%USERNAME% >> "%LAUNCH_LOG%"
echo [%date% %time%] AppDir=%APP_DIR% >> "%LAUNCH_LOG%"
echo [%date% %time%] AppDataDir=%APP_DATA_DIR% >> "%LAUNCH_LOG%"

REM Verify popup script exists
if not exist "%PS_SCRIPT%" (
    echo [%date% %time%] ERROR: DailyMotivation.ps1 not found at %PS_SCRIPT% >> "%LAUNCH_LOG%"
    exit /b 1
)
echo [%date% %time%] Script found. Launching... >> "%LAUNCH_LOG%"

REM Launch PowerShell with all defensive flags
REM   -STA           : required for WPF (ERR-017)
REM   -NoProfile     : skip profile scripts (prevent profile crash)
REM   NOTE: -NonInteractive removed (BUG-005) -- it hides all unhandled error dialogs
REM   -WindowStyle Hidden: no console window
REM   -ExecutionPolicy Bypass: skip policy for this invocation only
"%PS_EXE%" -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%PS_SCRIPT%" >> "%PS_LOG%" 2>&1

set EXIT_CODE=!errorlevel!
echo [%date% %time%] PowerShell exited with code !EXIT_CODE! >> "%LAUNCH_LOG%"

endlocal
exit /b !EXIT_CODE!
