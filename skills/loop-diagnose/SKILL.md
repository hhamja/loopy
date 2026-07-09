---
name: loop-diagnose
description: Diagnose a target project's harness and loop-engineering architecture against the control plane; spawn the loop-architect agent and write a scored report with a maturity level to harness-diagnosis.md
argument-hint: [target-path]
disable-model-invocation: true
---

# loop-diagnose — harness architecture diagnosis

Diagnose a target project's agent/loop harness against the control plane (`${CLAUDE_PLUGIN_ROOT}/docs/loop-control-plane.md`) — ETCLOVG responsibility coverage plus a maturity level. Complementary to `/loop-harness:loop-audit` (which grades an already-initialized `.claude/loop/`'s process) and to `loop-run --verify-only` (which grades the product): this diagnoses whether the harness *architecture* exists at all, and works on any project, including one with no `.claude/loop/`.

Target path (`$ARGUMENTS`): the project to diagnose. Default to the current project (`.`) when no path is given.

1. Spawn the `loop-architect` agent with "diagnose the harness/loop structure at `<path>` against the control plane — ETCLOVG coverage and maturity level". It maps the target's CI, gates, subagents, hooks, and loop state, then returns one `## Harness diagnosis` report (per-responsibility PASS/PARTIAL/FAIL/UNKNOWN + `maturity: L<n>/5`) and a `## Priority fixes` list ordered by build order. It modifies nothing.
2. Print the report verbatim.
3. Apply it (the main agent does the write, mirroring how verifier/auditor reports are applied): OVERWRITE `<path>/harness-diagnosis.md` with the report and a one-line timestamp header. It is a human-facing artifact — commit it like `review.md`, not gitignored.
4. Suggest the next step: address the top Priority fix; or, if the target has no loop yet, run `/loop-harness:loop-init` there to scaffold one.

Do not fix anything here beyond writing `harness-diagnosis.md`; the fixes are for a human or a follow-up loop. Writing one report file into the target is a reversible/local (T0) action — never merge, push, or publish from this skill. Safe to run anytime, including as the first command in a fresh project.
