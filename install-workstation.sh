#!/bin/bash
# Idempotent installer for the workstation side of Tower Dashboard.
# - Symlinks the launcher into ~/.local/bin
# - Symlinks the .desktop entry into ~/.local/share/applications
# - Ensures the unraid-dash function is sourced from ~/.bashrc
# - Prints follow-up steps for SSH ControlMaster + walker refresh
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/scalable/apps"

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

cat <<'EOF'

Next steps (manual):
  1. Append workstation/ssh-config.snippet to ~/.ssh/config (or set up your
     own ControlMaster block for tower.local / 192.168.1.67).
  2. Run `omarchy restart walker` (or your launcher's equivalent) so the
     "Tower Dashboard" entry shows up.
  3. Open a new shell (or `source ~/.bashrc`) to pick up unraid-dash.
  4. See tower/README for the Unraid-side install.
EOF
