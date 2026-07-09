# Replan — try real alternatives before escalating to a human

When the same rubric criterion has failed 3 consecutive cycles, the loop is stuck, not broken. Escalating to a human on every stuck criterion is over-confirmation — most stalls are the maker repeating one approach that cannot work. Before escalating, the orchestrator (main agent) re-plans and retries with a *different* approach on its own, because trying another reversible approach is a T0 action (see `decision-gates.md`).

## The one rule you may not break

**Never weaken a rubric criterion to force a pass.** Relaxing, deleting, or loosening a `verify:` command is a *human* decision — an escalation option, never an autonomous replan move. The maker/checker contract depends on the standard staying fixed while the loop runs; auto-relaxing is grading your own work through the back door. The `auditor` checks this (A7) against `rubric.md`'s git history.

## Replan procedure (bounded)

On the 3-consecutive-failure trigger, before escalating, try up to `replan_max` alternative strategies (default 2; read from loop.config.md). Each attempt must change *something real* about the approach — not retry the same thing harder:

- **Change approach** — a different implementation path to the same criterion (different API, different layer, a library already in the project).
- **Decompose** — split the criterion's *work* into smaller steps the maker can land one at a time. Split the work, never the criterion — the `verify:` command stays byte-identical.
- **Spike the cause** — spend one cycle only investigating (read logs, reproduce in isolation, add a temporary probe), record the root cause in memory.md per `memory-protocol.md`, then attempt the fix with that knowledge.

Record each attempt in state.md (`replan: <n>/<replan_max>, strategy: <which>`) and its outcome in memory.md. A replan attempt is still one cycle and still counts toward `max_iterations`.

## When replan is exhausted → escalate

If every `replan_max` alternative fails the same criterion, stop guessing — this is now genuinely a human decision. Present 2-3 concrete options, e.g.:

- relax or re-scope the criterion (**human-only** — see the one rule above),
- change the goal or approach at a level above the loop,
- provide missing input the loop cannot infer (a credential, a product decision, a spec).

Interactive: ask the user. Headless: write the options and the stall reason to state.md, set `human_gate: stalled`, and end the turn. Do not loop further on that criterion.

## Relation to the safety rails

Replan sits *inside* the 3-consecutive-failure rail, not around it: it turns a hard stop into "try N real alternatives, then a hard stop". `max_iterations` still bounds the whole run, and an unbounded "keep trying new ideas" loop is forbidden — `replan_max` is the ceiling.
