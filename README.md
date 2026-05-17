<p align="center">
  <img src="workstation/tower-dashboard.svg" alt="Tower Dashboard icon" width="128" height="128">
</p>

# Tower Dashboard

A live, read-only monitoring dashboard for your Unraid tower, rendered as a
single tmux window over SSH and launchable from any XDG app launcher as
**"Tower Dashboard"**. One click, one keystroke, one window — everything you
need to glance at to know the box is healthy.



## Layout

Three rows, all running on the Unraid host over SSH:

| Region | Content | Source |
|---|---|---|
| Top ~60%, full width | `btop --force-utf` — CPU/cores/load, mem, disk R/W per array disk, eth0 net, processes | upstream btop |
| Middle ~40%, 50/50 split | `nvtop` (left) · `ctop -s cpu` (right) — GPU stack + container management | upstream |
| Bottom 1 row, full width | `watch -t -n 2 fan-status --line` — intake/exhaust %+RPM | this repo |

Anything interactive (lazydocker, lazygit, etc.) was deliberately moved out —
this view is pure observability.

## Why this over the alternatives?

- **vs. the Unraid web UI** — the WebGUI lives behind a tab and refreshes
  slowly. This is one keystroke (`tdl` → "Tower Dashboard") and updates in
  real time. No browser, no bookmark, no auth.
- **vs. Glances / Beszel / Netdata** — those are excellent dashboards that
  require a daemon on the tower, a port, and (usually) a browser. This is
  zero new daemons: it's `btop` + `nvtop` + `ctop` + a tiny fan script,
  composed in tmux. Read-only by design.
- **vs. `ssh root@tower htop`** — htop is one pane. This is the four panes
  you actually want, laid out at the right sizes, with the right tools for
  each (btop for storage I/O, nvtop for GPU, ctop for containers, custom
  script for fan PWM).

## Repo layout

```
workstation/         # Files that live on the laptop/desktop
  unraid-dash.sh       # bash function — sourced from ~/.bashrc
  tower-dashboard      # launcher script — symlinked into ~/.local/bin
  tower-dashboard.svg  # icon — symlinked into ~/.local/share/icons/.../apps/
  Tower Dashboard.desktop  # XDG launcher entry
  ssh-config.snippet   # ControlMaster block template to append to ~/.ssh/config
tower/               # Files that live on the Unraid host
  bin/                 # fan-status, array-status — into /boot/config/bin/
  config/              # btop.conf, ctop config, sensors-ignore-fans.conf
  go.snippet           # boot-restore lines to append to /boot/config/go
  README.md            # Unraid-side install instructions
install-workstation.sh # Idempotent installer for the workstation side
LICENSE              # MIT
```

## Install

### Workstation

```bash
git clone https://github.com/BrettKinny/tower-dashboard ~/Repos/tower-dashboard
~/Repos/tower-dashboard/install-workstation.sh
```

The installer is idempotent (safe to re-run): it symlinks the launcher,
`.desktop` entry, and icon into the right XDG dirs, appends a source line for
the `unraid-dash` bash function to `~/.bashrc`, and refreshes the desktop
database so launchers pick up the new entry.

Then follow the printed steps: append the SSH `ControlMaster` snippet,
optionally export the env vars below, and install the tower side.

### Tower (Unraid)

See [`tower/README.md`](tower/README.md). Summary:

1. SCP `tower/bin/*` to `/boot/config/bin/` and `tower/config/*` into the
   matching `/boot/config/` paths.
2. Drop in static `btop` + `ctop` binaries at `/boot/config/bin/`.
3. Build `tmux-256color` terminfo into `/boot/config/terminfo/` (one-liner).
4. Append `tower/go.snippet` to `/boot/config/go` and either reboot or run
   the snippet lines manually.

## Customize

Everything machine-specific is reachable via env vars, so you should rarely
need to fork.

### Workstation side (set in `~/.bashrc` or shell rc)

| Var | Default | What it does |
|---|---|---|
| `TOWER_HOST` | `root@tower.local` | SSH target passed through to `unraid-dash` |
| `TOWER_SESSION` | `tower` | tmux session name to host the dashboard window in |
| `TOWER_WINDOW` | `unraid` | tmux window name within that session |
| `TERMINAL` | autodetected | Override terminal autodetection (otherwise tries `xdg-terminal-exec`, `ghostty`, `kitty`, `alacritty`, `foot`, `wezterm`, `gnome-terminal`, `konsole`, `xterm` in that order) |

### Tower side — `fan-status` hardware mapping

`fan-status` defaults match an Asus board with NCT6779 superio + Intel
coretemp + 3-intake/2-exhaust fan wiring. To adapt:

```bash
ssh root@tower.local fan-status --detect   # lists all hwmon chips + their pwm/fan/temp inputs
```

Then export overrides on the tower side (e.g. in `/etc/profile.d/` or via the
unraid-dash SSH command), or edit the defaults at the top of the script:

| Var | Default | Notes |
|---|---|---|
| `TOWER_INTAKE_CHIP` | `nct6779` | Chip name (prefix-matched against `/sys/class/hwmon/*/name`) |
| `TOWER_EXHAUST_CHIP` | `nct6779` | Same chip in most setups |
| `TOWER_TEMP_CHIP` | `coretemp` | `k10temp` for AMD |
| `TOWER_INTAKE_NUM` | `1` | `pwm1` + `fan1_input` |
| `TOWER_EXHAUST_NUM` | `3` | `pwm3` + `fan3_input` |
| `TOWER_TEMP_NUM` | `1` | `temp1_input` |

### Tower side — `btop` array disks

Edit `disks_filter` in [`tower/config/btop/btop.conf`](tower/config/btop/btop.conf)
to match your array (Unraid's `/etc/fstab` doesn't list array mounts, so an
explicit filter is required).

## Why a launcher script + a bash function?

The launcher (`tower-dashboard`) spawns the terminal, waits for tmux to adopt
its real geometry, then `send-keys` the function. Building the layout in a
detached 80×24 session and then attaching scales every pane proportionally on
resize — the 1-row fans strip ends up as a 12-row chunk. The poll-and-then-send
dance in the launcher is the workaround.

The bash function (`unraid-dash`) does the actual tmux splits + remote `ssh -t`
for each pane. It's a function (not a script) so it can read `$TMUX_PANE` from
the calling shell and run inside the existing tmux session.

## Required SSH `ControlMaster`

The dashboard opens 4 SSH connections; without ControlMaster they each pay a
fresh handshake and the launch feels sluggish. See
[`workstation/ssh-config.snippet`](workstation/ssh-config.snippet).

## License

MIT — see [LICENSE](LICENSE).
