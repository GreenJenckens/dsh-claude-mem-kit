#!/usr/bin/env bash
# dsh-claude-mem-kit — one-command bootstrap for Linux and macOS.
#
# Downloads the kit from GitHub into ~/.local/share/dsh-claude-mem-kit and runs
# scripts/install.sh with the arguments you pass through.
#
# MIT License, Copyright (c) 2026 GreenJenckens.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/GreenJenckens/dsh-claude-mem-kit/main/scripts/bootstrap.sh | bash -s -- --profile web
#   curl -fsSL .../scripts/bootstrap.sh -o bootstrap.sh && bash bootstrap.sh --dry-run
set -euo pipefail

REF="${REF:-main}"
DEST="${DEST:-$HOME/.local/share/dsh-claude-mem-kit}"
URL="https://codeload.github.com/GreenJenckens/dsh-claude-mem-kit/tar.gz/refs/heads/$REF"

[ -n "$DEST" ] && [ "$DEST" != "/" ] || { echo "[bootstrap] refusing to use DEST=$DEST" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[bootstrap] downloading $URL"
curl -fsSL "$URL" -o "$TMP/kit.tar.gz"

mkdir -p "$DEST"
find "$DEST" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
tar -xzf "$TMP/kit.tar.gz" -C "$DEST" --strip-components=1

echo "[bootstrap] running $DEST/scripts/install.sh"
exec bash "$DEST/scripts/install.sh" "$@"
