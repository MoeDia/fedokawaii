# lane-pixels — menus and panels to the pixel (owner 18:03; feedback.md)
Started 18:12, 4 Nov. Done by 21:30.

## Plan
1. Foundation: select = 12 % tint + 2 px edge (RIGHT); row grammar; keycaps; seals; panel-art pictures
2. Quick settings, power dialog
3. Calendar, timer, sound, downloads, help
4. Critical notice, Super+U (value insets, 16 px tabs, footer, fit)
5. Tests, design-system.md, renders 1x + 4x into .claude/review/next/, three critique passes

## Status (20:18, before main's forced reboot at about 20:25)
Everything below is committed and pushed on lane-pixels. NOT DONE yet: see "Next, after the reboot".

Built:
- `select` is now the 12 % tint, `select_edge` its 2 px edge, `text_on_select` the strong ink. The old red is `lacquer` + `text_on_lacquer`: GTK, Qt, gtklock, dwl's rail and rod, the prompt's failure code (foot slots 31, 32). fzf: pointer = glyph `band-edge`, no `:strip`.
- kawa-panel: one row grammar (band = content width, right inset 8), keycaps (`chord_parts`), seals, `@name` pictures from `configs/home/.config/fedokawaii/panel-art.txt`, hints, seal tiles with a second press, dim window, sand and watch lines, a row's own key, `--caps --dim --ghost`.
- Surfaces: quick settings (masthead, two instruments, sections, seals, keycaps), power dialog, calendar (month flowers, Sa/Su, today's seal, hint footer, week number), timer (sand bar), sound (instrument, rows with keys, device pictures), downloads (torrents a row with key t), help (keycaps, ghost), critical notice (mako patch: left-edge, summary-icon-seal), Super+U (16 px tabs, value inset, footer, no "soon" rows, "held back" has a value). Lights row, shown once kawa-quick reports `rgb` (lane-hardware).
- Super+/ one size whatever the sheet (`--lines` on a typed list); centred menus centred on the whole screen and the frame to the pixel.
- design-system.md updated. tools/panel-review.sh renders, tools/panel-measure.py measures, tools/regress/power-dialog.sh is new, menu-cursor and menu-first-click rewritten.

Verified, before the machine went bad:
- tests/menus: test_panel 759/0, test_quick 370/0, test_help 139/0, test_power 70/0; test_calendar 98/0, test_menu 84/0, test_timer 80/0 (these three before the last merge).
- static: test_contrast 24/0, test_design_doc 54/0, test_generated 278/0, test_noellipsis 9/0 (also before the last merge).
- tools/contrast.py 86 pairs 0 under; --apca 0 under (two kept: the workspace seal, today's digit).
- panel-measure: 128 checks held at 19:38, both moods.
- regress: power-dialog, menu-cursor, menu-first-click, calendar-middle, level-display, wheel-notch held on the kit.

NOT verified:
- The full suite never finished: killed at its background time limit, on a tree from 19:24 and a machine main says cannot be trusted. Of 33 files seen, these had failures: test_backup 1, test_clip 3, test_fetch 4, test_git 3, test_shell 1, test_tiles 12, a second test_menu 30, test_status 1 (a timing check under load). Some are surely mine: screen_row's value moved a column, screen_keys' chips, prompt slots 24/25 → 31/32. Each must be read, none assumed.
- one-popup.sh timed out at 400 s; not known to hold. gallery-expect.json not re-recorded.
- The last kit runs (20:10 on) came up blank: no bar, the panel 43 s late. Taken as the sick machine, not shown to be. If it survives the reboot, it is a real fault to find first.
- The mako patch built only in /tmp/lp/mako; test_syntax's config check now skips until an installed mako has `left-edge`.
- Nothing rendered into .claude/review/next/ yet; only two of the three critique passes done.

## Next, after the reboot (in this order)
1. /dev/shm and maybe /tmp are gone. Rebuild mako for renders: copy ~/.local/src/mako, `git checkout -f 91c6b79`, apply src/mako/mako.patch, meson (see setup.sh build_mako), `nice -n 10`.
2. `bash tools/panel-review.sh --only quick --themes light --out /dev/shm/lp/next`: does the kit work again? If it is still blank, find out why first.
3. The owner's 18:49 and 19:12 notes and lane-browser's below, not yet done: section "sound" with the share-sound row (`sharesound`, opener, draw @share-sound); the masthead as a title plate with lane-ink's smooth 48–56 px head (check lane-ink's output name; my head-32*.png from lane-art's sheet go if so); pressed state drawn; his section names are screen · sound · connect · capture · power (I had "session": change it).
4. `git merge main`, rebuild icons and themes, read each failure above and fix, run the whole suite with a long timeout, re-record gallery-expect.json, run one-popup.sh.
5. Third critique pass; write the measurement table; render 1x and 4x into .claude/review/next/ with a note per page.
6. Fill "What main must do", then the line DONE.

## What main must do to merge and apply (draft)
- After merging: `python3 tools/build-icons.py` and `python3 tools/build-themes.py` (art/icons.txt, the fonts and themes conflict with any lane that appended icons: keep both, rebuild).
- Any lane reading `P[...]["select"]` for a strong red must use `lacquer` now: lane-art's tools/build-heads.py does (`D_["select"]`), and tools/build-lock.py should be checked.
- The apply must rebuild mako (src/mako/mako.patch changed): the theme's `left-edge` line makes an old mako refuse the whole config.
- lane-appsui: yazi's cursor gets the tint by itself; its 2 px edge is theirs to draw (`ICON_BAND_EDGE`, slot 16). `screen_keys` now draws keycaps.
- Heads: themes/MOOD/head-32.png and head-32-open.png are from lane-art's sheet as of 18:33, to be replaced as above.
- The Learn book: the power dialog, the second press and the new keys need a line at the book pass.

## OWNER 18:45 — RGB: SOLID, NOT BREATHING
The GPU's RGB cannot stay in sync, so no breathing or any animation across devices. Instead:
- ONE steady red on every device (fans, hub, cooler, GPU logo, K617), calibrated per device so they LOOK identical (each brand renders red differently; the GPU drifts orange or pink): a per-device colour value, then one question on his page to confirm the match by eye.
- Event-driven instead of animated: lock screen → fade to about 30 %; screens off or sleep → off; unlock or wake → full.
- The quick-settings switch (rgb on/off for everything, remembered across reboots) as asked at 18:39.

## OWNER 18:49 — MORE LOVE FOR QUICK SETTINGS (Super+X)
He wants quick settings to be a small masterpiece, not a plain list. Keep it a menu (no circle), but:
- a header with character: the mood's head (lane-ink's ink version at menu size) beside "quick settings", drawn into a little title plate
- the two meters as real instruments at the top, with numbers: brightness as the lantern's glow filling, volume as segments; the same ramp as every meter
- on/off drawn as small hanko seals (inked = on, blank = off) instead of the words
- small section labels in muted ink (screen · sound · connect · capture · power) with even rhythm between sections
- the new rows: RGB (all lights on/off, from lane-hardware) and share sound (from lane-browser)
- every action row shows its key at the right as a keycap; the selected row uses the highlight RIGHT (2 px edge + tint)
- hover/selected/pressed states drawn, the unroll motion kept, both moods, every gap measured; render it at 1x and 4x into .claude/review/next/ for his verdict

## OWNER 19:12 — THE DEMON AND ANGEL ICONS: NO PIXEL ART EITHER
His words: "same for the icons: drop this pixelated act for the demon/angel icons — keep pixel art for everything else — just for the lockscreen, the bar and the terminal icons, keep it super serious."
- ONE character everywhere: every demon/angel icon is derived from lane-ink's lock painting (the same Hannya face, the same angel), never a separate drawing.
- fetch (~300 px sixel): the full engraved ink portrait.
- quick settings and menus (48-56 px): the same face, smooth anti-aliased reduction (no pixel snapping), hand-sharpened and retouched at that size.
- the bar (21 px PNG): a tight face crop, smooth and high-contrast, retouched by hand to read like a tiny engraved coin or seal; state images (demon roar / angel eyes open) from the painting's own states.
- the terminal prompt (a font glyph, one cell line high, one colour only): a hand-drawn two-ink woodcut reduction of the same face (the only size without shading, because a glyph is one colour), in the shu (demon) / sumi (angel) ink; the failed-command state too.
- Everything else in the UI stays pixel art. Render every size side by side at 1x and 4x into .claude/review/next/ for his verdict, then wire them in (bar, prompt font, fetch, quick settings, menus).
- Ownership: lane-ink makes all sizes; lane-pixels uses the 48-56 px one in quick settings; main wires the bar, the prompt font and fetch.

## From lane-browser (19:58) — the share-sound row, please draw it in your quick settings
The machine side is on branch lane-browser (bin/kawa-sharesound, kawa-quick). What your row needs:
- state: `kawa-quick --state` gives `sharesound<TAB>off | desktop | <program's name>` (read from a file, no process).
- click: `kawa-quick --do sharesound` opens its small menu (off · the desktop's sound · each program playing), kawa-menu's grammar. It is an opener: add `sharesound` to OPENERS.
- your row, in the section "sound": `("sharesound", "@share-sound", "share sound", value, on, on, "")` with value = "" when off, "desktop" or the program's name, on = state != off. Seal: inked = on.
- `@share-sound` is yours to draw: a speaker with a small arrow leaving it. My branch has the row in the old layout with the plain `share` glyph, one line in `quick_rows`; on merge yours wins.
