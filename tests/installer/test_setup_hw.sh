#!/usr/bin/env bash
# tests/installer/test_setup_hw.sh — setup.sh on the machines and networks a first install may
# meet: a Wi-Fi-only desktop set up over a phone's USB tethering (its radio's firmware missing
# until phase 2, NetworkManager's Wi-Fi part added once the radio shows), Codeberg slow to
# answer the dwl fetch, the network gone after a restart, a machine already named / named
# localhost / one that cannot be named, a BIOS install (no grubby until phase 1 brings it),
# Secure Boot with NVIDIA alone, a laptop's Intel + NVIDIA, and a Windows beside it (dual boot).
. "$(dirname "$0")/lib.sh"
CLONE=/home/fkuser/fedokawaii
TK=/usr/local/lib/fedokawaii
setup() { fkrun bash "$CLONE/setup.sh" "$@"; }
resume() { fkrun bash "$TK/setup.sh" --resume "$@"; }
iwl='[    3.1] iwlwifi 0000:00:14.3: Direct firmware load for iwlwifi-so-a0-gf-a0-89.ucode failed with error -2'

# ── a Wi-Fi-only desktop, set up over USB tethering ──────────────────────────
world fresh; releases
fkh kmsg "$iwl"                                      # the radio is there, its firmware is not: no phy yet
fkh route-dev enp0s20f0u1; fkh nm-devices "ethernet:connected" "wifi:unavailable"
fkh hostname mydesk
case_ "Wi-Fi only, phase 1: ready over the phone's tethering; the radio and its missing firmware said"
setup --no-reboot; eq "$RC" 0
has "$OUT" "✔ default route (enp0s20f0u1)"; has "$OUT" "iwlwifi-so-a0-gf-a0-89.ucode"
eq "$(cat "$FKH/hostname")" mydesk "a machine already named keeps its name"
lacks "$OUT" "the machine's name: fedokawaii"
reboot_world; keep wifi-p2
case_ "Wi-Fi only, phase 2: the radio's firmware installed (found from the kernel's log); its Wi-Fi part waits for the radio"
resume --no-reboot; eq "$RC" 0
pkg_has iwlwifi-mvm-firmware && _ok || _no "the firmware not installed"
pkg_has NetworkManager-wifi && _no "NetworkManager-wifi before the radio showed" || _ok
has "$(state hardware-pkgs)" iwlwifi-mvm-firmware
case_ "Wi-Fi only, phase 3 after the restart (the radio up now) — and Codeberg failing twice: retried, built"
reboot_world; hw_wifi; fkh kmsg ""; fkh fail-git-fetch 2
resume --no-reboot; eq "$RC" 0 "$(grep '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
has "$OUT" "attempt 1/3 failed: as_user git -C /home/fkuser/.local/src/dwl fetch"; has "$OUT" "✔ 3.02 dwl"
pkg_has NetworkManager-wifi && pkg_has wireless-regdb && _ok || _no "the Wi-Fi part not added at the gate"
has "$(state hardware-pkgs)" NetworkManager-wifi
eq "$(state phase)" "done"
has "$(cat "$W/etc/NetworkManager/conf.d/90-fedokawaii.conf")" "wifi.powersave = 2"

case_ "the network gone after the restart (the tethered phone unplugged): minutes of tries, then said, and how to go on"
back wifi-p2; fkh net off
resume --no-reboot; eq "$RC" 1
has "$OUT" "no network — connect to one (nmtui), then run it again"; has "$OUT" "restart the computer: setup continues by itself"
n=$(grep -c 'curl\] .*mirrors.fedoraproject.org' "$CALLS"); ((n >= 25)) && _ok || _no "only $n tries after a restart"
eq "$(state phase)" 2
case_ "…typed by you instead: half a minute of tries"
back wifi-p2; fkh net off
setup --no-reboot; eq "$RC" 1
n=$(grep -c 'curl\] .*mirrors.fedoraproject.org' "$CALLS"); ((n <= 7)) && _ok || _no "$n tries for a run you typed"

case_ "dwl's tag moved upstream to another commit: refused before building"
back wifi-p2; resume --no-reboot; reboot_world; keep p3
fkh dnf-fail 'install .*greetd'                       # (nothing after dwl needed here)
fkh tag-v0.9 0000000000000000000000000000000000000000
resume --no-reboot; eq "$RC" 1; has "$OUT" "dwl tag v0.9 does not point at the pinned commit"
[[ ! -e $W/usr/local/bin/dwl ]] && _ok || _no "dwl installed anyway"
case_ "Codeberg down for good: stops with what to do, nothing half-built installed"
back p3; fkh fail-git-fetch 3
resume --no-reboot; eq "$RC" 1; has "$OUT" "could not fetch dwl from codeberg.org — try again in a while"
has "$OUT" "attempt 3/3 failed"
[[ ! -e $W/usr/local/bin/dwl ]] && _ok || _no "dwl installed anyway"

# ── the machine's name ───────────────────────────────────────────────────────
world fresh; releases
setup --no-reboot; keep named          # (phase 1 done: each case runs its 1.5 again)
rerun_base() { back named; echo 1 >"$W/var/lib/fedokawaii/phase"; rm -f "$W/var/lib/fedokawaii/done.1.5 base packages"; }
case_ "named localhost, or localhost.localdomain (DHCP's or the installer's default): given its own"
for h in localhost localhost.localdomain; do
  rerun_base; fkh hostname "$h"; setup --no-reboot
  eq "$(cat "$FKH/hostname")" fedokawaii "$h"; has "$OUT" "the machine's name: fedokawaii"
done
case_ "the name cannot be set (hostnamed not answering): said, and setup goes on"
rerun_base; rm -f "$FKH/hostname"; fkh rc-hostnamectl 1
setup --no-reboot; eq "$RC" 0; has "$OUT" "could not name the machine"; has "$OUT" "✔ 1.5 base packages"

# ── BIOS, Secure Boot, NVIDIA, Intel + NVIDIA ────────────────────────────────
case_ "a BIOS install: no grubby at first; phase 1 brings it, phase 2's kernel argument works"
world fresh; releases; hw_bios
pkg_has grubby && _no "the BIOS machine has grubby already" || _ok
setup --no-reboot; eq "$RC" 0; has "$OUT" "legacy BIOS boot (fine)"
pkg_has grubby && pkg_has tar && _ok || _no "grubby and tar not installed in phase 1"
reboot_world; resume --no-reboot; eq "$RC" 0
has "$(cat "$FKH/grub-args")" "amdgpu.ppfeaturemask=0xfff7ffff"
case_ "Secure Boot on, NVIDIA alone: the check refuses before anything is installed (exit 1)"
world fresh; releases; hw_nvidia; hw_secureboot
setup --no-reboot; eq "$RC" 1
has "$OUT" "✘ NVIDIA only"; has "$OUT" "Secure Boot on"; has "$OUT" "this machine is not ready"
not_called 'dnf\] -y'; eq "$(state user)" "" "nothing recorded"
case_ "a laptop's Intel + NVIDIA, Secure Boot on: built for Intel (no amdgpu argument), Intel's microcode; the laptop said"
world fresh; releases; hw_hybrid; hw_secureboot; mkdir -p "$W/sys/class/power_supply/BAT0"; echo Battery >"$W/sys/class/power_supply/BAT0/type"
setup --no-reboot; eq "$RC" 0; has "$OUT" "! a laptop"
reboot_world; resume --no-reboot; eq "$RC" 0
eq "$(state gpu)" intel; pkg_has intel-media-driver && pkg_has microcode_ctl && _ok || _no "Intel's packages missing"
lacks "$(cat "$FKH/grub-args")" "amdgpu"; pkg_has lact && _no "LACT (AMD's) installed" || _ok

# ── dual boot ────────────────────────────────────────────────────────────────
case_ "a Windows beside it: the boot menu stays shown (never hidden), the other system recorded and said"
world fresh; releases
fkh os-prober "/dev/nvme0n1p1@/efi/Microsoft/Boot/bootmgfw.efi:Windows Boot Manager:Windows:efi"
setup --no-reboot; eq "$RC" 0
has "$OUT" "this machine also starts Windows Boot Manager — the boot menu stays shown"
lacks "$(cat "$FKH/grubenv" 2>/dev/null)" "menu_auto_hide=1"; eq "$(state other-os)" "Windows Boot Manager"
called 'grub2-editenv\] - unset menu_auto_hide'

done_
