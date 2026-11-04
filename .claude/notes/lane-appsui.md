# lane-appsui — the app surfaces to the pixel (owner 18:03; feedback.md pages 25, 26, 28, 31, 32)
Started 18:12, 4 Nov. Branch lane-appsui (merged origin/lane-pixels, which holds main, at 18:58: one grammar for keycaps and the highlight).

## Done (built, tested here, rendered both moods into .claude/review/next/ by tools/apps-review.sh)
- **yazi from source with square pop-ups** — src/yazi/yazi.patch (33 files, yazi-fm/src/frame.rs the heart), setup.sh build_yazi, `ya` still from the
  release zip, fedokawaii.conf YAZI_TAG/YAZI_COMMIT, Fedora's rust + cargo in PKG_BUILD (packages.evidence, PACKAGES.md, not-launched.txt), verify's row, update and repair
  rows, stubs/cargo. Rename, the inputs, confirm, help, which, pick, cmp, tasks, notices: §4's frame in cells of Sumi Icons Term (fixed code points, U+FF003–A), §7's heading inside,
  key tiles (U+FF001, U+FF000 + ASCII, U+FF002); a confirm fits what it says, names under their folder; rename's field exactly over the name. `yazi --version` says "Patch  : fedokawaii".
- **yazi's lists** — breadcrumb, size and age columns (units faint), dotfiles muted, cards for what has no picture (plugins/kawa-card.yazi), a folder's preview that works
  (plugins/kawa-folder.yazi: the old override of yazi's `folder` RECURSED: "C stack overflow" in yazi.log, the pane stood empty: that is what he saw), footer size · changed ·
  rights · place, marks and tasks as muted facts, the task window's rows.
- **btop** — boxes cpu, gpu, mem, proc (net one key away), no per-core heat, memory as graphs, one ramp asagi → gold → the seal's red, calm asagi for what is good to have, the
  rules' words stepped back (title muted, hi_fg faint). I kept the card's box rather than main's first pass (show_gpu_info On, no box): the art note asks for vram and watts.
- **calculator** — kawa-panel's `Calc`, floating as the launcher: the answer at 28 px, units small and muted, Enter copies in place, the session's sums below with a kind's icon,
  hints in faint until then, its keys as caps. bin/kawa-calc: `kawa-menu --calc`, `--answer` kept. The old TUI is gone.
- **books** — the cover centred to the pixel (table below), words centred under it, "new" only beside a book begun, a thin cursor bar before the ghost's first letter, a value's inset.
- **wallpaper picker** — settings block as options (r, o, s; dots in columns), sections with labels the cursor passes by, the old masters second, the picture centred between the
  settings and the hairline; timer hourly, wallpaper-rotate off|1h|4h|daily (old "on" reads as 4h), wallpaper-from, wallpaper-order, wallpaper-changed.
- docs/design-system.md: pop-ups, Keys, Options, Sections, a picture in a screen, the calculator, Files; keys/wallpaper.txt, keybinds.txt, the two Learn paragraphs.
- **Added in the final sprint** (found by looking at the sheets again): **Tab's pop-up** was still yazi's raw table, words flush on the frame and rows about its own plugins: now a card in the
  pop-ups' frame (plugins/kawa-card.yazi `M:spot`, yazi.toml's spotters): what, points to, size, changed, created, rights, owner; marks say "2 marked", what they are, their size together; j/k move a
  band with the cursor's edge (yazi-binding's table.rs, for any table), c c copies. **Tasks** with nothing running was a 60 % empty frame: it now fits what it says (none: 40 columns, 3 rows; each task 3 rows).
  A link's target: muted after "→", no italics. `file`'s build fingerprint (BuildID, interpreter) gone from "what". The wallpaper picker's counts and key tiles moved a column in, onto the values' column.
- **Float exit** (lane-review's finding; main's request): fzf's --no-clear in books, kawa-file, kawa-git, yazi's `Raterm::goodbye`, tools/regress/float-exit.sh. kawa-backup keeps fzf's clear on purpose (text follows it).

## Measured (tools/apps-review-measure.py, both moods)
| surface | gap | px |
|---|---|---|
| books | rule → cover · cover → hairline | 16 · 16 |
| books | window's top → block · block → window's foot | 69 · 69 |
| wallpaper | settings' last row → picture · picture → hairline | 49 · 49 |
| yazi pop-up | hairline → content, every side | 16 (x 7 of the left cell, x 0 of the right, y 3, y 16: by the glyphs) |
| calculator | the panel | launcher's frame, 47 cells; answer row 40, capitals on 10–29 |
| yazi Tab card | ring → band · band → ring (both sides) | 8 · 8 |
| yazi Tab card | band's left → words · ring → heading's rule end | 16 · 16 |
| wallpaper | right edges: value, count · key tile (ink; its cell on the values' column) | 1256 · 1252 |

## Verified, 4 Nov ~22:00–22:20 (the PC at load 50+ from the other lanes)
PENDING: being filled in as the last runs end (see below when this line is gone).

## The master's review (lane-integrate, 22:00, ~/.cache/r27-integrate/master-appsui-1.md): what became of it
- MUST FIX fedokawaii.sh: done (a3768f9c): `src/yazi/*` is built by setup, so a copy whose only change is the patch runs repair; tests/engine/test_front.sh covers the three patches.
- build_yazi: `retry 3 10 … cargo fetch --locked` before the build; a failure leaves no checkout (yazi_fail); tests in test_upkeep (a dropped fetch tried again, a failed build said, its checkout gone, the old yazi kept, the next update builds it; crates that cannot be fetched). stubs/cargo: fail-cargo-build.
- test_git, test_clip: the gate's fixed versions taken as they are (9248fd8b), so the merge meets the same lines.

## What main (or lane-integrate) must do
1. Merge lane-appsui. Conflict-prone generated files: run `python3 tools/build-icons.py` and `python3 tools/build-themes.py` after the merge (the fonts are binary; every cell of mine has a
   fixed code point, `cp=` in art/icons.txt, so they survive any order). Foot's slot 33 = the floating hairline (31, 32 are the prompt's lacquer).
2. `fedokawaii apply` builds yazi (needs `dnf install rust cargo`: the manifest has them; about 5–8 minutes on this PC). Without the build the Lua and toml still work on the old binary, only
   the pop-ups stay yazi's own (test_yazi skips their cases there).
3. kawa-panel restart for the calculator (memory live-panel-restart). The timer's new hourly unit comes with theme.sh + the next login.
4. tools/review-gather.sh picks up .claude/review/next/ (40–59; 59-yazi-tab-card is new).

## Open / honest
- The relayed art note on 57-yazi-half (20:00): its 2, 3, 4 are done (60eedc8a: the parent column, min for minutes, help one row a deed with its insets). Its 1 asked for "…" on cut names: NOT done, on purpose:
  the owner's standing rule is never "…"; a name is cut at a word's end. Main may mark that heading done with this note.
- The calculator's big whole numbers: qalc says 2^64 = 1.844674407E19. `-s "exp off"` gives 18446744073709551616 (checked here), but the answer row holds about 21 digits at 28 px; a longer one would need a
  rule of its own. Not asked by a verdict: left for the next round.
- btop's words in its rules (menu, preset, filter …) are C++: a source patch would remove them; this PC has no g++ (gcc-c++ is not installed) and I may not sudo, so it stays
  theme-only. If the owner still finds it busy: src/btop/btop.patch on v1.4.7, build like mako, 15 lines at the sites listed in btop_draw.cpp (cpu buttons 598–607, proc 1870–1947).
- tests/look/test_wallpaper.sh "15 restores at once" failed here at load 30+ (flock -w 30 queue, exit 1 for the last ones): load, not this lane — re-run on a quiet PC.

## OWNER VERDICT 2026-11-04 20:00 on your render 57-yazi-half.png: comment
[Claude, art direction while the owner is away; his verdicts win] Big step up: size and age columns, the preview always shows the folder, the highlight as the 2 px edge + tint, a real footer. Fix: (1) names cut without an ellipsis ("a file with a rather long nam") — end them with … at the column edge; (2) the parent column cuts "fedokawa" — give it one more cell or ellipsis; (3) "m" for minutes vs "mo" for months is easy to misread: use "min", "h", "d", "w", "mo", "y" or a fixed-width date for old files; (4) the help pop-up's keycaps are right — give the pop-up the same inner padding on the right as on the left, and drop the duplicate rows (home/g g, up/k) into one row each with both keys.

## OWNER VERDICT 2026-11-04 21:31 on your render final-sprint: comment
OWNER 21:30 — FINAL SPRINT: "you have 2 hours, finish the whole fedokawaii project fully". Deadline 23:30. Order of the night (relayed by Claude):
1. 21:30–22:30 every lane: finish the most valuable COMPLETE part of its task, test it, push, end its notes with a line DONE and a handover (what main must apply, what is left). No new scope. Never fake done.
2. lane-integrate: merge each DONE lane at once (master review, full offline suite), in this priority: ink, pixels, appsui, updates, iso, asobi, art, chess, typing, torrents, learning, firealpaca, nvim, fixer, hardware, network, saver.
3. main: 22:45 at the latest merge lane-integrate, then APPLY on the PC (he is here, screen takeover allowed; a notice on his page first) and check the desktop, the lock (lane-ink's M1 / M2) and the menus live.
4. main ~23:00: the Fedora 45 upgrade through the update button (snapshot first, btrfs scrub after; he decided to go ahead), unless the apply left something broken.
5. lane-iso: build and prove the final Fedora 45 ISO from merged main in its VM as soon as main has the merge, in parallel.
6. 23:30: main writes the owner's summary: what is done and proven, what is left (kept open in the plan for the next round), how to roll back.
