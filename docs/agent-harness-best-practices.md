# Agent Harness Best Practices

Operational reference for designing and running autonomous coding-agent harnesses.
Consolidated from Anthropic, OpenAI, and community research. Written to be read by agents: rules are imperative — follow them unless the task explicitly overrides.

## Core Principles

1. **Context windows are the constraint; structured artifacts on disk are the solution.** Everything below exists to bridge sessions.
2. **Separate generation from evaluation.** An agent cannot objectively grade its own work.
3. **One task per session.** Prevents context exhaustion; keeps sessions recoverable.
4. **Verify before building.** Assume the previous session may have broken something.
5. **Wire in fast feedback loops.** Tests, linters, type checkers, and UI automation act as backpressure.
6. **Bound every loop.** Iteration cap, budget limit, machine-verifiable stop condition, human escalation path.
7. **The repository is the single source of truth.** Knowledge not in the repo does not exist for an agent.
8. **Instructions are advisory; hooks are guarantees.** Anything that must happen every time belongs in a hook, not in an instruction file.
9. **Humans steer, agents execute.** Engineers design environments, specify intent, and build feedback loops; the agent writes the code.
10. **Simplify relentlessly.** Every harness component encodes an assumption about what the model can't do; those assumptions expire with each model upgrade.

## 1. Architecture

- Start with a single-agent loop. Multi-agent orchestration adds microservice-grade complexity compounded by non-determinism; adopt it only after hitting a specific ceiling a single agent cannot clear.
- When you do split, separate concerns:
  - **Planner** — expands a short prompt into a product/feature spec. High-level design only; over-specifying upfront cascades errors downstream.
  - **Generator** — implements one feature at a time against the spec.
  - **Evaluator** — tests the running app as a user would, grades against criteria, returns concrete feedback. Tuning a standalone evaluator to be skeptical is far more tractable than making a generator self-critical.
- Prefer a fresh context per session (context reset) over compaction alone: a full reset removes "context anxiety" (premature wrap-up as context fills), with handoff files bridging the gap. Re-evaluate as models improve — capable models may make compaction sufficient.

## 2. State and Persistence

Persist on disk everything that must survive a session:

- **Task/feature list** — JSON, not Markdown (resists model-induced corruption). Never remove or reorder items; only flip status from incomplete to complete.
- **Progress notes** — what was done, bugs found/fixed, what's next, key decisions. Write at the end of every session.
- **Plan/spec file** — the original requirements, kept in the project directory.
- **Init script** — automates environment setup so no context is wasted on installation.
- **Git history** — descriptive commits are the recovery mechanism; read recent commits at session start.

Keep the top-level instruction file (AGENTS.md / CLAUDE.md) a map, not an encyclopedia (~100 lines): a table of contents pointing into `docs/`. Structure knowledge for progressive disclosure — a small, stable entry point that says where to look. Put the most important instructions first so truncation can't drop them.

Push all relevant knowledge into the repo — decisions from chat threads, architectural patterns, product context. If an agent can't discover it, it's illegible.

## 3. Session Protocol

Run every session in this order:

1. **Orient** — read progress notes, task list, recent git history
2. **Setup** — run the init script
3. **Verify baseline** — confirm existing functionality still works before touching anything new
4. **Select one task** — the highest-priority incomplete item
5. **Implement**
6. **Test** — through the real UI/API, not unit tests alone
7. **Update state** — mark the task complete, commit with a descriptive message, write progress notes
8. **Clean exit** — leave the application in a working state

One task per session. Relax only after the project proves stable; tighten again if quality degrades. Compounding bugs across sessions is the most common failure mode — always verify baseline first.

## 4. Feedback Loops and Backpressure

- Wire everything that can reject invalid output into the loop: type checkers, linters, test suites, static analyzers, security scanners. The feedback wheel must turn fast — slow verification cuts the iterations an agent can attempt.
- Run the tests for a unit of code immediately after implementing it.
- Force interaction with the running application (Playwright/Puppeteer MCP: navigate, click, fill forms, screenshot). Without this, agents mark features complete without testing them.
- Give the evaluator gradable criteria, not "is this good?": a definition of good, few-shot scored examples for calibration, and hard failing thresholds. Weight criteria toward model weaknesses (design originality, feature completeness), not what it already does well.
- For complex chunks, use a **sprint contract**: the generator proposes what it will build and how success is verified; the evaluator reviews the proposal before implementation starts.
- The evaluator pays off when the task sits at or beyond the generator's solo capability; well inside it, the evaluator is overhead. Calibrate accordingly.

## 5. Context Management

- The primary context is a scheduler. Offload searches, code analysis, test runs, and summarization to subagents; have them return summaries, never raw dumps.
- Fan out read-only subagents (search, analysis) with high parallelism; limit parallelism for writes (build, test).
- Deterministically load the same core files (plan, spec) every loop so each iteration starts from the same foundation.
- Never assume code doesn't exist — agent searches are unreliable. Search before implementing to avoid duplicate implementations.

## 6. Prompting Rules

- Forbid placeholder/stub implementations explicitly and enforce full implementations — models are biased toward minimal code that merely compiles. Use strong language if needed.
- Capture the "why" of tests and architectural decisions in docs or comments — future loops won't have the original reasoning in context.
- Let the agent update AGENTS.md / CLAUDE.md with build/test/run learnings, so future loops don't repeat the same mistakes.
- Log any discovered bug in the plan/todo file immediately, even if unrelated to the current task; fix it now or leave it for a later loop.

## 7. Security and Sandboxing

Defense in depth, three layers:

1. **OS-level sandbox** — isolate the execution environment
2. **Filesystem restrictions** — limit file operations to the project directory
3. **Command allowlist** — parse with a real shell lexer (e.g. `shlex`), handle pipes/chaining, block anything not explicitly allowed, and validate sensitive commands (`pkill` for dev processes only, `chmod` for `+x` only)

## 8. Code Quality and Agent Legibility

- Enforce invariants mechanically — linters, structural tests, CI checks — not through documentation alone. Lint error messages must include remediation steps so agents can self-fix without human intervention.
- Encode rules as code: in an agent-generated codebase, encoded rules are multipliers.
- Treat technical debt like garbage collection: recurring cleanup agents scan for deviations from golden principles and open small, targeted refactoring PRs.
- Favor boring technology — composable, stable APIs, well-represented in training data — over cutting-edge stacks agents model poorly.
- Make the application inspectable: boot per git worktree for isolated instances, wire the DevTools protocol for DOM snapshots and screenshots, expose logs/metrics/traces via queryable APIs.

## 9. Recovery and Stop Conditions

Define before the loop starts — an unbounded loop is the harness's most expensive failure mode:

- **Iteration cap** — a hard maximum number of sessions/attempts
- **Budget limit** — token or dollar ceilings per session and per run
- **Machine-verifiable success** — "done" is a passing check (tests green, exit 0, file exists), never the agent's own judgment
- **Give-up + escalation** — N consecutive no-progress sessions on one task → stop and escalate to a human

Git is the safety net: commit after every successful task, tag known-good states, read history at session start, and `git reset --hard` + re-run when the codebase breaks. Reset-and-rerun vs prompt-rescue are both valid — pick the cheaper one.

Regenerate plans periodically: have the agent diff the codebase against the spec and rebuild the todo list. Plans drift; stale plans mislead.

Expect eventual consistency: most issues resolve with more loops and better-tuned prompts.

## 10. Evolving the Harness

- On every model upgrade: strip scaffolding that is no longer load-bearing, add components for newly possible capabilities, and test by removing one component at a time and reviewing the impact.
- Start simple; add complexity only at a specific, demonstrated ceiling. Three similar lines of code beat a premature abstraction.

## Tool Notes

### Claude Code
- **CLAUDE.md**: only what can't be inferred from code. For each line ask "would removing this cause mistakes?" — if not, cut it. Occasionally-needed knowledge goes in **Skills** (loaded on demand).
- Workflow: **Explore → Plan → Code → Commit**; skip planning when the diff fits in one sentence.
- Verification options, cheapest to strongest: explicit test cases in the prompt, screenshot comparison, `/goal` conditions, Stop hooks as deterministic gates, adversarial review subagents. Demand evidence, not claims of success.
- Scale: `claude -p` (headless) for CI and fan-out, git worktrees for parallel sessions, writer/reviewer split across sessions.

### Codex
- **AGENTS.md layering**: `~/.codex/AGENTS.md` (global) → repo root → subdirectory overrides (closest wins); 32 KiB default cap. Promote repeated ad-hoc prompt rules into AGENTS.md immediately.
- Include: working agreements, build/test commands, done criteria, approval steps. Exclude: long explanations and stack configuration (→ `config.toml`).
- Prompt structure: **Goal / Context / Constraints / Done-when**.
- Anti-patterns: build commands not documented, skipping planning on complex work, granting full permissions before understanding, working outside a worktree, one giant task for a whole project, stale ad-hoc rules left in prompts.

## References

- [Ralph Wiggum as a "software engineer"](https://ghuntley.com/ralph/) — Geoffrey Huntley, Jul 2025
- [Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — Anthropic, Nov 2025
- [Harness engineering: leveraging Codex in an agent-first world](https://openai.com/index/harness-engineering/) — OpenAI, Feb 2026
- [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps) — Anthropic, Mar 2026
- [Claude Code best practices](https://code.claude.com/docs/en/best-practices) — Anthropic
- [Codex best practices](https://developers.openai.com/codex/learn/best-practices) · [AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md) — OpenAI
