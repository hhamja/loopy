# shellcheck shell=bash
# loopy core lib — runtime-agnostic config parsers and small verdict helpers.
# Source only; no Claude Code hook JSON parsing and no side effects.

LOOP_DIR="${LOOP_DIR:-.claude/loop}"

# sid_safe <sid> — session id reduced to filename-safe chars (it names the
# per-session .touched-<sid> manifest); empty in -> "unknown" out. When the
# filter dropped characters, two DISTINCT sids could collapse to one name
# ("a/b" and "ab") — that collision would merge two sessions' manifests and
# defeat the peer detection, so a checksum of the raw sid disambiguates.
sid_safe() {
  local raw="${1:-}" s
  s="$(printf '%s' "$raw" | tr -cd 'A-Za-z0-9._-')"
  if [ -n "$raw" ] && [ "$s" != "$raw" ]; then
    s="${s}-$(printf '%s' "$raw" | cksum | cut -d' ' -f1)"
  fi
  printf '%s' "${s:-unknown}"
}

# config_field <key> — first `key: value` line from loop.config.md, raw
# (empty when the file or key is absent). Callers own default/TODO handling.
config_field() {
  sed -n "s/^$1:[[:space:]]*//p" "$LOOP_DIR/loop.config.md" 2>/dev/null | head -n1
}

# cfg_flag <key> <default> — boolean key; only the literal opposite of the
# default flips it (any other value, TODO, or absence keeps the default).
cfg_flag() {
  case "$2:$(config_field "$1")" in
    true:false) printf 'false' ;;
    false:true) printf 'true' ;;
    *)          printf '%s' "$2" ;;
  esac
}

# protected_re — validated protected_branches (default "main master") as an
# ERE alternation, e.g. "main|master".
protected_re() {
  local p re
  p="$(config_field protected_branches)"
  case "$p" in ''|TODO*|'<'*) p="main master" ;; esac
  re="$(printf '%s' "$p" | tr -s ' ' '|' | sed 's/^|//;s/|$//')"
  [ -n "$re" ] || re="main|master"
  printf '%s' "$re"
}

