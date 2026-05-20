# Tower (Unraid) side

The dashboard runs as a tmux session **on the Unraid box itself** — the
workstation just attaches to it over one SSH connection. So the box needs
`tmux`, the `tower-dash` builder script, and the four monitors it lays out
(`btop`, `nvtop`, `ctop`, `fan-status`).

Unraid is RAM-based — anything outside `/boot/` is rebuilt every boot, and
`/boot/config/` is FAT32 (so it does NOT preserve unix exec bits). Everything
this repo installs lives under `/boot/config/` and is restored at boot by
appending [`go.snippet`](go.snippet) to `/boot/config/go`.

## Requirements on the box

- **tmux** — install the **NerdTools** plugin (Unraid *Apps* tab), then enable
  `tmux` under *Settings → NerdTools*. NerdTools re-installs it on every boot,
  so tmux does NOT need a `/boot/config/go` line of its own.
- **nvtop** — install the **nvtop** plugin (Unraid *Apps* tab).
- **btop**, **ctop** — static x86_64 binaries dropped at `/boot/config/bin/`.
- **fan-status**, **array-status**, **tower-dash** — from this repo.

## Layout on the Unraid host

```
/boot/config/
├── bin/
│   ├── btop                # static x86_64-musl build, v1.4.7+
│   ├── ctop                # bcicen/ctop v0.7.7 static linux-amd64
│   ├── fan-status          # from this repo (bin/fan-status)
│   ├── array-status        # from this repo (bin/array-status)
│   └── tower-dash          # from this repo (bin/tower-dash) — builds the tmux dashboard
├── btop/btop.conf          # from this repo (config/btop/btop.conf)
├── ctop/config             # from this repo (config/ctop/config)
├── sensors-ignore-fans.conf  # from this repo (config/sensors.d/zz-ignore-fans.conf)
├── terminfo/t/tmux-256color  # built via `infocmp tmux-256color | tic -x -o ...`
└── go                      # boot script — append go.snippet contents
```

## Install

From the workstation:

```bash
HOST=root@tower.local

# Companion scripts + binaries (download btop/ctop separately).
scp tower/bin/fan-status     "$HOST:/boot/config/bin/fan-status"
scp tower/bin/array-status   "$HOST:/boot/config/bin/array-status"
scp tower/bin/tower-dash     "$HOST:/boot/config/bin/tower-dash"

# Configs.
ssh "$HOST" 'mkdir -p /boot/config/btop /boot/config/ctop'
scp tower/config/btop/btop.conf            "$HOST:/boot/config/btop/btop.conf"
scp tower/config/ctop/config               "$HOST:/boot/config/ctop/config"
scp tower/config/sensors.d/zz-ignore-fans.conf "$HOST:/boot/config/sensors-ignore-fans.conf"

# tmux-256color terminfo (build it on the workstation first).
ssh "$HOST" 'mkdir -p /boot/config/terminfo/t'
infocmp tmux-256color | ssh "$HOST" 'tic -x -o /boot/config/terminfo -'

# Then append go.snippet to /boot/config/go and reboot, or run the snippet
# lines manually for an immediate install without rebooting.
```

After install, verify from the workstation:

```bash
ssh root@tower.local 'tmux -V && btop --version && ctop -v && fan-status --line'
```

Then open the dashboard with `tower-dashboard` on the workstation (or its
"Tower Dashboard" launcher entry). The first launch builds the `dash` tmux
session on the box; later launches just re-attach to it.

## How the dashboard is built

`tower-dash` builds a detached tmux session named `dash` with the three-row
layout, sized to the calling terminal, then attaches. It only builds once —
subsequent runs (and subsequent `tower-dashboard` launches from the
workstation) re-attach to the warm session. The monitors keep running on the
box between launches; the session lives until the box reboots.

- `tower-dash`        — build if needed, then attach (default)
- `tower-dash build`  — build the detached session only, don't attach
- `tower-dash kill`   — tear the session down

Each pane runs its monitor in a `while :; do …; sleep 2; done` loop, so a
crash (or an accidental `q`) brings the monitor back instead of leaving a dead
shell — or, for the first pane, taking the whole session down.

## Hardware notes

`fan-status` reads NCT6779 hwmon2 sysfs directly:

- `pwm1`/`fan1_input` = `CHA_FAN1` = 3× intakes (Y-splitter, only master reports tach)
- `pwm3`/`fan3_input` = `CHA_FAN2` = 2× exhausts (PST-chained)
- `hwmon1/temp1_input` = `coretemp` CPU package temp

`/etc/sensors.d/zz-ignore-fans.conf` (from FanCtrlPlus) is required so
lm-sensors stops polling the fan tachs — otherwise it races our sysfs reads.

## Quirks worth not re-discovering

- **btop wants `--force-utf`** — Unraid's default locale isn't UTF-8, so btop
  bails on box-drawing glyphs without it. `tower-dash` passes it.
- **`watch(1)` exits on a 1-row terminal**, so the fan strip doesn't use it —
  `tower-dash` loops `fan-status --line` onto the strip itself with a shell
  loop and an ANSI repaint. (`fan-status` output stays plain ASCII anyway, so
  it renders cleanly even under a non-UTF-8 locale.)
- **btop config booleans are lowercase** (`true`/`false`). Capitalized `False`
  is silently ignored.
- **ctop's `-s` requires a sort-field arg** (name/cpu/mem/state/uptime);
  `ctop -s` alone errors.
- **Build the 1-row fan strip before the column split.** `tower-dash` carves
  the full-width fan strip off the bottom first, then splits the middle row
  50/50, and sets a `window-resized` hook that re-pins the strip to 1 row — so
  attaching a differently-sized client can't scale it into a fat band.
- **The terminfo entry still matters.** tmux runs the panes with
  `TERM=tmux-256color`; the matching terminfo must exist on the box (the
  `go.snippet` restores it from `/boot/config/terminfo/`), or btop/nvtop bail
  with `ncurses: cannot initialize terminal type`.
```

