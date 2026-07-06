# Changelog

## 0.2.0 — 2026-07-07

- Cross-model maker/checker: `loop-run` delegates the Implement step to OpenAI's Codex CLI (`codex exec --full-auto`) when `implementer: codex`; Claude stays the orchestrator and the verifier.
- `loop.config.md` gains `implementer: codex|claude` (auto-detected by `loop-init` via `codex --version`) and an optional `codex_args` passthrough (e.g. model, network access).
- Fresh `codex exec` per cycle; the prompt is rebuilt from disk state (goal, unresolved criteria, last failure reasons, distilled rules) with fixed guardrails (no `.claude/loop/` writes, no git commit/push).
- Context hygiene: codex stdout → `.claude/loop/.codex-log`; the main agent reads only `.codex-last` (`--output-last-message`); prompt in `.codex-prompt` — all covered by the existing `.claude/loop/.*` gitignore rule.
- Fallback: codex unavailable at run start → the run proceeds as claude (recorded in state.md/memory.md); a non-zero `codex exec` → one retry, then claude for that cycle.
- Docs: mission spec v3.4.4 → v3.5.0 (ko/en); README cross-model section (en/ko).

## 0.1.0 — 2026-07-06

- Initial release.
- Commands: `loop-init`, `loop-run` (`--once`, `--verify-only`), `loop-status`.
- Agents: `verifier` (read-only grader), `explorer` (haiku scout).
- Skill: `loop-engineering` + 3 references (memory-protocol, rubric-guide, worktree-guide).
- Hooks: Stop gate (`stop_gate.sh`), verifier write guard (`verifier_guard.sh`, PreToolUse Bash).
- `check_budget.sh` token-budget proof script.
