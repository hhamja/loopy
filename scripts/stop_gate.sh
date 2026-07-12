#!/usr/bin/env bash
# loopy stop gate (Stop hook).
#
# Verdict order — block ONLY if all four hold (fail-open on any doubt):
#   1. .claude/loop/ exists              (else: non-loop session, pass)
#   2. stop_hook_active != true          (else: pass — prevents infinite block loop)
#   3. .run-marker exists AND its session_id is parseable, != "unknown",
#      and equals this session's id      (else: pass — stale markers from other or
#                                         killed sessions must never block)
#   4. state.md exists and is OLDER than .run-marker -> BLOCK (state not updated
#      this run). state.md missing -> pass (cannot judge, do not block).
#
# .run-marker is intentionally NEVER deleted after a run: once state.md is updated,
# its mtime exceeds the marker's, so verdict 4 passes naturally from then on.
# A leftover marker is NOT a bug.
#
# .last-usage (run token estimate) is written whenever verdict 4 is REACHED (i.e. a
# same-session marker exists), even if the outcome is pass. Estimate = transcript
# bytes / 4. The delta can include non-loop turns of the same session (accepted).
#
# Block JSON is only parsed on exit 0 — never combine it with exit 2.

set -u

# shellcheck source=scripts/hook_lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hook_lib.sh"

stop_gate_core() {
  local CUR_SID="${1:-}" TRANSCRIPT="${2:-}" STOP_ACTIVE="${3:-}" MARKER MARKER_SID BYTES EST PREV STATE

  # --- verdict 1: not a loop project ---
  [ -d "$LOOP_DIR" ] || return 0

  # --- verdict 2: already re-prompted once ---
  [ "$STOP_ACTIVE" = "true" ] && return 0

  # --- verdict 3: same-session marker required (fail-open on every doubt) ---
  MARKER="$LOOP_DIR/.run-marker"
  [ -f "$MARKER" ] || return 0

  MARKER_SID="$(sed -n 's/^session_id=//p' "$MARKER" 2>/dev/null | head -n1)"
  [ -n "$MARKER_SID" ] || return 0
  [ "$MARKER_SID" != "unknown" ] || return 0

  [ -n "$CUR_SID" ] || return 0
  [ "$MARKER_SID" = "$CUR_SID" ] || return 0

  # --- verdict 4 reached: record the run token estimate ---
  if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    BYTES="$(wc -c < "$TRANSCRIPT" 2>/dev/null | tr -d '[:space:]')"
    case "$BYTES" in ''|*[!0-9]*) BYTES=0 ;; esac
    EST=$((BYTES / 4))
    PREV="$(sed -n 's/^cumulative_est_tokens=//p' "$LOOP_DIR/.last-usage" 2>/dev/null | head -n1)"
    case "$PREV" in ''|*[!0-9]*) PREV=0 ;; esac
    {
      printf '# run token estimate = transcript bytes / 4 (rough heuristic, not billing data)\n'
      printf '# delta may include non-loop turns from this session (accepted limitation)\n'
      printf 'cumulative_est_tokens=%s\n' "$EST"
      printf 'delta_est_tokens=%s\n' "$((EST - PREV))"
      printf 'updated_epoch=%s\n' "$(date +%s)"
    } > "$LOOP_DIR/.last-usage" 2>/dev/null || true
  fi

  # --- verdict 4: block only if state.md is stale relative to the marker ---
  STATE="$LOOP_DIR/state.md"
  [ -f "$STATE" ] || return 0   # fail-open: nothing to compare against

  # [ A -ot B ] avoids the stat -f/-c macOS/Linux portability split entirely.
  if [ "$STATE" -ot "$MARKER" ]; then
    printf '%s\n' "state.md not updated this run. If this turn was loop work: update state.md (attempted / passed / unresolved). If this turn was unrelated to the loop: append exactly one line 'loop interrupted (previous run did not update state)' to state.md, then finish."
    return 2
  fi

  return 0
}

stop_gate_block_json() {
  cat <<'JSON'
{"decision":"block","reason":"state.md not updated this run. If this turn was loop work: update state.md (attempted / passed / unresolved). If this turn was unrelated to the loop: append exactly one line 'loop interrupted (previous run did not update state)' to state.md, then finish."}
JSON
}

stop_gate_main() {
  local active=false rc
  hook_init
  hook_debug stop_gate
  if stop_hook_active; then active=true; fi
  # core's stdout reason is for the CLI adapter; the CC path emits fixed block JSON
  stop_gate_core "$(json_str session_id)" "$(json_str transcript_path)" "$active" >/dev/null; rc=$?
  if [ "$rc" -eq 2 ]; then
    stop_gate_block_json
  fi
  exit 0
}

if [ "${LOOPY_SOURCE_ONLY:-}" != "1" ]; then
  stop_gate_main "$@"
fi
