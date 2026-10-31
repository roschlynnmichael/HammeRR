<#
.SYNOPSIS
    HammeRR Automated Update & Rebuild Tool
.DESCRIPTION
    Pulls the latest commits from Git, recompiles the Windows release binaries,
    and updates the dist\ folder and distribution zip package.
#>
[CmdletBinding()]
param(
    [string]$Remote = "origin",
    [string]$Branch = "master",
    [switch]$SkipPull
)

$ErrorActionPreference = 'Stop'

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "       HammeRR Update & Rebuild Utility           " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = (Resolve-Path "$ScriptDir\..").Path
Set-Location $RootDir

# 1. Pull latest changes
if (-not $SkipPull) {
    Write-Host "`n[1/4] Checking for latest updates from Git ($Remote/$Branch)..." -ForegroundColor Yellow
    try {
        # Check git status
        $status = git status --porcelain
        if ($status) {
            Write-Host "Notice: You have unstaged or modified files in your workspace." -ForegroundColor Gray
            Write-Host "Stashing local working changes..." -ForegroundColor Gray
            git stash
        }

        # Pull
        Write-Host "Pulling latest commits..." -ForegroundColor Gray
        git pull $Remote $Branch
        Write-Host "  [OK] Git repository is up to date." -ForegroundColor Green
    } catch {
        Write-Host "`n[!] Warning: Git pull encountered an issue: $_" -ForegroundColor Red
        Write-Host "If upstream introduced conflicts with Windows port files," -ForegroundColor Yellow
        Write-Host "ask your AI assistant to resolve the merge conflict for you." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "`n[1/4] Skipping Git pull (-SkipPull specified)..." -ForegroundColor Gray
}

# 2. Build Release Binaries
Write-Host "`n[2/4] Compiling native release executables with Cargo..." -ForegroundColor Yellow
Write-Host "This will incrementally compile only modified files..." -ForegroundColor Gray

try {
    cargo build --release --bins
    if ($LASTEXITCODE -ne 0) {
        throw "Cargo build exited with code $LASTEXITCODE"
    }
    Write-Host "  [OK] Release binaries successfully compiled!" -ForegroundColor Green
} catch {
    Write-Host "`n[!] Compilation Error: $_" -ForegroundColor Red
    Write-Host "A new upstream feature may require Windows-specific adaptation." -ForegroundColor Yellow
    Write-Host "Please ask your AI assistant to inspect the error and adapt the code." -ForegroundColor Yellow
    exit 1
}

# 3. Update Distribution Folder
Write-Host "`n[3/4] Updating distribution folder (dist\HammeRR-Windows-v0.1.0)..." -ForegroundColor Yellow

$DistDir = Join-Path $RootDir "dist\HammeRR-Windows-v0.1.0"
$ReleaseDir = Join-Path $RootDir "target\release"

if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

Copy-Item (Join-Path $ReleaseDir "editor.exe") (Join-Path $DistDir "hammerr.exe") -Force
Copy-Item (Join-Path $ReleaseDir "editor.exe") (Join-Path $DistDir "editor.exe") -Force
Copy-Item (Join-Path $ReleaseDir "hammerr-compile.exe") (Join-Path $DistDir "hammerr-compile.exe") -Force
Copy-Item (Join-Path $ReleaseDir "hammerr-physics.exe") (Join-Path $DistDir "hammerr-physics.exe") -Force
Copy-Item (Join-Path $ReleaseDir "hammerr-headless.exe") (Join-Path $DistDir "hammerr-headless.exe") -Force

if (Test-Path (Join-Path $ReleaseDir "hammerr-native-runtime.exe")) {
    Copy-Item (Join-Path $ReleaseDir "hammerr-native-runtime.exe") (Join-Path $DistDir "hammerr-native-runtime.exe") -Force
}

Write-Host "  [OK] Binaries copied to distribution folder." -ForegroundColor Green

# 4. Update Distribution Zip Package
Write-Host "`n[4/4] Updating distribution zip package..." -ForegroundColor Yellow
$ZipPath = Join-Path $RootDir "dist\HammeRR-Windows-v0.1.0.zip"
$ProgressPreference = 'SilentlyContinue'
try {
    Compress-Archive -Path "$DistDir\*" -DestinationPath $ZipPath -Force
    Write-Host "  [OK] Zip package updated: $ZipPath" -ForegroundColor Green
} catch {
    Write-Warning "Could not update zip archive: $_"
}

Write-Host "`n==================================================" -ForegroundColor Green
Write-Host "      HammeRR Successfully Updated & Rebuilt!     " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Ready to run from: dist\HammeRR-Windows-v0.1.0\hammerr.exe"
Write-Host "Or install with:   dist\HammeRR-Windows-v0.1.0\Install-HammeRR.bat`n"
