# dsh-claude-mem-kit - one-command bootstrap.
#
# Downloads the latest kit from GitHub and runs scripts\install.ps1 with the
# usual options. MIT License, Copyright (c) 2026 GreenJenckens.
#
# Usage:
#   irm https://raw.githubusercontent.com/GreenJenckens/dsh-claude-mem-kit/main/scripts/bootstrap.ps1 | iex
#
# Or download and inspect first:
#   irm .../scripts/bootstrap.ps1 -OutFile bootstrap.ps1
#   powershell -ExecutionPolicy Bypass -File bootstrap.ps1 -Profile desktop
[CmdletBinding()]
param(
    [string]$Ref = 'main',
    [string]$Dest = (Join-Path $env:LOCALAPPDATA 'dsh-claude-mem-kit'),
    [string]$Profile = 'desktop',
    [string]$ObserverKey = '',
    [switch]$SkipBridge,
    [switch]$AutoInstall,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if (-not $IsWindows -and $env:OS -ne 'Windows_NT') { throw 'bootstrap.ps1 targets Windows' }

$zip = Join-Path $env:TEMP "dsh-claude-mem-kit-$Ref.zip"
$url = "https://codeload.github.com/GreenJenckens/dsh-claude-mem-kit/zip/refs/heads/$Ref"

Write-Host "[bootstrap] downloading $url" -ForegroundColor Cyan
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
Expand-Archive -Path $zip -DestinationPath $Dest -Force
Remove-Item $zip -Force

$source = Join-Path $Dest "dsh-claude-mem-kit-$Ref"
if (-not (Test-Path (Join-Path $source 'scripts\install.ps1'))) {
    throw "unexpected archive layout: $source"
}

$installer = Join-Path $source 'scripts\install.ps1'
$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installer, '-Profile', $Profile)
if ($ObserverKey) { $arguments += @('-ObserverKey', $ObserverKey) }
if ($SkipBridge) { $arguments += '-SkipBridge' }
if ($AutoInstall) { $arguments += '-AutoInstall' }
if ($DryRun) { $arguments += '-DryRun' }

Write-Host "[bootstrap] running $installer" -ForegroundColor Cyan
& powershell @arguments
exit $LASTEXITCODE
