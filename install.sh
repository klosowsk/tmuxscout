#!/usr/bin/env bash
# tmuxscout installer (thin): installs fzf, puts `tmuxscout` on PATH, writes a
# default config, then runs `tmuxscout setup all` to wire the tmux UI and agents.
# All config edits happen in `setup` (idempotent, with backups). Re-runnable.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmuxscout"

say() { printf '==> %s\n' "$*"; }

say "fzf"
if command -v fzf >/dev/null 2>&1; then
  echo "    present: $(fzf --version)"
elif sudo -n true 2>/dev/null; then
  sudo apt-get update -y && sudo apt-get install -y fzf
else
  echo "    installing fzf without sudo (~/.fzf)"
  if [ ! -x "$HOME/.fzf/bin/fzf" ]; then
    rm -rf "$HOME/.fzf"
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    "$HOME/.fzf/install" --bin
  fi
  mkdir -p "$HOME/.local/bin" && ln -sf "$HOME/.fzf/bin/fzf" "$HOME/.local/bin/fzf"
fi

say "binaries + PATH symlink"
chmod +x "$HERE/bin/tmuxscout" "$HERE/bin/tmuxscout-setup" \
         "$HERE/integrations/claude-code/claude-notify.sh" \
         "$HERE/integrations/codex/codex-notify.sh"
mkdir -p "$HOME/.local/bin"
ln -sf "$HERE/bin/tmuxscout" "$HOME/.local/bin/tmuxscout"

say "config ($CFG_DIR)"
mkdir -p "$CFG_DIR"
if [ -f "$CFG_DIR/config" ]; then
  echo "    keeping existing config"
else
  cp "$HERE/config.example" "$CFG_DIR/config"
  echo "    wrote default config"
fi

say "wiring integrations (tmuxscout setup all)"
"$HERE/bin/tmuxscout" setup all

case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *)
  echo
  echo "NOTE: add ~/.local/bin to your PATH to run 'tmuxscout' directly." ;;
esac

cat <<'EOF'

OK ✓  tmuxscout installed.
  • Popup:  prefix + a        • Status:  tmuxscout doctor
  • Badge:  see 'tmuxscout setup tmux --print' to add it to your status-right
  • Wiring: re-run 'tmuxscout setup <target> [--print]' anytime
EOF
