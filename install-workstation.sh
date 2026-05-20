#!/bin/bash
# Idempotent installer for the workstation side of Tower Dashboard.
# - Symlinks the launcher into ~/.local/bin
# - Renders the .desktop entry (template → absolute Exec path) into ~/.local/share/applications
# - Symlinks the SVG icon into ~/.local/share/icons/hicolor/scalable/apps
# - Adds an 'unraid-dash' convenience alias to ~/.bashrc
# - Refreshes the XDG desktop database so launchers pick up the new entry
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
BIN_PATH="$HOME/.local/bin/tower-dashboard"
DESKTOP_PATH="$HOME/.local/share/applications/Tower Dashboard.desktop"

mkdir -p "$HOME/.local/bin" \
         "$HOME/.local/share/applications" \
         "$HOME/.local/share/icons/hicolor/scalable/apps"

ln -sfv "$REPO/workstation/tower-dashboard"        "$BIN_PATH"
ln -sfv "$REPO/workstation/tower-dashboard.svg"    "$HOME/.local/share/icons/hicolor/scalable/apps/tower-dashboard.svg"
chmod +x "$REPO/workstation/tower-dashboard"

# Render the .desktop from its template with an absolute Exec path. Symlinking
# the template directly would leave Exec=tower-dashboard unqualified, which
# some launchers (notably walker on omarchy) won't resolve even when
# ~/.local/bin is in the systemd-user PATH — they raise "Command not found".
# Writing a real local file with an absolute path is deterministic.
sed "s|@BIN_PATH@|$BIN_PATH|g" "$REPO/workstation/Tower Dashboard.desktop.in" > "$DESKTOP_PATH"
echo "Rendered $DESKTOP_PATH (Exec=$BIN_PATH)"

# 'unraid-dash' is a convenience alias for the launcher — handy from a shell.
if ! grep -Fqs "alias unraid-dash=" "$HOME/.bashrc"; then
  {
    echo ""
    echo "# tower-dashboard: shell alias for the launcher"
    echo "alias unraid-dash='tower-dashboard'"
  } >> "$HOME/.bashrc"
  echo "Appended 'unraid-dash' alias to ~/.bashrc"
else
  echo "'unraid-dash' alias already in ~/.bashrc — skipping"
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
     line to point at your Unraid box. Make sure the hostname resolves — if you
     rely on mDNS (.local) and it's flaky, pin the box in /etc/hosts instead.
  2. Install the tower side — see tower/README.md. The dashboard now runs as a
     tmux session ON the box, so the box needs tmux (via the NerdTools plugin)
     plus the tower-dash script and the btop/nvtop/ctop/fan-status tools.
  3. Customize via env vars in your shell rc (optional; defaults shown):
       export TOWER_HOST=root@tower.local   # SSH target
       export TERMINAL=ghostty              # override terminal autodetect
EOF
