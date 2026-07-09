#!/usr/bin/env bash
# loop-harness token budget proof — the ONLY accepted evidence of budget compliance.
#   budget 1: resident surface = sum of single-line `description:` frontmatter words
#             across commands/*.md, agents/*.md, skills/*/SKILL.md  -> <= 300 words
#   budget 2: each skills/*/SKILL.md body (after the closing ---)   -> <= 500 words
# Descriptions MUST be single-line YAML scalars; multi-line descriptions are not counted
# and would silently understate the surface — keep them single-line.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESIDENT_LIMIT=300
BODY_LIMIT=500

total=0
printf 'resident surface (frontmatter descriptions):\n'
for f in "$ROOT"/commands/*.md "$ROOT"/agents/*.md "$ROOT"/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  desc="$(awk '/^---[[:space:]]*$/{n++; next} n==1 && sub(/^description:[[:space:]]*/, ""){print; exit}' "$f")"
  w="$(printf '%s' "$desc" | wc -w | tr -d '[:space:]')"
  printf '  %-45s %3s words\n' "${f#"$ROOT"/}" "$w"
  total=$((total + w))
done
printf 'resident total: %s / %s words\n' "$total" "$RESIDENT_LIMIT"

fail=0
if [ "$total" -gt "$RESIDENT_LIMIT" ]; then
  printf 'FAIL: resident surface over budget\n'
  fail=1
fi

printf 'SKILL.md bodies (limit %s):\n' "$BODY_LIMIT"
for SKILL in "$ROOT"/skills/*/SKILL.md; do
  [ -f "$SKILL" ] || continue
  body="$(awk '/^---[[:space:]]*$/{n++; next} n>=2{print}' "$SKILL" | wc -w | tr -d '[:space:]')"
  printf '  %-45s %3s words\n' "${SKILL#"$ROOT"/}" "$body"
  if [ "$body" -gt "$BODY_LIMIT" ]; then
    printf 'FAIL: %s body over budget\n' "${SKILL#"$ROOT"/}"
    fail=1
  fi
done

[ "$fail" -eq 0 ] && printf 'BUDGET OK\n'
exit "$fail"
