<#
.SYNOPSIS
    HammeRR Native Windows Installer (Source / Dev Tree)
.DESCRIPTION
    Installs HammeRR Map Editor, registers file associations (.vmf),
    creates Desktop and Start Menu shortcuts, and registers in Windows Installed Apps.
#>
[CmdletBinding()]
param(
    [string]$InstallPath = "$env:LOCALAPPDATA\Programs\HammeRR",
    [switch]$NoStartMenuShortcut,
    [switch]$NoDesktopShortcut,
    [switch]$NoFileAssociation,
    [switch]$Silent
)

$ErrorActionPreference = 'Stop'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   HammeRR Map Editor Windows Setup     " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = (Resolve-Path "$ScriptDir\..\..").Path
$ReleaseDir = Join-Path $RootDir "target\release"

# Verify binaries exist
$RequiredBinaries = @("editor.exe", "hammerr-compile.exe", "hammerr-physics.exe", "hammerr-headless.exe")
foreach ($bin in $RequiredBinaries) {
    $fullPath = Join-Path $ReleaseDir $bin
    if (-not (Test-Path $fullPath)) {
        Write-Error "Required binary not found: $fullPath`nPlease run 'cargo build --release' first."
        exit 1
    }
}

Write-Host "`nTarget Installation Directory: $InstallPath" -ForegroundColor Yellow

if (-not $Silent) {
    $choice = Read-Host "Proceed with installation to '$InstallPath'? (Y/n/change)"
    if ($choice -match '^[cC]') {
        $InstallPath = Read-Host "Enter custom installation path"
    } elseif ($choice -match '^[nN]') {
        Write-Host "Installation canceled." -ForegroundColor Red
        exit 0
    }
}

# Create installation directory
if (-not (Test-Path $InstallPath)) {
    Write-Host "Creating directory: $InstallPath" -ForegroundColor Gray
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

# Copy executables
Write-Host "`nInstalling binaries..." -ForegroundColor Green

# Install main editor as hammerr.exe and editor.exe
Copy-Item (Join-Path $ReleaseDir "editor.exe") (Join-Path $InstallPath "hammerr.exe") -Force
Copy-Item (Join-Path $ReleaseDir "editor.exe") (Join-Path $InstallPath "editor.exe") -Force
Write-Host "  [OK] hammerr.exe (Main GUI Application)" -ForegroundColor Gray

# Install compiler & physics
Copy-Item (Join-Path $ReleaseDir "hammerr-compile.exe") (Join-Path $InstallPath "hammerr-compile.exe") -Force
Write-Host "  [OK] hammerr-compile.exe (Map Compiler)" -ForegroundColor Gray

Copy-Item (Join-Path $ReleaseDir "hammerr-physics.exe") (Join-Path $InstallPath "hammerr-physics.exe") -Force
Write-Host "  [OK] hammerr-physics.exe (Engine Physics Worker)" -ForegroundColor Gray

Copy-Item (Join-Path $ReleaseDir "hammerr-headless.exe") (Join-Path $InstallPath "hammerr-headless.exe") -Force
Write-Host "  [OK] hammerr-headless.exe (AI/MCP Headless Server)" -ForegroundColor Gray

if (Test-Path (Join-Path $ReleaseDir "hammerr-native-runtime.exe")) {
    Copy-Item (Join-Path $ReleaseDir "hammerr-native-runtime.exe") (Join-Path $InstallPath "hammerr-native-runtime.exe") -Force
    Write-Host "  [OK] hammerr-native-runtime.exe" -ForegroundColor Gray
}

# Create shortcuts
try {
    $WshShell = New-Object -ComObject WScript.Shell

    if (-not $NoStartMenuShortcut) {
        try {
            $StartMenuDir = Join-Path ([Environment]::GetFolderPath('Programs')) "HammeRR"
            if (-not (Test-Path $StartMenuDir)) {
                New-Item -ItemType Directory -Path $StartMenuDir -Force | Out-Null
            }
            $StartMenuShortcut = $WshShell.CreateShortcut((Join-Path $StartMenuDir "HammeRR.lnk"))
            $StartMenuShortcut.TargetPath = Join-Path $InstallPath "hammerr.exe"
            $StartMenuShortcut.WorkingDirectory = $InstallPath
            $StartMenuShortcut.Description = "HammeRR Map Editor for Source Engine"
            $StartMenuShortcut.Save()
            Write-Host "  [OK] Start Menu Shortcut created" -ForegroundColor Gray
        } catch {
            Write-Warning "Could not create Start Menu shortcut: $_"
        }
    }

    if (-not $NoDesktopShortcut) {
        try {
            $DesktopDir = [Environment]::GetFolderPath('Desktop')
            $DesktopShortcut = $WshShell.CreateShortcut((Join-Path $DesktopDir "HammeRR.lnk"))
            $DesktopShortcut.TargetPath = Join-Path $InstallPath "hammerr.exe"
            $DesktopShortcut.WorkingDirectory = $InstallPath
            $DesktopShortcut.Description = "HammeRR Map Editor"
            $DesktopShortcut.Save()
            Write-Host "  [OK] Desktop Shortcut created" -ForegroundColor Gray
        } catch {
            Write-Warning "Could not create Desktop shortcut: $_"
        }
    }
} catch {
    Write-Warning "Could not initialize WScript.Shell: $_"
}

# Register .vmf file association
if (-not $NoFileAssociation) {
    try {
        $RegBase = "HKCU:\Software\Classes"
        New-Item -Path "$RegBase\.vmf" -Value "HammeRR.Vmf" -Force | Out-Null
        New-Item -Path "$RegBase\.vmf" -Name "Content Type" -Value "text/plain" -Force | Out-Null
        New-Item -Path "$RegBase\HammeRR.Vmf" -Value "Valve Map Format (.vmf)" -Force | Out-Null
        New-Item -Path "$RegBase\HammeRR.Vmf\DefaultIcon" -Value "`"$InstallPath\hammerr.exe`",0" -Force | Out-Null
        New-Item -Path "$RegBase\HammeRR.Vmf\shell\open\command" -Value "`"$InstallPath\hammerr.exe`" `"%1`"" -Force | Out-Null
        Write-Host "  [OK] .vmf file association registered" -ForegroundColor Gray
    } catch {
        Write-Warning "Could not register file association: $_"
    }
}

# Create Uninstaller script
$DesktopDir = [Environment]::GetFolderPath('Desktop')
$StartMenuDir = Join-Path ([Environment]::GetFolderPath('Programs')) "HammeRR"
$UninstallerScript = @"
@echo off
echo Uninstalling HammeRR...
taskkill /F /IM hammerr.exe 2>nul
taskkill /F /IM editor.exe 2>nul
taskkill /F /IM hammerr-compile.exe 2>nul
taskkill /F /IM hammerr-headless.exe 2>nul

reg delete "HKCU\Software\Classes\.vmf" /f 2>nul
reg delete "HKCU\Software\Classes\HammeRR.Vmf" /f 2>nul
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\HammeRR" /f 2>nul

del /F /Q "$StartMenuDir\HammeRR.lnk" 2>nul
rmdir /Q "$StartMenuDir" 2>nul
del /F /Q "$DesktopDir\HammeRR.lnk" 2>nul

echo Removing files...
cd /d "%TEMP%"
rmdir /S /Q "$InstallPath" 2>nul
echo HammeRR has been successfully uninstalled.
pause
"@
try {
    [IO.File]::WriteAllText((Join-Path $InstallPath "uninstall.cmd"), $UninstallerScript)
} catch {
    Write-Warning "Could not write uninstall.cmd: $_"
}

# Register in Windows Add/Remove Programs
try {
    $UninstallReg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\HammeRR"
    New-Item -Path $UninstallReg -Force | Out-Null
    Set-ItemProperty -Path $UninstallReg -Name "DisplayName" -Value "HammeRR Map Editor"
    Set-ItemProperty -Path $UninstallReg -Name "DisplayVersion" -Value "0.1.0"
    Set-ItemProperty -Path $UninstallReg -Name "Publisher" -Value "HammeRR Team"
    Set-ItemProperty -Path $UninstallReg -Name "InstallLocation" -Value $InstallPath
    Set-ItemProperty -Path $UninstallReg -Name "UninstallString" -Value "`"$InstallPath\uninstall.cmd`""
    Set-ItemProperty -Path $UninstallReg -Name "DisplayIcon" -Value "$InstallPath\hammerr.exe,0"
    Set-ItemProperty -Path $UninstallReg -Name "NoModify" -Value 1 -Type DWord
    Set-ItemProperty -Path $UninstallReg -Name "NoRepair" -Value 1 -Type DWord
    Write-Host "  [OK] Registered in Windows Installed Apps" -ForegroundColor Gray
} catch {
    Write-Warning "Could not register uninstaller in Registry: $_"
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  HammeRR Successfully Installed!        " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Location: $InstallPath\hammerr.exe"
Write-Host "Start Menu: HammeRR"
Write-Host "Desktop Shortcut: HammeRR.lnk"
Write-Host "File Association: .vmf maps will open in HammeRR"
Write-Host ""
