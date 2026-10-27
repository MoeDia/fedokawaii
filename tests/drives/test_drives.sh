#!/usr/bin/env bash
# tests/drives/test_drives.sh — kawa-drives against a made-up machine: a USB stick, an external
# disk with an encrypted half and an NTFS half, an SD card in the machine's own reader, a DVD
# drive with nothing in it, two disk images (one yours, one root's) and the system's own SSD.
# lsblk answers from fixtures/disks.json (fake_lsblk.py), losetup from fixtures/losetup.json
# (your image's file made in the sandbox; root's is not there, so not yours).
. "$(dirname "$0")/../lib/harness.sh"
D=$(cd "$(dirname "$0")" && pwd)

setup() {   # setup — a fresh sandbox with the fixture machine; $MNT holds real folders for mounts
  sandbox
  MNT=$TMP/media; mkdir -p "$MNT/KINGSTON" "$MNT/BACKUP" "$MNT/IMAGE"
  sed -e "s|@MNT@|$MNT|g" "$D/fixtures/disks.json" >"$TMP/disks.json"
  export FAKE_DISKS=$TMP/disks.json
  stub lsblk 'exec python3 '"$D"'/fake_lsblk.py "$@"'
  mkdir -p "$TMP/Pictures"; : >"$TMP/Pictures/holiday photos.img"
  sed "s|/home/me/Pictures|$TMP/Pictures|" "$D/fixtures/losetup.json" >"$TMP/losetup.json"
  stub losetup "cat '$TMP/losetup.json'"
  stub busctl 'exit 1'                          # (udisks is never asked: a click never waits on it)
  stub setsid; stub udiskie-mount; stub udiskie-umount; stub kawa-term; stub makoctl
  stub pgrep 'exit 1'; stub kawa-menu 'cat >/dev/null; exit 1'
}
mounted() {   # mounted DEV FOLDER|"" — the fixture's mount table, changed in place
  python3 - "$FAKE_DISKS" "$1" "$2" <<'EOF'
import json, sys
f, dev, mp = sys.argv[1:]
t = json.load(open(f))
def walk(ns):
    for n in ns:
        if n["name"] == dev: n["mountpoints"] = [mp or None]
        walk(n.get("children") or [])
walk(t["blockdevices"]); json.dump(t, open(f, "w"))
EOF
}
state() { cat "$XDG_RUNTIME_DIR/kawa-drives/${1##*/}" 2>/dev/null; }

# ── what is listed ───────────────────────────────────────────────────────────
setup
out=$(kawa-drives list)
case_ "the stick, both halves of the external disk, the SD card and your image are listed"
has "$out" $'/dev/sdb1\t/dev/sdb\tKINGSTON\t28.9G\tvfat\t'"$MNT/KINGSTON"
has "$out" $'/dev/mapper/luks-1234\t/dev/sdc\tBACKUP'
has "$out" $'/dev/sdc2\t/dev/sdc\tWD Elements 25A2\t431.5G\tntfs\t' "an unlabelled partition takes the maker and model (spaces trimmed)"
has "$out" $'/dev/mmcblk0p1\t/dev/mmcblk0\tSD card\t59.5G\texfat\t' "an unlabelled card in the machine's reader is 'SD card'"
has "$out" $'/dev/loop0\t/dev/loop0\tholiday photos.img\t' "your unlabelled image is named after its file"
case_ "what is not yours stays out"
lacks "$out" nvme0n1 "the system's own SSD"
lacks "$out" zram0 "the swap in memory"
lacks "$out" loop1 "someone else's disk image"
lacks "$out" /dev/sr0 "an empty DVD drive (nothing to open)"
lacks "$out" $'/dev/sdc1\t' "the locked-and-unlocked LUKS container itself (its inside is listed)"
eq "$(wc -l <<<"$out")" 5 "five file systems"

case_ "a plugged stick lights the bar — the kernel's word (lsblk), no daemon asked on the way"
# (the regression: the bar asked udisks about every disk and drew nothing when it did not
# answer — or took 25 s a disk when it hung — so on the real machine the mark was gone)
reset_calls
out=$(kawa-drives list); eq "$?" 0
has "$out" $'/dev/sdb1\t/dev/sdb\tKINGSTON' "the stick listed"
bar=$(kawa-drives bar); [[ $bar != '{"text":""}' ]] && _ok || _no "a plugged drive gave an empty bar: $bar"
eq "$bar" "{\"text\":\"$(. "$HOME/.config/fedokawaii/icons.sh"; printf '%s' "$ICON_BAR_USB")4\",\"class\":[\"open\",\"count\"]}" \
  "four drives: the mark's bar twin (its 8 px to the value: ICON_BAR_*), then the count"
not_called '^busctl'; not_called '^udisksctl'
case_ "only the stick plugged in (the rest of the machine its own): the bar's mark, alone"
python3 - "$FAKE_DISKS" <<'PY'
import json, sys
t = json.load(open(sys.argv[1])); t["blockdevices"] = [d for d in t["blockdevices"] if d["name"] in ("/dev/sdb", "/dev/nvme0n1", "/dev/zram0")]
json.dump(t, open(sys.argv[1], "w"))
PY
eq "$(kawa-drives bar)" "{\"text\":\"$(. "$HOME/.config/fedokawaii/icons.sh"; printf '%s' "$ICON_USB")\",\"class\":\"open\"}"
setup
case_ "an image goes by its file's owner: yours listed, a service's (root's file) not"
has "$(kawa-drives list)" $'/dev/loop0\t/dev/loop0\tholiday photos.img'
lacks "$(kawa-drives list)" loop1
case_ "lsblk's older flags as strings (\"1\"/\"0\") read the same"
python3 - "$FAKE_DISKS" <<'PY'
import json, sys
t = json.load(open(sys.argv[1]))
for d in t["blockdevices"]: d["rm"] = "1" if d.get("rm") else "0"; d["tran"] = None if d["name"] == "/dev/sdb" else d.get("tran")
json.dump(t, open(sys.argv[1], "w"))
PY
has "$(kawa-drives list)" $'/dev/sdb1\t/dev/sdb\tKINGSTON' "removable \"1\", no transport: a drive"
lacks "$(kawa-drives list)" nvme0n1

case_ "no drives at all: an empty list, an empty bar"
setup; printf '{"blockdevices": []}\n' >"$FAKE_DISKS"
eq "$(kawa-drives list)" ""
eq "$(kawa-drives bar)" '{"text":""}'

case_ "the bar: the mark, lit while one is open, a count past one"
setup
bar=$(kawa-drives bar)
has "$bar" '"class":["open","count"]'
has "$bar" "$(. "$HOME/.config/fedokawaii/icons.sh"; printf %s "$ICON_BAR_USB")4\"" "four drives: sdb, sdc, mmcblk0, loop0"
mounted /dev/sdb1 ""; mounted /dev/mapper/luks-1234 ""; mounted /dev/loop0 ""
has "$(kawa-drives bar)" '"closed"' "nothing open: the quiet mark"
python3 - "$FAKE_DISKS" <<'EOF'
import json, sys
t = json.load(open(sys.argv[1])); t["blockdevices"] = [d for d in t["blockdevices"] if d["name"] in ("/dev/sdb", "/dev/nvme0n1")]
json.dump(t, open(sys.argv[1], "w"))
EOF
eq "$(kawa-drives bar)" "{\"text\":\"$(. "$HOME/.config/fedokawaii/icons.sh"; printf '%s' "$ICON_USB")\",\"class\":\"closed\"}" "one drive: no count"

case_ "a label with quotes, a dollar and a backslash reaches the bar as JSON-safe text and is never run"
setup
python3 - "$FAKE_DISKS" <<'EOF'
import json, sys
t = json.load(open(sys.argv[1]))
t["blockdevices"][0]["children"][0]["label"] = 'my "stick" $(touch /tmp/kawa-pwned) \\ ü'
json.dump(t, open(sys.argv[1], "w"))
EOF
out=$(kawa-drives list)
has "$out" 'my "stick" $(touch /tmp/kawa-pwned) \ ü'
stub kawa-menu 'cat >/dev/null; echo 1'                 # (row 0 is the drives' heading)
kawa-drives menu >/dev/null 2>&1
called "kawa-term yazi $MNT/KINGSTON"
[[ ! -e /tmp/kawa-pwned ]] && _ok || { _no "a label ran as a command"; rm -f /tmp/kawa-pwned; }
kawa-drives bar | python3 -c 'import json,sys; json.load(sys.stdin)' && _ok || _no "the bar's JSON does not parse"

# ── udiskie's events ─────────────────────────────────────────────────────────
case_ "a stick that opens: remembered, the bar poked, the click-to-open notice handed off"
setup
kawa-drives event device_mounted /dev/sdb1 True KINGSTON "DataTraveler 3.0"
has "$(state /dev/sdb1)" $'/dev/sdb\tKINGSTON\topen'
called 'kawa-dwlstatus --poke 13'
called 'setsid -f .*kawa-drives notice-open /dev/sdb1 .*KINGSTON 28.9G vfat · click to open it'

case_ "the notice's click: the files on the drive (notify-send's default action)"
stub notify-send 'echo default'
kawa-drives notice-open /dev/sdb1 "KINGSTON" "click to open it"
called 'notify-send -a drives -A default=open -- KINGSTON click to open'; called "kawa-term yazi $MNT/KINGSTON"
reset_calls; stub notify-send; kawa-drives notice-open /dev/sdb1 "KINGSTON" "…"; not_called kawa-term "closed or timed out: nothing opens"
rc 2 kawa-drives notice-open /dev/sdb1 "KINGSTON"

case_ "the backup drive (BACKUP_TARGET as settings saved it — the real kawa-backup reads it): the notice says so, its click backs up"
setup; toolkit BACKUP_TARGET=BACKUP                                 # (the theme's env still names none)
kawa-drives event device_mounted /dev/mapper/luks-1234 False BACKUP ""
called 'notice-open /dev/mapper/luks-1234 .*BACKUP your backup drive · click to back up now \(last backup: never\) backup$'
reset_calls; kawa-drives event device_mounted /dev/sdb1 True KINGSTON ""
called 'notice-open /dev/sdb1 .*KINGSTON 28.9G vfat · click to open it$' "another drive: the usual notice"
stub notify-send 'echo default'; reset_calls
stub kawa-backup; kawa-drives notice-open /dev/mapper/luks-1234 "BACKUP" "your backup drive · click to back up now" backup
called 'notify-send -a drives -A default=backup -- '; called '^kawa-backup --window$'; not_called kawa-term
case_ "no BACKUP_TARGET (none in settings, no toolkit, no env), or kawa-backup missing: every drive's notice is the usual one"
setup; toolkit; kawa-drives event device_mounted /dev/mapper/luks-1234 False BACKUP ""
called 'notice-open /dev/mapper/luks-1234 .*click to open it$'
setup; rm -f "$HOME/.config/fedokawaii/env"; kawa-drives event device_mounted /dev/sdb1 True KINGSTON ""
called 'click to open it$'
setup; toolkit BACKUP_TARGET=BACKUP; stub kawa-backup 'exit 127'
kawa-drives event device_mounted /dev/mapper/luks-1234 False BACKUP ""; called 'click to open it$'

case_ "opened because you asked (the menu, M in yazi): no notice"
setup; mkdir -p "$XDG_RUNTIME_DIR/kawa-drives"; : >"$XDG_RUNTIME_DIR/kawa-drives/asked.sdb"
kawa-drives event device_mounted /dev/sdb1 True KINGSTON ""
not_called 'notice-open'

case_ "the machine's own disk opening: ignored completely"
setup
kawa-drives event device_mounted /dev/nvme0n1p1 False "" ""
not_called 'notice-open'; not_called 'kawa-dwlstatus'
eq "$(state /dev/nvme0n1p1)" ""

case_ "an unlocked encrypted drive counts as the system's to udisks, but its drive is external"
setup
kawa-drives event device_mounted /dev/mapper/luks-1234 False BACKUP ""
has "$(state /dev/mapper/luks-1234)" $'/dev/sdc\tBACKUP\topen'
called 'notice-open /dev/mapper/luks-1234'

case_ "an image you opened yourself (HintSystem true, set up by you): like a stick"
setup
kawa-drives event device_mounted /dev/loop0 False "" ""
has "$(state /dev/loop0)" $'/dev/loop0\tholiday photos.img'
case_ "someone else's image (root's, set up by a service): ignored"
reset_calls; kawa-drives event device_mounted /dev/loop1 False "" ""
not_called 'notice-open'

case_ "pulled out while open: a critical notice"
setup
kawa-drives event device_mounted /dev/sdb1 True KINGSTON ""
reset_calls
kawa-drives event device_unmounted /dev/sdb1 True KINGSTON ""
kawa-drives event device_removed /dev/sdb1 True KINGSTON ""
called 'notify-send -a drives -u critical -- .*KINGSTON was pulled out while open'
eq "$(state /dev/sdb1)" "" "forgotten"

case_ "closed a while ago, then pulled: no warning (it was safe)"
setup
kawa-drives event device_mounted /dev/sdb1 True KINGSTON ""
printf '/dev/sdb\tKINGSTON\tclosed\t%s\n' $((EPOCHSECONDS - 60)) >"$XDG_RUNTIME_DIR/kawa-drives/sdb1"
reset_calls; kawa-drives event device_removed /dev/sdb1 True KINGSTON ""
not_called 'critical'

case_ "ejected, then gone: no warning"
setup
kawa-drives event device_mounted /dev/sdb1 True KINGSTON ""
: >"$XDG_RUNTIME_DIR/kawa-drives/eject.sdb"
reset_calls; kawa-drives event device_unmounted /dev/sdb1 True KINGSTON ""; kawa-drives event device_removed /dev/sdb1 True KINGSTON ""
not_called 'critical'

case_ "an old eject mark does not hide a real pull-out"
setup
kawa-drives event device_mounted /dev/sdb1 True KINGSTON ""
: >"$XDG_RUNTIME_DIR/kawa-drives/eject.sdb"; touch -d '-5 minutes' "$XDG_RUNTIME_DIR/kawa-drives/eject.sdb"
reset_calls; kawa-drives event device_removed /dev/sdb1 True KINGSTON ""
called 'critical'

case_ "a drive plugged in again forgets the marks of the one before (also a card's reader)"
setup; mkdir -p "$XDG_RUNTIME_DIR/kawa-drives"
: >"$XDG_RUNTIME_DIR/kawa-drives/eject.sdb"; : >"$XDG_RUNTIME_DIR/kawa-drives/asked.sdb"
kawa-drives event device_added /dev/sdb1 True "" ""
[[ ! -e $XDG_RUNTIME_DIR/kawa-drives/eject.sdb && ! -e $XDG_RUNTIME_DIR/kawa-drives/asked.sdb ]] && _ok || _no "marks of /dev/sdb survived a new partition"

case_ "misuse"
rc 2 kawa-drives event device_mounted
rc 2 kawa-drives open
rc 2 kawa-drives frobnicate
rc 2 kawa-drives passphrase

# ── eject ────────────────────────────────────────────────────────────────────
umount_ok() {   # udiskie-umount that closes every file system of the fixture's drive
  stub udiskie-umount 'python3 - "$FAKE_DISKS" <<'"'"'EOF'"'"'
import json, sys
t = json.load(open(sys.argv[1]))
def walk(ns):
    for n in ns:
        n["mountpoints"] = [None] if n["name"] not in ("/dev/nvme0n1p1", "/dev/nvme0n1p2") else n["mountpoints"]
        walk(n.get("children") or [])
walk(t["blockdevices"]); json.dump(t, open(sys.argv[1], "w"))
EOF'
}
case_ "eject: written out, closed, switched off (a stick that says its media come out: ejected)"
setup; umount_ok
kawa-drives event device_mounted /dev/sdb1 True KINGSTON ""; reset_calls
rc 0 kawa-drives eject /dev/sdb1
called 'udiskie-umount --force --eject /dev/sdb'
called 'notify-send -a drives -- .*KINGSTON safe to unplug'
eq "$(state /dev/sdb1)" "" "forgotten"
[[ -e $XDG_RUNTIME_DIR/kawa-drives/eject.sdb ]] && _ok || _no "no eject mark (its removal would read as pulled out)"

case_ "eject: a drive that does not say so is switched off (--detach); an image is just closed"
setup; umount_ok
rc 0 kawa-drives eject /dev/sdc2
called 'udiskie-umount --force --detach /dev/sdc'
reset_calls; rc 0 kawa-drives eject /dev/loop0
called 'notify-send -a drives -- .*closed'

case_ "eject while a program still works in the drive: which one, and nothing switched off"
setup
stub udiskie-umount 'echo "failed to unmount /org/freedesktop/UDisks2/block_devices/sdb1: GDBus.Error:org.freedesktop.UDisks2.Error.DeviceBusy: Error unmounting /dev/sdb1: target is busy" >&2'
(cd "$MNT/KINGSTON" && exec sleep 30) & holder=$!
sleep 0.2
rc 1 kawa-drives eject /dev/sdb1
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
called '-- .*KINGSTON is in use still open in: sleep'
[[ ! -e $XDG_RUNTIME_DIR/kawa-drives/eject.sdb ]] && _ok || _no "the eject mark stayed after a refused eject"

case_ "eject refused with no program of yours to name: udisks' own reason"
setup
stub udiskie-umount 'echo "failed to unmount /org/freedesktop/UDisks2/block_devices/sdb1: GDBus.Error:org.freedesktop.UDisks2.Error.Failed: Error unmounting /dev/sdb1: target is busy" >&2'
rc 1 kawa-drives eject /dev/sdb1
called 'is in use target is busy — close what uses it'

case_ "eject that times out while the drive is still writing: says so"
setup
stub udiskie-umount 'echo "failed to unmount /org/freedesktop/UDisks2/block_devices/sdb1: Timeout was reached" >&2'
rc 1 kawa-drives eject /dev/sdb1
called 'still being written to'

case_ "a slow write-out: a notice says so, and the result takes its place"
setup; umount_ok
stub sync 'sleep 2'
stub notify-send 'case "$*" in *" -p "*|*"-p "*) echo 4242 ;; esac'
rc 0 kawa-drives eject /dev/sdb1
called 'notify-send -a drives -p -t 0 -- .*writing what is still on its way'
called 'notify-send -a drives -r 4242 -- .*safe to unplug'

case_ "pulled out during the write-out: a pulled-out notice, not 'safe to unplug'"
setup
kawa-drives event device_mounted /dev/sdb1 True KINGSTON ""; reset_calls
stub sync 'python3 - "$FAKE_DISKS" <<'"'"'EOF'"'"'
import json, sys
t = json.load(open(sys.argv[1])); t["blockdevices"] = [d for d in t["blockdevices"] if d["name"] != "/dev/sdb"]
json.dump(t, open(sys.argv[1], "w"))
EOF'
# (the fixture's /dev/sdb is not a real block device: -b fails, as for a stick that is gone)
rc 1 kawa-drives eject /dev/sdb1
called 'critical .*KINGSTON was pulled out .*before it was all written out'
not_called 'safe to unplug'

case_ "eject of something no longer there"
setup
rc 0 kawa-drives eject /dev/sdz9
called 'no longer plugged in'

# ── open ─────────────────────────────────────────────────────────────────────
case_ "open: already open → its folder, nothing mounted again"
setup
eq "$(kawa-drives open /dev/sdb1)" "$MNT/KINGSTON"
not_called 'udiskie-mount'

case_ "open a closed one: mounted through udiskie, asked mark set (no notice for it)"
setup; mounted /dev/sdc2 ""
stub udiskie-mount 'python3 - "$FAKE_DISKS" <<'"'"'EOF'"'"'
import json, sys
t = json.load(open(sys.argv[1]))
def walk(ns):
    for n in ns:
        if n["name"] == "/dev/sdc2": n["mountpoints"] = ["/run/media/x/WIN"]
        walk(n.get("children") or [])
walk(t["blockdevices"]); json.dump(t, open(sys.argv[1], "w"))
EOF'
eq "$(kawa-drives open /dev/sdc2)" /run/media/x/WIN
called 'udiskie-mount --recursive /dev/sdc2'
[[ -e $XDG_RUNTIME_DIR/kawa-drives/asked.sdc ]] && _ok || _no "no asked mark"

case_ "open fails, udiskie not running: the reason in a notice"
setup; mounted /dev/sdc2 ""
stub udiskie-mount 'echo "failed to mount /dev/sdc2: GDBus.Error:org.freedesktop.UDisks2.Error.NotAuthorizedCanObtain: Not authorized" >&2; exit 1'
rc 1 kawa-drives open /dev/sdc2
called 'not opened — Not authorized'

case_ "open fails as a udisks job while udiskie runs: udiskie has said it (no second notice)"
setup; mounted /dev/sdc2 ""; stub pgrep 'exit 0'
stub udiskie-mount 'echo "failed to mount /dev/sdc2: GDBus.Error:org.freedesktop.UDisks2.Error.Failed: wrong fs type" >&2; exit 1'
rc 1 kawa-drives open /dev/sdc2
not_called 'not opened'

case_ "files: opened, then yazi in a window of its own"
setup
rc 0 kawa-drives files /dev/sdb1
called "setsid -f kawa-term yazi $MNT/KINGSTON"

# ── the passphrase box ───────────────────────────────────────────────────────
case_ "passphrase: hidden typing, the label in the prompt, Esc = status 1 and nothing printed"
setup
stub kawa-menu 'echo "s3cret pass"'
eq "$(kawa-drives passphrase /dev/sdc1 vault "")" "s3cret pass"
called "^kawa-menu --title vault · passphrase --prompt $(. "$HOME/.config/fedokawaii/icons.sh"; printf '%s' "$ICON_LOCK")   --password --width 40\$"
stub kawa-menu 'exit 1'
out=$(kawa-drives passphrase /dev/sdc1 vault ""); r=$?
eq "$r" 1 "Esc must fail so udiskie leaves it locked"; eq "$out" ""
case_ "passphrase: a very long name is cut to fit"
stub kawa-menu 'echo x'
kawa-drives passphrase /dev/sdc1 "A really very extremely long volume name indeed" "" >/dev/null
called 'A really very extremely · passphrase'

# ── the menu ─────────────────────────────────────────────────────────────────
case_ "menu: the rows, then each choice does what it says"
setup; umount_ok
stub kawa-menu 'cat >"$TMP_MENU"; echo 9'
export TMP_MENU=$TMP/menu.txt
kawa-drives menu
rows=$(cat "$TMP_MENU")
ICON_EJECT=$(. "$HOME/.config/fedokawaii/icons.sh"; printf '%s' "$ICON_EJECT")
ICON_DRIVE=$(. "$HOME/.config/fedokawaii/icons.sh"; printf '%s' "$ICON_DRIVE")
eq "$(head -n1 <<<"$rows")" "part	$ICON_DRIVE	drives" "the drives under their heading (the panel's line format)"
eq "$(sed -n '2,6p' <<<"$rows" | cut -f1,2,4 | sort -u | tr '\n' '|')" "on	$ICON_DRIVE	open|row	$ICON_DRIVE	closed|" "a row a file system: open (lit) or closed in its own column"
[[ $(sed -n 2p <<<"$rows" | cut -f5) =~ ^[0-9.]+[KMGT]?B?$|^[0-9.,]+\ ?[KMGT]i?B$ ]] && _ok || _no "the size as the row's value: $(sed -n 2p <<<"$rows")"
eq "$(sed -n 7p <<<"$rows")" "part	$ICON_EJECT	eject" "the second heading right after (the panel spaces its parts)"
ej=$(sed -n '8,$p' <<<"$rows")
has "$ej" "row	$ICON_EJECT	KINGSTON"; has "$ej" "row	$ICON_EJECT	BACKUP" "a drive is named by its first file system, under the eject heading"
lacks "$rows" "eject KINGSTON" "the heading says eject: the rows do not again"
eq "$(grep -c . <<<"$rows")" 11 "a heading, 5 file systems, a heading, 4 drives to eject"
called 'kawa-menu --drop --index --select 1$' "a dropdown, sized to its content, the cursor's first key on the first drive"
called 'notify-send .*(safe to unplug|closed)'
case_ "menu: Esc does nothing"
reset_calls; stub kawa-menu 'exit 1'
rc 0 kawa-drives menu
not_called 'udiskie'
case_ "menu with nothing plugged in: one quiet row"
printf '{"blockdevices": []}\n' >"$FAKE_DISKS"
stub kawa-menu 'cat >"$TMP_MENU"; exit 1'
reset_calls; kawa-drives menu; eq "$(cat "$TMP_MENU" | tr '\n' '|')" "part	$ICON_DRIVE	drives|off	$ICON_DRIVE	nothing plugged in|" "faint, nothing to choose"
called 'kawa-menu --drop --index$' "no cursor place: nothing to choose"

# ── ~/Drives: a folder per open drive ────────────────────────────────────────
case_ "~/Drives: each open drive a link by its menu name; the folder there with none open too"
setup; stub udisksctl 'exit 0'                         # (the monitor: no events, then gone)
mounted /dev/sdb1 ""; mounted /dev/mapper/luks-1234 ""; mounted /dev/loop0 ""
kawa-drives watch; [[ -d $HOME/Drives && -z $(ls -A "$HOME/Drives") ]] && _ok || _no "no empty ~/Drives: $(ls -A "$HOME/Drives" 2>&1)"
mounted /dev/sdb1 "$MNT/KINGSTON"
kawa-drives watch; eq "$(readlink "$HOME/Drives/KINGSTON")" "$MNT/KINGSTON"
case_ "~/Drives: a link left by a drive since closed goes; yours (a file, a link elsewhere) stay"
ln -s /run/media/me/OLD "$HOME/Drives/OLD"; ln -s "$TMP" "$HOME/Drives/mine"; echo n >"$HOME/Drives/notes.txt"
kawa-drives watch
[[ ! -L $HOME/Drives/OLD ]] && _ok || _no "the closed drive's link stayed"
[[ -L $HOME/Drives/mine && -f $HOME/Drives/notes.txt && -L $HOME/Drives/KINGSTON ]] && _ok || _no "$(ls -A "$HOME/Drives" | tr '\n' '|')"

done_
