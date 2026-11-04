# Gaming VM research — T32 (round 27): sources, each with what it taught

The design (`.claude/notes/vm-design.md`) cites this file by section. Written by the research lane on
branch `lane-research`, 4 Nov 2026. Evidence grades, used on every line:

- **[P]** primary: the vendor, upstream, kernel or the PC itself (a command run here, 4 Nov).
- **[R]** a first-hand report by someone who ran it (forum, gist, issue): true for their machine at best.
- **[C]** community opinion with nothing behind it: never decides anything.

## 0. This PC, read on 4 Nov 2026 (nothing changed; no sudo) [P]

| Fact | Value | Command |
|---|---|---|
| CPU | Ryzen 5 9600X, 6 cores / 12 threads, one CCD, 32 MiB L3, AMD-V; `avic x2avic npt tsc_scale vgif v_vmsave_vmload` | `lscpu`, `/proc/cpuinfo` |
| RAM | 30 GiB usable | `free -h` |
| Board / BIOS | MSI PRO B650M-B (MS-7E28), BIOS A.J3 of 2026-09-07 | `/sys/class/dmi/id/*` |
| dGPU | 03:00.0 Navi 44 `1002:7590`, Gigabyte `1458:2429`, PCIe 5.0 x16 running at 32 GT/s x16; 16 GiB VRAM (`mem_info_vram_total` 17095983104) | `lspci`, sysfs |
| dGPU audio | 03:00.1 `1002:ab40`, no reset method at all (empty `reset_method`) | sysfs |
| dGPU reset | `reset_method` = **bus** only: no FLR | sysfs |
| dGPU BARs | BAR0 16 GiB (at `0xf800000000`), BAR2 256 MiB; `resource0_resize` `0x7f00` (256 MiB…16 GiB), `resource2_resize` `0x1fe` (2…256 MiB): Resizable BAR is on and at its maximum | sysfs |
| dGPU bridges | 01:00.0 upstream, 02:00.0 downstream, in the card (Navi switch), groups 12 and 13; root port 00:01.1 group 1 | `/sys/kernel/iommu_groups` |
| IOMMU groups | 39 groups; dGPU alone in 14, its audio alone in 15 (the ACS on this board splits them), nothing else shares | same |
| iGPU | 15:00.0 Granite Ridge Radeon 610M `1002:13c0`, alone in group 32; audio 15:00.1 group 33; 512 MiB carved from RAM; `boot_vga=0` | sysfs |
| USB | 13:00.0 chipset (usb1/2) group 30 **shared with bridge 06:0c.0**; 15:00.3 (usb3/4) alone group 35; 15:00.4 (usb5/6) alone group 36; 16:00.0 USB 2 (usb7) alone group 38 | sysfs |
| USB devices | usb1: TP-Link UB500 Bluetooth, MSI Mystic Light `0db0:0076`, keyboard `1a2c:4184`. usb5: keyboard `258a:0049`, Logitech receiver `046d:c53f`. usb3, usb4, usb6, usb7: empty | `lsusb -t` |
| Connectors | dGPU card0: DP-1, DP-2 disconnected, **HDMI-A-1 connected** (the LG). iGPU card1: DP-3, DP-4, DP-5 disconnected, **HDMI-A-2 disconnected** | sysfs |
| Boot VGA | dGPU `boot_vga=1`, iGPU 0 | sysfs |
| KVM | `/dev/kvm` 0666, `kvm_amd.nested=1`, `avic=Y`; `/dev/vfio/vfio` present; hugepage sizes 2 MiB and 1 GiB | sysfs |
| Secure Boot | off (`SecureBoot-*` byte 0) | efivars |
| Virtualisation stack | libvirt 12.0.0, qemu-kvm 10.2.2, edk2-ovmf 20260812, swtpm 0.10.2; `virtio-win` not installed; user `dia` not in a `libvirt` group (session VMs) | `rpm -q`, `id` |
| Disk | 929 GiB Btrfs, 766 GiB free; `~/VM` its own subvolume (harness 86 GiB) | `df`, ledger r27-5 |

**The second cable is not in yet**: T06's notice asked for it, sysfs shows HDMI-A-2 and both DP ports of the
dGPU disconnected. Nothing on the PC can test the switch or the reset until it is.

## 1. CS2, VAC and VMs

### What Valve itself says [P]

- [Steam Support: Disconnected by VAC: You cannot play on secure servers](https://help.steampowered.com/en/faqs/view/22C0-03D0-AE4B-04E8)
  (article version 8, last changed **2026-01-23**, read from the page's own data on 4 Nov 2026). Word for word:
  "This error is caused by third party software interfering with your game or Steam." and "There are a number of
  common software conflicts that can cause this error. If you are running any of the following software, please
  disable it while playing: CCleaner, Powershell, Cheat Engine, IObit Start Menu 8, DLL Injectors, **Hypervisors**,
  Steam Idlers". Also: "Kernel integrity checks, kernel debugging, and Data Execution Prevention (DEP) must be set
  to default to play on VAC secured servers." It is a **disconnect from secure servers, not a ban**, in this
  article. It does not say whether a guest under a hypervisor counts, or how the check works.
- [Steam Support: Valve Anti-Cheat (VAC) System](https://help.steampowered.com/en/faqs/view/571A-97DA-70E9-FF74)
  (last changed 2021-07-12): "VAC bans are permanent, non-negotiable, and cannot be removed by Steam Support. If a
  VAC ban is determined to have been issued incorrectly, it will automatically be removed." "The VAC system
  reliably detects cheats using their cheat signatures." "The following will not trigger a VAC ban: System hardware
  configurations. Updated system drivers, such as video card drivers."
- Steam Support's reply to one player, quoted in a [Steam thread of March 2017](https://steamcommunity.com/discussions/forum/9/135510393198367927/?ctp=5):
  "Your recent disconnects by VAC have been caused by running a KVM hypervisor alongside CS:GO." and to "disable
  this software while playing CS:GO to avoid being kicked moving forward". The only Valve wording that names KVM;
  nine years old, CS:GO, relayed by the player [R of a P].
- Nothing else found: no Valve page or statement on CS2 specifically in a VM (searches of 4 Nov 2026, four queries).

### What players report

- [R] [False positive ban after playing in a VM](https://steamcommunity.com/app/730/discussions/0/4039228198241213867/)
  (25 Nov 2023, CS2 deathmatch and casual, libvirt KVM + NVIDIA passthrough on Ubuntu, XML with a spoofed
  `vendor_id`, `host-model`): banned, "I GOT UNBANNED" on 6 Dec 2023, no Valve reason given.
- [R] [CS2 on VMware Workstation](https://steamcommunity.com/app/730/discussions/0/594021171629935711/) (23 Apr 2025):
  a player says "I play in a VM. You're fine" and that their libvirt setup has run "for quite some time".
- [R] [Disconnected to VAC server with unRAID KVM](https://steamcommunity.com/app/730/discussions/0/135510669595551654)
  (2017, CS:GO): disconnects with PCI passthrough under KVM; the only fix offered is removing the hypervisor.
- [R] [CachyOS RX 9070 thread](https://discuss.cachyos.org/t/vfio-pci-core-sriov-configure-null-pointer-dereference-with-amd-radeon-rx-9070-navi-48-1002-7550-on-vfio-passthrough/28545)
  (Sep 2026): the reporter stopped using their VM "mainly because an anti-cheat detected the VM" (the game not named).
- [C] Steam threads ([Hyper-V VM VAC](https://steamcommunity.com/app/730/discussions/0/4637111882089515924/),
  [KVM and VAC 2018](https://steamcommunity.com/discussions/forum/1/1696046342872491643)) repeat "VAC does not
  like it" or "fine" without evidence.
- Third-party competitive platforms are stricter. [FACEIT's own article](https://support.faceit.com/hc/en-us/articles/9394666828188)
  describes a kernel-mode driver. No page of theirs read so far allows VMs. To be checked before any claim.

Checked for the design: the claim "VAC disconnects a guest" stands on the 2017 Support reply and the FAQ's word
"Hypervisors"; the claim "it works" stands on one 2025 player. Neither is proof for this PC in November 2026. CS2's
own store page lists "SteamOS + Linux" with a native client and "VAC (Valve Anti-Cheat)"
([store page](https://store.steampowered.com/app/730/CounterStrike_2/)) [P]: the one documented way to play CS2 under
Linux without a hypervisor, and the opposite of the owner's "gaming out of the host", so an option to name, not to build.

## 2. RDNA4 reset behaviour under passthrough

No AMD or kernel document says what a Navi 44 does after a guest. The nearest primary source is the amdgpu tracker,
read through its API on 4 Nov 2026 (`gitlab.freedesktop.org/drm/amd`, issues and comment threads).

### The amdgpu tracker [P for the developers' words, R for the reporters']

- [#5447](https://gitlab.freedesktop.org/drm/amd/-/work_items/5447) (closed; Navi 48, Navi 32 too): after a **Windows**
  guest, amdgpu cannot re-probe: it reads the IP-discovery location from `DRIVER_SCRATCH_0/1/2`, which the Windows
  driver leaves filled with another meaning ("the existing usage from Windows side is missed", lijo, AMD, 13 Jul 2026).
  The reporter: worked on 7.0.12 "dozens of cycles", broke by 7.1.2; `d35617ef` turned the BUG_ON into a clean error.
  A reader showed the scratch values survive until the host is **powered off** and that only Windows writes them.
  Fix: "drm/amdgpu: Prefer default discovery offset" (Lijo Lazar, 2026-08-12).
  **Checked in the source of v7.2.13, this PC's kernel:** `amdgpu_discovery.c` now tries the default offset first and
  uses the scratch registers only when no valid signature is there; `amdgpu_device_mm_access` returns an error instead
  of the BUG_ON. So the failure every July report shows is fixed in our kernel; nobody has reported the rebind on it yet.
- [#5644](https://gitlab.freedesktop.org/drm/amd/-/work_items/5644) (open, 17 Aug 2026, Fedora 44, kernel 7.1.8, **QEMU 10.2.2,
  libvirt 12.0.0, MSI board**, RX 9070 XT): after a guest "the GPU's MMIO register block returns all zeros"; bus reset,
  remove + rescan, MODE1, BIOS options all fail; "Only a firmware POST at cold boot restores it"; a second guest also
  fails. "A bare vfio-pci bind/unbind cycle with no guest started re-initializes amdgpu perfectly." Its failing offset
  (`pos=0x22a02aa8a0`) is the same pattern as #5447, on a kernel without the August fix, so #5644 may be the same bug
  or may be worse. No developer has answered it. The reader cannot tell which until 7.2 is tested.
- [#5446](https://gitlab.freedesktop.org/drm/amd/-/work_items/5446) (open, 3 Jul 2026): `amdgpu_driver_release_kms()` clears the PCI
  drvdata at the last `drm_dev_put`. If **any process still holds the DRM node at unbind** (a GPU monitor, a compositor),
  the late release wipes vfio-pci's drvdata; vfio then oopses on unbind or runtime PM, the oops holds the device lock,
  and "When libvirt is the caller (qemu hook), libvirtd deadlocks until reboot". **Still present in v7.2.13:**
  `pci_set_drvdata(adev->pdev, NULL)` at `amdgpu_kms.c:1609`. It looks like the same crash as
  [the CachyOS RX 9070 report](https://discuss.cachyos.org/t/vfio-pci-core-sriov-configure-null-pointer-dereference-with-amd-radeon-rx-9070-navi-48-1002-7550-on-vfio-passthrough/28545)
  (7.0.1, NULL in `vfio_pci_core_sriov_configure`), which was cured by stopping the display manager that held amdgpu.
- [#4366](https://gitlab.freedesktop.org/drm/amd/-/work_items/4366) (open, Jun 2025, 6.14/6.15): rebind fails after a VM, reboot needed.
- [#4951](https://gitlab.freedesktop.org/drm/amd/-/work_items/4951) (open, Feb 2026): root port falls from 32 to 16 GT/s the moment a
  Linux guest loads amdgpu; only a host reboot restores it. Not reported for Windows guests. To measure after each cycle.
- [#5551](https://gitlab.freedesktop.org/drm/amd/-/work_items/5551) and [#4924](https://gitlab.freedesktop.org/drm/amd/-/work_items/4924) (Navi 31/33):
  rebind fails with -EEXIST on stale sysfs files after unbind. [#6076](https://gitlab.freedesktop.org/drm/amd/-/work_items/6076)
  (Navi 23, 7.2.10, 1 Nov 2026): a card handed to VFIO from runtime suspend fails to recover: wake it before the handoff.
  [#5976](https://gitlab.freedesktop.org/drm/amd/-/work_items/5976): a Raphael iGPU passed through needs amdgpu's MODE2 between guests.
- [#5380](https://gitlab.freedesktop.org/drm/amd/-/work_items/5380) (open, **RX 9060 XT on DisplayPort**, Fedora 44): a blank screen when
  a mode needs ODM combine, seen at 2560x1440@180 and with FreeSync at 165 Hz (`dc_status:13`), fix "merged and on its way
  upstream" (James_lin, AMD, 4 Nov 2026). 1080p144 needs no ODM by that reasoning; it matters only if Linux ever lights the DP.
- [#6062](https://gitlab.freedesktop.org/drm/amd/-/work_items/6062) (open, **RX 9060 XT**, 30 Oct 2026, kernels 7.2.11, 7.3): on a *static* screen
  all cores stall up to ~65 ms in `dm_ism_sso_delayed_work_func → dmub_srv_wait_for_idle`, heard as audio glitches and
  mouse hitches; not on 6.18. **Not about VMs, but about this card on this kernel series**: see `lane-research.md`.
- [vendor-reset](https://github.com/gnif/vendor-reset) lists Polaris, Vega, Navi 10/12/14 only: no Navi 2x, 3x or 4x. Not an answer. [P]

### Reports on the card family [R]

| Source | Card, kernel | What they saw |
|---|---|---|
| [Proxmox, D3 thread](https://forum.proxmox.com/threads/gpu-passthrough-for-windows-11-not-working-kvm-vfio-unable-to-power-on-device-stuck-in-d3.166833/) (uzumo, 2025) | 9070/9070 XT, 6.14+ | "months of stable use": amdgpu bound while the VM is off, vfio-pci while on; hook: unbind amdgpu, `resource2_resize`, and at stop unbind vfio, bind amdgpu; `disable_idle_d3=1` makes it worse; no vBIOS file. Confirmed by two others in Oct 2025, failed for one in Dec 2025. Its VM clears the hypervisor bit (`-hypervisor`) |
| [Proxmox hookscript thread](https://forum.proxmox.com/threads/amd-gpu-passthrough-reset-hookscript-that-works-through-guest-shutdowns.177138/) (Dec 2025) | **9060 XT** and 9070 XT, Win 11 | uzumo ran the script on both: both "booted next time" |
| [Proxmox, RX 9060 XT](https://forum.proxmox.com/threads/gpu-passthrough-error.178089/) (Dec 2025) | **9060 XT** `1002:7590`, 03:00.0 | `reset` write "Inappropriate ioctl", "stuck in D3", IRQ assertion after a stop/start without host reboot; "fixed" with a vendor-reset fork with the ID added, the assertion remained |
| [Unraid, RX 9060 XT](https://forums.unraid.net/topic/200320-trying-to-passthough-amd-radeon-rx-9060-xt-to-windows-11/) (Aug 2026) | **9060 XT**, only GPU, vfio at boot | "AMD Vdisplay" instead of the monitor, glitchy picture; unanswered |
| [L1T, 7.2-rc3 on Fedora 44](https://forum.level1techs.com/t/9070xt-passthrough-on-latest-kernels-improvements/252915) (Jul–Aug 2026) | 9070 XT | "Still getting AMD reset bug"; a suspend-to-RAM cycle (`rtcwake -m mem -s 5`) in the hook "fully reset" it. A second poster: the card breaks if amdgpu was ever loaded; the opposite of most |
| [Proxmox, reset bug](https://forum.proxmox.com/threads/amd-radeon-gpu-passthrough-infamous-reset-bug.186112/) (Sep–Oct 2026) | 9070 XT, custom kernel | binding amdgpu "successful only randomly"; a shutdown from inside Windows hangs the host in most cases, sometimes reboots it; without rebinding the host hangs 9 times in 10; blocking every reset leaves no GOP until the login screen |
| [Gist, CachyOS 7.0](https://gist.github.com/PhialsBasement/c34e908352bd2e8a49197edc70df2d94) (Oct 2026) | 9070 XT | "no reset bug", resets cleanly "on kernel ≥ 6.13"; never pre-bind vfio at boot; BAR2 to 8 MB or Code 43; its section 9 is "Anti-detection hardening": **not to be copied** |
| [L1T working thread](https://forum.level1techs.com/t/vfio-pass-through-working-on-9070xt/227194) (Mar–Jun 2025) | 9070 XT | kernel-dependent; 6.14.2 broke and 6.14.0 worked ([bug 220010](https://bugzilla.kernel.org/show_bug.cgi?id=220010), a reset-method check, fixed for 6.16); live-attaching after guest boot worked for one |

Reading: the *order* amdgpu-first, vfio only while running, rebind after stopping is what nearly every working report
does. Whether it survives on 7.2 with a Navi 44 is unknown; three sources report host hangs. Only a test on this PC
answers it, and that test can hang the PC.

## 3. The Windows driver and the hypervisor

- [gnif, Looking Glass's author: AMD Radeon 7000 VFIO discovery](https://forum.level1techs.com/t/amd-radeon-7000-series-vfio-discovery-amd-vdisplay/208307)
  (10 Mar 2024) [R, the most credible]: under a VM an RDNA3 GPU "disables all its physical outputs" and exposes "AMD
  vDisplay", "by default this device allows 60Hz up to 3840x2160". "the common consensus to get an output from this
  generation in a VM is to hide the kvm leaf and set a random vendor_id". No AMD confirmation in the thread. The 6000 series does not do this.
- [Arch wiki, Video card driver virtualisation detection](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Video_card_driver_virtualisation_detection):
  "Video card drivers by AMD incorporate very basic virtual machine detection targeting Hyper-V extensions", a black
  screen; the answer given is a custom Hyper-V `vendor_id`. [R, curated]
- [WindowsKVM (9070 XT, Fedora 45 Rawhide, 7.0)](https://github.com/serialexperimentslainnnn/WindowsKVM) [R]: without hiding, "AMD vDisplay", 60–75 Hz on
  a 165 Hz panel and no FreeSync; `kvm hidden` + `vendor_id` stop the vDisplay, and it also spoofs SMBIOS "so the driver
  thinks it's bare metal" for native refresh and FreeSync.
- [NoirCatto (9070 XT, X870E, Win 11 25H2)](https://github.com/NoirCatto/AmdGpuPassthrough) [R]: a corrupted picture until `vendor_id` + `kvm hidden`.
- [L1T: BuzzBumbleBee's XML](https://forum.level1techs.com/t/vfio-pass-through-working-on-9070xt/227194) (Mar 2025) [R]: `vendor_id` + `kvm hidden`,
  `host-passthrough` + `topoext`, **no** clearing of the hypervisor bit, Cyberpunk stable on the physical display. The only
  report found with the bit left on; no refresh rate given. Nobody reports a working physical display with nothing hidden.
- [#5644 above] "SMBIOS spoofed so the guest driver does not detect virtualization" on the same stack as ours.
- [QEMU: Hyper-V enlightenments](https://www.qemu.org/docs/master/system/i386/hyperv.html) [P]: `hv-vendor-id` changes CPUID 0x40000000;
  "According to the specification, guests shouldn't use this information and it is unknown if there is a Windows version which acts differently."
- [libvirt: hypervisor features](https://libvirt.org/formatdomain.html#hypervisor-features) [P]: `<kvm><hidden state='on'/>` "Hide the KVM hypervisor from
  standard MSR based discovery" (since 1.2.8); `<vendor_id>` since 1.3.3; `<hyperv mode='passthrough'>` since 8.0.0, `host-model` since 11.9.0.

These three levers are different in kind. **`vendor_id` and `kvm hidden` change names; the CPUID hypervisor bit stays on and
Windows should still say "Virtual machine: Yes" (the gist's check read the other way; T33 confirms it).** Clearing the bit (`-hypervisor`), spoofing SMBIOS, MAC OUI, ACPI ids or
`ucode-rev` make Windows believe it is bare metal: that is what a cheat loader does, whatever the reason.

## 4. Large BARs and the firmware

- [Kernel ABI, resourceN_resize](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/ABI/testing/sysfs-bus-pci) [P]: writing the bit
  number N sets 2^(N+20) bytes, "all PCI drivers must be unbound from the device". So `echo 3` = 8 MiB, `echo 8` = 256 MiB. The
  reports disagree: 3 (gist, BuzzBumbleBee) against 8 (uzumo, jce), and #4366 used 3. This PC's card: BAR2 now 256 MiB (bit 8), BAR0 16 GiB (bit 14).
- [Arch wiki: Code 43 with Resizable BAR](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Code_43_while_Resizable_Bar_is_turned_on_in_the_bios), and [Proxmox, July 2026](https://forum.proxmox.com/threads/proxmox-9-1-9-9-2-4-broke-vfio-passthrough-to-windows-11-guest.184999/) [R]: a 6650 XT gave Code 43 until Resizable BAR went off in the BIOS.
- [QEMU commit b5048a4c "vfio/pci: Static Resizable BAR capability"](https://qemu.googlesource.com/qemu/+/b5048a4cbfa0362abc720b5198fe9a35441bf5fe) [P]: the guest
  sees the *current* BAR size, read-only: what the host set before starting is what Windows gets; Adrenalin reports SAM with it.
- [OVMF's 64-bit aperture, edk2/libvirt thread](https://lists.libvirt.org/archives/list/devel@lists.libvirt.org/thread/3EULENHU75HRFFP3ESYURFVZFXFG6KDU/) [P, dated]: default 32 GiB, `opt/ovmf/X-PciMmio64Mb` (an unstable "X-" knob) raises it, which libvirt can pass only as a raw arg or `<sysinfo type='fwcfg'>`.
  [`<maxphysaddr mode='passthrough'/>`](https://libvirt.org/formatdomain.html#cpu-model-and-topology) (since 8.7.0) gives the guest the host's address width. 16 GiB + 256 MiB fits in the default, so no knob until a test says otherwise.

## 5. libvirt and QEMU facts the XML rests on [P]

- [Hooks](https://libvirt.org/hooks.html): `/etc/libvirt/hooks/qemu` and, since 6.5.0, `qemu.d/`; `prepare begin`, `start begin`, `started begin`, `stopped end`,
  `release end <reason>`. "A hook script must not call back into libvirt". Non-zero at start stops the guest; synchronous; a script added while the daemon runs is not used until its next start.
- [Domain XML](https://libvirt.org/formatdomain.html): `<sound model='ich9'>`; `virtio` sound since 10.4.0 with QEMU 8.2; [PipeWire backend](https://libvirt.org/formatdomain.html#pipewire-audio-backend) with `runtimeDir` "useful when a domain under qemu:///system wants to use session pipewire daemon"; [evdev input](https://libvirt.org/formatdomain.html#input-devices) with `grab='all' repeat='on' grabToggle='ctrl-ctrl'` (since 7.4.0, 7.6.0); `<memballoon model='none'/>`; `<smm>`; firmware features `secure-boot`, `enrolled-keys`.
- [QEMU virtio-sound](https://www.qemu.org/docs/master/system/devices/virtio/virtio-snd.html) names only Linux guests. **[kvm-guest-drivers-windows](https://github.com/virtio-win/kvm-guest-drivers-windows) has no sound driver** (folders on 4 Nov 2026: Balloon NetKVM fwcfg ivshmem pciserial pvpanic stdvga viocrypt viofs viogpu vioinput viomem viorng vioscsi vioserial viosock viostor). T33's "virtio-sound" cannot work on Windows.
- **`virtio-win` is not a Fedora package** (`packages.fedoraproject.org/pkgs/virtio-win` 404). [Fedora's own doc](https://docs.fedoraproject.org/en-US/quick-docs/creating-windows-virtual-machines-using-virtio-drivers/): "Fedora cannot ship Windows virtIO drivers because they cannot be built automatically as part of Fedora's build system". It lives at [fedorapeople](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/) (0.1.302 today); its [repo file](https://fedorapeople.org/groups/virt/virtio-win/virtio-win.repo) has `gpgcheck=0`, which Fedora 45's enforced RPM signatures refuse (`f45-changes-3nov.md` item 5). Take the ISO, pinned by checksum, into the VM's folder.
- Firmware on this PC: `/usr/share/qemu/firmware/30-edk2-ovmf-4m-qcow2-x64-sb-enrolled.json` → `OVMF_CODE_4M.secboot.qcow2` + `OVMF_VARS_4M.secboot.qcow2`, `enrolled-keys`, `requires-smm`, `pc-q35-*`. `qemu-audio-pipewire`, `virtiofsd`, `qemu-device-usb-host`, `swtpm-tools` are installed.
- Fedora 45 moves QEMU 10.2.2 → 11.1.3, libvirt 12.0.0 → 12.6.0; edk2 and swtpm unchanged (`f45-changes-3nov.md`). The gist's QEMU ≥ 11.0.1 refusal does not reach this card: §10.5.
- [Kernel VFIO](https://docs.kernel.org/driver-api/vfio.html): when a group holds several devices, "each will need to be bound to a VFIO driver before operations on the VFIO group are allowed"; the guide's bind is unbind + `new_id`; [`driver_override`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/ABI/testing/sysfs-bus-pci): "When specified, only a driver with a name matching the value written to driver_override will have an opportunity to bind", and it does not unbind by itself. `reset_method`: "Writing an empty string disables the ability to reset the device."
- [Fedora: Virtualization, getting started](https://docs.fedoraproject.org/en-US/quick-docs/virtualization-getting-started/): the Fedora guide; nothing on passthrough.
- [Arch wiki, PCI passthrough via OVMF](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF) [R, curated]: `vcpupin`/`emulatorpin`/`iothreadpin` layout, dynamic isolation with `systemctl set-property --runtime -- user.slice AllowedCPUs=…` (and `system.slice`, `init.scope`), audio via `runtimeDir` plus running QEMU as the desktop user, THP "allocated up front" with VFIO, dynamic hugepages section marked disputed.

## 6. Windows

- [Release information](https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information) (28 Oct 2026) [P]: **26H2** GA 2026-09-29, build 26300, Home/Pro serviced to 2028-10-10; 25H2 to 2027-10-12; 26H1 is only for new devices.
- Unattended [P]: [`LocalAccounts`](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-useraccounts-localaccounts) (oobeSystem) and [`HideOnlineAccountScreens`](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-oobe-hideonlineaccountscreens) are documented answer-file settings. Microsoft's October 2025 Insider note removes the *command-line* routes ("removing known mechanisms for creating a local account in the Windows Setup experience", [PCWorld quoting it](https://www.pcworld.com/article/2932975/microsoft-kills-two-more-ways-to-install-windows-11-with-local-accounts.html), `oobe\bypassnro`, `ms-cxh:localonly`), not the answer file. [Schneegans' generator](https://schneegans.de/windows/unattend-generator/) (MIT, updated 25 Oct 2026) lists 26H2 with local accounts [R]: a reference to read, not a dependency.
- Debloat: [`RemoveDefaultMicrosoftStorePackages`](https://support.microsoft.com/en-us/servicing/os/windows/docs/2025/08/policy-based-removal-of-pre-installed-microsoft-store-apps) is Enterprise and Education only [P]. On Home/Pro the documented tool is `Remove-AppxProvisionedPackage` (the [DISM module](https://learn.microsoft.com/en-us/powershell/module/dism/remove-appxprovisionedpackage)). LTSC needs a volume licence; tiny11 and the like are unofficial images, excluded by the owner's rule.
- [Options to optimize gaming performance in Windows 11](https://eus.prod.support.services.microsoft.com/en-us/windows/options-to-optimize-gaming-performance-in-windows-11-a255f612-2949-4373-a566-ff6f3f474613) [P]: "a performance impact with memory integrity and VMP on in some scenarios", with the toggle to turn each off and the warning about reduced protection.
- [WinGet](https://learn.microsoft.com/en-us/windows/package-manager/winget/) [P]: not available until after the first login, an asynchronous registration; `Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe` forces it.
- The ISO: [Fido](https://github.com/pbatard/Fido) (GPL-3, by Rufus's author, 26H2 added 30 Sep 2026, pushed 3 Nov 2026) scripts Microsoft's own download page, in PowerShell; [Mido](https://github.com/ElliotKillick/Mido) stopped in May 2024. Or the owner's download from [Microsoft's page](https://www.microsoft.com/software-download/windows11). The ISO's `sources/license/` carries the terms in force.
- Licence: the terms in Microsoft's own words are in §10.7. The ISO's `sources/license/` carries the text that applies to his copy: T33 reads it.
- [PresentMon v2.6.0](https://github.com/GameTechDev/PresentMon) (21 Sep 2026) [P]: frame times inside the guest.

## 7. Display: the monitor, the wiring, the alternative

### This monitor, read over DDC on 4 Nov 2026, reads only [P]

`ddcutil 3.0.2 --bus 5 --skip-ddc-checks --disable-dynamic-sleep --sleep-multiplier 2`. **T38's "capabilities failed" is cured by the sleep multiplier.** The string:

```
(prot(monitor)type(lcd)model(FALCON)cmds(01 02 03 07 0C 4E F3 E3)vcp(02 04 05 08 0B 0C 10 12 14(01 04 05 06 07 08 0A 0B)
16 18 1A 6C 6E 70 AC AE B6 C0 C6 C8 C9 CA CC(00 02 03 04 05 08 09 0A 0D) D6(01 02 04) DC(00 01 02 03 04) DF 60(01 03) 62 8D FF)
mswhql(1)mccs_ver(2.0)asset_eep(32)mpu_ver(01))
```

- Controller Novatek (`c8`), firmware 3.36 (`c9`), 143.90 Hz now (`ae`). EDID: `GSM 0x5cdd`, 2025, "LG ULTRAGEAR", range 48–144 Hz, H 30–200 kHz, 350 MHz.
- **`60` lists only `01` and `03`** (VGA-1, DVI-1 in MCCS terms): the monitor has neither. `getvcp 60` answers `sl=0x01` while it shows HDMI. The real DP and HDMI codes are not advertised.
- `getvcp f4`: `mh=ff ml=ff sh=00 sl=06`, the same with `--i2c-source-addr x50`. `f4` is not in the capabilities.

### What others found [R unless marked]

- `man ddcutil` (3.0.2, this PC) [P]: `--i2c-source-addr` "has been found to enable access some control functions when using some displays, particularly from LG". rockowitz in [#163](https://github.com/rockowitz/ddcutil/issues/163): "Some monitors will respond to DDC requests only on the currently selected input, others are responsive on any input."
- [ddcutil #100](https://github.com/rockowitz/ddcutil/issues/100), LG 29UM69G: `getvcp 60` always 0, `setvcp 60` just blinks; brightness works over a non-active input, "Input however does nothing".
- [monitorinputwizzard](https://github.com/lunat1q/monitorinputwizzard): LG UltraGear panels (27GN800) "silently ignore VCP `0x60` entirely"; input lives on `0xF4` through source `0x50`: DP 0xD0, HDMI 0x90. Those are other controllers: this one is a Novatek "FALCON", so nothing carries over.
- LG's [27GL650F-B manual](https://www.manualowl.com/m/LG/27GL650F-B/Manual/615320?page=27): "Auto Input Switch": "display will automatically switch to new input when connected" (another model). The 24G411A manual was not readable from here (two copies refused, `lg.com/us` 403).

### Connections and the kernel

- T06: LG has one DP 1.4, one HDMI 2.0; the board shows HDMI and VGA, no DP. Host on board HDMI, card's DP to the LG.
- [wlroots env_vars](https://gitlab.freedesktop.org/wlroots/wlroots/-/blob/master/docs/env_vars.md) [P]: `WLR_DRM_DEVICES` is colon-separated, so a `by-path` name (it has colons) cannot be used: pass `/dev/dri/cardN`, resolved from the PCI address at each start. `system/start-dwl` picks by largest VRAM today.
- [Kernel modedb](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/fb/modedb.rst) [P]: `video=<conn>:d` disables a connector for the console.
- MSI's AM5 BIOS offers primary display PEG or IGD: MSI's own guide, §10.1. The dGPU is `boot_vga=1`, so firmware, GRUB and the text console draw on it today.

### Looking Glass [P: its repo's docs, master, 7 Oct 2026]

- Newest *release* is [B7, 6 Mar 2025](https://github.com/gnif/LookingGlass/releases); the docs now describe an **IDD** (Windows indirect display driver) that "creates a virtual monitor" and needs no physical output or dummy plug, with its own "direct input driver" ([requirements.rst](https://github.com/gnif/LookingGlass/blob/master/doc/requirements.rst), [install_idd.rst](https://github.com/gnif/LookingGlass/blob/master/doc/install_idd.rst)).
- KVMFR (an out-of-tree module) "is recommended and is required for direct GPU imports"; "at least six CPU cores with twelve hardware threads", "Reserve at least two physical CPU cores, or four threads, for Linux"; DMA-BUF import "is particularly important for integrated GPUs, which already share memory bandwidth with the CPU".
- [FAQ](https://github.com/gnif/LookingGlass/blob/master/doc/faq.rst): frames in shared memory, no video codec; no latency number, its [performance page](https://github.com/gnif/LookingGlass/blob/master/doc/performance.rst) shows how to measure it (PHOTON via `wp_presentation`). Its docs say nothing about anti-cheat.

## 8. Host needs on the iGPU [P: this PC]

`vainfo` on renderD129: Mesa 26.2.5: H.264, HEVC Main10, VP9, AV1 decode; H.264 and HEVC encode. iGPU clock range 700–2200 MHz, `active_cu_number 2` (the card: 32, kernel log). Holders of the dGPU today (`/proc/*/fd`): dwl (`card0`, `renderD128`), Xwayland, localsend, steam, steamwebhelper. `renderD128` and `renderD129` are mode 0666, `card*` 0660 root:video with an ACL; he is in `video` and `render`. `/dev/input/event*` are root:input 0660 with no ACL for him. Two keyboards are attached (T36: which is the K617 is open): `usb-BY_Tech_Gaming_Keyboard-event-kbd` and `usb-SEMICO_USB_Gaming_Keyboard-event-kbd`. T36: OpenRGB drives the card's logo over `i2c-6`, the card's own bus. `/proc/kallsyms` has 126 `dm_ism` symbols: the code of #6062 is in his kernel. Owner's default sink is the board's analog output `15:00.6`, not the card's HDMI. SELinux enforcing. THP `madvise`. `~/.local/state/fedokawaii/for-you/` is empty since 28 Oct 22:11: **the T06 notice was cleared, the cables were not moved.**

## 9. Asked, not found

- Any report of a Navi 44 rebind on 7.2.x after the August fix. Any AMD statement on VMs and vDisplay.
- A physical display at 144 Hz with VRR under KVM with the hypervisor bit on.
- CS2 in a KVM guest in 2026 on a VAC-secured server, with evidence. FACEIT's or other anti-cheats' written position on VMs: none found, but see §10.8.
- Measured evdev versus USB-controller input latency: none credible found. Reports of the board's own `15:00.3/.4` USB controllers under passthrough ([Debian](https://lists.debian.org/debian-kernel/2025/09/msg00309.html), [Xen](https://lists.xen.org/archives/html/xen-devel/2025-07/msg01661.html)) describe AMD xHCI resets going badly on other platforms.

## 10. Second pass, 4 Nov 2026: what the first pass left open

### 10.1 Where the firmware, GRUB and the text console draw

- **[P]** [MSI's AM5 BIOS guide](https://download.msi.com/archive/mnu_exe/mb/AMDAM5BIOS.pdf) (January 2023, for AM5 boards in general; this board's own manual stays refused): `Settings > Advanced > Integrated Graphics Configuration > Initiate Graphic Adapter`, "Selects a graphics device as the primary boot device. [IGD] Integrated Graphics Display. [PEG] PCI-Express Graphics Device." Delete enters setup, F10 saves and resets. Read with `pdftotext`.
- **[P]** Kernel v7.2 `arch/x86/video/video-common.c`, `video_is_primary_device()`: true for the PCI device with a BAR holding the framebuffer the firmware set up. `fbcon.c` `fbcon_select_primary()` maps every console to that device's framebuffer (`CONFIG_FRAMEBUFFER_CONSOLE_DETECT_PRIMARY=y` here). This boot's journal: "fbcon: amdgpudrmfb (fb0) is primary device". `fbcon=map:<n>` overrides it and disables that detection (`fbcon.c:508–518`).
- **So tty1 follows the firmware, not the compositor.** With the firmware on the card, the console, every kernel message and an emergency prompt stay on the card's dark DP while the desktop is on the board's HDMI.
- **[R]** [Arch forum](https://bbs.archlinux.org/viewtopic.php?id=310537) (late 2025, board not named): iGPU as primary was honoured with CSM on; with CSM off, "system booted with display output on the dgpu". One report, no BIOS version, no end to the thread. CSM is no way out: MSI's guide calls it "For the non-UEFI driver add-on devices or non-UEFI mode OS", and the poster says it cost them Secure Boot. So the design must survive the setting being ignored: test B.

### 10.2 144 Hz on the iGPU's HDMI

- **[P]** The LG's EDID, decoded here: first timing 1920×1080 at 143.98 Hz with a **346.50 MHz** pixel clock; 60 Hz at 148.50; in the extension 119.98 Hz at 285.50 and 100 Hz at 228.80. HDMI 1.4 block: 300 MHz. HDMI Forum block: 450 MHz. AMD's FreeSync block: 48–144 Hz. So 144 Hz is above HDMI 1.4's rate: the source must do HDMI 2.0's.
- **[P]** MSI's [datasheet](https://storage-asset.msi.com/datasheet/mb/us/PRO-B650M-B.pdf): "Support 4K@60Hz as specified in HDMI 2.1, VGA – Requires Processor Graphics"; back panel "1. HDMI 2. VGA". 4K60 is 594 MHz, so 346.5 fits on paper.
- **[P]** [LG's page](https://www.lg.com/cl/monitores/gaming/24g411a-b/): "(HDMI 2.0 admite hasta 144 Hz)", DisplayPort "(1ea)", version 1.4, "Se requiere un cable y una tarjeta gráfica compatibles con DP 1.4", 120 Hz native with 144 Hz as overclock; the box holds "cables de conexión", not said which.
- Not proven until a cable is in. If the port falls short, 119.98 Hz at 285.50 MHz is in the EDID too.

### 10.3 What makes an unbind wait forever

- **[P]** `/dev/i2c-N`: `i2c-dev.c:604` takes `i2c_get_adapter()` at open, which holds `get_device(&adapter->dev)` (`i2c-core-base.c:2637`), until close (`i2c-dev.c:632`). `i2c_del_adapter()` ends in `wait_for_completion(&adap->dev_released)` (`:1840`), with no timeout. So one open fd on a bus of the card blocks amdgpu's unbind: an OpenRGB server on `i2c-6`, a `ddcutil` caught mid-read on `i2c-5`. The writer of the unbind holds the device lock while it waits; #5446 shows what that does to libvirt.
- **[P]** ALSA: `sound/core/init.c:644–661`, `snd_card_free()` waits "until all devices are ready for the free operation", without a timeout: every open file on the card closed. `/proc/asound/cards`: card 0 is the card's HDA; PipeWire holds it today. Test R runs with no session, so it cannot see this.
- **[P]** [WirePlumber's ALSA page](https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/alsa.html): `device.disabled` "Disables the device. WirePlumber will not create it at all". Used in `monitors/alsa.lua:690` in the installed 0.5.19. He listens on the board's analog output, so the card's HDA is not needed on the host at all.
- `/dev/kfd` (0666 root:render) is one node for every amdgpu device. T47's ROCm path holds it. Whether an open one blocks an unbind was not read or measured: the hook treats it as a holder.

### 10.4 virtiofs and the memory of a game VM

- **[P]** [libvirt's virtiofs page](https://libvirt.org/kbase/virtiofs.html): "QEMU needs to allocate the backing memory for all the guest RAM as shared memory"; memfd or hugepages; "Don't forget the <memoryBacking> elements".
- **[P]** This PC: `/sys/kernel/mm/transparent_hugepage/shmem_enabled` is `never`. [The kernel's THP page](https://docs.kernel.org/admin-guide/mm/transhuge.html) makes that the policy for the internal shmem mount that memfd uses. So memfd-backed guest RAM gets 4 KiB pages, against the "THP first" that section 4 of the design rests on; the way out would be hugetlb pages reserved up front.
- **[P]** [virtio-win's page](https://github.com/virtio-win/kvm-guest-drivers-windows/wiki/Virtiofs:-Shared-file-system): the guest needs "WinFSP with at least "Core" feature enabled" plus the service. A third-party filesystem driver in the guest, next to VAC, for a folder used once.

### 10.5 QEMU 11's "refusal" does not reach this card

- **[P]** QEMU v11.1.0 `hw/vfio/container-legacy.c:1068`, "vfio: Cannot reset device %s, depends on group %d which is not owned.", `iommufd.c:869` the same by device. It is the hot-reset path: for each device the kernel lists on the reset bus, it fails if this QEMU does not own its group.
- [The gist](https://gist.github.com/PhialsBasement/c34e908352bd2e8a49197edc70df2d94) [R] meets it passing an onboard audio function on B550/X570 and says 11.0.1+ will not start.
- Here the bus below the card's switch holds `03:00.0` and `03:00.1` and nothing else (`lspci -s 03:`), both passed. Test R on F45 still proves it.

### 10.6 Internal snapshots with UEFI

**[P]** libvirt v12.0.0 `src/qemu/qemu_snapshot.c:1040–1063`: an active VM with pflash needs "QCOW2 nvram format"; offline, `qemu-img snapshot` runs on each qcow2, the NVRAM included (`:356–377`). So `VARS.qcow2` with the VM off is supported. [`<nvram format=…>`](https://libvirt.org/formatdomain.html) must say qcow2. The TPM's state directory is in no qcow2, so a snapshot does not cover it.

### 10.7 Windows

- **Licence [P]:** [Windows 11 OEM terms, April 2024](https://www.microsoft.com/content/dam/microsoft/usetm/documents/windows/11/oem-(pre-installed)/UseTerms_OEM_Windows_11_English.pdf): "This license allows you to install only one instance of the software for use on one device, whether that device is physical or virtual. If you want to use the software on more than one virtual device, you must obtain a separate license for each instance." and "“device” means a local hardware system (whether physical or virtual)". These are the OEM terms; the retail file's address was not found. So this VM needs its own licence, and an OEM licence tied to another PC is not obviously one: T33 reads the ISO's copy.
- **Device encryption [P]:** [Microsoft's OEM page](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-bitlocker) documents `PreventDeviceEncryption` and frames it as being for OEMs with their own encryption, otherwise prohibited under Windows 11's licensing (read through a search excerpt). **Not scripted.** T33 reads `manage-bde -status`; if it is on and costs something, the Settings switch is his to use.
- **AMD's installer [P, excerpts]:** AMD's [command-line guide](https://drivers.amd.com/relnotes/command-line-installation.pdf) documents `Setup.exe -INSTALL -boot` for Radeon PRO; [RSX2-INSTALL](https://www.amd.com/en/resources/support-articles/faqs/RSX2-INSTALL.html) sends consumers to it. [R]: [an HP forum user](https://h30434.www3.hp.com/t5/Unanswered-Topics-Notebook/HP-EliteBook-745-G5-Command-Line-Install-Radeon-Driver/m-p/7701762) says `setup.exe -install` is silent and also installs the Radeon app. No document promises it for Adrenalin: test the pinned package. Whether Windows Update offers a driver for `1002:7590`: not found.

### 10.8 FACEIT

**[P, excerpts: its pages refuse fetching]** [FACEIT's rollout post](https://www.faceit.com/en/news/faceit-rollout-of-tpm-secure-boot-iommu-and-vbs): from 25 November 2025 "both TPM 2.0 and Secure Boot will be required for all players", IOMMU and VBS expanding in stages; [TPM attestation failed](https://support.faceit.com/hc/en-us/articles/20669555338268-TPM-attestation-failed). Nothing found names VMs. Inference: swtpm has no manufacturer's key chain to attest with, and VBS needs the nested `svm` the design turns off. The owner never named FACEIT.

### 10.9 Looking Glass on Wayland (T32's question)

**[P]** [requirements.rst](https://github.com/gnif/LookingGlass/blob/master/doc/requirements.rst): "The client requires an EGL-capable graphics driver. X11 and Wayland are supported." Only native HDR names a protocol, `color-management-v1`. `~/.local/src/dwl/dwl.c` has pointer constraints, relative pointer, presentation time, idle inhibit and xdg decoration. Nothing blocks the client on our compositor.

### 10.10 What catches a hung host

**[P]** `/dev/watchdog0` is the SP5100 TCO timer, 60 s. T45 sets `RuntimeWatchdogSec=1min` only during a kernel's trial (`lib/update.sh:482`). **This kernel has no hung-task detector: `CONFIG_DETECT_HUNG_TASK` is not set, and `/proc/sys/kernel/hung_task_panic` does not exist.** `softlockup_panic` (0) and `hardlockup_panic` exist, `panic` is 10. A stuck unbind leaves PID 1 running and the CPUs free: no watchdog and no lockup detector fires, so only a timer in the test's own runner can end it (`/proc/sysrq-trigger`).

### 10.11 Backups

**[P]** `bin/kawa-backup:223` runs `restic backup --exclude-file … -- "$HOME"` with no `--one-file-system`, and `backup-exclude` has no `VM` line. So `~/VM` goes to his backup drive: 86 GiB of harness today, a Windows disk later.

### 10.12 Things that needed no change

`cpu0` pairs with `cpu6`, `cpu1` with `cpu7`, `cpu5` with `cpu11` (sysfs): the pinning in the design holds. `libvirt-guests.service` is installed, disabled; its man page has `ON_SHUTDOWN=shutdown` with `SHUTDOWN_TIMEOUT`. Keyboards expose several event nodes: `usb-SEMICO_USB_Gaming_Keyboard-{event-kbd,event-if01,if01-event-kbd}`, `usb-BY_Tech_Gaming_Keyboard-{event-kbd,event-if01,if01-event-mouse}`.
