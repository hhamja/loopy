# Rubric Guide — writing machine-verifiable criteria

A rubric criterion is valid only if a command or file check can decide it. If a human must "feel" the answer, it does not belong in rubric.md.

Format (one line per criterion):

```markdown
- [ ] R<n>: <criterion> — verify: `<command>` (expect: <observable result>)
```

Keep 5-15 criteria. Fewer than 5 usually means the goal is under-specified; more than 15 means the goal should be split into separate loops.

## Good / bad pairs

1. BAD: "The code is well tested."
   GOOD: `- [ ] R1: test suite passes — verify: npm test (expect: exit 0)`
2. BAD: "The health endpoint works."
   GOOD: `- [ ] R2: GET /api/health returns 200 with {"status":"ok"} — verify: curl -s -w '%{http_code}' localhost:3000/api/health (expect: body contains "ok", code 200)`
3. BAD: "The component is accessible."
   GOOD: `- [ ] R3: every <img> in src/ has an alt attribute — verify: grep -rn '<img' src/ | grep -vc 'alt=' (expect: 0)`
4. BAD: "Error handling is robust."
   GOOD: `- [ ] R4: lint passes with zero warnings — verify: npm run lint (expect: exit 0, no warning lines)`

## Non-code artifacts are still checkable

Documents, configs and prose can be machine-verified by structure. Example:

```markdown
- [ ] R5: README quickstart mentions all three namespaced commands — verify: grep -c 'loopy:loop-' README.md (expect: >= 3)
```

Other structural checks: word counts (`wc -w`), required headings (`grep '^## '`), JSON/YAML parseability (`jq . file.json`), internal link targets existing (`test -f`).

## Anti-patterns

- "verify: ask the verifier whether it looks right" — the verifier runs commands; it is not an opinion oracle.
- Commands that depend on network state or wall-clock time without tolerance (flaky by construction).
- Two criteria testing the same thing in different words — inflates every cycle's cost.
- Criteria that pass on an empty project (e.g. `grep -vc` returning 0 because the directory is empty) — pair them with an existence check.
