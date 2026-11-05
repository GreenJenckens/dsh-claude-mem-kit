# Cost tuning

The observer is the only part of Claude-Mem that calls an LLM. Its cost is
roughly:

```
total ≈ Σ over captures( conversation_prefix + batch_payload + reply )
```

Two multipliers dominate:

1. **How many captures happen.** Every tool call in every watched transcript is a
   capture; subagent sessions multiply this.
2. **How big the re-sent prefix is.** Each observer request replays its whole
   conversation, so cost grows with the generation length and with the number of
   calls.

Everything below attacks one of those two.

## Knobs

| Setting | Upstream default | Kit | Effect | Trade-off |
|---|---|---|---|---|
| `CLAUDE_MEM_PROVIDER` | `claude` | `openai-compatible` | Only the OpenAI-compatible observer class implements batching. The OpenRouter class does not. | needs an OpenAI-compatible endpoint |
| `CLAUDE_MEM_OPENAI_COMPAT_OBSERVATION_BATCH_SIZE` | `1` | `4` | Up to 4 queued tool events per request; the shared prefix is paid once instead of 4 times | a failed request loses the batch; observations from one batch list the files of all events |
| `CLAUDE_MEM_OBSERVER_MAX_CONVERSATION_CHARS` | `400000` | `40000` | At ~4 chars/token this caps a generation at ~10k tokens; when full, the worker re-briefs (~550 tokens) instead of replaying 15–30k tokens every call | observer forgets the distant part of the conversation |
| `CLAUDE_MEM_OBSERVER_MAX_OUTPUT_TOKENS` | `4096` | `3000` | Enough for a batched reply with several observations | **do not go much lower** — replies get cut and observation tails are lost |
| `CLAUDE_MEM_SKIP_TOOLS` | 5 tools | 41 tools | DSH meta-tools (`todo_write`, `job_*`, `team_task_*`, `schedule_*`, `terminal_*`, `computer`, `skill`, …) produce no durable memory | those calls are not observable later |
| transcript watch path | all transcripts | `**/session-*/**` | subagent sessions make up ~78 % of captured events; their outcome is already in the parent session | subagent internals are not searchable |
| `CLAUDE_MEM_CONTEXT_OBSERVATIONS` / `…_SESSION_COUNT` | `50` / `10` | `15` / `3` | smaller block injected into every agent | less historical context |
| `CLAUDE_MEM_CONTEXT_SHOW_LAST_SUMMARY` | `true` | `false` | the previous summary is already represented by recent observations | slightly less continuity |
| `CLAUDE_MEM_WORK_VIEW_COPY_PROVIDER` | empty (`openrouter`) | `off` | "My Work" wording is presentation only and bills the same endpoint | plain card wording |
| `CLAUDE_MEM_WORK_VIEW_AUTO_REFRESH` | `true` | `false` | no background refresh work | My Work does not update automatically |
| `CLAUDE_MEM_TIER_ROUTING_ENABLED` | `true` | `false` | no accidental routing to tier models | none for a single model |

Kept on purpose: `CLAUDE_MEM_DEDUP_ENABLED=true` (no duplicate observations),
`CLAUDE_MEM_REDACT_ENABLED=true` (secrets are redacted before storage),
`CLAUDE_MEM_WORK_STATE_ENABLED=false` (DSH owns the to-do list),
`CLAUDE_MEM_SEMANTIC_INJECT=false` (no per-prompt retrieval request).

## Measured result

From `~/.claude-mem/logs/claude-mem-<date>.log`, counting `API usage` lines,
`ENQUEUED` events and `STORED obsCount`:

| Metric | Before | After |
|---|---|---|
| Observer input tokens per event | ≈10 900 | ≈5 700 |
| Events processed | 100 % (186 transcripts watched) | ≈22 % (91 top-level transcripts) |
| Estimated total spend | 100 % | **≈10–12 %** |

Historical distribution used for the estimate: 7 696 of 9 824 observations came
from subagent sessions, 2 128 from top-level sessions.

## Re-measuring

```powershell
$log = Get-Content "$env:USERPROFILE\.claude-mem\logs\claude-mem-$(Get-Date -Format yyyy-MM-dd).log"
$calls   = ($log | Select-String 'API usage').Count
$events  = ($log | Select-String 'ENQUEUED \|').Count
$obs     = ($log | Select-String 'STORED \|' | ForEach-Object { [int]([regex]::Match($_, 'obsCount=(\d+)').Groups[1].Value) } | Measure-Object -Sum).Sum
$inTok   = ($log | Select-String 'inputTokens=(\d+)' | ForEach-Object { [int]$_.Matches[0].Groups[1].Value } | Measure-Object -Sum).Sum
"calls=$calls events=$events obs=$obs input=$inTok input/event=$([math]::Round($inTok / $events))"
```

## Going further (and when not to)

- `BATCH=6..8` — fewer requests, larger payloads. Fine for terminal-heavy work;
  watch for `obsCount=0` replies, which mean the batch was too large for the
  model's attention.
- `OBSERVER_MAX_CONVERSATION_CHARS=30000` — cheaper still, but the observer starts
  losing earlier context within a turn.
- `CLAUDE_MEM_OBSERVER_ENABLED=false` — stops new observations and summaries
  entirely. Search and existing memory keep working; session summaries (`S…`
  rows) also stop being produced. Use it for a "recall-only" setup.
- Do **not** lower `OBSERVER_MAX_OUTPUT_TOKENS` below ~2500 with `BATCH=4`: the
  parser stores complete blocks only and silently drops the unfinished tail.

## Quality guards

After changing the profile, confirm:

1. `mem_context` returns recent sessions and observations.
2. The log shows `STORED obsCount=N` lines with `N > 0` for normal work.
3. No `reply was cut off at the output-token limit` errors.
4. Summaries still appear: `STORED … hasSummary=true` once per turn.
