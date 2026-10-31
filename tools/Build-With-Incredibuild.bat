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
echo Updating distribution folder...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { $Dist = '.\dist\HammeRR-Windows-v0.1.0'; Copy-Item '.\target\release\editor.exe' \"$Dist\hammerr.exe\" -Force; Copy-Item '.\target\release\editor.exe' \"$Dist\editor.exe\" -Force; Copy-Item '.\target\release\hammerr-compile.exe' \"$Dist\hammerr-compile.exe\" -Force; Copy-Item '.\target\release\hammerr-physics.exe' \"$Dist\hammerr-physics.exe\" -Force; Copy-Item '.\target\release\hammerr-headless.exe' \"$Dist\hammerr-headless.exe\" -Force; if (Test-Path '.\target\release\hammerr-native-runtime.exe') { Copy-Item '.\target\release\hammerr-native-runtime.exe' \"$Dist\hammerr-native-runtime.exe\" -Force }; Compress-Archive -Path \"$Dist\*\" -DestinationPath '.\dist\HammeRR-Windows-v0.1.0.zip' -Force; Write-Host 'Distribution packages successfully updated.' -ForegroundColor Green }"

echo.
echo ===================================================
echo    HammeRR release build ready in dist\ folder!    
echo ===================================================
pause
