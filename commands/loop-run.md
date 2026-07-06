---
description: Run implement-verify cycles until the rubric passes or a safety rail triggers; supports --once and --verify-only
argument-hint: "[--once | --verify-only]"
---

# loop-run — verified implement/grade cycles

Arguments (`$ARGUMENTS`): `--once` = exactly one cycle. `--verify-only` = grade once, report, write NOTHING (no marker, no state updates — strictly read-only; report only).

## Before anything

1. If `.claude/loop/` does not exist: tell the user to run `/loop-harness:loop-init` and stop.
2. Read, in order: `state.md` (entry point — resume from what it says is unresolved), `goal.md`, `rubric.md`, `loop.config.md`, and the `## Distilled rules` section of `memory.md` (consult step of the memory protocol).
3. If NOT `--verify-only`, record the run marker via Bash (single command):

   ```bash
   sid="${CLAUDE_CODE_SESSION_ID:-unknown}"; [ -n "$sid" ] || sid=unknown; printf 'session_id=%s\ntimestamp=%s\n' "$sid" "$(date +%s)" > .claude/loop/.run-marker
   ```

   `CLAUDE_CODE_SESSION_ID` is version-dependent; `unknown` is the accepted fallback (the Stop gate then fails open).

## --verify-only path

Spawn the `verifier` agent with the instruction "grade `.claude/loop/rubric.md`". Print its report verbatim plus a one-paragraph summary. Update no file, then stop.

## Cycle (repeat until a stop condition)

1. **Implement:** pick the unresolved rubric criteria (from state.md), make the smallest change that could pass them. For codebase reconnaissance, prefer the `explorer` agent (cheap) over broad reading in main context.
2. **Phase gate — end of cycle only:** spawn the `verifier` agent once with "grade `.claude/loop/rubric.md`". Never invoke the verifier per file edit. The verifier only reports; it modifies nothing.
3. **Apply the report (main agent does ALL updates):**
   - `rubric.md`: set `[x]` on criteria the report passed, `[ ]` otherwise.
   - `state.md`: REWRITE as a summary — loop_active, iteration count, attempted / passed / unresolved (with consecutive-failure count per criterion), and the token figure from `.claude/loop/.last-usage` if present, explicitly labeled "estimate". Max 100 lines. Never append (exception: the single 'loop interrupted' line the stop gate may demand).
   - `memory.md`: for each failure, follow the 5-step protocol (fail → investigate → verify → distill) per `references/memory-protocol.md`; tag `[plugin]` or `[project]`.
   - `review.md`: OVERWRITE with the human review summary — files changed, key changes, risks.

## Stop conditions

- **Success:** every rubric criterion passes → final state/review update, set `loop_active: false`, report done. Say explicitly: "done" is a claim — list what the human should verify by hand.
- **Safety rails (mandatory, never skip):**
  - iteration count would exceed `max_iterations` from loop.config.md → stop, record the reason in state.md.
  - the same criterion has failed 3 consecutive cycles → escalate with 2-3 concrete options (e.g. relax the criterion / change approach / needs human input). Interactive: ask the user. Headless: print the options, record the stall reason in state.md, end the turn.
  - An unbounded "repeat until pass" loop is forbidden.
- `--once`: stop after one full cycle regardless of outcome (state/memory/review still updated).

Token note: you cannot measure your own usage. `.last-usage` (written by the stop gate at turn end) covers the PREVIOUS run; report it as an estimate, never as a precise figure.
