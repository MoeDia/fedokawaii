# The installer ISO — written design (T55)

Written 4 Nov 2026 by the research lane. Sources: `iso-research.md`, cited as (I§n). This lane boots nothing and may not
touch a VM. `lane-iso` builds T56 from an earlier version of this file: **where its boots and this file differ, its boots win**, and
what they settled is folded in here (I§12.8). Section 10 is new: the owner's real PC and real disk, which no VM run shows.

## 1. Decisions

| Question | Decision | Why |
|---|---|---|
| Base | **The official Fedora Server netinst, its signed files untouched** | Secure Boot works as it comes; only files nobody signs change (I§5) |
| Build | **`xorriso … replay` + `mtools`, as a normal user, no root, no container, no `mkksiso`** | Proven here: byte-identical twice, 1.5 s (I§4). `mkksiso` needs root only for a loop mount we do not need |
| Install engine | **Anaconda from a kickstart, silent, behind our screens** | It knows UEFI, GPT, Btrfs, SELinux, dracut, efibootmgr; the harness already proves that exact layout. Omarchy's root image would not fit GitHub's 2 GiB, would be stale on day one, and leaves all that to us (I§1, I§8) |
| Questions | **Our own screen in `%pre`, on a VT of its own, in Python 3.15 with `termios`** | `%pre` runs before any UI and may write what `%include` reads (I§2); no `dialog` or `stty` in the image, but Python is always there |
| Text | **The Linux console with our own PSF2 font: Sumi UI ×2, a 14 × 28 cell, plus our icons and seal as tiles, exactly 256 glyphs** | Sumi UI's letters are a fixed 7 px wide, so ×2 is exactly the design system's "installer's screens" (§2, §9) with no renderer to write. No GPU assumptions; kmscon is not in the image (I§0). 137 × 38 cells at 1080p. The kernel takes 256 or 512, and 512 leaves only 8 background colours (I§10, I§11) |
| Colours | **`questions.py` sets the 16 slots itself with `ESC ] P`** | The lacquer of the cursor (`select`, `82241f`) is not among the console's 16 boot colours, `theme.sh`'s `VT_ARGS` (I§10). Omarchy sets its palette the same way (I§1) |
| Who owns the screen | **One owner, as Omarchy: our screens on tty8. Anaconda runs direct on tty1 behind them, `inst.notmux console=tty1`, and nothing shows tty1** | Settled by `lane-iso`'s boots (I§12.8), replacing this file's first idea of masking the tmux client. Its two costs are met: `%post` takes `console=` out of everything the installed system reads (I§12.6), and the second Anaconda that `inst.notmux` brings becomes our failure screen (section 6). `VT_LOCKSWITCH` once our first screen is up, so that Alt+F2 cannot show anything else |
| Boot menu | **Themed, words as PNG; default after 5 s; no "basic graphics"; `gfxmode=1920x1080,auto`** | Secure Boot refuses our `.pf2` files, PNG is allowed (I§5). Works identically with it on or off. `nomodeset` could not run this desktop anyway, which needs KMS: zero fallbacks. Plain `auto` keeps whatever mode the firmware left, which need not be 1080p; `theme.sh` already asks for the exact mode first (I§12.5). `lane-iso` has three lines today: install, check, power off |
| Stick check | **Our own: SHA-256 of the ISO's files, read through ISO9660. No `checkisomd5`, no `implantisomd5`** | `checkisomd5` hashes sectors, and firmware or an automount may rewrite GPT fields on a good stick: Fedora's own F45 issue, unfixed (I§12.2). Saying "damaged" and powering off on a false reading is the worst thing this screen could do. Files are what the install reads, which is upstream's own suggestion in that bug |
| Erase | **In `%pre`, after the confirmation and only after `%pre` has made Anaconda's own checks itself (section 3). Anaconda finds an empty disk** | So blivet never walks his subvolumes and snapshots one by one (I§12.3), and T57's blank disk is nearer his real one. **It has a price:** Anaconda's parse, repo, package and space checks all run before `clearpart`, so they would now come after the disk is gone (I§12.10). Hence the checks first. `clearpart` stays, on nothing |
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
| 3 | The splash stays | stage 2: `install.img` + `images/product.img` (our `questions.py`, `progress.py`, `failed.py`, font; `plymouth-quit`, `plymouth-quit-wait` and `systemd-vconsole-setup` masked, `anaconda.service` replaced, section 6). The handover, as `lane-iso` proved it (I§12.8): dress tty8 behind the splash, then at the first page `plymouth quit`, `VT_ACTIVATE`, `VT_LOCKSWITCH`, colours again, draw |
| 4 | Stick check if asked; refusal, or questions | `%pre`: with `fk.check` on the line, the file check in our screen with its progress (section 5; `rd.live.check` would run hidden and end in `sleep 43200`, I§11); checks; questions (section 3); writes `/tmp/answers.ks` atomically; **before the disk is touched** (Omarchy's lesson) proves the payload, the stick and what Anaconda will need; then erases (section 3) |
| 5 | Progress: base system, n of N packages | `%pre` left `progress.py` as a daemon with closed fds (the docs' warning, I§3); it reads Anaconda's own lines from `/tmp/syslog` (I§12.8). Anaconda behind it on tty1 |
| 6 | "restarting" | `%post`: payload to `/usr/local/lib/fedokawaii`, `state/user`, `state/with-theme` (without it setup skips the theme, I§11), `TIMEZONE`, `KB_LAYOUTS` and `USERNAME` into that `fedokawaii.conf` (else setup and repair put the default zone back, I§11), phase 1, resume unit enabled, first-boot dress (below), and **last of all** the marker of section 3. `reboot --eject` |
| 7 | Splash, then setup's progress | three phases of `setup.sh --resume` on tty1, through their reboots. This exists and is proven in the harness |
| 8 | **ready**: the login screen | greetd, the last reboot |

No part of it asks after step 4. `setup.sh` has no prompts (`grep` of `read -` shows only file loops); its user comes from `$STATE_DIR/user` (`setup.sh:126`); his password is the one from step 4.

**First-boot dress.** `bootloader --append` carries `BOOT_ARGS` from `lib/common.sh` (generated at build, one truth), less the simpledrm blacklist, which setup adds as on any install, and `%post` sets `sumi` as the default theme, with `plymouth-plugin-script` in `%packages`, so that the first boot is never Fedora's.

## 3. The questions

Before any question, in this order, each a full screen with the reason and **any key powers off**, no retry loop: (a) booted without UEFI (`/sys/firmware/efi` absent); (b) less than 4 GiB of RAM (T57 checks that number); (c) no disk ≥ 60 GiB (the size the harness proves; the ISO's own device excluded); (d) no network (`nm-online -s -t 30`, because `inst.waitfornet` only runs after `%pre`, I§11; then `curl` of the metalink: names the cause: "no cable", "no address", "no answer from Fedora"). Wired only; Wi-Fi is out of scope, and the message says so.

If an install is found on a disk (its marker in the Btrfs `root` subvolume, mounted `ro,rescue=nologreplay`, because a plain read-only Btrfs mount still replays its log, I§11), the ISO says "fedokawaii is installed on this disk, remove the USB and restart" instead of asking again: a firmware that boots the stick twice must not look like a fresh start. **`%post` writes the marker as its last act**: the stick stays in through every reboot of setup's three phases, and a boot back into the ISO half way must not offer to erase a disk that is being finished. A reset inside `%post` leaves no marker and counts as a reset during Anaconda.

That screen is no dead end: `i` leads to the questions and the same erase page, for a real reinstall.

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

**Before the erase, `%pre` proves what Anaconda would otherwise learn only after it** (I§12.10), each failure a refusal page with the disk untouched: the filled kickstart parses strictly (pykickstart, `F45Handler`); both repos answer with metadata, not only the `fedora-45` metalink; every file in `fk-sums` is good, `install.img` above all, since stage 2 goes on reading it from the stick (section 5); and, if a boot test shows its time and memory are acceptable, a `dnf5` dry run of the package set. What is left, a mirror failing in the minutes after that, ends on the failure screen with the disk gone, and he has his backup (T54b).

**The erase.** Holders first, for a disk that has any: `swapoff`, `vgchange -an`, `dmsetup remove`, `mdadm --stop`. `wipefs -a -f` on each partition, deepest first, then on the disk. `udevadm settle`, `blockdev --rereadpt` with retries, `udevadm settle`. Then **it checks its own work**: `lsblk` shows no partition left on that disk and `blkid` no signature. Any step that fails stops on the failure screen, naming the device. Nothing before the confirmation writes to any disk; this acts only on the disk `/tmp/answers.ks` names, and it runs before Anaconda scans anything (`anaconda.py:401`, `reset_storage` later). Read, not booted: backup superblocks and the old table's array may remain on the disk, so "blank" means blank to blkid and blivet, and T57's row is the only proof.

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

Boot line: `inst.stage2=hd:LABEL=<volid> inst.ks=hd:LABEL=<volid>:/ks.cfg inst.text inst.notmux inst.noshell inst.geoloc=0 inst.nosave=input_ks,output_ks console=tty1 rd.retry=30 rhgb quiet …VT_ARGS…`.

The skeleton with `/tmp/answers.ks` filled in (`keyboard --vckeymap=us --xlayouts=us`, `timezone Asia/Dubai --utc`, `network --hostname=…`, `user --name=… --groups=wheel --iscrypted --password=…`, `ignoredisk --only-use=…`, `clearpart … --drives=…`) parses strictly under `F45Handler` too (I§10).

`sshd` is off and the harness's `NOPASSWD` line stays in the harness only: no back door in the product. (`lane-iso`'s `iso/ks.cfg` has no `services` line today, so on a first boot `sshd` runs with Fedora's defaults until setup's step 1.7, after the full update, and `lane-research2` found his address public over IPv6.) `inst.nosave` keeps the hash out of `/root/anaconda-ks.cfg`. T56's test greps the whole installed disk for it, not only `/var/log/anaconda/`.

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

1. Verify the netinst. 2. Build `product.img` and `fedokawaii-boot.img` (`cpio --reproducible`, sorted, `xz --check=crc32`, the only check the kernel's decompressor takes). 3. PSF2 font, padded to exactly 256 glyphs. 4. Rewrite `grub.cfg`: entries, theme, one `initrd` line with two files. 5. `mcopy -o -m` it into the EFI partition image and `xorriso -update` it on the ISO9660 side (`/EFI/BOOT/grub.cfg`, `BOOT.conf`, `boot/grub2/grub.cfg`), all the same file. 6. `xorriso … replay`, `-map` the rest. 7. `.sha256`.

Before step 6, `fk-sums` is made, to go beside `ks.cfg` at the ISO's root: SHA-256 of every file on the ISO9660 side, the netinst's and ours. It lists `images/product.img`, so it cannot sit inside it.

**The stick check.** `%pre` mounts the ISO's device read-only a second time, hashes each file in `fk-sums` with Python's `hashlib`, and shows bytes read on our meter. A file that differs is "this stick is damaged", and then it is true. **It runs on every install, between the confirmation and the erase:** stage 2 reads `install.img` from the stick as it goes, so damage met later would be met with the disk gone. Under a minute even on USB 2, and it leaves the menu's "check this stick" line with little to add (`lane-iso`'s call, which today runs it only from that line). It cannot catch everything: stage 2 is running from the file it checks, so a bad block read earlier than `%pre` kills the boot instead (section 6). What firmware does to the GPT or to the EFI partition is not read at all (I§12.2); the signed files are on the ISO9660 side too, so a damaged `BOOTX64.EFI` is still caught there, and a damaged copy in the EFI partition could not have booted this far.

The stick's bytes are worth comparing once: right after it is written, before any firmware has seen it, by whatever writes it (section 9).

Twice from the same inputs: **the same bytes for the `xorriso` step, proven (I§4)**; steps 2, 3 to be proven in T56. Volume id stays Fedora's: `inst.stage2` and the GRUB `search` depend on it, and nothing else needs ours. The EFI partition has 0.5 MB free: nothing but `grub.cfg` goes there.

**GRUB under Secure Boot:** `theme.txt` draws everything with `image` components and the entries through `--class` icons (`icons/<class>.png`) with an empty title: the words are PNG in Sumi UI ×2, no `loadfont`, no text. `tools/build-art.py` renders them. Unifont (the signed image's only font) is what any GRUB error message will use, and that cannot be helped.

**The installed system** has the same limit: `theme.sh`'s `sumi-*.pf2` will not load under Secure Boot. Nothing changes on his PC (off). On a Secure Boot machine its menu falls back to Unifont, or to invisible words. T56 should make `theme.sh` use the same PNG words, and the test sees it.

## 6. Failure modes, argued against

| A skeptic says | Answer |
|---|---|
| The stick stays in; the firmware boots it again | Marker check, section 3; `reboot --eject` for optical; Anaconda should put Fedora first in the boot order: T57's row sees whether it does |
| Anaconda crashes, or dies early | `%onerror` shows it in our screen with the log's path. A `%pre` that raises or a parse error reaches no `%onerror` (I§11), the VT is locked with no shell, and `anaconda.service` starts next: a second Anaconda, a second `%pre`, the form back as if nothing had happened (I§12.7). **A drop-in in `product.img` turns that unit into the answer:** `Type=oneshot`, `ExecStart=` emptied, then `failed.py`. It can only start when Anaconda has ended without taking the machine down, so every early death lands on one screen, with no watcher to write. `%post` leaves a word in `/tmp`, and with that word there the unit does nothing, so a slow reboot can never flash it. Masking is no option: `anaconda-direct` `Requires` it. Read, not booted: tested with a bad repo URL, a raising `%pre` and a kickstart that cannot parse |
| "This stick is damaged", on a good stick | Fedora's check can say that (I§12.2). Ours reads files, not sectors (section 5). T57: a copy with the three GPT fields changed passes; flipped bytes at several offsets in `install.img` either fail the check or fail the boot, and never reach the erase |
| The stick cannot be read at all | Today: three minutes of splash, then Dracut's raw report and a prompt for a locked root (I§12.9). `rd.retry=30` on the boot line, and a hook in the second initrd, `var/lib/dracut/hooks/emergency/00-fedokawaii.sh`, sourced before that report: plain words on tty1 in the kernel's font (no font of ours exists yet at that point), any key powers off. Read, not booted |
| Stage 2 dies before `%pre` (a bad block in `install.img`) | The splash stays: `plymouth-quit` is masked and nothing has drawn yet. **Left open on purpose**: rare, the kernel's own errors go to tty1 behind the splash, and "check this stick" finds it. Said here so that nobody takes it for covered |
| The disk is not empty, and it is not simple | His has subvolumes, snapshots, nested ones. The erase in `%pre` leaves nothing to walk (section 3). T57: a second install over a finished one |
| Mirrors fail mid-way | Anaconda's own retries; a final failure → `%onerror`. Slow-network run in T57 |
| Mirror content changed between `%pre`'s check and install | Nothing to do but `%onerror`, and now the disk is already gone: the failure screen says so, and he has his backup. Section 3's checks make this window as small as it gets |
| A mirror that hangs instead of failing, or a question nobody can see | **Not covered by any exit:** Anaconda has no timeout on its spokes, and tty1 is behind a locked VT. `progress.py` says so on its page after minutes of log silence; the power button is then the way out. T57: a mirror that drops packets (read, not booted, I§12.10) |
| The failure screen itself | It must say **whether the disk was erased**, in two wordings, from a flag the erase sets. The cause goes on the screen, because logs are in RAM, there is no shell and the only exit is power off: copy them to `/mnt/sysimage` if it is mounted, and include `/tmp/fk-pre.log`. A log's path alone is no use to him (`lane-iso`'s `failed.py` today has one sentence for every case) |
| A reset right after `%post`'s marker | The marker is `%post`'s last act, not Anaconda's: "Copy installation logs" and "Set file contexts" still follow. Such a system says "installed", with contexts never set, under enforcing. First boot runs what that task runs; `i` still reinstalls. T57 row (I§12.10) |
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
- Hardware: **the agents test it in the VM only, and never run it on his real disk.** He does, at the end of the round (T54b): section 10 is what stands between those two facts.

## 8. Tests

### First, in T56, before building the rest (each answers something this lane could not boot to see)

| Experiment | Decides |
|---|---|
| Boot the replayed ISO with a stub `%pre` that opens tty1, quits Plymouth, sets `KD_TEXT`, locks switching, draws, reads a line, with `anaconda-tmux@` and both quit units masked | **Done by `lane-iso`:** tty8 won (I§12.8) |
| `setfont` a 14 × 28 PSF2 of 256 glyphs on `drm` fbcon (the kernel allows up to 64 × 128 and 512 glyphs, `vt.c`), `ESC ] P` for the lacquer, then a screenshot | **Done by `lane-iso`:** on a hidden VT, colours sent again after the switch |
| Second initrd with `script.so` + `sumi`, screenshot at 2 s and at switch-root | **Done by `lane-iso`:** needs `label-freetype.so` too on F45 |
| PNG-only theme with **OVMF secure-boot, enrolled keys** | **Done by `lane-iso`.** T57 keeps `mokutil --sb-state` in the guest |
| `images/product.img` overlay is present in stage 2 | **Done by `lane-iso`** |
| Parse packaging progress from a real run | **Done by `lane-iso`:** `/tmp/syslog` |
| `%pre`'s daemon survives into the installation | **Done by `lane-iso`** |
| `-kmscon` with `@^custom-environment` on F45 | Runs in `lane-iso`'s install; T57 confirms `rpm -q kmscon` says no |
| A damaged `install.img` on a test ISO, at several offsets | **Open.** The check says so, or the boot dies under the splash (section 6 expects nothing better there) |
| `inst.stage2=hd:LABEL=nothing` on a test build | **New.** Our words within 30 s and any key powers off, with the hook of section 6 |
| A drop-in that replaces `anaconda.service` | **New.** Does a raising `%pre` land on `failed.py`, and does a normal install still reboot with no flash of it? (I§12.7) |

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
| "check this stick" on a copy with GPT fields 0x210, 0x220, 0x230 changed | passes: Fedora's own false alarm does not reach us (I§12.2) |
| `updates` unreachable at the confirmation; a kickstart that cannot parse; an unsolvable package set, if the dry run is kept | refused **before the erase**, the disk's bytes unchanged (checksum), the page says why |
| A disk with active LVM, and one with swap | the erase tears them down and checks, or stops on the failure screen naming the device (only Btrfs is tested otherwise) |
| A mirror that drops packets after the erase | the page says there has been no progress; the failure screen says the disk was erased |
| A reset right after `%post`'s marker | "installed" on the next boot of the stick, `i` works, and without the stick the first boot sets contexts |
| **A second install over a finished one:** setup done, `home` split, snapper snapshots, `~/Downloads` and a nested subvolume, then `i` | installs; no old subvolume survives; time recorded. **His exact path** (I§12.3). Every other run starts wiped |
| Right after `%post`, before phase 1 | `rpm -q amd-gpu-firmware realtek-firmware amd-ucode-firmware` all there (I§12.4): no VM needs them, his PC does |
| After the update button brings a new kernel | its entry and `/etc/kernel/cmdline` hold no `console=` (I§12.6) |
| A VM whose firmware starts in another mode than 1080p | the menu in 1080p from `1920x1080,auto` (I§12.5) |
| Mirror unreachable at package step | `%onerror`'s screen with the log's path |
| Two builds | `sha256sum` equal |
| The whole installed disk | no password hash outside `/etc/shadow` |

Screens saved as PNG at menu, each question, progress, restarting, login; both measured with `tools/px.py`. Install time per run.

## 9. What changes in the plan

- **T56**: `%post` seeds `with-theme` and `fedokawaii.conf`; `product.img` masks three units and replaces `anaconda.service` (section 6); the erase in `%pre` (section 3); the stick check by files, `fk-sums` (section 5); drop `lorax`/`mkksiso` and `isomd5sum` from the build-only list (`xorriso` and `mtools` remain); no container or VM needed to build. "Terminus/our console font" → our PSF2. Question TUI in Python, not bash (no `stty`, `tput`, `clear`). `theme.sh` gets PNG words for Secure Boot.
- **`f45-changes.md` line 81**: kmscon is not in the installer's image. `-kmscon` in the kickstart, and the VM harness's kickstart should match when T46 moves it to F45, otherwise harness and product differ.
- **T57**: as section 8; add the rows that are new here.
- **T42/T45**: a marker for "installed", written last by `%post`. If a rollback ever loses it, the only cost is that a booted stick asks again; the erase page still stands in the way.
- **T50**: the Learn piece "installing from the ISO", once T57 has its screens: F11 at power-on on his board, the stick's UEFI line (I§12.4).
- **T54b, a step nobody has yet:** something must write the ISO to a stick. `kawa-carry` backs up and restores, and writes no stick. It belongs in the same "before you wipe" flow: pick a USB disk that is not the backup drive, name its model and size, confirm, write, **compare the bytes at once** (the one moment a sector check means something, I§12.2), and keep `udiskie` off that disk from start to finish: it runs in his session (`configs/home/.config/udiskie/config.yml`), and an automount is one of the causes Fedora lists. He never types `dd`. Also the rehearsal of section 10.

## 10. His PC, his disk

T54b has him wipe this PC and install from this ISO. T57 proves the ISO in VMs. These are the differences that decide whether that is enough.

**Read and fine (I§12.4):** the netinst carries drivers and firmware for his card, iGPU, network chip, NVMe disk and stick. One internal disk, so the form's default is right; a USB backup drive is never offered. His label `fedora_fedokawaii` skips the "already installed" page and goes to the form, whose erase page names the Lexar. Secure Boot off changes nothing. `BootOrder` has only Fedora, so he reaches the stick with F11, and with it left in the machine still boots the installed system.

**What no VM shows:**

| Only on his PC | Why it can differ | Who sees it, and when |
|---|---|---|
| The menu's mode | `1920x1080,auto` asks for 1080p; MSI's firmware has to offer it, as it does for his installed GRUB today (I§12.5) | The rehearsal below |
| Whether MSI's firmware touches the stick | Fedora's check would fail; ours is built not to care (I§12.2) | Not needed any more |
| The splash and first page on amdgpu | Real KMS, two cards, a monitor that re-syncs when 60 Hz becomes 144 Hz: a blank of a second or two is likely, and the first frame after it may differ from `virtio` | The rehearsal |
| The console's cell count | 137 × 38 on 1080p, read at run time, measured only on `virtio` | The rehearsal |
| A card that fails to initialise | Refused as "no graphics" if the check read `/sys/class/drm`. `lane-iso` now reads the PCI class | Done |
| The network chip's link | 2.8 s from bring-up to link in this boot's journal, at 1 Gbps; the check waits 30 s. Nothing expected | The rehearsal |
| A wrong clock | A reset CMOS makes `curl` fail on TLS, read as "no answer from Fedora" | Rare; the words could say so once |

**The rehearsal, before the wipe.** Nothing above needs the install to run. The form writes to no disk until its last page; `installed_disk()` mounts only `ro,rescue=nologreplay`, and on this PC does not even match. So: write the stick, boot it once with F11, look at the menu, the splash and the form, press `F2`, then hold the power button. Two minutes, the disk untouched, and it turns the rows of that table into facts while there is still time to fix one.

**What it cannot show:** the erase on his real NVMe disk, blivet and `efibootmgr` on MSI's firmware, the first boot under `BOOT_ARGS` with firmware from the disk, and whether the machine boots the installed system with the stick left in. Those are seen for the first time at the wipe itself, which is why the backup (T54b) comes first and is proven first. **The rehearsal is the one thing this design asks of him**: main's next review pack can carry it, when the ISO is built from the final tree. Agents still never run it on his disk: this is him, and it stops at the form.

If his session must be back afterwards, nothing has changed: the next boot is his desktop.
