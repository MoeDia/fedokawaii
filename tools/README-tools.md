# tools/ — how each is called (one screen)

| tool | what | call |
|---|---|---|
| `hl-dwl.sh` | a headless dwl on the real GPU (1920x1080@144, own runtime dir, wtype input, frame log on); `--asan` builds the tree with AddressSanitizer in /tmp | `bash tools/hl-dwl.sh SCRIPT [--dwl BIN] [--asan] [--time S] [--keep DIR]` |
| dwl's frame log | every frame, present, key, button, move, new window, animation step (F/H/P/K/B/M/W/A lines, µs on CLOCK_MONOTONIC) | `DWL_FRAMELOG=FILE dwl …`, or `kill -USR2 $(pgrep -x dwl)` on/off → `$XDG_RUNTIME_DIR/dwl-frames.log` |
| `framestat.py` | reads the frame log: dropped frames in moving streaks, build µs, key→glass, press→window; `--anim` each animation's steps; `--strict` exit 3 on a drop | `python3 tools/framestat.py LOG [--from T --to T] [--hz N] [--anim] [--strict] [--json]` |
| `perf.sh` | the before/after protocol in the live session (idle, boot, terminals, switches, typing, menus, nvim) | `bash tools/perf.sh [OUTDIR]` · `--again OUTDIR` |
| `shot.sh` | grim of the live session (or a headless run), `--both` themes | `bash tools/shot.sh NAME [--region "X,Y WxH"] [--runtime DIR] [--both]` → /dev/shm/r27/ |
| `px.py` | pixel measurement: runs (stripes), boxes, gaps, centre, hist, diff, zoom | `python3 tools/px.py --help` |
| `hotplug-test.sh` | a real monitor unplug/replug on the free GPU (root) with X11 windows (`xconf.c`) | `sudo bash tools/hotplug-test.sh [DWL]` (`CYCLES=N`) |
| `dwl-patch.sh` | `src/dwl/dwl.patch` from the edited tree — before `fedokawaii apply` | `bash tools/dwl-patch.sh [TREE]` |
| `selftest.sh` | the installed system checked from a copy | `fedokawaii selftest [--sandbox]` |
| `start.sh` / `claude-loop.sh` | round 27's autonomous loop (a user service) | `bash tools/start.sh [stop\|status]` |
| `build-*.py` | fonts, icons, themes, cursors, art from the repo's sources | each prints `--help` |

Rules: timing comes from the frame log only (a recorder perturbs frames); big recordings go to /dev/shm
and are deleted; nothing here touches the live session except `perf.sh`/`shot.sh` (they drive or
read it) and `hotplug-test.sh` (another card, root).
