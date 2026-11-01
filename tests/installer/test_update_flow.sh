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
# (the copy is gone again: nothing left beside the system)
grep -qx /run/fedokawaii/top/root.cand "$FKH/subvolumes" && _no "the copy was left behind" || _ok
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
eq "$(cut -d' ' -f5 "$U/holds")" mesa "its source recorded"; has "$(cut -d' ' -f6- "$U/holds")" "dwl does not start with mesa"
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
eq "$(awk '{ print $5 }' "$U/holds" | sort -u)" kernel "by its source"; has "$(sed -n 2p "$U/report")" "· held: kernel 7.2.13-200.fc44"; lacks "$(sed -n 2p "$U/report")" "kernel-core"
grep -q '^bash 5.3-1.fc44$' "$FKH/evr" && grep -q '^zlib 1.3.1-1.fc44$' "$FKH/evr" && _ok || _no "the rest not in: $(cat "$FKH/evr")"
grep -q '^kernel' "$FKH/evr" && _no "a kernel package went in: $(grep '^kernel' "$FKH/evr")" || _ok
# (one dnf call holds the family — each call loads the repositories; dnf5 skips what is held already)
eq "$(grep -c 'dnf\] -q versionlock exclude' "$CALLS")" 1 "versionlock calls: $(grep 'versionlock exclude' "$CALLS" | tr '\n' '|')"
called 'dnf\] -q versionlock exclude kernel-7\.2\.13-200\.fc44 kernel-core-7\.2\.13-200\.fc44 kernel-modules-7\.2\.13-200\.fc44$'
case_ "…the next press: the holds in force again in one call, none written twice"
reset_calls; up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(grep -c 'dnf\] -q versionlock exclude' "$CALLS")" 1 "versionlock calls: $(grep 'versionlock exclude' "$CALLS" | tr '\n' '|')"
eq "$(sort "$FKH/versionlock" | uniq -d)" "" "a hold written twice"; eq "$(grep -c '^kernel' "$FKH/versionlock")" 3
not_called 'versionlock list'

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
case_ "every run ends without its stored transaction or the downloads kept for the halves — nor its temp folder"
[[ ! -e $U/tx && ! -e $U/try ]] && _ok || _no "left: $(ls "$U")"; called 'dnf\] -q clean packages'
left=$(find "$W/var/tmp" -maxdepth 1 -name 'fedokawaii.*' 2>/dev/null); [[ -z $left ]] && _ok || _no "left in /var/tmp: $left"

case_ "red on the running system (the desktop does not start): the set held, the snapshot offered — his files are still inside /"
back built; reset_calls; pending "mesa 26.0-1.fc44 26.1-1.fc44"
fkh replay-breaks-dwl      # (dwl starts in the copy — the stand-in's checks — but not on the system after the replay)
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(report)" offered; has "$(sed -n 2p "$U/report")" "Super+U → snapshots"
has "$(cat "$U/report")" "the desktop does not start"
grep -q '^mesa 26.1-1.fc44 ' "$U/holds" && _ok || _no "the set not held"
not_called 'kawa-snap\] restore'
eq "$(cut -d' ' -f2 "$W/var/lib/fedokawaii/last-update")" stopped "an undone update is no update"
case_ "…the next press keeps that offered snapshot pinned (the report's way back) until an update is kept — then its probation releases it"
o=$(cat "$U/snap"); rm -f "$FKH/replay-breaks-dwl" "$FKH/dwl-crash"; pending "zlib 1.3-1.fc44 1.3.1-1.fc44"; reset_calls
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"; eq "$(report)" ok
not_called "snapper\] -c root modify -c number $o\$"; [[ ! -e $U/offered ]] && _ok || _no "the offered list left: $(cat "$U/offered")"
grep -q "^$o - " "$U/probation" && _ok || _no "the offered snapshot not the probation's: $(cat "$U/probation" 2>/dev/null)"
fkh grubenv boot_success=1; reset_calls; fkrun bash "$TK/setup.sh" --boot-good; eq "$RC" 0 "$OUT"; called "snapper\] -c root modify -c number $o\$"
case_ "…the same once /home is its own subvolume: the system before it restored for the next start"
back built; pending "mesa 26.0-1.fc44 26.1-1.fc44"; fkh replay-breaks-dwl
fkh versionlock; fkh mounts /run/fedokawaii/top /home
printf '#!/bin/sh\n. /usr/local/bin/_lib.sh\nfkh_log "$*"\nexit 0\n' >"$W/usr/local/sbin/kawa-snap"; chmod 755 "$W/usr/local/sbin/kawa-snap"
reset_calls; up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(report)" restored; called "kawa-snap\] restore $(cat "$U/snap")"
has "$(sed -n 2p "$U/report")" "comes back at the next start"

case_ "…sixty packages red only on the running system: all held together — the report and its notice a line, never sixty names"
back built; reset_calls; rm -f "$U/holds"; set=(); for i in $(seq -w 1 60); do set+=("p$i 1.0-1.fc44 1.1-1.fc44"); done
pending "${set[@]}"; fkh replay-breaks-dwl
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(report)" offered; eq "$(grep -c . "$U/holds")" 60 "all sixty held"
l=$(sed -n 2p "$U/report")
has "$l" "— held: all 60 packages together (which one broke it could not be told apart; newer versions are tried)"
lacks "$l" "p07"; ((${#l} <= 200)) && _ok || _no "${#l} characters: $l"
case_ "…holds from before, four families: two named, then how many more"
back built; reset_calls; mkdir -p "$U"
for f in ant bee cat dog; do printf '%s 2.0-1.fc44 1.0-1.fc44 2026-11-01 %s the desktop does not start\n' "$f-libs" "$f" "$f-tools" "$f"; done >"$U/holds"
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(report)" current; has "$(sed -n 2p "$U/report")" "up to date · held: ant 2.0-1.fc44 · bee 2.0-1.fc44 and 2 more"
rm -f "$U/holds"
case_ "…two sources whose names begin alike, at one version and reason: two families, never merged by the prefix"
back built; reset_calls; mkdir -p "$U"
printf '%s 3.14.1-1.fc44 3.14.0-1.fc44 2026-11-01 %s the desktop does not start\n' python3-foo python-foo python3-bar python-bar >"$U/holds"
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
has "$(sed -n 2p "$U/report")" "up to date · held: python3-foo 3.14.1-1.fc44 · python3-bar 3.14.1-1.fc44"
rm -f "$U/holds"

case_ "the desktop's start check red before the update already: not counted against it — kept, and said"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44"; fkh session-red "not running: waybar"
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(report)" ok; has "$OUT" "red before the update: the desktop does not start: not running: waybar — session-start (dark): not running: waybar"
[[ -s $U/holds ]] && _no "held: $(cat "$U/holds")" || _ok
has "$(sed -n 2p "$U/report")" "updated · 1 package · desktop red before: not judged"
has "$(sed -n '3,$p' "$U/report")" "its desktop items red before it were not judged:"$'\n'"the desktop does not start: not running: waybar"
case_ "…a red before (the bar's clock) never hides another the update brings (dwl gone): red, the set held — each item its own label"
back built; reset_calls; pending "mesa 26.0-1.fc44 26.1-1.fc44"; fkh bar-red "the clock's gaps:  (want 14 date→kanji, 14 kanji→time)"; fkh replay-breaks-dwl
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
has "$OUT" "red before the update: the desktop does not start: bar-geometry (dark): the clock's gaps — "
eq "$(report)" offered "$(tail -n3 <<<"$OUT")"; has "$(cat "$U/report")" "the desktop does not start: dwl does not start"
grep -q '^mesa 26.1-1.fc44 ' "$U/holds" && _ok || _no "the set not held: $(cat "$U/holds" 2>/dev/null)"
case_ "…the bar red before in one item (light: the clock's gaps, its LAST line) and the update makes it grow (dark: rows, its FIRST line): every line of the check passed on — red, the set held"
back built; reset_calls; pending "gtk3 3.24.50-1.fc44 3.24.51-1.fc44"; fkh bar-red "light: the clock's gaps:  (want 14 date→kanji, 14 kanji→time)"; fkh replay-breaks-bar
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
has "$OUT" "red before the update: the desktop does not start: bar-geometry (light): the clock's gaps — "
has "$OUT" "red after the update: "; has "$OUT" "the desktop does not start: bar-geometry (dark): rows — bar-geometry (dark): rows: 0+3"
eq "$(report)" offered "$(tail -n3 <<<"$OUT")"; grep -q '^gtk3 3.24.51-1.fc44 ' "$U/holds" && _ok || _no "the set not held: $(cat "$U/holds" 2>/dev/null)"
case_ "the bar off its measure after the update only: red — the set held, the snapshot offered"
back built; reset_calls; pending "gtk3 3.24.50-1.fc44 3.24.51-1.fc44"
fkh replay-breaks-bar       # (the bar is drawn right before, a row too tall after the replay)
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(report)" offered; has "$(cat "$U/report")" "the desktop does not start"
grep -q '^gtk3 3.24.51-1.fc44 ' "$U/holds" && _ok || _no "the set not held: $(cat "$U/holds" 2>/dev/null)"

case_ "the desktop's check could not run once (a loaded machine): tried again — green, kept"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44"; fkh fail-session-cannot 1
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"; eq "$(report)" ok
eq "$(grep -c '^fkuser\[session-start\.sh\]' "$CALLS")" 3 "twice before (the retry), once after"
case_ "…it cannot run after the replay at all: stopped — nothing held, nothing undone, said; the next press checks again"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44"; fkh replay-blinds-check
up; eq "$RC" 1; has "$OUT" "the desktop's start check could not run (session-start: the kit could not run: hl-dwl: out of time (60 s)) — nothing held, nothing undone"
eq "$(report)" stopped; [[ -s $U/holds ]] && _no "held: $(cat "$U/holds")" || _ok; not_called 'kawa-snap\] restore'
eq "$(cut -d' ' -f1 "$U/phase")" check "the phase kept: the next press resumes at the checks"
sn=$(cat "$U/snap")
reset_calls; up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"; has "$OUT" "its steps and checks again"; eq "$(report)" ok
not_called 'dnf\] .*replay'; not_called "snapper\] -c root modify -c number $sn\$"; grep -q "^$sn " "$U/probation" && _ok || _no "snapshot $sn not the probation's"
case_ "the transaction fails on the running system: undone the same way (offered), the set held"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44"; fkh fail-replay 1
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
eq "$(report)" offered; has "$(cat "$U/report")" "the transaction stopped on the running system"
grep -q '^bash 5.3-1.fc44 ' "$U/holds" && _ok || _no "not held"

case_ "a run cut before its transaction (a power cut: no exit ran): its copy dropped, its pinned snapshot back to the cleanup — first thing, before the space is measured"
back built; reset_calls; mkdir -p "$U"; fkh_add subvolumes /run/fedokawaii/top/root.cand
printf 'snapshot 1\n' >"$U/phase"; echo 7 >"$U/snap"; rm -f "$U/probation"
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"; eq "$(report)" current
called 'snapper\] -c root modify -c number 7$'; called 'btrfs\] subvolume delete --commit-after /run/fedokawaii/top/root.cand'
grep -qx /run/fedokawaii/top/root.cand "$FKH/subvolumes" && _no "the stale copy is still there" || _ok
d=$(grep -n 'subvolume delete' "$CALLS" | head -n1 | cut -d: -f1); f=$(grep -n 'filesystem usage' "$CALLS" | head -n1 | cut -d: -f1)
((d < f)) && _ok || _no "the copy dropped at call $d, the space measured at $f"
case_ "…a green run's snapshot is its probation's: the next press leaves it pinned (released when the trial closes)"
s=$(cut -d' ' -f1 "$U/probation" | tail -n1); [[ $s =~ ^[0-9]+$ ]] && _ok || _no "no snapshot in the probation: $(cat "$U/probation" 2>/dev/null)"
reset_calls; up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"; not_called "snapper\] -c root modify -c number $s\$"
not_called 'subvolume delete'

case_ "stopped from outside while it fetches (systemctl stop, a shutdown: SIGTERM): 143, said as interrupted — never \"built\" — and the next press goes on"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44"
echo '^dnf\] -y --setopt=keepcache=True upgrade --store=' >"$FKH/cut-on"; echo TERM >"$FKH/cut-sig"; chmod 666 "$FKH"/cut-*
up; eq "$RC" 143 "$(tail -n3 <<<"$OUT")"
lacks "$OUT" "Fedokawaii is built"; has "$OUT" "interrupted — press update again (Super+U) to continue"
eq "$(report)" stopped; has "$(sed -n 2p "$U/report")" "stopped (fetch): interrupted — press update again (Super+U) to continue"
grep -q '^bash 5.3' "$FKH/evr" 2>/dev/null && _no "bash went in" || _ok
rm -f "$FKH"/cut-*; reset_calls; up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"; eq "$(report)" ok

case_ "a run cut in its transaction, whole after all: finished — the steps and checks, then kept"
back built; reset_calls; mkdir -p "$U"; printf 'replay 1\n' >"$U/phase"; echo "bash 5.2-1.fc44 5.3-1.fc44" >"$U/set"; : >"$U/baseline"
echo "bash 5.3-1.fc44" >>"$FKH/evr"; fkh_add installed bash; echo 7 >"$U/snap"
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
has "$OUT" "the last update was cut off in its transaction — finishing it first"
eq "$(report)" ok; not_called 'systemd-nspawn'; not_called 'dnf\] .*--store'
grep -q '^7 ' "$U/probation" && _ok || _no "snapshot 7 not the probation's: $(cat "$U/probation" 2>/dev/null)"; not_called 'snapper\] -c root modify -c number 7$'
case_ "a cut run whose transaction still writes (its dnf unit alive): followed to its end first, then judged — whole: kept"
back built; reset_calls; mkdir -p "$U"; printf 'replay 1\n' >"$U/phase"; echo "bash 5.2-1.fc44 5.3-1.fc44" >"$U/set"; : >"$U/baseline"; echo 7 >"$U/snap"
fkh_add installed bash; echo "bash 5.3-1.fc44" >>"$FKH/evr"; fkh_add units "active fedokawaii-dnf-1-1.service"; fkh fail-busy-fedokawaii-dnf-1-1.service 3
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"; has "$OUT" "(fedokawaii-dnf-1-1.service) is still going — followed to its end"
eq "$(report)" ok; not_called 'kawa-snap\] restore'
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
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44"; fkh kernels "$K" "$NEWK"; : >"$W/boot/vmlinuz-$NEWK"; fkh menu "$NEWK" "$K"
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"; eq "$(report)" ok
env_has boot_counter=3; env_has boot_success=0; env_has boot_indeterminate=1
called "grubby\] --update-kernel=/boot/vmlinuz-$NEWK --args=rd.shell=0 rd.emergency=reboot rd.retry=30 panic=10"
grep -qx 'RuntimeWatchdogSec=1min' "$W/etc/systemd/system.conf.d/90-fedokawaii-probation.conf" && _ok || _no "no watchdog while on trial"
eq "$(cut -d' ' -f1,2 "$U/probation")" "$(cat "$U/snap") $NEWK" "the probation: its snapshot, the kernel on trial"
has "$OUT" "kernel $NEWK on trial at the next start: three starts to reach the desktop, else $K again"
case_ "…the next press while it is on trial: no other kernel this time (it would take the fallback's place) — the rest in, said"
pending "bash 5.3-1.fc44 5.4-1.fc44" "kernel-core ${NEWK%.x86_64} 7.3.1-200.fc44"; reset_calls
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"; eq "$(report)" ok
called 'dnf\] -y --setopt=keepcache=True upgrade --store=/var/lib/fedokawaii/update/tx --exclude=kernel,kernel-core,kernel-modules,kernel-modules-core,kernel-modules-extra,kernel-devel,kernel-devel-matched$'
grep -q '^bash 5.4-1.fc44$' "$FKH/evr" && _ok || _no "the rest not in: $(cat "$FKH/evr")"
grep -q '^kernel-core 7.3.1' "$FKH/evr" && _no "a kernel went in while one is on trial" || _ok
has "$OUT" "no new kernel this time: kernel $NEWK is still on trial — restart, and the next update brings it"
case_ "…a start marked good before the counting ran out, on the new kernel: the trial over, the snapshot back to the cleanup"
s=$(cat "$U/snap"); echo "$s $K 2026-11-01" >"$U/probation"; fkh grubenv boot_success=1 boot_counter=2; reset_calls
good; eq "$RC" 0 "$OUT"
called 'grub2-editenv\] - unset boot_counter'; called "grubby\] --update-kernel=/boot/vmlinuz-$K --remove-args=rd.shell=0 rd.emergency=reboot rd.retry=30 panic=10"
called "snapper\] -c root modify -c number $s"; [[ ! -e $U/probation && ! -e $W/etc/systemd/system.conf.d/90-fedokawaii-probation.conf ]] && _ok || _no "the probation or its watchdog left"
case_ "a kernel with a third entry in the boot menu (a rescue image): no trial — GRUB's way back would not be the running kernel — said"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44"; fkh kernels "$K" "$NEWK"; : >"$W/boot/vmlinuz-$NEWK"
fkh menu "$NEWK" "$K" "0-rescue-0123456789abcdef"
[[ ! -e $W/etc/systemd/system.conf.d/90-fedokawaii-probation.conf ]] && _ok || _no "precondition: a watchdog drop-in before the run (this PC's own, leaked?)"
up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"; eq "$(report)" ok
not_called 'grub2-editenv\] - set boot_counter'; not_called "grubby\] --update-kernel=/boot/vmlinuz-$NEWK"
eq "$(cut -d' ' -f2 "$U/probation")" - "no kernel on trial"
[[ ! -e $W/etc/systemd/system.conf.d/90-fedokawaii-probation.conf ]] && _ok || _no "the watchdog on with no trial"
has "$OUT" "kernel $NEWK is not on trial: the boot menu is [$NEWK $K 0-rescue-0123456789abcdef], not [$NEWK $K]"
case_ "GRUB took the one before after three starts: the new kernel held at its version and out, this one the default — said at login"
back built; reset_calls; cut_run; rm -f "$U/phase"; fkh kernels "$K" "$NEWK"; echo "7 $NEWK 2026-11-01" >"$U/probation"
fkh grubenv boot_success=1 boot_counter=-1
good; eq "$RC" 0 "$OUT"
grep -q "^kernel-core ${NEWK%.*} ${K%.*} [0-9-]* kernel did not reach the desktop in three starts$" "$U/holds" && _ok || _no "not held: $(cat "$U/holds" 2>/dev/null)"
called "dnf\] -q versionlock exclude kernel-core-${NEWK%.*}"; called "grubby\] --set-default /boot/vmlinuz-$K"
called "dnf\] -y --disable-repo=\* remove kernel-$NEWK kernel-core-$NEWK kernel-modules-$NEWK kernel-modules-core-$NEWK"
has "$(foryou)" "update-kernel kernel $NEWK did not reach the desktop in three starts back on $K"
called 'grub2-editenv\] - unset boot_counter'; called 'snapper\] -c root modify -c number 7'; [[ ! -e $U/probation ]] && _ok || _no "the probation left"
case_ "the one before chosen in the menu (the counting not run out), or a start not marked good yet: the trial waits — nothing changed"
back built; reset_calls; mkdir -p "$U"; fkh kernels "$K" "$NEWK"; echo "7 $NEWK 2026-11-01" >"$U/probation"; fkh grubenv boot_success=1 boot_counter=2
good; eq "$RC" 0; not_called 'grub2-editenv\] - unset'; not_called 'snapper\] -c root modify'; [[ -s $U/probation ]] && _ok || _no "the probation closed"
fkh grubenv boot_success=0 boot_counter=2; echo "7 $K 2026-11-01" >"$U/probation"; reset_calls
good; eq "$RC" 0; not_called 'grub2-editenv\] - unset'; [[ -s $U/probation ]] && _ok || _no "closed before a good start"
case_ "a mark the path unit missed: the kernels run, a quarter of an hour in, closes the probation — and only then takes the one before"
OLDK=6.19.1-200.fc44.x86_64
back built; reset_calls; mkdir -p "$U"; fkh kernels "$OLDK" "$K"; echo "7 $K 2026-11-01" >"$U/probation"; fkh grubenv boot_success=1 boot_counter=2
fkrun bash "$TK/setup.sh" --kernels; eq "$RC" 0 "$OUT"
u=$(grep -n 'grub2-editenv\] - unset boot_counter' "$CALLS" | cut -d: -f1); r=$(grep -n "dnf\] .*remove .*kernel-core-$OLDK" "$CALLS" | cut -d: -f1)
[[ -n $u && -n $r ]] && ((u < r)) && _ok || _no "closed at $u, the one before removed at $r"
[[ ! -e $U/probation ]] && _ok || _no "the probation left"
case_ "…while a kernel is still on trial, the update's own \"one kernel\" step keeps the one before"
back built; reset_calls; mkdir -p "$U"; fkh kernels "$OLDK" "$K"; echo "7 $K 2026-11-01" >"$U/probation"; fkh grubenv boot_success=1 boot_counter=2
pending "bash 5.2-1.fc44 5.3-1.fc44"; up; eq "$RC" 0 "$(tail -n3 <<<"$OUT")"
has "$OUT" "a kernel is still on trial (the update's probation) — the one before $K stays"; not_called "dnf\] .*remove .*kernel-core-$OLDK"
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
case_ "…a restore waiting for the restart, or a snapshot started from the boot menu: not the system itself"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44"; fkh fsroot-_ /root.old
up; eq "$RC" 1; has "$OUT" "this start is not the system itself"; not_called 'snapper\] -c root create'; not_called 'dnf\] -y --setopt'
rm -f "$FKH/fsroot-_"
case_ "…Btrfs with too little unallocated"
back built; reset_calls; fkh btrfs-unalloc $((2 * 1024 ** 3))
up; eq "$RC" 1; has "$OUT" "only 2.0GB of the disk is unallocated — this needs 5GB"; not_called 'snapper\] -c root create'
case_ "…a stored package without a signature this system trusts: stopped before the snapshot"
back built; reset_calls; pending "bash 5.2-1.fc44 5.3-1.fc44"; fkh rpm-badsig
up; eq "$RC" 1; has "$OUT" "a package is not signed by a key this system trusts — nothing changed"
not_called 'snapper\] -c root create .*before update'; not_called 'dnf\] -y -C replay'

done_
