# Changelog

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
