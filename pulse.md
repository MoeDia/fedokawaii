# round 28 pulse · Fri 06 10:43 (Dubai)

pace: 13/107 done (12%) · time used 10% · ahead 1.9 h · ETA Mon 09 08:00 · left 88 · blocked 0 · owner 6
alerts: 4 errors in 2 h
run: conductor active · passes 1 (oldest 48 min) · last activity 16 min ago · commits since start 21 · hold False
machine: load 3.50 1.61 1.11/12 · mem free 19.4 GB · disk free 620 GB · up 10.5 h · cpu tccd1 68° · cpu tctl 70° · gpu edge 44° · gpu junction 33° · gpu mem 54° · ssd composite 38° · ssd sensor 1 38° · ssd sensor 2 38°
dark: True (active) · pulse timer active
tokens since start: out 331,782 · in 632 · cache write 1,076,912 · cache read 27,440,807 · msgs 300 · out last 6 h 160,439

## now / blocked / owner
- [now] f06i the first report on the fresh F45 says BROKEN, 15 failures, 20 warnings, run with no session (~/VM/harness/f45/smoke-20261106-090130/first-report.txt). Sort them: needs a session, needs hardware, real. Suspects: FONT-02 Sumi UI not crisp, DISK-06 snapper, LOGIN-19 and SLP-20 power keys, UPK-21 and KEY-11 Super+U, kawa-browser and kawa-stick --help, FETCH-01 ble.sh. Fix the real ones, name the rest — with a session: 20 failures, 22 warnings, ~/VM/harness/f45/r28-f06h/after.txt
- [owner] o01 his picks on the options pack, relayed by Claude; each pick built, the others dropped — assumed meanwhile: my strongest
- [owner] o02 the RAM: restart, Delete, F7, OC, DRAM Frequency DDR5-4800, F10; then ram-check three copies for 20 minutes — still 5600 MT/s on 6 Nov; wrong bits measured, ledger r27-note-flips-2; say it before he installs anything built here
- [owner] o03 Phase E: his answers to the questionnaire applied: the last edit of the repo — then the ISO again
- [owner] o04 the ISO installed on his PC: fedokawaii lives there on Fedora 45, self-maintaining until Fedora 46 — the VM cannot show his firmware: the rehearsal first
- [owner] o05 T62: r28-track, r28-pulse, r28-dark, the round's sudo and polkit rules and linger removed, never in the ISO — 
- [owner] o06 triad, his private repo fluvia4ai/triad: a read-only deploy key's public key posted for him, added with his OK; installed by default, self-updating, taught in Part 1 — the last line, owner 00:24

## last done
- f06c the fresh F45 journal has 2 SELinux denials at setup's end: snapperd_t asks init_t for reload (method_reload) during create-config; config and snapshots still work. Read snapper's source and policy: harmless, or a fix in setup (Fri 6 Nov 05:05)
- f06d the fresh F45 install has 69 other denials, all harmless so far: 51 are setup's lock (fd 9) inherited by children (restorecon, ip, usermod, passwd, sshd, pasta...), 12 load_policy reading /dev/tty1, 6 ldconfig reading the state folder as its cwd. Close fd 9 for children or set it close-on-exec; say what remains (Fri 6 Nov 08:52)
- f06f a fresh F45 install never gets its /home split: on the start after setup, fedokawaii-split fails on home/.asobi/snapshots/clean (a read-only snapshot, could not be moved) and puts everything back; verify then reds 1 of 272. Fix it, and make tools/vm-smoke.sh verify after setup's last reboot: it verified in the 15 s before it, so no smoke ever saw this. VM state r28-split-failed, ~/VM/harness/f45/smoke-20261106-075417/split-failed.txt (Fri 6 Nov 09:33)
- f06e setup.log has "Failed to start transient service unit: Failed to set unit properties: Bad message" and "Failed to start jobs: Transport endpoint is not connected" after systemd's %triggerin scriptlet, 4 times, on the F45 install: whose, harmless or not (Fri 6 Nov 09:38)
- f06g the smoke's first look at the last boot: it started 09:26:07, systemctl is-system-running --wait returned only near 09:32:18. What holds a fresh start about 6 min before "running"? (VM f45, journal of smoke-20261106-090130's last boot; systemd-analyze blame) (Fri 6 Nov 09:40)
- f06h the first report gives up on the session after 5 min and is marked done, so a login at minute 6 keeps a report of "no desktop session", BROKEN, for good (system/fedokawaii-report:69, setup.sh s_report). Wait for the first login however long, without holding the start at "starting" (Type=exec, the done mark when it ends); tools/vm-smoke.sh waits for the report before its verify. tests/installer/test_report.sh (6 Nov 09:55)

## commits
- Fri 09:55 ab878c33 f06h done: the first report waits for the first login however long, marked only when it ended; f06i next
- Fri 09:40 53a74472 f06g done: the 6 min before "running" is the first health report waiting for a session; f06h next
- Fri 09:38 ba6e824b f06e done: the Bad message lines are SELinux refusing PID 1 dnf's pipe, harmless on install; f06g next
- Fri 09:33 f059d95b f06f done: a fresh install's split moves read-only subvolumes, the smoke verifies after the last reboot; f06e next
- Fri 08:53 1dca0aeb f06d done: setup's lock no longer reaches its children, 69 denials down to 15; f06f next
- Fri 05:06 95459209 f06c done: snapper's configs made without D-Bus, no SELinux denial at setup's end; f06d next
- Fri 04:26 64ac02f3 f06b done: the never-again list reads round 28's ids, r28-note-* exempt; f07 next
- Fri 04:25 fd11109b f06 done: clean install of main green in the Fedora 45 VM (271 passed, 4 hardware skips); f06b next

## repairs

## errors (2 h)
- End of file while reading data: Input/output error
- End of file while reading data: Input/output error
- End of file while reading data: Input/output error
- End of file while reading data: Input/output error

steering received: none
options: none yet
