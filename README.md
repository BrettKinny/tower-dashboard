<p align="center">
  <img src="workstation/tower-dashboard.svg" alt="Tower Dashboard icon" width="128" height="128">
</p>

# Tower Dashboard: a TUI for monitoring your Unraid box

A live, read-only monitoring dashboard for **Unraid**: `btop`, `nvtop`, `ctop`,
and a custom `fan-status` strip composed in a tmux session that runs **on the
box itself**. The workstation just attaches to it over a single SSH connection,
launchable from any XDG app launcher. One click, one keystroke, one window —
everything you need to glance at to know the box is healthy.

![Tower Dashboard screenshot](https://github.com/user-attachments/assets/f715879b-fd18-4847-b6df-f2c1da0fc7c2)
<sub>Running in `foot` on [omarchy](https://omarchy.org) with the etherial theme.</sub>

> **Built for Unraid.** The tower-side pieces are Unraid-coupled (`mdcmd`,
> `/mnt/disk*` / `/mnt/cache` / `/mnt/user`, RAM-FS restored from
> `/boot/config/go`). The workstation-side launcher will happily SSH into any
> Linux host, but the array-status and boot-restore bits assume Unraid.

> **Shared as a starting point, not a finished product.** Fork it, rip out
> what doesn't match your box, rewire the rest. The generalizable bits — the
> tmux composition pattern, the hwmon-via-sysfs fan reader, the
> FAT32-survives-boot install dance via `/boot/config/go` — are the parts
> worth lifting even if your stack looks nothing like mine.

## Layout

Three rows, all running on the Unraid host inside a server-side tmux session:

| Region | Content | Source |
|---|---|---|
| Top ~60%, full width | `btop --force-utf` — CPU/cores/load, mem, disk R/W per array disk, eth0 net, processes | upstream btop |
| Middle ~40%, 50/50 split | `nvtop` (left) · `ctop -s cpu` (right) — GPU stack + container management | upstream |
| Bottom 1 row, full width | `fan-status --line` on a 2-second refresh — intake/exhaust %+RPM | this repo |

Anything interactive (lazydocker, lazygit, etc.) was deliberately moved out —
this view is pure observability.

## How it works

The dashboard is a tmux session named `dash` that lives **on the Unraid box**:

- **`tower/bin/tower-dash`** (on the box) builds that session — the three-row
  layout, each pane running its monitor in a restart loop — then attaches. It
  builds once; every later run re-attaches to the warm session.
- **`workstation/tower-dashboard`** (on the workstation) is the launcher: it
  spawns a fresh terminal that runs `ssh -t <box> tower-dash`. That's the whole
  client side — one SSH connection, no client-side tmux, no layout logic.

Because the session lives on the box, the monitors stay warm between launches
and survive the workstation disconnecting — re-opening is instant. The session
lasts until the box reboots (or until `tower-dash kill` ends it sooner).

> Earlier versions built the layout client-side and drove it over `send-keys`
> at attach time, which needed a fragile geometry-poll dance to keep the 1-row
> fan strip from scaling into a fat band. Building the layout on the box, sized
> to the caller's terminal, removed all of that.

## Why this over the alternatives?

- **vs. the Unraid web UI** — the WebGUI lives behind a tab and refreshes
  slowly. This is one keystroke ("Tower Dashboard" in your launcher) and
  updates in real time. No browser, no bookmark, no auth.
- **vs. Glances / Beszel / Netdata** — those are excellent dashboards that
  want a daemon on the box, a port, and (usually) a browser. This is no web
  daemon and no port: just `tmux` plus the TUI tools you'd run by hand anyway.
  Read-only by design.
- **vs. `ssh root@tower htop`** — htop is one pane. This is the four panes you
  actually want, laid out at the right sizes, with the right tool for each
  (btop for storage I/O, nvtop for GPU, ctop for containers, custom script for
  fan PWM).

## Repo layout

```
workstation/         # Files that live on the laptop/desktop
  tower-dashboard      # launcher — spawns a terminal, SSHes in, attaches
  tower-dashboard.svg  # icon — symlinked into ~/.local/share/icons/.../apps/
  Tower Dashboard.desktop.in  # XDG launcher entry template (Exec=@BIN_PATH@)
  ssh-config.snippet   # optional SSH ControlMaster block for ~/.ssh/config
tower/               # Files that live on the Unraid host
  bin/                 # tower-dash, fan-status, array-status — into /boot/config/bin/
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

The installer is idempotent (safe to re-run): it symlinks the launcher script
and icon into the right XDG dirs, renders the `.desktop` entry from its
template with an absolute `Exec=` path (some launchers — notably walker on
omarchy — don't resolve `~/.local/bin` from unqualified Exec lines), adds an
`unraid-dash` shell alias to `~/.bashrc`, and refreshes the desktop database
so launchers pick up the new entry.

Then follow the printed steps: append the SSH snippet, optionally export the
env vars below, and install the tower side.

### Tower (Unraid)

See [`tower/README.md`](tower/README.md). Summary:

1. Install **tmux** (NerdTools plugin) and **nvtop** (nvtop plugin) from the
   Unraid Apps tab.
2. SCP `tower/bin/*` to `/boot/config/bin/` and `tower/config/*` into the
   matching `/boot/config/` paths.
3. Drop in static `btop` + `ctop` binaries at `/boot/config/bin/`.
4. Build `tmux-256color` terminfo into `/boot/config/terminfo/` (one-liner).
5. Append `tower/go.snippet` to `/boot/config/go` and either reboot or run the
   snippet lines manually.

## Customize

Everything machine-specific is reachable via env vars, so you should rarely
need to fork.

### Workstation side (set in `~/.bashrc` or shell rc)

| Var | Default | What it does |
|---|---|---|
| `TOWER_HOST` | `root@tower.local` | SSH target the launcher connects to |
| `TERMINAL` | autodetected | Override terminal autodetection (otherwise tries `xdg-terminal-exec`, `ghostty`, `kitty`, `alacritty`, `foot`, `wezterm`, `gnome-terminal`, `konsole`, `xterm` in that order) |

### Tower side — `fan-status` hardware mapping

`fan-status` defaults match an Asus board with NCT6779 superio + Intel
coretemp + 3-intake/2-exhaust fan wiring. To adapt:

```bash
ssh root@tower.local fan-status --detect   # lists all hwmon chips + their pwm/fan/temp inputs
```

Then export overrides on the tower side (e.g. in `/etc/profile.d/`), or edit
the defaults at the top of the script:

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

## SSH

The dashboard uses a **single** SSH connection — it attaches to the tmux
session on the box. [`workstation/ssh-config.snippet`](workstation/ssh-config.snippet)
has an optional `ControlMaster` block; it's no longer required (there's only
one connection), but it's harmless and still speeds up any other SSH to the
box. The launcher pins `TERM=xterm-256color` for the remote tmux, because the
box's RAM-FS won't have terminfo for `xterm-ghostty` / `xterm-kitty` and friends.

## License

MIT — see [LICENSE](LICENSE).
