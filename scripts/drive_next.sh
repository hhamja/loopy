#!/usr/bin/env bash
# loopy driver verdict — the deterministic "what should the driver do next?"
# Pure function of .claude/loop/state.md; prints ONE verdict token, always exit 0.
# A driver (attended `/loop`, or an unattended launchd tick) reads this to decide
# whether to fire another loop-run, surface to a human, or do nothing.
#
#   run                  loop is active -> fire another `/loopy:loop-run`
#   notify:ready_for_merge  rubric green + green gate clean -> human should review & merge
#   notify:pending_t2    a T2 (irreversible) action is waiting on human approval
#   notify:stalled       replan exhausted -> human decision needed
#   idle                 no loop / no active goal -> nothing to drive
#
# human_gate takes precedence over loop_active (it is a stop signal). Any unknown
# human_gate value is ignored (falls through to loop_active/idle) — fail-safe: an
# unrecognized marker never masquerades as a human gate.
#
# Usage: drive_next.sh [project_dir]   (default: cwd)
set -u

DIR="${1:-.}"
STATE="$DIR/.claude/loop/state.md"
[ -f "$STATE" ] || { printf 'idle\n'; exit 0; }

field() { grep -E "^$1:" "$STATE" | tail -1 | sed "s/^$1:[[:space:]]*//" | tr -d '[:space:]'; }

gate="$(field human_gate)"
case "$gate" in
  ready_for_merge|pending_t2|stalled) printf 'notify:%s\n' "$gate"; exit 0 ;;
esac

[ "$(field loop_active)" = "true" ] && { printf 'run\n'; exit 0; }
printf 'idle\n'
