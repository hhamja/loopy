#!/usr/bin/env bash
# Acceptance spec for install.sh — the non-plugin vendoring path. Author =
# orchestrator (checker), NOT the maker. install.sh must copy the engine +
# skills + agents into a TARGET project's .claude/ and MERGE (never clobber)
# its .claude/settings.json hooks, idempotently. Pure bash; JSON reads via python3.
#   bash tests/test_install.sh   -> exit 0 = all pass, exit 1 = any failure
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/install.sh"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
# condition evaluated INSIDE the helper (shellcheck-clean: no A&&B||C, no bare $?)
chk() { local l="$1"; shift; if test "$@"; then ok "$l"; else bad "$l" "test: $*"; fi; }
eq()  { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3" "${4:-want=$2 got=$1}"; fi; }
# pyget <file> <python-expr on json 'd'> -> prints result (empty on error)
pyget() { python3 -c 'import json,sys
try:
    d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))
except Exception:
    pass' "$1" "$2" 2>/dev/null; }

[ -f "$INSTALL" ] || { printf 'install.sh missing\n'; exit 1; }
SET="" # settings.json path, set after target created

# ── target with a PRE-EXISTING settings.json (unrelated key + unrelated hook) ──
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
SET="$T/.claude/settings.json"
git -C "$T" init -q
mkdir -p "$T/.claude"
cat > "$SET" <<'JSON'
{"model":"opus","hooks":{"PreCompact":[{"hooks":[{"type":"command","command":"echo pre"}]}]}}
JSON

printf '\ninstall.sh vendors engine + skills + agents into target/.claude\n'
if ( cd "$T" && bash "$INSTALL" ) >/dev/null 2>&1; then ok "install.sh exits 0"; else bad "install.sh exits 0"; fi

chk "vendored scripts/decision_gate.sh" -f "$T/.claude/loopy/scripts/decision_gate.sh"
chk "vendored scripts/core_lib.sh"      -f "$T/.claude/loopy/scripts/core_lib.sh"
chk "vendored bin/loopy (executable)"   -x "$T/.claude/loopy/bin/loopy"
chk "vendored skills/loop-run"          -f "$T/.claude/skills/loop-run/SKILL.md"
chk "vendored agents/verifier.md"       -f "$T/.claude/agents/verifier.md"

printf '\nsettings.json: valid JSON, our hook events added, single SessionStart\n'
eq "$(pyget "$SET" 'bool(d.get("hooks"))')" True "has hooks block"
for ev in SessionStart PreToolUse PostToolUse Stop; do
  eq "$(pyget "$SET" "isinstance(d['hooks'].get('$ev'),list)")" True "hooks.$ev is an array"
done
# exactly one SessionStart key (the pre-0.15 duplicate-key bug must not be reintroduced)
eq "$(grep -c '"SessionStart"' "$SET")" 1 "exactly one SessionStart key"
# vendored path, not the plugin var
if grep -q 'loopy/scripts' "$SET"; then ok "hooks point at vendored loopy/scripts"; else bad "hooks point at vendored loopy/scripts"; fi
if grep -q 'CLAUDE_PLUGIN_ROOT' "$SET"; then bad "no CLAUDE_PLUGIN_ROOT in vendored settings" "found plugin var"; else ok "no CLAUDE_PLUGIN_ROOT in vendored settings"; fi

printf '\nmerge preserved pre-existing keys (never clobber)\n'
eq "$(pyget "$SET" 'd.get("model")')" opus "top-level model:opus preserved"
eq "$(pyget "$SET" 'isinstance(d["hooks"].get("PreCompact"),list)')" True "pre-existing PreCompact hook preserved"

printf '\nidempotency: second install exits 0 and does not duplicate our hooks\n'
if ( cd "$T" && bash "$INSTALL" ) >/dev/null 2>&1; then ok "second install exits 0"; else bad "second install exits 0"; fi
eq "$(grep -c 'decision_gate.sh' "$SET")" 1 "decision_gate hook not duplicated"
eq "$(grep -c '"SessionStart"' "$SET")" 1 "still one SessionStart after re-install"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
