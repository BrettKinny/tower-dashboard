#!/bin/bash
# unraid-dash — live Unraid monitoring dashboard in a tmux window.
# Source this from ~/.bashrc (or copy the function into it).
#
# Layout (top → bottom):
#   • btop --force-utf       (top ~60%, full width)
#   • nvtop | ctop           (middle ~40%, 50/50 split)
#   • watch fan-status --line (bottom 1-row strip, full width)
#
# Usage: unraid-dash [user@host]   (defaults to root@tower.local)
unraid-dash() {
  [[ -z $TMUX ]] && { echo "You must start tmux to use unraid-dash."; return 1; }

  local host="${1:-root@tower.local}"
  local btop_pane="$TMUX_PANE"
  local nvtop_pane ctop_pane fans_pane

  tmux rename-window -t "$btop_pane" "unraid"

  # Three rows: btop (top ~60%), nvtop|ctop equal split (middle ~40%), fan-status (1-row strip, full width).
  nvtop_pane=$(tmux split-window -v -p 40 -t "$btop_pane" -P -F '#{pane_id}')
  # Carve the 1-row fan strip off the bottom of the middle row before splitting it horizontally.
  fans_pane=$(tmux split-window -v -l 1 -t "$nvtop_pane" -P -F '#{pane_id}')
  # Now split the (slightly shorter) middle row 50/50 into nvtop | ctop.
  ctop_pane=$(tmux split-window -h -p 50 -t "$nvtop_pane" -P -F '#{pane_id}')

  tmux send-keys -t "$btop_pane"   "ssh $host -t 'btop --force-utf'" C-m
  tmux send-keys -t "$nvtop_pane"  "ssh $host -t nvtop" C-m
  # ctop: sort by CPU, default-dark theme inherits the terminal's ANSI palette
  tmux send-keys -t "$ctop_pane"   "ssh $host -t 'CTOP_THEME=default-dark ctop -s cpu'" C-m
  # watch -t suppresses the 2-line title header; --line collapses fan-status to a single row
  tmux send-keys -t "$fans_pane"   "ssh $host -t 'watch -t -n 2 fan-status --line'" C-m

  tmux select-pane -t "$btop_pane"
}
