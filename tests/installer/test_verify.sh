#!/usr/bin/env bash
# tests/installer/test_verify.sh — verify.sh on a finished install (the fake machine): every check
# passes on a sound system (exit 0); warnings never fail it (exit 0, counted); each failure is
# named and makes exit 3; --pre-finalize (setup's gate) leaves out what comes after it; misuse
# is exit 2. Then the recent ones by name: the firewall (a warning when firewalld is off), the
# render node of the card the desktop is built for (Intel's graphics first, AMD's second),
# the boot checks skipped while the theme could not make the boot menu, a laptop's backlight
# as brightness control, a dual boot's menu, the user units Fedora's presets enable, the ROCm
# SMI library btop opens an AMD card through (a warning when rocm-smi renames it); what
# it waits for said before it waits (Prowlarr's first start).
. "$(dirname "$0")/lib.sh"
TK=/usr/local/lib/fedokawaii
V() { fkrun bash "$TK/verify.sh" "$@"; }
line() { grep -F -- "$1" <<<"$OUT" | head -n1; }      # the report line holding TEXT

world built
keep built

# ── a sound system ───────────────────────────────────────────────────────────
case_ "a finished install: everything passes (exit 0), the outcome recorded for the menu"
V; eq "$RC" 0 "$(grep '✘' <<<"$OUT" | head -n4 | tr '\n' '|')"
has "$OUT" "✔ verified"; lacks "$OUT" "✘"
read -r t p f w <"$W/var/lib/fedokawaii/last-verify"
[[ $t =~ ^[0-9]+$ ]] && ((p > 100)) && _ok || _no "last-verify: $t $p $f $w"; eq "$f" 0
has "$OUT" "✔ all " ; has "$OUT" "manifest packages installed"
has "$OUT" "✔ user unit wireplumber.service enabled"; has "$OUT" "✔ hardware decode: H264High"
has "$OUT" "✔ torrent port 6881 open"; has "$OUT" "✔ firewall: no ssh / cockpit"
has "$OUT" "✔ ROCm SMI library for btop (librocm_smi64.so.1.0)"
has "$OUT" "✔ restic runs (backups to another disk: kawa-backup)"   # (the exclude list is the theme's: test_theme.sh)
has "$OUT" "✔ Syncplay v1.7.6 loads (Fedora's python3, Twisted with TLS, certifi, pem)"; has "$OUT" "✔ syncplay runs without a window"
has "$OUT" "✔ user in video, render"; lacks "$OUT" "input, render"
has "$OUT" "✔ Bluetooth dongle power saving off (btusb)"; has "$OUT" "✔ shutdown waits 30 s at most for your services"

case_ "Prowlarr not running: verify says it starts it, and why that may take a while, before it waits"
i=$(grep -n "· starting Prowlarr to check it — its first start after a boot can take a minute or two" <<<"$OUT" | cut -d: -f1)
s=$(grep -n "✔ Prowlarr starts" <<<"$OUT" | cut -d: -f1)
[[ -n $i && -n $s ]] && ((i < s)) && _ok || _no "the line before the start: [$i] [$s]"
case_ "…already running: nothing to wait for, so nothing said"
fkh_add units "user-active prowlarr.service"
V; eq "$RC" 0; lacks "$OUT" "starting Prowlarr"; has "$OUT" "✔ Prowlarr starts"

# ── warnings: never a failure ────────────────────────────────────────────────
case_ "warnings only (no firewall running, no AV1 decoding, GE-Proton not yet, the file dialog not built, Syncplay not yet, a driver package missing): exit 0"
back built
fkh firewalld-down
printf '      VAProfileH264High   : VAEntrypointVLD\n      VAProfileHEVCMain   : VAEntrypointVLD\n' >"$FKH/vainfo-renderD128"
rm -f "$W/home/fkuser/.local/share/fedokawaii/upstream/ge-proton" "$W/usr/local/libexec/xdg-desktop-portal-termfilechooser"
rm -f "$W/home/fkuser/.local/share/fedokawaii/upstream/syncplay"
fkh kmsg '[ 3.1] iwlwifi 0000:00:14.3: Direct firmware load for iwlwifi-so-a0-gf-a0-89.ucode failed with error -2'
fkh fwfiles "iwlwifi-mvm-firmware /usr/lib/firmware/iwlwifi-so-a0-gf-a0-89.ucode.xz"
V; eq "$RC" 0 "$(grep '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
has "$OUT" "! no firewall running (firewalld)"; lacks "$OUT" "torrent port 6881"; lacks "$OUT" "firewall: no ssh"
has "$OUT" "! no AV1 hardware decode"; has "$OUT" "! GE-Proton not installed yet"
has "$OUT" "! yazi file dialog not built"; has "$OUT" "! driver packages this machine needs — iwlwifi-mvm-firmware"
has "$OUT" "! Syncplay not installed yet"
has "$OUT" "warning(s)"; read -r _ _ _ w <"$W/var/lib/fedokawaii/last-verify"; ((w >= 5)) && _ok || _no "$w warnings recorded"

# ── failures: each named, exit 3 ─────────────────────────────────────────────
case_ "a damaged system: each failure named in place and in the list at the end, exit 3"
back built
fkh_del installed grubby man-db                                           # the base tools, gone
fkh_add installed nano; fkh_add userinstalled "htop User"; fkh_add installed htop   # forbidden; extra
fkh_del units "global-enabled wireplumber.service"                         # Fedora's preset undone
fkh fw-services dhcpv6-client ssh                                          # SSH_SERVER=no, ssh open
fkh kernels "6.18.1-200.fc44.x86_64" "6.18.2-200.fc44.x86_64" "6.18.44-fc-v114"
rm -f "$FKH/vainfo-renderD128"                                             # no VA-API driver
fkh scrub-status $'Scrub started: x\nError summary:    csum=3\n  Corrected:      0\n  Uncorrectable:  3'
echo 'PROWLARR_API_KEY=short' >"$W/home/fkuser/.config/fedokawaii/secrets.sh"
echo 1 >"$FKH/rc-restic"                                                   # restic broken
echo 1111111111111111111111111111111111111111 >"$W/home/fkuser/.local/share/fedokawaii/upstream/syncplay"   # an older pin
fkh_add installed systemd-oomd-defaults                                    # oomd's rules: a whole-session kill
fkh_add units "global-enabled grub-boot-success.timer"                     # any boot would count as successful
rm -f "$W/etc/modprobe.d/fedokawaii-btusb.conf" "$W/etc/systemd/system/user@.service.d/fedokawaii.conf"
V; eq "$RC" 3
has "$(line "✘ missing packages")" grubby; has "$(line "✘ missing packages")" man-db
has "$OUT" "✘ forbidden packages present — nano"; has "$(line "✘ forbidden packages present")" systemd-oomd-defaults
has "$OUT" "✘ Bluetooth dongle power saving off (btusb)"; has "$OUT" "✘ shutdown waits 30 s at most for your services"
has "$OUT" "✘ installed outside the manifest — htop"
has "$OUT" "✘ user unit wireplumber.service enabled"
has "$OUT" "✘ firewall: no ssh / cockpit"
has "$OUT" "✘ at most two kernels"
has "$OUT" "✘ hardware decode — vainfo found no VA-API driver on /dev/dri/renderD128"
has "$OUT" "✘ the last scrub found errors"
has "$OUT" "✘ Prowlarr key in secrets.sh"
has "$OUT" "✘ restic runs"
has "$OUT" "✘ Syncplay is not the pinned v1.7.6"
has "$OUT" "✘ boot success marked by the desktop, not at boot"
has "$OUT" "checks failed:"; has "$OUT" "most of these fix themselves: fedokawaii repair"
read -r _ _ f _ <"$W/var/lib/fedokawaii/last-verify"; ((f >= 11)) && _ok || _no "$f failures recorded"
case_ "in the input group by your own choice (a controller, handbook §21.1): no failure"
back built; fk usermod -aG input fkuser
V; eq "$RC" 0 "$(grep '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"; has "$OUT" "✔ user in video, render"
case_ "a package Fedora retired (named by the last update) is a warning, not a failure"
back built; fkh_del installed man-db; echo man-db >"$W/var/lib/fedokawaii/unavailable"
V; eq "$RC" 0; has "$OUT" "! no longer in Fedora (renamed or retired) — man-db"
case_ "rpm's database broken: said, never a pass"
back built; fkh rpm-broken
V; eq "$RC" 3; has "$OUT" "✘ manifest packages: rpm gave no answer"; has "$OUT" "✘ forbidden packages: rpm gave no answer"
lacks "$OUT" "✔ all "
case_ "one boot entry without the console argument (a kernel added by hand, say): named, exit 3"
back built; sed -i '2 s/ systemd.tty.term.console=dumb//' "$FKH/grub-args"
V; eq "$RC" 3; has "$OUT" "✘ no console-size wait at boot (systemd.tty.term.console=dumb on every entry)"
has "$OUT" "✔ amdgpu.ppfeaturemask on the kernel" "the other argument's check unmoved"
case_ "a kernel whose boot image dracut could not make (dnf does not fail on that): named, exit 3"
back built; fkh kernels "6.18.1-200.fc44.x86_64" "$(uname -r)"              # the older one at rest, no image for it
V; eq "$RC" 3; has "$OUT" "✘ kernels without a boot image (initramfs) — 6.18.1-200.fc44.x86_64 — would not start; repair makes them (dracut)"
echo initramfs >"$W/boot/initramfs-6.18.1-200.fc44.x86_64.img"
V; eq "$RC" 0 "$(grep '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"; has "$OUT" "✔ every kernel has its boot image (initramfs)"

# ── setup's gate, and misuse ─────────────────────────────────────────────────
case_ "--pre-finalize (setup's gate): the login and snapshots not yet looked at; nothing recorded for the menu"
back built; rm -f "$W/etc/systemd/system/display-manager.service" "$W/var/lib/fedokawaii/last-verify"
fkh_del units "enabled greetd.service" "enabled snapper-timeline.timer" "enabled snapper-cleanup.timer"
V --pre-finalize; eq "$RC" 0 "$(grep '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
has "$OUT" "✔ the login is greetd's alone"; lacks "$OUT" "greetd.service enabled"; lacks "$OUT" "snapshots"
[[ ! -e $W/var/lib/fedokawaii/last-verify ]] && _ok || _no "the gate's run was recorded for the menu"
V; eq "$RC" 3 "without --pre-finalize those are failures"; has "$OUT" "✘ the login is no login manager at all"
case_ "misuse: an unknown option, not root, setup not started (exit 2); --help (0)"
V --frobnicate; eq "$RC" 2; has "$OUT" "unknown option"
fkrun runuser -u fkuser -- bash "$TK/verify.sh"; eq "$RC" 2; has "$OUT" "run with sudo"
mv "$W/var/lib/fedokawaii/user" "$W/var/lib/fedokawaii/user.away"; V; eq "$RC" 2; has "$OUT" "setup has not started"
mv "$W/var/lib/fedokawaii/user.away" "$W/var/lib/fedokawaii/user"
V --help; eq "$RC" 0; has "$OUT" "--pre-finalize"

# ── the GPU's render node ────────────────────────────────────────────────────
case_ "Intel's graphics switched on beside the AMD card: AMD's render node is the one checked"
back built; hw_igpu_amd                      # card0 (Intel, renderD128) first, card1 (AMD, renderD129)
rm -f "$FKH/vainfo-renderD128"
printf '      VAProfile%s   : VAEntrypointVLD\n' H264High HEVCMain AV1Profile0 >"$FKH/vainfo-renderD129"
V; has "$OUT" "✔ hardware decode: H264High"; has "$OUT" "✔ hardware decode: AV1Profile0"
case_ "…built for Intel instead: Intel's node"
echo intel >"$W/var/lib/fedokawaii/gpu"; rm -f "$FKH/vainfo-renderD129"
printf '      VAProfile%s   : VAEntrypointVLD\n' H264High HEVCMain >"$FKH/vainfo-renderD128"
V; has "$OUT" "✔ hardware decode: H264High"; lacks "$OUT" "amdgpu.ppfeaturemask"
lacks "$OUT" "ROCm SMI" "an Intel machine is not asked for AMD's library"

# ── btop's view of the AMD card ──────────────────────────────────────────────
case_ "rocm-smi ships the library under another name: a warning (btop finds no GPU), never a failure"
back built; fkh files "rocm-smi /usr/lib64/librocm_smi64.so.2.0"
V; eq "$RC" 0 "$(grep '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
has "$OUT" "! btop's view of the card — rocm-smi has no librocm_smi64.so.1.0"; lacks "$OUT" "✔ ROCm SMI library"

# ── the boot menu ────────────────────────────────────────────────────────────
case_ "one system, not themed: Fedora's hidden menu is checked"
back built; V; has "$OUT" "✔ GRUB menu hidden (shows after a failed boot)"
case_ "a Windows beside it (setup left the menu shown): the shown menu is checked, and passes"
echo "Windows Boot Manager" >"$W/var/lib/fedokawaii/other-os"; fkh grubenv ""
V; eq "$RC" 0; has "$OUT" "✔ GRUB menu shown (this machine also starts Windows Boot Manager)"
fkh grubenv "menu_auto_hide=1"; V; eq "$RC" 3; has "$OUT" "✘ GRUB menu shown (this machine also starts"

# ── the live session (you are logged in) ─────────────────────────────────────
case_ "a laptop: its own screen's backlight counts as brightness control (no DDC/CI monitor needed)"
back built; hw_laptop; fkh procs "/usr/local/bin/dwl"
V; has "$OUT" "live session"; has "$OUT" "✔ the laptop's own screen: brightness through its backlight"
case_ "a desktop whose monitor does not answer DDC/CI: a warning saying what to switch on — also when its firmware lists a backlight (acpi_video0) with no panel"
back built; fkh procs "/usr/local/bin/dwl"
V; has "$OUT" "! no monitor answered DDC/CI — switch DDC/CI on in the monitor's on-screen menu"
mkdir -p "$W/sys/class/backlight/acpi_video0"
V; has "$OUT" "! no monitor answered DDC/CI"; lacks "$OUT" "the laptop's own screen" "an external monitor is not the laptop's screen"
case_ "a monitor that answers DDC/CI: passes"
rm -f "$W/usr/local/bin/ddcutil"; cat >"$W/usr/local/bin/ddcutil" <<'EOF'
#!/bin/bash
echo "Display 1"
EOF
chmod 755 "$W/usr/local/bin/ddcutil"
V; has "$OUT" "✔ a monitor answers DDC/CI"

# ── Wi-Fi ────────────────────────────────────────────────────────────────────
case_ "a Wi-Fi radio NetworkManager does not manage: a failure"
back built; hw_wifi; fkh nm-devices "ethernet:connected" "wifi:unmanaged"
V; has "$OUT" "✘ Wi-Fi managed by NetworkManager"
fkh nm-devices "ethernet:connected" "wifi:disconnected"; V; has "$OUT" "✔ Wi-Fi managed by NetworkManager"

# ── DNF's settings ───────────────────────────────────────────────────────────
case_ "Node 22 as a weak dependency: kept out by DNF's settings (both names), else a failure"
back built; V; has "$OUT" "✔ dnf never takes Node 22 as a weak dependency"
sed -i '/^exclude_from_weak=/d' "$W/etc/dnf/libdnf5.conf.d/90-fedokawaii.conf"
V; eq "$RC" 3; has "$OUT" "✘ dnf never takes Node 22 as a weak dependency"
echo 'exclude_from_weak=nodejs22*' >>"$W/etc/dnf/libdnf5.conf.d/90-fedokawaii.conf"
V; has "$OUT" "✘ dnf never takes Node 22 as a weak dependency" "Fedora 45's package named nodejs left out"

done_
