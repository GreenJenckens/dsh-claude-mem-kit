# Architecture

```text
┌─────────────────────────────┐
│ DeepSeek Harness (profile)  │
│  plugin: @claude-mem/dsh    │
│   ├─ tools: mem_*           │
│   ├─ skill: mem-search      │
│   └─ context on agent/created
└──────────────┬──────────────┘
               │ HTTP (loopback)
               ▼
┌─────────────────────────────┐        ┌──────────────────────────────┐
│ claude-mem worker :37777    │◀──────▶│ ~/.claude-mem               │
│  ├─ transcript watcher      │        │  ├─ claude-mem.db (SQLite)   │
│  ├─ observer queue          │        │  ├─ chroma/ (vectors)        │
│  └─ REST + MCP search       │        │  ├─ settings.json            │
└──────────────┬──────────────┘        │  ├─ transcript-watch.json    │
               │ observer requests      │  └─ logs/                    │
               ▼                        └──────────────────────────────┘
┌─────────────────────────────┐
│ observer bridge :37901      │───────▶ OpenCode Go / OpenAI-compatible
└─────────────────────────────┘
```

## Components

| Component | Where | Owned by |
|---|---|---|
| DSH bundle `@claude-mem/dsh` | `~/.claude/plugins/marketplaces/thedotmack/dsh`, linked into the profile | Claude-Mem (Apache-2.0) |
| Worker | `…/thedotmack/plugin/scripts/worker-service.cjs` (Bun), port 37777 | Claude-Mem |
| Data directory | `~/.claude-mem` | you |
| Transcript watch | `~/.claude-mem/transcript-watch.json` | this kit writes it |
| Observer bridge | `proxy/server.mjs` (Node), port 37901 | this kit (MIT) |

## Capture path

1. DSH appends every event to
   `~/.dsh/sessions/<project>/<session>/session.v4.jsonl.zstd`.
2. The worker's transcript watcher tails only files matching
   `**/session-*/session.v4.jsonl.zstd` (top-level sessions; subagent sessions use
   bare UUID folders and are skipped).
3. Each line is mapped through the `dsh` schema (`session`, `user/message`,
   `assistant/message`, `tool/call`, `tool/result`, `turn/end`).
4. Tool events become observations; `turn/end` queues a session summary.
5. Observations are stored in SQLite and synced to the local Chroma store.

## Recall path

- **Pull**: the agent calls `mem_search` → `mem_timeline` → `mem_get_observations`
  (progressive disclosure keeps the token count small), or `mem_context` for the
  worker's rendered startup block.
- **Push**: on `agent/created` the plugin calls
  `/api/context/inject?cwd=<session cwd>` and injects a compact context block
  (15 observations across 3 sessions by default in this kit).

The plugin's own `ingest` and `summarize` switches stay `false`: the transcript
watcher is the single writer, so nothing is observed twice.

## Why a bridge

OpenCode Go rejects inference requests without an `x-opencode-session` routing
header. Claude-Mem's observer speaks plain OpenAI `/chat/completions` and cannot
set that header, so the kit runs a ~120-line loopback proxy that adds it and
streams the response back. The bridge holds no secrets: the `Authorization`
header from the client is forwarded verbatim.

If you use a different OpenAI-compatible endpoint, skip the bridge and point
`CLAUDE_MEM_OPENAI_COMPAT_BASE_URL` at it directly.

## Ports and processes

| Port | Process | Started by |
|---|---|---|
| 37777 | Claude-Mem worker (Bun, detached) | `install.ps1`, the DSH plugin on demand, `bun worker-service.cjs start` |
| 37901 | Observer bridge (Node) | autostart shortcut created by `install.ps1` |
