@echo off
setlocal enabledelayedexpansion

REM Define the directory containing the scripts
set scriptDirectory=%~dp0weekend-scripts

REM Define log file location
set logFile=C:\Git\Admin\Logs\Weekend_Scripts\weekend_script.log

REM Start logging
echo [%DATE% %TIME%] Script started. > "%logFile%"
echo [%DATE% %TIME%] Script started.

REM Check if the directory exists
if not exist "%scriptDirectory%" (
    echo [%DATE% %TIME%] Directory "%scriptDirectory%" not found! >> "%logFile%"
    echo [%DATE% %TIME%] Directory "%scriptDirectory%" not found!
    exit /b 1
)

REM Get all .ps1 files in the directory
for /r "%scriptDirectory%" %%f in (*.ps1) do (
    echo [%DATE% %TIME%] Executing script: %%f >> "%logFile%"
    echo [%DATE% %TIME%] Executing script: %%f

    REM Execute the script using PowerShell and log the output
    powershell -ExecutionPolicy Bypass -File "%%f" >> "%logFile%" 2>&1

    REM Check if the script executed successfully
    if !errorlevel! neq 0 (
        echo [%DATE% %TIME%] Error executing script: %%f >> "%logFile%"
        echo [%DATE% %TIME%] Error executing script: %%f
    ) else (
        echo [%DATE% %TIME%] Script executed successfully: %%f >> "%logFile%"
        echo [%DATE% %TIME%] Script executed successfully: %%f
    )

    echo. >> "%logFile%"
    echo.
)

endlocal
exit /b 0
