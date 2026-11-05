# Troubleshooting

Logs: `~/.claude-mem/logs/claude-mem-<date>.log`

> On Linux/macOS every `powershell`/`curl.exe` snippet below has a direct
> equivalent: `curl`, `~/.claude-mem/...`, and the installer scripts
> `scripts/install.sh` / `scripts/uninstall.sh`. The worker restart command is
> the same on all platforms:
> `bun "$HOME/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs" restart`.

## The plugin does not appear in DeepSeek Harness

1. Check the profile manifest: `~/.dsh/profiles/<profile>/package.json` must contain
   `"@claude-mem/dsh"` in both `dependencies` and `dsh.profile.bundles`.
2. Restart DeepSeek Harness — the plugin mounts at boot.
3. The `desktop` profile cannot be edited with `dsh plugin --profile desktop …`
   ("managed exclusively by the Electron application"). `install.ps1` writes the
   manifest directly (with a `package.json.bak` backup) and runs `pnpm add` in the
   profile directory.

## Worker is not running

```powershell
curl.exe -s http://127.0.0.1:37777/api/health
bun "$env:USERPROFILE\.claude\plugins\marketplaces\thedotmack\plugin\scripts\worker-service.cjs" restart
```

If the file is missing, Claude-Mem is not installed: run
`npx -y claude-mem@15.9.0 install --ide dsh --dsh-profile web` once (it provisions
the worker and marketplace), then re-run `install.ps1`.

## Observer requests fail

- `401` / `invalid api key`: set `CLAUDE_MEM_OPENAI_COMPAT_API_KEY` in
  `~/.claude-mem/settings.json` or pass `-ObserverKey` to `install.ps1`.
- Connection refused on :37901: start the bridge (`proxy\run-proxy.cmd`) or point
  `CLAUDE_MEM_OPENAI_COMPAT_BASE_URL` at another endpoint.
- Timeouts: the bridge and the upstream tolerate long streams; check
  `~/.claude-mem/proxy.log`.

## No observations are stored

- `CLAUDE_MEM_TRANSCRIPTS_ENABLED` must be `true` and
  `CLAUDE_MEM_TRANSCRIPTS_CONFIG_PATH` must point at the watch file.
- The watch path must match real files:
  `~/.dsh/sessions/**/session-*/session.v4.jsonl.zstd`. If your DSH writes a
  different name, adapt `transcript-watch.json`.
- `CLAUDE_MEM_OBSERVER_ENABLED` must be `true`.
- Session files are zstd-compressed; the worker needs Node/Bun with
  `zlib.zstdDecompressSync` (bundled Bun is fine).

## Batching does not happen

Batching exists only for `CLAUDE_MEM_PROVIDER=openai-compatible`. With
`openrouter`, each event is its own request no matter what the batch setting says.

## `summarize` returns `{"status":"skipped","reason":"unknown_session"}`

The worker looks sessions up by `(content_session_id, platform_source)`. The
`platform_source` is the transcript watch name, so a watch must be named `dsh`
(not `dsh-sessions`) for summaries and filters to line up.

## Replies are cut off

`reply was cut off at the output-token limit` in the log means
`CLAUDE_MEM_OBSERVER_MAX_OUTPUT_TOKENS` is too low for the current batch size.
Raise it (3000 is a safe value for `BATCH=4`).

## Restoring a database backup

SQLite runs in WAL mode. Never replace `claude-mem.db` while the worker is
running:

```powershell
bun "$env:USERPROFILE\.claude\plugins\marketplaces\thedotmack\plugin\scripts\worker-service.cjs" stop
Remove-Item "$env:USERPROFILE\.claude-mem\claude-mem.db*" -Force
Copy-Item ".\backup.db" "$env:USERPROFILE\.claude-mem\claude-mem.db"
bun "$env:USERPROFILE\.claude\plugins\marketplaces\thedotmack\plugin\scripts\worker-service.cjs" start
```

Then verify: open the DB read-only and check `PRAGMA integrity_check`, the
observation count and `max(id)` — before trusting it.

## Uninstall

`scripts\uninstall.ps1` removes the DSH wiring, the autostart shortcut and stops
both processes; `-PurgeData` also moves `~/.claude-mem` to a timestamped backup
folder instead of deleting it.
