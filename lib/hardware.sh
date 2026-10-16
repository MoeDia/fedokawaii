#!/usr/bin/env bash
# lib/hardware.sh — this machine's own drivers and firmware.
#
# The kernel brings the drivers; what Fedora ships apart from it is found here from the
# hardware itself, so a new card, dongle or CPU works the day it is plugged in:
#   · firmware the kernel asked for and did not find (its own log, this boot), installed
#     from whichever Fedora package provides that file — Intel's Wi-Fi and Bluetooth
#     firmware among them: linux-firmware does not bring those by itself
#   · the CPU's microcode (Intel: microcode_ctl · AMD: amd-ucode-firmware)
#   · Wi-Fi: NetworkManager's Wi-Fi part and the regulatory database, once a radio is there
#   · Intel's audio DSP (SOF): its firmware, when that driver holds the sound card
#   · an Intel GPU beside the AMD card the desktop drives: Intel's video decoding too
# What is installed here is recorded in /var/lib/fedokawaii/hardware-pkgs, and from then on
# belongs to the manifest (lib/manifest.sh, manifest_all): verify counts it as the
# desktop's, never as something you added. Firmware inside devices (the SSD's, the
# motherboard's) comes from fwupd: listed by update, applied only by you (fwupdmgr update).
#
# Read-only here (check.sh and verify.sh use these); setup.sh's s_hardware installs.

HW_FW=${HW_FW:-/usr/lib/firmware}   # where the firmware packages put their files

hw_cpu_vendor()  { awk -F': *' '/^vendor_id/ { print $2; exit }' /proc/cpuinfo 2>/dev/null; }
hw_has_wifi()    { compgen -G '/sys/class/ieee80211/*' >/dev/null; }
hw_has_sof()     { compgen -G '/sys/bus/pci/drivers/sof-audio-pci-intel-*/0000:*' >/dev/null; }
# (the glob only finds cards: a connector — card0-DP-1 — has no vendor file beneath it)
hw_gpu_vendors() { cat /sys/class/drm/card[0-9]*/device/vendor 2>/dev/null | sort -u || true; }   # (no card: nothing, not a failure)

# hw_gpu → the GPU the desktop is built for, from the cards the kernel shows: amd wherever an
# AMD card is (a desktop's discrete card, the CPU's own graphics beside it or not; an APU),
# else intel (a laptop's NVIDIA card beside Intel's graphics stays unused) — or what is
# there instead: nvidia (an NVIDIA card alone: the open drivers this desktop is built on are
# AMD's and Intel's), vm (a virtual machine's display: virtio, QXL, VMware, VirtualBox,
# QEMU's VGA), none (no card the kernel drives)
hw_gpu() {
  local v; v=$(hw_gpu_vendors)
  if grep -qx 0x1002 <<<"$v"; then echo amd
  elif grep -qx 0x8086 <<<"$v"; then echo intel
  elif grep -qx 0x10de <<<"$v"; then echo nvidia
  elif grep -qxE '0x(1af4|1b36|15ad|80ee|1234)' <<<"$v"; then echo vm
  else echo none; fi
}
# hw_discrete_amd — an AMD card with memory of its own (2 GiB or more): not an APU's shared
# memory. mpv's high-quality scaling is written for such a card (theme.sh).
hw_discrete_amd() {
  local d v
  for d in /sys/class/drm/card[0-9]*/device; do
    [[ -r $d/vendor && $(<"$d/vendor") == 0x1002 && -r $d/mem_info_vram_total ]] || continue
    v=$(<"$d/mem_info_vram_total")
    [[ $v =~ ^[0-9]+$ ]] && ((v >= 2147483648)) && return 0
  done
  return 1
}
# hw_is_laptop — a portable: the firmware says so (DMI chassis: portable, laptop, notebook,
# hand-held, sub-notebook, tablet, convertible, detachable) or a battery powers the machine —
# not a wireless mouse's or a headset's battery, which the kernel lists too (scope Device)
hw_is_laptop() {
  local t d
  t=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null) || t=""
  [[ $t =~ ^(8|9|10|11|14|30|31|32)$ ]] && return 0
  for d in /sys/class/power_supply/*; do
    [[ $(cat "$d/type" 2>/dev/null) == Battery && $(cat "$d/scope" 2>/dev/null) != Device ]] && return 0
  done
  return 1
}

# firmware files the kernel could not find this boot (error -2: not there — not -22, a file
# there that it refused): names only, checked to be plain relative paths (they become
# package queries and a file test, nothing else)
hw_missing_firmware() {
  journalctl -k -b -o cat --no-pager 2>/dev/null \
    | sed -nE 's/.*Direct firmware load for ([^ ]*) failed with error -2([^0-9].*)?$/\1/p' \
    | grep -E '^[A-Za-z0-9._+-]+(/[A-Za-z0-9._+-]+)*$' | grep -v '\.\.' | sort -u || true
}
# … of those, the ones still not on disk, and the packages that provide them. A file no
# package has is a driver asking for a newer version first; it then loads one it has.
# CACHE=-C: from dnf's cached metadata only (verify, offline); empty: refreshed (setup)
hw_firmware_pkgs() {
  local f cache=${1:-}
  while IFS= read -r f; do
    [[ -n $f ]] || continue
    compgen -G "$HW_FW/$f*" >/dev/null && continue                # (installed since this boot)
    # shellcheck disable=SC2086  # $cache: -C or nothing
    # (dnf5: --whatprovides takes one value, a comma list — more words would be package names)
    dnf -q $cache repoquery --qf '%{name}\n' \
      --whatprovides="/usr/lib/firmware/$f,/usr/lib/firmware/$f.xz,/usr/lib/firmware/$f.zst" 2>/dev/null || true
  done < <(hw_missing_firmware) | grep . | sort -u || true
}

# hw_wanted [-C] → every package this machine's hardware needs, one per line
hw_wanted() {
  case $(hw_cpu_vendor) in
    GenuineIntel) echo microcode_ctl ;;
    AuthenticAMD) echo amd-ucode-firmware ;;
  esac
  if hw_has_wifi; then printf '%s\n' NetworkManager-wifi wireless-regdb; fi
  if hw_has_sof; then echo alsa-sof-firmware; fi
  if [[ $(cat "${STATE_DIR:-/var/lib/fedokawaii}/gpu" 2>/dev/null) == amd ]] && grep -qx 0x8086 <<<"$(hw_gpu_vendors)"; then
    echo intel-media-driver
  fi
  hw_firmware_pkgs "${1:-}"
}

# devices on the PCI bus that should have a driver and have none: network, display, sound,
# USB and wireless controllers (bridges and the like need none) → "address class vendor:device"
hw_driverless() {
  local d c
  for d in /sys/bus/pci/devices/*; do
    [[ -e $d/driver ]] && continue
    c=$(<"$d/class") || continue
    case ${c:0:4} in
      0x02|0x03|0x04|0x0d) ;;          # network · display · multimedia · wireless
      0x0c) [[ ${c:0:6} == 0x0c03 ]] || continue ;;   # USB controllers
      *) continue ;;
    esac
    printf '%s %s %s:%s\n' "${d##*/}" "$c" "$(<"$d/vendor")" "$(<"$d/device")"
  done 2>/dev/null
}

# hw_fw_updates → firmware updates fwupd knows of for this machine's devices ("Device: version"),
# from what it fetched last (fwupdmgr refresh, run by update); nothing is ever applied here
hw_fw_updates() {
  command -v fwupdmgr >/dev/null || return 0
  fwupdmgr get-updates --json 2>/dev/null \
    | jq -r '.Devices[]? | select((.Releases // []) | length > 0) | "\(.Name): \(.Releases[0].Version)"' 2>/dev/null || true
}
