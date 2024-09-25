@echo off
setlocal enabledelayedexpansion

REM Define the directory containing the scripts
set scriptDirectory=%~dp0logon-scripts

REM Check if the directory exists
if not exist "%scriptDirectory%" (
    echo Directory "%scriptDirectory%" not found!
    exit /b 1
)

REM Get all .ps1 files in the directory
for /r "%scriptDirectory%" %%f in (*.ps1) do (
    echo Executing script: %%f
    
    REM Execute the script using PowerShell
    powershell -ExecutionPolicy Bypass -File "%%f"
    
    REM Check if the script executed successfully
    if !errorlevel! neq 0 (
        echo Error executing script: %%f
    ) else (
        echo Script executed successfully: %%f
    )

    echo.
)

endlocal
exit /b 0
