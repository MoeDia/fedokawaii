# round 28 pulse · Sat 07 11:15 (Dubai)

pace: 72/171 done (42%) · time used 35% · ahead 7.4 h · ETA Mon 09 07:39 · left 92 · blocked 0 · owner 7
alerts: none
run: conductor active · passes 1 (oldest 2 min) · last activity 2 min ago · commits since start 99 · hold False
machine: load 0.16 0.31 0.36/12 · mem free 19.2 GB · disk free 611 GB · up 35.0 h · cpu tccd1 38° · cpu tctl 46° · gpu edge 40° · gpu junction 34° · gpu mem 54° · ssd composite 39° · ssd sensor 1 39° · ssd sensor 2 40°
dark: True (active) · pulse timer active
tokens since start: out 1,881,577 · in 3,030 · cache write 6,162,309 · cache read 109,746,096 · msgs 1437 · out last 6 h 110,716
out by model: last 6 h claude-opus-5-5 71,667 · claude-haiku-5-5 22,644 · claude-sonnet-5-5 16,405 · since start claude-opus-5-5 1,818,877 · claude-haiku-5-5 38,386 · claude-sonnet-5-5 24,314

## now / blocked / owner
- [now] f27 the book retired: Learn PDF, its build and every entry that opens it gone; its content kept as the source of the lessons; tests — 
- [owner] c1b his eyes on the cooler's display with the PC dark: no 99 (S6) — only he can see it; assumed: dark. If it still blinks: the steady real temperature instead (S6)
- [owner] o01 his picks on the options pack, relayed by Claude; each pick built, the others dropped — assumed meanwhile: my strongest, each in r28-questionnaire.md part A
- [owner] o02 the RAM: restart, Delete, F7, OC, DRAM Frequency DDR5-4800, F10; then ram-check three copies for 20 minutes — still 5600 MT/s on 6 Nov; wrong bits measured, ledger r27-note-flips-2; say it before he installs anything built here
- [owner] o03 Phase E: his answers to the questionnaire applied: the last edit of the repo — then the ISO again
- [owner] o04 the ISO installed on his PC: fedokawaii lives there on Fedora 45, self-maintaining until Fedora 46 — the VM cannot show his firmware: the rehearsal first
- [owner] o05 T62: r28-track, r28-pulse, r28-dark, r28-cooler, the round's sudo and polkit rules and linger removed, never in the ISO — 
- [owner] o06 triad, his private repo fluvia4ai/triad: a read-only deploy key's public key posted for him, added with his OK; installed by default, self-updating, taught in Part 1 — the last line, owner 00:24

## last done
- s11e ~/.local/bin/r28-track: pulse.md's tokens line also splits output tokens by model (message.model), last 6 hours and since the start; its CLI and page keep working; restarted (S11) (Sat 7 Nov 01:45)
- dsat daily (S11): the full suite (bash tests/run.sh) and a full clean-install VM run (tools/vm-smoke.sh f45, one VM at a time, own unit); red fixed or blocked with why (Sat 7 Nov 03:36 +04)
- s13a model mix (S13): check that open rows carry sonnet/haiku per S11 and that the loop passes --model (message.model in the latest transcript); fix what is off (Sat 7 Nov 11:10)
- s14a pace (S14): long jobs as their own systemd user units, the pass marks the row running and goes on; no idle between passes (loop sleep, conductor interval); daily rows gated by day and 12 h (Sat 7 Nov 11:11)
- s15a self-audit every 6 passes on haiku (S15): pace/ETA, no daily before its day, model mix, passes over 90 min and idle gaps, blocked rows over 6 h get a fresh try, design track not crowding out the rest; notes in the plan (Sat 07 Nov 11:11)
- f26 kawa-learn rebuilt on it: today's pair, progress, next, in Super+U's Learning; both moods, many sizes; tests (Sat 7 Nov 11:08)

## commits
- Sat 11:12 4b6270d9 s15a done: self-audit (pace, model mix, passes); dsun dmon dtue reopened for their days; l4 fresh try; f27 now
- Sat 11:11 e11cda65 s14a done: pace rules (units for long jobs, daily gate), nonstop gap 1 s; s15a now
- Sat 11:10 a0df31fd s13a done: model mix checked, 13 rows to sonnet, START names the now-row lookup; s14a now
- Sat 11:08 ec35cab5 f26 done: kawa-learn rebuilt on the daily lessons; s13a now
- Sat 10:38 c5337e3a f20c done: ~/Projects poured into ~/dojo, tested; S12-S15 in the plan; f26 now
- Sat 10:36 5e59f35f r28-dtue done: full suite (165/165) and f45 VM smoke green; f20c now
- Sat 07:59 77d047a9 r28-dmon done: full suite (165/165) and f45 VM smoke green; dtue now
- Sat 05:34 ff846836 r28-dsun done: full suite (164/165, test_list ledger id fixed) and f45 VM smoke green; dmon now

## repairs

## errors (2 h)

steering received: S8 S9 S10 S11 S12 S13 S14 S15
options: a1-window.jpg, b1-workspace.jpg, c1-scroll.jpg, d1-prompt.jpg, e1-lock.jpg, e2-lock.jpg, f1-bar.jpg, g1-power.jpg, h1-menus.jpg, h2-menus.jpg, i1-helium.jpg
