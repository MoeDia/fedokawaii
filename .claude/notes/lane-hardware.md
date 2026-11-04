# lane-hardware: T36, T37, T38 (branch lane-hardware, worktree ~/repos/fk-hardware)

Source: lane-research2's digests (`~/repos/fk-research2/.claude/notes/research-T36-T37-rgb.md`, `research-T38-monitor.md`).
Scratch: `/dev/shm/r27-lane-hardware` (scripts, device backups). Started 4 Nov 18:12.

## State (21:55, after the reboot of 21:16)
Solid red, event-driven, as the owner decided at 18:45. **The real units run on the PC since 21:46** (the owner's 21:41 "FIX FIRST": nothing had driven the cooler's display since the reboot, because tonight's temporary unit lived in /run and main's apply had not come yet; the display had been told "out" when that unit stopped). Installed by hand with exactly the files theme.sh writes: `/usr/local/bin/kawa-rgb` (restorecon: bin_t), `/etc/systemd/system/kawa-rgb{,-sleep}.service`, enabled, `multi-user.target`, nothing of a session in it. The udev rule stays for the apply (the ghost keyboard: not needed for the fix). Main's apply takes them over by itself: no sha256 mark yet, so it builds, installs and restarts once.

| What | State | How it was verified |
|---|---|---|
| K617: live frames | works | owner's eyes: green/blue/red cycle (19:01); one frame holds (static blue, 19:13) |
| K617: its memory | works | owner's eyes: plain red (19:08, 19:17); read back; keymap block unchanged (`.claude/notes/hardware/`: the stock blocks) |
| Board, fans, hub, cooler's fan | one red | owner's eyes (19:06, 19:17) |
| Card's logo | one red, static | owner's eyes; it parses only 64-byte writes (shorter ones get no answer), each 9 ms of kernel busy wait: why nothing is streamed |
| Per-device match | all 178,0,0 | owner: "everything aligned and good" (19:17) |
| Lock 30 %, switch, screens off | runs on the PC | shows at 19:19 and 19:28, status lines read; dpms=Off seen with wlopm, disconnected with the button (19:26); owner on the fades: no complaint, not yet a yes (asked 19:41) |
| Out faster with the monitor | built | a look ten times a second, three steps out: 250 ms from what DRM says; the monitor's own delay stays. Owner asked 19:41; 0.066 % of a core, 2.5 MB steady |
| Cooler's display (T37) | our number, and off | owner: 42 when sent 42 (19:12), else the CPU's temperature (19:06); dark with digits 0x0a, stays dark 30 s unsent (19:33); told again every 10 s, and when the service stops |
| USB replug | recovers | rebind of the board and the cooler: missing, then ok within 4 s |
| FreeSync (T38) | proven, HDMI-A-1 | tools/vrr-proof.sh, ledger line below; setting "full screen", live since 19:20 |
| LG off and on | state identical | D6 (tools/monitor-power-test.sh) and his own button (19:26): tag, layout, 144 Hz, sRGB and level kept; owner: "stays the same workspace" (19:02) |
| LG's menu | sRGB preset, set | kawa-display --monitor, read back xde; owner left it to me (19:04), "this is fine its the best" (19:12) |
| The real unit (21:46, 21:52) | runs, restarts | `systemctl restart`: all four found in 3 s; 64 bytes a second to the display and nothing else (/proc/PID/io over 10 s: 640 bytes, 10 writes); Tctl 82 to 85 under the lanes' load; 2.5 MB. Lock → dim 121 ms, unlock → full 130 ms, `kawa-rgb sleep` → out 127 ms, wake → full 215 ms, read from its status; the sleep unit itself (started with no sleep) ran under enforcing SELinux, no AVC |
| Tests | see "After the reboot" | a made-up machine |

**The stuck PID 1 (since 19:51):** see the 20:00 and 20:07 findings in the inbox, and "About the 19:51 reload" below. A kernel Oops at 19:15:04 (`unlink_file_vma_batch_process` → `vma_interval_tree_remove`, a stray bit in a pointer) most likely left a file's i_mmap_rwsem held for ever: inference, /proc/1/stack could not be read. sudo and systemctl hang until a reboot. Suspect: RAM.

## After the reboot (written 21:55)
- Main merged in (6268cd73). No Fedora 44 in this branch's diff (`git diff` greps clean; the owner's 21:41 "Fedora 45 only").
- New rows: `verify.sh` asks that the service is enabled, not only running (tonight's failure: a service that was not there after a reboot); `tests/status/test_rgb.sh`: the unit is the system's, with nothing of a session in it. `tools/hl-dwl.sh` sets KAWA_RGB_ROOT: after the apply, the kit's and the regress checks' lock screens would have dimmed his real lights (`bin/kawa-lock` runs `kawa-rgb lock`, the mark's folder is his). Proven: `kawa-rgb lock` inside a headless desktop failed there, the real mark stayed absent, the real status stayed "full".
- `tools/` and tests re-run on the healthy PID 1: results at the end of this section's list below.
- test_lock's 13 failures of 20:09 were the stuck PID 1, as I thought: 185/0 now.

**About the 19:51 reload:** PID 1's last action was my `daemon-reload` at 19:51:02 (main's finding, journal: "Reloading finished"). Reloads by me at 19:16, 19:29 and 19:37, after the Oops, had passed. Nothing shows the reload caused the hang, and nothing rules it out: it may be what first touched the file left locked at 19:15:04. So no more routine reloads: `lab/ember-unit.sh` had one on every start, and only needs one when the unit text changes.

## What main must do to merge and apply
**Merge** `lane-hardware` (it has main merged in as of 19:25). Touches: `src/kawa-rgb/`, `configs/system/etc/{fedokawaii/rgb.conf,systemd/system/kawa-rgb*.service,udev/rules.d/60-fedokawaii-cooler.rules}`, `theme.sh` (one tool more, the step that enables it), `lib/manifest.sh` + `PACKAGES.md` + `tools/packages.evidence` + fixtures (OpenRGB retired), `bin/kawa-display`, `bin/kawa-brightness`, `bin/kawa-lock`, `bin/kawa-quick`, autostart, `configs/home/.config/fedokawaii/monitor.conf`, `verify.sh`, `system/fedokawaii`, `system/fedokawaii-report`, `tests/lib/harness.sh` (KAWA_RGB_ROOT: no test ever reaches his lights), `tools/{vrr-proof,monitor-power-test}.sh`, the docs.

**Apply:** `fedokawaii apply` builds and installs `/usr/local/bin/kawa-rgb`, the units, the udev rule and the conf, and restarts the service (it is already running from the identical files, by hand since 21:46: the owner's "FIX FIRST"). Until the apply the lights and the display follow the screens and a sleep, but not the lock (the installed `kawa-lock` is the old one), and the bar's and quick settings' parts are not there. Should this branch not make tonight's apply: nothing breaks, the service stands alone.

**The quick settings row** ("lights", on lane-pixels' `kawa-panel`) appears by itself once this is merged: `kawa-quick --state` reports `rgb`, `--do rgb` toggles.

**Left for main, because this lane may not reboot or suspend the PC:**
1. **The real boot proof, the one thing this lane cannot do:** after the next reboot (the Fedora 45 upgrade's): `kawa-rgb status` says `lights full` and all four `ok`, `journalctl -u kawa-rgb -b` shows it started with the boot, and the cooler's display shows the CPU's number; the lights stay red through the greeter (watch for a dark moment before dwl lights the screen). Nothing proves that but a boot: enabled in `multi-user.target`, session-free, restarted for real.
2. One `systemctl suspend` and wake when it is allowed (with the cold power-off test): the lights go out before the sleep and come back; `journalctl -u kawa-rgb -u kawa-rgb-sleep`.
3. `dwl` takes `LIBINPUT_IGNORE_DEVICE` for the cooler (the ghost keyboard's rule, proven with `udevadm test`) at the next session.
4. The Learn pieces: `.claude/notes/lane-hardware-learn.md` is their text, for the book's update on his word (`docs/learn/syllabus.txt`).
5. Fold into `.claude/plan.md`: T36 and T37 as below (the plan's ember, OpenRGB and VM capture no longer apply); T38's iGPU re-run falls away with the gaming VM.
6. For T42's layout (what lives where): `/usr/local/bin/kawa-rgb`, `/etc/systemd/system/kawa-rgb{,-sleep}.service` (and their enable links), `/etc/fedokawaii/rgb.conf`, `/etc/udev/rules.d/60-fedokawaii-cooler.rules`, `/var/lib/kawa-rgb/card` (the service's), `/var/lib/fedokawaii-greeter/rgb` and `rgb-locked` (yours), `/run/kawa-rgb/`, `~/.config/fedokawaii/monitor.conf`. Gone with OpenRGB: `~/.config/OpenRGB/` (a stray once it leaves; it holds only its logs).
7. At the cold power-off test, ask him: does anything stay lit after the PC is off? USB may keep power (the keyboard, the cooler's display), which depends on the board's setting. The display is put out when the service stops; the keyboard and the board keep their last frame until the power goes.

## Ledger lines, ready to paste
```
- r27-40 (T36, lane-hardware, 4 Nov) the lights: one steady red, event-driven (the owner, 18:45: no animation across devices). src/kawa-rgb, C, no libraries, kawa-rgb.service as root without capabilities, no network, hidraw and I2C only, 0.000 % of a core and 2.5 MB when steady (top over 20 s), nothing sent while nothing changes. K617 258a:0049: live frame 08 0a 7a 01 holds alone (owner, 19:13); stored fixed-on by two blocks, read back, keymap block unchanged; never a word within 1 s of a frame (19:15: an immediate select cut the painting at the left half). MSI 0db0:0076 report 0x52, static, save only on a change. Gigabyte card 0x75 on the OEM bus: parses only 64-byte writes (shorter: no answer, proven by its presence reply), each 9 ms of kernel busy wait (8.75 ms sys): streaming it at 8 Hz cost 6.6 % of a core, hence no breathing. All 178,0,0: "everything aligned and good" (owner, 19:17). Lock → dim 30 %, screens off → off, switch: the show at 19:19. Recovery: USB rebind of the board and the cooler, missing then ok within 4 s. OpenRGB retired (its rule gave the session every I2C bus). VERIFIED by his eyes and tests/status/test_rgb.sh. Open: reboot and suspend, main's.
- r27-41 (T37, lane-hardware, 4 Nov) the cooler's display is 1a2c:4184, and it is driven: 07 ff ff H T U as an output report (JL DGT 1.0.0's report for its siblings 1a2c:434d, 1a2c:4385; its own list does not name 4184), padded to 64 bytes, once a second: the k10temp Tctl averaged. VERIFIED: owner saw 42 when sent 42 (19:12), and the CPU's temperature otherwise. Source: https://shop-api.htssl.com/uploads/driver/JL%20DGT%20Setup%201.0.0.zip, read, never run.
- r27-42 (T38, lane-hardware, 4 Nov) the LG 24G411A-B on HDMI-A-1 (card0, the 9060 XT). FreeSync proven, tools/vrr-proof.sh: DRM yes/on; dwl's presents p5 p50 p95: 100 fps 8.96 9.99 10.97 ms; 60 fps 15.93 16.67 17.34; 40 fps 23.79 25.00 26.23 (below the 48 Hz floor); FreeSync off at 100 fps 6.94 6.95 13.89. The monitor's own VCP 0xAE stays 143.90 Hz throughout: it does not follow, so it is no witness. Setting: "full screen" (dwl's mode 1, the words changed from "in games"), set live 19:20: a 60 fps video is even. Capabilities: (prot(monitor)type(lcd)model(FALCON)cmds(01 02 03 07 0C 4E F3 E3)vcp(02 04 05 08 0B 0C 10 12 14(01 04 05 06 07 08 0A 0B) 16 18 1A 6C 6E 70 AC AE B6 C0 C6 C8 C9 CA CC(00 02 03 04 05 08 09 0A 0D) D6(01 02 04) DC(00 01 02 03 04) DF 60(01 03) 62 8D FF)mswhql(1)mccs_ver(2.0)asset_eep(32)mpu_ver(01)). Menu: kawa-display --monitor at login and wake, read first: 0x14 = sRGB (x01, reads xde), contrast 70, gains 50, black 50; 0x10 still moves. Owner left the preset to me (19:04), A/B seen, "this is fine its the best" (19:12). Not exposed: response time, Black Stabilizer, Adaptive-Sync; LG's private codes untouched; no 0x60 or F4 writes (the VM that needed them is gone). No colour profile: no colorimeter, a 1D LUT cannot correct primaries. Power: D6 04 then the monitor drops off the cable at 12 s and comes back; tags, layout, title, mode identical (tools/monitor-power-test.sh); owner: "stays the same workspace" (19:02). The bar's tile: kawa-brightness --reread after --monitor, 90 from the LG; the "0 %" was the kit's, which has no monitor.
```

## OWNER 18:45 — RGB: SOLID, NOT BREATHING
The GPU's RGB cannot stay in sync, so no breathing or any animation across devices. Instead:
- ONE steady red on every device (fans, hub, cooler, GPU logo, K617), calibrated per device so they LOOK identical (each brand renders red differently; the GPU drifts orange or pink): a per-device colour value, then one question on his page to confirm the match by eye.
- Event-driven instead of animated: lock screen → fade to about 30 %; screens off or sleep → off; unlock or wake → full.
- The quick-settings switch (rgb on/off for everything, remembered across reboots) as asked at 18:39.

## OWNER ANSWER 2026-11-04 18:59 — to your question «2026-11-04 18:56 — question from lane-hardware»
the keyboard is not red fix that and cpu is showing temperature between 88 and 89 c and the color is nice but brightness could be a little bit less

## OWNER ANSWER 2026-11-04 19:01 — to your question «2026-11-04 19:01 — question from lane-hardware»
it IS showing 10 green 10 blue 10 red

## OWNER ANSWER 2026-11-04 19:02 — to your question «2026-11-04 18:43 — question from lane-hardware»
yes it stays the same workspcae it works

## OWNER ANSWER 2026-11-04 19:02 — to your question «2026-11-04 18:41 — question from lane-hardware»
we spoke about this

## OWNER ANSWER 2026-11-04 19:04 — to your question «2026-11-04 18:18 — question from lane-hardware»
you decide whats best

## OWNER ANSWER 2026-11-04 19:04 — to your question «2026-11-04 19:05 — question from lane-hardware»
the keyboard is still rolling different colors

## OWNER ANSWER 2026-11-04 19:05 — to your question «2026-11-04 18:31 — question from lane-hardware»
yea the freesync scan ran i guess double check you deal with it

## OWNER ANSWER 2026-11-04 19:06 — to your question «2026-11-04 18:22 — question from lane-hardware»
right now its showing between 85 and 89 c i think its working make sure

## OWNER ANSWER 2026-11-04 19:06 — to your question «2026-11-04 18:16 — question from lane-hardware»
all good except the keyboard still

## OWNER ANSWER 2026-11-04 19:08 — to your question «2026-11-04 19:07 — question from lane-hardware»
now the keyboard is all good perfect

## OWNER ANSWER 2026-11-04 19:12 — to your question «2026-11-04 19:13 — question from lane-hardware»
it does show 42

## OWNER ANSWER 2026-11-04 19:12 — to your question «2026-11-04 19:09 — question from lane-hardware»
this is fine its the best yea

## OWNER ANSWER 2026-11-04 19:13 — to your question «2026-11-04 19:10 — question from lane-hardware»
now its showing static blue i think

## OWNER ANSWER 2026-11-04 19:15 — to your question «2026-11-04 19:17 — question from lane-hardware»
all good the keyboard right now only its left side is in red

## OWNER ANSWER 2026-11-04 19:17 — to your question «2026-11-04 19:18 — question from lane-hardware»
yea now the whole keyboard good

## OWNER ANSWER 2026-11-04 19:17 — to your question «2026-11-04 19:16 — question from lane-hardware»
everythihng aligned and good

## OWNER ANSWER 2026-11-04 19:26 — to your question «2026-11-04 19:24 — question from lane-hardware»
yes rgb dies down when i turn off the monitor but there is a delay could improve its performance

## OWNER ANSWER 2026-11-04 19:29 — to your question «2026-11-04 19:29 — question from lane-hardware»
i think the cpu cooler display stays on. make the behavior that if i turn off the monitor turn all rgb and cpu display off

## OWNER ANSWER 2026-11-04 19:32 — to your question «2026-11-04 19:32 — question from lane-hardware»
cpu display does go dark afer 42 i guess you can control it?

## OWNER ANSWER 2026-11-04 19:33 — to your question «2026-11-04 19:34 — question from lane-hardware»
right now its staying dark so i think its working as intended harden it tho

## OWNER VERDICT 2026-11-04 21:31 on your render final-sprint: comment
OWNER 21:30 — FINAL SPRINT: "you have 2 hours, finish the whole fedokawaii project fully". Deadline 23:30. Order of the night (relayed by Claude):
1. 21:30–22:30 every lane: finish the most valuable COMPLETE part of its task, test it, push, end its notes with a line DONE and a handover (what main must apply, what is left). No new scope. Never fake done.
2. lane-integrate: merge each DONE lane at once (master review, full offline suite), in this priority: ink, pixels, appsui, updates, iso, asobi, art, chess, typing, torrents, learning, firealpaca, nvim, fixer, hardware, network, saver.
3. main: 22:45 at the latest merge lane-integrate, then APPLY on the PC (he is here, screen takeover allowed; a notice on his page first) and check the desktop, the lock (lane-ink's M1 / M2) and the menus live.
4. main ~23:00: the Fedora 45 upgrade through the update button (snapshot first, btrfs scrub after; he decided to go ahead), unless the apply left something broken.
5. lane-iso: build and prove the final Fedora 45 ISO from merged main in its VM as soon as main has the merge, in parallel.
6. 23:30: main writes the owner's summary: what is done and proven, what is left (kept open in the plan for the next round), how to roll back.

## OWNER VERDICT 2026-11-04 21:41 on your render cooler-display: comment
OWNER 21:40 — FIX FIRST: "the CPU cooler display is not working". It stopped after tonight's reboot and repairs: at 21:20 his user service manager had been broken (a lane-asobi user@.service.d drop-in, now moved to /etc/systemd/off-by-fix5) and every user unit was down. Make the cooler display (the CPU temperature, following the lights) work again and survive a reboot (start it from a unit that does not depend on his desktop session); check the RGB too; prove both after a real restart of the unit; then answer him in one line in the inbox.
