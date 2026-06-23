# tmuxscout demo — render a GIF with:  vhs scripts/demo.tape
# Requires: vhs + ttyd + ffmpeg, and tmuxscout installed (on PATH).
Output docs/demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 1320
Set Height 760
Set Padding 14
Set Theme "Catppuccin Mocha"

# --- set up the scenario off-camera, then attach ---
Hide
Type "bash scripts/demo.sh up" Enter
Sleep 2.5s
Type "clear; tmux -L scoutdemo attach -t web" Enter
Sleep 2s
Show

# badge is visible in the status bar (⏳ 2  ✅ 2)
Sleep 2s

# open the popup: tmux prefix (C-b) then a
Ctrl+b
Type "a"
Sleep 3s
Down
Sleep 1500ms
Down
Sleep 1500ms
# jump to the highlighted agent
Enter
Sleep 2500ms

# open it again to show the badge dropped after visiting
Ctrl+b
Type "a"
Sleep 3s
Escape
Sleep 1500ms

# --- tear down off-camera ---
Hide
Ctrl+b
Type "d"
Sleep 500ms
Type "bash scripts/demo.sh down" Enter
Sleep 1s
