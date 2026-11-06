# round 28 pulse · Fri 06 09:13 (Dubai)

pace: 9/104 done (9%) · time used 9% · ahead -0.1 h · ETA Mon 09 23:33 · left 89 · blocked 0 · owner 6
alerts: none
run: conductor active · passes 1 (oldest 20 min) · last activity 16 min ago · commits since start 17 · hold False
machine: load 0.97 0.60 0.73/12 · mem free 19.8 GB · disk free 620 GB · up 9.0 h · cpu tccd1 51° · cpu tctl 56° · gpu edge 39° · gpu junction 32° · gpu mem 53° · ssd composite 44° · ssd sensor 1 44° · ssd sensor 2 47°
dark: True (active) · pulse timer active
tokens since start: out 236,022 · in 464 · cache write 769,874 · cache read 21,844,832 · msgs 219 · out last 6 h 93,007

## now / blocked / owner
- [now] f06f a fresh F45 install never gets its /home split: on the start after setup, fedokawaii-split fails on home/.asobi/snapshots/clean (a read-only snapshot, could not be moved) and puts everything back; verify then reds 1 of 272. Fix it, and make tools/vm-smoke.sh verify after setup's last reboot: it verified in the 15 s before it, so no smoke ever saw this. VM state r28-split-failed, ~/VM/harness/f45/smoke-20261106-075417/split-failed.txt — found in f06d
- [owner] o01 his picks on the options pack, relayed by Claude; each pick built, the others dropped — assumed meanwhile: my strongest
- [owner] o02 the RAM: restart, Delete, F7, OC, DRAM Frequency DDR5-4800, F10; then ram-check three copies for 20 minutes — still 5600 MT/s on 6 Nov; wrong bits measured, ledger r27-note-flips-2; say it before he installs anything built here
- [owner] o03 Phase E: his answers to the questionnaire applied: the last edit of the repo — then the ISO again
- [owner] o04 the ISO installed on his PC: fedokawaii lives there on Fedora 45, self-maintaining until Fedora 46 — the VM cannot show his firmware: the rehearsal first
- [owner] o05 T62: r28-track, r28-pulse, r28-dark, the round's sudo and polkit rules and linger removed, never in the ISO — 
- [owner] o06 triad, his private repo fluvia4ai/triad: a read-only deploy key's public key posted for him, added with his OK; installed by default, self-updating, taught in Part 1 — the last line, owner 00:24

## last done
- f04 the kit renders the tree with nothing applied: dwl, mako, yazi built into a scratch prefix, a throw-away home from theme.sh; one bar and one menu shot in both moods (Fri 6 Nov 03:45)
- f05 kawa-rgb off keeps everything dark across reboots, by reading its code and a test with no light lit; make it so if not (Fri 6 Nov 03:52)
- f06 a clean-install smoke of main in the Fedora 45 VM (tools/vm-smoke.sh, own unit): the baseline before round 28's changes (Fri 6 Nov 04:25)
- f06b tools/regress/items.py reads ledger ids only up to r27: teach it r28, so that a behaviour of this round can have its row (CLAUDE.md asks for it), r28-note-* exempt (Fri 6 Nov 04:26)
- f06c the fresh F45 journal has 2 SELinux denials at setup's end: snapperd_t asks init_t for reload (method_reload) during create-config; config and snapshots still work. Read snapper's source and policy: harmless, or a fix in setup (Fri 6 Nov 05:05)
- f06d the fresh F45 install has 69 other denials, all harmless so far: 51 are setup's lock (fd 9) inherited by children (restorecon, ip, usermod, passwd, sshd, pasta...), 12 load_policy reading /dev/tty1, 6 ldconfig reading the state folder as its cwd. Close fd 9 for children or set it close-on-exec; say what remains (Fri 6 Nov 08:52)

## commits
- Fri 08:53 1dca0aeb f06d done: setup's lock no longer reaches its children, 69 denials down to 15; f06f next
- Fri 05:06 95459209 f06c done: snapper's configs made without D-Bus, no SELinux denial at setup's end; f06d next
- Fri 04:26 64ac02f3 f06b done: the never-again list reads round 28's ids, r28-note-* exempt; f07 next
- Fri 04:25 fd11109b f06 done: clean install of main green in the Fedora 45 VM (271 passed, 4 hardware skips); f06b next
- Fri 03:55 21c26d06 f05 note: what was not proven, said plainly (no real reboot; the display before the service)
- Fri 03:55 c7e5538e f05 done: kawa-rgb off stays dark across reboots, proven by a case with no light lit; f06 next
- Fri 03:45 31994995 f04 done: the kit renders the tree with nothing applied; f05 next
- Fri 03:39 202d736f f03 done: train-f45 on main, Fedora 45 only; two stale sweep expectations fixed; f04 next

## repairs

## errors (2 h)

steering received: none
options: none yet
