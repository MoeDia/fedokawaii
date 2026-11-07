# round 28 pulse · Sat 07 19:44 (Dubai)

pace: 143/223 done (64%) · time used 43% · ahead 20.9 h · ETA Sun 08 17:31 · left 72 · blocked 1 · owner 7
alerts: 1 blocked; usage limit hit 5× (last 2026-11-07T12:09 UTC); 3 errors in 2 h
run: conductor active · passes 1 (oldest 0 min) · last activity 0 min ago · commits since start 168 · hold False
machine: load 0.75 0.69 0.57/12 · mem free 19.0 GB · disk free 610 GB · up 43.5 h · cpu tccd1 38° · cpu tctl 45° · gpu edge 40° · gpu junction 34° · gpu mem 54° · ssd composite 39° · ssd sensor 1 39° · ssd sensor 2 40°
dark: True (active) · pulse timer active
tokens since start: out 2,748,290 · in 6,146 · cache write 9,966,114 · cache read 200,143,438 · msgs 2984 · out last 6 h 581,811
out by model: last 6 h claude-opus-5-5 423,484 · claude-sonnet-5-5 138,064 · claude-haiku-5-5 20,263 · since start claude-opus-5-5 2,342,434 · claude-sonnet-5-5 345,969 · claude-haiku-5-5 59,887

## now / blocked / owner
- [blocked] sa20e Helium square address, TUI hairlines, square tab/hover card: Helium draws them itself (no pref, no GTK CSS); only a patched Helium build (a Chromium tree: tens of GB, hours) would do it — unblock: a Helium source build fits the budget and the disk (or Helium adds a square-frame option); from sa20b
- [now] sa25d2b the jikusaki bar's widths: pad 10 (style.css paddings from Sumi UI 16's air, width.sh __AIR16_*), BAR_GAP 10 in build-icons (icons.sh), ws numerals 1-9 at 16-20 px in art/icons-bar.txt, seal 26 + thump 28 centred on them, the clock (knob ends, its parts 18 apart, kanji on x 960); test_bargaps' horizontal checks on Sumi UI 16 and icons-bar.txt (today still on 14 px Sumi UI / icons.txt) — from sa25d2
- [owner] c1b his eyes on the cooler's display with the PC dark: no 99 (S6) — only he can see it; assumed: dark. If it still blinks: the steady real temperature instead (S6)
- [owner] o01 his picks on the options pack, relayed by Claude; each pick built, the others dropped — assumed meanwhile: my strongest, each in r28-questionnaire.md part A
- [owner] o02 the RAM: restart, Delete, F7, OC, DRAM Frequency DDR5-4800, F10; then ram-check three copies for 20 minutes — still 5600 MT/s on 6 Nov; wrong bits measured, ledger r27-note-flips-2; say it before he installs anything built here
- [owner] o03 Phase E: his answers to the questionnaire applied: the last edit of the repo — then the ISO again
- [owner] o04 the ISO installed on his PC: fedokawaii lives there on Fedora 45, self-maintaining until Fedora 46 — the VM cannot show his firmware: the rehearsal first
- [owner] o05 T62: r28-track, r28-pulse, r28-dark, r28-cooler, the round's sudo and polkit rules and linger removed, never in the ISO — 
- [owner] o06 triad, his private repo fluvia4ai/triad: a read-only deploy key's public key posted for him, added with his OK; installed by default, self-updating, taught in Part 1 — the last line, owner 00:24

## last done
- sa25b4 the bar's scripts reach the 20 px drawings: kawa-dwlstatus's layout (ICON_SPIRAL/TILE/FLOAT plain codes) and kawa-downloads' bare mark (dl_N) to their _BAR twins, gaps re-measured; a 20 px spiral in icons-bar.txt (Sat 7 Nov 19:22)
- sa25c Sumi UI 16 for the bar's words: Shinonome 16 + 16B through tools/build-fonts.py, its air table; capitals 13 tall, baseline 16 down the 20-row line (Sat 7 Nov 19:18)
- sa25c2 Sumi UI 16's own signs and Latin Extended-A: art/signs.txt rows for ui16/ui16b (— – • → ◆ ✓ ° % …, 8 wide, both weights), Ext-A composed on its 13-row capitals; Cozette's 9-row fill-ins look small beside them (Sat 7 19:31)
- sa25d the bar switched to the jikusaki metrics: style.css (paper 30, top 4, pad 10, BAR_GAP 10, Sumi Icons Bar first), kami pictures (tile, seal 26, head 32) from build-themes, windows from y 44, FONT-09 lists SumiIconsBar.ttf and SumiUI16{,-Bold}.ttf, 60-fedokawaii-pixel.conf covers Sumi UI 16; kit renders both moods, every gap measured; tests (Sat 7 Nov 19:36)
- sa25d2 the bar switched to the jikusaki metrics: ornaments() writes the JIKUSAKI pictures (kami_knob as kami-scroll, seal 26/28), old 27-row code removed; style.css (paper 30, top 4, pad 10, line on the paper's 20-row middle, BAR_GAP 10 in build-icons, Sumi Icons Bar and Sumi UI 16 first), config.jsonc height and exclusive zone (windows from y 44), test_bargaps on the new numbers (Sat 7 Nov 19:43)
- sa26 packages: smartmontools (smartd warns by notification and a line in the inventory/health) and LocalSend from its official release, not Flatpak, self-updating, port 53317 TCP+UDP in the home/LAN zone only; launcher, inventory, manifest checklist; tests (Sat 7 17:55)

## commits
- Sat 19:43 6a246613 sa25d2: the bar on the jikusaki rows (39: tiles sliced 10 7 9 6, the knob scroll, Sumi UI 16 at 16px, windows from y 44); widths -> sa25d2b
- Sat 19:36 9a70c7aa sa25d1: the jikusaki bar's pictures in build-themes (39-row tile, seal 26, the clock's finials and brocade), not yet wired
- Sat 19:31 f53f6d9d sa25c2: Sumi UI 16's own signs (both weights) and Latin Extended-A composed on its rows
- Sat 19:22 015ec36a sa25b4: the bar's layout mark and bare download mark by their 20 px twins; a 20 px spiral
- Sat 19:18 bd07784d sa25c: Sumi UI 16 and its bold for the bar's words (Shinonome 16, 20-row line), their air tables
- Sat 19:12 0a09c813 sa25b3: the bar's download mark and its fill, share, quiet bell, float and monocle at 20 px
- Sat 19:08 1953c38b sa25b2: the bar's weather, hourglass, rec, tv, usb, cassette and pause icons at 20 px
- Sat 19:02 7bcdc918 sa25b: the bar's volume and brightness icons at 20 px (Sumi Icons Bar)

## repairs

## errors (2 h)
- [   107][  0.878433] (read_unsupported_feature      ) busno=5, sleep-multiplier= 2.00, Testing for unsupported feature 0xdd returned Error_Info[DDCRC_RETRIES in ddc_write_read_with_retry, causes: DDCRC_DDC_DATA(10)]
- [   107][  0.878589] (read_unsupported_feature      ) Turning off dynamic sleep and retrying
- [   107][  1.299321] (read_unsupported_feature      ) busno=5, sleep-multiplier= 1.00, Retesting for unsupported feature 0xdd returned Error_Info[DDCRC_REPORTED_UNSUPPORTED in ddc_get_nontable_vcp_value_full]

steering received: S19 S20 S21 S22 S23 S24 S25 S26
options: a1-window.jpg, b1-workspace.jpg, c1-scroll.jpg, d1-prompt.jpg, f1-bar.jpg, g1-power.jpg, h2-menus.jpg, t1-transparency.jpg
