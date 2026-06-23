#!/usr/bin/env bash
# Claude Code Stop / Notification hook -> tmuxscout.
#   Stop         -> claude-notify.sh done
#   Notification -> claude-notify.sh waiting
# Claude Code passes a JSON payload on stdin. We use it to derive:
#   - label   : basename of .cwd (the project)
#   - summary : last assistant text message from .transcript_path (what it just did)
# The pane comes from $TMUX_PANE. Outside tmux this is a harmless no-op.
set -euo pipefail

status="${1:-done}"
[ -n "${TMUX:-}" ] || exit 0

input="$(cat 2>/dev/null || true)"
label="" summary=""

if [ -n "$input" ] && command -v jq >/dev/null 2>&1; then
  label="$(printf '%s' "$input" | jq -r '(.cwd // "") | split("/") | last // ""' 2>/dev/null || true)"
  tpath="$(printf '%s' "$input" | jq -r '.transcript_path // ""' 2>/dev/null || true)"
  if [ -n "$tpath" ] && [ -f "$tpath" ]; then
    # Last assistant text block from the JSONL transcript (one object per line).
    summary="$(tail -n 80 "$tpath" 2>/dev/null | jq -rs '
        [ .[]
          | select(.type=="assistant")
          | (.message.content // [])[]?
          | select(.type=="text")
          | .text ] | last // ""
      ' 2>/dev/null | tr '\t\n' '  ' | sed 's/  */ /g; s/^ //; s/ $//')"
    summary="${summary:0:180}"
  fi
fi

# Resolve the tmuxscout binary: $TMUXSCOUT_BIN, then PATH, then repo-relative.
BIN="${TMUXSCOUT_BIN:-}"
if [ -z "$BIN" ]; then
  if command -v tmuxscout >/dev/null 2>&1; then
    BIN="tmuxscout"
  else
    BIN="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)/bin/tmuxscout"
  fi
fi
exec "$BIN" mark "$status" "$label" "$summary"
