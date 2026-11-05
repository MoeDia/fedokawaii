# round 28 pulse · Fri 06 02:13 (Dubai)

pace: 2/99 done (2%) · time used 2% · ahead 0.3 h · ETA Mon 09 08:27 · left 91 · blocked 0 · owner 6
alerts: 32 errors in 2 h
run: conductor active · passes 1 (oldest 19 min) · last activity 19 min ago · commits since start 8 · hold False
machine: load 0.06 0.17 0.35/12 · mem free 27.4 GB · disk free 605 GB · up 2.0 h · cpu tccd1 38° · cpu tctl 43° · gpu edge 36° · gpu junction 30° · gpu mem 52° · ssd composite 44° · ssd sensor 1 44° · ssd sensor 2 47°
dark: True (active) · pulse timer active
tokens since start: out 101,221 · in 172 · cache write 223,790 · cache read 14,637,841 · msgs 84 · out last 6 h 101,221

## now / blocked / owner
- [now] f03 train-f45 onto main: the tree is Fedora 45 only (the PC stays on 44, nothing applied); read test_upgrade's and test_toolkit_move's reds first — ledger r27-note-f45-merge
- [owner] o01 his picks on the options pack, relayed by Claude; each pick built, the others dropped — assumed meanwhile: my strongest
- [owner] o02 the RAM: restart, Delete, F7, OC, DRAM Frequency DDR5-4800, F10; then ram-check three copies for 20 minutes — still 5600 MT/s on 6 Nov; wrong bits measured, ledger r27-note-flips-2; say it before he installs anything built here
- [owner] o03 Phase E: his answers to the questionnaire applied: the last edit of the repo — then the ISO again
- [owner] o04 the ISO installed on his PC: fedokawaii lives there on Fedora 45, self-maintaining until Fedora 46 — the VM cannot show his firmware: the rehearsal first
- [owner] o05 T62: r28-track, r28-pulse, r28-dark, the round's sudo and polkit rules and linger removed, never in the ISO — 
- [owner] o06 triad, his private repo fluvia4ai/triad: a read-only deploy key's public key posted for him, added with his OK; installed by default, self-updating, taught in Part 1 — the last line, owner 00:24

## last done
- f01 the plan: this file; both inbox blocks marked; CLAUDE.md cut to what a pass needs (the r27 digest moved to .claude/notes/r27-digest.md, word for word) (Fri 06 00:52)
- f02 the train onto main: every lane merged, its last reds fixed, the installer area green, main fast-forwarded and pushed (Fri 6 Nov 01:53)

## commits
- Fri 01:53 b70c6f1a f02 done: the train is on main, the installer area green; f03 next
- Fri 01:52 08a38934 Merge branch 'train-head'
- Fri 01:41 471c5eab a clone's round-only files are no difference from the toolkit: git's own reason is said; the Widevine case runs setup's own s_widevine
- Fri 00:54 1498acb4 CLAUDE.md: a pass waits for its own long job in one loop, it never ends just to look again
- Fri 00:53 36f53935 the ledger: what the train's reds were (five real bugs fixed on train-head), the run's hand-over to the conductor
- Fri 00:53 47b2f1b7 the fake machine answers rpm -qa and the fixer's CSS check; the undo case sets up its own red
- Fri 00:52 6da65703 round 28 begins: the plan (r28-plan.tsv, 99 rows by day), both inbox blocks marked, CLAUDE.md cut to what a pass needs
- Fri 00:45 3329df65 setup's IFS has no space: the update guard's library list stood empty, Widevine never came through setup

## repairs

## errors (2 h)
- #4  0x00007facaef55681 __libc_start_call_main (libc.so.6 + 0x3681)
- #5  0x00007facaef55798 __libc_start_main@@GLIBC_2.34 (libc.so.6 + 0x3798)
- #6  0x000055629df704d5 _start (bwrap + 0x44d5)
- ELF object binary architecture: AMD x86-64

steering received: none
options: none yet
