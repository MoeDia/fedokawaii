# round 28 pulse · Sat 07 22:15 (Dubai)

pace: 161/230 done (70%) · time used 46% · ahead 24.2 h · ETA Sun 08 15:52 · left 62 · blocked 0 · owner 7
alerts: usage limit hit 5× (last 2026-11-07T12:09 UTC); 3 errors in 2 h
run: conductor active · passes 1 (oldest 7 min) · last activity 0 min ago · commits since start 186 · hold False
machine: load 1.00 0.63 0.53/12 · mem free 18.9 GB · disk free 610 GB · up 46.0 h · cpu tccd1 39° · cpu tctl 49° · gpu edge 41° · gpu junction 35° · gpu mem 56° · ssd composite 39° · ssd sensor 1 40° · ssd sensor 2 41°
dark: True (active) · pulse timer active
tokens since start: out 3,070,975 · in 7,344 · cache write 11,135,219 · cache read 238,207,943 · msgs 3574 · out last 6 h 669,109
out by model: last 6 h claude-opus-5-5 544,804 · claude-sonnet-5-5 106,867 · claude-haiku-5-5 17,438 · since start claude-opus-5-5 2,573,023 · claude-sonnet-5-5 433,909 · claude-haiku-5-5 64,043

## now / blocked / owner
- [now] sb03b sb03 rest: kawa-learn daily 5-minute review screen (uses lib/review.py due/add_review; record ~/.local/state/fedokawaii/reviews), checkers per exercise, concept map page (concepts()), explain-it-back note in ~/notes with checklist, weekly look back + quiet rank/streak in a corner, about page citing the learning science (docs/lesson-standard.md list) — inbox S19, S20
- [owner] c1b his eyes on the cooler's display with the PC dark: no 99 (S6) — only he can see it; assumed: dark. If it still blinks: the steady real temperature instead (S6)
- [owner] o01 his picks on the options pack, relayed by Claude; each pick built, the others dropped — assumed meanwhile: my strongest, each in r28-questionnaire.md part A
- [owner] o02 the RAM: restart, Delete, F7, OC, DRAM Frequency DDR5-4800, F10; then ram-check three copies for 20 minutes — still 5600 MT/s on 6 Nov; wrong bits measured, ledger r27-note-flips-2; say it before he installs anything built here
- [owner] o03 Phase E: his answers to the questionnaire applied: the last edit of the repo — then the ISO again
- [owner] o04 the ISO installed on his PC: fedokawaii lives there on Fedora 45, self-maintaining until Fedora 46 — the VM cannot show his firmware: the rehearsal first
- [owner] o05 T62: r28-track, r28-pulse, r28-dark, r28-cooler, the round's sudo and polkit rules and linger removed, never in the ISO — 
- [owner] o06 triad, his private repo fluvia4ai/triad: a read-only deploy key's public key posted for him, added with his OK; installed by default, self-updating, taught in Part 1 — the last line, owner 00:24

## last done
- sa27 dwl: menus open and close as his pick c 2 omori, under ASan headless, frames looked at (Sat 7 Nov 20:58)
- sa28 dwl: window open and close built: his pick a 5 mozaiku as the default, behind the same switch, the others one switch away (S9) (Sat 7 Nov 21:02)
- sa29 dwl: the workspace move built: his pick b 4 heya as the default, the others one switch away (S10) (Sat 7 Nov 21:05)
- sb01 dojo sandbox: rootless podman (bubblewrap where too heavy) seeing only ~/dojo, no sudo, localhost-only servers, checkers inside; `dojo` command, launcher entry, Super+U; Space r/t/d run inside the box; `dojo reset` rebuilds the box but never deletes project files, wiping files a separate command that asks first; pages open in Helium (Sat 7 21:16)
- sb02 lesson standard (S18, S19, S21): example first, 2 parts practice to 1 reading, one idea each, plain words with a definition box and a glossary page, 3-question check, 'Behind the scenes' part with a real tool, 'checked against' line, common-mistakes box; lessons open as a calm local page (60-70 char column, line height 1.6, 18-20 px, WCAG AA, click-to-advance pictures, reduced motion); rank and streak quiet (Sat 7 Nov 22:05)
- sb03 learning engine: checkers per exercise, 5-minute spaced daily review (1, 3, 7, 14 days; learned after 3 right answers on different days), concept map page, explain-it-back in ~/notes, weekly look back, quiet dojo rank and streak; about page citing the learning science used (Sat 7 22:07)

## commits
- Sat 22:07 a0790e34 sb03: the spaced daily review core (lib/review.py), tested; the rest -> sb03b
- Sat 22:05 f0bb5f16 sb02: the lesson standard 2, checked by lib/lessons.py; docs/lesson-standard.md; the page -> sb02b
- Sat 21:45 0d5e321d d3b: keycaps in the power dialog (under each seal's word) and on Helium's new tab
- Sat 21:36 46aedc45 sa29: plan: one now (dsun2), next sb02 noted
- Sat 21:36 18dcd739 sa29: Part 2 re-ordered: Python and Bash first, then short units, web and TUI, then Rust; track list in the syllabus
- Sat 21:31 19baebfb sa25d3: FONT-09 checks Sumi Icons Bar and Sumi UI 16 (and Bold) against the toolkit's; rest -> sa25d3b
- Sat 21:29 e73dd504 sa28: Neovim Rust: inlay hints on in Rust buffers, Space c h toggles them; crates.nvim not added
- Sat 21:26 c26c4828 sa15e3: tairyoku's inks on the glyph meters: the downloads mark, Super+R's books, torrents (C_HP/C_HP_HI, foot 34/35, no fire)

## repairs

## errors (2 h)
- [   124][  1.239942] (read_unsupported_feature      ) busno=5, sleep-multiplier= 2.00, Testing for unsupported feature 0xdd returned Error_Info[DDCRC_RETRIES in ddc_write_read_with_retry, causes: DDCRC_DDC_DATA(10)]
- [   124][  1.240164] (read_unsupported_feature      ) Turning off dynamic sleep and retrying
- [   124][  1.345351] (read_unsupported_feature      ) busno=5, sleep-multiplier= 1.00, Retesting for unsupported feature 0xdd returned Error_Info[DDCRC_REPORTED_UNSUPPORTED in ddc_get_nontable_vcp_value_full]

steering received: S20 S21 S22 S23 S24 S25 S26 S27
options: a1-window.jpg, b1-workspace.jpg, c1-scroll.jpg, d1-prompt.jpg, f1-bar.jpg, g1-power.jpg, h2-menus.jpg, t1-transparency.jpg
