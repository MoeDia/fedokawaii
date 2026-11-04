# T36 and T37: the lights. Device IDs, protocols and a design (lane-research2, 4 Nov 2026)

Paper plus read-only checks: `lsusb`, sysfs, HID descriptors, the journal, source and vendor files read but never
run. **This lane wrote to no device.** `lane-hardware` builds on this and proves it on the hardware, and what it finds
there outranks this file. The plan's approach for T36 and T37 is out of date on several facts; section 1 lists them.

**Corrected 19:05. Two decisions came after this was written:** the gaming VM is dropped (owner, 17:38), so nothing
ever takes the card away from the host; and the owner chose **one steady red, no breathing** (18:45), which replaces
this file's synced ember (section 7).

## 1. What changes in the plan

| The plan says | The evidence says | Consequence |
|---|---|---|
| Two keyboards attached; which is the K617? | `258a:0049` **is** the K617 Fizz: `fizzctl` (MIT, PyPI, Sep 2026, section 3) targets exactly that ID and calls it that. His typing confirms it: `urbnum` on 5-1 rose 309 → 333 in 15 minutes, on 1-12 it stayed 15 | Settled |
| The other "keyboard" `1a2c:4184` is unexplained; "lsusb shows no such device" for the cooler | **`1a2c:4184 SEMICO USB Gaming Keyboard` is very likely his Jungle Leopard cooler's display.** liquidctl issue 817: "Jungle Leopard KF400 CPU Cooler … Air cooler (identifies as a keyboard) … USB header", same VID:PID, same strings, same HID descriptor lengths (65 and 205 bytes, mine measured in sysfs). It sends no keys: 15 URBs since boot, no growth while he typed on the other. Its port, `usb1-port12`, has no ACPI node, unlike every other port on that hub | **T37 is reachable: a USB HID device to drive** (section 9). **Not proven:** his `bcdDevice` is 0.03, the issue's 1.11, and the vendor's own KF400 page lists "4PIN+3PIN SYNC", with no USB or display, so that report's model name may be loose. A real display reacting is the proof |
| T36 waits on T33's VM to capture the K617's vendor tool | The protocol is public, tested on the hardware by its author, and matches his descriptor to the byte (section 3) | **T36 needs no VM**, and T33's is gone anyway |
| Set the JRAINBOW zones' LED counts by observation | MSI board `0x7E28` is `DIRECT_MODE_ZONE_BASED`: one colour per zone (`GetMaxDirectLeds` returns 1). **No LED count is needed** | Drop that step |
| GPU: "RGB Fusion 2" controller | His card (`1002:7590`, subsystem `1458:2429`) uses OpenRGB's newer **Blackwell** controller, a different packet (section 5) | Use section 5, not `RGBFusion2GPUController` |
| Zones JRGB1, JRGB2, JRAINBOW1, JRAINBOW2, JCORSAIR, PIPE1, PIPE2, ONBOARD | OpenRGB lists those for this ID; MSI's manual shows **one JRGB (12 V) and one JARGB_V2 (5 V)** on the board | Most zones are phantoms; write only the real ones |
| `hidraw5`, `i2c-6` | Numbers move: Mystic Light is `hidraw4` today | Find devices by VID:PID and interface, and by adapter name plus PCI parent |
| "openrgb kept" | See section 2 | Recommend dropping it; `lane-hardware` retired it (2cc856d) |

## 2. Decision: one tool, `kawa-rgb`, and no OpenRGB at run time

The owner's rule is one tool per job and "write it all yourself". Three small protocols do not justify a general scanner:
- `openrgb` probes every I2C bus and the DIMM SPD on **each run** (its own log of 27 Oct: `Detecting I2C DIMM modules`, 3.27 s to finish detecting).
- Its udev rule gives the logged-in user **every** I2C bus: `KERNEL=="i2c-[0-99]*", TAG+="uaccess"` (`60-openrgb.rules:8`), including the PIIX4 SMBus where the RAM's SPD lives (here `i2c-16`: `16-0050`, `16-0052`, the `spd5118` sensors). ddcutil's rule is narrower (`ATTRS{class}=="0x03*"`, display adapters only). Dropping OpenRGB closes that for T39, and the GPU's buses stay reachable.
- Fedora ships a January snapshot (`1.0~rc2-3.20260126git74cbdcc`, `openrgb --version` even says `0.9+`); upstream released 1.0 on 11 Sep and 1.1 on 16 Oct 2026.

Keep it installed only until `kawa-rgb` is proven, as a cross-check. Note that `openrgb --version` writes a log into `~/.config/OpenRGB/logs`. If the owner's "OpenRGB where supported" is read strictly, MSI and the GPU could stay on it, but that means two tools and the scan on every change, so I decided against it.

Language: a small C program beside `src/kawa-saver`, because this runs for ever: `HIDIOCSFEATURE` / `HIDIOCGFEATURE` on hidraw, `I2C_RDWR` on `/dev/i2c-N`, no libraries. About 300 lines. OpenRGB is GPLv2: take the protocol facts, not its code. If `fizzctl`'s captured frames are used, keep its MIT notice.

## 3. K617 Fizz (`258a:0049`, USB 5-1, 12 Mbit/s, 500 mA)

**Not in OpenRGB**: `SinowealthControllerDetect.cpp:43` defines the PID as `Fl_Esports_F11_PID` and `:458` has its detector **commented out** (master, 3 Nov); `60-openrgb.rules` has no entry, hence `hidraw0/1` are `600 root`.

**His device's descriptor** (`/sys/class/hidraw/hidraw1/device/report_descriptor`), interface 1, usage page `0xFF00`:
report `0x05` feature 5 bytes, `0x06` feature 1031 bytes, `0x08` feature 381 bytes. With the report ID those are 6, 1032 and 382 bytes: exactly `fizzctl`'s frame sizes. Interface 1 also carries report `0x04`, a keyboard bitmap, so **raw access to it can read keys** (section 7).

**Protocol: separate projects, read and never run, which agree on the layout** (whether some derive from others I did not establish). My first version of this digest rested on `fizzctl` alone and got part of it wrong:
- `MarceloAntonio/redragon-fizz-k617-rgb` (Rust): reverse-engineered from the official `KeyboardDrv.exe` 1.6.6, and tested on the keyboard, per its README.
- `Syozik/Redragon-keyboard-linux-app` (Python): K617 and siblings, with backups and a strict allow-list.
- `pedro-anthony/openRGB`, `Controllers/RedragonK617Controller` ("experimental", an OpenRGB fork, not upstream).
- `fizzctl` 0.5.1 (MIT) and `MrSchrodingers/fizz-rgb`, from USB captures of OpenRGB issue 2172. fizz-rgb's own protocol notes still put speed and brightness at [69, 71], which fizzctl's history calls a wrong offset.

| Path | Bytes | Flash? |
|---|---|---|
| **Read** | Select `05 83 b6 00 00 00` (config), `05 88 b8` (colours), `05 89 bc`, `05 89 c0` (per-key); wait 30 to 60 ms; GET_REPORT `0x06`, 1032 bytes. The config's reply is **262 bytes**, header `06 83 b6`. Check `5A A5` at [14] and [137] before trusting it | No |
| **Stored effect, as three drivers do it** | Read the config; write the colour table `06 08 b8 00 40`; wait 50 to 200 ms; write the config `06 03 b6 00 00` padded to 1032, with [20] = 0 and [21] = effect. **No CANVAS or ROUTING for a firmware effect** (`fizzctl` writes them, from a template; Syozik's allow-list leaves out `06 09 c0`) | **Yes**: once per real change |
| **Live frame** | Feature report `08 0a 7a 01` + 96 RGB triplets, 382 bytes total; raster 16 columns × 6 rows, column first, `pos = col*6 + row`; byte offset `4 + pos*3`. Keys: Esc=1, 1=7, Tab=2, Q=8, CapsLk=3, A=9, LShift=4, Z=10, LCtrl=5, Space=35, Bksp=79, Enter=81, RShift=82, RCtrl=83 and the rest in `PER_KEY_POS`. No handshake | **No**, volatile. **His eyes confirmed it, 19:01:** green, blue and red followed. How long one frame holds is **not** settled: every streaming driver re-sends, and fizz-rgb's static path sends once |

**The layout, by frame offset** (these drivers agree, and it explains `fizzctl`'s scattered slots): `[14..15]` = `5A A5`; `[20]` = 1 only with per-key mode; `[21]` = effect; colour table `[8 + 21*effect + 3*slot]`, 7 slots per effect; selector `[36 + 2*effect]`, low 3 bits = slot, **7 = random**; parameters `[37 + 2*effect]` = speed<<4 \| brightness, brightness 0 to 4. Fixed-on (effect 1) is therefore `[29..31]`, `[38]`, `[39]`. **Correction:** "colour at `MODE[218..220]`" in my first version was only snake's slot (effect 10). Speed's base differs between sources (`fizzctl` says stored 0-based, verified on its hardware; Syozik takes 1 to 4); irrelevant for fixed-on.

**His own keyboard, from `lane-hardware`'s read-back at 18:14:** effect `0x0C` Reaction, not the stock `0x0B` Neon Stream (`fizzctl`'s `CONST_EXEC`), with parameters of his own; ROUTING equals stock. So a read showing `0B` after a write would suggest a fallback to the default config (my inference).

**The effect table** (Syozik's, matching `fizzctl`'s order): 00 off on Syozik's list, 16 off on `fizzctl`'s; 01 static, 02 breathing, 03 rainbow, 0A snake, 0B neon stream, 0C reaction, 0D sine wave, 14 flashing, 15 per-key.

**State at 19:10:** `lane-hardware` has the live path working and is still debugging the stored colour; he reports "rolling different colors", possibly while its 10-second colour test was still running. I sent it this section's facts. **The stored path is not proven on his keyboard yet.**

**Four cautions, all from reading the code:**
0. **Report 5 is shared with the Sinowealth ISP bootloader** (Syozik's `hidraw.py`: "0x75 jump-to-bootloader, 0x45 erase"). So `kawa-rgb` sends only the known selectors, from an allow-list. Never fuzz this report: it is his only keyboard in use.
1. **Flash wear:** the stored path must run once per real change, never per frame. The live path is the only one fit for animation.
2. **Its template frames are someone else's state.** `encode_firmware_effect` starts from captured bytes, so EXEC's unknown bytes could overwrite a setting of his. Our tool reads his live MODE and EXEC first and patches only the bytes above.
3. **It is his only keyboard in use.** Before the first stored write, save every read-back block to `~/.local/state/fedokawaii/k617/`. Prove the live path first; it cannot hurt. `fizzctl`'s `keymap` and `restore` are not needed at all: never send them. The cooler counts as a keyboard, but it has no keys.

**A calibration fact:** the OpenRGB fork's default for this keyboard is `BlueScale` 32/81, blue only. It hardly touches a red.

## 4. Motherboard: Mystic Light (`0db0:0076`, MS-7E28, USB 1-7)

**Physical** (MSI user guide, PRO A620M-B / PRO B650M-B): `JRGB1`, 12 V 5050 strips, up to 2 m, 3 A; `JARGB_V2_1`, 5 V, pins +5V / Data / no pin / Ground, "up to 240 individually addressable RGB LEDs" at 3 A; `SYS_FAN1~2` DC mode by default, 2 A; `CPU_FAN1`; two USB 2.0 headers, `JUSB2~3`. **The board has no second ARGB header, so the hub or the cooler or both share `JARGB_V2_1`, if they use it at all.**

**Controller** (OpenRGB `MSIMotherboard185Controller.cpp:355`): `{ 0x7E28, 6 onboard LEDs, 0, 0, 2 JRGBs, zones_set21, DIRECT_MODE_ZONE_BASED, min fw 0 }`. His descriptor has report `0x52` with 184 feature bytes, so 185 with the ID, matching. It also has `0x53` (724), `0x80-82` (241) and `0xA0-A2` (760), which we do not use.

**Packet** `FeaturePacket_185` (`MSIMotherboardCommon.h:213`), 185 bytes: report ID `0x52`, then `j_rgb_1` at 1, `j_pipe_1` 11, `j_pipe_2` 21, `j_rainbow_1` 31, `j_rainbow_2` 42, `j_corsair` 53, `j_corsair_outerll120` 64, `on_board_led` 74, then `on_board_led_1..9` from 84 to 164, `j_rgb_2` 174, **`save_data` at 184**. A zone is `effect, R, G, B, speedAndBrightnessFlags, R2, G2, B2, colorFlags, padding`; rainbow zones add `cycle_or_led_num`. Effects: 0 off, 1 static, 2 breathing, 3 flashing. Flags: speed in bits 0-1 (0 low), brightness in bits 2-6 (0 to 10), custom colour via `MSI_COLOR_FLAG_USE_CUSTOM_COLOR`.

**Writes:** read first (GET `0x52`), patch `j_rgb_1`, `j_rainbow_1` and `on_board_led`, write back. **`save_data = 1` persists to flash, so only once per real change; every frame uses 0.** OpenRGB's comment: "Windows Mystic Light sends two consecutive reports" in the mode path; its zone-based direct path sends one. Start from its zone-based initial packet (`:565-597`).

## 5. GPU logo: Gigabyte RX 9060 XT GAMING OC 16G

**Identity:** `pci_ids.h`: `GIGABYTE_RX9060XT_GAMING_OC_16G_SUB_DEV 0x2429`. **Controller:** `GigabyteRGBFusion2BlackwellGPUControllerDetect.cpp:145`, Gaming layout, **address `0x75`**, on the adapter named "AMDGPU DM i2c OEM bus" whose PCI parent is the card (`i2c-6` on 27 Oct, by the log and the planner). Do not hard-code the number.

**Presence test** (read-only in spirit, though it is a write): 64-byte block `10 01 00…`, then read: `01 01|02 01 xx` is valid ("Radeon RX 9070 XT GAMING OC 16G: 0x01 0x02 0x01 0x00").

**Set:** one 64-byte I2C write: `[reg, 0x01, mode, speed, brightness, R, G, B, 0x00, zone, numColours, …]`.
- `reg` = `0x12`: mode register, **"Limits updates to at most 9 per second"** (OpenRGB's comment). `reg` = `0x16`: "Intelligent", "faster updates (used for direct mode)", mode 0.
- Modes: 00 direct, 01 static, 02 breathing ("Pulse"), 03 flash, 04 double flash, 05 cycle. Speed 1 (slowest) to 6. Brightness 1 to 10.
- Zones in this layout: 0 Right fan, 1 Left fan, 2 Center fan, **3 Side** (6 hardware zones are written on a mode change). He says the card has only "a little rgb for the gigabyte logo and around it", so Side should be it. **The fan zones may have no LEDs; write the same colour to all.**
- Save: `13 01 00…` (64 bytes). **Once per real change.**

## 6. Fans, hub, cooler's LEDs: what software cannot know

- **No USB device for the hub** (the only unexplained one was the cooler), so it is at most a passive 5 V ARGB splitter or a controller with its own remote.
- **Nothing can be sensed:** ARGB data is one-way, and the board has no Super I/O driver loaded (`/sys/class/hwmon` shows no fan tach; the kernel's `nct6683` has `force` "to enable support for unknown vendors" per `modinfo`, root needed; worth one try to see fans on `SYS_FAN1/2`; I don't know that it reads this board).
- **darkFlash:** the case and fan models are unknown, so this is general. Its support pages: power the hub "such as SATA power", its fan cable to a board fan header, and "if the hub also controls lighting, connect its ARGB synchronization cable only as shown in the manual". Several of its products run their own effects from a button or remote (C6 "up to 20 lighting effects controlled by reset button", RC2 "up to 14", DR12 Pro "4 lighting mode controllable with controller"), and its FAQ has an entry "How do I use the LED button on my case?" (title only; I could not read the answer). **So a case button, a reset button or a remote may own the fans' LEDs**, with no cable to the board at all. Some of its cases and coolers have Windows drivers, but `lsusb` shows no darkFlash device here. Third-party copies of the DR12 Pro and DM12 Pro manuals describe the same: a SATA-powered hub, an optional 5 V cable to the board, an RF remote.
- **Jungle Leopard's air coolers** are sold with "5V 3-pin motherboard sync" (retailer text for KF420E-DGT), so the cooler's fan could be on `JARGB_V2_1` too.

**Design:** write red to `JRGB1` and `JARGB_V2_1` and accept what is connected. Zone-based mode means no LED count, so a chain of any length gets the one colour. Current is not a concern at dim red under a 3 A limit, though a long chain at full white would be.

**The one thing only his eyes can answer**, and the only physical request: "do the case fans and the cooler follow the red?" `lane-hardware` asked him on his page at 18:16. If not: one 3-pin cable into `JARGB_V2_1`, or the hub's remote set to board sync.

## 7. The design

**The owner decided at 18:45: one steady red, no breathing.** His words: "The GPU's RGB cannot stay in sync, so no breathing or any animation across devices." One steady red on every device, calibrated per device so they look identical (each brand renders red differently; the GPU drifts orange or pink). Event-driven: lock screen, fade to about 30 %; screens off or sleep, off; unlock or wake, full. A quick-settings switch for all of it, remembered across reboots. `lane-hardware` builds it. **This replaces the synced 8 Hz ember I proposed here**, and most of the K617 streaming worry with it.

**What still stands from this design:**

1. **Stored baseline** (once at install, again only on a real change): MSI static, GPU static, K617 `fixed-on`, all red, saved. Every device glows correctly from power-on: at the greeter, in ASOBI's session, with the host hung. No CPU, no bus traffic.
2. **Events use the volatile paths only:** MSI with `save_data` 0, the K617's live frame, the GPU's mode register without its save. **The flash paths never run per event;** a lock screen a day for years is real wear. A fade on the GPU's `0x12` is limited to 9 steps a second.
3. **Send linear light, not sRGB codes.** LEDs are linear PWM; sending `accent` `eb5324` as it stands gives orange. Decoded (2.2): about **213, 22, 3**. Compute this from the palette file at start, never hard-code. His per-device calibration goes on top. Dim by one factor on the linear values, so the hue holds; at 30 % the small channels are few counts, so check the hue there too.
4. **Typing:** a 382-byte control transfer goes to the same small controller that scans his keys (its EP0 is 8 bytes, `bMaxPacketSize0`, so about 48 packets, not trivial). On events this is rare, but the first keys after an unlock can meet it, so measure SET_REPORT once with `usbmon` and hold the frame if it costs a key. The 100+ WPM goal outranks the lights.
5. **Where it runs: a system service, not a user one.** It must work at the greeter, and interface 1 of the K617 carries key reports, so `TAG+="uaccess"` (as `fizzctl`'s rule does, even `MODE="0666"`) would let any process of his read keystrokes. Instead: `kawa-rgb.service`, `DynamicUser=yes`, a group `kawa-rgb`, udev rules giving that group only `hidraw` for `258a:0049` interface 1 and `0db0:0076`, plus the OEM I2C bus; `PrivateNetwork=yes`, `ProtectSystem=strict`, `DeviceAllow=` those, `MemoryMax=`. State arrives through a file in `/run/kawa-rgb/`. Reopen by sysfs on any write error, so replug and resume just work. `kawa-refresh` (T20r) already expects "the RGB/DDC state once T36/T38 exist".
6. **Tidy-up:** the cooler appears as keyboard and mouse to dwl (`input17-21`). `LIBINPUT_IGNORE_DEVICE=1` for `1a2c:4184` removes the ghost devices. `kawa-dwlstatus`'s Caps Lock comes from dwl's own state, so it is not affected, but `/sys/class/leds/input17::capslock` exists: nothing should read LEDs by first match.

**T36's accept, adjusted:** read back each device (MSI `GET 0x52`; K617 `05 88 b8` + GET; the GPU has no documented read of colour: say so); every event logged and the state correct after it; CPU under 0.5 % by `top`; restored after reboot and suspend; the `usbmon` number for the K617. Owner's eyes, on his page: the match across devices, and the fade.

## 8. T37: the cooler's display

**State:** the device is found (section 1) and a protocol to try is in section 9. This lane wrote nothing to it; `lane-hardware` sends that frame from `src/kawa-rgb/kawa-rgb.c`. **His eyes, 18:59 and 19:06:** the display shows "between 85 and 89 c", while `k10temp`'s Tctl read 85 at 19:01 under this round's load. That fits our frame, but a display with its own sensor would read the same. **The clean proof is his answer to a fixed number** (`lane-hardware` asked, 88 then 42, at 18:22; his 19:06 answer gives a temperature, not those numbers). **Searched again, 18:45:** GitHub's code and issue search find no other project naming this ID, only liquidctl 817. **Model:** not proven. The vendor's catalogue (`shop.htssl.com` API, behind `jlcpucooler.com`) lists KF400, KF401 ("KF401 DGT"), KF420 DGT, KF200-DGT, AF401 DGT, K400LCD and others; "DGT" is its digital line: the vendor's KF401 DGT and KF420 DGT photos show digits and a degree mark on the top cover ("Intelligent temperature display: visualize CPU temperature"), and their spec tables list only the fan's connector. KF400's page shows an infinity mirror and no digits.

**His HID interface:** `hidraw6` (interface 1), usage page `0xFF01`, report `0x07`: feature 63 bytes (usage 3) and output 63 bytes (usage 4), so 64 with the ID. Device: low speed, EP0 8 bytes, 100 mA. No OUT endpoint: `write()` on hidraw goes out as SET_REPORT. `hidraw` is `600 root`, as for the K617.

**Other Jungle Leopard displays do not apply:** `vunloon/kg401dgt` is serial; ProFlow is `33c3:7792`; AstroShel is `1f3a:0007` serial; `volcie/cooler-lcd-linux` is `5131:2007`; liquidctl closed issue 817 as not planned.

## 9. The display's protocol: the best evidence, unproven on his unit

**Source, read and never run:** the vendor's official "JL DGT Setup 1.0.0" (download page: `shop.htssl.com/shop-api/api/infos/articles/slug/driver-download`; zip sha256 `9413743af61d1f57fd96aab8935b43d6aa52cbf08477f11baab9a5a91ee262bd`). It is an Electron app by "Dongguan Hongtai Technology Co, Ltd.", a platform shared by many cooler brands, unpacked from its `app.asar`.

**What it says:**
- **His `1a2c:4184` appears nowhere in it.** JL DGT's own list is one device, `5131:2007` (`constant/appConstant.js:1396-1403`), and the "Jungle Leopard Display" build's is `5131:2023`. So **the vendor's current software does not support his firmware at all**, as far as this app shows.
- **But the same platform names two siblings** with the same chip maker's VID and the same usage page as his report: `{ vid: 6700, pid: 17229, usagePage: 65281 }` (`1a2c:434d`, "隐翅虫数显_客户自己的设备", a brand's digital display on the customer's own hardware) and `1a2c:4385` ("途易客户自己的风冷", a customer's own air cooler).
- **The protocol for `1a2c:434d`** (`_baseClass/device_hid.js:942-949`):
```js
const tempData = splitTempBCD(cpuFlag === 0 ? cpu_Temp_Z : gpu_Temp_Z);
const sendData = [0x07, 0xff, 0xff, ...tempData];
```
`splitTempBCD` (`util/common.js`) returns `[hundreds, tens, units]`, each a plain 0 to 9. So 42 °C is `07 FF FF 00 04 02`.
- **The first byte is report ID `0x07`, the exact report his descriptor declares for output on `0xFF01`.** That is why this is worth trying. It is a sibling's frame, not his: **a good hypothesis, nothing more.**
- **Timing:** every 200 ms (`getSendIntervalTime`), with no end. Comment at `:1096`: this device "occasionally fails during normal sending; closing it would flash the screen", so up to 10 failures are retried before closing. Keep the file open and tolerate failures.

**The test (`lane-hardware`'s; harmless, a display and no keys):**
1. **Read first:** `HIDIOCGFEATURE` report 7, 64 bytes, on interface 1. Log it. Any structure in it is a clue.
2. **Write:** `write(fd, frame, 64)`, padded with zeros, digits 1 2 3, every 200 ms for 10 s. `usbmon` shows an ACK or a STALL; a STALL rejects the frame shape.
3. **If nothing:** the same bytes as a feature report (the report has both), then the 6 bytes unpadded. **Then stop.** Do not fuzz: the firmware is a keyboard controller's, and nobody knows what its other commands do.
4. **Only his eyes can see the digits.** The model on the box or the cooler, if he has it to hand, would settle the rest.
5. **If it fails:** a capture would need a throw-away Windows VM with USB passthrough and a tool that actually supports `4184`, and this one does not. **One build remains unread:** the driver page's other download, `Jungle Leopard Display Setup 1.0.96` (228 MB, last modified 3 Nov), in case a newer platform build lists his ID. The server gave me 10 to 38 KB/s, so hours, and its payload is solid, so a part proves nothing; I stopped at 17 MB and deleted it. Worth finishing only if the digits do not respond (`curl -C -` resumes; look for pid `16772`, which is `0x4184`). `download.htssl.com`'s root answers 403, so other brands' builds cannot be listed. Otherwise T37's honest end: "the device is reachable, its protocol unknown, nothing driven", in the ledger.

**If it works:**
- Feed `k10temp` `Tctl` (find the hwmon by name, never by number) from `kawa-rgb`, on its own timer. **Learn the rate:** stop sending and see whether the display holds or blanks. Prefer 1 Hz if it holds: each frame is 8-byte control packets at low speed. If it needs 5 Hz, that is the vendor's rate and costs little.
- The frame carries digits only: no colour, and no sign of brightness. Its digits' colour is whatever the hardware has; the red is the fan's LEDs, from `JARGB_V2_1` if wired.
- Screens off or suspended: stop sending, and accept what the firmware does; check it does not show something wrong.

## Sources

Commands (4 Nov 2026): `lsusb`; `/sys/class/hidraw/*/device/report_descriptor`; `/sys/bus/usb/devices/*/{urbnum,bMaxPacketSize0,speed,removable}`; `/sys/bus/usb/devices/usb1/*/usb1-port*/{connect_type,location,firmware_node/path}`; `/proc/bus/input/devices`; `journalctl -k`; `rpm -q openrgb`; `strings /usr/bin/openrgb`; `~/.config/OpenRGB/logs/OpenRGB_20261027_021023.log`; `/usr/lib/udev/rules.d/60-openrgb.rules`, `60-ddcutil-i2c.rules`.
- K617: https://pypi.org/project/fizzctl/ , https://github.com/ayoubdya/fizzctl (0.5.1 sdist and `docs/` read, not run); https://github.com/MarceloAntonio/redragon-fizz-k617-rgb (`src/lib.rs`, README); https://github.com/Syozik/Redragon-keyboard-linux-app (`redragon_kb/lighting.py`, `hidraw.py`); https://github.com/pedro-anthony/openRGB (`Controllers/RedragonK617Controller/`); https://github.com/MrSchrodingers/fizz-rgb (`docs/reverse-engineering/protocol.md`, `packages/daemon/src/engine.ts`); OpenRGB's related device issues https://gitlab.com/CalcProgrammer1/OpenRGB/-/issues/3365 (Machenike K500 lists the same ID), `/issues/4388`
- OpenRGB, master of 3 Nov 2026, at https://gitlab.com/CalcProgrammer1/OpenRGB : `Controllers/SinowealthController/SinowealthControllerDetect.cpp`; `Controllers/MSIMotherboardController/` (`MSIMotherboardCommon.h`, `MSIMotherboard185Controller/`, `MSIMotherboardControllerDetect.cpp`); `Controllers/GigabyteRGBFusion2BlackwellGPUController/`; `pci_ids/pci_ids.h`; releases via its GitLab API
- MSI: https://www.msi.com/Motherboard/PRO-B650M-B/Specification , https://download-2.msi.com/archive/mnu_exe/mb/PROA620M-B_PROB650M-B_EN.pdf
- Cooler: https://github.com/liquidctl/liquidctl/issues/817 ; vendor site https://www.jlcpucooler.com/ , API `https://shop.htssl.com/shop-api/api/products` (KF400 is product 47), its installer `https://shop-api.htssl.com/uploads/driver/JL%20DGT%20Setup%201.0.0.zip` (`main/_baseClass/device_hid.js`, `main/constant/appConstant.js`, `main/util/common.js`, read in its `app.asar`, never run) ; others https://github.com/vunloon/kg401dgt , https://github.com/fimimo/proflow-240-control , https://github.com/loudscreamx/GifDisplay , https://github.com/volcie/cooler-lcd-linux ; retailer text (secondary) https://easypc.com.ph/products/jungle-leopard-kf420e-dgt-argb-cpu-air-cooler-black
- darkFlash: https://www.darkflash.com/support/0000024/0000377 (hub wiring), https://www.darkflash.com/driver , https://www.darkflash.com/product/c6 , https://www.darkflash.com/product/rc2 , https://www.darkflash.com/product/dr12proargb4pin , https://www.darkflash.com/article/argb-gen1-vs-gen2-whats-the-difference-and-how-to-connect-them ; third-party manual copies (secondary): https://manuals.plus/asin/B07CGH9CZL (DR12 Pro), https://manuals.plus/asin/B0F87Y8QVR (DM12 Pro)
