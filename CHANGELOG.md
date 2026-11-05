# Changelog

## 1.0.1 — 2026-11-05

- One-command install: `scripts/bootstrap.ps1` downloads the kit into
  `%LOCALAPPDATA%\dsh-claude-mem-kit` and runs the installer.
- `install.ps1` now checks Node 20+, installs pnpm through corepack/npm when it is
  missing, offers to install Bun when it is missing, and asks for the observer API
  key with a masked prompt.
- Clearer bootstrap message: the official installer can report a failure for its
  own DSH wiring step; the kit wires the profile itself right after it.
- New `-AutoInstall` and `-DryRun` switches.

## 1.0.0 — 2026-11-05

- Initial public kit.
- Windows installer that wires `@claude-mem/dsh` into a DSH profile, including
  the Electron-managed `desktop` profile.
- Transcript capture for DeepSeek Harness sessions with the top-level-only watch
  (`**/session-*/session.v4.jsonl.zstd`); subagent sessions are skipped.
- Cost profile: OpenAI-compatible observer with batch=4, 40 000-char observer
  generations, 41 skipped DSH meta-tools, 15/3 startup context, no My Work LLM
  wording, tier routing off. Measured ≈10 % of the default observer spend.
- Loopback observer bridge for OpenCode Go (`x-opencode-session` header), with
  autostart shortcut.
- Idempotent tuning and uninstall scripts; backups of every edited file.
