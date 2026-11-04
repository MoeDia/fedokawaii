#!/usr/bin/env bash
# lane-review: kawa-drives watch + the real kawa-carry hint on the drives fixture: he closes a drive; the line udisks prints is a job's
R=/home/dia/repos/fk-review
. "$R/tests/lib/harness.sh"
D=$R/tests/drives
sandbox
MNT=$TMP/media; mkdir -p "$MNT/KINGSTON" "$MNT/BACKUP" "$MNT/IMAGE"
sed -e "s|@MNT@|$MNT|g" "$D/fixtures/disks.json" >"$TMP/disks.json"
export FAKE_DISKS=$TMP/disks.json
stub lsblk 'exec python3 '"$D"'/fake_lsblk.py "$@"'
mkdir -p "$TMP/Pictures"; : >"$TMP/Pictures/holiday photos.img"
sed "s|/home/me/Pictures|$TMP/Pictures|" "$D/fixtures/losetup.json" >"$TMP/losetup.json"
stub losetup "cat '$TMP/losetup.json'"
stub busctl 'exit 1'
stub setsid; stub udiskie-mount; stub udiskie-umount; stub kawa-term; stub makoctl; stub notify-send; stub kawa-dwlstatus
stub pgrep 'exit 1'; stub kawa-menu 'cat >/dev/null; exit 1'
config .config/fedokawaii/carry.list
echo "--- list:"; kawa-drives list | cut -f1,3,6 | tr '\t' ' '
reset_calls
stub udisksctl 'echo "12:00:00.000: Added /org/freedesktop/UDisks2/jobs/7"'
kawa-drives watch
for _ in {1..30}; do grep -q '^udiskie-mount' "$CALLS" && break; sleep 0.1; done
sleep 1
echo "--- calls after a job's Added line (he only closed a drive):"
grep -E '^(udiskie-mount|notify-send|kawa-carry)' "$CALLS" | cut -c1-120
echo "--- .told: $(ls "$HOME/.local/state/fedokawaii/" 2>/dev/null | tr '\n' ' ')"
done_ 2>/dev/null
