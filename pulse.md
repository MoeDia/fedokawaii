# round 28 pulse · Fri 06 11:14 (Dubai)

pace: 16/108 done (15%) · time used 11% · ahead 4.1 h · ETA Sun 08 20:55 · left 86 · blocked 0 · owner 6
alerts: 8 errors in 2 h
run: conductor active · passes 1 (oldest 0 min) · last activity 0 min ago · commits since start 25 · hold False
machine: load 0.11 0.33 0.53/12 · mem free 27.4 GB · disk free 612 GB · up 11.0 h · cpu tccd1 42° · cpu tctl 45° · gpu edge 39° · gpu junction 34° · gpu mem 54° · ssd composite 39° · ssd sensor 1 39° · ssd sensor 2 40°
dark: True (active) · pulse timer active
tokens since start: out 395,664 · in 718 · cache write 1,283,899 · cache read 30,540,845 · msgs 342 · out last 6 h 200,805

## now / blocked / owner
- [now] f09 options (c) menus as a real hanging scroll, rods, paper, edges, drawn through dwl's border system: 3 motions, filmstrips: c1-scroll.jpg — 
- [owner] o01 his picks on the options pack, relayed by Claude; each pick built, the others dropped — assumed meanwhile: my strongest
- [owner] o02 the RAM: restart, Delete, F7, OC, DRAM Frequency DDR5-4800, F10; then ram-check three copies for 20 minutes — still 5600 MT/s on 6 Nov; wrong bits measured, ledger r27-note-flips-2; say it before he installs anything built here
- [owner] o03 Phase E: his answers to the questionnaire applied: the last edit of the repo — then the ISO again
- [owner] o04 the ISO installed on his PC: fedokawaii lives there on Fedora 45, self-maintaining until Fedora 46 — the VM cannot show his firmware: the rehearsal first
- [owner] o05 T62: r28-track, r28-pulse, r28-dark, the round's sudo and polkit rules and linger removed, never in the ISO — 
- [owner] o06 triad, his private repo fluvia4ai/triad: a read-only deploy key's public key posted for him, added with his OK; installed by default, self-updating, taught in Part 1 — the last line, owner 00:24

## last done
- f06e setup.log has "Failed to start transient service unit: Failed to set unit properties: Bad message" and "Failed to start jobs: Transport endpoint is not connected" after systemd's %triggerin scriptlet, 4 times, on the F45 install: whose, harmless or not (Fri 6 Nov 09:38)
- f06g the smoke's first look at the last boot: it started 09:26:07, systemctl is-system-running --wait returned only near 09:32:18. What holds a fresh start about 6 min before "running"? (VM f45, journal of smoke-20261106-090130's last boot; systemd-analyze blame) (Fri 6 Nov 09:40)
- f06h the first report gives up on the session after 5 min and is marked done, so a login at minute 6 keeps a report of "no desktop session", BROKEN, for good (system/fedokawaii-report:69, setup.sh s_report). Wait for the first login however long, without holding the start at "starting" (Type=exec, the done mark when it ends); tools/vm-smoke.sh waits for the report before its verify. tests/installer/test_report.sh (6 Nov 09:55)
- f06i the first report on the fresh F45 says BROKEN, 15 failures, 20 warnings, run with no session (~/VM/harness/f45/smoke-20261106-090130/first-report.txt). Sort them: needs a session, needs hardware, real. Suspects: FONT-02 Sumi UI not crisp, DISK-06 snapper, LOGIN-19 and SLP-20 power keys, UPK-21 and KEY-11 Super+U, kawa-browser and kawa-stick --help, FETCH-01 ble.sh. Fix the real ones, name the rest (Fri 6 Nov 10:56)
- f07 options (a) window open and close: 3 motions behind a dwl switch, filmstrips from headless frames: a1-window.jpg (Fri 6 Nov 11:02)
- f08 options (b) the workspace move: 3 motions, filmstrips: b1-workspace.jpg (Fri 6 Nov 11:13)

## commits
- Fri 11:13 b5f9214f f08 done: three workspace motions behind anim_tag_motion, filmstrips on b1-workspace.jpg; next row now
- Fri 11:02 efcd226e f07 done: three window motions behind anim_motion, filmstrips on a1-window.jpg; f08 next
- Fri 10:56 ce02ecee r28-f06i ledger: the login screen's power keys are read from the code, not his words
- Fri 10:56 0f8f09e9 f06i done: the fresh F45 report sorted: /home's snapshots and the wallpaper fixed, stale rows follow the desktop; f07 next
- Fri 09:55 ab878c33 f06h done: the first report waits for the first login however long, marked only when it ended; f06i next
- Fri 09:40 53a74472 f06g done: the 6 min before "running" is the first health report waiting for a session; f06h next
- Fri 09:38 ba6e824b f06e done: the Bad message lines are SELinux refusing PID 1 dnf's pipe, harmless on install; f06g next
- Fri 09:33 f059d95b f06f done: a fresh install's split moves read-only subvolumes, the smoke verifies after the last reboot; f06e next

## repairs

## errors (2 h)
- server: /tmp/hl-dwl.TZVet3/foot-wayland-0.sock is already accepting connections; is 'foot --server' already running
- server: /tmp/hl-dwl.H8eKEy/foot-wayland-0.sock is already accepting connections; is 'foot --server' already running
- server: /tmp/hl-dwl.zFFXxr/foot-wayland-0.sock is already accepting connections; is 'foot --server' already running
- server: /tmp/hl-dwl.hbHDaj/foot-wayland-0.sock is already accepting connections; is 'foot --server' already running

steering received: none
options: a1-window.jpg, b1-workspace.jpg
