# Security

## Reporting

Open a private security advisory on this repository, or contact the maintainer
through the GitHub profile. Please do not open a public issue for a concrete
vulnerability.

## What this kit runs locally

- **Claude-Mem worker** — a detached Bun process listening on
  `127.0.0.1:37777`. It exposes an unauthenticated HTTP API on loopback,
  including settings (with your observer API key) and delete endpoints. Never
  bind it to a LAN address (`CLAUDE_MEM_WORKER_HOST`) and never port-forward it.
- **Observer bridge** — a Node process on `127.0.0.1:37901` that forwards
  requests to OpenCode Go. It holds no credentials and only forwards the
  `Authorization` header it receives.

## Secrets

- The observer API key lives in `~/.claude-mem/settings.json`. This repository
  ships only `config/settings.example.json` with a placeholder.
- `CLAUDE_MEM_REDACT_ENABLED=true` is part of the cost profile: recognised secret
  patterns are redacted before storage. It is a safety net, not a guarantee.
- `CLAUDE_MEM_REDACT_GENERIC_ENABLED` stays `false` by default; enable it if you
  routinely paste credentials of unrecognised formats.

## Data sensitivity

`~/.claude-mem` contains full session content compressed into observations,
including command output and file fragments. Treat it like shell history:

- it is not encrypted at rest;
- do not commit it, upload it to issue trackers, or share `claude-mem.db`;
- `scripts/uninstall.ps1 -PurgeData` moves it to a timestamped backup folder
  rather than deleting it.

## Supply chain

`scripts/install.ps1` may run `npx -y claude-mem@15.9.0 install`, which downloads
and executes the upstream package. Pin the version you trust, review
`npm view claude-mem@15.9.0`, and prefer the official installer on a machine
where you can inspect it first.

## Scope

This kit is a configuration and installation layer. Vulnerabilities in the
memory engine, worker API, or the DSH adapter belong to the upstream project
(https://github.com/thedotmack/claude-mem).
