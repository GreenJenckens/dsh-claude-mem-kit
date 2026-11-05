#!/usr/bin/env bash
# dsh-claude-mem-kit — installer for Linux and macOS.
#
# Installs the Claude-Mem worker + marketplace if needed, wires @claude-mem/dsh
# into a DeepSeek Harness profile, writes the DSH transcript watch, applies the
# cost profile and runs the loopback observer bridge.
#
# MIT License, Copyright (c) 2026 GreenJenckens.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$REPO_ROOT/scripts/lib"

DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
PROFILE="web"
CLAUDE_MEM_VERSION="15.9.0"
OBSERVER_KEY=""
SKIP_TUNING=0
SKIP_BRIDGE=0
AUTO_INSTALL=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: scripts/install.sh [options]

Options:
  --profile <name>          DSH profile to wire (default: web; desktop needs the app)
  --dsh-home <dir>          DSH home (default: $DSH_HOME or ~/.dsh)
  --claude-mem-version <v>  Claude-Mem version to install (default: 15.9.0)
  --observer-key <key>      Observer API key (skip the prompt)
  --skip-tuning             Do not touch ~/.claude-mem/settings.json
  --skip-bridge             Do not install/start the observer bridge
  --auto-install            Install missing pnpm/Bun without asking
  --dry-run                 Print what would happen, change nothing
  -h, --help                Show this help
EOF
}

info() { printf '[kit] %s\n' "$*"; }
step() { printf '\n[kit] %s\n' "$*"; }
warn() { printf '[kit] %s\n' "$*" >&2; }
die() { printf '[kit] ERROR: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

confirm() {
  [ "$AUTO_INSTALL" -eq 1 ] && return 0
  [ -t 0 ] || return 1
  local answer
  read -r -p "[kit] $1 [y/N] " answer
  [[ "$answer" =~ ^[Yy] ]]
}

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:?--profile needs a value}"; shift 2 ;;
    --profile=*) PROFILE="${1#*=}"; shift ;;
    --dsh-home) DSH_HOME="${2:?--dsh-home needs a value}"; shift 2 ;;
    --dsh-home=*) DSH_HOME="${1#*=}"; shift ;;
    --claude-mem-version) CLAUDE_MEM_VERSION="${2:?}"; shift 2 ;;
    --claude-mem-version=*) CLAUDE_MEM_VERSION="${1#*=}"; shift ;;
    --observer-key) OBSERVER_KEY="${2:?}"; shift 2 ;;
    --observer-key=*) OBSERVER_KEY="${1#*=}"; shift ;;
    --skip-tuning) SKIP_TUNING=1; shift ;;
    --skip-bridge) SKIP_BRIDGE=1; shift ;;
    --auto-install) AUTO_INSTALL=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown argument: $1" ;;
  esac
done

case "$(uname -s)" in
  Linux) PLATFORM="linux" ;;
  Darwin) PLATFORM="macos" ;;
  *) die "this installer supports Linux and macOS; on Windows use scripts\\install.ps1" ;;
esac
info "platform: $PLATFORM"

step "Checking Node.js"
have node || die "Node.js 20+ was not found on PATH. Install it from https://nodejs.org and re-run."
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 20 ] || die "Node.js 20+ is required (found $(node --version))."
NODE_BIN="$(command -v node)"
info "node $(node --version)"

MARKETPLACE="$HOME/.claude/plugins/marketplaces/thedotmack"
BUNDLE_DIR="$MARKETPLACE/dsh"
PROFILE_DIR="$DSH_HOME/profiles/$PROFILE"

if [ "$DRY_RUN" -eq 1 ]; then
  step "Dry run — nothing will be changed"
  echo "  platform:    $PLATFORM"
  echo "  profile:     $PROFILE ($PROFILE_DIR)"
  echo "  claude-mem:  $BUNDLE_DIR"
  echo "  settings:    $HOME/.claude-mem/settings.json"
  if have pnpm; then
    echo "  pnpm:        $(pnpm --version)"
  else
    echo "  pnpm:        not found (would be installed through corepack / npm)"
  fi
  if [ -f "$BUNDLE_DIR/package.json" ]; then
    echo "  1. reuse the installed Claude-Mem worker and marketplace"
  else
    echo "  1. provision Claude-Mem $CLAUDE_MEM_VERSION (npx claude-mem install --ide dsh --dsh-profile dsh-mem-bootstrap)"
  fi
  echo "  2. link @claude-mem/dsh into profile '$PROFILE'"
  echo "  3. write ~/.claude-mem/transcript-watch.json (top-level DSH sessions only)"
  [ "$SKIP_TUNING" -eq 0 ] && echo "  4. apply the cost profile to settings.json (with a backup)"
  echo "  5. restart the Claude-Mem worker"
  [ "$SKIP_BRIDGE" -eq 0 ] && echo "  6. install and start the observer bridge for $PLATFORM"
  echo ""
  echo "  Then restart DeepSeek Harness."
  exit 0
fi


step "Checking pnpm"
if ! have pnpm; then
  info "pnpm not found; enabling it through corepack / npm"
  corepack enable 2>/dev/null || true
  have pnpm || npm install -g pnpm
  have pnpm || die "pnpm could not be installed. Run 'npm install -g pnpm' and re-run."
fi
have pnpm && info "pnpm $(pnpm --version)"

step "Locating Claude-Mem"
if [ ! -f "$BUNDLE_DIR/package.json" ]; then
  have npx || die "npx was not found on PATH."
  info "Claude-Mem is not installed yet; provisioning worker + marketplace (a few minutes)"
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would run: npx -y claude-mem@$CLAUDE_MEM_VERSION install --ide dsh --dsh-profile dsh-mem-bootstrap --provider openrouter --no-auto-start"
  else
    info "The official installer may report a failure for its own DSH step; the kit wires the profile itself."
    npx -y "claude-mem@$CLAUDE_MEM_VERSION" install --ide dsh --dsh-profile dsh-mem-bootstrap --provider openrouter --no-auto-start || true
    rm -rf "$DSH_HOME/profiles/dsh-mem-bootstrap"
  fi
  [ -f "$BUNDLE_DIR/package.json" ] || die "Claude-Mem marketplace is missing at $BUNDLE_DIR. Run 'npx -y claude-mem@$CLAUDE_MEM_VERSION install --ide dsh --dsh-profile web' manually, then re-run."
fi
info "bundle: $BUNDLE_DIR"

step "Wiring @claude-mem/dsh into profile '$PROFILE'"
if [ "$PROFILE" = "desktop" ]; then
  [ -f "$PROFILE_DIR/package.json" ] || die "profile 'desktop' is not initialized ($PROFILE_DIR). Open DeepSeek Harness once, then re-run."
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would run (in $PROFILE_DIR): pnpm add \"$BUNDLE_DIR\""
  else
    ( cd "$PROFILE_DIR" && pnpm add "$BUNDLE_DIR" )
  fi
elif have dsh; then
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would run: dsh plugin --profile $PROFILE add \"$BUNDLE_DIR\""
  else
    dsh plugin --profile "$PROFILE" add "$BUNDLE_DIR"
  fi
else
  warn "the dsh CLI is not on PATH; falling back to pnpm in an existing profile"
  [ -f "$PROFILE_DIR/package.json" ] || die "profile '$PROFILE' is not initialized and the dsh CLI is missing. Install it with 'npm install -g @deepseek-ai/dsh', run 'dsh --profile $PROFILE', then re-run."
  if [ "$DRY_RUN" -eq 1 ]; then
    info "would run (in $PROFILE_DIR): pnpm add \"$BUNDLE_DIR\""
  else
    ( cd "$PROFILE_DIR" && pnpm add "$BUNDLE_DIR" )
  fi
fi

WIRE_ARGS=(--profile-dir "$PROFILE_DIR" --bundle "$BUNDLE_DIR")
[ "$DRY_RUN" -eq 1 ] && WIRE_ARGS+=(--dry-run)
node "$LIB/wire-profile.mjs" "${WIRE_ARGS[@]}"

step "Configuring transcript capture"
mkdir -p "$HOME/.claude-mem"
WATCH_ARGS=(--example "$REPO_ROOT/config/transcript-watch.example.json" --package "$BUNDLE_DIR")
[ "$DRY_RUN" -eq 1 ] && WATCH_ARGS+=(--dry-run)
node "$LIB/write-watch.mjs" "${WATCH_ARGS[@]}"

if [ "$SKIP_TUNING" -eq 0 ]; then
  step "Applying the cost profile"
  SETTINGS="$HOME/.claude-mem/settings.json"
  if [ -z "$OBSERVER_KEY" ] && [ "$DRY_RUN" -eq 0 ] && [ -t 0 ]; then
    if [ ! -f "$SETTINGS" ] || ! node -e 'const s=require(process.argv[1]); if(!s.CLAUDE_MEM_OPENAI_COMPAT_API_KEY) process.exit(1)' "$SETTINGS" 2>/dev/null; then
      read -r -s -p "[kit] Observer API key (OpenCode Go), empty to skip: " OBSERVER_KEY || true
      echo
    fi
  fi
  TUNE_ARGS=(--example "$REPO_ROOT/config/settings.example.json")
  [ -n "$OBSERVER_KEY" ] && TUNE_ARGS+=(--key "$OBSERVER_KEY")
  [ "$DRY_RUN" -eq 1 ] && TUNE_ARGS+=(--dry-run)
  node "$LIB/apply-tuning.mjs" "${TUNE_ARGS[@]}"
fi

step "Starting the Claude-Mem worker"
WORKER="$MARKETPLACE/plugin/scripts/worker-service.cjs"
if [ ! -f "$WORKER" ]; then
  warn "worker script not found at $WORKER"
elif [ "$DRY_RUN" -eq 1 ]; then
  info "would run: bun \"$WORKER\" restart"
elif have bun; then
  bun "$WORKER" restart || warn "worker did not start; run manually: bun \"$WORKER\" restart"
else
  warn "Bun is not installed; the claude-mem worker runs on Bun"
  if confirm "Install Bun now with npm (npm i -g bun)?"; then
    npm install -g bun && bun "$WORKER" restart || warn "worker did not start; run manually: bun \"$WORKER\" restart"
  else
    warn "start the worker later with: bun \"$WORKER\" restart"
  fi
fi

if [ "$SKIP_BRIDGE" -eq 0 ]; then
  step "Installing the observer bridge"
  mkdir -p "$HOME/.claude-mem"

  if [ "$DRY_RUN" -eq 1 ]; then
    info "would register and start the bridge for $PLATFORM"
  else
    if [ "$PLATFORM" = "macos" ]; then
      PLIST="$HOME/Library/LaunchAgents/com.greenjenckens.dsh-claude-mem-bridge.plist"
      mkdir -p "$HOME/Library/LaunchAgents"
      cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.greenjenckens.dsh-claude-mem-bridge</string>
  <key>ProgramArguments</key>
  <array>
    <string>$NODE_BIN</string>
    <string>$REPO_ROOT/proxy/server.mjs</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$HOME/.claude-mem/proxy.log</string>
  <key>StandardErrorPath</key><string>$HOME/.claude-mem/proxy.log</string>
</dict>
</plist>
EOF
      launchctl unload "$PLIST" 2>/dev/null || true
      launchctl load "$PLIST"
      info "LaunchAgent: $PLIST"
    elif have systemctl && systemctl --user show-environment >/dev/null 2>&1; then
      UNIT_DIR="$HOME/.config/systemd/user"
      mkdir -p "$UNIT_DIR"
      cat > "$UNIT_DIR/dsh-claude-mem-bridge.service" <<EOF
[Unit]
Description=dsh-claude-mem observer bridge
After=network-online.target

[Service]
ExecStart=$NODE_BIN $REPO_ROOT/proxy/server.mjs
Restart=on-failure
RestartSec=3
StandardOutput=append:$HOME/.claude-mem/proxy.log
StandardError=append:$HOME/.claude-mem/proxy.log

[Install]
WantedBy=default.target
EOF
      systemctl --user daemon-reload
      systemctl --user enable --now dsh-claude-mem-bridge.service
      info "systemd user unit: $UNIT_DIR/dsh-claude-mem-bridge.service"
    else
      nohup "$NODE_BIN" "$REPO_ROOT/proxy/server.mjs" >> "$HOME/.claude-mem/proxy.log" 2>&1 &
      echo $! > "$HOME/.claude-mem/proxy.pid"
      AUTOSTART_DIR="$HOME/.config/autostart"
      mkdir -p "$AUTOSTART_DIR"
      cat > "$AUTOSTART_DIR/dsh-claude-mem-bridge.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=dsh-claude-mem observer bridge
Exec=$NODE_BIN $REPO_ROOT/proxy/server.mjs
X-GNOME-Autostart-enabled=true
EOF
      info "XDG autostart entry: $AUTOSTART_DIR/dsh-claude-mem-bridge.desktop"
    fi

    for _ in 1 2 3 4 5 6 7 8 9 10; do
      if curl -fsS http://127.0.0.1:37901/health >/dev/null 2>&1; then
        info "bridge: $(curl -fsS http://127.0.0.1:37901/health)"
        break
      fi
      sleep 1
    done
  fi
fi

step "Summary"
echo "  worker:   curl -s http://127.0.0.1:37777/api/health"
echo "  bridge:   curl -s http://127.0.0.1:37901/health"
echo "  settings: $HOME/.claude-mem/settings.json"
echo ""
if [ "$SKIP_TUNING" -eq 0 ] && [ -f "$HOME/.claude-mem/settings.json" ]; then
  if ! node -e 'const s=require(process.argv[1]); if(!s.CLAUDE_MEM_OPENAI_COMPAT_API_KEY) process.exit(1)' "$HOME/.claude-mem/settings.json" 2>/dev/null; then
    warn "The observer API key is not set yet. Add CLAUDE_MEM_OPENAI_COMPAT_API_KEY to the settings file above."
  fi
fi
echo "  Next: restart DeepSeek Harness (or start it with 'dsh $PROFILE'), then ask the agent to call mem_context."
