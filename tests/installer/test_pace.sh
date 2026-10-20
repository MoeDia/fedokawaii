#!/usr/bin/env bash
# tests/installer/test_pace.sh — lib/pace.sh and the report's rows that use it: every start's
# stages read from the journal (the owner's 20 Oct start: 11.5 s firmware, 3.0 s loader, 1.7 s
# kernel, 3.5 s initrd, 5.4 s userspace, the login screen 7.7 s after the kernel), the login
# and its session, each shut down's length and the units killed at their stop time-out; the
# limits and the spread judged; fstab's Btrfs lines given noatime and nothing else changed.
# A stand-in journalctl answers from one file per start. No fake machine.
FK_PURE=1
. "$(dirname "$0")/../lib/harness.sh"
sandbox
. "$REPO/lib/pace.sh"
J=$TMP/j; mkdir -p "$J"
stub journalctl 'case "$*" in
  *--list-boots*) n=$(ls "$TMP/j" | wc -l); i=$((1 - n)); for f in $(ls -tr "$TMP/j"); do printf "%3d %s Tue 2026-10-20 04:00:31 +04 Tue 2026-10-20 04:17:58 +04\n" "$i" "$f"; i=$((i + 1)); done ;;
  *"-b "*) id=$(printf "%s\n" "$@" | sed -n "/^-b$/{n;p;}"); cat "$TMP/j/$id" ;;
esac'
n=0
boot() {   # boot USERSPACE GREETER [SHUT_START SHUT_END [TIMEOUT_UNIT]] — one start's journal (its matched lines)
  n=$((n + 1)); local id; id=$(printf '%032x' "$n")
  {
    printf '[    %s] fedokawaii systemd[1]: Startup finished in 11.481s (firmware) + 3.006s (loader) + 1.674s (kernel) + 3.524s (initrd) + %ss (userspace) = 25.102s.\n' "$(awk -v g="$2" 'BEGIN { printf "%.6f", g + 2 }')" "$1"
    printf '[    %s] fedokawaii systemd[1]: Started greetd.service - Greeter daemon.\n' "$2"
    printf '[    %s] fedokawaii greetd[900]: pam_unix(greetd:session): session opened for user greetd(uid=983) by (uid=0)\n' "$2"
    echo '[   13.774558] fedokawaii greetd[901]: pam_unix(greetd:session): session opened for user kawa(uid=1000) by kawa(uid=0)'
    echo '[   15.100000] fedokawaii systemd[1500]: Reached target dwl-session.target - the dwl session.'
    echo '[   20.000000] fedokawaii systemd[1500]: Startup finished in 210ms.'
    if [[ -n ${3:-} ]]; then
      printf '[ %s] fedokawaii systemd-logind[800]: System is powering down.\n' "$3"
      [[ -n ${5:-} ]] && printf "[ %s] fedokawaii systemd[1]: %s: State 'stop-sigterm' timed out. Killing.\n" "$(awk -v a="$3" 'BEGIN { printf "%.6f", a + 1 }')" "$5"
      printf '[ %s] fedokawaii systemd-journald[600]: Journal stopped\n' "$4"
    fi
  } >"$J/$id"
  touch -d "@$((1760000000 + n))" "$J/$id"
}

case_ "a start's stages, the login screen and the session after the password, read from its journal"
boot 5.416 7.726471 1000.0 1003.5
L=$(pace_boots 10)
eq "$L" "$(printf '%032x' 1) 11.48 3.01 1.67 3.52 5.42 7.73 1.33 3.50 -"
case_ "the greeter's own session (user greetd) is not your login; a start not shut down yet has no length"
rm -f "$J"/*; n=0; boot 5.4 7.7
eq "$(pace_boots 1 | cut -d' ' -f8-10)" "1.33 - -"

case_ "within the limits: stages, even, session, shutdown, shuteven, timeouts all pass (3 starts)"
rm -f "$J"/*; n=0
boot 5.4 7.7 500.0 503.0; boot 5.6 7.9 600.0 604.0; boot 5.5 7.8 700.0 702.5
for w in stages even session shutdown shuteven timeouts; do rc 0 pace_judge "$w" 10; done
has "$(pace_judge even 10)" "spread 0.20 s"
has "$(pace_table 10)" "shutdown"

case_ "a slow start fails 'stages', with the stage named; an uneven one fails 'even'"
boot 14.2 15.9
OUT=$(pace_judge stages 10); RC=$?; eq "$RC" 1; has "$OUT" "userspace: 14.20 s, over 10 s"; has "$OUT" "login screen (from the kernel): 15.90 s"
rc 1 pace_judge even 10
case_ "a shut down that hung on a unit: its length over the limit, the unit named"
boot 5.4 7.7 800.0 831.0 prowlarr.service
OUT=$(pace_judge timeouts 10); RC=$?; eq "$RC" 1; has "$OUT" "prowlarr.service reached the stop time-out"
OUT=$(pace_judge shutdown 10); RC=$?; eq "$RC" 1; has "$OUT" "31.00 s, over 15 s"
rc 1 pace_judge shuteven 10
case_ "only the last N starts are judged"
boot 5.4 7.7 900.0 902.0; boot 5.4 7.7 950.0 952.0; boot 5.5 7.7 990.0 992.0
for w in stages even shutdown timeouts; do rc 0 pace_judge "$w" 3; done
case_ "too few starts for a spread: said, not failed"
rm -f "$J"/*; n=0; boot 5.4 7.7
OUT=$(pace_judge even 10); RC=$?; eq "$RC" 0; has "$OUT" "too few to judge"

case_ "fstab: every Btrfs line gets noatime (relatime out), compress and the rest kept; other lines as they were"
F=$(printf '%s\n' '# /etc/fstab' 'UUID=7ea4 /     btrfs subvol=root,compress=zstd:1 0 0' \
  'UUID=7ea4 /home btrfs subvol=home,relatime,compress=zstd:1,x-systemd.device-timeout=0 0 0' \
  'UUID=AB12 /boot ext4 defaults 1 2' 'UUID=7ea4 /var/x btrfs noatime,noatime,subvol=x 0 0')
G=$(pace_fstab <<<"$F")
has "$G" $'UUID=7ea4\t/\tbtrfs\tsubvol=root,compress=zstd:1,noatime\t0\t0'
has "$G" $'/home\tbtrfs\tsubvol=home,compress=zstd:1,x-systemd.device-timeout=0,noatime'
has "$G" 'UUID=AB12 /boot ext4 defaults 1 2'
has "$G" $'/var/x\tbtrfs\tnoatime,subvol=x\t'
eq "$(pace_fstab <<<"$G")" "$G" "a second pass changes nothing"

# ── the report's rows, as checks() reads them ──
RPT=$REPO/system/fedokawaii-report
row() {
  local line rest
  line=$(awk -v n="$1 | " 'index($0, n) == 1 { print; exit }' "$RPT")
  [[ -n $line ]] || { echo "false # no row $1"; return; }
  rest=${line#* | }; rest=${rest#* | }; rest=${rest#* | }; rest=${rest#* | }
  rest=${rest% | *}; printf '%s' "${rest% | *}"
}
mkdir -p "$TMP/tk/lib"; cp "$REPO/lib/pace.sh" "$TMP/tk/lib/"
run() { OUT=$(TK=$TMP/tk STATE=$TMP/state U=$USER UH=$HOME UIDN=$UID QUICK=0 timeout 20 bash -c "$(row "$1")" 2>&1 </dev/null); RC=$?; }
case_ "the rows: BOOT-40/41/42 and SHUT-01/02/03 pass on even starts, fail on a hung shut down"
rm -f "$J"/*; n=0
boot 5.4 7.7 500.0 503.0; boot 5.6 7.9 600.0 604.0; boot 5.5 7.8 700.0 702.5
for r in "BOOT-40 the start, stage by stage" "BOOT-41 every start as quick" "BOOT-42 the session after your password" \
         "SHUT-01 each shut down's length" "SHUT-02 every shut down as quick" "SHUT-03 no unit killed at its stop time-out"; do
  run "$r"; eq "$RC" 0 "$r: $OUT"
done
run "BOOT-40 the start, stage by stage"; has "$OUT" "firmware"
boot 5.4 7.7 800.0 840.0 podman-prowlarr.service
run "SHUT-01 each shut down's length"; eq "$RC" 1
run "SHUT-03 no unit killed at its stop time-out"; eq "$RC" 1; has "$OUT" "podman-prowlarr.service"
done_
