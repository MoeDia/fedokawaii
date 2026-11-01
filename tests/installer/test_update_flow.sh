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
called 'dnf\] -y upgrade --store=/var/lib/fedokawaii/update/tx'
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

case_ "red on the running system (the desktop does not start): the set held, the snapshot offered — his files are still inside /"
back built; reset_calls; pending "mesa 26.0-1.fc44 26.1-1.fc44"
fkh replay-breaks-dwl      # (dwl starts in the copy — the stand-in's checks — but not on the system after the replay)
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(report)" offered; has "$(sed -n 2p "$U/report")" "Super+U → snapshots"
has "$(cat "$U/report")" "the desktop does not start (dwl)"
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
