@echo off
title Uninstall HammeRR
cd /d "%~dp0"
echo ===================================================
echo             Uninstall HammeRR                      
echo ===================================================
echo.
echo Stopping HammeRR and removing old versions...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-HammeRR.ps1"
echo.
pause

