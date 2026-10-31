@echo off
title HammeRR Update and Rebuild Tool
cd /d "%~dp0"
echo ===================================================
echo           HammeRR Update & Rebuild Tool            
echo ===================================================
echo.
echo Launching automated update and rebuild process...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-And-Rebuild.ps1"
echo.
pause

