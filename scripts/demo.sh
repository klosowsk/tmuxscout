#!/usr/bin/env bash
# tmuxscout demo — simulate several AI agents working across tmux sessions, so
# you can grab a screenshot / GIF of the badge + popup with real-looking
# conversations, provenance and summaries.
#
#   scripts/demo.sh up    # create the scenario (sessions: web, api)
#   scripts/demo.sh down  # tear it down
#
# Everything runs on a PRIVATE tmux socket ("scoutdemo"), fully isolated from
# your real sessions/agents. Attach with:  tmux -L scoutdemo attach -t web
# You sit in an un-tracked Claude conversation; four OTHER agents are flagged.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GEN="$HERE/demo-agent.sh"
RADAR="$(command -v tmuxscout 2>/dev/null || echo "$HERE/../bin/tmuxscout")"
SOCK="${TMUXSCOUT_DEMO_SOCKET:-scoutdemo}"
chmod +x "$GEN" 2>/dev/null || true

# Route every tmux call — ours AND tmuxscout's — to the private socket.
WRAP="${TMPDIR:-/tmp}/tmuxscout-demo-wrap"
mkdir -p "$WRAP"
printf '#!/bin/sh\nexec /usr/bin/tmux -L %s "$@"\n' "$SOCK" > "$WRAP/tmux"
chmod +x "$WRAP/tmux"
export PATH="$WRAP:$PATH"

up() {
  tmux kill-session -t web 2>/dev/null || true
  tmux kill-session -t api 2>/dev/null || true

  local p1 p2 p3 p4
  # web window 0 = the Claude conversation you're sitting in (NOT tracked — it's
  # the one you're looking at, so anti-noise wouldn't flag it anyway).
  tmux new-session -d -s web -n 'claude' "cd /tmp; bash '$GEN' claude"
  # The four flagged agents live in windows/sessions you're NOT focused on.
  p1="$(tmux new-window  -d -P -F '#{pane_id}' -t web -n 'claude·auth'   "bash '$GEN' claude")"
  p2="$(tmux new-window  -d -P -F '#{pane_id}' -t web -n 'opencode·e2e'  "bash '$GEN' opencode")"
  p3="$(tmux new-session -d -P -F '#{pane_id}' -s api -n 'codex·billing' "cd /tmp; bash '$GEN' codex")"
  p4="$(tmux new-window  -d -P -F '#{pane_id}' -t api -n 'pi·pipeline'   "bash '$GEN' pi")"

  TMUXSCOUT_PANE="$p1" "$RADAR" mark waiting web-app       "Refactored the auth middleware; needs your call on the session-store migration before sign-ins break."
  TMUXSCOUT_PANE="$p2" "$RADAR" mark done    web-app       "Added Playwright e2e for the checkout flow — 14 specs, all green."
  TMUXSCOUT_PANE="$p3" "$RADAR" mark done    api-server    "Billing client now retries with backoff and surfaces 402 as a typed error. Ready for review."
  TMUXSCOUT_PANE="$p4" "$RADAR" mark waiting data-pipeline "Wants confirmation before a destructive backfill of warehouse.daily_agg on staging."
  "$RADAR" refresh 2>/dev/null || true

  # Force the English UI in the popup for the capture (overrides the local config).
  # Done AFTER the server is up + ~/.tmux.conf is sourced, so this binding wins.
  tmux bind a display-popup -E -w 80% -h 70% "TMUXSCOUT_LANG=en-US tmuxscout pick"
  echo "demo up (socket: $SOCK). Attach:  tmux -L $SOCK attach -t web"
}

down() {
  tmux kill-server 2>/dev/null || true   # kills only the private scoutdemo server
  rm -rf "$WRAP"
  echo "demo down."
}

case "${1:-up}" in
  up) up ;;
  down) down ;;
  *) echo "usage: demo.sh {up|down}" >&2; exit 1 ;;
esac
