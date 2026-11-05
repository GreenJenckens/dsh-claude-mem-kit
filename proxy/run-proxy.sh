#!/usr/bin/env bash
# dsh-claude-mem-kit — start the observer bridge in the foreground.
# MIT License, Copyright (c) 2026 GreenJenckens.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$HOME/.claude-mem/proxy.log"
mkdir -p "$HOME/.claude-mem"

command -v node >/dev/null 2>&1 || { echo "[kit] Node.js 20+ is required" >&2; exit 1; }

# Optional overrides:
#   OC_PROXY_PORT=37901 OC_PROXY_UPSTREAM=https://opencode.ai OC_PROXY_MODEL=deepseek-v4.1-flash
exec node "$DIR/server.mjs" >> "$LOG" 2>&1
