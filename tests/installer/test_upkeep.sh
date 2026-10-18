#!/usr/bin/env bash
# tests/installer/test_upkeep.sh — setup.sh's season's update and repair on a finished install
# (the fake machine): offline they say so within half a minute, not after minutes; a package
# transaction cut off half-way is tidied before it is tried again, and a failure never claims
# "nothing was changed"; a fighting service of yours that cannot be disabled (static: D-Bus
# starts it) is masked; your upkeep.conf counts with quotes too; every package change runs as
# a service of its own (a closed window cuts none in half). A machine set up earlier:
# taken out of the input group once (never again once you put yourself back), the Bluetooth
# dongle's and the shutdown's settings put back, systemd-oomd's rules taken out.
. "$(dirname "$0")/lib.sh"
TK=/usr/local/lib/fedokawaii
tk() { fkrun bash "$TK/setup.sh" "$@"; }
grubenv() { touch "$FKH/grubenv"; sed -i "/^${1%%=*}=/d" "$FKH/grubenv"; echo "$1" >>"$FKH/grubenv"; }   # grubenv KEY=VALUE — the rest kept

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
case_ "Spotify: an update finds it in place — nothing built, no question asked"
back built; reset_calls
tk --update; eq "$RC" 0; has "$OUT" "Spotify spotify-client — in place"; not_called 'lpf-pkgbuild\] build'
case_ "a new recipe (a Spotify release): built by the update — what it needs by root, the build by pkg-build in its own home, the package installed"
back built; fkh lpf-newer; reset_calls
tk --update; eq "$RC" 0 "$(grep -E '✘|failed' <<<"$OUT" | head -n3 | tr '\n' '|')"
called '^root\[lpf-sudo-builddep\] /usr/share/lpf/packages/spotify-client/spotify-client.spec'
called '^pkg-build\[lpf-pkgbuild\] build spotify-client \(as pkg-build, HOME=/var/lib/lpf\)'
called 'dnf\] -y install /var/lib/lpf/rpms/spotify-client/spotify-client-1.3.4.258-1.fc44.x86_64.rpm'
eq "$(cat "$W/var/lib/lpf/packages/spotify-client/state")" OK "lpf's own record: done"
[[ ! -e $W/var/lib/lpf/rpms/spotify-client ]] && _ok || _no "the built package left in lpf's folder"
has "$OUT" "✔ Spotify"; lacks "$OUT" "installed outside the manifest"
called 'dnf\] -y mark dependency lsb_release' "what the build needed: marked as needed, not as yours"
grep -q '^lsb_release User' "$FKH/userinstalled" && _no "lsb_release left as yours" || _ok
case_ "…the build fails (Spotify's server down): the update goes on, says so with lpf's log; verify warns; repair builds it"
back built; fkh lpf-newer; fkh lpf-build-fail
tk --update; has "$OUT" "Spotify did not build — lpf's log: /var/lib/lpf/log/spotify-client.log"
has "$OUT" "not updated this time"; has "$OUT" "a newer Spotify waits to be built"
eq "$(cat "$W/var/lib/lpf/packages/spotify-client/state")" failed
rm -f "$FKH/lpf-build-fail"; reset_calls
tk --repair; called 'lpf-pkgbuild\] build spotify-client'; eq "$(cat "$W/var/lib/lpf/packages/spotify-client/state")" OK
case_ "Spotify never built (its first build failed at setup): repair builds it; verify said so meanwhile"
back built; fkh_del installed spotify-client; sed -i '/^spotify-client /d' "$FKH/userinstalled"; echo untriaged >"$W/var/lib/lpf/packages/spotify-client/state"
fkrun bash "$TK/verify.sh"; has "$OUT" "Spotify not built yet"
tk --repair; pkg_has spotify-client && _ok || _no "not installed by repair"
case_ "update: presenterm and spotify_player (release binaries this desktop no longer has) leave ~/.local/bin"
back built
for t in presenterm spotify_player; do
  printf '#!/bin/sh\n' >"$W/home/fkuser/.local/bin/$t"; echo v0.1.0 >"$W/home/fkuser/.local/share/fedokawaii/upstream/$t"
done
fk_perms; tk --update; eq "$RC" 0
[[ ! -e $W/home/fkuser/.local/bin/presenterm && ! -e $W/home/fkuser/.local/bin/spotify_player ]] && _ok || _no "a retired tool stayed"
case_ "repair: a boot entry that lost the console argument (no black-screen wait at boot) gets it back"
back built; sed -i '1 s/ systemd.tty.term.console=dumb//' "$FKH/grub-args"
tk --repair; called 'grubby\] --update-kernel=ALL --args=systemd.tty.term.console=dumb'
eq "$(grep -c systemd.tty.term.console=dumb "$FKH/grub-args")" 2 "both entries carry it again"
not_called 'grubby\] --update-kernel=ALL --args=rhgb' "rhgb is there already: grubby not run for it"
case_ "repair: entries without rhgb quiet (an install that left them out: no splash) get them"
back built; sed -i 's/ rhgb quiet//' "$FKH/grub-args"
tk --repair; called 'grubby\] --update-kernel=ALL --args=rhgb'; called 'grubby\] --update-kernel=ALL --args=quiet'
eq "$(grep -c ' rhgb' "$FKH/grub-args")" 2 "both entries"
case_ "repair: Fedora's every-session boot-success timer on again (a fresh preset): off again, the desktop's stays"
back built; fkh_add units "global-enabled grub-boot-success.timer"
tk --repair; called 'systemctl\] --global disable grub-boot-success.timer'
grep -qx "global-enabled grub-boot-success.timer" "$FKH/units" && _no "still on for every session" || _ok
case_ "repair: a new kernel (waiting for its restart) without its boot image gets one (dracut --kver), and verify passes after"
back built; fkh kernels "6.99.1-200.fc44.x86_64" "$(uname -r)"; echo vmlinuz >"$W/boot/vmlinuz-6.99.1-200.fc44.x86_64"
tk --repair; has "$OUT" "kernel 6.99.1-200.fc44.x86_64 has no boot image (initramfs) — dracut makes it now"
called 'dracut\] -f --kver 6.99.1-200.fc44.x86_64'
[[ -s $W/boot/initramfs-6.99.1-200.fc44.x86_64.img ]] && _ok || _no "no image made"
has "$OUT" "problem(s) before, 0 now"
case_ "update: the same, counted among the parts that failed when dracut cannot"
back built; fkh kernels "6.99.1-200.fc44.x86_64" "$(uname -r)"; echo vmlinuz >"$W/boot/vmlinuz-6.99.1-200.fc44.x86_64"; fkh rc-dracut 1
tk --update; has "$OUT" "dracut could not make the boot image for 6.99.1-200.fc44.x86_64"
has "$OUT" "not updated this time"; has "$OUT" "the kernels' boot images (dracut)"; rm -f "$FKH/rc-dracut"
case_ "repair: /boot not mounted (no vmlinuz either): said, nothing written into the empty folder"
back built; fkh kernels "6.99.1-200.fc44.x86_64" "$(uname -r)"
tk --repair; has "$OUT" "no /boot/vmlinuz-6.99.1-200.fc44.x86_64 — is /boot mounted?"
not_called 'dracut\] -f --kver'; [[ ! -e $W/boot/initramfs-6.99.1-200.fc44.x86_64.img ]] && _ok || _no "an image written beside a missing kernel"

case_ "repair: each package change a service of its own (closing the window cuts none in half); what only asks dnf stays in the window"
back built; fkh_del installed bat; fkh_add installed systemd-oomd-defaults; reset_calls
tk --repair; pkg_has bat && _ok || _no "bat not put back"
called 'systemd-run\] .*--wait .* /usr/bin/dnf -y install bat$'
called 'systemd-run\] .*--wait .* /usr/bin/dnf -y remove .*systemd-oomd-defaults'
not_called 'systemd-run\] .* /usr/bin/dnf .*repoquery'; called '^root\[dnf\] -q repoquery --available --whatprovides bat$'
has "$OUT" "(as fedokawaii-dnf-"
case_ "update: the manifest's install after the upgrade is detached too"
back built; fkh_del installed bat; reset_calls
tk --update; called 'systemd-run\] .*--wait .* /usr/bin/dnf -y upgrade --refresh'; called 'systemd-run\] .*--wait .* /usr/bin/dnf -y install bat$'
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

case_ "repair: dnf's metadata timer on again (static, as Fedora 44 ships it) — masked again, never a bare disable"
back built; sed -i 's/^masked dnf5-makecache.timer$/static dnf5-makecache.timer/' "$FKH/units"
reset_calls; tk --repair
called 'systemctl\] mask --now dnf5-makecache.timer'; not_called 'disable --now dnf5-makecache'
grep -qx "masked dnf5-makecache.timer" "$FKH/units" && _ok || _no "not masked"
has "$OUT" "problem(s) before, 0 now"
case_ "repair before setup's own end made the snapshot configs: the missing one made (/home too), an existing one never again"
back built; rm -f "$W/etc/snapper/configs/home"; sed -i '/^home$/d' "$FKH/snapper-configs"
reset_calls; tk --repair
called 'snapper\] -c home create-config /home'; not_called 'snapper\] -c root create-config'
[[ -f $W/etc/snapper/configs/home ]] && _ok || _no "no config for /home"
lacks "$OUT" "config already exists"

# ── one kernel ───────────────────────────────────────────────────────────────
case_ "repair from the rescue screen (the newest kernel runs, its desktop never started: no boot_success): the one before stays, the way back"
back built; fkh kernels "6.18.1-200.fc44.x86_64" "$(uname -r)"; grubenv boot_success=0
echo vmlinuz >"$W/boot/vmlinuz-6.18.1-200.fc44.x86_64"; : >"$W/boot/initramfs-6.18.1-200.fc44.x86_64.img"
reset_calls; tk --repair; not_called 'remove kernel'
has "$OUT" "the kernel before $(uname -r) stays as the way back"
reset_calls; tk --update; not_called 'remove kernel' "nor does an update"
case_ "repair: the kernel before the running newest — removed (all its packages), no repository asked; the start-up timer in place"
back built; fkh kernels "6.18.1-200.fc44.x86_64" "$(uname -r)"; rm -f "$W/etc/systemd/system/fedokawaii-kernels.timer"
grubenv boot_success=1                 # (this start has reached the desktop)
echo vmlinuz >"$W/boot/vmlinuz-6.18.1-200.fc44.x86_64"; : >"$W/boot/initramfs-6.18.1-200.fc44.x86_64.img"
reset_calls; tk --repair
called "dnf\] -y --disable-repo=\* remove kernel-6.18.1-200.fc44.x86_64 kernel-core-6.18.1-200.fc44.x86_64 kernel-modules-6.18.1-200.fc44.x86_64 kernel-modules-core-6.18.1-200.fc44.x86_64$"
eq "$(cat "$FKH/kernels")" "$(uname -r)" "one kernel left"
[[ -f $W/etc/systemd/system/fedokawaii-kernels.timer ]] && _ok || _no "no start-up timer"
grep -qx "enabled fedokawaii-kernels.timer" "$FKH/units" && _ok || _no "timer not enabled"
has "$OUT" "problem(s) before, 0 now"
case_ "repair: a boot menu left shown (no theme, no other system) — hidden again, as setup left it"
back built; sed -i '/^menu_auto_hide=/d' "$FKH/grubenv"
fkrun bash "$TK/verify.sh"; has "$OUT" "✘ GRUB menu hidden"
tk --repair; grep -qx menu_auto_hide=1 "$FKH/grubenv" && _ok || _no "the menu still shown"
has "$OUT" "problem(s) before, 0 now"
case_ "repair or update with a new kernel not yet running: both kept, said — nothing removed"
back built; fkh kernels "$(uname -r)" "6.99.1-200.fc44.x86_64"; echo vmlinuz >"$W/boot/vmlinuz-6.99.1-200.fc44.x86_64"; : >"$W/boot/initramfs-6.99.1-200.fc44.x86_64.img"
reset_calls; tk --repair; not_called 'remove kernel'
has "$OUT" "kernel 6.99.1-200.fc44.x86_64 is installed and waits for a restart"
reset_calls; tk --update; not_called 'remove kernel'
case_ "the start-up run (a quarter of an hour in): only once this start reached the desktop (boot_success=1) — then the one before goes"
back built; fkh kernels "6.18.1-200.fc44.x86_64" "$(uname -r)"; grubenv boot_success=0
reset_calls; tk --kernels; eq "$RC" 0; not_called 'remove kernel'
has "$OUT" "this start has not reached the desktop for two minutes"
grubenv boot_success=1; tk --kernels; eq "$RC" 0
called 'remove kernel-6.18.1-200.fc44.x86_64'; eq "$(cat "$FKH/kernels")" "$(uname -r)"
case_ "the start-up run while another run holds the lock, or before setup has finished: nothing, quietly"
back built; fkh kernels "6.18.1-200.fc44.x86_64" "$(uname -r)"; grubenv boot_success=1
echo 3 >"$W/var/lib/fedokawaii/phase"; reset_calls; tk --kernels; eq "$RC" 0; not_called 'remove kernel'

# ── run from a folder of yours: it becomes the toolkit, then goes ──────────────────────────
H=/home/fkuser
clone_at() {   # clone_at DIR — a fresh copy of the project there (as unpacked from a download), yours:
  # unzip gives the folder the commit's time (days back), its change time is the unpacking
  mkdir -p "$W$1"; cp -a "$W$TK/." "$W$1/"; touch -d '3 days ago' "$W$1"; chown -R "$FK_UID:$FK_UID" "$W$(dirname "$1")"
}
older() { touch -d '1 hour ago' "$@"; }   # older FILE… — downloaded before the folder was unpacked
case_ "repair started from a download unpacked in ~/src: the folder, its .zip beside it and the empty ~/src go at the very end"
back built; clone_at $H/src/fedokawaii-main; : >"$W$H/src/fedokawaii-main.zip"; older "$W$H/src/fedokawaii-main.zip"; chown "$FK_UID:$FK_UID" "$W$H/src/fedokawaii-main.zip"
fkrun bash $H/src/fedokawaii-main/setup.sh --repair
has "$OUT" "~/src/fedokawaii-main removed: the toolkit has all of it (a terminal still inside it: cd ~)"
has "$OUT" "~/src/fedokawaii-main.zip removed: the download it came from"; has "$OUT" "~/src removed: empty once it was gone"
[[ ! -e $W$H/src && -x $W$TK/setup.sh ]] && _ok || _no "left: $(ls -A "$W$H/src" 2>&1)"
r=$(grep -n 'removed: the toolkit' <<<"$OUT" | cut -d: -f1); l=$(grep -n 'sound (PipeWire' <<<"$OUT" | head -n1 | cut -d: -f1)   # (its own line; the summary after names it again)
[[ -n $r && -n $l ]] && ((r > l)) && _ok || _no "removed at line [$r], the last repair (sound) at [$l]"
case_ "update started from a clone in your home: gone at its end too; ~/Downloads, where its zip was, stays"
back built; clone_at $H/fedokawaii; mkdir -p "$W$H/Downloads"; : >"$W$H/Downloads/fedokawaii.zip"; older "$W$H/Downloads/fedokawaii.zip"; chown -R "$FK_UID:$FK_UID" "$W$H/Downloads"
fkrun bash $H/fedokawaii/setup.sh --update
[[ ! -e $W$H/fedokawaii && ! -e $W$H/Downloads/fedokawaii.zip && -d $W$H/Downloads && -d $W$H ]] && _ok || _no "the clone or its zip left (or Downloads, your home gone)"
has "$OUT" "~/fedokawaii removed"
case_ "…a newer download of it in ~/Downloads (fetched since): it stays"
back built; clone_at $H/fedokawaii; mkdir -p "$W$H/Downloads"; : >"$W$H/Downloads/fedokawaii.zip"; touch -d '1 hour' "$W$H/Downloads/fedokawaii.zip"; chown -R "$FK_UID:$FK_UID" "$W$H/Downloads"
fkrun bash $H/fedokawaii/setup.sh --repair
[[ ! -e $W$H/fedokawaii && -f $W$H/Downloads/fedokawaii.zip ]] && _ok || _no "the newer download went (or the clone stayed)"
case_ "fedokawaii apply from your own git clone (--toolkit, the copy kept elsewhere): the clone is never removed"
back built; clone_at $H/code/fedokawaii
fkrun bash $H/code/fedokawaii/setup.sh --toolkit; eq "$RC" 0
[[ -f $W$H/code/fedokawaii/setup.sh ]] && _ok || _no "your working clone was removed"
lacks "$OUT" "removed: the toolkit has all of it"
# (a real git repository: a pushed main, and work of yours git alone holds)
gitrepo() {   # gitrepo DIR — DIR a git repository with everything committed and pushed to a bare "origin"
  local g=(git -c safe.directory='*' -c user.name=t -c user.email=t@t -c init.defaultBranch=main -C "$W$1")
  "${g[@]}" init -q && "${g[@]}" add -A && "${g[@]}" commit -qm base \
    && git init -q --bare "$W$H/origin.git" && "${g[@]}" remote add origin "$W$H/origin.git" && "${g[@]}" push -q origin main
  chown -R "$FK_UID:$FK_UID" "$W$1" "$W$H/origin.git"; fkh real-git
}
case_ "repair from a clone whose main is pushed but a branch of yours is not: packed first, then removed"
back built; clone_at $H/fedokawaii; gitrepo $H/fedokawaii
g=(git -c safe.directory='*' -c user.name=t -c user.email=t@t -C "$W$H/fedokawaii")
"${g[@]}" checkout -qb mine && echo idea >"$W$H/fedokawaii/idea.txt" && "${g[@]}" add idea.txt && "${g[@]}" commit -qm idea && "${g[@]}" checkout -q main
rm -f "$W$H/fedokawaii/idea.txt"; chown -R "$FK_UID:$FK_UID" "$W$H/fedokawaii"
fkrun bash $H/fedokawaii/setup.sh --repair
has "$OUT" "~/fedokawaii: git has commits or tags not on GitHub — the whole folder is kept, packed"
a=$(ls "$W"/home/fkuser/.local/state/fedokawaii/started-from-*.tar.gz 2>/dev/null | tail -n1)
tar -tzf "$a" | grep -q 'fedokawaii/.git/refs/heads/mine' && _ok || _no "the branch is not in the pack"
[[ ! -e $W$H/fedokawaii ]] && _ok || _no "the clone is still there"
case_ "…a clone with a second git worktree: kept"
back built; clone_at $H/fedokawaii; gitrepo $H/fedokawaii
git -c safe.directory='*' -C "$W$H/fedokawaii" worktree add -q "$W$H/fk-other"; chown -R "$FK_UID:$FK_UID" "$W$H/fedokawaii" "$W$H/fk-other"
fkrun bash $H/fedokawaii/setup.sh --repair
[[ -d $W$H/fedokawaii ]] && _ok || _no "removed despite its other worktree"; has "$OUT" "~/fedokawaii kept: git has other worktrees of it"
rm -f "$FKH/real-git"
case_ "an update that stopped half-way leaves no record: a later update from the toolkit removes nothing"
back built; clone_at $H/fk; fkh net off
fkrun bash $H/fk/setup.sh --update; eq "$RC" 1; rm -f "$FKH/net"
tk --update; [[ -d $W$H/fk ]] && _ok || _no "a folder an earlier, stopped run started from was removed"
case_ "the project unpacked straight into a folder of other things: only the project's files go, yours stay"
back built; clone_at $H/stuff; echo mine >"$W$H/stuff/my-notes.txt"; chown "$FK_UID:$FK_UID" "$W$H/stuff/my-notes.txt"
fkrun bash $H/stuff/setup.sh --repair
[[ -f $W$H/stuff/my-notes.txt && ! -e $W$H/stuff/setup.sh && ! -e $W$H/stuff/lib ]] && _ok || _no "in it now: $(ls "$W$H/stuff" | tr '\n' ' ')"
has "$OUT" "~/stuff: the project's files removed; the rest is yours and stays (my-notes.txt)"
case_ "the project unpacked straight into ~/Downloads (a standard folder): nothing removed, said"
back built; clone_at $H/Downloads
fkrun bash $H/Downloads/setup.sh --repair
[[ -f $W$H/Downloads/setup.sh ]] && _ok || _no "removed from ~/Downloads"; has "$OUT" "~/Downloads kept: it is one of your standard folders"
case_ "repair run from the toolkit itself: nothing of yours touched"
back built; clone_at $H/fedokawaii; tk --repair
[[ -d $W$H/fedokawaii ]] && _ok || _no "a folder this run was not started from was removed"

done_
