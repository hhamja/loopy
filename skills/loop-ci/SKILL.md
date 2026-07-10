---
name: loop-ci
description: Scaffold a GitHub Actions CI workflow from the loop's detected test/lint/build commands
disable-model-invocation: true
---

# loop-ci — scaffold CI from the loop's own checks

Generate `.github/workflows/loop-ci.yml` so CI runs the SAME test/lint/build the loop verifies — CI and the loop can never disagree. Detection is yours (the agent's); the workflow text comes from `${CLAUDE_PLUGIN_ROOT}/scripts/gen_ci.sh`, a pure, golden-tested generator.

**Idempotency:** if `.github/workflows/loop-ci.yml` already exists, print its path and stop. Never overwrite.

**Scope today:** node projects (npm / pnpm / yarn / bun) are fully supported. Other stacks: see step 4.

## Steps

1. **Stop if it exists.** If `.github/workflows/loop-ci.yml` is present, show the path and end — do not regenerate.

2. **Detect the commands.** Prefer `.claude/loop/loop.config.md` (`test:` / `lint:` / `build:` lines). If it is missing, read `package.json` `scripts` directly. Pass a value through verbatim even if it is `TODO: ...` — the generator comments that step out so the gap stays visible rather than silently dropping it.

3. **Detect the package manager** from the lockfile: `pnpm-lock.yaml`→pnpm, `package-lock.json`→npm, `yarn.lock`→yarn, `bun.lockb`/`bun.lock`→bun. If several exist, prefer the most recently modified; if none, default to npm and say so in the report.

4. **Non-node projects.** If there is no `package.json`, this command does not yet emit a workflow for your stack (python/go/rust setup is not implemented). Stop and tell the user, pointing at `scripts/gen_ci.sh` as the place to extend. Never emit a workflow that cannot run.

5. **Generate:**
   ```bash
   mkdir -p .github/workflows
   "${CLAUDE_PLUGIN_ROOT}/scripts/gen_ci.sh" \
     --pm <detected> --test "<test>" --lint "<lint>" --build "<build>" \
     > .github/workflows/loop-ci.yml
   ```
   Passing an empty or `TODO` value is fine — it becomes a commented-out step.

6. **Report:** the created path, any TODO steps still to fill, and the next step. The workflow triggers on `pull_request` and `push` to main. Committing and pushing is the user's call — this command only writes the file.
