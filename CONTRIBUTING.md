# Contributing

Thanks for helping. This kit is deliberately small: shell/PowerShell installers, a
Node proxy, a few Node helpers, and documentation. No build step, no dependencies
to install for development.

## Ground rules

- **Never commit secrets or personal data.** No API keys, no `settings.json`, no
  `~/.claude-mem` contents, no machine-specific paths (`C:\Users\...`, `/home/...`).
  The CI workflow scans for common secret patterns.
- **Keep it portable.** Anything in `scripts/lib/` and `proxy/` runs on Windows,
  Linux, and macOS — use `node:os`/`node:path`, never hard-coded separators.
- **ASCII in PowerShell output.** Windows PowerShell 5.1 reads `.ps1` as ANSI;
  em dashes and arrows become mojibake. Use `-`, `->`.
- **Bash:** `set -euo pipefail`, quote expansions, no GNU-only flags on macOS
  (`sed -i`, `readlink -f`, `stat -c` are out).

## Test locally

```bash
# Linux / macOS
bash -n scripts/install.sh scripts/uninstall.sh scripts/bootstrap.sh proxy/run-proxy.sh
bash scripts/install.sh --dry-run --profile web
```

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File scripts\install.ps1 -DryRun -Profile web
```

`--dry-run` prints the plan and changes nothing, so it is safe on any machine.
The CI matrix runs the same checks on Ubuntu, macOS, and Windows.

## What to change where

| Change | Files |
|---|---|
| Install/uninstall logic | `scripts/install.*`, `scripts/uninstall.*`, `scripts/lib/*` |
| Default cost profile | `config/settings.example.json` (+ `docs/cost-tuning.md`) |
| Transcript watch / capture scope | `config/transcript-watch.example.json` |
| Observer bridge | `proxy/server.mjs`, `proxy/README.md` |
| Docs / landing page | `README*.md`, `docs/*.md`, `docs/index.html` |

## Pull requests

- One logical change per PR; describe the user-visible effect.
- Update `CHANGELOG.md` for behaviour changes.
- Mention which OS and profile you tested (`desktop`, `web`, `tui`).
- If you change cost defaults, include a before/after measurement from
  `~/.claude-mem/logs` (see `docs/cost-tuning.md` for the method).

## Commit messages

`feat:`, `fix:`, `docs:`, `chore:` — short imperative subject, optional body.

## License

By contributing you agree that your contribution is licensed under the MIT
License of this repository. Upstream Claude-Mem code stays Apache-2.0; do not
copy it into this repository.
