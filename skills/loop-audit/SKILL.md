---
name: loop-audit
description: Audit the loop against loop-engineering principles and decision-gate adherence; write a scored report to audit.md
disable-model-invocation: true
---

# loop-audit — principle & gate adherence check

On-demand process audit, complementary to `loop-run --verify-only` (which grades the product against rubric.md). This grades whether the loop upheld its own method.

If `.claude/loop/` does not exist: say so and point to `/loopy:loop-init`. Otherwise:

1. Spawn the `auditor` agent with the instruction "audit this loop's process and decision-gate adherence". It reads `.claude/loop/` and recent git history and returns one `## Auditor report` (per-principle PASS/FAIL/UNKNOWN + verdict) plus a `## Gaps / next` list. It modifies nothing.
2. Print the report verbatim.
3. Apply it (main agent does the write, mirroring how verifier reports are applied): OVERWRITE `.claude/loop/audit.md` with the report and a one-line timestamp header. `audit.md` is a human-facing artifact — committed like `review.md`, not gitignored.
4. Suggest the next step: address the top gap, or resume with `/loopy:loop-run`.

Do not fix anything here yourself beyond writing `audit.md`; the gaps are for the next `loop-run` cycle or a human to act on. Safe to run anytime, including as the first command of a fresh session.
