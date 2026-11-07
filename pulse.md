# round 28 pulse · Sat 07 19:15 (Dubai)

pace: 138/218 done (63%) · time used 43% · ahead 20.5 h · ETA Sun 08 17:33 · left 72 · blocked 1 · owner 7
alerts: 1 blocked; usage limit hit 5× (last 2026-11-07T12:09 UTC); 3 errors in 2 h
run: conductor active · passes 1 (oldest 2 min) · last activity 0 min ago · commits since start 163 · hold False
machine: load 0.42 0.30 0.35/12 · mem free 19.0 GB · disk free 610 GB · up 43.0 h · cpu tccd1 38° · cpu tctl 51° · gpu edge 40° · gpu junction 34° · gpu mem 55° · ssd composite 39° · ssd sensor 1 39° · ssd sensor 2 40°
dark: True (active) · pulse timer active
tokens since start: out 2,632,228 · in 5,846 · cache write 9,574,860 · cache read 189,852,657 · msgs 2834 · out last 6 h 465,749
out by model: last 6 h claude-opus-5-5 307,422 · claude-sonnet-5-5 138,064 · claude-haiku-5-5 20,263 · since start claude-opus-5-5 2,226,372 · claude-sonnet-5-5 345,969 · claude-haiku-5-5 59,887

## now / blocked / owner
- [blocked] sa20e Helium square address, TUI hairlines, square tab/hover card: Helium draws them itself (no pref, no GTK CSS); only a patched Helium build (a Chromium tree: tens of GB, hours) would do it — unblock: a Helium source build fits the budget and the disk (or Helium adds a square-frame option); from sa20b
- [now] sa25c Sumi UI 16 for the bar's words: Shinonome 16 + 16B through tools/build-fonts.py, its air table; capitals 13 tall, baseline 16 down the 20-row line — from sa25
- [owner] c1b his eyes on the cooler's display with the PC dark: no 99 (S6) — only he can see it; assumed: dark. If it still blinks: the steady real temperature instead (S6)
- [owner] o01 his picks on the options pack, relayed by Claude; each pick built, the others dropped — assumed meanwhile: my strongest, each in r28-questionnaire.md part A
- [owner] o02 the RAM: restart, Delete, F7, OC, DRAM Frequency DDR5-4800, F10; then ram-check three copies for 20 minutes — still 5600 MT/s on 6 Nov; wrong bits measured, ledger r27-note-flips-2; say it before he installs anything built here
- [owner] o03 Phase E: his answers to the questionnaire applied: the last edit of the repo — then the ISO again
- [owner] o04 the ISO installed on his PC: fedokawaii lives there on Fedora 45, self-maintaining until Fedora 46 — the VM cannot show his firmware: the rehearsal first
- [owner] o05 T62: r28-track, r28-pulse, r28-dark, r28-cooler, the round's sudo and polkit rules and linger removed, never in the ISO — 
- [owner] o06 triad, his private repo fluvia4ai/triad: a read-only deploy key's public key posted for him, added with his OK; installed by default, self-updating, taught in Part 1 — the last line, owner 00:24

## last done
- sa20d regress README rows for r28-sa14b, r28-sa15, r28-sa15b2, r28-sa15d2a (items.py check clean) (Sat 7 Nov 18:59)
- sa25 the bar bigger: one set of metrics, icons drawn at real size, right hinting, no scaling; every gap measured (Sat 7 Nov 16:34)
- sa25b the bar's other icons at 20 px in art/icons-bar.txt (2 px strokes, air symmetric): vol 0-4/mute, bri 0-4, weather, hourglass, rec, tv, usb, cassette, pause, dl-fill, share, bell-off, float, monocle (Sat 7 Nov 19:02)
- sa25b2 the bar's 20 px icons, part 2 in art/icons-bar.txt: weather (sun moon cloud rain snow storm fog), hourglass hg-0..4, rec-0/1, tv-0..3, usb, cassette-a/b, pause (Sat 7 Nov 19:08)
- sa25b3 the bar's 20 px icons, part 3: dl-fill-1..20 (adv 0 overlays over dl-*), dl-0..5, share, bell-off, float, monocle (Sat 7 Nov 19:12)
- sa26 packages: smartmontools (smartd warns by notification and a line in the inventory/health) and LocalSend from its official release, not Flatpak, self-updating, port 53317 TCP+UDP in the home/LAN zone only; launcher, inventory, manifest checklist; tests (Sat 7 17:55)

## commits
- Sat 19:12 0a09c813 sa25b3: the bar's download mark and its fill, share, quiet bell, float and monocle at 20 px
- Sat 19:08 1953c38b sa25b2: the bar's weather, hourglass, rec, tv, usb, cassette and pause icons at 20 px
- Sat 19:02 7bcdc918 sa25b: the bar's volume and brightness icons at 20 px (Sumi Icons Bar)
- Sat 18:59 e01e587c r28-sa20d: regress rows for sa14b, sa15, sa15b2, sa15d2a, sa20c
- Sat 18:58 4f378c22 sa20c: the noellipsis test reads the yubi pointer's pixel rows as ink, not text
- Sat 18:57 41af1762 sa20b: Helium's chrome in Sumi UI; the light new tab proven with a portal
- Sat 18:52 b09827ef sa15e2: the timer's sand bar as a tairyoku (one meter drawer for levels and sand)
- Sat 18:49 d5cc720f s12c2: its regress row; two missing rows found, planned

## repairs

## errors (2 h)
- [   107][  0.878433] (read_unsupported_feature      ) busno=5, sleep-multiplier= 2.00, Testing for unsupported feature 0xdd returned Error_Info[DDCRC_RETRIES in ddc_write_read_with_retry, causes: DDCRC_DDC_DATA(10)]
- [   107][  0.878589] (read_unsupported_feature      ) Turning off dynamic sleep and retrying
- [   107][  1.299321] (read_unsupported_feature      ) busno=5, sleep-multiplier= 1.00, Retesting for unsupported feature 0xdd returned Error_Info[DDCRC_REPORTED_UNSUPPORTED in ddc_get_nontable_vcp_value_full]

steering received: S19 S20 S21 S22 S23 S24 S25 S26
options: a1-window.jpg, b1-workspace.jpg, c1-scroll.jpg, d1-prompt.jpg, f1-bar.jpg, g1-power.jpg, h2-menus.jpg, t1-transparency.jpg
