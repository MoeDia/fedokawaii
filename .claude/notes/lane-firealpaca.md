
## OWNER 17:32 — TONIGHT
The owner wants the whole round finished today; he is at the PC until 23:30. Finish, test, push and end this file with a line DONE by 21:30. Complete and working first, refine after; never fake done; list what is left for main. Run heavy builds and tests with nice -n 10. Questions for him: append to ~/repos/fedokawaii/.claude/inbox.md as "## <time> — question from lane-firealpaca".

## OWNER ANSWER 2026-11-04 19:31 — to your question «2026-11-04 19:31 — question from lane-firealpaca»
i want it skipped

<!-- status -->
## State at 20:35, 4 Nov: NOT DONE yet; the re-check is running

Main merged in (77b19a9f), the skin regenerated: no change. Re-run on the merge, all green: `test_sketch` 110/110, `test_theme` 151/151 (its first finished run), `test_theme_parts` 129/129, `test_manifest` 68/68, `test_upstream` 266/266, `test_syntax` 824/824, `test_generated` 276/276, `test_contrast` 21/21, `test_help` 142/142, `test_launcher` 268/268, `test_yazi` 140/140, `test_deps` 197/197, `test_design_doc` 54/54, `test_noellipsis` 9/9. The pen, on the last code: held, 2, 8, 16 px at 0.10, 0.50, 1.00 (20:32).

The machine is still sick (PID 1 stuck, 28k zombies): `getgrgid` hangs in nss-systemd, so `ls -l`, `ps` and `tar` take minutes; a crashing process hangs in the core dump's pipe. Avoid them; `tar --numeric-owner`.

Left: every dialog walked (`/dev/shm/fa-lane/scripts/dlgwalk.c`, a probe, never installed) because dialog buttons touch the frame (0 px on the right in New, also at the foot in Environment). Then this file ends with DONE; `rm -rf ~/.cache/lane-firealpaca /dev/shm/fa-lane` first.

# lane-firealpaca — T28: Sketch is FireAlpaca, themed to the limit

Branch `lane-firealpaca`. Every test below was run on this PC, in a fenced headless dwl (`tools/hl-dwl.sh`, `tools/kit.sh`): nothing on the owner's screen. Proof shots beside this file: `lane-firealpaca/sketch-dark.png`, `sketch-light.png`, `pen-pressure.png`.

## What is there

| path | what |
|---|---|
| `lib/upstream.sh` `install_firealpaca` | the official Linux build (`firealpaca.com/download/linux`, an AppImage, 2.16.3, sha256 pinned), unpacked by the user to `~/.local/share/fedokawaii/firealpaca/app`. Its terms forbid redistribution, so it is always fetched from them, never from the repo or the ISO. The address serves only the newest: a newer version is taken and said; anything else is refused |
| `setup.sh`, `verify.sh`, `system/fedokawaii-report` | `s_firealpaca`, gate + update + repair steps; a verify row; a report row |
| `src/kawa-firealpaca/` | C, no Qt headers, loaded with LD_PRELOAD by kawa-sketch; a missing Qt symbol turns the whole of it off, a class it does not know is left as drawn; `KAWA_FA_PLAIN=1` shows the program as it comes; children do not inherit it. See its header |
| `tools/firealpaca_skin.py` + `tools/build-themes.py` | `themes/*/firealpaca.qss`, `firealpaca.conf`, `firealpaca-*.png`: the sheet, inks and pictures, from the design's tokens |
| `art/firealpaca-icons.txt` → `tools/build-firealpaca.py` | 86 masks of our own drawing, same names and sizes as the program's resources; `art/firealpaca-parts.txt`: marks, arrows, panel heading icons |
| `configs/firealpaca/` + `theme.sh` 4f | what it starts from, once (state `firealpaca-seed`): Wada's 159 colours by name (`art/wada-159.tsv`), 12 brushes with our *Fude*, the panels laid out, a white page 1920 × 1080 |
| `bin/kawa-sketch`, `kawa-sketch.desktop` | a new `.mdp` in `~/Pictures/Sketches`, or a file; one running: it is asked |
| `keys/sketch.txt`, `bin/kawa-help` | its keys first in Super+/ while it is in front |
| `tools/regress/sketch-pen.sh`, `tools/fake-tablet.py` | never again: pressure through to the stroke, on a private dwl with a tablet of nothing |
| docs | Learn §20.2 (the first drawing, keys, why, what if), Guide §16.4, README, design-system §13 §14, PACKAGES.md, keybinds.txt |

## Decisions (each measured or from the source)

- **Xwayland only**: the build ships the `xcb` platform plugin alone (Qt 6.5.2; `usr/plugins/platforms/libqxcb.so`). Unpacked, not mounted: no FUSE, first window 1.0 s.
- **Tiled**, as any window: its dialogs float by themselves. No dwl rule needed.
- **Skipped start page** (owner, inbox 19:31, told that its terms forbid "acts that bring detriment" and that SE has no Linux build, firealpaca.com/fase): `DialogAd` never comes up and its page is not fetched. The tree falls from about 500 MB to 312 MB. `KAWA_FA_PLAIN=1` brings it back.
- **Open and Save** go through `kawa-pick` (yazi), the desktop's one dialog. `getOpenFileNames` (several files) and the QFileDialog objects it builds itself stay Qt's, dressed by the sheet.
- **The pen's buttons** are FireAlpaca's own: upper = eyedropper, lower = hand (measured). Xournal++ keeps its own.
- **`kawa-file` keeps Xournal++** for PDFs; `.xopp` opens there, `.mdp` here.

## Why FireAlpaca over Xournal++ (the owner asked for proof first)

| | FireAlpaca 2.16.3 | Xournal++ 1.3.8 | source |
|---|---|---|---|
| what it is | digital painting | "note-taking software" | firealpaca.com; xournalpp.github.io |
| brushes | pen, airbrush, watercolour, blur, smudge, mix, edge, bitmap, scatter, roller, scripted (`.bs`), each with options | pen, highlighter, eraser | the program's `BrushNew.xml`; xournalpp.github.io |
| pressure | per brush: size and opacity by pressure, minimum width; a global curve; fade in and out, ink pool | width by pressure | its Edit Brush and Brush Environment dialogs |
| stabiliser | global and per brush | yes too (`StrokeStabilizer` in the binary): no advantage | the programs |
| layers | blend modes (Normal … Color Dodge …), clipping, protect alpha, folders, masks | plain layers | its Layer panel and menu; xournalpp.github.io |
| drawing aids | snaps: parallel, cross, radial, circle, curve, 3D; symmetry | grid and rotation snap | its Snap bar; xournalpp.github.io |
| more | filters (levels, tone curve, gauss …), onion-skin animation, time-lapse, panels, export PNG, PSD | PDF annotation, LaTeX, audio | its menus; xournalpp.github.io |
| first window (3 runs, warm) | 0.9 – 1.0 s | 0.9 – 2.6 s | measured here (headless, real GPU) |
| RAM | 220 MB, 312 MB with its web view's processes | 90 – 106 MB | measured here |
| idle CPU | 0 % | 0 % | measured here |

Costs, honestly: two to three times the RAM, closed source, X11 only.

## How it was tested

- **Pressure, the real path**: `tools/regress/sketch-pen.sh`: a `wlr_tablet` of nothing on a private dwl → dwl's penmove → tablet-v2 → Xwayland's stylus (Qt logged it: `xwayland-tablet stylus … Pen caps=Position|Pressure|…`) → Qt → the brush. Stroke widths **2, 8, 16 px at pressure 0.10, 0.50, 1.00** (default brush, page fitted, measured on the shot); a rising pressure tapers.
- **Not tested, could not be: the physical XP-Pen** (Star G430S; not plugged in on 4 Nov: not in `/proc/bus/input/devices`). Everything after the kernel is proven; the pad itself is for the owner's first stroke.
- Both moods, whole window and deep dialogs (Edit Brush, Environment, Layer Property, menus, tooltip, popups, layer rows with a folder, a lock and a clip): shots, at 2× and 3×.
- **The mood live**: `current` renamed as kawa-theme does, while it runs: sheet, inks, masks and lists follow, no restart (dark ↔ light, shots).
- **Alignment, measured** (`first/last non-ground x` per row, identical in both moods): content x 48 – 311 in the left panels, 1639 – 1902 in the right; heading icons +2; rule to the content's edge; meters 6 + 2 px on the grid.
- **Real launcher path** in the kit with `--bin bin`: new sketch named by date; Ctrl+S; Ctrl+O and Ctrl+Shift+S through kawa-pick (yazi); Cancel removes the stand-in; a second file through the launcher opens as a tab in the one running (no second process).
- **No network**: starts, opens the page, no hang (run before the start page was skipped: it showed "No internet" and Enter closed it).
- **The pen's side buttons**: on the private dwl: upper + tip: colour picked (#FFFFFF from the page); lower + drag: the page moved.
- **Keys**: Tab, F2, F7, Ctrl+K, Ctrl+N, Ctrl+O, Ctrl+Alt drag (size 24 → 46), Space drag (the page moved), from the running program.
- Test files, before the merge of main and the last changes (to be run again, above): `tests/content/test_sketch.sh` 110/110, `tests/look/test_launcher.sh` 268/268, `tests/menus/test_help.sh` 142/142, `tests/yazi/test_yazi.sh` 140/140, `tests/static/test_generated.sh`, `test_syntax.sh`, `test_deps.sh`, `test_design_doc.sh`, `test_noellipsis.sh`, `tools/check-packages`: green. `tests/installer/test_upstream.sh` 266/266.

## What main (lane-integrate) must do

1. **dwl, two lines in `penmove`** (dwl is not this lane's): a brush with a fade grows a long tail on its first stroke when the mouse has never been over the window (Sketch opened by keyboard, the mouse on the bar, the pen first). Proven on a private dwl: 3 of 3 clean with it; without it the tail came in every run but one:
   ```diff
    	if (surface != pen.surface) {
    		focusfollow(c, l);
   +		/* (a program that also watches the mouse is told it is here, then that it is gone) */
   +		wlr_seat_pointer_notify_enter(seat, surface, sx, sy);
    		wlr_seat_pointer_notify_clear_focus(seat);
    		wlr_tablet_v2_tablet_tool_notify_proximity_in(t, tab, surface);
   ```
   then `tools/dwl-patch.sh`. `tools/regress/sketch-pen.sh` reads that comment in dwl.c: without it, it only tries with the mouse over the window; with it, parked off the window.
2. Merge. Run `python3 tools/build-themes.py` after the merge if the palette moved (the skin is generated, committed).
3. `fedokawaii apply`: `theme.sh` builds `kawa-firealpaca` (TOOLS), copies the masks and blank page, seeds once; `setup.sh`'s update step: FireAlpaca is **already unpacked and recorded** under `~/.local` on this PC (tag `2.16.3`), so "in place". `nss` joins the manifest (the one system library of its bundle nothing else brings; `rpm -q nss` is already here).
4. The VM: a clean install should fetch and unpack it (131 MB, 323 MB unpacked). `tools/regress/sketch-pen.sh` joins `tools/regress/run.sh` by its name.
5. Ledger and plan: r27-32 from this file; T28's heading done. Learn §20.2 goes into T27's pieces (it has no figure yet: `docs/build` renders figures by name; `.claude/notes/lane-firealpaca/sketch-*.png` are ready pictures).
6. The owner's first stroke with the real pen, after the apply and a new session.

## Left, known, small

- The program's own tool cursors (`:/images_cursor`, black and white for any canvas) are still its own: they must read over any picture, and a mask's one ink cannot.
- "#1" is the palette group's name: its setting did not take from the file.
- `tests/static/test_contrast.sh` fails on `the prompt: the mood's head on the ground` on this branch's base: not this lane's (T19q).

## OWNER VERDICT 2026-11-04 21:31 on your render final-sprint: comment
OWNER 21:30 — FINAL SPRINT: "you have 2 hours, finish the whole fedokawaii project fully". Deadline 23:30. Order of the night (relayed by Claude):
1. 21:30–22:30 every lane: finish the most valuable COMPLETE part of its task, test it, push, end its notes with a line DONE and a handover (what main must apply, what is left). No new scope. Never fake done.
2. lane-integrate: merge each DONE lane at once (master review, full offline suite), in this priority: ink, pixels, appsui, updates, iso, asobi, art, chess, typing, torrents, learning, firealpaca, nvim, fixer, hardware, network, saver.
3. main: 22:45 at the latest merge lane-integrate, then APPLY on the PC (he is here, screen takeover allowed; a notice on his page first) and check the desktop, the lock (lane-ink's M1 / M2) and the menus live.
4. main ~23:00: the Fedora 45 upgrade through the update button (snapshot first, btrfs scrub after; he decided to go ahead), unless the apply left something broken.
5. lane-iso: build and prove the final Fedora 45 ISO from merged main in its VM as soon as main has the merge, in parallel.
6. 23:30: main writes the owner's summary: what is done and proven, what is left (kept open in the plan for the next round), how to roll back.
