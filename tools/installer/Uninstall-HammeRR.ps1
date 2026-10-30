<#
.SYNOPSIS
    HammeRR Uninstaller / Old Versions Cleaner
.DESCRIPTION
    Safely terminates running processes, removes old HammeRR installations,
    cleans up shortcuts, file associations, and registry entries.
#>
[CmdletBinding()]
param(
    [switch]$KeepUserData,
    [switch]$Silent
)

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "       HammeRR Uninstaller & Cleaner              " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Terminate running processes
Write-Host "`n[1/5] Terminating any running HammeRR processes..." -ForegroundColor Gray
$processes = @("hammerr", "editor", "hammerr-compile", "hammerr-physics", "hammerr-headless", "hammerr-native-runtime")
foreach ($proc in $processes) {
    $found = Get-Process -Name $proc -ErrorAction SilentlyContinue
    if ($found) {
        Write-Host "   - Stopping $proc.exe..." -ForegroundColor Yellow
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
    }
}
Start-Sleep -Milliseconds 500

# 2. Check and query installed locations
Write-Host "[2/5] Locating installed versions..." -ForegroundColor Gray
$targetsToClean = [System.Collections.Generic.List[string]]::new()

$defaultLocal = "$env:LOCALAPPDATA\Programs\HammeRR"
if (Test-Path $defaultLocal) {
    $targetsToClean.Add($defaultLocal)
}

$programFiles = "$env:ProgramFiles\HammeRR"
if (Test-Path $programFiles) {
    $targetsToClean.Add($programFiles)
}

$programFilesX86 = "${env:ProgramFiles(x86)}\HammeRR"
if (Test-Path $programFilesX86) {
    $targetsToClean.Add($programFilesX86)
}

# Check Registry for registered install location
$regPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\HammeRR",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\HammeRR"
)
foreach ($reg in $regPaths) {
    if (Test-Path $reg) {
        $loc = (Get-ItemProperty -Path $reg -Name "InstallLocation" -ErrorAction SilentlyContinue).InstallLocation
        if ($loc -and (Test-Path $loc) -and (-not $targetsToClean.Contains($loc))) {
            $targetsToClean.Add($loc)
        }
    }
}

# 3. Clean files
Write-Host "[3/5] Removing installed files..." -ForegroundColor Gray
if ($targetsToClean.Count -eq 0) {
    Write-Host "   - No existing installation directory found." -ForegroundColor DarkGray
} else {
    foreach ($dir in $targetsToClean) {
        Write-Host "   - Removing: $dir" -ForegroundColor Yellow
        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (-not $KeepUserData) {
    $appDataLocal = "$env:LOCALAPPDATA\HammeRR"
    if (Test-Path $appDataLocal) {
        Write-Host "   - Cleaning local cache: $appDataLocal" -ForegroundColor DarkGray
        Remove-Item -Path $appDataLocal -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 4. Remove Shortcuts
Write-Host "[4/5] Removing desktop and start menu shortcuts..." -ForegroundColor Gray
$shortcuts = @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) "HammeRR.lnk"),
    (Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) "HammeRR.lnk"),
    (Join-Path ([Environment]::GetFolderPath('Programs')) "HammeRR\HammeRR.lnk"),
    (Join-Path ([Environment]::GetFolderPath('CommonPrograms')) "HammeRR\HammeRR.lnk")
)
foreach ($s in $shortcuts) {
    if (Test-Path $s) {
        Write-Host "   - Removing shortcut: $s" -ForegroundColor DarkGray
        Remove-Item -Path $s -Force -ErrorAction SilentlyContinue
    }
}

$startMenuFolder = Join-Path ([Environment]::GetFolderPath('Programs')) "HammeRR"
if (Test-Path $startMenuFolder) {
    Remove-Item -Path $startMenuFolder -Recurse -Force -ErrorAction SilentlyContinue
}

# 5. Clean Registry entries
Write-Host "[5/5] Cleaning Windows registry entries..." -ForegroundColor Gray
$registryKeys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\HammeRR",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\HammeRR",
    "HKCU:\Software\Classes\.vmf",
    "HKCU:\Software\Classes\HammeRR.Vmf",
    "HKCU:\Software\Classes\HammerR.Vmf",
    "HKCU:\Software\HammeRR"
)
foreach ($k in $registryKeys) {
    if (Test-Path $k) {
        Write-Host "   - Removing registry key: $k" -ForegroundColor DarkGray
        Remove-Item -Path $k -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`n==================================================" -ForegroundColor Green
Write-Host "  HammeRR has been successfully uninstalled/cleaned! " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green

