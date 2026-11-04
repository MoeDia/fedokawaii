# Installer ISO research — T55 (round 27): sources, each with what it taught

The design (`.claude/notes/iso-design.md`) cites this file by section. Research lane, branch `lane-research`, 4 Nov 2026.
Grades as in `vm-research.md`: **[P]** primary (upstream, or the object itself), **[R]** a first-hand report, **[C]** opinion.
Nothing was booted: this lane may not touch a VM. What only a boot can answer is listed in the design as T56's first experiments.

## 0. The real F45 netinst, read on 4 Nov 2026 [P]

Downloaded from [releases.json](https://fedoraproject.org/releases.json)'s link, checked against its checksum, opened with `xorriso` and `7z`, nothing mounted.

| Fact | Value |
|---|---|
| File | `Fedora-Server-netinst-x86_64-45-1.4.iso`, 1 272 281 088 bytes, SHA-256 `a1e916f139a05955b943cf183b020780cca9c399b02b8f5ec4354c9e5c1dff1a` (matches `releases.json`) |
| Built with | `.buildstamp`: `Lorax=45.4-1`, `IsFinal=True`, `UUID=202610281944.x86_64`. `ModernizeBootISO` is F46, see §4 |
| Volume id | `Fedora-S-dvd-x86_64-45` |
| Files | `/EFI/BOOT/{BOOTX64,mmx64,grubx64}.efi` + ia32, `grub.cfg` = `BOOT.conf`; `/boot/grub2/grub.cfg`; `/images/eltorito.img`, `install.img` (945 MB), `pxeboot/initrd.img` (277 MB), `pxeboot/vmlinuz`. No `.treeinfo` |
| Boot | El Torito: BIOS `eltorito.img`, UEFI = a hidden appended GPT partition 2 (13.6 MB FAT16, label `ANACONDA`; 0.5 MB free), **which holds its own `grub.cfg`** |
| Menu | `set timeout=60`, Install / Test / Troubleshooting; `linux /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=Fedora-S-dvd-x86_64-45 quiet` |
| Kernel | 7.2.11-300.fc45, signed `Fedora Secure Boot Signer` |
| `install.img` | squashfs, 32 511 files, direct root (no nested `rootfs.img`), Python 3.15 with `termios`, `_curses`, `gi`, `cairo`; no PIL |

### What stage 2 has and lacks [P: its file list]

- **Has:** `bash`, `python3`, `setfont`, `loadkeys`, `chvt`, `tmux`, `agetty`, `plymouth`, `plymouthd`, `gnome-kiosk`, `mutter`, `curl`, `nmcli`, `ip`, `ping`, `lsblk`, `blkid`, `parted`, `sfdisk`, `blockdev`, `mount`, `mkfs.btrfs`, `dnf5`, `rsync`, `tar`, `xz`, `zstd`, `openssl`, `localectl`, `timedatectl`, `hostnamectl`, `efibootmgr`, `mokutil`, `dbus-send`, `journalctl`, `fuser`, `flock`, `sshd`; `libcrypt.so.2`; terminfo `linux`; 249 console fonts in `/usr/lib/kbd/consolefonts`; 689 keymap files; `tzdata.zi`, `zone1970.tab`; Python's `termios`, `fcntl`, `_ctypes`, `_hashlib`.
- **Lacks:** **`kmscon`**, `stty`, `tput`, `clear`, `dialog`, `whiptail`, `openvt`, `setsid`, `nohup`, `timeout`, `getent`, `sha512sum`, `git`, `dracut`, `findfs`, `fbset`.
- Fonts: Noto, Noto Sans CJK, others; nothing of ours.
- Plymouth: `details.so`, `text.so`, `tribar.so`. In the **initrd**: `details.so`, `text.so` only, no renderers, no `script.so`, no `libpng`, no `libdrm`, `plymouthd.defaults` `Theme=bgrt`: **the installer's early boot has no graphical splash at all**.

Correction to `f45-changes.md` line 81 ("kmscon for the ISO's text screens"): kmscon is not in the installer's image. It is in F45's `@core` for installed systems (§7).

## 1. Omarchy's ISO [P: [omacom/omarchy-iso](https://github.com/omacom/omarchy-iso), MIT, branch `quattro`, pushed 4 Nov 2026]

What it does, from its README, `configs/` and `builder/`:

- **Base:** archiso (Arch), with a *pre-built root image*: `omarchy-root.img.zst`, "a zstd-compressed btrfs partition image", written with its own `omarchy-image-write`, then given a fresh filesystem id and grown; the rest from a bundled offline mirror. Nothing fetched at install.
- **Boot:** GRUB `timeout=0`, `timeout_style=hidden`: no menu shown; `plymouthd.conf`: `Theme=omarchy`, `ShowDelay=0`.
- **Questions** ([`configurator`](https://github.com/omacom/omarchy-iso/blob/quattro/configs/airootfs/root/configurator), 1446 lines of bash with `gum`): language, keyboard, timezone, drive + encryption, user. On tty1 by autologin; `.automated_script.sh` exits unless `$(tty) == /dev/tty1`.
- **Console craft:** a Linux console, not a compositor. `echo -en "\e]P01a1b26"…` sets the 16 colours; a patched Terminus (`console-font.py`); "gum's key hints … add nothing to prompts that already say what to do, so every widget leaves them off"; waits for a stable terminal size before drawing.
- **Progress** ([`omarchy-install-dashboard`](https://github.com/omacom/omarchy-iso/blob/quattro/configs/airootfs/usr/local/bin/omarchy-install-dashboard)): "This process is the only owner of the visible install UI. It launches the actual installer as a non-interactive child, sends child output to the support log, renders progress while the child runs, then renders the final installed time + reboot prompt itself." Installer logs go to a file.
- **Safety:** `omarchy-root-image-verify.service` hashes the image at boot: "A bad image makes the install halt before the disk is touched". Minimum 32 GiB.
- **Secure Boot:** the README's only statement: "Turn off Secure Boot and/or TPM in the BIOS". **We can do better**: see §5.
- **Hands-off installs for tests:** a drive labelled `cidata` with the answers skips the wizard. [`omarchy-iso-test`](https://github.com/omacom/omarchy-iso/blob/quattro/bin/omarchy-iso-test): QEMU + OVMF, screenshots collected for review, `--no-network`, fake hardware.
- **Delivery:** `.sig` signature, nightly channel, `latest.json`.

## 2. Anaconda [P: source, [`rhinstaller/anaconda`](https://github.com/rhinstaller/anaconda) branch `fedora-45`, and its `docs/user-guide/boot-options.rst`]

- [`anaconda.py`](https://github.com/rhinstaller/anaconda/blob/fedora-45/anaconda.py): order at start: `find_kickstart` → **`run_pre_scripts(kspath)`** → `parse_kickstart` → `activate_keyboard` → … → `display.setup_display`. So `%pre` runs **before any UI exists**, and a file it writes can still be `%include`d.
- [`scripts.py`](https://github.com/rhinstaller/anaconda/blob/fedora-45/pyanaconda/core/kickstart/scripts.py): `execWithRedirect(script.interp, …, stdout=fp, root=scriptRoot)`: stdout goes to a log; stdin is inherited. A screen in `%pre` must open its own VT.
- Units: [`anaconda-tmux@`](https://github.com/rhinstaller/anaconda/blob/fedora-45/data/systemd/anaconda-tmux@.service) has `ConditionKernelCommandLine=!inst.notmux`; [`anaconda-direct`](https://github.com/rhinstaller/anaconda/blob/fedora-45/data/systemd/anaconda-direct.service) has `ConditionKernelCommandLine=|inst.notmux`, `StandardInput=tty`, `StandardOutput=journal+console`. [`anaconda.target`](https://github.com/rhinstaller/anaconda/blob/fedora-45/data/systemd/anaconda.target) wants `plymouth-quit` and `plymouth-quit-wait`: the splash dies as stage 2 reaches the target.
- `anaconda-generator` (in the image): puts the tmux client on "the real tty for /dev/console" and a shell only on virtual consoles (`hvc0`…), not on tty2.
- `vtActivate(1)` appears only on an early exception and on failed Wayland start or the remote WebUI (`anaconda.py`, `display.py`): in text mode nothing moves the VT away from us during a normal install.
- Boot options: `inst.notmux` "Do not use tmux during install … really meant for non-interactive uses"; `inst.noninteractive`; `inst.noshell`; `inst.waitfornet=<seconds>` "Wait for network connectivity at the beginning of the second stage"; `inst.nosave` (`input_ks`, `output_ks`, `all_ks`, `logs`, `all`); `inst.geoloc=0`; `inst.updates`; `inst.stage2`; `inst.virtiolog`.
- Initrd [`anaconda-lib.sh`, from the image]: `anaconda_auto_updates $repodir/images` unpacks `images/updates.img` and `images/product.img` over stage 2 ("so they'll end up in the location(s) that anaconda expects them"). **This is how our files get into stage 2.**
- Older pattern, still the only documented one for screens in `%pre`: `chvt 6; exec </dev/tty6 >/dev/tty6 2>&1` ([Red Hat](https://access.redhat.com/node/685543), [kickstart-list](https://listman.redhat.com/archives/kickstart-list/2008-April/004434.html)) [R, dated].

## 3. Kickstart [P: [pykickstart docs](https://pykickstart.readthedocs.io/en/latest/kickstart-docs.html)]

- `%pre`: "immediately after the ks.cfg has been parsed and the lang, keyboard, and url options have been processed"; "not run in the chroot"; "If your script spawns a daemon process, you must make sure to close stdout and stderr… the installation will appear hung". Options `--erroronfail`, `--interpreter`, `--log`. Its example generates `/tmp/part-include` for `%include`.
- `text --non-interactive`: "This mode will kill the installation when user interaction will be required."
- `reboot --eject`; `ignoredisk --only-use`; `repo --metalink`; `rootpw --lock`; `user --iscrypted`.
- Both metalinks answer today: `repo=fedora-45` and `repo=updates-released-f45`, HTTP 200 (`curl`, 4 Nov 2026).
- Console font limits in kernel v7.2.13 `drivers/tty/vt/vt.c`: `max_font_width 64`, `max_font_height 128`, `max_font_glyphs 512`.
- **The skeleton in the design parses strictly with pykickstart 3.77 (the version in F45, per `src.fedoraproject.org/rpms/pykickstart/raw/f45/f/sources`), handler `F45Handler`, warnings as errors**: run in scratch on 4 Nov 2026. `module` is gone from F45 (`f45-changes-3nov.md`).
- `%post`: the harness's kickstart (`tools/vm-create.sh`) already proves the layout on the VM (`btrfs none --label=fedora` + `btrfs / --subvol --name=root`).

## 4. Fedora's media tools

- [mkksiso (lorax)](https://weldr.io/lorax/mkksiso.html) [P]: `--ks`, `--add`, `--cmdline`, `--rm-args`, `--replace`, `--updates`, `--volid`. "Since 38.4, root is needed for a fully bootable ISO"; `--skip-mkefiboot` runs as a user but leaves the EFI image's config. Dependencies `xorriso`, `isomd5sum`.
- [Its source](https://github.com/weldr/lorax/blob/master/src/bin/mkksiso) [P]: at heart `xorriso -indev IN -outdev OUT -boot_image any replay`, `-append_partition 2 <guid> efibootimg`, `-update` for configs, `-map` for files, `-alter_date_r b =EPOCH / --` with `SOURCE_DATE_EPOCH`. Root only because `mkefiboot` mounts a loop device.
- [Modernize boot.iso](https://fedoraproject.org/wiki/Changes/ModernizeBootISO) [P]: lorax → image-builder, "Targeted release: Fedora Linux 46", category `ChangeAcceptedF46`, last updated 2026-08-20; "should not change in any functional way"; about 150–200 MiB bigger. Its page does not mention mkksiso; a tool bound to lorax's layout may need a look at F46.
- [livemedia-creator](https://weldr.io/lorax/livemedia-creator.html) [P]: "make live isos, bootable (partitioned) disk images, tarfiles, and filesystem images", from a kickstart, with qemu or `--no-virt`, "the examples all use `sudo`". `image-builder 87` (`f45-changes-3nov.md`). Both build whole media from package sets: no use when an official signed netinst already holds everything.

### A build experiment on this PC, as `dia`, no root, no container (4 Nov 2026) [P]

```
SOURCE_DATE_EPOCH=$E xorriso -indev f45-netinst.iso -outdev out.iso -boot_image any replay \
  -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B esp.img \
  -update grub.cfg /EFI/BOOT/grub.cfg -update grub.cfg /EFI/BOOT/BOOT.conf -map ks.cfg /ks.cfg \
  -alter_date_r b =$E / --
```

- Two runs: **byte-identical** (`031664d2e21e…`, 1 272 315 904 bytes), 1.5 s each from RAM. El Torito BIOS + UEFI, both GPT partitions, volume id and `BOOTX64.EFI` (`351e131d3c4a…`) preserved.
- **The EFI image edited without root:** `touch -d @$E grub.cfg; mcopy -o -m -i esp.img grub.cfg ::/EFI/BOOT/grub.cfg` (`mtools` is already on this PC): two runs two seconds apart, byte-identical (`c42dd885b2f5…`); the rebuilt ISO carries it on partition 2.
- Not tested, by this lane's limit: that it boots. `isomd5sum` is not installed.

## 5. Secure Boot [P]

### The signatures, read from the ISO's files

| File | Signed by | SBAT |
|---|---|---|
| `BOOTX64.EFI` (shim 16.1) | **two signatures: Microsoft Corporation UEFI CA 2011 and Microsoft UEFI CA 2023** | `shim,4`, `shim.fedora 16.1-1` |
| `grubx64.efi` (2.12-81.fc45) | Fedora Secure Boot CA 2020 and 2025 | `grub,5`, `grub.rh,2` |
| `vmlinuz` | Fedora Secure Boot Signer | |

- [Fedora Magazine, 11 Jun 2026](https://fedoramagazine.org/expiration-of-microsoft-secure-boot-keys/): 2011 keys could sign only until end of June 2026; "signed by multiple keys for maximal compatibility"; machines "will continue to boot" unless revoked; edk2-ovmf ships both. [Fedora Discussion](https://discussion.fedoraproject.org/t/updating-the-shim-package-in-fedora-44-16-1-8/194569) [R]: F44's installed shim was 2011-only. So F45's dual signature boots on old and new firmware; a later one-signature shim may not ([fwupd](https://fwupd.github.io/libfwupdplugin/uefi-db.html)).
- Editing `grub.cfg`, adding files or a second initrd breaks no signature: none of them is signed.

### What Fedora's GRUB refuses, from [its source, branch `fedora-45`](https://github.com/rhboot/grub2/blob/fedora-45/grub-core/kern/efi/sb.c)

`shim_lock_verifier_init`: "Files that do not affect secureboot state" skip verification: `LINUX_INITRD`, `PIXMAP`, `CONFIG`, `THEME`, `GRUB_MODULE_LIST`, `LOADENV`… Everything else: `prohibited by secure boot policy`. **`FONT` is not on the list** (commit "kern/efi/sb: Enforce verification of font files", 2022-11-14). So:

- **With Secure Boot on, our `sumi-*.pf2` cannot load, from the ISO or from the installed system.** Only what is inside the signed image can: `grubx64.efi`'s `mods` section holds exactly one font: **"Unifont Regular 16"** (found by its header; `font.c` tries `(memdisk)/fonts/` first).
- Built-in modules (strings in `mods`): `gfxmenu gfxterm png jpeg font all_video efi_gop linux loopback iso9660 fat part_gpt regexp search configfile test echo sleep`. **PNG and themes are allowed.**
- This PC has Secure Boot **off**, which is why nobody has seen it. A theme that keeps its look under Secure Boot draws its words as PNG.
- The initrd is loaded unverified, so a second one is allowed. Fedora's kernel enforces lockdown under Secure Boot, which T56 meets as: unsigned modules (none in `lib/manifest.sh`: no `akmod`, no `dkms`), debugfs (`system/fedokawaii-report` reads it, so that row must expect it), `/dev/port`.

## 6. "The newest stable Fedora at install time"

- [releases.json](https://fedoraproject.org/releases.json) [P]: machine-readable; highest version 45; **it holds "45 Beta" rows beside "45"**, so a parser must drop anything not purely numeric. Fields: version, variant, subvariant, link, sha256, size. Not signed; TLS only.
- [T46's update system] already takes the PC across releases with a VM pre-flight, rollback and the fixer: the same button after install.
- No Anaconda document found promises that an F45 installer can install F46 packages; nobody tests that. Metalink: `repo=fedora-$N` and `repo=updates-released-f$N` ([Fedora's mirror manager](https://mirrors.fedoraproject.org/)).

## 7. What Fedora 45 changes under us [P: `f45-changes-3nov.md`, wiki]

- [Use kmscon as default VT console](https://fedoraproject.org/wiki/Changes/UseKmsconVTConsole): `@core` gains kmscon on fresh installs; `setfont` and `loadkeys` stop working there; "It should be easy to revert, just not install kmscon, and fbcon with getty service will be the default"; "won't affect the installation". An upgraded PC keeps fbcon. **An ISO install would differ from his upgraded PC** unless `%packages` says `-kmscon`.
- Enforced RPM signatures; `/usr/share/dnf5/repos.d`; PAM in `chpasswd`/`newusers` (`f45-changes.md`: "verify (T56)").
- Fedora's [GeoIP](https://geoip.fedoraproject.org/city), Anaconda's own default provider: JSON with `time_zone`; answered `Asia/Dubai` here on 4 Nov 2026.

## 8. Limits of GitHub

[About releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases) [P]: "Each file included in a release must be under 2 GiB." Measured: the netinst 1.19 GiB + the repo as `git archive | xz` 46 MiB (of which `docs/Fedokawaii-Guide.pdf` is 39 MiB raw and leaves in T27). Omarchy's route, an offline root image, would not fit.

## 9. Asked, not found

- Whether `%pre` on a VT behaves on F45 as the source reads: only a boot says.
- How the text-mode progress can be read best (`/tmp/packaging.log`, Anaconda's D-Bus): read it at T56 from a real run.
- The exact path where stage 2 keeps the ISO mounted for `inst.stage2=hd:`: `anaconda-lib.sh` uses `/run/install/repo`; not relied on.

## 10. Second pass, 4 Nov 2026 [P]

- **Console fonts above 256 glyphs cost colours.** Kernel v7.2 `vt.c` `build_attr()`: "if (vc->vc_hi_font_mask == 0x100) a <<= 1;", on a `u8`, so the top background bit is lost; `fbcon.c:328–329` reads the foreground at bit 9 and the background at bit 13, against 8 and 12 for a 256-glyph font. A font above 256 glyphs leaves 16 foregrounds and 8 backgrounds.
- **The cursor's colour is not in the boot palette.** `tools/build-themes.py:55`: the 16 console slots are `ansi0, red, green, yellow, blue, purple, teal, ansi7`, then the bright ones, and `select` (`82241f`, `docs/design-system.md` §4) is none of them. The console's own escape takes any colour into any slot: `ESC ] P n rr gg bb` (`vt.c`, `ESnonstd` → `ESpalette`).
- **`--retain-splash` leaves graphics mode.** Plymouth 24.004.60, `src/main.c`, `quit_splash()`, [Debian's copy of the source](https://sources.debian.org/data/main/p/plymouth/24.004.60-5/src/main.c), the same upstream version as F44's package; freedesktop's GitLab refuses fetching: `ply_terminal_close()` runs only `if (!state->should_retain_splash)`. Fbcon draws nothing in `KD_GRAPHICS`, so the first thing `%pre` does on tty1 is `KDSETMODE KD_TEXT`. Not seen on a boot yet, read only.
- **`VT_LOCKSWITCH` exists for this.** `drivers/tty/vt/vt_ioctl.c:927`: needs `CAP_SYS_TTY_CONFIG`, sets `vt_dont_switch`.
- **tty2 is logind's.** From the F45 `install.img`: `usr/lib/systemd/logind.conf.d/anaconda-shell.conf` has `ReserveVT=2`; `autovt@.service` links to `anaconda-shell@.service`, which has `DefaultInstance=tty2`, `TTYVHangup=yes`, `TTYVTDisallocate=yes`, `ConditionKernelCommandLine=!inst.noshell`. `inst.noshell` keeps it out.
- **`product.img` confirmed for this path.** The initrd's `usr/lib/anaconda-lib.sh`, `anaconda_live_root_dir()` calls `anaconda_auto_updates "$repodir/images"`, which unpacks `product.img` into `/updates`.
- **Answers parse.** The skeleton with a filled-in `answers.ks` (`scripts` in scratch): `F45Handler`, warnings as errors, OK; `excludedList ['kmscon']`, environment `custom-environment`.
- **Wired only is enough for this PC.** `ip -br link`: `enp8s0`, no wireless device in `/sys/class/net`.

## 11. From the independent review, each re-read here before use [P unless marked]

F45's `install.img` and initrd; Anaconda branch `fedora-45`; kernel v7.2.

- **`inst.waitfornet` is too late for us.** `anaconda.py:401` runs `%pre`; `:468–470` waits for the network afterwards. `usr/bin/nm-online` is in the image, so `%pre` waits for itself.
- **`console=` and `nomodeset` are copied to the installed system.** `etc/anaconda/anaconda.conf`, `[Bootloader] preserved_arguments` lists `nomodeset` and `console`; `pyanaconda/modules/storage/bootloader/base.py`, `_preserve_some_boot_args()`. So `console=tty3` would send emergency shells to a hidden VT for good.
- **`inst.notmux` means two Anacondas in turn.** `anaconda.target` wants both `anaconda-direct.service` and `anaconda.service`; `anaconda.service` is `After=anaconda.target` and runs `tmux … start`, whose `tmux.conf:21` is `new-session -d -s anaconda -n main anaconda`. `anaconda-direct` is a oneshot, and a target orders itself after what it wants ([systemd.target(5)](https://www.freedesktop.org/software/systemd/man/latest/systemd.target.html), not re-read today). So when the direct one ends, the tmux one starts, and with the pidfile free it runs `%pre` again. Without `inst.notmux` the direct unit's condition fails and only the tmux one exists, as in a normal install. `anaconda-tmux@.service` is only the client that attaches on the console: mask it and nothing shows.
- **`nomodeset` plus the simpledrm blacklist is no display.** Kernel parameters: "With nomodeset, DRM and fbdev drivers will not load if they could possibly displace the pre-initialized output. Only the system framebuffer will be available for use." `BOOT_ARGS` blacklists simpledrm (`lib/common.sh:448`), and sysfb gives it the only `simple-framebuffer`. The same emptiness awaits any machine whose native driver fails.
- **The media check is invisible.** The initrd's `anaconda-diskroot`: `systemctl start checkisomd5@…`; failure ends in `sleep 43200`. `usr/bin/checkisomd5` is in stage 2, so `%pre` can run it on our screen.
- **`%onerror` misses early deaths.** `pyanaconda/errors.py`: `if not self.ui: raise exn`. `pyanaconda/kickstart.py:325–331`: a parse error prints "The installer will now terminate.", sleeps 10 s, exits.
- **The splash dies with Plymouth. [plausible, read not seen]** `drm_file.c:441`: the last close of a DRM master restores the fbdev client, so the picture ends at plymouthd's exit, not at our first draw. Plymouth's fd escrow is shutdown-only (`plymouth-main.c:2294`).
- **`with-theme`.** `setup.sh:2121`: `[[ -f $STATE_DIR/with-theme ]] || { log "theme not requested …"; return 0; }`; only `fedokawaii.sh:245` writes it.
- **Setup applies the conf's answers.** `setup.sh:607`, `:2906`, `:3502`: `timedatectl set-timezone "$TIMEZONE"`, the last one in `repair`. `fedokawaii.conf`: `TIMEZONE="Asia/Dubai"`, `KB_LAYOUTS="us,ara"` ("the first is also used for keybindings"). `setup.sh:611` keeps a hostname already set; `:125` takes the user from `state/user` first. This one was found checking the review, not in it.
- **Fonts are 256 or 512.** `fbcon.c:2484`: `if (charcount != 256 && charcount != 512) return -EINVAL`.
- **The kernel's xz takes CRC32 or none.** `Documentation/staging/xz.rst`: "use `--check=crc32` or `--check=none` to override the default `--check=crc64`".
- **`vt.default_*` is not in `BOOT_ARGS`.** `theme.sh:372–374` builds `VT_ARGS` from `CONSOLE_PALETTE`.
- **A read-only Btrfs mount writes.** `man 5 btrfs`: "the tree log is replayed even with a read-only mount! To disable that behaviour, mount also with nologreplay."
- **`usr/share/systemd/kbd-model-map`** is in the image.
- Checked, correct, by the reviewer: stage 1 tolerates the missing `%include`; `/updates` reaches stage 2; GRUB's allow-list; `%post` precedes `SetContextsTask`; `inst.nosave`'s gates. No hash leak found.
