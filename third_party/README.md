# Third-party notices

This repository does **not** vendor Claude-Mem source code. It installs the
upstream package and, at install time, copies the DSH transcript schema from the
installed `@claude-mem/dsh` package into the local `transcript-watch.json`.

| Project | License | What this kit uses |
|---|---|---|
| [Claude-Mem](https://github.com/thedotmack/claude-mem) — © 2026 Alex Newman | Apache-2.0 | worker, CLI, `@claude-mem/dsh` bundle |
| [Bleed00/dsh-claude-mem](https://github.com/Bleed00/dsh-claude-mem) — © 2026 Bleed00 | Apache-2.0 | upstream of the DSH adapter (via Claude-Mem) |
| [DeepSeek Harness](https://github.com/deepseek-ai) | proprietary application | host runtime, plugin API |

The upstream Claude-Mem `NOTICE` is reproduced in
[claude-mem/NOTICE.txt](claude-mem/NOTICE.txt). Its full license ships with the
installed package at:

- `~/.claude/plugins/marketplaces/thedotmack/LICENSE`
- `~/.claude/plugins/marketplaces/thedotmack/NOTICE`
- `~/.claude/plugins/marketplaces/thedotmack/dsh/LICENSE`
- `~/.claude/plugins/marketplaces/thedotmack/dsh/NOTICE`
- `~/.claude/plugins/marketplaces/thedotmack/dsh/THIRD-PARTY-LICENSES.txt`

Apache-2.0 permits redistribution and modification, including commercially,
provided you keep the license and NOTICE files, state your changes, and do not
use the project's marks to imply endorsement. Apache-2.0 does not grant
trademark rights.

If you fork this kit and bundle Claude-Mem code into it, copy the files above
into your fork and record what you changed.

Codes and documentation in this repository are MIT-licensed — see
[../LICENSE](../LICENSE) and [../NOTICE](../NOTICE).
