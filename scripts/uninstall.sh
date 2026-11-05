#!/usr/bin/env bash
# dsh-claude-mem-kit — uninstall for Linux and macOS.
#
# MIT License, Copyright (c) 2026 GreenJenckens.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$REPO_ROOT/scripts/lib"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
PROFILE="web"
PURGE=0
DRY_RUN=0

info() { printf '[kit] %s\n' "$*"; }
step() { printf '\n[kit] %s\n' "$*"; }
warn() { printf '[kit] %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:?}"; shift 2 ;;
    --profile=*) PROFILE="${1#*=}"; shift ;;
    --dsh-home) DSH_HOME="${2:?}"; shift 2 ;;
    --dsh-home=*) DSH_HOME="${1#*=}"; shift ;;
    --purge-data) PURGE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: scripts/uninstall.sh [options]
  --profile <name>   DSH profile to unwire (default: web)
  --dsh-home <dir>   DSH home (default: ~/.dsh)
  --purge-data       Move ~/.claude-mem to a timestamped backup folder
  --dry-run          Print what would happen
EOF
      exit 0 ;;
    *) warn "unknown argument: $1"; exit 2 ;;
  esac
done

MARKETPLACE="$HOME/.claude/plugins/marketplaces/thedotmack"
WORKER="$MARKETPLACE/plugin/scripts/worker-service.cjs"
PROFILE_DIR="$DSH_HOME/profiles/$PROFILE"

step "Stopping the worker"
if [ -f "$WORKER" ] && have bun; then
  if [ "$DRY_RUN" -eq 1 ]; then info "would run: bun \"$WORKER\" stop"; else bun "$WORKER" stop || true; fi
fi

step "Removing the observer bridge"
if [ "$DRY_RUN" -eq 1 ]; then
  info "would stop the bridge and remove its autostart entry"
else
  PLIST="$HOME/Library/LaunchAgents/com.greenjenckens.dsh-claude-mem-bridge.plist"
  UNIT="$HOME/.config/systemd/user/dsh-claude-mem-bridge.service"
  DESKTOP_ENTRY="$HOME/.config/autostart/dsh-claude-mem-bridge.desktop"
  if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    info "removed $PLIST"
  fi
  if [ -f "$UNIT" ] && have systemctl; then
    systemctl --user disable --now dsh-claude-mem-bridge.service 2>/dev/null || true
    rm -f "$UNIT"
    systemctl --user daemon-reload 2>/dev/null || true
    info "removed $UNIT"
  fi
  if [ -f "$DESKTOP_ENTRY" ]; then rm -f "$DESKTOP_ENTRY"; info "removed $DESKTOP_ENTRY"; fi
  if [ -f "$HOME/.claude-mem/proxy.pid" ]; then
    PID="$(cat "$HOME/.claude-mem/proxy.pid")"
    if kill -0 "$PID" 2>/dev/null; then kill "$PID" 2>/dev/null || true; fi
    rm -f "$HOME/.claude-mem/proxy.pid"
  fi
fi

step "Unwiring @claude-mem/dsh from profile '$PROFILE'"
if [ -f "$PROFILE_DIR/package.json" ]; then
  WIRE_ARGS=(--profile-dir "$PROFILE_DIR" --remove)
  [ "$DRY_RUN" -eq 1 ] && WIRE_ARGS+=(--dry-run)
  node "$LIB/wire-profile.mjs" "${WIRE_ARGS[@]}"
  if [ "$DRY_RUN" -eq 0 ] && have pnpm; then ( cd "$PROFILE_DIR" && pnpm install >/dev/null 2>&1 || true ); fi
else
  warn "profile not found: $PROFILE_DIR"
fi

if [ "$PURGE" -eq 1 ]; then
  step "Moving the memory database aside"
  BACKUP="$HOME/.claude-mem-backup-$(date +%Y%m%d-%H%M%S)"
  if [ -d "$HOME/.claude-mem" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then info "would move ~/.claude-mem -> $BACKUP"; else mv "$HOME/.claude-mem" "$BACKUP"; info "moved to $BACKUP"; fi
  fi
fi

step "Done"
echo "  Restart DeepSeek Harness to unload the plugin."
[ "$PURGE" -eq 1 ] || echo "  Memory data was kept in ~/.claude-mem"
