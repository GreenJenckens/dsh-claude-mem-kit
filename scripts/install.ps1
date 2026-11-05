# dsh-claude-mem-kit — install claude-mem into DeepSeek Harness and apply the
# cost profile. Windows PowerShell 5.1+.
#
# MIT License, Copyright (c) 2026 GreenJenckens.
[CmdletBinding()]
param(
    [string]$DshHome = (Join-Path $env:USERPROFILE '.dsh'),
    [string]$Profile = 'desktop',
    [string]$ClaudeMemVersion = '15.9.0',
    [string]$ObserverKey = '',
    [switch]$SkipTuning,
    [switch]$SkipBridge,
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

if (-not $IsWindows -and $env:OS -ne 'Windows_NT') { Fail 'this installer targets Windows' }

Step "Checking prerequisites"
foreach ($tool in @('node', 'pnpm', 'npx')) {
    if (-not (Have $tool)) { Fail "$tool was not found on PATH. Install Node.js 20+ and pnpm 11+ first." }
}
if (-not (Have 'bun')) { Fail "Bun was not found on PATH. Install it with: winget install Oven-sh.Bun" }

$marketplace = Join-Path $env:USERPROFILE '.claude\plugins\marketplaces\thedotmack'
$bundleDir = Join-Path $marketplace 'dsh'

Step "Locating Claude-Mem"
if (-not (Test-Path (Join-Path $bundleDir 'package.json'))) {
    if (-not (Have 'dsh')) {
        Fail "Claude-Mem is not installed and the 'dsh' CLI is not on PATH. Install DeepSeek Harness and claude-mem first, or run: npx -y claude-mem@$ClaudeMemVersion install --ide dsh --dsh-profile web"
    }
    Info "Claude-Mem not found; bootstrapping worker + marketplace (this can take a few minutes)"
    if ($DryRun) {
        Info "would run: npx -y claude-mem@$ClaudeMemVersion install --ide dsh --dsh-profile dsh-mem-bootstrap --provider openrouter --no-auto-start"
    } else {
        & npx -y "claude-mem@$ClaudeMemVersion" install --ide dsh --dsh-profile dsh-mem-bootstrap --provider openrouter --no-auto-start
        # The bootstrap profile is only needed to provision the marketplace; the
        # real wiring happens below, so drop it again.
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

Step "Linking @claude-mem/dsh into the profile"
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

Step "Configuring transcript capture"
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
if (-not (Test-Path $worker)) {
    Warn "worker script not found at $worker"
} elseif ($DryRun) {
    Info "would run: bun `"$worker`" restart"
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
            Warn 'bridge health check failed; the observer requests will fail until it is up (see proxy\README.md)'
        }
    }
}

Step 'Summary'
Write-Host '  worker:  curl.exe -s http://127.0.0.1:37777/api/health'
Write-Host '  bridge:  curl.exe -s http://127.0.0.1:37901/health'
Write-Host "  settings: $memDir\settings.json"
Write-Host ''
Write-Host '  Next: restart DeepSeek Harness once, then ask the agent to call mem_context.'
Write-Host '  If the observer key is empty, put your API key into CLAUDE_MEM_OPENAI_COMPAT_API_KEY.'
