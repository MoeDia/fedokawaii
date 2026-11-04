# The games VM — written design (T32)

Written 4 Nov 2026 by the research lane. Sources and grades: `vm-research.md`, cited as (R§n). Nothing here has run on
the PC: the six tests in section 3 decide the open branches, and each says which result leads where.

## 1. Decisions

| Question | Decision | Why |
|---|---|---|
| Display | **Native: the card's DP into the LG, the host on the board's HDMI.** Looking Glass only if test O or S fails | No latency added, FreeSync possible, no out-of-tree kernel module, no unreleased code (R§7) |
| Who owns the card when the VM is off | **amdgpu, with no process holding it.** vfio-pci only while the VM runs | What nearly every working report does (R§2); the AI fixer (T47) needs the card |
| Host compositor | **Always on the iGPU**, whether the VM runs or not | wlroots picks its renderer for its whole life; moving means losing the session. If the frame budget fails on 2 compute units against 32 (test H), this design needs rethinking |
| Hiding the VM | **The CPUID hypervisor bit stays on, always.** No SMBIOS spoof, no MAC, ACPI or `ucode-rev` tricks. `vendor_id` and `kvm hidden` only if test O shows the card's outputs need them, and then disclosed | Clearing the bit makes Windows believe it runs on bare metal: what a cheat loader does (R§3) |
| CS2 | **Stays on the list only if a real VAC-secured match works, with that config, unchanged.** Otherwise off, said plainly | Valve's FAQ names hypervisors (R§1); it cannot be proven from here |
| Input | evdev with `grabToggle='ctrl-ctrl'`, both Ctrl keys return the keyboard to the host even if Windows hangs | A passed-through USB controller has no way back when the guest hangs |
| Audio | HDA (`ich9`) to the host's PipeWire | **virtio-win has no sound driver** (R§5); he listens on the board's analog output `15:00.6` (R§8) |
| Drivers | virtio-win **ISO pinned by checksum, kept in the VM's folder** | Not a Fedora package; `gpgcheck=0` is refused by F45's enforced signatures (R§5) |
| Disk | qcow2 on a NOCOW directory, `cache=none`, `io_uring`, iothread, virtio-blk; raw only if the guest's benchmark shows > 15 % | Internal snapshots keep everything in one file: `rm -rf` is the whole uninstall |

## 2. What the owner has to do

Revised from T06. Nothing yet: tests H, V and R need no change of cables, and O needs none either (the LG stays on the
card's HDMI). **Only when H, R and O pass**, one notice, with one reason line, because the T06 file was cleared on 28 Oct
22:11 while sysfs still shows the cables unmoved (R§8):

> For the games VM: move the HDMI cable from the graphics card to the motherboard, and connect a DisplayPort cable from
> the graphics card to the monitor. Then restart the PC.

He does this whenever he reads it, so **`start-dwl --gpu` must already work with both wirings before the notice goes out**:
the iGPU when its HDMI answers, else the card. If he restarts before the host is ready, he must still get a desktop.

Open: whether he owns a DisplayPort cable (not checked, LG's box contents unread); whether the BIOS needs primary display
= IGD (decided in test S, one more line then, never a second notice for the same thing). IOMMU and AMD-V need nothing:
39 groups, the card alone in 14, its audio alone in 15, no `direct` reserved regions there (read 4 Nov), so the MSI X870 refusal of #5644 does not apply.

**Only he can do the CS2 test:** the agent never types his Steam password. See test C.

## 3. The tests, in order

Each is a script kept in `tools/`, gated by `tools/away.sh` wherever he could notice, as `tools/vm-*-proof.sh`.

### H. The desktop on the iGPU (no risk, no cables, headless)

`tools/perf.sh` protocol from T04 with `WLR_RENDER_DRM_DEVICE=/dev/dri/renderD129` in `tools/hl-dwl.sh`: window open and
close, workspace switch, wash 1.2 s, dissolve frames at 144 Hz, 1080p and 4K AV1 in mpv through VA-API.

- Pass: no animation drops frames beyond T04's baseline; key-to-glass within 1 ms of it.
- Fail: tune on the iGPU (T19's shader cost first). If it still fails, stop and tell him: running the desktop at this level on 2 compute units is the price of this design, and no later test can repay it.

### V. Windows without the card (no risk)

Stage 1 of T33: unattended 26H2, virtio display, virtio-win, guest agent, Steam and qBittorrent, measured with `virsh screenshot` and guest-exec. Saves a clean snapshot. Everything after this reuses it.

### R. The reset (can hang the PC; needs him away, everything pushed, session ended)

The session is on the card, so it ends for the test (START §4 allows restarts); `panic=10` and pstore are already there. Then, on the text console:

1. amdgpu bound, `power/control=on` (R§2 #6076), BAR2 per test O, `driver_override` to vfio-pci for both functions.
2. Stage 1's Windows + the card, driver initialised: `Get-PnpDevice` through guest-exec reports OK.
3. Stop: three ways in turn: from inside Windows, `virsh shutdown`, `virsh destroy`.
4. Unbind vfio, clear the overrides, bind amdgpu; pass = "Initialized amdgpu" and `vulkaninfo` lists the card, and `current_link_speed` still 32 GT/s (#4951).
5. 20 cycles. A journal oops or a watchdog reboot ends the run.

| Result | Design |
|---|---|
| R1: 20 of 20 | The plan's design: amdgpu ↔ vfio per run |
| R2: rebind fails, a new guest starts | The card stays on vfio after the first VM until the next boot. The VM always works; the AI fixer needs a reboot, and `update` says so |
| R3: a new guest also fails; `rtcwake -m mem -s 5` recovers (#L1T, Jul 2026) | Stop = short suspend, automatic, with a line on screen; needs its own test that the lock stays out of it |
| R4: only a power-off recovers | **One VM session per boot**, said plainly by kawa-vm; `rtcwake -m off` offered as "restart for another session" |
| R5: the host hangs even once | Retry with `vfio-pci.ids=1002:7590,1002:ab40` at boot, amdgpu never touching the card (reports split both ways, R§2). A "games mode" boot toggle, as the plan foresaw. Still hangs: no VM on this card, told plainly |

The kernel's August fix (R§2 #5447) makes R1 more likely than any report suggests, and nobody has tested it on a Navi 44. Expect nothing.

### O. The outputs (needs him away; same run as R)

No cable change: Windows drives the LG on the card's HDMI, which is where it is plugged today. Read through guest-exec:
`WmiMonitorID` (does "LG ULTRAGEAR" appear, or "AMD Vdisplay"), `Win32_VideoController.CurrentRefreshRate`, the Radeon driver's FreeSync state, `Get-PnpDevice` for Code 43. Once both cables are in, VRR gets an outside proof: `getvcp ae` from the host while a game runs at 100 fps, if the LG answers on the inactive input (test S).

Step up one lever at a time, and stop at the first that passes:

- O0 nothing hidden. O1 `vendor_id` only. O2 `vendor_id` + `kvm hidden`.
- Each with BAR2 at 256 MiB and then at 8 MiB (`resource2_resize` 8 and 3, R§4), BAR0 16 GiB. `Get-PnpDevice` decides.

| Result | Design |
|---|---|
| O0 or O1 or O2 gives LG at 144 Hz and VRR | Native. The levers used are written in the VM's XML, in the Learn piece and in kawa-vm's about line |
| Only 60 Hz or a virtual display at O2 (reports say SMBIOS spoof was needed, R§3) | **No spoof.** Looking Glass (section 5), measured with PHOTON; if its latency is not acceptable for CS2, the VM runs with what it has and he is told what is missing |

### S. The switch (needs the cables; T38)

The LG advertises only `60(01 03)`, and its real input codes are unknown; `f4` answers but is undocumented; another LG, another controller, proves nothing (R§7). Find it in this order, with him away, with read-back from `ae` (0 or changed = no signal):

1. `setvcp 60 0x0f` and `0x11`, normal source and `--i2c-source-addr x50`, then `f4` with the same address.
2. **From the inactive input:** whether the HDMI's DDC still accepts the write that brings it back. This is the question that decides everything; rockowitz: "Some monitors will respond to DDC requests only on the currently selected input".
3. If DDC cannot return: **the signal itself.** Blank the host's HDMI (`wlr-randr` or DPMS) when the VM starts and light it when the VM stops, and see whether the LG follows a dying input to the live one (its manual was unreadable; "Auto Input Switch" exists on other UltraGears, R§7).
4. Neither: Looking Glass, or a monitor press on rare occasions, decided by what test O said.

Pass: 20 cycles both ways. A killed QEMU returns the picture in < 3 s (T34's own bar). The boot path also passes: firmware and GRUB draw on the card (`boot_vga=1`), so with the DP in, the LG may land on DP before Linux; `video=DP-1:d video=DP-2:d` keeps the kernel's console off it, and the names must be re-checked across boots because they depend on probe order. If the boot still flickers between inputs: primary display = IGD in the BIOS, the one extra line of section 2.

### C. CS2 (needs his login; last)

Valve's words: "Hypervisors … please disable it while playing", ending in a disconnect, not a ban; "System hardware configurations" do not trigger bans; a mistaken ban "will automatically be removed" (R§1). A KVM player, with a custom `vendor_id` like lever O1, was banned in Nov 2023 and unbanned 11 days later, with no reason given.

- The notice tells him this in three lines, and that a free spare Steam account tries it without risking his own.
- He signs in himself and plays casual on a VAC-secured server, twice on different days.
- Green: CS2 stays, "not promised by Valve, works today". Red ("Disconnected by VAC"): **CS2 is off the list. Nothing is changed to get past it.**
- Then the honest one-liner: the only documented ways to play CS2 on secure servers from this PC are no hypervisor at all: CS2's native Linux client on the host, or Windows booted directly. He has ruled the first out for now; neither is built.

## 4. The VM

### One folder: `~/VM/games/`, its own Btrfs subvolume, NOCOW

`win11.qcow2`, `VARS.qcow2`, `tpm/` (`<source type='dir'>` since libvirt 10.10), `virtio-win-0.1.302.iso`, `games.xml`, `autounattend.iso`, `logs/`, `import/` (virtiofs: `blasphemous-save-backup-20261022`).

Outside the folder, on purpose, and removed by `kawa-vm --remove`: the libvirt definition (`virsh undefine`), the hook in `/etc/libvirt/hooks/qemu.d/` (part of the installer), and QEMU's log `/var/log/libvirt/qemu/games.log` (T33's audit lists it).

### Domain, in `qemu:///system`

PCI passthrough cannot run in a session domain; the harness's session VMs stay as they are. Per-domain DAC label as `dia` instead of editing `qemu.conf`, so the home folder and PipeWire socket are reachable; SELinux is enforcing here, so T33 reads the AVCs first (the same Fedora setup needed a small module in [WindowsKVM](https://github.com/serialexperimentslainnnn/WindowsKVM)).

```xml
<domain type='kvm'>
  <name>games</name>
  <memory unit='GiB'>16</memory> <memoryBacking><nosharepages/></memoryBacking>
  <vcpu placement='static'>10</vcpu> <iothreads>1</iothreads>
  <cputune>
    <!-- cores 1-5 with their SMT siblings 7-11; the host keeps core 0 (cpus 0, 6) -->
    <vcpupin vcpu='0' cpuset='1'/> <vcpupin vcpu='1' cpuset='7'/> <!-- … to 5, 11 -->
    <emulatorpin cpuset='0,6'/> <iothreadpin iothread='1' cpuset='0,6'/>
  </cputune>
  <os firmware='efi'>
    <type arch='x86_64' machine='q35'>hvm</type>
    <firmware><feature enabled='yes' name='secure-boot'/><feature enabled='yes' name='enrolled-keys'/></firmware>
    <loader secure='yes'/> <nvram>/home/dia/VM/games/VARS.qcow2</nvram>
  </os>
  <features>
    <acpi/> <apic/> <smm state='on'/>
    <hyperv mode='custom'>
      <relaxed state='on'/> <vapic state='on'/> <spinlocks state='on' retries='8191'/> <vpindex state='on'/>
      <runtime state='on'/> <synic state='on'/> <stimer state='on'/> <reset state='on'/> <frequencies state='on'/>
      <tlbflush state='on'/> <ipi state='on'/> <avic state='on'/>
      <!-- vendor_id only at O1 and above -->
    </hyperv>
    <!-- <kvm><hidden state='on'/></kvm> only at O2 -->
    <vmport state='off'/>
  </features>
  <cpu mode='host-passthrough' check='none' migratable='off'>
    <topology sockets='1' cores='5' threads='2'/>
    <cache mode='passthrough'/> <maxphysaddr mode='passthrough'/>
    <feature policy='require' name='topoext'/> <feature policy='disable' name='svm'/>
    <!-- never: <feature policy='disable' name='hypervisor'/> -->
  </cpu>
  <clock offset='localtime'><timer name='hypervclock' present='yes'/><timer name='hpet' present='no'/></clock>
  <devices>
    <!-- virtio-blk with the iothread · hostdev 03:00.0 and 03:00.1, managed='no' · virtio-net on libvirt's NAT
         input: <input type='evdev'> on /dev/input/by-id, one for each keyboard in use (T36: which is the K617)
                with grab='all' repeat='on' grabToggle='ctrl-ctrl'; usb-Logitech_USB_Receiver-if02-event-mouse
                (the nodes are root:input 0660: T33 checks that libvirt relabels them for the dia label)
         usb: qemu-xhci; a controller as <hostdev type='usb'> by vendor:product, attached live
         sound: <sound model='ich9'/> with <audio type='pipewire' runtimeDir='/run/user/1000'/>
         tpm-crb, emulator 2.0, <source type='dir' path='…/tpm'/> · <memballoon model='none'/> · no video after stage 1 -->
  </devices>
</domain>
```

`svm` off: Windows then cannot start its own hypervisor for Memory Integrity, the cost Microsoft itself names for gaming (R§6). Host keeps one core plus its SMT sibling: LG's docs ask for two cores only for their own client. Measured in T33; five cores for the guest is the first try, not a promise. 16 GiB of 30: THP first (VFIO allocates up front, R§5); 1 GiB pages only if PresentMon's 1 % lows show a gain; the dynamic route is disputed in Arch's own wiki.

### The hook: `/etc/libvirt/hooks/qemu.d/kawa-vm`, root, never calls libvirt

`prepare begin`:

1. Refuses (non-zero: the guest does not start, libvirt logs why) when: an update runs (shared lock with T45), or any process other than the fixer holds a dGPU node.
2. `power/control=on` for both functions; unbind amdgpu and `snd_hda_intel`; sets BAR2; `driver_override=vfio-pci`, `drivers_probe`.
3. `AllowedCPUs=0,6` on `user.slice`, `system.slice`, `init.scope` (R§5).

`release end`: the reverse, always, whatever the reason, also after a killed QEMU, per test R's result. Then the display back (it must not depend on the TUI being open). `reconnect begin` exits 0 so a daemon restart does not kill the VM.

### Keeping the host away from the card

`amdgpu_kms.c:1609` in our kernel still has the race of #5446: any open fd at unbind can oops and deadlock libvirt until reboot (R§2). So the rule is not "be careful" but "no one can open it": a udev rule after 70-uaccess for the card's two nodes, removing `uaccess`, mode 0660 and a group of their own (today `renderD128` is 0666 and he is in `video` and `render`, so the ACL alone would not do). The fixer's unit gets that group; the desktop should fall to `renderD129` by itself, which T33 proves. Every app the PC runs today is re-checked with that rule: Xwayland, localsend, the browser (T31a), mpv's VA-API.

### Windows

Stage 1 without the card, stage 2 with it, so most of the build needs no risky step.

- `autounattend.xml` of our own from Microsoft's reference: `LocalAccounts` with an empty password and `AutoLogon` (the VM has no inbound route), `HideOnlineAccountScreens`, virtio drivers through `PnpCustomizationsWinPE`. **No product key in any file.** Windows runs unactivated until he enters his own; the notice says so. Whether he owns a licence is not known here.
- First logon: forces winget's registration (R§6), installs `Valve.Steam`, `qBittorrent.qBittorrent`, removes provisioned apps with `Remove-AppxProvisionedPackage`, sets Game Mode and the power plan. `RemoveDefaultMicrosoftStorePackages` needs Enterprise, Pro cannot use it. Nothing unofficial.
- Stage 2: AMD's driver, then `ExcludeWUDriversInQualityUpdate` (Pro and above, [CSP](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-update)) so a tested driver is not replaced behind his back; on Home: not available, said so.
- The ISO: his own download, or fetched with the method Fido uses if it works from a script; checksum recorded. T33 tries the script first.

## 5. If it comes to Looking Glass

Needed only if O or S fails. What it costs: an out-of-tree `kvmfr` built on every kernel (an update-proofing risk), IDD only on master with no release since B7 of March 2025, a Windows input driver next to VAC, and a 2-compute-unit iGPU compositing 1080p144. What it gives: no second cable, no DDC, and possibly nothing hidden. The test of it is the latency PHOTON reports plus a frame-time capture. It would also change the notice to "HDMI to the motherboard" only.

## 6. Failure modes

| Failure | Answer |
|---|---|
| QEMU killed or crashes | `release end` runs; rebind per test R; display back; QEMU's death frees evdev by itself |
| Windows hangs | Both Ctrl keys, then the host's key to stop: ACPI, forced after 60 s. Also from the remote page (`fk-remote`) |
| No grab and no picture on host | Display key flips the input back, by DDC or by signal, whichever test S kept |
| Host would idle while he plays | His keys go to QEMU, so the host sees no input: saver, lock, 5 s screens off and the **suspend after 90 s would kill the VM**. `systemd-inhibit --what=idle:sleep` for the VM's life |
| Host suspend asked | Refused with a line, while the VM runs |
| Session restarted while VM runs | PipeWire is gone: sound dies. kawa-vm warns before it, T20r's refresh key keeps its hands off the card |
| Update while VM runs | Refused in phase 0 (T45 already plans it). VM start during update refused. The fixer needs the card |
| Hook half-way fails | Reverse what it did, exit non-zero: the guest never starts |
| Daemon restart while running | `reconnect` exits 0 |
| Power cut | Boots normally, amdgpu binds; Windows recovers its own disk; #5447 says scratch values clear at power-off |
| Windows' update changes the driver | Blocked on Pro; snapshot before updates from kawa-vm (VM off, qcow2 internal) |
| Fedora 45's QEMU 11 | The gist's reset-domain refusal: re-run R after T46; the plan puts the host on F45 anyway, so run R on F45 if T46 lands first |
| A controller plugged late | kawa-vm attaches by `vendor:product` (`virsh attach-device`), learnt from `lsusb`; none is plugged in today |

## 7. Limits to tell him plainly

1. **CS2 cannot be promised.** Valve's page lists hypervisors; the rest is reports. Other anti-cheats with kernel drivers: assume they refuse until tried.
2. **The card might work one session per boot.** That is the bad end of test R and it may be what he gets.
3. **The desktop runs on a GPU with 2 compute units instead of 32**, always, whether he plays or not. It is enough for 1080p and video, the numbers from H will say by how much.
4. **While he plays**, the desktop has one core, and downloads and torrents on the host run slowly. Near-native frame rates are a measurement to come, not a claim here.
5. **The VM may need two driver-facing names changed** (`vendor_id`, `kvm hidden`): the guest still knows it is a VM.
6. **A rare crash may need a press on the monitor**, if test S ends at that branch.
7. **Windows needs his own licence**, and he signs in to Steam himself.
8. **The card's logo RGB (T36)** cannot be driven from Linux while the VM has the card: OpenRGB reaches it over `i2c-6`, amdgpu's bus.
9. **`update` and the VM exclude each other.**

## 8. What changes in the plan

- **T33**: `virtio-sound` → HDA + PipeWire; "Fedora's `virtio-win` package" → the pinned ISO; `qemu:///system`; stage 1 without the card, reset and outputs tests before any cable; TPM state `source` in the folder; `autounattend` per section 4.
- **T34**: idle and sleep inhibited for the VM's life; display return lives in the hook, not the TUI; a hung-Windows path; the `grabToggle` state readable through QMP if the display should flip with it (decide in T34).
- **T35**: unchanged, but only after C is answered: he might want CS2 on Linux after all. T35's title stands, though the question is his.
- **T36**: the logo's RGB goes through amdgpu's I2C (`i2c-6`): only while the VM is off.
- **T38**: capabilities work with `--sleep-multiplier 2` (string in R§7); the input question moves to test S. Note `60(01 03)`.
- **T45/T47**: the shared lock; the fixer's unit in the card's group.
- **T06**: re-issue once, per section 2.
- **Host today**: `start-dwl --gpu` picks by VRAM → by config, resolved from the PCI address (R§7).
