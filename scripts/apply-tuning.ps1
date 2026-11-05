# dsh-claude-mem-kit - apply only the cost profile to an existing Claude-Mem
# installation (no DSH profile changes).
#
# MIT License, Copyright (c) 2026 GreenJenckens.
[CmdletBinding()]
param(
    [string]$ObserverKey = '',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host '[kit] ERROR: node was not found on PATH' -ForegroundColor Red
    exit 1
}

$argsList = @(
    (Join-Path $PSScriptRoot 'lib\apply-tuning.mjs'),
    '--example', (Join-Path $repo 'config\settings.example.json')
)
if ($ObserverKey) { $argsList += @('--key', $ObserverKey) }
if ($DryRun) { $argsList += '--dry-run' }

& node @argsList
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host '[kit] Restart the worker to pick up the new settings:' -ForegroundColor Cyan
Write-Host '  bun "$env:USERPROFILE\.claude\plugins\marketplaces\thedotmack\plugin\scripts\worker-service.cjs" restart'
