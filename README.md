<p align="center">
  <img src="workstation/tower-dashboard.svg" alt="Tower Dashboard icon" width="128" height="128">
</p>

# Tower Dashboard

Live, read-only monitoring dashboard for my Unraid tower (`root@tower.local`),
rendered as a single tmux window over SSH. Launchable from any app launcher
as **"Tower Dashboard"**.



## Layout

Three rows, all running on the Unraid host over SSH:

| Region | Content | Source |
|---|---|---|
| Top ~60%, full width | `btop --force-utf` — CPU/cores/load, mem, disk R/W per array disk, eth0 net, processes | upstream btop |
| Middle ~40%, 50/50 split | `nvtop` (left) · `ctop -s cpu` (right) — GPU stack + container management | upstream |
| Bottom 1 row, full width | `watch -t -n 2 fan-status --line` — intake/exhaust %+RPM | this repo |

Anything interactive (lazydocker, lazygit, etc.) was deliberately moved out —
this view is pure observability.

## Repo layout

```
workstation/         # Files that live on the laptop/desktop
  unraid-dash.sh       # bash function — sourced from ~/.bashrc
  tower-dashboard      # launcher script — symlinked into ~/.local/bin
  Tower Dashboard.desktop  # XDG launcher entry
  ssh-config.snippet   # ControlMaster block to append to ~/.ssh/config
tower/               # Files that live on the Unraid host
  bin/                 # fan-status, array-status — into /boot/config/bin/
  config/              # btop.conf, ctop config, sensors-ignore-fans.conf
  go.snippet           # boot-restore lines to append to /boot/config/go
  README.md            # Unraid-side install instructions
install-workstation.sh # Idempotent installer for the workstation side
```

## Install

### Workstation

```bash
git clone <repo> ~/Repos/tower-dashboard
~/Repos/tower-dashboard/install-workstation.sh
# Then follow the printed steps: ssh config, walker refresh, new shell.
```

### Tower (Unraid)

See [`tower/README.md`](tower/README.md). Summary:

1. SCP `tower/bin/*` to `/boot/config/bin/` and `tower/config/*` into the
   matching `/boot/config/` paths.
2. Drop in static `btop` + `ctop` binaries at `/boot/config/bin/`.
3. Build `tmux-256color` terminfo into `/boot/config/terminfo/`.
4. Append `tower/go.snippet` to `/boot/config/go` (and either reboot or run
   the snippet lines manually).

## Why a launcher script + a bash function?

The launcher (`tower-dashboard`) spawns the terminal, waits for tmux to
adopt its real geometry, then `send-keys` the function. Building the layout
in a detached 80×24 session and then attaching scales every pane
proportionally on resize — the 1-row fans strip ends up as a 12-row chunk.
The poll-and-then-send dance in the launcher is the workaround.

The bash function (`unraid-dash`) does the actual tmux splits + remote
`ssh -t` for each pane. It's a function (not a script) so it can read
`$TMUX_PANE` from the calling shell.

## Required SSH `ControlMaster`

The dashboard opens 4 SSH connections; without ControlMaster they each pay a
fresh handshake and the launch feels sluggish. See
[`workstation/ssh-config.snippet`](workstation/ssh-config.snippet).

## Hostname

Defaults to `root@tower.local` (mDNS). Pass a different `user@host` as the
first argument to `unraid-dash` to override.
