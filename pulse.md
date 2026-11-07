# round 28 pulse · Sat 07 20:45 (Dubai)

pace: 148/226 done (66%) · time used 44% · ahead 21.2 h · ETA Sun 08 17:58 · left 71 · blocked 0 · owner 7
alerts: usage limit hit 5× (last 2026-11-07T12:09 UTC)
run: conductor active · passes 1 (oldest 4 min) · last activity 0 min ago · commits since start 172 · hold False
machine: load 0.59 0.40 0.36/12 · mem free 18.9 GB · disk free 610 GB · up 44.5 h · cpu tccd1 39° · cpu tctl 46° · gpu edge 40° · gpu junction 35° · gpu mem 56° · ssd composite 39° · ssd sensor 1 39° · ssd sensor 2 41°
dark: True (active) · pulse timer active
tokens since start: out 2,849,120 · in 6,472 · cache write 10,273,153 · cache read 212,353,668 · msgs 3146 · out last 6 h 632,333
out by model: last 6 h claude-opus-5-5 498,413 · claude-sonnet-5-5 120,638 · claude-haiku-5-5 13,282 · since start claude-opus-5-5 2,432,044 · claude-sonnet-5-5 357,189 · claude-haiku-5-5 59,887

## now / blocked / owner
- [now] sa25d2e the jikusaki bar's widths, the last: the kanji's ink on x 960 measured (月 日 make the scroll 3 px narrower than 火); the date's 30th/31st (a 3 has no air: 17 px to the band, not 18) and a year ending in 1; tools/regress/bar-geometry.sh moved to 39 rows, 10 px paper to ink, 18 between the clock's parts, the 26 px seal on its 16 × 16 numeral, then run on the kit (both moods) — from sa25d2d
- [owner] c1b his eyes on the cooler's display with the PC dark: no 99 (S6) — only he can see it; assumed: dark. If it still blinks: the steady real temperature instead (S6)
- [owner] o01 his picks on the options pack, relayed by Claude; each pick built, the others dropped — assumed meanwhile: my strongest, each in r28-questionnaire.md part A
- [owner] o02 the RAM: restart, Delete, F7, OC, DRAM Frequency DDR5-4800, F10; then ram-check three copies for 20 minutes — still 5600 MT/s on 6 Nov; wrong bits measured, ledger r27-note-flips-2; say it before he installs anything built here
- [owner] o03 Phase E: his answers to the questionnaire applied: the last edit of the repo — then the ISO again
- [owner] o04 the ISO installed on his PC: fedokawaii lives there on Fedora 45, self-maintaining until Fedora 46 — the VM cannot show his firmware: the rehearsal first
- [owner] o05 T62: r28-track, r28-pulse, r28-dark, r28-cooler, the round's sudo and polkit rules and linger removed, never in the ISO — 
- [owner] o06 triad, his private repo fluvia4ai/triad: a read-only deploy key's public key posted for him, added with his OK; installed by default, self-updating, taught in Part 1 — the last line, owner 00:24

## last done
- sa25d the bar switched to the jikusaki metrics: style.css (paper 30, top 4, pad 10, BAR_GAP 10, Sumi Icons Bar first), kami pictures (tile, seal 26, head 32) from build-themes, windows from y 44, FONT-09 lists SumiIconsBar.ttf and SumiUI16{,-Bold}.ttf, 60-fedokawaii-pixel.conf covers Sumi UI 16; kit renders both moods, every gap measured; tests (Sat 7 Nov 19:36)
- sa25d2 the bar switched to the jikusaki metrics: ornaments() writes the JIKUSAKI pictures (kami_knob as kami-scroll, seal 26/28), old 27-row code removed; style.css (paper 30, top 4, pad 10, line on the paper's 20-row middle, BAR_GAP 10 in build-icons, Sumi Icons Bar and Sumi UI 16 first), config.jsonc height and exclusive zone (windows from y 44), test_bargaps on the new numbers (Sat 7 Nov 19:43)
- sa25d2b the jikusaki bar's widths: pad 10 (style.css paddings from Sumi UI 16's air, width.sh __AIR16_*), BAR_GAP 10 in build-icons (icons.sh), ws numerals 1-9 at 16-20 px in art/icons-bar.txt, seal 26 + thump 28 centred on them, the clock (knob ends, its parts 18 apart, kanji on x 960); test_bargaps' horizontal checks on Sumi UI 16 and icons-bar.txt (today still on 14 px Sumi UI / icons.txt) (Sat 7 Nov 20:21)
- sa25d2c the jikusaki bar's widths, the rest: ws numerals 1-9 at 16-20 px in art/icons-bar.txt (today icons.txt's 10 x 10), seal 26 + thump 28 centred on them; the kanji's ink on x 960 measured (月 日 make the scroll 3 px narrower than 火); the date's 30th/31st (a 3 has no air: 17 px to the band, not 18) and a year ending in 1; write_air caps at 3 but Sumi UI 16's 1 has 4 after it (uncap to 4, r4 classes); kawa-time's l1 class now a no-op (0 and 1 alike); tools/regress/bar-geometry.sh on 10/18 (Sat 7 Nov 20:35)
- sa25d2d the jikusaki bar's widths, the rest: ws numerals 1-9 at 16-20 px in art/icons-bar.txt (today icons.txt's 10 x 10), seal 26 + thump 28 centred on them; the kanji's ink on x 960 measured (月 日 make the scroll 3 px narrower than 火); the date's 30th/31st (a 3 has no air: 17 px to the band, not 18) and a year ending in 1; tools/regress/bar-geometry.sh on 10/18 (Sat 7 Nov 20:39)
- sa26 packages: smartmontools (smartd warns by notification and a line in the inventory/health) and LocalSend from its official release, not Flatpak, self-updating, port 53317 TCP+UDP in the home/LAN zone only; launcher, inventory, manifest checklist; tests (Sat 7 17:55)

## commits
- Sat 20:39 23587ffa sa25d2d: the workspaces' numerals 16 x 16 for the bar, the seal 26 (thump 28) round them; rest -> sa25d2e
- Sat 20:35 9fe07094 sa25d2c: Sumi UI 16's air to 4 px (r4 classes), the clock's l1 gone; rest -> sa25d2d
- Sat 20:29 220f60b3 sa25c3: Sumi UI 16's Œ œ Ĳ ĳ Ŋ ŋ ĸ ŉ ſ drawn on its rows
- Sat 20:22 d3ebad76 sa25d2b: the jikusaki tiles at 10 px paper to ink (BAR_GAP 10, Sumi UI 16's air, the clock 18 apart); S27: sa20e closed, routine rows to sonnet; rest -> sa25d2c
- Sat 19:43 6a246613 sa25d2: the bar on the jikusaki rows (39: tiles sliced 10 7 9 6, the knob scroll, Sumi UI 16 at 16px, windows from y 44); widths -> sa25d2b
- Sat 19:36 9a70c7aa sa25d1: the jikusaki bar's pictures in build-themes (39-row tile, seal 26, the clock's finials and brocade), not yet wired
- Sat 19:31 f53f6d9d sa25c2: Sumi UI 16's own signs (both weights) and Latin Extended-A composed on its rows
- Sat 19:22 015ec36a sa25b4: the bar's layout mark and bare download mark by their 20 px twins; a 20 px spiral

## repairs

## errors (2 h)

steering received: S20 S21 S22 S23 S24 S25 S26 S27
options: a1-window.jpg, b1-workspace.jpg, c1-scroll.jpg, d1-prompt.jpg, f1-bar.jpg, g1-power.jpg, h2-menus.jpg, t1-transparency.jpg
