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
| Text | **The Linux console with our own PSF2 font: Sumi UI ×2, a 14 × 28 cell, plus our icons and seal as tiles** | Sumi UI's letters are a fixed 7 px wide, so ×2 is exactly the design system's "installer's screens" (§2, §9) with no renderer to write. No GPU assumptions; kmscon is not in the image (I§0). 137 × 38 cells at 1080p |
| Who owns the screen | **One owner, as Omarchy: the installer's noise goes elsewhere** | `inst.notmux` + `console=tty2`: Anaconda's text lands on an unseen VT, our screens have tty1 |
| Boot menu | **Themed, words as PNG; default after 5 s** | Secure Boot refuses our `.pf2` files, PNG is allowed (I§5). Works identically with it on or off |
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
| 1 | Themed GRUB menu, torii, three lines ("install", "check this stick, then install", "install with basic graphics"), first chosen after 5 s | shim → GRUB (signed, unchanged) → our `grub.cfg` on partition 2 and the theme on the ISO9660 side |
| 2 | Plymouth `sumi`, torii on sumi ink | kernel (signed) + `initrd.img` + `fedokawaii-boot.img` (second initrd: `script.so`, renderers, `libpng`, `libdrm`, theme, `plymouthd.conf`). `rhgb quiet` + the palette's `vt.default_*` from `lib/common.sh` |
| 3 | The splash stays | stage 2: `install.img` + `images/product.img` (our `questions.py`, `progress.py`, `failed.py`, font, and a `plymouth-quit` override: `anaconda.target` wants it, and `--retain-splash` must hold the picture until our first draw) |
| 4 | Refusal, or questions | `%pre`: checks, then the questions (section 3); writes `/tmp/answers.ks`; verifies the payload's hash **before the disk is touched** (Omarchy's lesson) |
| 5 | Progress: base system, n of N packages | `%pre` left `progress.py` as a daemon with closed fds (the docs' warning, I§3). Anaconda silent on tty2 |
| 6 | "restarting" | `%post`: payload to `/usr/local/lib/fedokawaii`, `state/user`, phase 1, resume unit enabled, first-boot dress (below). `reboot --eject` |
| 7 | Splash, then setup's progress | three phases of `setup.sh --resume` on tty1, through their reboots. This exists and is proven in the harness |
| 8 | **ready**: the login screen | greetd, the last reboot |

No part of it asks after step 4. `setup.sh` has no prompts (`grep` of `read -` shows only file loops); its user comes from `$STATE_DIR/user` (`setup.sh:126`); his password is the one from step 4.

**First-boot dress.** `bootloader --append` carries `BOOT_ARGS` from `lib/common.sh` (generated at build, one truth) and `%post` sets `sumi` as the default theme, with `plymouth-plugin-script` in `%packages`, so that the first boot is never Fedora's.

## 3. The questions

Before any question, in this order, each a full screen with the reason and **any key powers off**, no retry loop: (a) booted without UEFI (`/sys/firmware/efi` absent); (b) less than 4 GiB of RAM (T57 checks that number); (c) no disk ≥ 60 GiB (the size the harness proves; the ISO's own device excluded); (d) no network (`inst.waitfornet=30`, then `curl` of the metalink: names the cause: "no cable", "no address", "no answer from Fedora"). Wired only; Wi-Fi is out of scope, and the message says so.

If a finished install is found on a disk (its marker in the Btrfs `root` subvolume, mounted read-only), the ISO says "fedokawaii is installed on this disk, remove the USB" instead of asking again: a firmware that boots the stick twice must not look like a fresh start.

| # | Asked | Default | Rule |
|---|---|---|---|
| 1 | name | none | `^[a-z_][a-z0-9_-]{0,31}$`, not a system name |
| 2 | password, twice | none | not empty; dots; hashed `$y$` through `libcrypt.so.2` with `ctypes` (Python's `crypt` is gone); the hash goes in `/tmp/answers.ks`, on tmpfs |
| 3 | disk | largest eligible | list: name, model, size; smaller ones `faint` with their size, not selectable |
| 4 | timezone | Fedora's GeoIP, else UTC | filter on `tzdata.zi` |
| 5 | keyboard | us | filter over `localectl list-keymaps`; `loadkeys` at once |
| 6 | this PC's name | fedokawaii | RFC 1123 |

Screens, in the design system's text grammar (§7, in Sumi UI ×2):

- One page for "who" (1, 2), one for "where" (3), one line each for 4, 5, 6 with their defaults, which `enter` accepts. The cursor is the lacquer row, as everywhere.
- Then one page: "everything on **nvme0n1** (Lexar 1 TB) will be erased", `enter` to begin, `esc` back.
- The keyboard's key, `F2`, works on every page, so a wrong layout can be fixed before a password is typed.
- Words lower case, no hints a good design makes obvious; never "…"; the seal; dark mood.
- A typed password is confirmed by typing it again: that is the check, not a second question. Nothing else repeats.

A reset during Anaconda's stage restarts the ISO and asks again: the disk has nothing yet, and it is a new install. After step 6 nothing asks.

## 4. The kickstart

Strict parse with pykickstart 3.77, `F45Handler`, warnings as errors: **OK** (I§3). `/tmp/answers.ks` holds `keyboard`, `timezone`, `network --hostname`, `user`, `ignoredisk --only-use`. Layout identical to `tools/vm-create.sh`.

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
clearpart --all --initlabel --disklabel=gpt
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

Boot line: `inst.stage2=hd:LABEL=<volid> inst.ks=hd:LABEL=<volid>:/ks.cfg inst.text inst.notmux inst.noshell inst.geoloc=0 inst.waitfornet=30 inst.nosave=input_ks,output_ks console=tty2 rhgb quiet …BOOT_ARGS…`.

`sshd` is off and the harness's `NOPASSWD` line stays in the harness only: no back door in the product. `inst.nosave` keeps the hash out of `/root/anaconda-ks.cfg`. T56's test greps `/var/log/anaconda/` for it.

## 5. The build: `tools/build-iso.sh`

Inputs, each pinned, in a small file next to the tool:

| Input | Pin |
|---|---|
| Fedora netinst | URL + SHA-256 from `releases.json` (refuses any mismatch) |
| The toolkit | `git archive <ref>`, `xz -T1`, its hash in the ISO for `%pre` to check |
| Plymouth bits for the second initrd | RPMs by NVR of the **same** release as the ISO, SHA-256 each, from Fedora's repo |
| Art, fonts | from the repo at `<ref>` (`tools/build-art.py`, `art/grub`, `system/plymouth/sumi`) |
| Time | `SOURCE_DATE_EPOCH` = the commit's time |

Steps, none needing root:

1. Verify the netinst. 2. Build `product.img` and `fedokawaii-boot.img` (`cpio --reproducible`, sorted, `xz`). 3. PSF2 font. 4. Rewrite `grub.cfg`: entries, theme, one `initrd` line with two files. 5. `mcopy -o -m` it into the EFI partition image and `xorriso -update` it on the ISO9660 side (`/EFI/BOOT/grub.cfg`, `BOOT.conf`, `boot/grub2/grub.cfg`), all the same file. 6. `xorriso … replay`, `-map` the rest. 7. `implantisomd5` (build-only `isomd5sum`), so that the media test still passes. 8. `.sha256`.

Twice from the same inputs: **the same bytes for step 6, proven (I§4)**; steps 2, 3, 7 to be proven in T56. Volume id stays Fedora's: `inst.stage2` and the GRUB `search` depend on it, and nothing else needs ours. The EFI partition has 0.5 MB free: nothing but `grub.cfg` goes there.

**GRUB under Secure Boot:** `theme.txt` draws everything with `image` components and the entries through `--class` icons (`icons/<class>.png`) with an empty title: the words are PNG in Sumi UI ×2, no `loadfont`, no text. `tools/build-art.py` renders them. Unifont (the signed image's only font) is what any GRUB error message will use, and that cannot be helped.

**The installed system** has the same limit: `theme.sh`'s `sumi-*.pf2` will not load under Secure Boot. Nothing changes on his PC (off). On a Secure Boot machine its menu falls back to Unifont, or to invisible words. T56 should make `theme.sh` use the same PNG words, and the test sees it.

## 6. Failure modes, argued against

| A skeptic says | Answer |
|---|---|
| The stick stays in; the firmware boots it again | Marker check, section 3; `reboot --eject` for optical; Anaconda should put Fedora first in the boot order: T57's row sees whether it does |
| Anaconda crashes | `%onerror` shows it in our screen with the log's path. Tested with a bad repo URL |
| Mirrors fail mid-way | Anaconda's own retries; a final failure → `%onerror`. Slow-network run in T57 |
| Mirror content changed between `%pre`'s check and install | Nothing to do: `%onerror`; no half-state matters on a disk that was going to be erased |
| Reset during `setup.sh` | The resume unit, proven by the harness; T57's reset in phase 2 |
| A newer Fedora lands between builds | Stays on the proven one; `update` crosses over (section 1) |
| F46's boot.iso comes from image-builder (I§4) | `replay` reads what is there, and is not tied to lorax; a T46-class re-check at F46 |
| A one-signature shim arrives | Then F46's ISO may not boot on firmware without the 2023 key. It is what the release does; the ISO says nothing about it; note it for F46 |
| The second initrd's `plymouth` plugin does not match stage 1's `libply` | Same release, same NVR, pinned; checked with `ldd` in the build |
| `%pre`'s daemon is killed or Anaconda blocks | Docs' warning followed; first experiment in section 8 |
| Password in a log | Never on a command line, never printed; `inst.nosave`; test greps the installed system's logs for the hash |
| A disk is chosen wrongly | Two steps, the confirmation names model and size; the ISO's own stick is excluded; never automatic |
| His real disk during tests | `vm-iso-test.sh` only ever creates a qcow2 for a session VM and takes no device argument; the owner decided the ISO is never run on his PC |

## 7. What it does not do

- No Wi-Fi: wired network required, said on the refusal screen.
- No BIOS install: UEFI only, said on the refusal screen (the GPT layout assumes it). The ISO still has its BIOS boot record, because replay keeps it.
- No offline install: `setup.sh` fetches everything anyway.
- No disk encryption: the layout has none, the owner never asked; a question less.
- No dual boot, no keeping other partitions: `clearpart --all` on the chosen disk.
- Keyboard: `loadkeys` for the VT; the desktop's own US and AR come from setup.
- Hardware: tested in the VM only. The owner's rule is never to run it on his real disk.

## 8. Tests

### First, in T56, before building the rest (each answers something this lane could not boot to see)

| Experiment | Decides |
|---|---|
| Boot the replayed ISO with a stub `%pre` that opens tty1, draws, reads a line, under `inst.notmux console=tty2` | The VT plan; if Anaconda or a getty fights for tty1, use tty8 and `chvt` (the documented older pattern) |
| `setfont` a 14 × 28 PSF2 on `drm` fbcon (the kernel allows up to 64 × 128 and 512 glyphs, `vt.c`), then a screenshot | The font plan, down to the pixel with `tools/px.py` |
| Second initrd with `script.so` + `sumi`, screenshot at 2 s and at switch-root, under `console=tty2` | The splash; no black gap; whether Plymouth follows `console=` to tty2 (then `%pre` does `chvt 1`) |
| PNG-only theme with **OVMF secure-boot, enrolled keys** | The menu under Secure Boot; `mokutil --sb-state` in the guest proves it was on |
| `images/product.img` overlay is present in stage 2 | Our files arrive; otherwise embed them in `%pre` |
| Parse packaging progress from a real run | `progress.py`'s source |
| `%pre`'s daemon survives into the installation | Otherwise start it from `%pre-install`; a VT must keep showing it |
| `-kmscon` with `@^custom-environment` on F45 | Excluded cleanly; greetd and resume unit as on the harness |

### T57's matrix, each from a wiped disk (`tools/vm-iso-test.sh`, `virsh send-key` and `virsh screenshot`; the real screens, no answer file)

| Run | Expect |
|---|---|
| 3 × clean, Secure Boot on, 8 GiB, 6 vCPU, 80 GiB | login screen, `verify` green, time recorded, `mokutil` on |
| Secure Boot off | the same; menu pixel-identical |
| 60 GiB exactly | installs (the stated minimum) |
| 20 GiB | refusal, stops, disk untouched |
| No network (`domif-setlink down`) | refusal naming the cause, stops |
| BIOS firmware | refusal |
| Slow network (`tc netem`) | converges |
| Reset during Anaconda | ISO starts over, asks, installs |
| Reset during `setup.sh` phase 2 | resumes, converges, asks nothing |
| ISO left in, boot order ISO first | "installed on this disk" |
| Wrong keyboard chosen, `F2` | password typed right |
| Mirror unreachable at package step | `%onerror`'s screen with the log's path |
| Two builds | `sha256sum` equal |
| Logs of the installed system | no password hash |

Screens saved as PNG at menu, each question, progress, restarting, login; both measured with `tools/px.py`. Install time per run.

## 9. What changes in the plan

- **T56**: drop `lorax`/`mkksiso` from the build-only list (`xorriso`, `mtools` and `isomd5sum` remain); no container or VM needed to build. "Terminus/our console font" → our PSF2. Question TUI in Python, not bash (no `stty`, `tput`, `clear`). `theme.sh` gets PNG words for Secure Boot.
- **`f45-changes.md` line 81**: kmscon is not in the installer's image. `-kmscon` in the kickstart, and the VM harness's kickstart should match when T46 moves it to F45, otherwise harness and product differ.
- **T57**: as section 8; add the rows that are new here.
- **T42/T45**: a marker for "finished install". If a rollback ever loses it, the only cost is that a booted stick asks again; the erase page still stands in the way.
- **T50**: the Learn piece "installing from the ISO", once T57 has its screens.
