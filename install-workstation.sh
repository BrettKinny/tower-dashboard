#!/bin/bash
# Idempotent installer for the workstation side of Tower Dashboard.
# - Symlinks the launcher into ~/.local/bin
# - Symlinks the .desktop entry into ~/.local/share/applications
# - Symlinks the SVG icon into ~/.local/share/icons/hicolor/scalable/apps
# - Ensures the unraid-dash function is sourced from ~/.bashrc
# - Refreshes the XDG desktop database so launchers pick up the new entry
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$HOME/.local/bin" \
         "$HOME/.local/share/applications" \
         "$HOME/.local/share/icons/hicolor/scalable/apps"

ln -sfv "$REPO/workstation/tower-dashboard"        "$HOME/.local/bin/tower-dashboard"
ln -sfv "$REPO/workstation/Tower Dashboard.desktop" "$HOME/.local/share/applications/Tower Dashboard.desktop"
ln -sfv "$REPO/workstation/tower-dashboard.svg"    "$HOME/.local/share/icons/hicolor/scalable/apps/tower-dashboard.svg"
chmod +x "$REPO/workstation/tower-dashboard"

SOURCE_LINE="[ -f \"$REPO/workstation/unraid-dash.sh\" ] && source \"$REPO/workstation/unraid-dash.sh\""
if ! grep -Fqs "$REPO/workstation/unraid-dash.sh" "$HOME/.bashrc"; then
  {
    echo ""
    echo "# tower-dashboard: unraid-dash tmux function"
    echo "$SOURCE_LINE"
  } >> "$HOME/.bashrc"
  echo "Appended unraid-dash source line to ~/.bashrc"
else
  echo "unraid-dash already sourced from ~/.bashrc — skipping"
fi

# Refresh the XDG desktop database so launchers (walker, rofi, GNOME, KDE, …)
# pick up the new "Tower Dashboard" entry without a logout.
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
  echo "Refreshed XDG desktop database"
fi

cat <<'EOF'

Next steps:
  1. Append workstation/ssh-config.snippet to ~/.ssh/config and edit the host
     line to point at your Unraid tower. SSH ControlMaster is a launch-speed
     optimization, not strictly required.
  2. Customize via env vars in your shell rc (all optional; defaults shown):
       export TOWER_HOST=root@tower.local   # SSH target
       export TOWER_SESSION=tower           # tmux session name
       export TOWER_WINDOW=unraid           # tmux window name
       export TERMINAL=ghostty              # override terminal autodetect
  3. Install the tower-side companion scripts on Unraid — see tower/README.md.
  4. Open a new shell (or `source ~/.bashrc`) to pick up unraid-dash.
EOF
