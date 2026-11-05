# dsh-claude-mem-kit - remove the DSH wiring, stop the services and optionally
# move the memory database aside.
#
# MIT License, Copyright (c) 2026 GreenJenckens.
[CmdletBinding()]
param(
    [string]$DshHome = (Join-Path $env:USERPROFILE '.dsh'),
    [string]$Profile = 'desktop',
    [switch]$PurgeData,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$lib = Join-Path $PSScriptRoot 'lib'

function Info([string]$Message) { Write-Host "[kit] $Message" -ForegroundColor Cyan }
function Step([string]$Message) { Write-Host "`n[kit] $Message" -ForegroundColor White }
function Warn([string]$Message) { Write-Host "[kit] $Message" -ForegroundColor Yellow }

$marketplace = Join-Path $env:USERPROFILE '.claude\plugins\marketplaces\thedotmack'
$worker = Join-Path $marketplace 'plugin\scripts\worker-service.cjs'
$profileDir = Join-Path $DshHome "profiles\$Profile"

Step 'Stopping the worker'
if ((Test-Path $worker) -and (Get-Command bun -ErrorAction SilentlyContinue)) {
    if ($DryRun) { Info "would run: bun `"$worker`" stop" }
    else { & bun $worker stop | Out-Null }
}

Step "Unwiring @claude-mem/dsh from profile '$Profile'"
if (Test-Path (Join-Path $profileDir 'package.json')) {
    $wireArgs = @((Join-Path $lib 'wire-profile.mjs'), '--profile-dir', $profileDir, '--remove')
    if ($DryRun) { $wireArgs += '--dry-run' }
    & node @wireArgs
    if (-not $DryRun -and (Get-Command pnpm -ErrorAction SilentlyContinue)) {
        Push-Location $profileDir
        try { & pnpm install | Out-Null } finally { Pop-Location }
    }
} else {
    Warn "profile not found: $profileDir"
}

Step 'Removing the bridge autostart shortcut'
$shortcutPath = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\claude-mem Observer Bridge.lnk'
if (Test-Path $shortcutPath) {
    if ($DryRun) { Info "would remove: $shortcutPath" }
    else { Remove-Item $shortcutPath -Force }
}

Step 'Stopping the observer bridge (port 37901)'
$listener = Get-NetTCPConnection -LocalPort 37901 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($listener) {
    $process = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
    if ($process -and $process.ProcessName -eq 'node') {
        if ($DryRun) { Info "would stop node PID $($process.Id)" }
        else { Stop-Process -Id $process.Id -Force }
    } else {
        Warn "port 37901 is held by $($process.ProcessName) (PID $($listener.OwningProcess)); not touching it"
    }
}

if ($PurgeData) {
    Step 'Moving the memory database aside'
    $memDir = Join-Path $env:USERPROFILE '.claude-mem'
    $backupDir = Join-Path $env:USERPROFILE ('.claude-mem-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    if (Test-Path $memDir) {
        if ($DryRun) { Info "would move $memDir -> $backupDir" }
        else { Move-Item $memDir $backupDir; Info "moved to $backupDir" }
    }
}

Step 'Done'
Write-Host '  Restart DeepSeek Harness to unload the plugin.'
if (-not $PurgeData) { Write-Host '  Memory data was kept in %USERPROFILE%\.claude-mem' }
