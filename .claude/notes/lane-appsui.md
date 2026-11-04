# lane-appsui — the app surfaces to the pixel (owner 18:03; feedback.md pages 25, 26, 28, 31, 32)
Started 18:12, 4 Nov. Branch lane-appsui (merged origin/lane-pixels, which holds main, at 18:58: one grammar for keycaps and the highlight).

## Done (built, tested here, rendered both moods into .claude/review/next/ by tools/apps-review.sh)
- **yazi from source with square pop-ups** — src/yazi/yazi.patch (30 files, yazi-fm/src/frame.rs the heart), setup.sh build_yazi, `ya` still from the
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

## Measured (tools/apps-review-measure.py, both moods)
| surface | gap | px |
|---|---|---|
| books | rule → cover · cover → hairline | 16 · 16 |
| books | window's top → block · block → window's foot | 69 · 69 |
| wallpaper | settings' last row → picture · picture → hairline | 49 · 49 |
| yazi pop-up | hairline → content, every side | 16 (x 7 of the left cell, x 0 of the right, y 3, y 16: by the glyphs) |
| calculator | the panel | launcher's frame, 47 cells; answer row 40, capitals on 10–29 |

## What main (or lane-integrate) must do
1. Merge lane-appsui. Conflict-prone generated files: run `python3 tools/build-icons.py` and `python3 tools/build-themes.py` after the merge (the fonts are binary; every cell of mine has a
   fixed code point, `cp=` in art/icons.txt, so they survive any order). Foot's slot 33 = the floating hairline (31, 32 are the prompt's lacquer).
2. `fedokawaii apply` builds yazi (needs `dnf install rust cargo`: the manifest has them; about 5–8 minutes on this PC). Without the build the Lua and toml still work on the old binary, only
   the pop-ups stay yazi's own (test_yazi skips their cases there).
3. kawa-panel restart for the calculator (memory live-panel-restart). The timer's new hourly unit comes with theme.sh + the next login.
4. tools/review-gather.sh picks up .claude/review/next/ (40–58).

## Open / honest
- btop's words in its rules (menu, preset, filter …) are C++: a source patch would remove them; this PC has no g++ (gcc-c++ is not installed) and I may not sudo, so it stays
  theme-only. If the owner still finds it busy: src/btop/btop.patch on v1.4.7, build like mako, 15 lines at the sites listed in btop_draw.cpp (cpu buttons 598–607, proc 1870–1947).
- tests/look/test_wallpaper.sh "15 restores at once" failed here at load 30+ (flock -w 30 queue, exit 1 for the last ones): load, not this lane — re-run on a quiet PC.

## OWNER VERDICT 2026-11-04 20:00 on your render 57-yazi-half.png: comment
[Claude, art direction while the owner is away; his verdicts win] Big step up: size and age columns, the preview always shows the folder, the highlight as the 2 px edge + tint, a real footer. Fix: (1) names cut without an ellipsis ("a file with a rather long nam") — end them with … at the column edge; (2) the parent column cuts "fedokawa" — give it one more cell or ellipsis; (3) "m" for minutes vs "mo" for months is easy to misread: use "min", "h", "d", "w", "mo", "y" or a fixed-width date for old files; (4) the help pop-up's keycaps are right — give the pop-up the same inner padding on the right as on the left, and drop the duplicate rows (home/g g, up/k) into one row each with both keys.
