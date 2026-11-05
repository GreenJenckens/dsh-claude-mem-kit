<p align="center"><img src="docs/banner.svg" alt="dsh-claude-mem-kit — persistent memory for DeepSeek Harness (claude-mem integration)" width="100%"></p>

<p align="center">
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <a href="https://github.com/GreenJenckens/dsh-claude-mem-kit/releases"><img alt="release" src="https://img.shields.io/github/v/release/GreenJenckens/dsh-claude-mem-kit?color=4D6BFE"></a>
  <a href="https://github.com/GreenJenckens/dsh-claude-mem-kit/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/GreenJenckens/dsh-claude-mem-kit/actions/workflows/ci.yml/badge.svg"></a>
  <img alt="claude-mem 15.9" src="https://img.shields.io/badge/claude--mem-15.9.0-111111">
  <img alt="platforms" src="https://img.shields.io/badge/platforms-Windows%20%7C%20Linux%20%7C%20macOS-2ea44f">
  <img alt="observer spend" src="https://img.shields.io/badge/observer%20spend-~10%25-brightgreen">
  <a href="https://greenjenckens.github.io/dsh-claude-mem-kit/"><img alt="docs" src="https://img.shields.io/badge/docs-landing%20page-0b0f17"></a>
</p>

<h1 align="center">Persistent memory for DeepSeek Harness</h1>

<p align="center"><b>Cross-session memory for <a href="https://github.com/deepseek-ai">DeepSeek Harness (DSH)</a> agents, built on <a href="https://github.com/thedotmack/claude-mem">Claude-Mem</a> — native <code>mem_search</code> tools, automatic transcript capture, and roughly one tenth of the default observer cost. Works on Windows, Linux, and macOS.</b></p>

> **Unofficial.** A community installation and tuning kit for Claude-Mem inside
> DeepSeek Harness. Not affiliated with, sponsored by, or endorsed by the
> Claude-Mem project, DeepSeek, or the authors of the DSH adapter it installs.

---

## Contents

- [Why this exists](#why-this-exists) · [Features](#features) · [Platforms](#platform-support)
- [Install](#install) · [How it works](#how-it-works) · [Cost tuning](#cost-tuning)
- [Everyday use](#everyday-use) · [FAQ](#faq) · [Security](#security) · [Uninstall](#uninstall)
- [License and third-party notices](#license-and-third-party-notices)

## Why this exists

Coding agents forget everything between sessions. Claude-Mem fixes that by
compressing session transcripts into durable observations and exposing them as
tools (`mem_search`, `mem_timeline`, `mem_get_observations`, `mem_save`,
`mem_context`). Its DeepSeek Harness adapter (`@claude-mem/dsh`) is shipped
upstream, but the defaults are tuned for a different harness: every tool call
becomes its own observer request, subagent transcripts are captured too, and the
observer conversation grows until each call costs tens of thousands of tokens.

Measured on real DSH sessions, the default setup spends **≈10 900 input tokens
per captured tool event**, and **78 % of all stored observations came from
subagent sessions** whose results the parent session already contains. This kit
keeps the memory and removes the waste: **≈5 700 tokens per event, top-level
sessions only**, ending up at roughly **10 % of the original observer spend**.

## Features

- **Native DSH plugin, not an MCP bridge** — the upstream `@claude-mem/dsh`
  bundle registers `mem_*` tools and a `mem-search` skill directly in the agent.
- **Automatic capture** — the worker tails `~/.dsh/sessions/**/session-*/…` and
  turns them into observations; subagent sessions are skipped.
- **Context on start** — a compact block of recent observations is injected when
  an agent is created.
- **Cost profile** — batched observer requests, short generations, DSH meta-tools
  skipped, My Work wording disabled.
- **Works across profiles** — including the Electron-only `desktop` profile that
  the `dsh plugin` CLI refuses to edit, and CLI-managed `web` / `tui` profiles.
- **One-command installers** for Windows (PowerShell) and Linux/macOS (bash),
  with `--dry-run`, idempotent re-runs, and automatic cleanup/uninstall.

## Platform support

| Platform | Installer | Default profile | Bridge autostart |
|---|---|---|---|
| Windows 10/11 | [`scripts/install.ps1`](scripts/install.ps1) (PowerShell 5.1+) | `desktop` (DSH Desktop) | Startup shortcut |
| Linux | [`scripts/install.sh`](scripts/install.sh) (bash) | `web` (DSH CLI) | systemd user unit / XDG autostart |
| macOS | [`scripts/install.sh`](scripts/install.sh) (bash) | `web` (DSH CLI) | LaunchAgent |

The `desktop` profile exists wherever the DSH Electron app runs; `web` and `tui`
profiles are managed by the `dsh` CLI (`npm install -g @deepseek-ai/dsh`).
On Linux/macOS pass `--profile desktop` if you have the desktop app profile.

## Install

### Windows (one command)

```powershell
irm https://raw.githubusercontent.com/GreenJenckens/dsh-claude-mem-kit/main/scripts/bootstrap.ps1 | iex
```

### Linux / macOS (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/GreenJenckens/dsh-claude-mem-kit/main/scripts/bootstrap.sh | bash -s -- --profile web
```

Prefer to read before running? Download the bootstrap script first
([`bootstrap.ps1`](scripts/bootstrap.ps1) / [`bootstrap.sh`](scripts/bootstrap.sh)),
then run it.

### From a clone

```bash
git clone https://github.com/GreenJenckens/dsh-claude-mem-kit.git
cd dsh-claude-mem-kit

# Linux / macOS
bash scripts/install.sh --profile web

# Windows
powershell -ExecutionPolicy Bypass -File scripts\install.ps1
```

Common options:

| Option (bash / PowerShell) | Meaning |
|---|---|
| `--dry-run` / `-DryRun` | Print the plan, change nothing |
| `--profile <name>` / `-Profile` | DSH profile to wire (`web`, `tui`, `desktop`) |
| `--observer-key` / `-ObserverKey` | Observer API key, skips the prompt |
| `--skip-bridge` / `-SkipBridge` | You already have an OpenAI-compatible endpoint |
| `--auto-install` / `-AutoInstall` | Install missing pnpm/Bun without asking |

The installer is idempotent. It:

1. provisions Claude-Mem's worker and marketplace into
   `~/.claude/plugins/marketplaces/thedotmack` if they are missing;
2. links `@claude-mem/dsh` into the chosen profile and appends it to
   `dsh.profile.bundles`;
3. writes `~/.claude-mem/transcript-watch.json` with the DSH schema and the
   top-level-only watch;
4. merges the cost profile into `~/.claude-mem/settings.json` (backup kept);
5. starts the worker and the observer bridge, and registers the bridge's
   autostart (Startup shortcut / systemd user unit / LaunchAgent).

Then **restart DeepSeek Harness** once. New sessions show the `mem-search` skill
and the `mem_*` tools.

## How it works

```text
  DSH session
      │  writes
      ▼
  ~/.dsh/sessions/**/session-*/session.v4.jsonl.zstd
      │  transcript-watch.json (schema: dsh)
      ▼
  claude-mem worker  :37777  ──▶  SQLite + Chroma (local)
      │  observer requests (batched)
      ▼
  loopback bridge    :37901  ──▶  OpenCode Go / any OpenAI-compatible endpoint
      │
      ▼
  DSH plugin: context on agent/created + mem_* tools
```

- **Capture** is worker-side; the plugin does not double-write (`ingest` and
  `summarize` stay off in the bundle config).
- **Recall** is pull-based (`mem_search` → `mem_timeline` →
  `mem_get_observations`) plus a compact context block injected at agent start.
- **Nothing leaves the machine** except observer requests to the endpoint you
  configure. The worker binds to `127.0.0.1` without authentication.

More detail: [docs/architecture.md](docs/architecture.md).

## Cost tuning

| Knob | Default | This kit | Why |
|---|---|---|---|
| `CLAUDE_MEM_PROVIDER` | `claude` | `openai-compatible` | only this observer class implements batching |
| `…OPENAI_COMPAT_OBSERVATION_BATCH_SIZE` | `1` | `4` | up to four tool events per request |
| `…OBSERVER_MAX_CONVERSATION_CHARS` | `400000` | `40000` | shorter generations, smaller re-sent prefix |
| `…OBSERVER_MAX_OUTPUT_TOKENS` | `4096` | `3000` | enough for batched replies without truncation |
| `…SKIP_TOOLS` | 5 tools | 41 tools | DSH meta-tools carry no durable knowledge |
| transcript watch | all sessions | top-level only | 78 % of historical observations were subagent churn |
| `…CONTEXT_OBSERVATIONS` / `…SESSION_COUNT` | `50` / `10` | `15` / `3` | smaller startup context |
| `…WORK_VIEW_COPY_PROVIDER` | `openrouter` | `off` | My Work wording is presentation-only |
| `…TIER_ROUTING_ENABLED` | `true` | `false` | no accidental expensive model routing |

Measured from the worker log: **≈10 900 → ≈5 700 input tokens per event**, with
78 % fewer events to process. Method, trade-offs, and ways to go further:
[docs/cost-tuning.md](docs/cost-tuning.md).

## Everyday use

- Ask the agent "what did we do last time?" — the `mem-search` skill drives
  `mem_search` → `mem_timeline` → `mem_get_observations`.
- `mem_context` renders the same startup block on demand.
- `mem_save` stores a manual note.
- New sessions start with recent observations already injected.

## FAQ

**Do I need OpenCode Go?** No. Any OpenAI-compatible `/chat/completions`
endpoint works. On Windows pass `-SkipBridge`, on Linux/macOS `--skip-bridge`,
and set `CLAUDE_MEM_OPENAI_COMPAT_BASE_URL` / `…_MODEL` in
`~/.claude-mem/settings.json`.

**Does it phone home?** Only the observer requests go to the endpoint you
configure. The worker is loopback-only. The kit itself has no telemetry.

**Will it slow the agent down?** Capture runs in a detached worker. Observer
requests are batched and capped by `OBSERVER_MAX_CONVERSATION_CHARS`.

**Does it fight DSH's todo list?** No — `CLAUDE_MEM_WORK_STATE_ENABLED=false`, so
Claude-Mem does not advertise its own `work_state_write`.

**Where is my memory stored?** `~/.claude-mem` (SQLite + local Chroma vectors +
logs). Treat it as sensitive; it contains session content.

**How do I update?** Re-run the installer (it is idempotent); update the
`--claude-mem-version` to move to a newer Claude-Mem.

**Does it work with a remote worker?** The plugin supports `DSH_MEM_BASE_URL`,
but this kit targets a local worker and a local transcript watch.

**Why "dsh-claude-mem-kit" and not a plugin on npm?** The actual plugin is
upstream (`@claude-mem/dsh`); this repository wires it, tunes it, and keeps the
installation repeatable.

## Security

- The worker listens on `127.0.0.1` **without authentication** — never bind it to
  a LAN address and never port-forward it.
- Your observer API key lives in `~/.claude-mem/settings.json`; this repository
  ships only placeholders.
- Auto-redaction is enabled for recognised secret patterns; it is a safety net,
  not a guarantee.
- Do not copy `claude-mem.db` while the worker is running (SQLite WAL).

See [SECURITY.md](SECURITY.md).

## Uninstall

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File scripts\uninstall.ps1
```

```bash
# Linux / macOS
bash scripts/uninstall.sh --profile web
```

Add `-PurgeData` / `--purge-data` to move `~/.claude-mem` into a timestamped
backup folder instead of deleting it.

## License and third-party notices

- **This kit** (scripts, proxy, docs, configs): MIT — see [LICENSE](LICENSE).
- **Claude-Mem** is Apache-2.0, © 2026 Alex Newman. The DSH adapter it installs
  is derived from [Bleed00/dsh-claude-mem](https://github.com/Bleed00/dsh-claude-mem)
  (Apache-2.0). No Claude-Mem source is vendored here: the transcript schema is
  copied at install time from the installed package.
- See [NOTICE](NOTICE) and [third_party/](third_party/README.md). Claude-Mem,
  DeepSeek, and DeepSeek Harness are trademarks of their respective owners.

## Repository layout

```text
config/     example settings and transcript watch
docs/       architecture, cost tuning, troubleshooting, landing page
proxy/      loopback OpenAI-compatible bridge (OpenCode Go)
scripts/    install / bootstrap / uninstall (PowerShell + bash + Node helpers)
third_party/ notices for the upstream projects this kit installs
```

---

Русская версия: [README.ru.md](README.ru.md).
