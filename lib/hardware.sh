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

hw_cpu_vendor()  { awk -F': *' '/^vendor_id/ { print $2; exit }' /proc/cpuinfo 2>/dev/null; }
hw_has_wifi()    { compgen -G '/sys/class/ieee80211/*' >/dev/null; }
hw_has_sof()     { compgen -G '/sys/bus/pci/drivers/sof-audio-pci-intel-*/0000:*' >/dev/null; }
hw_gpu_vendors() { cat /sys/class/drm/card[0-9]*/device/vendor 2>/dev/null | sort -u; }

# firmware files the kernel could not load this boot: names only, checked to be plain
# relative paths (they become package queries and a file test, nothing else)
hw_missing_firmware() {
  journalctl -k -b -o cat --no-pager 2>/dev/null \
    | sed -n 's/.*Direct firmware load for \([^ ]*\) failed with error -2.*/\1/p' \
    | grep -E '^[A-Za-z0-9._+-]+(/[A-Za-z0-9._+-]+)*$' | grep -v '\.\.' | sort -u || true
}
# … of those, the ones still not on disk, and the packages that provide them. A file no
# package has is a driver asking for a newer version first; it then loads one it has.
# CACHE=-C: from dnf's cached metadata only (verify, offline); empty: refreshed (setup)
hw_firmware_pkgs() {
  local f cache=${1:-}
  while IFS= read -r f; do
    [[ -n $f ]] || continue
    compgen -G "/usr/lib/firmware/$f*" >/dev/null && continue     # (installed since this boot)
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
