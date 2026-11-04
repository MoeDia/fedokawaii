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
