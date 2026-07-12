# shellcheck shell=bash
# loopy hook lib — the single home of the preamble and parsers the hook/gate
# scripts used to copy-paste: stdin/cwd handling, JSON field extraction, and
# the loop.config.md accessors the gates must agree on (a protected_branches
# parse that drifts between decision_gate and auto_push/auto_pr/branch_guard
# is a gate hole, not a style issue). Source only — no side effects:
#   . "$(cd "$(dirname "$0")" && pwd)/hook_lib.sh"
# Behavior contract: identical to the blocks it replaced; tests/run.sh
# exercises every caller against fixed inputs.

SCRIPT_DIR_FOR_HOOK_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/core_lib.sh
. "$SCRIPT_DIR_FOR_HOOK_LIB/core_lib.sh"

# json_str <key> — first top-level string field from INPUT (crude sed; fine
# for the machine-written cwd/session_id/transcript_path fields).
json_str() {
  case "$1" in
    session_id) [ "${LOOPY_SESSION_ID+x}" = x ] && { printf '%s' "$LOOPY_SESSION_ID"; return 0; } ;;
    transcript_path) [ "${LOOPY_TRANSCRIPT+x}" = x ] && { printf '%s' "$LOOPY_TRANSCRIPT"; return 0; } ;;
    transcript) [ "${LOOPY_TRANSCRIPT+x}" = x ] && { printf '%s' "$LOOPY_TRANSCRIPT"; return 0; } ;;
  esac
  printf '%s' "$INPUT" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n1
}

# hook_init — read hook stdin into INPUT, then cd to its cwd field (hooks run
# in the project cwd; prefer the field when present).
hook_init() {
  INPUT="$(cat 2>/dev/null || true)"
  local d; d="$(json_str cwd)"
  if [ -n "$d" ] && [ -d "$d" ]; then
    cd "$d" 2>/dev/null || true
  fi
}

# stop_hook_active — true when this Stop event is already a re-prompt
# (callers exit 0 to avoid an infinite block loop / acting mid-block).
stop_hook_active() {
  [ "${LOOPY_STOP_HOOK_ACTIVE+x}" = x ] && {
    [ "$LOOPY_STOP_HOOK_ACTIVE" = "true" ] || [ "$LOOPY_STOP_HOOK_ACTIVE" = "1" ]
    return
  }
  printf '%s' "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'
}

# hook_debug <name> — opt-in observability (smoke checks read this log to tell
# "field absent" apart from "value mismatch"). Default state writes nothing.
hook_debug() {
  [ "${LOOP_GUARD_DEBUG:-}" = "1" ] || return 0
  [ -d "$LOOP_DIR" ] || return 0
  printf '%s %s input=%s\n' "$(date +%s)" "$1" "$INPUT" >> "$LOOP_DIR/.hook-debug.log" 2>/dev/null || true
}

# bash_cmd — the Bash tool command from INPUT. Three tiers: jq (exact),
# python3 (exact), sed (crude last resort; may truncate at escaped quotes —
# callers fail open, so a weaker parse only weakens detection, never blocks
# wrongly).
bash_cmd() {
  [ "${LOOPY_TOOL_CMD+x}" = x ] && { printf '%s' "$LOOPY_TOOL_CMD"; return 0; }
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))
except Exception:
    pass' 2>/dev/null || true
  else
    printf '%s' "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -n1
  fi
}

# tool_str <key> — first string field from INPUT's tool_input object. Same
# three tiers and fail-open contract as bash_cmd (jq exact, python3 exact,
# sed crude last resort); callers treat empty as "not present".
tool_str() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r ".tool_input.\"$1\" // empty" 2>/dev/null || true
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
    v = json.load(sys.stdin).get("tool_input", {}).get(sys.argv[1], "")
    print(v if isinstance(v, str) else "")
except Exception:
    pass' "$1" 2>/dev/null || true
  else
    printf '%s' "$INPUT" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n1
  fi
}
