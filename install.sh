#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-$(pwd)}"
CLAUDE_DIR="$TARGET/.claude"
LOOPY_DIR="$CLAUDE_DIR/loopy"

mkdir -p "$LOOPY_DIR/scripts" "$LOOPY_DIR/bin" "$CLAUDE_DIR/skills" "$CLAUDE_DIR/agents"

cp -R "$ROOT/scripts/." "$LOOPY_DIR/scripts/"
cp "$ROOT/bin/loopy" "$LOOPY_DIR/bin/loopy"
chmod +x "$LOOPY_DIR/bin/loopy" 2>/dev/null || true
find "$LOOPY_DIR/scripts" -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

if [ -d "$ROOT/skills" ]; then
  cp -R "$ROOT/skills/." "$CLAUDE_DIR/skills/"
fi
if [ -d "$ROOT/agents" ]; then
  cp -R "$ROOT/agents/." "$CLAUDE_DIR/agents/"
fi

# Project-level skills/agents are not plugin-namespaced. Rewrite only vendored
# copies so the plugin install remains namespaced and backward compatible.
if command -v python3 >/dev/null 2>&1; then
  python3 - "$CLAUDE_DIR" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
for base in (root / "skills", root / "agents"):
    if not base.exists():
        continue
    for path in base.rglob("*.md"):
        text = path.read_text()
        text = text.replace("/loopy:", "/")
        text = re.sub(r"\bloopy:([A-Za-z0-9_-]+)", r"\1", text)
        path.write_text(text)
PY
else
  find "$CLAUDE_DIR/skills" "$CLAUDE_DIR/agents" -type f -name '*.md' -exec sed -i.bak 's#/loopy:#/#g; s/\bloopy://g' {} + 2>/dev/null || true
  find "$CLAUDE_DIR/skills" "$CLAUDE_DIR/agents" -type f -name '*.bak' -delete 2>/dev/null || true
fi

SETTINGS="$CLAUDE_DIR/settings.json"
if [ ! -f "$SETTINGS" ]; then
  printf '{}\n' > "$SETTINGS"
fi

if command -v python3 >/dev/null 2>&1; then
  python3 - "$SETTINGS" <<'PY'
import json, pathlib, sys

settings = pathlib.Path(sys.argv[1])
try:
    data = json.loads(settings.read_text() or "{}")
    if not isinstance(data, dict):
        data = {}
except Exception:
    data = {}

hooks = data.setdefault("hooks", {})
if not isinstance(hooks, dict):
    hooks = {}
    data["hooks"] = hooks

base = "$CLAUDE_PROJECT_DIR/.claude/loopy/scripts"
desired = {
    "SessionStart": [
        {
            "matcher": "startup|resume|clear|compact",
            "hooks": [
                {"type": "command", "command": f"{base}/session_state_digest.sh", "timeout": 5}
            ],
        },
        {
            "hooks": [
                {"type": "command", "command": f"{base}/loop_reminder.sh"},
                {"type": "command", "command": f"{base}/session_state_digest.sh", "timeout": 5},
            ],
        },
    ],
    "PreToolUse": [
        {
            "matcher": "Bash",
            "hooks": [
                {"type": "command", "command": f"{base}/verifier_guard.sh"},
                {"type": "command", "command": f"{base}/decision_gate.sh"},
            ],
        }
    ],
    "PostToolUse": [
        {
            "matcher": "Bash|Edit|Write|NotebookEdit",
            "hooks": [
                {"type": "command", "command": f"{base}/touch_track.sh"}
            ],
        }
    ],
    "Stop": [
        {
            "hooks": [
                {"type": "command", "command": f"{base}/stop_gate.sh"},
                {"type": "command", "command": f"{base}/check_memory.sh"},
                {"type": "command", "command": f"{base}/auto_commit.sh"},
                {"type": "command", "command": f"{base}/auto_push.sh"},
                {"type": "command", "command": f"{base}/auto_pr.sh"},
            ],
        }
    ],
}

def commands(entry):
    return {
        h.get("command")
        for h in entry.get("hooks", [])
        if isinstance(h, dict) and h.get("command")
    }

for event, entries in desired.items():
    current = hooks.get(event)
    if not isinstance(current, list):
        current = []
        hooks[event] = current
    existing = set()
    for entry in current:
        if isinstance(entry, dict):
            existing.update(commands(entry))
    for entry in entries:
        needed = commands(entry)
        if not needed.issubset(existing):
            current.append(entry)
            existing.update(needed)

settings.write_text(json.dumps(data, indent=2, sort_keys=False) + "\n")
PY
else
  printf 'install.sh requires python3 to merge .claude/settings.json\n' >&2
  exit 1
fi

printf 'loopy installed into %s\n' "$CLAUDE_DIR"

