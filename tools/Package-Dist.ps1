<#
.SYNOPSIS
    Copies release binaries to dist\ folder and creates zip package.
#>
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = (Resolve-Path "$ScriptDir\..").Path

$ReleaseDir = Join-Path $RootDir "target\release"
$DistDir = Join-Path $RootDir "dist\HammeRR-Windows-v0.1.0"
$ZipPath = Join-Path $RootDir "dist\HammeRR-Windows-v0.1.0.zip"

if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

Write-Host "Copying compiled release binaries to $DistDir..." -ForegroundColor Cyan
Copy-Item (Join-Path $ReleaseDir "editor.exe") (Join-Path $DistDir "hammerr.exe") -Force
Copy-Item (Join-Path $ReleaseDir "editor.exe") (Join-Path $DistDir "editor.exe") -Force
Copy-Item (Join-Path $ReleaseDir "hammerr-compile.exe") (Join-Path $DistDir "hammerr-compile.exe") -Force
Copy-Item (Join-Path $ReleaseDir "hammerr-physics.exe") (Join-Path $DistDir "hammerr-physics.exe") -Force
Copy-Item (Join-Path $ReleaseDir "hammerr-headless.exe") (Join-Path $DistDir "hammerr-headless.exe") -Force

if (Test-Path (Join-Path $ReleaseDir "hammerr-native-runtime.exe")) {
    Copy-Item (Join-Path $ReleaseDir "hammerr-native-runtime.exe") (Join-Path $DistDir "hammerr-native-runtime.exe") -Force
}

Write-Host "Updating distribution zip archive: $ZipPath..." -ForegroundColor Cyan
$ProgressPreference = 'SilentlyContinue'
Compress-Archive -Path "$DistDir\*" -DestinationPath $ZipPath -Force

Write-Host "Packaging complete!" -ForegroundColor Green
