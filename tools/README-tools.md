# tools/ — how each is called (one screen)

| tool | what | call |
|---|---|---|
| `hl-dwl.sh` | a headless dwl on the real GPU (1920x1080@144, own runtime dir, a PID namespace of its own — ps and kill inside see only the run —, wtype input, frame log on); `--asan` builds the tree with AddressSanitizer in /tmp | `bash tools/hl-dwl.sh SCRIPT [--dwl BIN] [--asan] [--time S] [--keep DIR]` |
| dwl's frame log | every frame, present, key, button, move, new window, animation step (F/H/P/K/B/M/W/A lines, µs on CLOCK_MONOTONIC) | `DWL_FRAMELOG=FILE dwl …`, or `kill -USR2 $(pgrep -x dwl)` on/off → `$XDG_RUNTIME_DIR/dwl-frames.log` |
| `framestat.py` | reads the frame log: dropped frames in moving streaks, build µs, key→glass, press→window; `--anim` each animation's steps; `--strict` exit 3 on a drop | `python3 tools/framestat.py LOG [--from T --to T] [--hz N] [--anim] [--strict] [--json]` |
| `perf.sh` | the before/after protocol in the live session (idle, boot, terminals, switches, typing, menus, nvim) | `bash tools/perf.sh [OUTDIR]` · `--again OUTDIR` |
| `nvim-bench.py` | Neovim in a pty that answers as foot does (a PID namespace, no display or bus, a throw-away home): first frame, full screen, exit, each plugin's load, each key to its redraw and how many frames it took; a variant is a config with parts off | `python3 -B tools/nvim-bench.py sandbox DIR --config NAME=PATH` · `start` · `keys` · `first` · `check` |
| `shot.sh` | grim of the live session (or a headless run), `--both` themes | `bash tools/shot.sh NAME [--region "X,Y WxH"] [--runtime DIR] [--both]` → /dev/shm/r27/ |
| `px.py` | pixel measurement: runs (stripes), boxes, gaps, centre, hist, diff, zoom | `python3 tools/px.py --help` |
| `kit.sh` | the real surfaces in a headless dwl from a throw-away home (the installed configs; dwl itself in that home): the bar, notices, the launcher, quick settings, Super+U and its tabs, a mock TUI — or a play | `bash tools/kit.sh [--theme dark\|light] [--bin bin] [--time S] [--out DIR] SCENE…` · `--play FILE play` |
| `kit-play.sh` | a play's words (sourced by the kit): `at X Y`, `by`, `click`, `key`, `chord logo u`, `text`, `shot NAME [X,Y WxH]`, `panel`, `warm`, `nap`, `say` — the pointer through wlrctl, the keys through wtype | a play is a file of those lines |
| `vpointer.c` | a virtual pointer that sends what a real mouse wheel sends (axis_discrete) or a touchpad's part — wlrctl's scroll is a touchpad's only; for a headless dwl | build: its header (wayland-scanner + cc, the XML in `tools/protocols/`) · `vpointer wheel N` · `finger DY` · `move X Y` |
| `hotplug-test.sh` | a real monitor unplug/replug on the free GPU (root) with X11 windows (`xconf.c`) | `sudo bash tools/hotplug-test.sh [DWL]` (`CYCLES=N`) |
| `dwl-patch.sh` | `src/dwl/dwl.patch` from the edited tree — before `fedokawaii apply` | `bash tools/dwl-patch.sh [TREE]` |
| `selftest.sh` | the installed system checked from a copy | `fedokawaii selftest [--sandbox]` |
| `regress/*.sh` | never again: one headless check per reported bug or measured surface (`menu-first-click`, `calendar-middle`, `one-popup`, `nvim-start`, `bar-geometry`, `window-frame`, `level-display`, `warm-exit`, `notes-page`, `wheel-notch` (a real mouse notch from `vpointer.c`); `no-xwayland-exit` and `term-burst` take a dwl binary, not kit options), each passing on the fixed build and failing on the old one; `regress/shots.py` measures their shots | `bash tools/regress/NAME.sh [KIT OPTION…]` (`--bin bin --repo-art`: the repository's state) |
| `vm-create.sh` / `vm-snap.sh` / `vm-run.sh` | the harness VM (a kickstart install of Fedora, passt ssh on a local port): saved states as reflink copies; a command, the repo's working tree, a file in or out | `bash tools/vm-create.sh NAME` · `vm-snap.sh NAME start\|stop\|save S\|revert S\|list` · `vm-run.sh NAME CMD\|--repo [DIR]\|--get P OUT\|--wait` |
| `vm-clone.sh` | a second harness VM from one (reflinked states, its own disk, UEFI variables and port) — two proofs side by side | `bash tools/vm-clone.sh SRC NAME [--port P]` |
| `vm-inject/*.sh` | the update system's failures injected in the VM, each ending in a table: `restore-cut.sh` (kawa-snap restore cut at each step), `split-cut.sh` (the flat layout: whole, cut at each step, put back after a failure), `update-green.sh` (the button on the VM's real pending updates) | `bash tools/vm-inject/NAME.sh [VM] [STEP…]` |
| `start.sh` / `claude-loop.sh` | round 27's autonomous loop (a user service) | `bash tools/start.sh [stop\|status]` |
| `build-*.py` | fonts, icons, themes, cursors, art from the repo's sources | each prints `--help` |

Rules: timing comes from the frame log only (a recorder perturbs frames); big recordings go to /dev/shm
and are deleted; nothing here touches the live session except `perf.sh`/`shot.sh` (they drive or
read it) and `hotplug-test.sh` (another card, root).
