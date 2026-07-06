---
description: Scaffold .claude/loop/ state files and detect this project's test/lint/build commands
---

# loop-init — scaffold project-local loop state

Create the mutable loop state under `.claude/loop/` in the current project. The plugin itself is immutable; everything the loop learns or tracks lives in these files.

**Idempotency:** if `.claude/loop/` already exists, list its files and stop. Never overwrite existing loop state.

## Steps

Scaffold first, questions last: you often cannot tell whether anyone can answer you (headless `-p` sessions look identical to interactive ones). Creating the files NEVER waits on user input.

1. **Detect stack commands** for `loop.config.md`. Check ecosystem manifests in this order and extract test / lint / build commands:
   - `package.json` → `scripts.test` / `scripts.lint` / `scripts.build` (prefix with the package manager detected from the lockfile: npm / pnpm / yarn / bun)
   - `pyproject.toml` → pytest / ruff / mypy etc. from tool sections or dev dependencies
   - `Makefile` → `test` / `lint` / `build` targets
   - `Cargo.toml` → `cargo test` / `cargo clippy` / `cargo build`
   - `go.mod` → `go test ./...` / `go vet ./...` / `go build ./...`

   For anything missing or ambiguous, use `TODO: <fill in manually>` — do not stop to ask.
2. **Create the files** from the templates below immediately, using detected values and TODOs. Goal: use the command arguments if given, else `TODO: define the goal`. Print one warning line per TODO written.
3. **Gitignore:** ensure the project `.gitignore` contains the line `.claude/loop/.*` (create `.gitignore` if missing; skip if the line already exists). Non-hidden loop files are MEANT to be committed (team sharing, session recovery).
4. **Interactive refinement (optional):** only AFTER the files exist, and only if this session is clearly interactive (a human typed the command and can reply), you may ask ONE question to fill the remaining TODOs, then update the files. If in doubt, skip — TODOs are the designed outcome. Never end the turn with questions instead of created files.
5. **Report:** created paths + remaining TODOs + next steps — try `/loop-harness:loop-run --verify-only` first (grade only), then `/loop-harness:loop-run`.

## Templates

### .claude/loop/goal.md

```markdown
# Goal

<one sentence: what "done" means — or TODO: define the goal>

## Stop condition
The loop stops when every criterion in rubric.md passes.
Criteria must be machine-checkable; subjective wording is forbidden
(see loop-engineering skill, references/rubric-guide.md).
```

### .claude/loop/rubric.md

```markdown
# Rubric

<!-- 5-15 criteria. Every criterion MUST carry a verification command or file check. -->
<!-- Checkboxes are updated ONLY by the main agent after a verifier report. -->

- [ ] R1: <criterion> — verify: `<command>` (expect: <observable result>)
```

### .claude/loop/state.md

```markdown
# Loop State

loop_active: false
iteration: 0
last_run_tokens_est: n/a

## Attempted
(nothing yet)

## Passed
(nothing yet)

## Unresolved
(nothing yet)

<!-- REWRITE as a summary every cycle. Max 100 lines. Never append —
     single exception: the one-line 'loop interrupted' note the stop gate may ask for. -->
```

### .claude/loop/memory.md

```markdown
# Loop Memory

<!-- 5-step protocol: fail -> investigate -> verify -> distill -> consult.
     See loop-engineering skill, references/memory-protocol.md.
     Tag every entry [plugin] or [project]. -->

## Distilled rules (consult before every cycle)
(none yet)

## Raw log
(compress when this section exceeds 200 lines)
```

### .claude/loop/review.md

```markdown
# Cycle Review (for humans)

<!-- Overwritten every cycle. -->
- Files changed:
- Key changes:
- Risks / needs human eyes:
```

### .claude/loop/loop.config.md

```markdown
# Loop Config — the only stack-dependent file

test: <detected command or TODO: fill in manually>
lint: <detected command or TODO: fill in manually>
build: <detected command or TODO: fill in manually>

max_iterations: 10
escalation: after 3 consecutive failures of the same criterion, stop and present 2-3 options
```
