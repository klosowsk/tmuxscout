#!/usr/bin/env sh
# tmuxscout — OpenAI Codex CLI integration.
#
# Codex invokes its `notify` program with a single JSON argument ($1) on the
# `agent-turn-complete` event (the only event Codex's notify hook emits today).
# That maps to tmuxscout "done" (turn finished, Codex is waiting on you).
#
# Wire it up in ~/.codex/config.toml (top-level key, above any [table] headers):
#   notify = ["/abs/path/to/integrations/codex/codex-notify.sh"]
# Restart running Codex sessions to pick it up (config.toml is read at startup).
#
# NOTE: Codex does NOT pass TMUX/TMUX_PANE to the notify program, and in
# interactive mode the notify is fired by Codex's detached app-server (not by the
# TUI process in your pane), so walking up from notify doesn't reach the pane.
# We resolve it via, in order: $TMUX_PANE -> notify's ancestry (covers
# `codex exec`) -> the pane that actually runs the Codex TUI process -> a unique
# pane in the payload's cwd, then hand it to tmuxscout via $TMUXSCOUT_PANE.
# Only the Claude Code codex *plugin* (codex as a subagent via app-server) has no
# TUI pane of its own — there the Claude Code pane is what flags.
# Keep this fast and always exit 0 — Codex waits on it during turn finalization.

CFG="${TMUXSCOUT_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/tmuxscout/config}"
[ -f "$CFG" ] && . "$CFG"

_dbg() {
  [ "${TMUXSCOUT_DEBUG:-0}" = "1" ] || return 0
  f="${XDG_STATE_HOME:-$HOME/.local/state}/tmuxscout/debug.log"
  mkdir -p "$(dirname "$f")" 2>/dev/null || return 0
  printf '%s  [codex] %s\n' "$(date '+%H:%M:%S')" "$*" >> "$f" 2>/dev/null || true
}

# Map a PID to the tmux pane whose root process is one of its ancestors.
_pane_of() {
  _p="$1"
  while [ "${_p:-0}" -gt 1 ]; do
    _m="$(printf '%s\n' "$PANES" | awk -F'\t' -v pp="$_p" '$1==pp{print $2; exit}')"
    [ -n "$_m" ] && { printf '%s' "$_m"; return 0; }
    _p="$(awk '/^PPid:/{print $2}' "/proc/$_p/status" 2>/dev/null)"; [ -n "$_p" ] || break
  done
  return 1
}

# Resolve the tmux pane for this codex turn. Arg $1 = payload cwd.
resolve_pane() {
  [ -n "${TMUX_PANE:-}" ] && { printf '%s' "$TMUX_PANE"; return 0; }
  command -v tmux >/dev/null 2>&1 || return 0
  cwd="${1:-}"
  PANES="$(tmux list-panes -a -F '#{pane_pid}	#{pane_id}	#{pane_current_path}' 2>/dev/null)"

  # 1) notify's own ancestry (covers `codex exec`, where notify is a child).
  pane="$(_pane_of $$)" && { printf '%s' "$pane"; return 0; }

  # 2) the pane running the Codex TUI. Codex's notify is fired by the detached
  #    app-server, so instead of walking up from notify we locate the codex
  #    process (comm=codex, not an app-server daemon) and map IT to a pane.
  cand=""
  for pid in $(pgrep -x codex 2>/dev/null); do
    grep -aq app-server "/proc/$pid/cmdline" 2>/dev/null && continue
    pp="$(_pane_of "$pid")" || continue
    cand="$cand$pp
"
  done
  cand="$(printf '%s' "$cand" | grep -v '^$' | sort -u)"
  cnt="$(printf '%s\n' "$cand" | grep -c .)"
  [ "$cnt" = "1" ] && { printf '%s' "$cand"; return 0; }
  if [ "$cnt" -gt 1 ] && [ -n "$cwd" ]; then
    m="$(printf '%s\n' "$cand" | while read -r id; do
          p="$(printf '%s\n' "$PANES" | awk -F'\t' -v i="$id" '$2==i{print $3}')"
          [ "$p" = "$cwd" ] && printf '%s\n' "$id"
        done | head -n1)"
    [ -n "$m" ] && { printf '%s' "$m"; return 0; }
  fi

  # 3) cwd fallback: a UNIQUE pane sitting in the payload's cwd.
  [ -n "$cwd" ] || return 0
  matches="$(printf '%s\n' "$PANES" | awk -F'\t' -v c="$cwd" '$3==c{print $2}')"
  [ "$(printf '%s\n' "$matches" | grep -c .)" = "1" ] && printf '%s' "$matches"
  return 0
}

payload="${1:-}"
RADAR="${TMUXSCOUT_BIN:-tmuxscout}"

if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  type="$(printf '%s' "$payload" | jq -r '.type // empty' 2>/dev/null)"
  cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)"
  summary="$(printf '%s' "$payload" | jq -r '."last-assistant-message" // empty' 2>/dev/null)"
else
  type=""; cwd="$PWD"; summary=""
  printf '%s' "$payload" | grep -q '"agent-turn-complete"' && type="agent-turn-complete"
fi

[ -n "$payload" ] || exit 0
[ "$type" = "agent-turn-complete" ] || { _dbg "ignored event type='$type'"; exit 0; }

PANE="$(resolve_pane "$cwd")"
_dbg "invoked: type='$type' pane='${PANE:-none}' cwd='$cwd'"
[ -n "$PANE" ] || { _dbg "  -> skip: no resolvable codex pane (Claude-plugin subagent, or ambiguous)"; exit 0; }

label="$(basename "${cwd:-codex}")"
summary="$(printf '%s' "${summary:-Turn complete}" | cut -c1-180)"

TMUXSCOUT_PANE="$PANE" "$RADAR" mark done "$label" "$summary" >/dev/null 2>&1 || true
exit 0
