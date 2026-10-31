@echo off
title HammeRR Incredibuild Accelerator
cd /d "%~dp0\.."

echo ===================================================
echo        HammeRR Incredibuild Build Accelerator      
echo ===================================================
echo.

set "IB_CONSOLE=C:\Program Files (x86)\IncrediBuild\BuildConsole.exe"

if not exist "%IB_CONSOLE%" (
    echo [ERROR] Incredibuild BuildConsole was not found at:
    echo "%IB_CONSOLE%"
    echo.
    pause
    exit /b 1
)

set "CORES=%NUMBER_OF_PROCESSORS%"
if "%CORES%"=="" set "CORES=16"

echo Detected %CORES% CPU cores.
echo Launching Cargo build utilizing full CPU parallelism under Incredibuild...
echo.

"%IB_CONSOLE%" /COMMAND="cargo build --release --bins --jobs %CORES%" /KEEPORIGJOBSNUM /MAXCPUS=%CORES% /OPENMONITOR /TITLE="HammeRR Windows Release Build (All Cores)"

if %ERRORLEVEL% neq 0 (
    echo.
    echo [!] Incredibuild build finished with errors (code %ERRORLEVEL%).
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [OK] Incredibuild compilation succeeded!
echo Updating distribution folder and zip package...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Package-Dist.ps1"

echo.
echo ===================================================
echo    HammeRR release build ready in dist\ folder!    
echo ===================================================
pause
