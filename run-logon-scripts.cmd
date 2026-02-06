@echo off
title VM Startup Scripts
color 0a

REM Disable QuickEdit mode for THIS console session to prevent freezing when clicked
powershell -NoProfile -Command "$m='[DllImport(\"kernel32.dll\")]static extern IntPtr GetStdHandle(int n);[DllImport(\"kernel32.dll\")]static extern bool GetConsoleMode(IntPtr h,out uint m);[DllImport(\"kernel32.dll\")]static extern bool SetConsoleMode(IntPtr h,uint m);public static void Disable(){var h=GetStdHandle(-10);uint m;GetConsoleMode(h,out m);m&=~0x0040;m&=~0x0020;SetConsoleMode(h,m);}';Add-Type -M $m -N C -Name M;[C.M]::Disable();" 2>nul

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