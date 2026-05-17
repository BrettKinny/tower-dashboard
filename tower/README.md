# Tower (Unraid) side

Unraid is RAM-based — anything outside `/boot/` is rebuilt every boot, and
`/boot/config/` is FAT32 (so it does NOT preserve unix exec bits).
Everything below lives under `/boot/config/` and is restored at boot by
appending [`go.snippet`](go.snippet) to `/boot/config/go`.

## Layout on the Unraid host

```
/boot/config/
├── bin/
│   ├── btop                # static x86_64-musl build, v1.4.7+
│   ├── ctop                # bcicen/ctop v0.7.7 static linux-amd64
│   ├── fan-status          # from this repo (bin/fan-status)
│   └── array-status        # from this repo (bin/array-status)
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
ssh root@tower.local 'btop --version && ctop -v && fan-status --line && array-status'
```

## Hardware notes

`fan-status` reads NCT6779 hwmon2 sysfs directly:

- `pwm1`/`fan1_input` = `CHA_FAN1` = 3× intakes (Y-splitter, only master reports tach)
- `pwm3`/`fan3_input` = `CHA_FAN2` = 2× exhausts (PST-chained)
- `hwmon1/temp1_input` = `coretemp` CPU package temp

`/etc/sensors.d/zz-ignore-fans.conf` (from FanCtrlPlus) is required so
lm-sensors stops polling the fan tachs — otherwise it races our sysfs reads.

## Quirks worth not re-discovering

- **btop refuses to start over SSH** without `--force-utf` because the SSH
  session inherits no UTF-8 locale. The `unraid-dash` function passes it.
- **`watch` over SSH silently drops multi-byte UTF-8 chars.** A `°C` in a
  `printf` came through as missing. Use plain ASCII (`C`) in anything that
  gets watched over SSH.
- **btop config booleans are lowercase** (`true`/`false`). Capitalized `False`
  is silently ignored.
- **ctop's `-s` requires a sort-field arg** (name/cpu/mem/state/uptime);
  `ctop -s` alone errors.
- **5-pane tmux layouts with mixed sizing** are a pain with
  `tmux select-layout tiled` — it rebalances everything including thin status
  strips. Solution: split the 1-row fans strip off first, then build the rest
  with manual `-p`/`-l` splits and skip `select-layout` entirely.
