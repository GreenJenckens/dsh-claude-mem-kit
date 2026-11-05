# dsh-claude-mem-kit — install claude-mem into DeepSeek Harness and apply the
# cost profile. Windows PowerShell 5.1+.
#
# Idempotent: re-running it repairs the wiring and re-applies the tuning.
# MIT License, Copyright (c) 2026 GreenJenckens.
[CmdletBinding()]
param(
    [string]$DshHome = (Join-Path $env:USERPROFILE '.dsh'),
    [string]$Profile = 'desktop',
    [string]$ClaudeMemVersion = '15.9.0',
    [string]$ObserverKey = '',
    [switch]$SkipTuning,
    [switch]$SkipBridge,
    [switch]$AutoInstall,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$lib = Join-Path $PSScriptRoot 'lib'

function Info([string]$Message) { Write-Host "[kit] $Message" -ForegroundColor Cyan }
function Step([string]$Message) { Write-Host "`n[kit] $Message" -ForegroundColor White }
function Warn([string]$Message) { Write-Host "[kit] $Message" -ForegroundColor Yellow }
function Fail([string]$Message) { Write-Host "[kit] ERROR: $Message" -ForegroundColor Red; exit 1 }
function Have([string]$Name) { return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

function Confirm([string]$Question) {
    if ($AutoInstall) { return $true }
    try { return ((Read-Host "$Question [y/N]") -match '^[Yy]') } catch { return $false }
}

if (-not $IsWindows -and $env:OS -ne 'Windows_NT') { Fail 'this installer targets Windows' }

Step 'Checking Node.js'
if (-not (Have 'node')) { Fail 'Node.js 20+ was not found on PATH. Install it from https://nodejs.org and re-run.' }
$nodeVersion = [version](((& node --version) -replace '^v', '').Split('-')[0])
if ($nodeVersion.Major -lt 20) { Fail "Node.js 20+ is required (found $nodeVersion)." }
Info "node $nodeVersion"

Step 'Checking pnpm'
if (-not (Have 'pnpm')) {
    Info 'pnpm not found; enabling it through corepack / npm'
    if ($DryRun) {
        Info 'would run: corepack enable && npm install -g pnpm'
    } else {
        & corepack enable 2>$null
        if (-not (Have 'pnpm')) { & npm install -g pnpm }
        if (-not (Have 'pnpm')) { Fail 'pnpm could not be installed. Run "npm install -g pnpm" manually and re-run.' }
    }
}
if (Have 'pnpm') { Info "pnpm $(& pnpm --version)" }

$marketplace = Join-Path $env:USERPROFILE '.claude\plugins\marketplaces\thedotmack'
$bundleDir = Join-Path $marketplace 'dsh'

Step 'Locating Claude-Mem'
if (-not (Test-Path (Join-Path $bundleDir 'package.json'))) {
    if (-not (Have 'npx')) { Fail 'npx was not found on PATH.' }
    Info "Claude-Mem is not installed yet; provisioning worker + marketplace (a few minutes)"
    if (-not $DryRun) {
        Info 'The official installer may report a failure for its own DSH step — that is expected on this DSH version.'
        Info 'This kit wires the DSH profile itself right after the download, so the failure is harmless.'
    }
    $bootstrapArgs = @('install', '--ide', 'dsh', '--dsh-profile', 'dsh-mem-bootstrap', '--provider', 'openrouter', '--no-auto-start')
    if ($DryRun) {
        Info "would run: npx -y claude-mem@$ClaudeMemVersion $($bootstrapArgs -join ' ')"
    } else {
        & npx -y "claude-mem@$ClaudeMemVersion" @bootstrapArgs
        $bootstrapProfile = Join-Path $DshHome 'profiles\dsh-mem-bootstrap'
        if (Test-Path $bootstrapProfile) {
            Remove-Item $bootstrapProfile -Recurse -Force -ErrorAction SilentlyContinue
            Info 'removed throwaway profile dsh-mem-bootstrap'
        }
    }
    if (-not (Test-Path (Join-Path $bundleDir 'package.json'))) {
        Fail "Claude-Mem marketplace is still missing at $bundleDir. Run 'npx -y claude-mem@$ClaudeMemVersion install --ide dsh --dsh-profile web' manually, then re-run this script."
    }
}
Info "bundle: $bundleDir"

$profileDir = Join-Path $DshHome "profiles\$Profile"
if (-not (Test-Path (Join-Path $profileDir 'package.json'))) {
    Fail "DSH profile '$Profile' is not initialized ($profileDir). Open DeepSeek Harness once, then re-run."
}
Info "profile: $profileDir"

Step 'Linking @claude-mem/dsh into the profile'
if ($DryRun) {
    Info "would run (in $profileDir): pnpm add `"$bundleDir`""
} else {
    Push-Location $profileDir
    try {
        & pnpm add $bundleDir
        if ($LASTEXITCODE -ne 0) { Fail 'pnpm add failed; see the output above' }
    } finally {
        Pop-Location
    }
}

$wireArgs = @((Join-Path $lib 'wire-profile.mjs'), '--profile-dir', $profileDir, '--bundle', $bundleDir)
if ($DryRun) { $wireArgs += '--dry-run' }
& node @wireArgs
if ($LASTEXITCODE -ne 0) { Fail 'wire-profile failed' }

Step 'Configuring transcript capture'
$memDir = Join-Path $env:USERPROFILE '.claude-mem'
if (-not $DryRun -and -not (Test-Path $memDir)) { New-Item -ItemType Directory -Force -Path $memDir | Out-Null }
$watchArgs = @(
    (Join-Path $lib 'write-watch.mjs'),
    '--example', (Join-Path $repo 'config\transcript-watch.example.json'),
    '--package', $bundleDir
)
if ($DryRun) { $watchArgs += '--dry-run' }
& node @watchArgs
if ($LASTEXITCODE -ne 0) { Fail 'write-watch failed' }

if (-not $SkipTuning) {
    Step 'Applying the cost profile'
    $settingsPath = Join-Path $memDir 'settings.json'
    if (-not $ObserverKey -and -not $DryRun) {
        $hasKey = $false
        if (Test-Path $settingsPath) {
            try {
                $existing = Get-Content $settingsPath -Raw | ConvertFrom-Json
                $hasKey = [bool]$existing.CLAUDE_MEM_OPENAI_COMPAT_API_KEY
            } catch { }
        }
        if (-not $hasKey) {
            try {
                $secure = Read-Host -AsSecureString 'Observer API key (OpenCode Go). Leave empty to set it later'
                $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
                try { $ObserverKey = ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)).Trim() }
                finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
            } catch {
                Warn 'no interactive console; skipping the API key prompt'
            }
        }
    }
    $tuneArgs = @(
        (Join-Path $lib 'apply-tuning.mjs'),
        '--example', (Join-Path $repo 'config\settings.example.json')
    )
    if ($ObserverKey) { $tuneArgs += @('--key', $ObserverKey) }
    if ($DryRun) { $tuneArgs += '--dry-run' }
    & node @tuneArgs
    if ($LASTEXITCODE -ne 0) { Fail 'apply-tuning failed' }
}

Step 'Starting the Claude-Mem worker'
$worker = Join-Path $marketplace 'plugin\scripts\worker-service.cjs'
$bunReady = Have 'bun'
if (-not $bunReady -and -not $DryRun) {
    Warn 'Bun is not installed; the claude-mem worker runs on Bun'
    if (Confirm 'Install Bun now with npm (npm i -g bun)?') {
        & npm install -g bun
        $bunReady = Have 'bun'
    }
}
if (-not (Test-Path $worker)) {
    Warn "worker script not found at $worker"
} elseif ($DryRun) {
    Info "would run: bun `"$worker`" restart"
} elseif (-not $bunReady) {
    Warn "Bun is unavailable; start the worker later with: bun `"$worker`" restart"
} else {
    & bun $worker restart
    if ($LASTEXITCODE -ne 0) { Warn "worker did not start; run manually: bun `"$worker`" restart" }
}

if (-not $SkipBridge) {
    Step 'Starting the observer bridge'
    $proxyDir = Join-Path $repo 'proxy'
    if ($DryRun) {
        Info "would start: wscript `"$proxyDir\start-hidden.vbs`" and register autostart"
    } else {
        Start-Process -FilePath 'wscript.exe' -ArgumentList "`"$(Join-Path $proxyDir 'start-hidden.vbs')`"" -WindowStyle Hidden
        $startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
        $shortcutPath = Join-Path $startup 'claude-mem Observer Bridge.lnk'
        if (-not (Test-Path $shortcutPath)) {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
            $shortcut.Arguments = "`"$(Join-Path $proxyDir 'start-hidden.vbs')`""
            $shortcut.WorkingDirectory = $proxyDir
            $shortcut.Description = 'claude-mem observer bridge (dsh-claude-mem-kit)'
            $shortcut.Save()
            Info "autostart shortcut: $shortcutPath"
        }
        Start-Sleep -Seconds 3
        try {
            $health = Invoke-RestMethod -Uri 'http://127.0.0.1:37901/health' -TimeoutSec 5
            Info "bridge: $($health.status) -> $($health.upstream)"
        } catch {
            Warn 'bridge health check failed; observer requests will fail until it is up (see proxy\README.md)'
        }
    }
}

Step 'Summary'
$settingsPath = Join-Path $memDir 'settings.json'
$keySet = $false
if (Test-Path $settingsPath) {
    try { $keySet = [bool]((Get-Content $settingsPath -Raw | ConvertFrom-Json).CLAUDE_MEM_OPENAI_COMPAT_API_KEY) } catch { }
}
Write-Host '  worker:   curl.exe -s http://127.0.0.1:37777/api/health'
Write-Host '  bridge:   curl.exe -s http://127.0.0.1:37901/health'
Write-Host "  settings: $settingsPath"
Write-Host ''
if (-not $keySet -and -not $SkipTuning) {
    Warn 'The observer API key is not set yet. Memory capture will fail until you put it into'
    Warn 'CLAUDE_MEM_OPENAI_COMPAT_API_KEY in the settings file above.'
}
Write-Host '  Next: restart DeepSeek Harness once, then ask the agent to call mem_context.'
