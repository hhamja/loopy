#!/usr/bin/env bash
# Acceptance spec for the runtime-agnostic engine CLI (bin/loopy) and the
# "one decision core, two adapters" invariant. Author = orchestrator (checker),
# NOT the maker — the maker (Codex) implements bin/loopy + core_lib.sh + the
# gate-script refactor until this passes. Pure bash, zero deps.
#   bash tests/test_cli.sh   -> exit 0 = all pass, exit 1 = any failure
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOOPY="$ROOT/bin/loopy"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
# condition evaluated INSIDE the helper (keeps shellcheck happy: no A&&B||C, no bare $?)
chk() { local l="$1"; shift; if test "$@"; then ok "$l"; else bad "$l" "test: $*"; fi; }
eq()  { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3" "${4:-want=$2 got=$1}"; fi; }
has() { case "$1" in *"$2"*) ok "$3" ;; *) bad "$3" "want substring: $2 | got: $1" ;; esac; }

printf '\nbin/loopy — CLI surface\n'
chk "bin/loopy is executable" -x "$LOOPY"

h="$("$LOOPY" help 2>&1 || true)"
has "$h" gate-check "help lists gate-check"
has "$h" stop-check "help lists stop-check"
has "$h" init       "help lists init"

printf '\ngate-check — T2 blocked (exit 2), T0/T1 allowed (exit 0). Run from a bare\n'
printf 'temp dir so default protected set (main master) is exercised loop-independently.\n'
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

assert_gc() { # <cmd> <want-exit> <label>
  local got
  ( cd "$TMP" && "$LOOPY" gate-check --cmd "$1" ) >/dev/null 2>&1; got=$?
  eq "$got" "$2" "$3" "want exit $2 got $got for: $1"
}
# T2 -> exit 2
assert_gc 'git push origin main'          2 "git push to protected branch -> block"
assert_gc 'npm publish'                   2 "npm publish -> block"
assert_gc 'gh pr merge 12'                2 "gh pr merge -> block"
assert_gc 'git push --force origin topic' 2 "git force-push -> block"
assert_gc 'rm -rf /'                      2 "catastrophic rm -rf / -> block"
# T0/T1 -> exit 0
assert_gc 'git commit -m wip'             0 "local commit -> allow"
assert_gc 'git push origin feature/x'     0 "push to work branch -> allow"
assert_gc 'npm test'                      0 "test run -> allow"
assert_gc 'rm -rf ./build'                0 "local subdir rm -> allow"

printf '\nblocked gate-check writes a human reason to stderr\n'
err="$( ( cd "$TMP" && "$LOOPY" gate-check --cmd 'git push origin main' ) 2>&1 1>/dev/null || true )"
chk "block prints a reason" -n "$err"

printf '\nstop-check — fail-open when no run-marker (exit 0)\n'
ST="$(mktemp -d)"; mkdir -p "$ST/.claude/loop"
( cd "$ST" && "$LOOPY" stop-check ) >/dev/null 2>&1; got=$?
eq "$got" 0 "stop-check no marker -> exit 0" "got $got"
rm -rf "$ST"

printf '\none core, two adapters — same T2 blocked via the CC-JSON hook path\n'
cc="$(printf '{"tool_input":{"command":"git push origin main"},"session_id":"t"}' | ( cd "$TMP" && bash "$ROOT/scripts/decision_gate.sh" ) 2>/dev/null || true)"
has "$cc" '"permissionDecision":"deny"' "CC-JSON adapter denies same T2"
cc0="$(printf '{"tool_input":{"command":"git commit -m x"},"session_id":"t"}' | ( cd "$TMP" && bash "$ROOT/scripts/decision_gate.sh" ) 2>/dev/null || true)"
chk "CC-JSON adapter allows T0 (empty)" -z "$cc0"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
