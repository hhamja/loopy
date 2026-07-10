---
name: loop-status
description: Summarize loop state, rubric progress, and the last run token estimate from .claude/loop/
---

# loop-status — read-only summary

If `.claude/loop/` does not exist: say so and point to `/loopy:loop-init`. Otherwise read `state.md`, `rubric.md`, `loop.config.md`, and `.claude/loop/.last-usage` (if present), then print:

- `loop_active` and iteration count (from state.md) vs `max_iterations` (from loop.config.md)
- Rubric progress: `<passed>/<total>` plus the list of unresolved criteria
- Attempted / unresolved summary from state.md (including any consecutive-failure counts)
- Implementer (`implementer` from loop.config.md), plus any codex-fallback note found in state.md
- Last run token figure, explicitly labeled as an estimate
- Suggested next step: resume with `/loopy:loop-run`, or grade only with `/loopy:loop-run --verify-only`

Modify nothing. This command is always safe to run, including as the first command of a fresh session resuming a dead loop.
