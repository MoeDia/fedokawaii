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
