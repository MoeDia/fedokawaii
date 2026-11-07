# round 28 pulse · Sat 07 21:15 (Dubai)

pace: 153/226 done (68%) · time used 45% · ahead 22.9 h · ETA Sun 08 16:33 · left 66 · blocked 0 · owner 7
alerts: usage limit hit 5× (last 2026-11-07T12:09 UTC); 3 errors in 2 h
run: conductor active · passes 1 (oldest 9 min) · last activity 1 min ago · commits since start 177 · hold False
machine: load 1.06 0.77 0.58/12 · mem free 18.6 GB · disk free 610 GB · up 45.0 h · cpu tccd1 53° · cpu tctl 65° · gpu edge 42° · gpu junction 35° · gpu mem 56° · ssd composite 38° · ssd sensor 1 39° · ssd sensor 2 39°
dark: True (active) · pulse timer active
tokens since start: out 2,941,471 · in 6,834 · cache write 10,624,221 · cache read 223,736,768 · msgs 3322 · out last 6 h 602,223
out by model: last 6 h claude-opus-5-5 511,368 · claude-sonnet-5-5 77,573 · claude-haiku-5-5 13,282 · since start claude-opus-5-5 2,485,546 · claude-sonnet-5-5 396,038 · claude-haiku-5-5 59,887

## now / blocked / owner
- [now] sb01 dojo sandbox: rootless podman (bubblewrap where too heavy) seeing only ~/dojo, no sudo, localhost-only servers, checkers inside; `dojo` command, launcher entry, Super+U; Space r/t/d run inside the box; `dojo reset` rebuilds the box but never deletes project files, wiping files a separate command that asks first; pages open in Helium — inbox S22, S23
- [owner] c1b his eyes on the cooler's display with the PC dark: no 99 (S6) — only he can see it; assumed: dark. If it still blinks: the steady real temperature instead (S6)
- [owner] o01 his picks on the options pack, relayed by Claude; each pick built, the others dropped — assumed meanwhile: my strongest, each in r28-questionnaire.md part A
- [owner] o02 the RAM: restart, Delete, F7, OC, DRAM Frequency DDR5-4800, F10; then ram-check three copies for 20 minutes — still 5600 MT/s on 6 Nov; wrong bits measured, ledger r27-note-flips-2; say it before he installs anything built here
- [owner] o03 Phase E: his answers to the questionnaire applied: the last edit of the repo — then the ISO again
- [owner] o04 the ISO installed on his PC: fedokawaii lives there on Fedora 45, self-maintaining until Fedora 46 — the VM cannot show his firmware: the rehearsal first
- [owner] o05 T62: r28-track, r28-pulse, r28-dark, r28-cooler, the round's sudo and polkit rules and linger removed, never in the ISO — 
- [owner] o06 triad, his private repo fluvia4ai/triad: a read-only deploy key's public key posted for him, added with his OK; installed by default, self-updating, taught in Part 1 — the last line, owner 00:24

## last done
- sa25d2e the jikusaki bar's widths, the last: the kanji's ink on x 960 measured (月 日 make the scroll 3 px narrower than 火); the date's 30th/31st (a 3 has no air: 17 px to the band, not 18) and a year ending in 1; tools/regress/bar-geometry.sh moved to 39 rows, 10 px paper to ink, 18 between the clock's parts, the 26 px seal on its 16 × 16 numeral, then run on the kit (both moods) (Sat 7 Nov 20:49)
- sa26 packages: smartmontools (smartd warns by notification and a line in the inventory/health) and LocalSend from its official release, not Flatpak, self-updating, port 53317 TCP+UDP in the home/LAN zone only; launcher, inventory, manifest checklist; tests (Sat 7 17:55)
- sa27 Neovim: our own colorscheme kawa generated from tools/build-themes.py tokens, both moods, following the live switch; gruvbox plugin dropped (Sat 7 20:53)
- sa27 dwl: menus open and close as his pick c 2 omori, under ASan headless, frames looked at (Sat 7 Nov 20:58)
- sa28 dwl: window open and close built: his pick a 5 mozaiku as the default, behind the same switch, the others one switch away (S9) (Sat 7 Nov 21:02)
- sa29 dwl: the workspace move built: his pick b 4 heya as the default, the others one switch away (S10) (Sat 7 Nov 21:05)

## commits
- Sat 21:05 ade1f8f4 sa29: dwl's workspaces move as his pick b-4 heya (360/0), headless frames looked at; -> sb01
- Sat 21:02 44be77bc sa28: dwl's windows open and close as his pick a-5 mozaiku (300/220), headless frames looked at; -> sa29
- Sat 20:58 cf71380e sa27: dwl's menus open and close as his pick c-2 omori (460/240), ASan headless, frames looked at; -> sa28
- Sat 20:53 be199210 sa27: Neovim's own colour scheme kawa (colors/kawa.lua from the palettes, both moods), gruvbox dropped
- Sat 20:49 42b1a2e4 sa25d2e: bar-geometry on the jikusaki bar (39 rows, 10 px, 18·18, the kanji on 960), Sumi UI 16 unsmoothed, a year ending in 1 (date.r4), the head centred; -> sa27
- Sat 20:39 23587ffa sa25d2d: the workspaces' numerals 16 x 16 for the bar, the seal 26 (thump 28) round them; rest -> sa25d2e
- Sat 20:35 9fe07094 sa25d2c: Sumi UI 16's air to 4 px (r4 classes), the clock's l1 gone; rest -> sa25d2d
- Sat 20:29 220f60b3 sa25c3: Sumi UI 16's Œ œ Ĳ ĳ Ŋ ŋ ĸ ŉ ſ drawn on its rows

## repairs

## errors (2 h)
- [   124][  1.239942] (read_unsupported_feature      ) busno=5, sleep-multiplier= 2.00, Testing for unsupported feature 0xdd returned Error_Info[DDCRC_RETRIES in ddc_write_read_with_retry, causes: DDCRC_DDC_DATA(10)]
- [   124][  1.240164] (read_unsupported_feature      ) Turning off dynamic sleep and retrying
- [   124][  1.345351] (read_unsupported_feature      ) busno=5, sleep-multiplier= 1.00, Retesting for unsupported feature 0xdd returned Error_Info[DDCRC_REPORTED_UNSUPPORTED in ddc_get_nontable_vcp_value_full]

steering received: S20 S21 S22 S23 S24 S25 S26 S27
options: a1-window.jpg, b1-workspace.jpg, c1-scroll.jpg, d1-prompt.jpg, f1-bar.jpg, g1-power.jpg, h2-menus.jpg, t1-transparency.jpg
