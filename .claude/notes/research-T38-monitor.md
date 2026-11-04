# T38: the LG 24G411A-B. DDC/CI and FreeSync facts (lane-research2, 4 Nov 2026)

Reads only: the EDID from sysfs, and `ddcutil` reads on `i2c-5` with its caches kept in `/dev/shm`. **Nothing was
written to the monitor by this lane.** Values are as of 17:51 today. Decisions below are for `lane-hardware`, which
has the sudo and the screen.

**Corrected 18:45: the gaming VM is dropped (owner, 17:38; ASOBI replaces it, plan T32). No second cable, no input
switching, the desktop stays on the card's `HDMI-A-1`. Section 6's test must not be run.**

## 1. What changes in the plan

- **`ddcutil capabilities` works.** The plan's "Maximum DDC retries exceeded" is gone: it failed for me with `--sleep-multiplier 2 --maxtries 5,5,10`, and succeeded in 4 s with `--skip-ddc-checks --sleep-multiplier 4 --maxtries 10,10,15`. `lane-research` read the identical string independently with `--skip-ddc-checks --disable-dynamic-sleep --sleep-multiplier 2` (`vm-research.md`, R§7), which credits the sleep multiplier. **`--skip-ddc-checks` is the one flag common to both successes and missing from the failure**; test that first, though it is not isolated.
- **VCP `0xAE` is the monitor's own measure of its refresh: 143.90 Hz today.** So FreeSync can be proven from the far end of the cable, not only from dwl's logs (section 4).
- **`0x14` lists an `sRGB` preset**, and the panel's factory primaries are wider than sRGB, so the design's palette is probably oversaturated today (section 5).
- **Most game settings are not exposed.** Response time, Black Stabilizer, Adaptive-Sync and Overclock are not in the capabilities string. "Set them all over DDC" is only partly possible (section 3).
- **Games leave his desktop for ASOBI's own session** (gamescope on its own VT, plan T32), so dwl's `games` VRR mode loses its reason. Section 4 proposes what replaces it.

## 2. The monitor

**From LG** (PH and CA spec pages, 4 Nov): 23.8", IPS, 1920×1080, 120 Hz native with **144 Hz overclock**; 5 ms GtG at Faster, "1 ms MBR"; **250 cd/m² typical, 220 minimum**; **1500:1 typical, 1050:1 minimum**; **sRGB 99 % typical, 95 % minimum**; HDMI ×1 (version not stated), DisplayPort 1.4 ×1; HDR10; Flicker Safe, Reader Mode, Black Stabilizer, Dynamic Action Sync; FreeSync: the spec row says "FreeSync", the feature list "Premium Pro", a caption "Premium", so the tier is unclear (AMD's own FreeSync page timed out from here; nothing below depends on the tier); no VRR range given.

**No independent measurement found** (searched twice, the second time at 18:50). Searches for RTINGS, TFTCentral and Monitors Unboxed returned no review of this model, and I could not retrieve LG's manual: the mirrors refused me, and LG's pages gave no direct link (its support tab is `/ca_en/support/product-support/cs-24G411A-B.AUS#manual-tab`, for a browser). So the OSD tree is **unverified** here. Do not cite reviewer settings for it.

**From his unit** (EDID, 256 bytes, checksums good; `/sys/class/drm/card0-HDMI-A-1/edid`):

| Item | Value |
|---|---|
| Identity | `GSM` product `0x5CDD`, week 9 of 2025, name "LG ULTRAGEAR", EDID 1.3 |
| Size, gamma | 53 × 30 cm; 2.2; sRGB-default bit **not** set |
| Primaries (x, y) | R 0.671, 0.317 · G 0.293, 0.638 · B 0.143, 0.048 · white 0.313, 0.329 (D65) |
| Gamut (computed) | **121 % of sRGB's area, 100 % of sRGB covered**, 88 % of DCI-P3 covered. EDID values are the maker's typical, not measured on this panel |
| Timings | **1920×1080 at 143.981 Hz** (346.50 MHz, htotal 2080, vtotal 1157), preferred; also 120 (285.5 MHz), 100, 60 |
| Range limits | V 48 to 144 Hz, H 30 to 200 kHz, max 350 MHz |
| HDMI | VSDB max TMDS 300 MHz; **Forum VSDB ver 1, 450 MHz, SCDC bit set; no VRR bytes** |
| **FreeSync** | **AMD VSDB (OUI `00001A`) version 2, supported bit set, 48 to 144 Hz.** On HDMI this block is the only VRR path: FreeSync-over-HDMI, not HDMI Forum VRR |
| HDR | static metadata: SDR and PQ; desired max 248 nits |
| Colorimetry | BT.2020 RGB and YCC flags |

**The link:** 346.5 MHz is above HDMI 1.4's limit, so 144 Hz needs the HDMI 2.0-class link. `card0-HDMI-A-1`'s DDC bus is `i2c-5`; read it from the `ddc` link in sysfs (`readlink /sys/class/drm/card0-HDMI-A-1/ddc`), which needs no DDC traffic, unlike `ddcutil detect`.

## 3. DDC/CI: what the monitor exposes

**Capabilities string, verbatim:**
```
(prot(monitor)type(lcd)model(FALCON)cmds(01 02 03 07 0C 4E F3 E3)vcp(02 04 05 08 0B 0C 10 12 14(01 04 05 06 07 08 0A 0B) 16 18 1A 6C 6E 70 AC AE B6 C0 C6 C8 C9 CA CC(00 02 03 04 05 08 09 0A 0D) D6(01 02 04) DC(00 01 02 03 04) DF 60(01 03) 62 8D FF)mswhql(1)mccs_ver(2.0)asset_eep(32)mpu_ver(01))
```
Internal model FALCON, Novatek controller, firmware 3.36, MCCS 2.0 by the string and 2.1 by `0xDF`, 1001 hours used.

**Commands that worked** (`B=--bus 5`; add `--noconfig` only as I did, for clean probes):
```
ddcutil --bus 5 --skip-ddc-checks --sleep-multiplier 4 --maxtries 10,10,15 capabilities --verbose   # 4 s
ddcutil --bus 5 --skip-ddc-checks --disable-dynamic-sleep --sleep-multiplier 2 getvcp known          # 26 s, 33 codes
ddcutil --bus 5 --skip-ddc-checks --disable-dynamic-sleep --sleep-multiplier 2 getvcp SCAN           # 48 s, every code
ddcutil --bus 5 --skip-ddc-checks --sleep-multiplier 2 --i2c-source-addr=0x50 getvcp F4 F5 F6 F7     # same values
```
ddcutil's cross-instance locking is on by default, so these do not fight `kawa-brightness`. It writes `~/.cache/ddcutil/`; a probe should point `XDG_CACHE_HOME` elsewhere (memory: no strays).

**Every code that answers, now:**

| Code | Meaning | Now | In caps | T38 decision |
|---|---|---|---|---|
| `10` | brightness | **90** of 100 | yes | **His**: the bar's tile. Not `0 %`: check why the tile showed that |
| `12` | contrast | 70 | yes | Keep |
| `14` | colour preset | **`0B` User 1** | 01 sRGB, 04 5000K, 05 6500K, 06 7500K, 07 8200K, 08 9300K, 0A 11500K, 0B User 1 | **Try `01`** (section 5) |
| `16 18 1A` | gains | 50 50 50 | yes | Keep: no measurement to justify a change |
| `6C 6E 70` | black levels | 50 50 50 | yes | Keep |
| `0B 0C` | colour temp increment, request | 50 K; request `3000 + 70×50` = 6500 K | yes | Read only |
| `72` | gamma | **2.2** | **no**, answers anyway | Keep |
| `87` | sharpness | **50** (ddcutil prints "Invalid", it is just unlabelled) | **no**, answers anyway | Keep unless the owner's eyes say otherwise |
| `62 8D` | volume, mute | 30, unmuted | yes | Leave |
| `60` | input | **reads `01` while on HDMI** | `01 03` | Do not write (section 6) |
| `D6` | power | 01 on | 01 on, 02 standby, 04 off | T38's power-cycle test, when away |
| `DC` | display mode | **`2D`**, not in its own list (00 to 04) | listed | **Do not write.** Read only |
| `15` | not in MCCS | max 8, now `2D` | no | Same value as `DC`: possibly the Game Mode. Read only |
| `AC` | H frequency | 35628: **16-bit overflow**, true about 166.7 kHz | yes | Ignore |
| `AE` | **V frequency** | **143.90 Hz** | yes | VRR proof (section 4) |
| `B2 B6 C0 C6 C8 C9 CA CC DF` | panel info, OSD | RGB stripe, LCD, 1001 h, `6F`, Novatek, 3.36, OSD on, English, 2.1 | mostly | Never change `CA` |
| `F4` | **LG side channel** | `06` | no | Do not write (section 6) |
| `F5 F6 F7 F9 FA` | LG private | 1, 1, 2, **50**, 2 | no | **Do not write** (below) |
| `E2 E6 EF FB FF` | LG private | 0, 1, 4, 0, 0 | `FF` only | Do not write |
| `02 04 05 08` | control, **factory resets** | | yes | **Never write `04 05 08`** |

**The private codes.** A 2016 forum post about a 34" LG lists F5 aspect, F6 smart energy saving, F7 response time, F8 FreeSync, F9 Black Stabilizer; ddccontrol-db issue 80 agrees that F5 is aspect, wide = 1. His values fit (F5 = 1, F9 = 50), and F8 does not answer. **That is a decade-old pattern from another monitor, not LG's word.** ddcutil issue 100 records someone bricking an LG by looping through codes until a factory reset rescued it. **Decision: leave the private codes at their defaults.** Nothing on this PC can observe whether response time or Black Stabilizer changed, so a write could not be verified, and verify is the rule. If he ever wants them, the OSD does it in a minute. Tell him so in one line of the Learn piece rather than pretending.

## 4. FreeSync

**Already known:** EDID says 48 to 144 Hz (section 2); the planner read `vrr_range` Min 48 Max 144 from debugfs (root); dwl has `m->vrr` and logs `vrr: NAME on/off`; tearing is only allowed when `m->vrr == 1`; `~/.config/fedokawaii/vrr` is `off` today.

**`tools/vrr-proof.sh`, with three independent witnesses:** it needs the real screen, so a notice first (the away gate is off tonight, owner 17:32; afterwards `tools/away.sh` gates it).
1. **Linux:** `wlr-randr` Adaptive Sync, dwl's log, `vrr_range`.
2. **dwl's own present intervals:** at a fullscreen client held to 72 and 100 fps, 13.9 and 10 ms, not multiples of 6.94 ms.
3. **The monitor itself:** poll `getvcp AE` once a second during each step: expect about 72 and 100, not 143.90. **This is the check that cannot be fooled by the software stack.** It may lag or round; report what it does. Keep the poll at 1 Hz (DDC is slow, and locking delays the bar's brightness tile).

Then below 48 Hz: LFC should double frames. **The plan's master note (re-run on the iGPU's HDMI after T33) no longer applies:** there is one connector. ASOBI's gamescope asks for adaptive sync on the same connector in its own session, so `getvcp AE` should witness that too: lane-asobi's to prove, not this tool's.

**What VRR is for on the host now.** With games gone, `games` means nothing. There is a better use, and it is the kind of thing he notices: **60 fps video on a 144 Hz desktop has uneven cadence** (144/60 = 2.4: frames held 2, 3, 2, 3, 2), and so do 30 and 25. 24 fps divides cleanly. Fullscreen video with VRR on plays at exactly its rate. **Proposal (r27-extra): replace `games` with `video`: adaptive sync on only while a fullscreen client has the focus**, off on the desktop. Measure before adopting: mode-switch flicker, IPS brightness flicker at a steady 60 Hz, and whether browsers' fullscreen video commits steadily. The tile in `kawa-quick`, `DWL-06..08` in `fedokawaii-report` and `system/fedokawaii:1130` all name these modes. Alternative worth one line: 120 Hz is this panel's native rate and all of 24, 30 and 60 divide it, but he chose 144.

## 5. Colour

**The case for `0x14 = 01`.** The factory primaries cover 121 % of sRGB's area, red and green beyond it, and `docs/design-system.md`'s palette is authored in sRGB. So in User 1 (today) a saturated colour such as the seal is probably shown more saturated than designed. His red is the most exposed. An sRGB preset exists to correct exactly this.

**The test** (a notice first, then his eyes):
1. Save a `getvcp SCAN` as the baseline.
2. `setvcp 14 01 --noverify`, wait 1 s.
3. `getvcp 14 10 12 16 18 1A 72 87 DC 15`, and diff against the baseline. Learn: does it hold? Does it lock brightness, which would break the bar's tile?
4. **Keep only if** `14` reads `01` and `10` still moves. Otherwise restore `0B` and stop.
5. **Honesty:** a screenshot sees nothing here; the change happens after the scan-out. Without a colorimeter nobody can claim accuracy. Ask his eyes through the review pack: "the monitor is now in its sRGB preset; is the red calmer and right?" He may prefer the saturation, and that is his call.

**Rejected: a LUT or ICC profile through dwl.**
- The gamma path is a per-channel 1D LUT. It can shape gamma and white balance, and **cannot correct primaries**, which is the actual error here.
- wlroots 0.20 has a real colour transform (`wlr/render/color.h`, `wlr_scene`), and a 3×3 from the EDID's primaries is computable. But those primaries are typical values, unmeasured, and a per-frame render pass would cost direct scanout, for an unverifiable gain. **"Measured, not guessed"** rules it out unless a colorimeter appears. Keep `src/kawa-gamma` out of the plan, and gammastep stays the one tool for the night light.

## 6. Switching the input: not needed, do not test

The VM was the only reason to switch inputs, and it is gone, so **nothing writes `60` or `F4`**: a wrong value leaves the screen dark until he presses the monitor's joystick, for no gain. For the record, should it ever return:
- `60(01 03)` is non-standard: 0x60 reads `01` while on HDMI, and this monitor has neither VGA nor DVI.
- ddcutil's wiki, "Switching input source on LG monitors": recent LGs use a **side channel, VCP `F4` from source address `0x50`** (`setvcp xF4 x0090 --i2c-source-addr=x50 --noverify`; `0x90` HDMI 1, `0xD0` DP 1). This model is not on that page's confirmed list, and his `F4` reads `06`.
- Monitors differ on whether DDC works on the **inactive** input (ddcutil issue 100; `lg-monitor-switch`, tested on a 32GN650, says it does there). Any such design would rest on that one unproven fact.

## 7. Design: `kawa-display`

- `monitor.conf`: only `14=01`, if kept, documented with this file as its source.
- **Applied at login and on wake, in the background, read before write:** `getvcp 14`, and `setvcp` only if it differs. Log one journal line. No write at all when it matches, which is the normal case: DDC is slow and the monitor may persist on its own. **Test persistence once** across a power cycle (`D6 04`, then `D6 01`; if `D6 01` cannot wake it, the plan's test needs his button: note it). `0C` Save Settings is in `cmds`, so `ddcutil scs` exists if needed.
- `kawa-refresh` (T20r) calls it, as planned. The bar's `0 %` belongs here: `kawa-brightness` should read `10` after login and wake, and it gets a real value today (90).

**T38's accept, adjusted:** capabilities string in the ledger (above); `0x14` written and read back at login and after a wake, or restored with the reason; vrr-proof's three witnesses at 72 and 100 Hz; the private codes explicitly untouched, and said so in the Learn piece; `D6` power cycle with tags, layout and focus identical (T02's open row).

## Sources

Commands (4 Nov 2026, 17:51 to 17:54): `od` of `/sys/class/drm/card0-HDMI-A-1/edid`, decoded by a small script; `readlink .../ddc`; `ddcutil` 3.0.2 as listed; `/usr/share/man/man5`. wlroots headers in `/usr/local/lib/fedokawaii-wlroots-0.20/include`.
- LG: https://www.lg.com/ph/monitors/ultragear-gaming/24g411a-b/ , https://www.lg.com/ca_en/monitors/gaming/24g411a-b/ , https://www.lg.com/us/monitors/lg-24g411a-b-gaming-monitor
- MSI's HDMI: https://storage-asset.msi.com/datasheet/mb/us/PRO-B650M-B.pdf
- ddcutil: wiki https://github.com/rockowitz/ddcutil/wiki/Switching-input-source-on-LG-monitors , issue https://github.com/rockowitz/ddcutil/issues/100
- Other LG work (community): https://github.com/EntangledQuantum/lg-monitor-switch , https://github.com/leinardi/monmux , https://github.com/lunat1q/monitorinputwizzard
- Private codes (old, other models): https://www.overclock.net/threads/lg-34uc88-34uc98-34um88-monitors-thread.1597604/page-39 , https://github.com/ddccontrol/ddccontrol-db/issues/80
