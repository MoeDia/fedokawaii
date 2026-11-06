# round 28 pulse · Fri 06 09:43 (Dubai)

pace: 12/107 done (11%) · time used 9% · ahead 2.0 h · ETA Mon 09 06:07 · left 89 · blocked 0 · owner 6
alerts: 2 errors in 2 h
run: conductor active · passes 1 (oldest 2 min) · last activity 1 min ago · commits since start 20 · hold False
machine: load 0.91 0.47 0.63/12 · mem free 26.8 GB · disk free 612 GB · up 9.5 h · cpu tccd1 51° · cpu tctl 57° · gpu edge 40° · gpu junction 32° · gpu mem 54° · ssd composite 37° · ssd sensor 1 37° · ssd sensor 2 37°
dark: True (active) · pulse timer active
tokens since start: out 281,396 · in 548 · cache write 936,786 · cache read 23,956,667 · msgs 260 · out last 6 h 138,381

## now / blocked / owner
- [now] f06h the first report gives up on the session after 5 min and is marked done, so a login at minute 6 keeps a report of "no desktop session", BROKEN, for good (system/fedokawaii-report:69, setup.sh s_report). Wait for the first login however long, without holding the start at "starting" (Type=exec, the done mark when it ends); tools/vm-smoke.sh waits for the report before its verify. tests/installer/test_report.sh — found in f06g
- [owner] o01 his picks on the options pack, relayed by Claude; each pick built, the others dropped — assumed meanwhile: my strongest
- [owner] o02 the RAM: restart, Delete, F7, OC, DRAM Frequency DDR5-4800, F10; then ram-check three copies for 20 minutes — still 5600 MT/s on 6 Nov; wrong bits measured, ledger r27-note-flips-2; say it before he installs anything built here
- [owner] o03 Phase E: his answers to the questionnaire applied: the last edit of the repo — then the ISO again
- [owner] o04 the ISO installed on his PC: fedokawaii lives there on Fedora 45, self-maintaining until Fedora 46 — the VM cannot show his firmware: the rehearsal first
- [owner] o05 T62: r28-track, r28-pulse, r28-dark, the round's sudo and polkit rules and linger removed, never in the ISO — 
- [owner] o06 triad, his private repo fluvia4ai/triad: a read-only deploy key's public key posted for him, added with his OK; installed by default, self-updating, taught in Part 1 — the last line, owner 00:24

## last done
- f06b tools/regress/items.py reads ledger ids only up to r27: teach it r28, so that a behaviour of this round can have its row (CLAUDE.md asks for it), r28-note-* exempt (Fri 6 Nov 04:26)
- f06c the fresh F45 journal has 2 SELinux denials at setup's end: snapperd_t asks init_t for reload (method_reload) during create-config; config and snapshots still work. Read snapper's source and policy: harmless, or a fix in setup (Fri 6 Nov 05:05)
- f06d the fresh F45 install has 69 other denials, all harmless so far: 51 are setup's lock (fd 9) inherited by children (restorecon, ip, usermod, passwd, sshd, pasta...), 12 load_policy reading /dev/tty1, 6 ldconfig reading the state folder as its cwd. Close fd 9 for children or set it close-on-exec; say what remains (Fri 6 Nov 08:52)
- f06f a fresh F45 install never gets its /home split: on the start after setup, fedokawaii-split fails on home/.asobi/snapshots/clean (a read-only snapshot, could not be moved) and puts everything back; verify then reds 1 of 272. Fix it, and make tools/vm-smoke.sh verify after setup's last reboot: it verified in the 15 s before it, so no smoke ever saw this. VM state r28-split-failed, ~/VM/harness/f45/smoke-20261106-075417/split-failed.txt (Fri 6 Nov 09:33)
- f06e setup.log has "Failed to start transient service unit: Failed to set unit properties: Bad message" and "Failed to start jobs: Transport endpoint is not connected" after systemd's %triggerin scriptlet, 4 times, on the F45 install: whose, harmless or not (Fri 6 Nov 09:38)
- f06g the smoke's first look at the last boot: it started 09:26:07, systemctl is-system-running --wait returned only near 09:32:18. What holds a fresh start about 6 min before "running"? (VM f45, journal of smoke-20261106-090130's last boot; systemd-analyze blame) (Fri 6 Nov 09:40)

## commits
- Fri 09:40 53a74472 f06g done: the 6 min before "running" is the first health report waiting for a session; f06h next
- Fri 09:38 ba6e824b f06e done: the Bad message lines are SELinux refusing PID 1 dnf's pipe, harmless on install; f06g next
- Fri 09:33 f059d95b f06f done: a fresh install's split moves read-only subvolumes, the smoke verifies after the last reboot; f06e next
- Fri 08:53 1dca0aeb f06d done: setup's lock no longer reaches its children, 69 denials down to 15; f06f next
- Fri 05:06 95459209 f06c done: snapper's configs made without D-Bus, no SELinux denial at setup's end; f06d next
- Fri 04:26 64ac02f3 f06b done: the never-again list reads round 28's ids, r28-note-* exempt; f07 next
- Fri 04:25 fd11109b f06 done: clean install of main green in the Fedora 45 VM (271 passed, 4 hardware skips); f06b next
- Fri 03:55 21c26d06 f05 note: what was not proven, said plainly (no real reboot; the display before the service)

## repairs

## errors (2 h)
- End of file while reading data: Input/output error
- End of file while reading data: Input/output error

steering received: none
options: none yet
