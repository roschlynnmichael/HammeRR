<#
.SYNOPSIS
    HammeRR Native Windows Installer (Source / Dev Tree)
.DESCRIPTION
    Cleans previous versions, installs HammeRR Map Editor, registers .vmf file associations,
    creates Desktop and Start Menu shortcuts with high-res icon, and registers in Windows Installed Apps.
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
$AssetsDir = Join-Path $RootDir "assets"

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

# 1. Clean previous versions & terminate active processes
Write-Host "`n[1/6] Stopping any running HammeRR processes..." -ForegroundColor Gray
$processes = @("hammerr", "editor", "hammerr-compile", "hammerr-physics", "hammerr-headless", "hammerr-native-runtime")
foreach ($proc in $processes) {
    Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Milliseconds 400

# 2. Create installation directory
Write-Host "[2/6] Preparing installation directory..." -ForegroundColor Gray
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

# 3. Copy executables & assets
Write-Host "[3/6] Installing binaries & assets..." -ForegroundColor Gray

# Install main editor as hammerr.exe and editor.exe
Copy-Item (Join-Path $ReleaseDir "editor.exe") (Join-Path $InstallPath "hammerr.exe") -Force
Copy-Item (Join-Path $ReleaseDir "editor.exe") (Join-Path $InstallPath "editor.exe") -Force
Write-Host "  [OK] hammerr.exe (Main GUI Application)" -ForegroundColor DarkGray

# Install compiler & physics
Copy-Item (Join-Path $ReleaseDir "hammerr-compile.exe") (Join-Path $InstallPath "hammerr-compile.exe") -Force
Write-Host "  [OK] hammerr-compile.exe (Map Compiler)" -ForegroundColor DarkGray

Copy-Item (Join-Path $ReleaseDir "hammerr-physics.exe") (Join-Path $InstallPath "hammerr-physics.exe") -Force
Write-Host "  [OK] hammerr-physics.exe (Engine Physics Worker)" -ForegroundColor DarkGray

Copy-Item (Join-Path $ReleaseDir "hammerr-headless.exe") (Join-Path $InstallPath "hammerr-headless.exe") -Force
Write-Host "  [OK] hammerr-headless.exe (AI/MCP Headless Server)" -ForegroundColor DarkGray

if (Test-Path (Join-Path $ReleaseDir "hammerr-native-runtime.exe")) {
    Copy-Item (Join-Path $ReleaseDir "hammerr-native-runtime.exe") (Join-Path $InstallPath "hammerr-native-runtime.exe") -Force
    Write-Host "  [OK] hammerr-native-runtime.exe" -ForegroundColor DarkGray
}

# Copy icons
$IconPath = Join-Path $InstallPath "icon.ico"
if (Test-Path (Join-Path $AssetsDir "icon.ico")) {
    Copy-Item (Join-Path $AssetsDir "icon.ico") $IconPath -Force
    Copy-Item (Join-Path $AssetsDir "icon.png") (Join-Path $InstallPath "icon.png") -Force
    Write-Host "  [OK] High-resolution application icons installed" -ForegroundColor DarkGray
}

# Copy uninstaller scripts into installation path
Copy-Item (Join-Path $ScriptDir "Uninstall-HammeRR.ps1") (Join-Path $InstallPath "Uninstall-HammeRR.ps1") -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $ScriptDir "Uninstall-HammeRR.bat") (Join-Path $InstallPath "Uninstall-HammeRR.bat") -Force -ErrorAction SilentlyContinue

# 4. Create shortcuts
Write-Host "[4/6] Creating shortcuts..." -ForegroundColor Gray
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
            if (Test-Path $IconPath) {
                $StartMenuShortcut.IconLocation = "$IconPath,0"
            }
            $StartMenuShortcut.Save()
            Write-Host "  [OK] Start Menu Shortcut created" -ForegroundColor DarkGray
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
            if (Test-Path $IconPath) {
                $DesktopShortcut.IconLocation = "$IconPath,0"
            }
            $DesktopShortcut.Save()
            Write-Host "  [OK] Desktop Shortcut created" -ForegroundColor DarkGray
        } catch {
            Write-Warning "Could not create Desktop shortcut: $_"
        }
    }
} catch {
    Write-Warning "Could not initialize WScript.Shell: $_"
}

# 5. Register .vmf file association
if (-not $NoFileAssociation) {
    Write-Host "[5/6] Registering .vmf file association..." -ForegroundColor Gray
    try {
        $RegBase = "HKCU:\Software\Classes"
        New-Item -Path "$RegBase\.vmf" -Value "HammeRR.Vmf" -Force | Out-Null
        New-Item -Path "$RegBase\.vmf" -Name "Content Type" -Value "text/plain" -Force | Out-Null
        New-Item -Path "$RegBase\HammeRR.Vmf" -Value "Valve Map Format (.vmf)" -Force | Out-Null
        $assocIcon = if (Test-Path $IconPath) { "`"$IconPath`",0" } else { "`"$InstallPath\hammerr.exe`",0" }
        New-Item -Path "$RegBase\HammeRR.Vmf\DefaultIcon" -Value $assocIcon -Force | Out-Null
        New-Item -Path "$RegBase\HammeRR.Vmf\shell\open\command" -Value "`"$InstallPath\hammerr.exe`" `"%1`"" -Force | Out-Null
        Write-Host "  [OK] .vmf file association registered with icon" -ForegroundColor DarkGray
    } catch {
        Write-Warning "Could not register file association: $_"
    }
}

# 6. Create Uninstaller script & Register in Windows Add/Remove Programs
Write-Host "[6/6] Registering uninstaller..." -ForegroundColor Gray
$DesktopDir = [Environment]::GetFolderPath('Desktop')
$StartMenuDir = Join-Path ([Environment]::GetFolderPath('Programs')) "HammeRR"
$UninstallerScript = @"
@echo off
title Uninstall HammeRR
echo Terminating running processes and removing HammeRR...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-HammeRR.ps1"
pause
"@
try {
    [IO.File]::WriteAllText((Join-Path $InstallPath "uninstall.cmd"), $UninstallerScript)
} catch {
    Write-Warning "Could not write uninstall.cmd: $_"
}

try {
    $UninstallReg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\HammeRR"
    New-Item -Path $UninstallReg -Force | Out-Null
    Set-ItemProperty -Path $UninstallReg -Name "DisplayName" -Value "HammeRR Map Editor"
    Set-ItemProperty -Path $UninstallReg -Name "DisplayVersion" -Value "0.1.0"
    Set-ItemProperty -Path $UninstallReg -Name "Publisher" -Value "HammeRR Team"
    Set-ItemProperty -Path $UninstallReg -Name "InstallLocation" -Value $InstallPath
    Set-ItemProperty -Path $UninstallReg -Name "UninstallString" -Value "`"$InstallPath\uninstall.cmd`""
    $displayIconVal = if (Test-Path $IconPath) { "$IconPath,0" } else { "$InstallPath\hammerr.exe,0" }
    Set-ItemProperty -Path $UninstallReg -Name "DisplayIcon" -Value $displayIconVal
    Set-ItemProperty -Path $UninstallReg -Name "NoModify" -Value 1 -Type DWord
    Set-ItemProperty -Path $UninstallReg -Name "NoRepair" -Value 1 -Type DWord
    Write-Host "  [OK] Registered in Windows Installed Apps" -ForegroundColor DarkGray
} catch {
    Write-Warning "Could not register uninstaller in Registry: $_"
}

Write-Host "`n==================================================" -ForegroundColor Green
Write-Host "      HammeRR Successfully Installed!             " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Location: $InstallPath\hammerr.exe"
Write-Host "Start Menu: HammeRR"
Write-Host "Desktop Shortcut: HammeRR.lnk"
Write-Host "File Association: .vmf maps will open in HammeRR`n"
