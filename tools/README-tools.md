# tools/ — how each is called (one screen)

| tool | what | call |
|---|---|---|
| `hl-dwl.sh` | a headless dwl on the real GPU (1920x1080@144, own runtime dir, a PID namespace of its own — ps and kill inside see only the run —, wtype input, frame log on); `--asan` builds the tree with AddressSanitizer in /tmp | `bash tools/hl-dwl.sh SCRIPT [--dwl BIN] [--asan] [--time S] [--keep DIR]` |
| dwl's frame log | every frame, present, key, button, move, new window, animation step (F/H/P/K/B/M/W/A lines, µs on CLOCK_MONOTONIC) | `DWL_FRAMELOG=FILE dwl …`, or `kill -USR2 $(pgrep -x dwl)` on/off → `$XDG_RUNTIME_DIR/dwl-frames.log` |
| `framestat.py` | reads the frame log: dropped frames in moving streaks, build µs, key→glass, press→window; `--anim` each animation's steps; `--strict` exit 3 on a drop | `python3 tools/framestat.py LOG [--from T --to T] [--hz N] [--anim] [--strict] [--json]` |
| `perf.sh` | the before/after protocol in the live session (idle, boot, terminals, switches, typing, menus, nvim) | `bash tools/perf.sh [OUTDIR]` · `--again OUTDIR` |
| `shot.sh` | grim of the live session (or a headless run), `--both` themes | `bash tools/shot.sh NAME [--region "X,Y WxH"] [--runtime DIR] [--both]` → /dev/shm/r27/ |
| `px.py` | pixel measurement: runs (stripes), boxes, gaps, centre, hist, diff, zoom | `python3 tools/px.py --help` |
| `kit.sh` | the real surfaces in a headless dwl from a throw-away home (the installed configs; dwl itself in that home): the bar, notices, the launcher, quick settings, Super+U and its tabs, a mock TUI — or a play | `bash tools/kit.sh [--theme dark\|light] [--bin bin] [--time S] [--out DIR] SCENE…` · `--play FILE play` |
| `kit-play.sh` | a play's words (sourced by the kit): `at X Y`, `by`, `click`, `key`, `chord logo u`, `text`, `shot NAME [X,Y WxH]`, `panel`, `warm`, `nap`, `say` — the pointer through wlrctl, the keys through wtype | a play is a file of those lines |
| `vpointer.c` | a virtual pointer that sends what a real mouse wheel sends (axis_discrete) or a touchpad's part — wlrctl's scroll is a touchpad's only; for a headless dwl | build: its header (wayland-scanner + cc, the XML in `tools/protocols/`) · `vpointer wheel N` · `finger DY` · `move X Y` |
| `asobi-proof.sh` | the play world's promises tried for real, from inside (root): `walls`, `reset`, and on the real screen, with a dead man's switch, `vt`, `vt2`, `cycles` | `sudo bash tools/asobi-proof.sh walls` |
| `asobi-step.sh` | setup's `s_asobi` alone, or one of `lib/asobi.sh`'s functions, from this tree | `sudo bash tools/asobi-step.sh asobi_system` |
| `build-firealpaca.py`, `firealpaca_skin.py` | FireAlpaca's masks and starting files; its sheet, inks and pictures (read by `build-themes.py`) | `python3 tools/build-firealpaca.py` |
| `fake-tablet.py` | for `regress/sketch-pen.sh`: a private dwl given a tablet of nothing through a FIFO | that check builds it |
| `vkbd.c` | one virtual keyboard that stays, for a play with an X11 program (Xwayland never keeps up with wtype's, whose keyboard comes and goes): its protocol in `protocols/` | build it as `vpointer.c` |
| `hotplug-test.sh` | a real monitor unplug/replug on the free GPU (root) with X11 windows (`xconf.c`) | `sudo bash tools/hotplug-test.sh [DWL]` (`CYCLES=N`) |
| `dwl-patch.sh` | `src/dwl/dwl.patch` from the edited tree — before `fedokawaii apply` | `bash tools/dwl-patch.sh [TREE]` |
| `selftest.sh` | the installed system checked from a copy | `fedokawaii selftest [--sandbox]` |
| `regress/*.sh` | never again: one headless check per reported bug or measured surface (`menu-first-click`, `calendar-middle`, `one-popup`, `bar-geometry`, `window-frame`, `level-display`, `warm-exit`, `float-exit`, `notes-page`, `wheel-notch` (a real mouse notch from `vpointer.c`), `torrents` (three sizes, both moods, to the pixel); `no-xwayland-exit` and `term-burst` take a dwl binary, not kit options), each passing on the fixed build and failing on the old one; `regress/shots.py` measures their shots | `bash tools/regress/NAME.sh [KIT OPTION…]` (`--bin bin --repo-art`: the repository's state) |
| `torrent-stress.py` | Torrents measured in a throw-away home: 50 torrents on a local swarm (add → first peer, memory, CPU), the window at 500 rows (a key to its frame); `--real HASH…` the real network at the turtle's speed, `--torrra` the program it replaced | `python3 tools/torrent-stress.py [--real HASH…] [--torrra]` |
| `vm-create.sh` / `vm-snap.sh` / `vm-run.sh` | the harness VM (a kickstart install of Fedora, passt ssh on a local port): saved states as reflink copies; a command, the repo's working tree, a file in or out | `bash tools/vm-create.sh NAME` · `vm-snap.sh NAME start\|stop\|save S\|revert S\|list` · `vm-run.sh NAME CMD\|--repo [DIR]\|--get P OUT\|--wait` |
| `vm-clone.sh` | a second harness VM from one (reflinked states, its own disk, UEFI variables and port) — two proofs side by side | `bash tools/vm-clone.sh SRC NAME [--port P]` |
| `vm-inject/*.sh` | the update system's failures injected in the VM, each ending in a table: `restore-cut.sh` (kawa-snap restore cut at each step), `split-cut.sh` (the flat layout: whole, cut at each step, put back after a failure), `update-green.sh` (the button on the VM's real pending updates) | `bash tools/vm-inject/NAME.sh [VM] [STEP…]` |
| `yazi-patch.sh` | `src/yazi/yazi.patch` from an edited yazi tree (a checkout of YAZI_COMMIT): its words first, the diff after | `bash tools/yazi-patch.sh TREE` |
| `apps-review.sh` | the app surfaces (yazi and its pop-ups, btop, the calculator, books, the wallpaper picker) for the owner's page: both moods in the kit, sheets at 1× and 4×, the gaps measured beside them (`apps-review-measure.py`) → `.claude/review/next/` | `bash tools/apps-review.sh [--yazi BIN] [--out DIR] [--shots DIR]` |
| `vm-inject/run-all.sh` | every failure of update-design §5 a VM can prove, against a signed local repository: power cuts, the network, bad packages, a full disk, a damaged rpm database, red in the copy, red on the running system, the way back and forth, a bad release of fedokawaii, a backup to a USB drive; a line a row, the evidence in /dev/shm/r27/inject/ROW/ | `bash tools/vm-inject/run-all.sh VM TREE base` once, then `… VM TREE [ROW…]` |
| `vm-inject/release-move.sh` | the next Fedora through the button, for real: armed once, then green, cut in its offline transaction, red after it | `bash tools/vm-inject/release-move.sh VM TREE N [build] [green] [cut] [red]` |
| `vm-preflight.sh` | the test VM the button runs before a new Fedora: installed from its release tree, this desktop on it from nothing, started, checked, gone afterwards | `bash tools/vm-preflight.sh N [--out FILE] [--ram MB] [--keep]` |
| `start.sh` / `claude-loop.sh` | round 27's autonomous loop (a user service) | `bash tools/start.sh [stop\|status]` |
| `build-*.py` | fonts, icons, themes, cursors, art from the repo's sources | each prints `--help` |

Rules: timing comes from the frame log only (a recorder perturbs frames); big recordings go to /dev/shm
and are deleted; nothing here touches the live session except `perf.sh`/`shot.sh` (they drive or
read it) and `hotplug-test.sh` (another card, root).
