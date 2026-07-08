---
description: Run maker/checker cycles — implement via Codex CLI or Claude per loop.config.md, verifier grades — until the rubric passes; supports --once and --verify-only
argument-hint: "[--once | --verify-only]"
---

# loop-run — verified maker/checker cycles

Arguments (`$ARGUMENTS`): `--once` = exactly one cycle. `--verify-only` = grade once, report, write NOTHING (no marker, no state updates — strictly read-only; report only).

## Before anything

1. If `.claude/loop/` does not exist: tell the user to run `/loop-harness:loop-init` and stop.
2. Read, in order: `state.md` (entry point — resume from what it says is unresolved), `goal.md`, `rubric.md`, `loop.config.md`, and the `## Distilled rules` section of `memory.md` (consult step of the memory protocol).
3. **Implementer preflight** (skip for `--verify-only`): read `implementer:` from loop.config.md — a missing key means `claude`. If it is `codex`, run `codex --version` once via Bash. On failure, use claude for this entire run and record "codex unavailable, fell back to claude" in state.md at the next update and in memory.md per the protocol. Check once per run, never per cycle (`codex --version` succeeds on an installed-but-unauthenticated CLI — the per-cycle fallback in the Implement step covers that case).
4. If NOT `--verify-only`, record the run marker via Bash (single command):

   ```bash
   sid="${CLAUDE_CODE_SESSION_ID:-unknown}"; [ -n "$sid" ] || sid=unknown; printf 'session_id=%s\ntimestamp=%s\n' "$sid" "$(date +%s)" > .claude/loop/.run-marker
   ```

   `CLAUDE_CODE_SESSION_ID` is version-dependent; `unknown` is the accepted fallback (the Stop gate then fails open).

## --verify-only path

Spawn the `verifier` agent with the instruction "grade `.claude/loop/rubric.md`". Print its report verbatim plus a one-paragraph summary. Update no file, then stop.

## Cycle (repeat until a stop condition)

1. **Implement** — by the implementer chosen at preflight:
   - **claude** (or any fallback): pick the unresolved rubric criteria (from state.md), make the smallest change that could pass them. For codebase reconnaissance, prefer the `explorer` agent (cheap) over broad reading in main context.
   - **codex**: delegate to the Codex CLI. One FRESH `codex exec` per cycle — never `resume`; the prompt is rebuilt from disk each cycle (memory lives on disk, not in context).
     1. Write `.claude/loop/.codex-prompt` with: the goal (goal.md); each unresolved criterion verbatim with its verification command; the last verifier failure reasons; the `## Distilled rules` section of memory.md; then these fixed guardrails — "Do NOT modify anything under `.claude/loop/` — loop state belongs to the orchestrator. Do NOT run git commit or git push. Work only toward the listed criteria; make the smallest change that could pass them. End your reply with the list of files you changed."
     2. Run it as ONE Bash call with a generous timeout (10 min — Codex edits can take minutes; the default 2-min Bash timeout would kill it mid-edit). Splice a non-empty `codex_args:` from loop.config.md in before the `-`:

        ```bash
        codex exec --full-auto --skip-git-repo-check --output-last-message .claude/loop/.codex-last - < .claude/loop/.codex-prompt > .claude/loop/.codex-log 2>&1
        ```

     3. Read ONLY `.claude/loop/.codex-last`. NEVER read `.codex-log` — it is a human debugging artifact and would flood your context.
     4. If the command exits non-zero: retry the identical command once. If it fails again, implement this cycle yourself (claude path) and record "codex exec failed, fell back to claude (cycle N)" in state.md and memory.md. Codex stays the implementer for the next cycle (the preflight verdict stands).
2. **Phase gate — end of cycle only:** spawn the `verifier` agent once with "grade `.claude/loop/rubric.md`". Never invoke the verifier per file edit. The verifier only reports; it modifies nothing.
3. **Apply the report (main agent does ALL updates):**
   - `rubric.md`: set `[x]` on criteria the report passed, `[ ]` otherwise.
   - `state.md`: REWRITE as a summary — loop_active, iteration count, attempted / passed / unresolved (with consecutive-failure count per criterion), and the token figure from `.claude/loop/.last-usage` if present, explicitly labeled "estimate". Max 100 lines. Never append (exception: the single 'loop interrupted' line the stop gate may demand).
   - `memory.md`: for each failure, follow the 5-step protocol (fail → investigate → verify → distill) per `references/memory-protocol.md`; tag `[plugin]` or `[project]`.
   - `review.md`: OVERWRITE with the human review summary — files changed, key changes, risks. With codex, take the changed-file list from `.codex-last`, cross-checked with `git status --short` when the project is a git repo.

## Stop conditions

- **Success:** every rubric criterion passes → final state/review update, set `loop_active: false`, report done. Say explicitly: "done" is a claim — list what the human should verify by hand.
- **Safety rails (mandatory, never skip):**
  - iteration count would exceed `max_iterations` from loop.config.md → stop, record the reason in state.md.
  - the same criterion has failed 3 consecutive cycles → escalate with 2-3 concrete options (e.g. relax the criterion / change approach / needs human input). Interactive: ask the user. Headless: print the options, record the stall reason in state.md, end the turn.
  - An unbounded "repeat until pass" loop is forbidden.
- `--once`: stop after one full cycle regardless of outcome (state/memory/review still updated).

## Decision gates

Classify every side-effecting action by reversibility × impact before doing it (skill reference: `references/decision-gates.md`):

- **Reversible/local** (edits, tests, local commits, pushing a *work* branch, draft PR): act or delegate to the implementer/`explorer` immediately. Never pause to ask "shall I start?" or "proceed to the next step?" — re-confirming a reversible step is over-confirmation.
- **Irreversible or high-impact** (merge to a protected branch, release/publish, force-push, tag push, external send, cost, catastrophic delete): a human gate. `decision_gate.sh` blocks these mechanically inside a loop project. Stop, write the context to `review.md`, then — interactive: ask the user for approval; headless: record the pending T2 action in state.md and end the turn. Only on explicit human approval, write `.claude/loop/.gate-approved` (`action=<class>`, `session_id`, `ts=<epoch>`), retry the command, and remove the marker immediately. Never forge the marker to bypass the gate.

Token note: you cannot measure your own usage. `.last-usage` (written by the stop gate at turn end) covers the PREVIOUS run; report it as an estimate, never as a precise figure.
