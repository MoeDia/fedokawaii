#!/usr/bin/env bash
# tests/installer/test_upkeep.sh — setup.sh's season's update and repair on a finished install
# (the fake machine): offline they say so within half a minute, not after minutes; a package
# transaction cut off half-way is tidied before it is tried again, and a failure never claims
# "nothing was changed"; a fighting service of yours that cannot be disabled (static: D-Bus
# starts it) is masked; your upkeep.conf counts with quotes too. A machine set up earlier:
# taken out of the input group once (never again once you put yourself back), the Bluetooth
# dongle's and the shutdown's settings put back, systemd-oomd's rules taken out.
. "$(dirname "$0")/lib.sh"
TK=/usr/local/lib/fedokawaii
tk() { fkrun bash "$TK/setup.sh" "$@"; }

world built; releases
keep built

case_ "update offline: said within half a minute of tries (exit 1), what to do named"
fkh net off
tk --update; eq "$RC" 1
has "$OUT" "no network — connect to one (nmtui), then run it again"
n=$(grep -c 'curl\] .*mirrors.fedoraproject.org' "$CALLS"); ((n >= 3 && n <= 7)) && _ok || _no "$n tries before giving up (wanted about 6)"
eq "$(cut -d' ' -f2 "$W/var/lib/fedokawaii/last-update")" stopped "recorded as stopped"
case_ "repair offline: about half a minute of tries, then what needs no network"
reset_calls; tk --repair
has "$OUT" "offline: only what needs no network is repaired now"
n=$(grep -c 'curl\] .*mirrors.fedoraproject.org' "$CALLS"); ((n >= 3 && n <= 7)) && _ok || _no "$n tries"
rm -f "$FKH/net"

case_ "update: a transaction cut off half-way leaves packages twice — tidied, and the next try goes through"
back built; fkh fail-dnf-upgrade 1
tk --update; eq "$RC" 0 "$(grep -E '✘|failed' <<<"$OUT" | head -n3 | tr '\n' '|')"
called 'dnf\] -y remove --duplicates'; eq "$(cat "$FKH/dups")" "" "no package left twice"
has "$OUT" "update done"
case_ "update: it fails every time — stopped, the snapshot named as the way back (never 'nothing was changed')"
back built; fkh fail-dnf-upgrade 9
tk --update; eq "$RC" 1
has "$OUT" "dnf could not update"; has "$OUT" "the snapshot taken before it is the way back"; lacks "$OUT" "nothing was changed"

case_ "update with too little room on /: stopped before anything changes, with what to do"
back built; fkh btrfs-free $((5 * 1024 ** 3))
tk --update; eq "$RC" 1; has "$OUT" "only 5.0GB free on / — this needs 10GB: delete old snapshots"
not_called 'snapper\] -c root create'; not_called 'dnf\] .*upgrade'
case_ "…a disk full to the last byte (not even the log can be written): the same sentence, never a raw error"
back built; fkh btrfs-free 0
# (/var/log and /var/lib/fedokawaii, each a full file system of its own holding what it held)
fkrun bash -c 'for d in /var/log /var/lib/fedokawaii; do s=$1/save$RANDOM; cp -a "$d" "$s"
    mount -t tmpfs -o size=1m fkfull "$d" && cp -a "$s/." "$d/" && rm -rf "$s"; head -c 2m /dev/zero >"$d/.fill" 2>/dev/null
  done; exec bash /usr/local/lib/fedokawaii/setup.sh --update' _ "$W"
eq "$RC" 1; has "$OUT" "only 0B free on / — this needs 10GB"; lacks "$OUT" "✘ line"; lacks "$OUT" "No space left"

case_ "the snapshot count the menu shows: recorded by an update; 0 once every snapshot is gone (never the old count)"
back built; printf '%s\n' "1,fedokawaii baseline" "2,pre" "3,post" >"$FKH/snaps"
tk --update; eq "$RC" 0; eq "$(cat "$W/var/lib/fedokawaii/snapshots")" "$(grep -c . "$FKH/snaps")" "the count snapper has (with the update's own)"
: >"$FKH/snaps"; tk --repair; eq "$(cat "$W/var/lib/fedokawaii/snapshots")" 0 "none left: 0"
touch "$FKH/snapper-fail"; printf '%s\n' "1,x" >"$FKH/snaps"; tk --repair
eq "$(cat "$W/var/lib/fedokawaii/snapshots")" 0 "snapper not answering: the record as it was"; rm -f "$FKH/snapper-fail"

case_ "repair: your dunst fighting mako — static (D-Bus starts it), so masked, not only switched off"
back built; fkh_add units "user-static dunst.service" "user-active dunst.service"
printf '%s\n' "ro rootflags=subvol=root rhgb quiet amdgpu.ppfeaturemask=0xfff7ffff" "ro rootflags=subvol=root rhgb quiet" >"$FKH/grub-args"
tk --repair
has "$OUT" "your dunst.service fights mako"
called 'systemctl\] --user mask dunst.service'
case_ "…the same repair: a boot entry without amdgpu.ppfeaturemask (verify fails it) gets it back"
eq "$(grep -c 'amdgpu.ppfeaturemask=0xfff7ffff' "$FKH/grub-args")" 2 "every entry: $(tr '\n' '|' <"$FKH/grub-args")"
case_ "repair: an enabled one is switched off (and not masked); the GPU's kernel argument in place: not added again"
back built; fkh_add units "user-enabled swaync.service" "user-active swaync.service"
tk --repair; called 'systemctl\] --user disable --now swaync.service'; not_called 'mask swaync'; not_called 'grubby\] --update-kernel=ALL --args=amdgpu'

case_ "Syncplay: an update finds it in place; repair puts back one gone (its folder, starters and pin)"
back built; reset_calls
tk --update; eq "$RC" 0; has "$OUT" "Syncplay v1.7.6 — in place"; not_called 'git\] .*clone .*Syncplay'
back built; rm -rf "$W/home/fkuser/.local/share/fedokawaii/syncplay" "$W/home/fkuser/.local/bin/syncplay" \
  "$W/home/fkuser/.local/share/fedokawaii/upstream/syncplay"
tk --repair; called 'git\] .*clone .*Syncplay'; has "$OUT" "✔ Syncplay v1.7.6 (no window)"
[[ -x $W/home/fkuser/.local/bin/syncplay ]] && _ok || _no "syncplay not put back"
eq "$(cat "$W/home/fkuser/.local/share/fedokawaii/upstream/syncplay")" "$(. "$REPO/lib/upstream.sh"; syncplay_pin)"
case_ "repair: a boot entry that lost the console argument (no black-screen wait at boot) gets it back"
back built; sed -i '1 s/ systemd.tty.term.console=dumb//' "$FKH/grub-args"
tk --repair; called 'grubby\] --update-kernel=ALL --args=systemd.tty.term.console=dumb'
eq "$(grep -c systemd.tty.term.console=dumb "$FKH/grub-args")" 2 "both entries carry it again"
case_ "repair: Fedora's every-session boot-success timer on again (a fresh preset): off again, the desktop's stays"
back built; fkh_add units "global-enabled grub-boot-success.timer"
tk --repair; called 'systemctl\] --global disable grub-boot-success.timer'
grep -qx "global-enabled grub-boot-success.timer" "$FKH/units" && _no "still on for every session" || _ok
case_ "repair: a kernel without its boot image gets one (dracut --kver), and verify passes after"
back built; fkh kernels "6.18.1-200.fc44.x86_64" "$(uname -r)"; echo vmlinuz >"$W/boot/vmlinuz-6.18.1-200.fc44.x86_64"
tk --repair; has "$OUT" "kernel 6.18.1-200.fc44.x86_64 has no boot image (initramfs) — dracut makes it now"
called 'dracut\] -f --kver 6.18.1-200.fc44.x86_64'
[[ -s $W/boot/initramfs-6.18.1-200.fc44.x86_64.img ]] && _ok || _no "no image made"
has "$OUT" "problem(s) before, 0 now"
case_ "update: the same, counted among the parts that failed when dracut cannot"
back built; fkh kernels "6.18.1-200.fc44.x86_64" "$(uname -r)"; echo vmlinuz >"$W/boot/vmlinuz-6.18.1-200.fc44.x86_64"; fkh rc-dracut 1
tk --update; has "$OUT" "dracut could not make the boot image for 6.18.1-200.fc44.x86_64"
has "$OUT" "not updated this time"; has "$OUT" "the kernels' boot images (dracut)"; rm -f "$FKH/rc-dracut"
case_ "repair: /boot not mounted (no vmlinuz either): said, nothing written into the empty folder"
back built; fkh kernels "6.18.1-200.fc44.x86_64" "$(uname -r)"
tk --repair; has "$OUT" "no /boot/vmlinuz-6.18.1-200.fc44.x86_64 — is /boot mounted?"
not_called 'dracut\] -f --kver'; [[ ! -e $W/boot/initramfs-6.18.1-200.fc44.x86_64.img ]] && _ok || _no "an image written beside a missing kernel"

# ── a machine set up before these: the user in input, no record of it; no Bluetooth or
#    shutdown setting; systemd-oomd-defaults brought by something ───────────────────────
earlier() { fk usermod -aG input fkuser; rm -f "$W/var/lib/fedokawaii/input-group-out" \
              "$W/etc/modprobe.d/fedokawaii-btusb.conf" "$W/etc/systemd/system/user@.service.d/fedokawaii.conf"; }
case_ "repair on a machine set up earlier: out of the input group (said), the two settings back, oomd's rules out"
back built; earlier; fkh_add installed systemd-oomd-defaults
tk --repair
called 'gpasswd\] -d fkuser input'; lacks " $(fk id -nG fkuser) " " input "
has "$OUT" "fkuser is out of the input group (in it, any program could read every key pressed)"; has "$OUT" "handbook §21.1"
[[ -s $W/var/lib/fedokawaii/input-group-out ]] && _ok || _no "not recorded"
eq "$(grep -v '^#' "$W/etc/modprobe.d/fedokawaii-btusb.conf" 2>/dev/null)" "options btusb enable_autosuspend=0"
has "$(cat "$W/etc/systemd/system/user@.service.d/fedokawaii.conf" 2>/dev/null)" "TimeoutStopSec=30s"
called 'dnf\] -y remove .*systemd-oomd-defaults'; pkg_has systemd-oomd-defaults && _no "oomd's rules still there" || _ok
has "$OUT" "problem(s) before, 0 now"
case_ "…you put yourself back in it (a controller no game sees): the next repair leaves it so"
reset_calls; fk usermod -aG input fkuser
tk --repair; not_called 'gpasswd'; has " $(fk id -nG fkuser) " " input "
case_ "update on a machine set up earlier: out of the input group once, the two settings back"
back built; earlier
tk --update; eq "$RC" 0 "$(grep -E '✘|failed' <<<"$OUT" | head -n3 | tr '\n' '|')"
called 'gpasswd\] -d fkuser input'; lacks " $(fk id -nG fkuser) " " input "; has "$OUT" "fkuser is out of the input group"
[[ -s $W/etc/modprobe.d/fedokawaii-btusb.conf && -s $W/etc/systemd/system/user@.service.d/fedokawaii.conf ]] && _ok || _no "a setting not put back"
lacks "$OUT" "not updated this time"

case_ "upkeep.conf: EVERY=\"30\" (quoted) counts as 30 days, as the menu reads it"
back built; mkdir -p "$W/home/fkuser/.config/fedokawaii"
printf 'EVERY="30"     # days\nWAIT=\x2745\x27\n' >"$W/home/fkuser/.config/fedokawaii/upkeep.conf"; fk chown -R fkuser:fkuser /home/fkuser/.config
tk --update; has "$OUT" "the next one in 30 days"
printf 'EVERY=400\n' >"$W/home/fkuser/.config/fedokawaii/upkeep.conf"
tk --update; has "$OUT" "the next one in 90 days" "out of bounds: the default"

done_
