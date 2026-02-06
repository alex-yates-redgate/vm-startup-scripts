@echo off
title VM Startup Scripts
color 0a

echo.
echo ===============================
echo SCRIPT STARTED
echo ===============================
echo.

set SCRIPT_DIR=%~dp0logon-scripts
set LOG_FILE=C:\Git\Admin\Logs\Logon_Scripts\logon_script.log

echo Script dir: %SCRIPT_DIR%
echo Log file : %LOG_FILE%
echo.

if not exist "%SCRIPT_DIR%" (
    echo ERROR: Script directory not found!
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

for %%F in ("%SCRIPT_DIR%\*.ps1") do (
    echo.
    echo ---------------------------------
    echo Running %%~nxF
    echo ---------------------------------

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%%F"

    echo.
    echo Finished %%~nxF
    echo ---------------------------------
)

echo.
echo ===============================
echo ALL SCRIPTS COMPLETE
echo ===============================
echo.
echo Press any key to close this window
pause >nul
exit /b 0