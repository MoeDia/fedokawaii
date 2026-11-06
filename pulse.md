# round 28 pulse · Fri 06 13:13 (Dubai)

pace: 26/110 done (24%) · time used 13% · ahead 10.9 h · ETA Sun 08 03:24 · left 78 · blocked 0 · owner 6
alerts: 39 errors in 2 h
run: conductor active · passes 1 (oldest 12 min) · last activity 11 min ago · commits since start 38 · hold False
machine: load 0.00 0.05 0.18/12 · mem free 27.4 GB · disk free 612 GB · up 13.0 h · cpu tccd1 36° · cpu tctl 44° · gpu edge 39° · gpu junction 33° · gpu mem 54° · ssd composite 39° · ssd sensor 1 39° · ssd sensor 2 39°
dark: True (active) · pulse timer active
tokens since start: out 700,035 · in 1,122 · cache write 2,200,513 · cache read 44,053,520 · msgs 537 · out last 6 h 498,630

## now / blocked / owner
- [now] f16 the pack published: captions.txt, 16 files and 300 KB at most, seen in the pulse; r28-questionnaire.md begun with every assumption so far — 
- [owner] o01 his picks on the options pack, relayed by Claude; each pick built, the others dropped — assumed meanwhile: my strongest
- [owner] o02 the RAM: restart, Delete, F7, OC, DRAM Frequency DDR5-4800, F10; then ram-check three copies for 20 minutes — still 5600 MT/s on 6 Nov; wrong bits measured, ledger r27-note-flips-2; say it before he installs anything built here
- [owner] o03 Phase E: his answers to the questionnaire applied: the last edit of the repo — then the ISO again
- [owner] o04 the ISO installed on his PC: fedokawaii lives there on Fedora 45, self-maintaining until Fedora 46 — the VM cannot show his firmware: the rehearsal first
- [owner] o05 T62: r28-track, r28-pulse, r28-dark, the round's sudo and polkit rules and linger removed, never in the ISO — 
- [owner] o06 triad, his private repo fluvia4ai/triad: a read-only deploy key's public key posted for him, added with his OK; installed by default, self-updating, taught in Part 1 — the last line, owner 00:24

## last done
- f12 options (f) the bar: bigger, icons at real size, crisp, the clock in a scroll with dominant ends, seconds kept, fully floating: 3, both moods: f1-bar.jpg (Fri 6 Nov 12:02)
- f13 options (g) the power menu: 3 layouts, both moods: g1-power.jpg (Fri 6 Nov 12:14)
- f14 options (h) Super+U and Super+R tightened: 2 layouts each: h1-menus.jpg (Fri 6 Nov 12:22)
- f14b the kit with --tree stopped after the power dialog's first shot: a play's key Right never returned, twice, both moods, exit 124 (f13). Run tools/regress/power-dialog.sh --tree ~/.cache/r28/kit-tree: a kit fault, or keys lost in the tree's dialog? (Fri 6 Nov 12:33)
- f15 options (i) Helium's theme, a TUI of ours in both moods, a symmetrical toolbar: 3 sheets from a headless browser: i1-helium.jpg (Fri 6 Nov 12:44)
- f15b a browser started in a headless dwl after wtype's keyboard had gone showed no window (f15, every time; one dwl a shot avoids it): a kit fault, or a dwl bug with a virtual keyboard that a real session could meet? Reproduce with a small client, headless only (12:47)

## commits
- Fri 13:00 e0efec78 f06j: its regress row in the form items.py reads
- Fri 13:00 2d0945a5 f06j done: the first report shows nothing on the first login; BOOT-22, RES-04 and PERF-01 false alarms fixed; next row now
- Fri 12:49 4cc2adc2 f15b repaired: dwl.patch back with f07 to f09's motions, the seat's keyboard fix on top
- Fri 12:47 b75e873f f15b done: a dwl bug, a virtual keyboard's end left the seat without one and Helium segfaulted; next row now
- Fri 12:44 46a176db f15 done: three Helium themes from the real browser on i1-helium.jpg; f15b found, now
- Fri 12:33 ddd28b2c f14b done: a kit fault, no key lost: ready no longer misses an idle panel's request; next row now
- Fri 12:22 b127210f f14 done: Super+U and Super+R tightened, two layouts each, on h1-menus.jpg and h2-menus.jpg; next row now
- Fri 12:14 4d89283b f13 done: three power menu layouts on g1-power.jpg; next row now

## repairs

## errors (2 h)
- #8  0x0000559adf6800d0 n/a (helium + 0x426c0d0)
- #9  0x00007f326ab4dc42 start_thread (libc.so.6 + 0x72c42)
- #10 0x00007f326abd15ac __clone3 (libc.so.6 + 0xf65ac)
- ELF object binary architecture: AMD x86-64

steering received: none
options: a1-window.jpg, b1-workspace.jpg, c1-scroll.jpg, d1-prompt.jpg, e1-lock.jpg, e2-lock.jpg, f1-bar.jpg, g1-power.jpg, h1-menus.jpg, h2-menus.jpg, i1-helium.jpg
