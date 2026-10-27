#!/usr/bin/env bash
# tests/installer/test_hardware.sh — lib/hardware.sh against the cards, radios and kernel logs of
# made-up machines (sysfs as the kernel shows it, in the fake machine): which GPU the desktop is
# built for (AMD discrete, AMD APU, Intel, NVIDIA, Intel + NVIDIA, Intel beside AMD, a virtual
# machine, none), whether the AMD card has memory of its own, laptop or desktop, the firmware
# the kernel asked for (Wi-Fi chips above all), what each machine needs installed, devices
# with no driver, fwupd's updates — and what check.sh says of each machine.
. "$(dirname "$0")/lib.sh"
LIBHW=/home/fkuser/fedokawaii/lib/hardware.sh
# hw FN [ARG…] — FN of lib/hardware.sh, run in the fake machine: its output in $OUT, status in $RC
hw() { fkrun bash -c '. "$1"; shift; "$@"' _ "$LIBHW" "$@"; }

world fresh

# ── the GPU ──────────────────────────────────────────────────────────────────
case_ "hw_gpu: each machine's card, as setup builds for it"
for m in "hw_amd amd" "hw_apu amd" "hw_intel intel" "hw_igpu_amd amd" "hw_hybrid intel" "hw_nvidia nvidia" "hw_vm vm" "hw_nogpu none"; do
  ${m% *}; hw hw_gpu; eq "$OUT" "${m#* }" "${m% *}"
done
case_ "hw_gpu: QEMU's QXL, VMware, VirtualBox are virtual machines too; a connector never counts as a card"
for v in 0x1b36 0x15ad 0x80ee 0x1234; do hw_nogpu; gpu card0 "$v" 0x0100 none; hw hw_gpu; eq "$OUT" vm "vendor $v"; done
hw_nogpu; mkdir -p "$W/sys/class/drm/card0-HDMI-A-1"; echo 0x1002 >"$W/sys/class/drm/card0-HDMI-A-1/vendor"
hw hw_gpu; eq "$OUT" none "a connector's own files"
case_ "hw_gpu: the boot's simple framebuffer (no PCI vendor) is no GPU"
hw_nogpu; mkdir -p "$W/sys/class/drm/card0/device"; hw hw_gpu; eq "$OUT" none

case_ "hw_discrete_amd: a card with 2 GiB or more of its own — not an APU, not Intel"
hw_amd;       hw hw_discrete_amd; eq "$RC" 0 "RX 6700 XT, 12 GB"
hw_igpu_amd;  hw hw_discrete_amd; eq "$RC" 0 "Intel's graphics first, the AMD card second"
hw_apu;       hw hw_discrete_amd; eq "$RC" 1 "an APU's 512 MB"
hw_intel;     hw hw_discrete_amd; eq "$RC" 1 "Intel"
hw_nogpu;     hw hw_discrete_amd; eq "$RC" 1 "no card"
hw_nogpu; gpu card0 0x1002 0x6798 amdgpu 2147483648; hw hw_discrete_amd; eq "$RC" 0 "exactly 2 GiB"
hw_nogpu; gpu card0 0x1002 0x6798 radeon; hw hw_discrete_amd; eq "$RC" 1 "an old card on radeon (no memory figure)"
hw_nogpu; gpu card0 0x1002 0x6798 amdgpu "n/a"; hw hw_discrete_amd; eq "$RC" 1 "a figure that is not a number"
case_ "hw_discrete_amd_pci: its PCI address (game mode's clocks) — the AMD card's, not the APU's or Intel's"
hw_amd;      hw hw_discrete_amd_pci; eq "$RC:$OUT" "0:0000:03:00.0" "the only card"
hw_igpu_amd; hw hw_discrete_amd_pci; eq "$RC:$OUT" "0:0000:04:00.0" "Intel's card0, the AMD card1"
hw_nogpu; gpu card0 0x1002 0x164e amdgpu 536870912; gpu card1 0x1002 0x7590 amdgpu 17163091968
hw hw_discrete_amd_pci; eq "$RC:$OUT" "0:0000:04:00.0" "the CPU's Radeon 610M card0, the RX 9060 XT card1"
hw_apu;      hw hw_discrete_amd_pci; eq "$RC:$OUT" "1:" "an APU alone: none"
case_ "hw_btop_gpu: the discrete card's number in btop's order (ROCm SMI: the AMD cards by PCI address, not by card number)"
hw_nogpu; gpu card0 0x1002 0x7590 amdgpu 17163091968; gpu card1 0x1002 0x164e amdgpu 536870912
echo PCI_SLOT_NAME=0000:7a:00.0 >"$W/sys/class/drm/card1/device/uevent"
hw hw_btop_gpu; eq "$OUT" gpu0 "the card at 03:00.0, the CPU's graphics at 7a:00.0: the card first"
hw_nogpu; gpu card0 0x1002 0x7590 amdgpu 17163091968; gpu card1 0x1002 0x164e amdgpu 536870912
echo PCI_SLOT_NAME=0000:0e:00.0 >"$W/sys/class/drm/card0/device/uevent"
echo PCI_SLOT_NAME=0000:03:00.0 >"$W/sys/class/drm/card1/device/uevent"
hw hw_btop_gpu; eq "$OUT" gpu1 "the CPU's graphics at 03:00.0, the card at 0e:00.0 (card0 all the same): the card second"
hw_igpu_amd; hw hw_btop_gpu; eq "$OUT" gpu0 "Intel's graphics beside it: not an AMD card, not counted"
hw_apu;      hw hw_btop_gpu; eq "$RC:$OUT" "0:" "an APU alone: no card's box"
hw_nogpu;    hw hw_btop_gpu; eq "$RC:$OUT" "0:" "no card"

# ── laptop or desktop ────────────────────────────────────────────────────────
case_ "hw_is_laptop: a desktop is not; a battery, or the firmware's chassis type, makes one"
hw_amd; hw hw_is_laptop; eq "$RC" 1 "the desktop"
mkdir -p "$W/sys/class/power_supply/hidpp_battery_0"; echo Battery >"$W/sys/class/power_supply/hidpp_battery_0/type"
echo Device >"$W/sys/class/power_supply/hidpp_battery_0/scope"
mkdir -p "$W/sys/class/power_supply/ups"; echo UPS >"$W/sys/class/power_supply/ups/type"
hw hw_is_laptop; eq "$RC" 1 "a desktop with a wireless mouse's battery and a UPS"
hw_laptop; hw hw_is_laptop; eq "$RC" 0 "a battery (BAT0)"
rm -rf "$W/sys/class/power_supply"; mkdir -p "$W/sys/class/dmi/id"
echo 10 >"$W/sys/class/dmi/id/chassis_type"; hw hw_is_laptop; eq "$RC" 0 "chassis: notebook"
echo 3 >"$W/sys/class/dmi/id/chassis_type"; hw hw_is_laptop; eq "$RC" 1 "chassis: desktop"

# ── radios, sound, CPU ───────────────────────────────────────────────────────
case_ "hw_has_wifi / hw_has_sof / hw_cpu_vendor"
hw hw_has_wifi; eq "$RC" 1 "no radio"; hw_wifi; hw hw_has_wifi; eq "$RC" 0 "a radio (phy0)"
hw hw_has_sof; eq "$RC" 1
mkdir -p "$W/sys/bus/pci/drivers/sof-audio-pci-intel-tgl/0000:00:1f.3"; hw hw_has_sof; eq "$RC" 0
hw_amd; sed -i 's/GenuineIntel/AuthenticAMD/' "$W/proc/cpuinfo"; hw hw_cpu_vendor; eq "$OUT" AuthenticAMD
hw_intel; hw hw_cpu_vendor; eq "$OUT" GenuineIntel
: >"$W/proc/cpuinfo"; hw hw_cpu_vendor; eq "$OUT" "" "no vendor line: nothing (no microcode guessed)"

# ── firmware the kernel asked for ────────────────────────────────────────────
kmsg() { printf '%s\n' "$@" >"$FKH/kmsg"; }
case_ "hw_missing_firmware: each Wi-Fi chip's file, only 'not found' (-2), names checked, once each"
kmsg '[    3.1] iwlwifi 0000:00:14.3: Direct firmware load for iwlwifi-so-a0-gf-a0-89.ucode failed with error -2' \
     '[    3.1] iwlwifi 0000:00:14.3: Direct firmware load for iwlwifi-so-a0-gf-a0-89.ucode failed with error -2' \
     '[    3.2] rtw89_8852be 0000:04:00.0: Direct firmware load for rtw89/rtw8852b_fw-1.bin failed with error -2' \
     '[    3.3] mt7921e 0000:05:00.0: Direct firmware load for mediatek/WIFI_RAM_CODE_MT7961_1.bin failed with error -2' \
     '[    3.4] amdgpu 0000:03:00.0: Direct firmware load for amdgpu/gc_11_0_0_mes.bin failed with error -22' \
     '[    3.5] evil: Direct firmware load for ../../etc/shadow failed with error -2' \
     '[    3.6] odd: Direct firmware load for $(touch /tmp/kawa-hw-pwned) failed with error -2' \
     '[    3.7] Bluetooth: hci0: Direct firmware load for intel/ibt-0040-0041.sfi failed with error -2'
hw hw_missing_firmware
eq "$OUT" "$(printf '%s\n' intel/ibt-0040-0041.sfi iwlwifi-so-a0-gf-a0-89.ucode mediatek/WIFI_RAM_CODE_MT7961_1.bin rtw89/rtw8852b_fw-1.bin)"
[[ ! -e /tmp/kawa-hw-pwned ]] && _ok || { _no "a firmware name ran as a command"; rm -f /tmp/kawa-hw-pwned; }
case_ "hw_firmware_pkgs: the packages that provide them — not one whose file is on disk since this boot"
fkh fwfiles "iwlwifi-mvm-firmware /usr/lib/firmware/iwlwifi-so-a0-gf-a0-89.ucode.xz" \
            "realtek-firmware /usr/lib/firmware/rtw89/rtw8852b_fw-1.bin.xz" \
            "mt7xxx-firmware /usr/lib/firmware/mediatek/WIFI_RAM_CODE_MT7961_1.bin.xz" \
            "intel-bt-firmware /usr/lib/firmware/intel/ibt-0040-0041.sfi.xz"
hw hw_firmware_pkgs
eq "$OUT" "$(printf '%s\n' intel-bt-firmware iwlwifi-mvm-firmware mt7xxx-firmware realtek-firmware)"
mkdir -p "$W/root/fw/rtw89"; : >"$W/root/fw/rtw89/rtw8852b_fw-1.bin.xz"
fkrun env HW_FW=/root/fw bash -c '. "$1"; hw_firmware_pkgs' _ "$LIBHW"
lacks "$OUT" realtek-firmware "installed since this boot"; has "$OUT" iwlwifi-mvm-firmware
reset_calls; hw hw_firmware_pkgs -C; called 'dnf\] -q -C repoquery'
case_ "hw_firmware_pkgs offline: nothing (and no error)"
fkh net off; hw hw_firmware_pkgs; eq "$RC" 0
rm -f "$FKH/net"
case_ "no firmware missing, no kernel log at all: nothing"
rm -f "$FKH/kmsg"; hw hw_missing_firmware; eq "$OUT" ""; eq "$RC" 0

# ── what each machine needs ──────────────────────────────────────────────────
case_ "hw_wanted: an AMD desktop on ethernet — its microcode only"
world fresh; hw hw_wanted; eq "$OUT" amd-ucode-firmware
case_ "hw_wanted: an Intel laptop with Wi-Fi, Intel's audio DSP and a radio missing its firmware"
hw_intel; hw_wifi; mkdir -p "$W/sys/bus/pci/drivers/sof-audio-pci-intel-tgl/0000:00:1f.3"
kmsg '[ 3.1] iwlwifi 0000:00:14.3: Direct firmware load for iwlwifi-so-a0-gf-a0-89.ucode failed with error -2'
hw hw_wanted
eq "$OUT" "$(printf '%s\n' microcode_ctl NetworkManager-wifi wireless-regdb alsa-sof-firmware iwlwifi-mvm-firmware)"
case_ "hw_wanted: Intel's graphics beside the AMD card the desktop drives — Intel's video decoding too"
world fresh; hw_igpu_amd; echo amd >"$W/var/lib/fedokawaii/gpu"; hw hw_wanted; has "$OUT" intel-media-driver
echo intel >"$W/var/lib/fedokawaii/gpu"; hw hw_wanted; lacks "$OUT" intel-media-driver "(an Intel build has it from the manifest)"

# ── devices with no driver ───────────────────────────────────────────────────
case_ "hw_driverless: network, display, sound, USB without a driver are named; bridges and the like never"
world fresh; P=$W/sys/bus/pci/devices
pcidev() { mkdir -p "$P/$1"; echo "$2" >"$P/$1/class"; echo "$3" >"$P/$1/vendor"; echo "$4" >"$P/$1/device"; }
pcidev 0000:06:00.0 0x028000 0x14c3 0x7925                   # a Wi-Fi card this kernel has no driver for
pcidev 0000:00:01.0 0x060400 0x1022 0x14ab                   # a PCI bridge
pcidev 0000:00:14.0 0x0c0330 0x8086 0x7ae0                   # a USB controller
pcidev 0000:00:14.3 0x0c0500 0x8086 0x7aa3                   # SMBus: needs nothing of ours
hw hw_driverless
has "$OUT" "0000:06:00.0 0x028000 0x14c3:0x7925"; has "$OUT" "0000:00:14.0 0x0c0330"
lacks "$OUT" "0000:00:01.0"; lacks "$OUT" "0000:00:14.3"; lacks "$OUT" "0000:03:00.0" "the AMD card has amdgpu"

case_ "hw_fw_updates: fwupd's list, by device; none or no fwupdmgr: nothing"
fkh fwupd.json '{"Devices":[{"Name":"Samsung SSD 990 PRO","Releases":[{"Version":"4B2QJXD7"}]},{"Name":"Mouse","Releases":[]}]}'
hw hw_fw_updates; eq "$OUT" "Samsung SSD 990 PRO: 4B2QJXD7"
rm -f "$FKH/fwupd.json"; hw hw_fw_updates; eq "$OUT" ""; eq "$RC" 0

# ── what check.sh says of each machine ───────────────────────────────────────
chk() { fkrun bash /home/fkuser/fedokawaii/check.sh; }
case_ "check: an AMD desktop — ready; an AMD card without amdgpu — not"
world fresh; chk; eq "$RC" 0; has "$OUT" "✔  AMD GPU on the amdgpu driver"
hw_nogpu; gpu card0 0x1002 0x73df radeon 12868124672; chk; eq "$RC" 1; has "$OUT" "✘  AMD GPU found but amdgpu is not driving it"
case_ "check: Intel; Intel + NVIDIA (a laptop's) — ready, built for Intel"
hw_intel; chk; eq "$RC" 0; has "$OUT" "✔  Intel GPU"
hw_hybrid; chk; eq "$RC" 0; has "$OUT" "✔  Intel GPU"
case_ "check: NVIDIA alone — not ready, said why (Secure Boot on or off alike)"
hw_nvidia; hw_secureboot; chk; eq "$RC" 1; has "$OUT" "✘  NVIDIA only"; has "$OUT" "Secure Boot on"
case_ "check: a virtual machine — not ready, said why (even with GPU= set)"
hw_vm; chk; eq "$RC" 1; has "$OUT" "✘  a virtual machine's display"
sed -i 's/^GPU=.*/GPU="intel"/' "$W/home/fkuser/fedokawaii/fedokawaii.conf"; chk; eq "$RC" 1; has "$OUT" "virtual machine"
case_ "check: the test harness's VM (its marker: tools/vm-smoke.sh) — a warning, ready; the marker with a real card changes nothing"
sed -i 's/^GPU=.*/GPU="auto"/' "$W/home/fkuser/fedokawaii/fedokawaii.conf"
mkdir -p "$W/var/lib/fedokawaii" && touch "$W/var/lib/fedokawaii/test-vm"
hw_vm; chk; eq "$RC" 0; has "$OUT" "!  a virtual machine's display"; has "$OUT" "test harness"
hw_intel; chk; eq "$RC" 0; has "$OUT" "✔  Intel GPU"; lacks "$OUT" "test harness"
rm -f "$W/var/lib/fedokawaii/test-vm"
case_ "check: no card the kernel drives — not ready; with GPU= set, a warning and ready (setup installs its drivers)"
sed -i 's/^GPU=.*/GPU="auto"/' "$W/home/fkuser/fedokawaii/fedokawaii.conf"
hw_nogpu; chk; eq "$RC" 1; has "$OUT" "✘  no AMD or Intel GPU seen by the kernel"; has "$OUT" "set GPU= in fedokawaii.conf"
sed -i 's/^GPU=.*/GPU="amd"/' "$W/home/fkuser/fedokawaii/fedokawaii.conf"; chk; eq "$RC" 0; has "$OUT" "!  no GPU seen by the kernel — GPU=amd"
case_ "check: GPU= naming another card than the machine's: a warning"
hw_amd; sed -i 's/^GPU=.*/GPU="intel"/' "$W/home/fkuser/fedokawaii/fedokawaii.conf"; chk; has "$OUT" "!  GPU=intel in fedokawaii.conf — but this machine's card is amd"
case_ "check: a laptop is said (the tuning is a desktop's); a desktop with a mouse's battery is not"
world fresh; hw_laptop; chk; eq "$RC" 0; has "$OUT" "!  a laptop"
world fresh; mkdir -p "$W/sys/class/power_supply/hidpp_battery_0"; echo Battery >"$W/sys/class/power_supply/hidpp_battery_0/type"
echo Device >"$W/sys/class/power_supply/hidpp_battery_0/scope"; chk; lacks "$OUT" "a laptop"
case_ "check: BIOS or UEFI, Secure Boot on or off — all fine, each said"
world fresh; chk; has "$OUT" "UEFI boot · Secure Boot state unknown"
hw_secureboot; chk; has "$OUT" "Secure Boot on"
printf '\x06\x00\x00\x00\x00' >"$W/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c"; chk; has "$OUT" "Secure Boot off"
hw_bios; chk; eq "$RC" 0; has "$OUT" "legacy BIOS boot (fine)"
case_ "check: a Wi-Fi radio and its missing firmware are said (setup adds both)"
world fresh; hw_wifi; kmsg '[ 3.1] iwlwifi 0000:00:14.3: Direct firmware load for iwlwifi-so-a0-gf-a0-89.ucode failed with error -2'
chk; has "$OUT" "a Wi-Fi radio — setup adds NetworkManager's Wi-Fi part"; has "$OUT" "iwlwifi-so-a0-gf-a0-89.ucode"

case_ "hw_gpu with no card at all, under setup's own options (errexit, errtrace, pipefail, an ERR trap): 'none', no trap"
hw_nogpu; fkrun bash -c 'set -Eeuo pipefail; trap "echo TRAPPED" ERR; . "$1"; v=$(hw_gpu); echo "gpu=$v"' _ "$LIBHW"
has "$OUT" "gpu=none"; lacks "$OUT" "TRAPPED"

done_
