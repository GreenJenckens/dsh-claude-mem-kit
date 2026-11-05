# Observer bridge

A ~120-line loopback proxy that speaks OpenAI `/chat/completions` and forwards to
**OpenCode Go**, adding the `x-opencode-session` header the upstream requires.

```text
claude-mem observer ──▶ http://127.0.0.1:37901/v1 ──▶ https://opencode.ai/inference/go/openai/v1
```

## Run

Windows:

```powershell
.\run-proxy.cmd           # foreground, logs to %USERPROFILE%\.claude-mem\proxy.log
wscript start-hidden.vbs  # no console window
```

Linux / macOS:

```bash
./run-proxy.sh            # foreground, logs to ~/.claude-mem/proxy.log
nohup ./run-proxy.sh &    # or let install.sh register a systemd unit / LaunchAgent
```

Autostart is registered by the installer: a Startup shortcut on Windows, a
systemd user unit (or an XDG autostart entry) on Linux, a LaunchAgent on macOS.
Skip the bridge entirely if you point `CLAUDE_MEM_OPENAI_COMPAT_BASE_URL` at any
other OpenAI-compatible endpoint.

## Environment

| Variable | Default | Meaning |
|---|---|---|
| `OC_PROXY_PORT` | `37901` | listen port |
| `OC_PROXY_UPSTREAM` | `https://opencode.ai` | upstream origin |
| `OC_PROXY_SESSION` | random | value of `x-opencode-session` |
| `OC_PROXY_MODEL` | `deepseek-v4.1-flash` | model id reported by `/v1/models` |

## Health

```powershell
curl.exe -s http://127.0.0.1:37901/health
```

The bridge holds no credentials: it forwards the client's `Authorization` header
verbatim, so the API key stays in `~/.claude-mem/settings.json`.
