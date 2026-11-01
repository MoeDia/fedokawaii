#!/usr/bin/env bash
# tests/installer/test_update_flow.sh — the update button's run (lib/update.sh), every branch, on a
# finished install (the fake machine): up to date; a green update proven in a copy first, then
# the same transaction on the running system after a pinned snapshot; a red copy → the culprit
# found by halves and held, the rest applied, the hold kept until a newer version passes; two
# packages red only together held together; a copy that never goes through stops after three
# holds with nothing changed; red on the running system → the set held and the snapshot offered
# (his files still inside /) or restored (once /home is its own subvolume); a run cut in its
# transaction finished when whole, undone when not; and what refuses to start before anything
# changes: another package manager, the games VM holding the card, a full disk, a bad signature.
. "$(dirname "$0")/lib.sh"
TK=/usr/local/lib/fedokawaii
up() { fkrun bash "$TK/setup.sh" --update; }
report() { head -n1 "$U/report" | cut -d' ' -f2; }   # (the outcome word the pane reads)
pending() { fkh pending "$@"; }

world built; releases
U=$W/var/lib/fedokawaii/update
fkh mounts /run/fedokawaii/top     # (the file system's top level: a real mount needs root)
keep built

case_ "nothing to update: up to date, no copy made, nothing replayed — the snapshot before the steps all the same"
back built; reset_calls; up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(report)" current; has "$OUT" "update done"
not_called 'systemd-nspawn'; not_called 'dnf\] .*replay'
called 'snapper\] -c root create .*before update'
eq "$(cut -d' ' -f1 "$U/phase")" end "the phase at its end"
grep -q '^Before=display-manager.service greetd.service$' "$W/etc/systemd/system/fedokawaii-update-resume.service" && _ok || _no "the resume unit is not before the login screen"
grep -qx 'enabled fedokawaii-update-resume.service' "$FKH/units" && _ok || _no "the resume unit not enabled"

case_ "a green update: stored once, proven in a copy (the actions plugin off), pinned snapshot, the same transaction on the system"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44" "mesa 26.0-1.fc44 26.1-1.fc44"
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(report)" ok; has "$(sed -n 2p "$U/report")" "updated · 2 packages"
called 'dnf\] -y --setopt=keepcache=True upgrade --store=/var/lib/fedokawaii/update/tx'
called 'systemd-nspawn\] .*--private-network .*--bind-ro=/var/lib/fedokawaii/update/tx:/tx .* dnf5 --disable-plugin=actions -y -C replay /tx'
called 'systemd-nspawn\] .* /usr/bin/bash /run/fk-check'
called 'rpmkeys\] --checksig'
called "snapper\] -c root modify -c  [0-9]+"
called 'dnf\] -y -C replay /var/lib/fedokawaii/update/tx'
grep -q '^mesa 26.1-1.fc44$' "$FKH/evr" && _ok || _no "mesa not at its new version: $(cat "$FKH/evr")"
# (the copy is gone again, the top unmounted: nothing left beside the system)
[[ ! -e $W/run/fedokawaii/top/root.cand ]] && _ok || _no "the copy was left behind"
[[ $(cut -d' ' -f2 "$W/var/lib/fedokawaii/last-update") != stopped ]] && _ok || _no "recorded as stopped"
# (order: the copy before the snapshot, the snapshot before the system's replay)
c=$(grep -n 'systemd-nspawn\]' "$CALLS" | head -n1 | cut -d: -f1); s=$(grep -n 'snapper\] -c root create' "$CALLS" | tail -n1 | cut -d: -f1)
r=$(grep -n 'dnf\] -y -C replay' "$CALLS" | head -n1 | cut -d: -f1)
((c < s && s < r)) && _ok || _no "copy $c, snapshot $s, replay $r — out of order"
# (the desktop's start checked before and after: the installed dwl, as the user)
eq "$(grep -c '^fkuser\[session-start\.sh\] --dwl /usr/local/bin/dwl$' "$CALLS")" 2 "the session's start, before and after"
eq "$(grep -c '^fkuser\[bar-geometry\.sh\] --dwl /usr/local/bin/dwl$' "$CALLS")" 2 "the bar's measure, before and after"

case_ "red in the copy: the culprit found by halves, held at the version that broke it, the rest applied"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44" "foot 1.24-1.fc44 1.25-1.fc44" "mesa 26.0-1.fc44 26.1-1.fc44" "zlib 1.3-1.fc44 1.3.1-1.fc44"
fkh_add installed bash foot mesa zlib; fkh cand-red mesa
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(report)" ok; has "$(sed -n 2p "$U/report")" "updated · 3 packages · held: mesa 26.1-1.fc44"
called 'dnf\] -q versionlock exclude mesa-26.1-1.fc44'
grep -q '^mesa 26.1-1.fc44 1.0-1.fc44 ' "$U/holds" && _ok || _no "the hold not recorded: $(cat "$U/holds" 2>/dev/null)"
has "$(cut -d' ' -f5- "$U/holds")" "dwl does not start with mesa"
grep -q '^mesa ' "$FKH/evr" && _no "mesa went in" || _ok
grep -q '^zlib 1.3.1-1.fc44$' "$FKH/evr" && _ok || _no "the rest did not go in: $(cat "$FKH/evr")"
n=$(grep -c 'systemd-nspawn\] .* /usr/bin/bash /run/fk-check$' "$CALLS"); ((n <= 5)) && _ok || _no "$n copies checked for 4 packages (log2: at most 2 rounds of 2, and the set)"
eq "$(cut -d' ' -f2 "$W/var/lib/fedokawaii/last-update")" partial "a hold is a partial update"
case_ "…the next press: the held version still the only one — up to date, held said, no copy made"
reset_calls; up; eq "$RC" 0
eq "$(report)" current; has "$(sed -n 2p "$U/report")" "up to date · held: mesa 26.1-1.fc44"
not_called 'systemd-nspawn'
case_ "…a newer mesa passes the copy: in, and the hold let go"
reset_calls; pending "mesa 26.0-1.fc44 26.1.1-1.fc44"; : >"$FKH/cand-red"
up; eq "$RC" 0; eq "$(report)" ok
grep -q '^mesa 26.1.1-1.fc44$' "$FKH/evr" && _ok || _no "the newer mesa not in"
case_ "…and the press after that lets the old hold go (the package has moved on)"
reset_calls; up; [[ -s $U/holds ]] && _no "still held: $(cat "$U/holds")" || _ok
called 'dnf\] -q versionlock delete mesa'

case_ "a family red (one source package): held whole — never half a kernel"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44" "kernel 7.2.11-200.fc44 7.2.13-200.fc44" "kernel-core 7.2.11-200.fc44 7.2.13-200.fc44" \
  "kernel-modules 7.2.11-200.fc44 7.2.13-200.fc44" "zlib 1.3-1.fc44 1.3.1-1.fc44"
fkh srpms "kernel-core kernel" "kernel-modules kernel"; fkh cand-red kernel-core
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(awk '{ print $1 }' "$U/holds" | sort | tr '\n' ' ')" "kernel kernel-core kernel-modules " "the family held"
grep -q '^bash 5.3-1.fc44$' "$FKH/evr" && grep -q '^zlib 1.3.1-1.fc44$' "$FKH/evr" && _ok || _no "the rest not in: $(cat "$FKH/evr")"
grep -q '^kernel' "$FKH/evr" && _no "a kernel package went in: $(grep '^kernel' "$FKH/evr")" || _ok

case_ "two packages red only together: both halves green alone — held together, never a guess"
back built; reset_calls; pending "a 1-1 2-1" "b 1-1 2-1" "c 1-1 2-1" "d 1-1 2-1"; fkh cand-red "a+b"
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(awk '{ print $1 }' "$U/holds" | sort | tr '\n' ' ')" "a b " "held"
grep -q '^c 2-1$' "$FKH/evr" && grep -q '^d 2-1$' "$FKH/evr" && _ok || _no "c and d not in: $(cat "$FKH/evr")"

case_ "a copy that never takes the transaction: three holds, then stopped — the running system untouched"
back built; reset_calls; pending "a 1-1 2-1" "b 1-1 2-1" "c 1-1 2-1" "d 1-1 2-1" "e 1-1 2-1"; fkh cand-replay-fail
up; eq "$RC" 1; has "$OUT" "the update stays red in a copy of the system after three holds — nothing changed"
not_called 'dnf\] -y -C replay'; not_called 'snapper\] -c root create .*before update'
eq "$(report)" stopped; has "$(sed -n 2p "$U/report")" "stays red in a copy"
eq "$(cut -d' ' -f2 "$W/var/lib/fedokawaii/last-update")" stopped

case_ "the copy's container does not even start: no verdict on the packages — stopped, nothing held, nothing changed"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44" "mesa 26.0-1.fc44 26.1-1.fc44"; fkh nspawn-broken
up; eq "$RC" 1; has "$OUT" "the copy's container would not start (Failed to set up namespace: Operation not permitted) — nothing changed"
[[ -s $U/holds ]] && _no "held: $(cat "$U/holds")" || _ok; not_called 'versionlock exclude'; not_called 'dnf\] -y -C replay'
case_ "red, and a half that cannot be tried on its own: no culprit named — stopped, nothing held"
back built; reset_calls; pending "a 1-1 2-1" "b 1-1 2-1" "c 1-1 2-1" "d 1-1 2-1"; fkh cand-red a; fkh store-try-fail
up; eq "$RC" 1; has "$OUT" "the package that causes it could not be found: a part of the set could not be tried on its own — nothing changed, nothing held"
[[ -s $U/holds ]] && _no "held: $(cat "$U/holds")" || _ok; not_called 'dnf\] -y -C replay'
case_ "every run ends without its stored transaction or the downloads kept for the halves"
[[ ! -e $U/tx && ! -e $U/try ]] && _ok || _no "left: $(ls "$U")"; called 'dnf\] -q clean packages'

case_ "red on the running system (the desktop does not start): the set held, the snapshot offered — his files are still inside /"
back built; reset_calls; pending "mesa 26.0-1.fc44 26.1-1.fc44"
fkh replay-breaks-dwl      # (dwl starts in the copy — the stand-in's checks — but not on the system after the replay)
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(report)" offered; has "$(sed -n 2p "$U/report")" "Super+U → snapshots"
has "$(cat "$U/report")" "the desktop does not start"
grep -q '^mesa 26.1-1.fc44 ' "$U/holds" && _ok || _no "the set not held"
not_called 'kawa-snap\] restore'
eq "$(cut -d' ' -f2 "$W/var/lib/fedokawaii/last-update")" stopped "an undone update is no update"
case_ "…the same once /home is its own subvolume: the system before it restored for the next start"
back built; pending "mesa 26.0-1.fc44 26.1-1.fc44"; fkh replay-breaks-dwl
fkh versionlock; fkh mounts /run/fedokawaii/top /home
printf '#!/bin/sh\n. /usr/local/bin/_lib.sh\nfkh_log "$*"\nexit 0\n' >"$W/usr/local/sbin/kawa-snap"; chmod 755 "$W/usr/local/sbin/kawa-snap"
reset_calls; up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(report)" restored; called "kawa-snap\] restore $(cat "$U/snap")"
has "$(sed -n 2p "$U/report")" "comes back at the next start"

case_ "the desktop's start check red before the update already: not counted against it — kept, and said"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44"; fkh session-red "not running: waybar"
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(report)" ok; has "$OUT" "red before the update: the desktop does not start — session-start (dark): not running: waybar"
[[ -s $U/holds ]] && _no "held: $(cat "$U/holds")" || _ok
case_ "the bar off its measure after the update only: red — the set held, the snapshot offered"
back built; reset_calls; pending "gtk3 3.24.50-1.fc44 3.24.51-1.fc44"
fkh replay-breaks-bar       # (the bar is drawn right before, a row too tall after the replay)
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(report)" offered; has "$(cat "$U/report")" "the desktop does not start"
grep -q '^gtk3 3.24.51-1.fc44 ' "$U/holds" && _ok || _no "the set not held: $(cat "$U/holds" 2>/dev/null)"

case_ "the transaction fails on the running system: undone the same way (offered), the set held"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44"; fkh fail-replay 1
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(report)" offered; has "$(cat "$U/report")" "the transaction stopped on the running system"
grep -q '^bash 5.3-1.fc44 ' "$U/holds" && _ok || _no "not held"

case_ "a run cut in its transaction, whole after all: finished — the steps and checks, then kept"
back built; reset_calls; mkdir -p "$U"; printf 'replay 1\n' >"$U/phase"; echo "bash 5.2-1.fc44 5.3-1.fc44" >"$U/set"; : >"$U/baseline"
echo "bash 5.3-1.fc44" >>"$FKH/evr"; fkh_add installed bash; echo 7 >"$U/snap"
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
has "$OUT" "the last update was cut off in its transaction — finishing it first"
eq "$(report)" ok; not_called 'systemd-nspawn'; not_called 'dnf\] .*--store'
case_ "…not whole: undone (offered: snapshot 7 named), never repeated half-way"
back built; reset_calls; mkdir -p "$U"; printf 'replay 1\n' >"$U/phase"; echo "bash 5.2-1.fc44 5.3-1.fc44" >"$U/set"; : >"$U/baseline"; echo 7 >"$U/snap"
up; eq "$RC" 0; eq "$(report)" offered; has "$(sed -n 2p "$U/report")" "snapshot 7 is the system before it"
not_called 'dnf\] .*replay'

# ── the start after a run cut in its transaction (fedokawaii-update-resume.service) ───────────
resume() { fkrun bash "$TK/setup.sh" --update-resume; }
cut_run() {   # cut_run — the state a power cut in the transaction leaves: bash's new version stored, snapshot 7
  mkdir -p "$U"; printf 'replay 1\n' >"$U/phase"; echo "bash 5.2-1.fc44 5.3-1.fc44" >"$U/set"; echo 7 >"$U/snap"; fkh_add installed bash
  mkdir -p "$W/home/fkuser/.local/bin"; rm -f "$W/home/fkuser/.foryou"
  printf '#!/bin/sh\necho "$*" >>"$HOME/.foryou"\n' >"$W/home/fkuser/.local/bin/kawa-foryou"; chmod 755 "$W/home/fkuser/.local/bin/kawa-foryou"
  printf '#!/bin/sh\n. /usr/local/bin/_lib.sh\nfkh_log "$*"\nexit 0\n' >"$W/usr/local/sbin/kawa-snap"; chmod 755 "$W/usr/local/sbin/kawa-snap"
}
foryou() { cat "$W/home/fkuser/.foryou" 2>/dev/null; }
case_ "a start after a run cut in its transaction, whole after all: kept, the rest left for the next press — said at login"
back built; reset_calls; cut_run; echo "bash 5.3-1.fc44" >>"$FKH/evr"
resume; eq "$RC" 0 "$OUT"; eq "$(cut -d' ' -f1 "$U/phase")" steps
has "$(foryou)" "update-cut the last update was cut off after its packages went in"; not_called 'kawa-snap\] restore'; not_called 'systemctl\] reboot'
case_ "…the next press does the steps and the checks, nothing replayed again"
reset_calls; up; eq "$RC" 0; eq "$(report)" ok; not_called 'dnf\] .*replay'; not_called 'systemd-nspawn'
case_ "…not whole, /home its own subvolume: the system before it put back and started — once"
back built; reset_calls; cut_run; fkh mounts /run/fedokawaii/top /home
resume; eq "$RC" 0 "$OUT"; called 'kawa-snap\] restore 7$'; called 'systemctl\] reboot'
[[ -s $U/restored-once ]] && _ok || _no "not recorded as restored once"; eq "$(report)" restored
has "$(foryou)" "the system before it (snapshot 7) was put back"
case_ "…a start after that, still not whole: never again by itself — said, with the way back"
reset_calls; printf 'replay 1\n' >"$U/phase"; resume; eq "$RC" 0; not_called 'kawa-snap\] restore'; not_called 'systemctl\] reboot'
has "$(foryou)" "snapshot 7 is the system before it: Super+U → snapshots → 7"
case_ "…not whole, /home inside the system: offered, never done — his home would go back too"
back built; reset_calls; cut_run
resume; eq "$RC" 0; not_called 'kawa-snap\] restore'; has "$(foryou)" "(your home goes back too, until /home is split)"
case_ "a start with nothing cut, or in a snapshot started from the boot menu: nothing at all"
back built; reset_calls; resume; eq "$RC" 0; not_called 'kawa-snap'; not_called 'systemctl\] reboot'
cut_run; fkh fsroot-_ /root/.snapshots/41/snapshot; reset_calls; resume; eq "$RC" 0; not_called 'kawa-snap\] restore'
rm -f "$FKH/fsroot-_"

# ── the start after an update: its probation (up_probation, setup.sh --boot-good) ─────────────
K=$(uname -r) NEWK=7.2.99-200.fc44.x86_64
good() { fkrun bash "$TK/setup.sh" --boot-good; }
env_has() { grep -qx -- "$1" "$FKH/grubenv" && _ok || _no "grubenv lacks $1: $(tr '\n' ' ' <"$FKH/grubenv")"; }
case_ "a green update that brought a kernel: its next start on trial — GRUB counts three, no rescue shell, a panic restarts, the watchdog on"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44"; fkh kernels "$K" "$NEWK"; : >"$W/boot/vmlinuz-$NEWK"
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"; eq "$(report)" ok
env_has boot_counter=3; env_has boot_success=0; env_has boot_indeterminate=1
called "grubby\] --update-kernel=/boot/vmlinuz-$NEWK --args=rd.shell=0 rd.emergency=reboot panic=10"
grep -qx 'RuntimeWatchdogSec=1min' "$W/etc/systemd/system.conf.d/90-fedokawaii-probation.conf" && _ok || _no "no watchdog while on trial"
eq "$(cut -d' ' -f1,2 "$U/probation")" "$(cat "$U/snap") $NEWK" "the probation: its snapshot, the kernel on trial"
has "$OUT" "kernel $NEWK on trial at the next start: three starts to reach the desktop, else $K again"
case_ "…a start marked good before the counting ran out, on the new kernel: the trial over, the snapshot back to the cleanup"
s=$(cat "$U/snap"); echo "$s $K 2026-11-01" >"$U/probation"; fkh grubenv boot_success=1 boot_counter=2; reset_calls
good; eq "$RC" 0 "$OUT"
called 'grub2-editenv\] - unset boot_counter'; called "grubby\] --update-kernel=/boot/vmlinuz-$K --remove-args=rd.shell=0 rd.emergency=reboot panic=10"
called "snapper\] -c root modify -c number $s"; [[ ! -e $U/probation && ! -e $W/etc/systemd/system.conf.d/90-fedokawaii-probation.conf ]] && _ok || _no "the probation or its watchdog left"
case_ "GRUB took the one before after three starts: the new kernel held at its version and out, this one the default — said at login"
back built; reset_calls; cut_run; rm -f "$U/phase"; fkh kernels "$K" "$NEWK"; echo "7 $NEWK 2026-11-01" >"$U/probation"
fkh grubenv boot_success=1 boot_counter=-1
good; eq "$RC" 0 "$OUT"
grep -q "^kernel-core ${NEWK%.*} ${K%.*} [0-9-]* did not reach the desktop in three starts$" "$U/holds" && _ok || _no "not held: $(cat "$U/holds" 2>/dev/null)"
called "dnf\] -q versionlock exclude kernel-core-${NEWK%.*}"; called "grubby\] --set-default /boot/vmlinuz-$K"
called "dnf\] -y --disable-repo=\* remove kernel-$NEWK kernel-core-$NEWK kernel-modules-$NEWK kernel-modules-core-$NEWK"
has "$(foryou)" "update-kernel kernel $NEWK did not reach the desktop in three starts back on $K"
called 'grub2-editenv\] - unset boot_counter'; called 'snapper\] -c root modify -c number 7'; [[ ! -e $U/probation ]] && _ok || _no "the probation left"
case_ "the one before chosen in the menu (the counting not run out), or a start not marked good yet: the trial waits — nothing changed"
back built; reset_calls; mkdir -p "$U"; fkh kernels "$K" "$NEWK"; echo "7 $NEWK 2026-11-01" >"$U/probation"; fkh grubenv boot_success=1 boot_counter=2
good; eq "$RC" 0; not_called 'grub2-editenv\] - unset'; not_called 'snapper\] -c root modify'; [[ -s $U/probation ]] && _ok || _no "the probation closed"
fkh grubenv boot_success=0 boot_counter=2; echo "7 $K 2026-11-01" >"$U/probation"; reset_calls
good; eq "$RC" 0; not_called 'grub2-editenv\] - unset'; [[ -s $U/probation ]] && _ok || _no "closed before a good start"
case_ "the kernel on trial gone from the system (a restore took it): its trial ends with it at the next good start"
back built; reset_calls; mkdir -p "$U"; echo "7 $NEWK 2026-11-01" >"$U/probation"; fkh grubenv boot_success=1 boot_counter=3
good; eq "$RC" 0; has "$OUT" "kernel $NEWK is no longer on the system (a restore took it)"
called 'grub2-editenv\] - unset boot_counter'; not_called 'grubby\] --set-default'; [[ ! -e $U/probation ]] && _ok || _no "the probation left"
case_ "an update with no kernel: no trial, its snapshot released at the next good start"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44"; up; eq "$RC" 0
not_called 'grub2-editenv\] - set boot_counter'; eq "$(cut -d' ' -f2 "$U/probation")" -
s=$(cut -d' ' -f1 "$U/probation"); fkh grubenv boot_success=1; reset_calls; good; eq "$RC" 0
called "snapper\] -c root modify -c number $s"; not_called 'grubby\]'; [[ ! -e $U/probation ]] && _ok || _no "the probation left"

case_ "refused before anything changes: another package manager at work"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44"; fkh procs "/usr/bin/dnf5 install htop"
up; eq "$RC" 1; has "$OUT" "another package manager is running (dnf5) — update again once it has finished"
not_called 'snapper\] -c root create'; eq "$(report)" stopped
has "$(sed -n 2p "$U/report")" "stopped (start): another package manager is running"
case_ "…the games VM holding the graphics card"
back built; reset_calls; gpu card1 0x1002 0x7590 vfio-pci
up; eq "$RC" 1; has "$OUT" "the games VM holds the graphics card — stop it, then update"
case_ "…Btrfs with too little unallocated"
back built; reset_calls; fkh btrfs-unalloc $((2 * 1024 ** 3))
up; eq "$RC" 1; has "$OUT" "only 2.0GB of the disk is unallocated — this needs 5GB"; not_called 'snapper\] -c root create'
case_ "…a stored package without a signature this system trusts: stopped before the snapshot"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44"; fkh rpm-badsig
up; eq "$RC" 1; has "$OUT" "a package is not signed by a key this system trusts — nothing changed"
not_called 'snapper\] -c root create .*before update'; not_called 'dnf\] -y -C replay'

done_
