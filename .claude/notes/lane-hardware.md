# lane-hardware: T36, T37, T38 (branch lane-hardware, worktree ~/repos/fk-hardware)

Source: lane-research2's digests (`~/repos/fk-research2/.claude/notes/research-T36-T37-rgb.md`, `research-T38-monitor.md`).
Scratch: `/dev/shm/r27-lane-hardware` (scripts, device backups). Started 4 Nov 18:12.

## State (19:20)
Solid red, event-driven, as the owner decided at 18:45. Running on the PC as a temporary unit (`r27-kawa-rgb.service` in /run, binary `/usr/local/bin/kawa-rgb-try`), to be removed when this lane ends; `/etc/fedokawaii/rgb.conf` is in place, the same as the repo's.

| What | State | How it was verified |
|---|---|---|
| K617: live frames | works | owner's eyes: green/blue/red cycle (19:01); one frame holds (static blue, 19:13) |
| K617: its memory | works | owner's eyes: plain red (19:08, 19:17); read back; keymap block unchanged (`.claude/notes/hardware/`: the stock blocks) |
| Board, fans, hub, cooler's fan | one red | owner's eyes (19:06, 19:17) |
| Card's logo | one red, static | owner's eyes; it parses only 64-byte writes (shorter ones get no answer), each 9 ms of kernel busy wait: why nothing is streamed |
| Per-device match | all 178,0,0 | owner: "everything aligned and good" (19:17) |
| Cooler's display (T37) | our number | owner: shows 42 when sent 42 (19:12), else the CPU's temperature |
| FreeSync (T38) | proven, HDMI-A-1 | tools/vrr-proof.sh, below |
| LG off and on over DDC | state identical | tools/monitor-power-test.sh; owner: "stays the same workspace" (19:02) |
| LG's menu | sRGB preset, set | kawa-display --monitor, read back xde; owner left it to me (19:04), then "this is fine its the best" (19:12) |
| Tests | test_rgb 122/0, test_display 99/0 | a made-up machine; see "Tests" |

## What main must do to merge and apply
**Merge** `lane-hardware` (it has main merged in as of 19:25). Touches: `src/kawa-rgb/`, `configs/system/etc/{fedokawaii/rgb.conf,systemd/system/kawa-rgb*.service,udev/rules.d/60-fedokawaii-cooler.rules}`, `theme.sh` (one tool more, the step that enables it), `lib/manifest.sh` + `PACKAGES.md` + `tools/packages.evidence` + fixtures (OpenRGB retired), `bin/kawa-display`, `bin/kawa-brightness`, `bin/kawa-lock`, `bin/kawa-quick`, autostart, `configs/home/.config/fedokawaii/monitor.conf`, `verify.sh`, `system/fedokawaii`, `system/fedokawaii-report`, `tests/lib/harness.sh` (KAWA_RGB_ROOT: no test ever reaches his lights), `tools/{vrr-proof,monitor-power-test}.sh`, the docs.

**Apply:** `fedokawaii apply` builds and installs `/usr/local/bin/kawa-rgb`, the units, and starts the service. Nothing by hand. Until then the lights hold their stored red and do not react to the lock.

**The quick settings row** ("lights", on lane-pixels' `kawa-panel`) appears by itself once this is merged: `kawa-quick --state` reports `rgb`, `--do rgb` toggles.

**Left for main, because this lane may not reboot or suspend the PC:**
1. After the next reboot: `kawa-rgb status` says `lights full` and all four `ok`; the lights stay red through the greeter (watch for a dark moment before dwl lights the screen).
2. One `systemctl suspend` and wake when it is allowed (with the cold power-off test): the lights go out before the sleep and come back; `journalctl -u kawa-rgb -u kawa-rgb-sleep`.
3. `dwl` takes `LIBINPUT_IGNORE_DEVICE` for the cooler (the ghost keyboard's rule, proven with `udevadm test`) at the next session.
4. The Learn pieces: `.claude/notes/lane-hardware-learn.md` is their text, for the book's update on his word (`docs/learn/syllabus.txt`).
5. Fold into `.claude/plan.md`: T36 and T37 as below (the plan's ember, OpenRGB and VM capture no longer apply); T38's iGPU re-run falls away with the gaming VM.

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
