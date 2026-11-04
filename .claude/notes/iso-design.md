# The installer ISO — written design (T55)

Written 4 Nov 2026 by the research lane. Sources: `iso-research.md`, cited as (I§n). Nothing here has been booted (this
lane may not touch a VM): what only a boot can answer is section 8's first list, to run before anything else in T56.

## 1. Decisions

| Question | Decision | Why |
|---|---|---|
| Base | **The official Fedora Server netinst, its signed files untouched** | Secure Boot works as it comes; only files nobody signs change (I§5) |
| Build | **`xorriso … replay` + `mtools`, as a normal user, no root, no container, no `mkksiso`** | Proven here: byte-identical twice, 1.5 s (I§4). `mkksiso` needs root only for a loop mount we do not need |
| Install engine | **Anaconda from a kickstart, silent, behind our screens** | It knows UEFI, GPT, Btrfs, SELinux, dracut, efibootmgr; the harness already proves that exact layout. Omarchy's root image would not fit GitHub's 2 GiB, would be stale on day one, and leaves all that to us (I§1, I§8) |
| Questions | **Our own screen in `%pre`, on tty1, in Python 3.15 with `termios`** | `%pre` runs before any UI and may write what `%include` reads (I§2); no `dialog` or `stty` in the image, but Python is always there |
| Text | **The Linux console with our own PSF2 font: Sumi UI ×2, a 14 × 28 cell, plus our icons and seal as tiles, exactly 256 glyphs** | Sumi UI's letters are a fixed 7 px wide, so ×2 is exactly the design system's "installer's screens" (§2, §9) with no renderer to write. No GPU assumptions; kmscon is not in the image (I§0). 137 × 38 cells at 1080p. The kernel takes 256 or 512, and 512 leaves only 8 background colours (I§10, I§11) |
| Colours | **`questions.py` sets the 16 slots itself with `ESC ] P`** | The lacquer of the cursor (`select`, `82241f`) is not among the console's 16 boot colours, `theme.sh`'s `VT_ARGS` (I§10). Omarchy sets its palette the same way (I§1) |
| Who owns the screen | **One owner, as Omarchy: Anaconda runs in its normal tmux session, and nobody attaches** | `anaconda-tmux@.service`, the client on the console, is masked in `product.img`, so its text reaches no VT and our screens have tty1. **No `inst.notmux` and no `console=`:** the first starts a second Anaconda after the first ends, and the second is copied to the installed system and hides stage 1's failures (I§11). `VT_LOCKSWITCH` once our first screen is up, so that Alt+F2 cannot show anything else |
| Boot menu | **Themed, words as PNG; default after 5 s; two lines, no "basic graphics"** | Secure Boot refuses our `.pf2` files, PNG is allowed (I§5). Works identically with it on or off. `nomodeset` could not run this desktop anyway, which needs KMS: zero fallbacks |
| Splash | **Our `sumi` Plymouth theme through a second initrd** | The installer's initrd has no graphical Plymouth at all (I§0); a second initrd is unverified and allowed |
| Secure Boot | **Works on.** The owner's PC has it off and nothing requires a change | Dual-signed shim, no kernel modules of ours (I§5) |
| "Newest stable" | **The ISO is built from the newest stable and proven release; a newer one arrives through `update`, T46's path** | See below |
| Console stack | **`-kmscon` in `%packages`** | So an ISO install has the same console as his upgraded PC: one tool per job, `vt.default_*` and `setfont` keep working (I§7) |

### "The newest stable Fedora at install time"

The owner's words are one thing the ISO cannot literally do from a fixed image, and the honest answer has three parts:

1. `tools/build-iso.sh` reads `releases.json` at **build** time (numeric versions only, dropping "45 Beta") and refuses to build from anything but the newest stable that fedokawaii has proven (the VM pre-flight of T46).
2. At **install** time every package comes from the mirrors with `updates`, so the install is current to the day.
3. If Fedora has moved on since, the first `update` crosses over by T46's own path, with its VM pre-flight and rollback: **one tool per job, and that one is tested.** An F45 Anaconda installing F46 packages is promised by no document and tested by nobody (I§6): it is left out.

The ISO's first screen never asks about any of it.

## 2. What happens, in order

| # | On screen | What runs |
|---|---|---|
| 1 | Themed GRUB menu, torii, two lines ("install", "check this stick, then install"), the first chosen after 5 s | shim → GRUB (signed, unchanged) → our `grub.cfg` on partition 2 and the theme on the ISO9660 side |
| 2 | Plymouth `sumi`, torii on sumi ink | kernel (signed) + `initrd.img` + `fedokawaii-boot.img` (second initrd: `script.so`, `libply-splash-graphics.so.5`, renderers, `libpng`, `libdrm`, theme, `plymouthd.conf`). `rhgb quiet` + `theme.sh`'s `VT_ARGS`. Not the simpledrm blacklist of `BOOT_ARGS`: with it, a native driver that fails leaves no picture at all (I§11) |
| 3 | The splash stays | stage 2: `install.img` + `images/product.img` (our `questions.py`, `progress.py`, `failed.py`, font; `anaconda-tmux@`, `plymouth-quit` and `plymouth-quit-wait` masked, or `anaconda.target` would end the splash before our first draw and race it). `questions.py` does the handover itself, in this order: `plymouth quit --retain-splash`, `KDSETMODE KD_TEXT`, `VT_LOCKSWITCH`, first draw (I§10, I§11) |
| 4 | Stick check if asked; refusal, or questions | `%pre`: with `fk.check` on the line, `checkisomd5` in our screen with its progress (`rd.live.check` would run hidden and end in `sleep 43200`, I§11); checks; questions (section 3); writes `/tmp/answers.ks` atomically; verifies the payload's hash **before the disk is touched** (Omarchy's lesson) |
| 5 | Progress: base system, n of N packages | `%pre` left `progress.py` as a daemon with closed fds (the docs' warning, I§3). It also watches Anaconda's pid: gone without `%post`'s word, it shows `failed.py` (section 6). Anaconda silent in its tmux |
| 6 | "restarting" | `%post`: payload to `/usr/local/lib/fedokawaii`, `state/user`, `state/with-theme` (without it setup skips the theme, I§11), `TIMEZONE`, `KB_LAYOUTS` and `USERNAME` into that `fedokawaii.conf` (else setup and repair put the default zone back, I§11), phase 1, resume unit enabled, first-boot dress (below), and **last of all** the marker of section 3. `reboot --eject` |
| 7 | Splash, then setup's progress | three phases of `setup.sh --resume` on tty1, through their reboots. This exists and is proven in the harness |
| 8 | **ready**: the login screen | greetd, the last reboot |

No part of it asks after step 4. `setup.sh` has no prompts (`grep` of `read -` shows only file loops); its user comes from `$STATE_DIR/user` (`setup.sh:126`); his password is the one from step 4.

**First-boot dress.** `bootloader --append` carries `BOOT_ARGS` from `lib/common.sh` (generated at build, one truth), less the simpledrm blacklist, which setup adds as on any install, and `%post` sets `sumi` as the default theme, with `plymouth-plugin-script` in `%packages`, so that the first boot is never Fedora's.

## 3. The questions

Before any question, in this order, each a full screen with the reason and **any key powers off**, no retry loop: (a) booted without UEFI (`/sys/firmware/efi` absent); (b) less than 4 GiB of RAM (T57 checks that number); (c) no disk ≥ 60 GiB (the size the harness proves; the ISO's own device excluded); (d) no network (`nm-online -s -t 30`, because `inst.waitfornet` only runs after `%pre`, I§11; then `curl` of the metalink: names the cause: "no cable", "no address", "no answer from Fedora"). Wired only; Wi-Fi is out of scope, and the message says so.

If an install is found on a disk (its marker in the Btrfs `root` subvolume, mounted `ro,rescue=nologreplay`, because a plain read-only Btrfs mount still replays its log, I§11), the ISO says "fedokawaii is installed on this disk, remove the USB and restart" instead of asking again: a firmware that boots the stick twice must not look like a fresh start. **`%post` writes the marker as its last act**: the stick stays in through every reboot of setup's three phases, and a boot back into the ISO half way must not offer to erase a disk that is being finished. A reset inside `%post` leaves no marker and counts as a reset during Anaconda.

That screen is no dead end: `e` leads to the questions and the same erase page, for a real reinstall.

| # | Asked | Default | Rule |
|---|---|---|---|
| 1 | name | none | `^[a-z_][a-z0-9_-]{0,31}$`, not a system name |
| 2 | password, twice | none | not empty; dots; hashed `$y$` through `libcrypt.so.2` with `ctypes` (Python's `crypt` is gone); the hash goes in `/tmp/answers.ks`, on tmpfs |
| 3 | disk | one internal disk: that one. Several: none, he moves to one | internal only (`TRAN` not `usb`, `RM=0`): a backup drive is never offered, let alone by default. Each row: name, model, size, what is on it now. Smaller ones `faint` with their size, not selectable |
| 4 | timezone | Fedora's GeoIP, else UTC | filter on `tzdata.zi` |
| 5 | keyboard | us | filter over `/usr/share/systemd/kbd-model-map`, which pairs each console keymap with its XKB layout; `loadkeys` at once. The XKB one goes first in `KB_LAYOUTS`, so that the login screen reads the password as it was typed |
| 6 | this PC's name | fedokawaii | RFC 1123 |

Screens, in the design system's text grammar (§7, in Sumi UI ×2):

- One page for "who" (1, 2), one for "where" (3), one line each for 4, 5, 6 with their defaults, which `enter` accepts. The cursor is the lacquer row, as everywhere.
- Then one page: "everything on **nvme0n1** (Lexar 1 TB) will be erased", with what is on it now, `enter` to begin, `esc` back.
- The keyboard's key, `F2`, works on every page, so a wrong layout can be fixed before a password is typed.
- Words lower case, no hints a good design makes obvious; never "…"; the seal; dark mood.
- A typed password is confirmed by typing it again: that is the check, not a second question. Nothing else repeats.

A reset during Anaconda's stage restarts the ISO and asks again: no marker yet, and it is a new install. **This is the one place the owner's "nothing asks twice" does not hold**, and it stays so on purpose: before the marker there is nowhere to keep a password hash but the stick or the firmware's NVRAM, and neither is acceptable. After step 6 nothing asks.

## 4. The kickstart

Strict parse with pykickstart 3.77, `F45Handler`, warnings as errors: **OK** (I§3). `/tmp/answers.ks` holds `keyboard`, `timezone`, `network --hostname`, `user`, `ignoredisk --only-use` and `clearpart --all --initlabel --disklabel=gpt --drives=`, so that the erase names the chosen disk twice over. Written to a temporary name and renamed. Layout otherwise identical to `tools/vm-create.sh`.

```
text --non-interactive
lang en_US.UTF-8
url --metalink="https://mirrors.fedoraproject.org/metalink?repo=fedora-45&arch=x86_64"
repo --name=updates --metalink="https://mirrors.fedoraproject.org/metalink?repo=updates-released-f45&arch=x86_64"
rootpw --lock
firstboot --disable
selinux --enforcing
services --disabled=sshd
bootloader --timeout=1 --append="…BOOT_ARGS at build…"
zerombr
part /boot/efi --fstype=efi --size=600
part /boot --fstype=xfs --size=2048
part btrfs.01 --fstype=btrfs --grow
btrfs none --label=fedora btrfs.01
btrfs / --subvol --name=root fedora
%include /tmp/answers.ks
reboot --eject

%pre --interpreter=/usr/bin/python3 --erroronfail --log=/tmp/fk-pre.log
# hands over to /usr/share/fedokawaii-iso/questions.py (from product.img)
%end

%packages
@^custom-environment
plymouth-plugin-script
-kmscon
%end

%post --nochroot --erroronfail --log=/mnt/sysimage/var/log/fk-post.log
# the payload, the state, the resume unit (section 2, step 6)
%end

%onerror --interpreter=/usr/bin/python3
# /usr/share/fedokawaii-iso/failed.py: what failed, in our screen, the log's path
%end
```

Boot line: `inst.stage2=hd:LABEL=<volid> inst.ks=hd:LABEL=<volid>:/ks.cfg inst.text inst.noshell inst.geoloc=0 inst.nosave=input_ks,output_ks rhgb quiet …VT_ARGS and BOOT_ARGS, less the blacklist…`.

The skeleton with `/tmp/answers.ks` filled in (`keyboard --vckeymap=us --xlayouts=us`, `timezone Asia/Dubai --utc`, `network --hostname=…`, `user --name=… --groups=wheel --iscrypted --password=…`, `ignoredisk --only-use=…`, `clearpart … --drives=…`) parses strictly under `F45Handler` too (I§10).

`sshd` is off and the harness's `NOPASSWD` line stays in the harness only: no back door in the product. `inst.nosave` keeps the hash out of `/root/anaconda-ks.cfg`. T56's test greps the whole installed disk for it, not only `/var/log/anaconda/`.

## 5. The build: `tools/build-iso.sh`

Inputs, each pinned, in a small file next to the tool:

| Input | Pin |
|---|---|
| Fedora netinst | URL + SHA-256 from `releases.json` (refuses any mismatch) |
| The toolkit | `git archive <ref>`, `xz -T1`, its hash in the ISO for `%pre` to check |
| Plymouth bits for the second initrd | RPMs by NVR of the **same** release as the ISO, SHA-256 each, from Fedora's repo; `readelf` lists what `script.so` needs, the build fails if one is missing |
| Art, fonts | from the repo at `<ref>` (`tools/build-art.py`, `art/grub`, `system/plymouth/sumi`) |
| Time | `SOURCE_DATE_EPOCH` = the commit's time |

Steps, none needing root:

1. Verify the netinst. 2. Build `product.img` and `fedokawaii-boot.img` (`cpio --reproducible`, sorted, `xz --check=crc32`, the only check the kernel's decompressor takes). 3. PSF2 font, padded to exactly 256 glyphs. 4. Rewrite `grub.cfg`: entries, theme, one `initrd` line with two files. 5. `mcopy -o -m` it into the EFI partition image and `xorriso -update` it on the ISO9660 side (`/EFI/BOOT/grub.cfg`, `BOOT.conf`, `boot/grub2/grub.cfg`), all the same file. 6. `xorriso … replay`, `-map` the rest. 7. `implantisomd5` (build-only `isomd5sum`), so that the media test still passes. 8. `.sha256`.

Twice from the same inputs: **the same bytes for step 6, proven (I§4)**; steps 2, 3, 7 to be proven in T56. Volume id stays Fedora's: `inst.stage2` and the GRUB `search` depend on it, and nothing else needs ours. The EFI partition has 0.5 MB free: nothing but `grub.cfg` goes there.

**GRUB under Secure Boot:** `theme.txt` draws everything with `image` components and the entries through `--class` icons (`icons/<class>.png`) with an empty title: the words are PNG in Sumi UI ×2, no `loadfont`, no text. `tools/build-art.py` renders them. Unifont (the signed image's only font) is what any GRUB error message will use, and that cannot be helped.

**The installed system** has the same limit: `theme.sh`'s `sumi-*.pf2` will not load under Secure Boot. Nothing changes on his PC (off). On a Secure Boot machine its menu falls back to Unifont, or to invisible words. T56 should make `theme.sh` use the same PNG words, and the test sees it.

## 6. Failure modes, argued against

| A skeptic says | Answer |
|---|---|
| The stick stays in; the firmware boots it again | Marker check, section 3; `reboot --eject` for optical; Anaconda should put Fedora first in the boot order: T57's row sees whether it does |
| Anaconda crashes, or dies early | `%onerror` shows it in our screen with the log's path. A `%pre` that raises or a parse error reaches no `%onerror` (I§11), and the VT is locked with no shell: `questions.py` catches its own failures, and `progress.py` watches the pid. Tested with a bad repo URL and with a raising `%pre` |
| Mirrors fail mid-way | Anaconda's own retries; a final failure → `%onerror`. Slow-network run in T57 |
| Mirror content changed between `%pre`'s check and install | Nothing to do: `%onerror`; no half-state matters on a disk that was going to be erased |
| Reset during `setup.sh` | The resume unit, proven by the harness; T57's reset in phase 2 |
| A newer Fedora lands between builds | Stays on the proven one; `update` crosses over (section 1) |
| F46's boot.iso comes from image-builder (I§4) | `replay` reads what is there, and is not tied to lorax; a T46-class re-check at F46 |
| A one-signature shim arrives | Then F46's ISO may not boot on firmware without the 2023 key. It is what the release does; the ISO says nothing about it; note it for F46 |
| The second initrd's `plymouth` plugin does not match stage 1's `libply` | Same release, same NVR, pinned; checked with `ldd` in the build |
| `%pre`'s daemon is killed or Anaconda blocks | Docs' warning followed; first experiment in section 8 |
| Password in a log | Never on a command line, never printed; `inst.nosave`; test greps the whole installed disk for the hash |
| Setup overrides an answer | `setup.sh` and `repair` set `TIMEZONE` from `fedokawaii.conf`, and the login screen uses `KB_LAYOUTS`: `%post` writes both. T57 checks them after setup and after `repair` |
| The keyboard locks him out | The chosen layout is the login screen's first. T57: `de`, a password with z and y, a real login |
| A disk is chosen wrongly | Internal disks only, no default among several, every row says what is on it; the confirmation names model and size; never automatic. Two-disk row in T57 |
| His real disk during tests | `vm-iso-test.sh` only ever creates a qcow2 for a session VM and takes no device argument; the owner decided the ISO is never run on his PC |

## 7. What it does not do

- No Wi-Fi: wired network required, said on the refusal screen.
- No BIOS install: UEFI only, said on the refusal screen (the GPT layout assumes it). The ISO still has its BIOS boot record, because replay keeps it.
- No offline install: `setup.sh` fetches everything anyway.
- No disk encryption: the layout has none, the owner never asked; a question less.
- No dual boot, no keeping other partitions: `clearpart --all` on the chosen disk.
- Keyboard: one layout plus the desktop's Arabic second (`KB_LAYOUTS`, four at most); the bar's tile names what it finds.
- Hardware: tested in the VM only. The owner's rule is never to run it on his real disk.

## 8. Tests

### First, in T56, before building the rest (each answers something this lane could not boot to see)

| Experiment | Decides |
|---|---|
| Boot the replayed ISO with a stub `%pre` that opens tty1, quits Plymouth, sets `KD_TEXT`, locks switching, draws, reads a line, with `anaconda-tmux@` and both quit units masked | The VT plan and the handover: frame by frame, is there a black blink between the splash and our first draw (`drm_file.c:441`, I§11)? If Anaconda or a getty fights for tty1, use tty8 and `chvt` (the documented older pattern) |
| `setfont` a 14 × 28 PSF2 of 256 glyphs on `drm` fbcon (the kernel allows up to 64 × 128 and 512 glyphs, `vt.c`), `ESC ] P` for the lacquer, then a screenshot | The font and the colours, down to the pixel with `tools/px.py` |
| Second initrd with `script.so` + `sumi`, screenshot at 2 s and at switch-root | The splash; no black gap |
| PNG-only theme with **OVMF secure-boot, enrolled keys** | The menu under Secure Boot; `mokutil --sb-state` in the guest proves it was on |
| `images/product.img` overlay is present in stage 2 | Our files arrive; otherwise embed them in `%pre` |
| Parse packaging progress from a real run | `progress.py`'s source |
| `%pre`'s daemon survives into the installation | Otherwise start it from `%pre-install`; a VT must keep showing it |
| `-kmscon` with `@^custom-environment` on F45 | Excluded cleanly; greetd and resume unit as on the harness |
| A damaged `install.img` on a test ISO | What stage 1 shows under the splash. Silence is a defect: T56 decides how the failure reaches the screen |

### T57's matrix, each from a wiped disk (`tools/vm-iso-test.sh`, `virsh send-key` and `virsh screenshot`; the real screens, no answer file)

| Run | Expect |
|---|---|
| 3 × clean, Secure Boot on, 8 GiB, 6 vCPU, 80 GiB, the ISO attached as a USB disk in one of them | login screen, `verify` green, time recorded, `mokutil` on; `/proc/cmdline` as designed |
| Two internal disks and a 2 TB USB disk | USB not offered, no default, the unchosen disks' bytes unchanged (checksum) |
| Secure Boot off | the same; menu pixel-identical |
| 60 GiB exactly | installs (the stated minimum) |
| 20 GiB | refusal, stops, disk untouched |
| No network (`domif-setlink down`) | refusal naming the cause, stops |
| BIOS firmware | refusal |
| Slow network (`tc netem`) | converges |
| Reset during Anaconda | ISO starts over, asks, installs |
| Reset during `setup.sh` phase 2 | resumes, converges, asks nothing |
| ISO left in, boot order ISO first, once after `%post` and once after setup's end | "installed on this disk", both times; the disk untouched |
| Alt+F2 on every screen | nothing moves |
| Wrong keyboard chosen, `F2` | password typed right |
| `de` chosen, a password with z and y | a real login at the login screen, Asia/Tokyo and `de` still there after setup and after `repair` |
| A raising `%pre`, a kickstart that cannot parse | our failure screen, never a frozen one |
| "check this stick" with a corrupted ISO | says so in our screen, disk untouched |
| Mirror unreachable at package step | `%onerror`'s screen with the log's path |
| Two builds | `sha256sum` equal |
| The whole installed disk | no password hash outside `/etc/shadow` |

Screens saved as PNG at menu, each question, progress, restarting, login; both measured with `tools/px.py`. Install time per run.

## 9. What changes in the plan

- **T56**: `%post` seeds `with-theme` and `fedokawaii.conf`; `product.img` masks three units; drop `lorax`/`mkksiso` from the build-only list (`xorriso`, `mtools` and `isomd5sum` remain); no container or VM needed to build. "Terminus/our console font" → our PSF2. Question TUI in Python, not bash (no `stty`, `tput`, `clear`). `theme.sh` gets PNG words for Secure Boot.
- **`f45-changes.md` line 81**: kmscon is not in the installer's image. `-kmscon` in the kickstart, and the VM harness's kickstart should match when T46 moves it to F45, otherwise harness and product differ.
- **T57**: as section 8; add the rows that are new here.
- **T42/T45**: a marker for "installed", written last by `%post`. If a rollback ever loses it, the only cost is that a booted stick asks again; the erase page still stands in the way.
- **T50**: the Learn piece "installing from the ISO", once T57 has its screens.
