# loop-run preflight

Run once before the first cycle. Skip entirely for `--verify-only`.

## Implementer

Read `implementer:` from loop.config.md (a missing key means `claude`). If it is `codex`, run `codex --version` once via Bash. On failure, use claude for the entire run and record "codex unavailable, fell back to claude" in state.md and memory.md. Check once per run, never per cycle — `codex --version` succeeds on an installed-but-unauthenticated CLI, and the per-cycle fallback in `codex-exec.md` covers that.

## Run marker

Write the marker so the Stop gate can tell an interrupted run from a finished one (one Bash command):

```bash
sid="${CLAUDE_CODE_SESSION_ID:-unknown}"; [ -n "$sid" ] || sid=unknown; printf 'session_id=%s\ntimestamp=%s\n' "$sid" "$(date +%s)" > .claude/loop/.run-marker
```

`CLAUDE_CODE_SESSION_ID` is version-dependent; `unknown` is the accepted fallback (the Stop gate then fails open).
