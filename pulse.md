# round 28 pulse · Sat 07 23:15 (Dubai)

pace: 167/239 done (70%) · time used 47% · ahead 23.1 h · ETA Sun 08 17:43 · left 66 · blocked 0 · owner 6
alerts: usage limit hit 5× (last 2026-11-07T12:09 UTC)
run: conductor active · passes 1 (oldest 2 min) · last activity 0 min ago · commits since start 192 · hold False
machine: load 0.66 0.68 0.53/12 · mem free 18.5 GB · disk free 610 GB · up 47.0 h · cpu tccd1 48° · cpu tctl 55° · gpu edge 43° · gpu junction 36° · gpu mem 56° · ssd composite 43° · ssd sensor 1 43° · ssd sensor 2 46°
dark: True (active) · pulse timer active
tokens since start: out 3,251,235 · in 7,922 · cache write 11,717,212 · cache read 258,219,574 · msgs 3862 · out last 6 h 836,278
out by model: last 6 h claude-opus-5-5 715,294 · claude-sonnet-5-5 103,546 · claude-haiku-5-5 17,438 · since start claude-opus-5-5 2,751,207 · claude-sonnet-5-5 435,985 · claude-haiku-5-5 64,043

## now / blocked / owner
- [now] dsun2 daily (S11/S13/S14): suite + clean-install VM, only on Sun 8 Dubai time, skipped if the last daily passed under 12 h ago with no system-level change since; VM as its own background unit — S13,S14; not before its own day (Dubai date): until then the next row is the first todo dated today or earlier; design track: next sa25d3c, then sb04b
- [owner] c1b his eyes on the cooler's display with the PC dark: no 99 (S6) — only he can see it; assumed: dark. If it still blinks: the steady real temperature instead (S6)
- [owner] o01 his picks on the options pack, relayed by Claude; each pick built, the others dropped — assumed meanwhile: my strongest, each in r28-questionnaire.md part A
- [owner] o03 Phase E: his answers to the questionnaire applied: the last edit of the repo — then the ISO again
- [owner] o04 the ISO installed on his PC: fedokawaii lives there on Fedora 45, self-maintaining until Fedora 46 — the VM cannot show his firmware: the rehearsal first
- [owner] o05 T62: r28-track, r28-pulse, r28-dark, r28-cooler, the round's sudo and polkit rules and linger removed, never in the ISO — 
- [owner] o06 triad, his private repo fluvia4ai/triad: a read-only deploy key's public key posted for him, added with his OK; installed by default, self-updating, taught in Part 1 — the last line, owner 00:24

## last done
- sb01 dojo sandbox: rootless podman (bubblewrap where too heavy) seeing only ~/dojo, no sudo, localhost-only servers, checkers inside; `dojo` command, launcher entry, Super+U; Space r/t/d run inside the box; `dojo reset` rebuilds the box but never deletes project files, wiping files a separate command that asks first; pages open in Helium (Sat 7 21:16)
- sb02 lesson standard (S18, S19, S21): example first, 2 parts practice to 1 reading, one idea each, plain words with a definition box and a glossary page, 3-question check, 'Behind the scenes' part with a real tool, 'checked against' line, common-mistakes box; lessons open as a calm local page (60-70 char column, line height 1.6, 18-20 px, WCAG AA, click-to-advance pictures, reduced motion); rank and streak quiet (Sat 7 Nov 22:05)
- sb02b the calm lesson page (docs/lesson-standard.md 'The page'): kawa-learn opens a standard-2 lesson as a local page in Helium, offline: 66-char column, line height 1.6, 19 px, Sumi Term code, 4 px grid, theme inks both moods, WCAG AA measured by the build, [[keys]] as h2 keycaps, SVG step pictures advance on click/key, reduced motion; headless Helium renders both moods (Sat 7 22:33)
- sb03 learning engine: checkers per exercise, 5-minute spaced daily review (1, 3, 7, 14 days; learned after 3 right answers on different days), concept map page, explain-it-back in ~/notes, weekly look back, quiet dojo rank and streak; about page citing the learning science used (Sat 7 22:07)
- sb03b sb03 rest: kawa-learn daily 5-minute review screen (uses lib/review.py due/add_review; record ~/.local/state/fedokawaii/reviews), checkers per exercise, concept map page (concepts()), explain-it-back note in ~/notes with checklist, weekly look back + quiet rank/streak in a corner, about page citing the learning science (docs/lesson-standard.md list) (Sat 7 Nov 22:16)
- sb04 rewrite Part 1 and Part 2 lessons to sb02's standard (first 14 days first; one row per ~3 days): days 1-3 (login-and-screen, first-print, six-keys, variables, tiling-windows, numbers) + the course test runs every example with its output (Sat 7 Nov 22:44)

## commits
- Sat 23:12 ef36d75d pm01: panel-measure reads yubi, Super+U's edge, the notice and calendar from y 44
- Sat 22:59 9de4b6b0 sa25d3c: the gear and the weather skies at 20; menu-first-click and panel-measure on y 44
- Sat 22:45 63aafd17 sb04: lessons days 1-3 on standard 2; the course test runs every example against its output
- Sat 22:33 ed4d4b98 sb02b: the calm lesson page: kawa-learn --page opens a standard-2 lesson in Helium, offline
- Sat 22:24 c983aaca sa25d3b: the bar's head at 32 (a hand-drawn 26 px Fedora disc, 10 px of paper either side); the rest -> sa25d3c
- Sat 22:16 b75ac5fe sb03b: kawa-learn daily review, concept map, week and rank, explain-it-back note
- Sat 22:07 a0790e34 sb03: the spaced daily review core (lib/review.py), tested; the rest -> sb03b
- Sat 22:05 f0bb5f16 sb02: the lesson standard 2, checked by lib/lessons.py; docs/lesson-standard.md; the page -> sb02b

## repairs

## errors (2 h)

steering received: S22 S23 S24 S25 S26 S27 S28 S29
options: a1-window.jpg, b1-workspace.jpg, c1-scroll.jpg, d1-prompt.jpg, f1-bar.jpg, g1-power.jpg, h2-menus.jpg, t1-transparency.jpg
