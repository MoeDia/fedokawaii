#!/usr/bin/env bash
# tests/content/test_backup.sh — kawa-backup: your home to a USB drive with restic. The drive is
# a folder here, kawa-drives a stand-in that says whether it is plugged in (and opens it); the
# password sits in secrets.sh as on the desktop; BACKUP_TARGET in the toolkit's fedokawaii.conf,
# as settings saves it (the theme's env still holding the value from before). First what needs
# no restic — where the setting is read from, the words of every "why not" (not set up, not
# plugged in, no password, restic missing, a run going on), the status the menus show,
# --window — then, with the real restic (skipped where it is not
# installed, as Fedora 44 has 0.19.1): the first backup making the repository, a tree with
# Arabic, Japanese and spaced names and a 50 MB file, what the exclude list keeps out, list,
# restoring one file and a folder byte for byte into ~/Restored (never over the original), a
# second backup adding almost nothing, prune, check, a wrong password, the drive pulled, a
# full drive, two runs at once, a run killed halfway and run again.
. "$(dirname "$0")/lib.sh"
RESTIC=$(command -v restic 2>/dev/null)

setup() {   # setup [plugged|closed|unplugged] — a fresh home; KINGSTON in that state (plugged)
  sandbox; toolkit BACKUP_TARGET=KINGSTON
  config .config/fedokawaii/env .config/fedokawaii/backup-exclude   # (env: BACKUP_TARGET="", from before)
  W=$TMP/world; mkdir -p "$W"; export W
  DRIVE=$W/media/KINGSTON; mkdir -p "$DRIVE"; export DRIVE
  echo "${1:-plugged}" >"$W/drive"
  # kawa-drives list: the one line of the stick (its folder empty while closed); open: opened
  stub kawa-drives 'case $1 in
  list) case $(cat "$W/drive") in
          plugged) printf "/dev/sdb1\t/dev/sdb\tKINGSTON\t28.9G\tvfat\t%s\n" "$DRIVE" ;;
          closed)  printf "/dev/sdb1\t/dev/sdb\tKINGSTON\t28.9G\tvfat\t\n" ;;
        esac ;;
  open) [ "$2" = /dev/sdb1 ] || exit 1; echo plugged >"$W/drive"; echo "$DRIVE" ;;
esac'
  stub kawa-float
  # the real restic — or, where there is none, a stand-in the words' cases must never reach
  if [[ -n $RESTIC ]]; then ln -s "$RESTIC" "$STUBS/restic"; else stub restic 'echo "restic ran: $*" >&2; exit 99'; fi
  printf '# mine\nRESTIC_PASSWORD="correct horse"\n' >"$HOME/.config/fedokawaii/secrets.sh"
  chmod 600 "$HOME/.config/fedokawaii/secrets.sh"
}
REC=.local/state/fedokawaii/last-backup
record() { mkdir -p "$HOME/.local/state/fedokawaii"; printf '%s\t1 B\tKINGSTON\n' "$(( $(date +%s) - $1 * 86400 ))" >"$HOME/$REC"; }
notice() { grep '^notify-send' "$CALLS" | tail -n1; }     # the last notice
# the home's own files for a backup: Arabic, Japanese and spaced names, 50 MB of random bytes
home_files() {
  mkdir -p "$HOME/Documents/ملف جديد" "$HOME/Documents/sub dir/deeper" "$HOME/Downloads" "$HOME/.cache/thumbs"
  echo one >"$HOME/Documents/ملف جديد/日本語 ファイル.txt"; echo two >"$HOME/Documents/sub dir/deeper/a b.txt"
  echo three >"$HOME/Documents/report.ods"; echo four >"$HOME/Downloads/keep me.pdf"; echo five >"$HOME/.cache/thumbs/t.png"
  head -c 52428800 /dev/urandom >"$HOME/Documents/big.bin"
}

# ── without restic: the words ────────────────────────────────────────────────
case_ "--help: what it is and every command; misuse: exit 2, nothing run"
setup; out=$(kawa-backup --help); rc 0 kawa-backup --help
for w in "kawa-backup list" "restore PATH" "check" "prune" "init" "status" "where" "RESTIC_PASSWORD" "BACKUP_TARGET"; do has "$out" "$w"; done
rc 2 kawa-backup frobnicate; rc 2 kawa-backup list extra; rc 2 kawa-backup restore; rc 2 kawa-backup status now
not_called 'notify-send'
case_ "status (the menus' word): never · today · yesterday · N days ago; no drive named: not set up"
eq "$(kawa-backup status)" never
record 0; eq "$(kawa-backup status)" today; record 1; eq "$(kawa-backup status)" yesterday; record 12; eq "$(kawa-backup status)" "12 days ago"
printf 'garbage\n' >"$HOME/$REC"; eq "$(kawa-backup status)" never "a corrupt record reads as none"
toolkit BACKUP_TARGET=""; eq "$(kawa-backup status)" "not set up"
case_ "no toolkit (its one place for the settings): said, exit 1"
rm -rf "$KAWA_TOOLKIT"; rc 1 kawa-backup status; has "$(kawa-backup status 2>&1)" "cannot read the toolkit"

case_ "BACKUP_TARGET counts as soon as settings saves it: read from the toolkit's fedokawaii.conf, its one place"
setup; lacks "$(cat "$HOME/.config/fedokawaii/env")" 'BACKUP_' "the theme's env holds no copy"
eq "$(kawa-backup target)" KINGSTON; eq "$(kawa-backup where)" "$DRIVE/fedokawaii-backup"; eq "$(kawa-backup status)" never
conf_set BACKUP_TARGET "" "$KAWA_TOOLKIT/fedokawaii.conf"; eq "$(kawa-backup target)" ""; eq "$(kawa-backup status)" "not set up" "taken out: at once too"
case_ "a toolkit fedokawaii.conf from before the backup settings: none yet, no error"
setup; sed -i '/^BACKUP_/d' "$KAWA_TOOLKIT/fedokawaii.conf"; eq "$(kawa-backup status 2>&1)" "not set up"
case_ "a value against its rule (the file edited by hand, as root): said with its rule and where to put it right — never run"
setup; toolkit 'BACKUP_TARGET=$(touch '"$TMP"'/ran)'
out=$(kawa-backup where 2>&1); eq "$?" 1; has "$out" "fedokawaii.conf: BACKUP_TARGET must be a drive's name"; has "$out" "Super+U → settings"
eq "$(kawa-backup target)" "" "no drive is taken for the backup drive"
rc 1 kawa-backup; has "$(notice)" "fedokawaii.conf: BACKUP_TARGET must be"
[[ ! -e $TMP/ran ]] && _ok || _no "a value in fedokawaii.conf was run"
case_ "the toolkit's files are read, never written"
setup; sum=$(cat "$KAWA_TOOLKIT/fedokawaii.conf" "$KAWA_TOOLKIT/lib/common.sh" | cksum)
kawa-backup status >/dev/null; kawa-backup where >/dev/null; kawa-backup target >/dev/null
eq "$(cat "$KAWA_TOOLKIT/fedokawaii.conf" "$KAWA_TOOLKIT/lib/common.sh" | cksum)" "$sum"

case_ "where: the drive's folder when plugged in; opened first when closed; said when not plugged in"
setup; eq "$(kawa-backup where)" "$DRIVE/fedokawaii-backup"
setup closed; eq "$(kawa-backup where)" "$DRIVE/fedokawaii-backup"; called '^kawa-drives open /dev/sdb1$'
setup unplugged; out=$(kawa-backup where 2>&1); eq "$?" 1; eq "$out" "kawa-backup: KINGSTON is not plugged in"
case_ "where: a path is used as it is, if the folder is there; a restic address as it is"
setup; toolkit BACKUP_TARGET="$W/media/KINGSTON"; eq "$(kawa-backup where)" "$W/media/KINGSTON"
toolkit BACKUP_TARGET="$W/media/gone"; out=$(kawa-backup where 2>&1); eq "$?" 1; has "$out" "$W/media/gone is not there — is the drive plugged in?"
toolkit BACKUP_TARGET="sftp:you@nas:/backups"; eq "$(kawa-backup where)" "sftp:you@nas:/backups"
not_called '^kawa-drives'
case_ "where: no drive named: said, with where to name it"
toolkit BACKUP_TARGET=""; out=$(kawa-backup where 2>&1); eq "$?" 1; has "$out" "no BACKUP_TARGET yet"; has "$out" "settings"

case_ "a backup with no restic: a critical notice that says so, nothing else touched"
setup; rm -f "$STUBS/restic"; out=$(PATH=$(without restic) kawa-backup 2>&1); eq "$?" 1
has "$(notice)" "notify-send -a backup -u critical -- "; has "$(notice)" "not backed up restic is not installed — fedokawaii repair puts it back"
has "$out" "restic is not installed"; [[ ! -e $HOME/$REC && -z $(ls -A "$DRIVE") ]] && _ok || _no "something was written"
case_ "the drive not plugged in, or no drive named: the notice says which"
setup unplugged; rc 1 kawa-backup; has "$(notice)" "not backed up KINGSTON is not plugged in"
toolkit BACKUP_TARGET=""; rc 1 kawa-backup; has "$(notice)" "no BACKUP_TARGET yet"
case_ "the exclude list missing (the theme not applied): said"
setup; rm -f "$HOME/.config/fedokawaii/backup-exclude"; rc 1 kawa-backup; has "$(notice)" "backup-exclude is missing"
case_ "no password: secrets.sh missing, or without the line, or not private (644), or not yours — each said, no repository made"
setup; rm -f "$HOME/.config/fedokawaii/secrets.sh"; rc 1 kawa-backup
has "$(notice)" "no RESTIC_PASSWORD in $HOME/.config/fedokawaii/secrets.sh — add a line RESTIC_PASSWORD="; has "$(notice)" "keep a copy of it elsewhere"
printf 'PROWLARR_API_KEY=abc\n' >"$HOME/.config/fedokawaii/secrets.sh"; chmod 600 "$HOME/.config/fedokawaii/secrets.sh"
rc 1 kawa-backup; has "$(notice)" "no RESTIC_PASSWORD in"
printf 'RESTIC_PASSWORD=x\n' >"$HOME/.config/fedokawaii/secrets.sh"; chmod 644 "$HOME/.config/fedokawaii/secrets.sh"
rc 1 kawa-backup; has "$(notice)" "secrets.sh must be yours and private — chmod 600 it"
[[ -z $(ls -A "$DRIVE") ]] && _ok || _no "a repository was made without a password of yours"
rc 1 kawa-backup list; rc 1 kawa-backup init
case_ "a password in the environment already (a shell that read secrets.sh) is taken as it is"
setup; rm -f "$HOME/.config/fedokawaii/secrets.sh"; rm -f "$STUBS/restic"
stub restic 'echo "restic $*" >>"$W/restic.log"; [ "$3" = cat ] && exit 10; exit 0'
RESTIC_PASSWORD=given kawa-backup >/dev/null 2>&1; has "$(cat "$W/restic.log")" "restic -r $DRIVE/fedokawaii-backup init"
case_ "a run going on (its lock held): said at once, restic never started"
setup; rm -f "$STUBS/restic"; stub restic 'echo ran >>"$W/restic.log"'
( exec 8>"$XDG_RUNTIME_DIR/kawa-backup.lock"; flock 8; exec sleep 30 ) >/dev/null 2>&1 & holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$XDG_RUNTIME_DIR/kawa-backup.lock" true || break; sleep 0.1; done
rc 1 kawa-backup; has "$(notice)" "a backup is running already — wait for its notice"
rc 1 kawa-backup prune; rc 1 kawa-backup check; rc 1 kawa-backup list
[[ ! -e $W/restic.log ]] && _ok || _no "restic ran under another run's lock"
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
case_ "--window: the backup in a floating window of its own (one at a time)"
setup; kawa-backup --window; called '^kawa-float --once backup backup 80x25 -- .*kawa-backup --wait$'
case_ "a home folder with a space: the same words"
setup unplugged; mv "$HOME" "$TMP/my home"; export HOME="$TMP/my home"; rc 1 kawa-backup; has "$(notice)" "KINGSTON is not plugged in"

# ── with restic: the backup itself ───────────────────────────────────────────
if [[ -z $RESTIC ]]; then skip "restic is not installed — the backup itself is not run (Fedora 44 has restic 0.19.1)"; done_; exit; fi
setup; home_files
case_ "the first backup: the repository made on the drive, every file in, the notices at the start and the end"
out=$(kawa-backup 2>&1); r=$?
eq "$r" 0 "$(tail -n 3 <<<"$out" | tr '\n' '|')"
has "$out" "the first backup to $DRIVE/fedokawaii-backup: the repository is made now"
has "$out" "Losing your password means that your data is" "restic's own warning is shown"
[[ -f $DRIVE/fedokawaii-backup/config && -d $DRIVE/fedokawaii-backup/snapshots ]] && _ok || _no "no restic repository on the drive"
called 'notify-send -a backup -p -t 0 -- .*KINGSTON · backing up your home, minus downloads and caches'
has "$(notice)" "KINGSTON · backed up "; has "$(notice)" " files, 50.0"; has "$(notice)" "MiB new, in 0:"
case_ "the record the menus read: now, what was added, the drive"
t=0 added="" target=""; IFS=$'\t' read -r t added target <"$HOME/$REC"
(( $(date +%s) - t < 60 )) && _ok || _no "epoch $t"; has "$added" "MiB"; eq "$target" KINGSTON
eq "$(kawa-backup status)" today
case_ "the log: restic's words, in the cache (not backed up itself)"
has "$(cat "$HOME/.cache/fedokawaii/backup.log")" "snapshot "
R=(restic -r "$DRIVE/fedokawaii-backup"); export RESTIC_PASSWORD="correct horse"
case_ "what is in it: the documents, with their names as they were; not the downloads, not the cache"
ls_=$("${R[@]}" ls latest 2>/dev/null)
has "$ls_" "$HOME/Documents/ملف جديد/日本語 ファイル.txt"; has "$ls_" "$HOME/Documents/sub dir/deeper/a b.txt"
lacks "$ls_" "$HOME/Downloads" "Downloads is left out (arrivals: outside the snapshots too)"
lacks "$ls_" "$HOME/.cache/" "the cache is on the exclude list"
case_ "list: the backups, with their ids"
out=$(kawa-backup list 2>&1); eq "$?" 0; has "$out" "1 snapshots"; has "$out" "$HOME"
id=$(sed -n 's/^\([0-9a-f]\{8\}\)  .*/\1/p' <<<"$out" | head -n1); [[ $id =~ ^[0-9a-f]{8}$ ]] && _ok || _no "no id in: $out"

case_ "restore one file: into ~/Restored/<date>/, byte for byte; the original untouched"
echo changed >"$HOME/Documents/report.ods"
out=$(kawa-backup restore "$HOME/Documents/report.ods" 2>&1); eq "$?" 0 "$out"
f=$(find "$HOME/Restored" -type f -name report.ods); [[ -n $f ]] && _ok || _no "nothing restored: $out"
eq "$(cat "$f")" three; eq "$(cat "$HOME/Documents/report.ods")" changed; has "$out" "restored: $HOME/Restored/"
case_ "restore a folder, by a relative path from inside the home, with Arabic and Japanese and spaces: every byte the same"
rm -r "$HOME/Documents/ملف جديد"
out=$(cd "$HOME/Documents" && kawa-backup restore "ملف جديد" 2>&1); eq "$?" 0 "$out"
d=$(find "$HOME/Restored" -type d -name "ملف جديد" | head -n1); [[ -n $d ]] && _ok || _no "the folder did not come back: $out"
eq "$(cat "$d/日本語 ファイル.txt")" one
out=$(kawa-backup restore "$HOME/Documents/big.bin" 2>&1); eq "$?" 0
cmp -s "$(find "$HOME/Restored" -type f -name big.bin | head -n1)" "$HOME/Documents/big.bin" && _ok || _no "50 MB came back different"
case_ "restore by a snapshot's id; a path that is not in the backup: said, no empty folder left"
rc 0 kawa-backup restore "$HOME/Documents/sub dir/deeper/a b.txt" "$id"
out=$(kawa-backup restore "$HOME/Downloads/keep me.pdf" 2>&1); eq "$?" 1 "a download was never backed up"; has "$out" "in that backup"
n=$(find "$HOME/Restored" -mindepth 1 -maxdepth 1 | wc -l)
out=$(kawa-backup restore "$HOME/Documents/never-was.txt" 2>&1); eq "$?" 1; has "$out" "not in that backup: $HOME/Documents/never-was.txt"
eq "$(find "$HOME/Restored" -mindepth 1 -maxdepth 1 | wc -l)" "$n" "no folder left behind"
out=$(kawa-backup restore "$HOME/Documents/report.ods" deadbeef 2>&1); eq "$?" 1 "an id that is no snapshot"
rc 2 kawa-backup restore "$HOME/x" "not an id"; rc 2 kawa-backup restore /

case_ "a second backup: only what changed goes over (a few KiB, not 50 MB), two snapshots"
reset_calls; echo six >"$HOME/Documents/new.txt"
rc 0 kawa-backup; n=$(notice)
has "$n" "backed up"; lacks "$n" "MiB new" "the big file is not added again"; has "$n" "iB new"
has "$(kawa-backup list)" "2 snapshots"
case_ "Downloads wanted as well: its line deleted from the exclude list, and the next backup has it"
sed -i '\|/Downloads$|d' "$HOME/.config/fedokawaii/backup-exclude"
rc 0 kawa-backup; has "$("${R[@]}" ls latest 2>/dev/null)" "$HOME/Downloads/keep me.pdf"
case_ "prune: the keep rule (7 daily, 4 weekly, 12 monthly); check: a tenth of the data read — both end well"
out=$(kawa-backup prune 2>&1); eq "$?" 0 "$out"; has "$out" "keep"
out=$(kawa-backup check 2>&1); eq "$?" 0 "$out"; has "$out" "no errors were found"; has "$out" "a tenth of the data"
case_ "init when there is a backup already: refused"
out=$(kawa-backup init 2>&1); eq "$?" 1; has "$out" "there is a backup at $DRIVE/fedokawaii-backup already"

case_ "the wrong password (secrets.sh changed): said in the notice, nothing written, exit 1"
printf 'RESTIC_PASSWORD="wrong"\n' >"$HOME/.config/fedokawaii/secrets.sh"; unset RESTIC_PASSWORD
before=$(find "$DRIVE" -type f | wc -l); reset_calls
rc 1 kawa-backup; has "$(notice)" "not backed up the password in $HOME/.config/fedokawaii/secrets.sh is not this backup's"
eq "$(find "$DRIVE" -type f | wc -l)" "$before"; eq "$(kawa-backup status)" today "the record is the last good one"
out=$(kawa-backup list 2>&1); eq "$?" 1; has "$out" "is not this backup's"
printf 'RESTIC_PASSWORD="correct horse"\n' >"$HOME/.config/fedokawaii/secrets.sh"
case_ "the drive pulled out before a backup: not plugged in, said; plugged in closed: opened, backed up"
echo unplugged >"$W/drive"; reset_calls; rc 1 kawa-backup; has "$(notice)" "KINGSTON is not plugged in"
echo closed >"$W/drive"; reset_calls; rc 0 kawa-backup; called '^kawa-drives open /dev/sdb1$'; has "$(notice)" "backed up"

case_ "two at once: the second says a backup is running already (the lock), and does not start restic"
head -c 125829120 /dev/urandom >"$HOME/Documents/bigger.bin"; reset_calls
kawa-backup >"$W/first.out" 2>&1 & first=$!
# (waiting for its first notice, sent once it holds the lock — a probe of the lock would take it
# for a moment, and could be what the first run finds)
for _ in $(seq 1 100); do grep -q 'backing up' "$CALLS" && break; sleep 0.1; done
out=$(kawa-backup 2>&1); eq "$?" 1 "the second run"; has "$out" "a backup is running already"
wait "$first"; eq "$?" 0 "the first run: $(tail -n 2 "$W/first.out" | tr '\n' '|')"
eq "$(grep -c '· backed up ' "$CALLS")" 1 "one backup, one done-notice"
case_ "killed halfway (Super+Q, a power cut), then run again: the stale lock goes, the backup ends; prune and check still run"
echo more >"$HOME/Documents/more.txt"; head -c 62914560 /dev/urandom >"$HOME/Documents/third.bin"
kawa-backup >/dev/null 2>&1 & p=$!
for _ in $(seq 1 100); do [[ -n $(ls "$DRIVE/fedokawaii-backup/locks" 2>/dev/null) ]] && break; sleep 0.05; done
pkill -KILL -P "$p" restic 2>/dev/null; kill -KILL "$p" 2>/dev/null; wait "$p" 2>/dev/null
[[ -n $(ls "$DRIVE/fedokawaii-backup/locks") ]] && _ok || _no "no lock was left to test with"
for _ in $(seq 1 50); do flock -n "$XDG_RUNTIME_DIR/kawa-backup.lock" true && break; sleep 0.1; done   # (tee lets go of the lock as restic dies)
reset_calls; out=$(kawa-backup 2>&1); eq "$?" 0 "$(tail -n 2 <<<"$out" | tr '\n' '|')"; has "$(notice)" "backed up"
rc 0 kawa-backup prune; rc 0 kawa-backup check
eq "$(ls "$DRIVE/fedokawaii-backup/locks" | wc -l)" 0 "no lock left"

case_ "the drive full: said as such (in a 16 MB tmpfs of its own), the record untouched"
if unshare -rm true 2>/dev/null; then
  cp "$HOME/$REC" "$W/rec.before"; reset_calls
  out=$(unshare -rm bash -c 'mount -t tmpfs -o size=16M none "$1"; shift; exec "$@"' _ "$DRIVE" kawa-backup 2>&1); r=$?
  eq "$r" 1 "$(tail -n 2 <<<"$out" | tr '\n' '|')"
  has "$(notice)" "not backed up: the drive is full"; has "$(notice)" "kawa-backup prune"
  cmp -s "$HOME/$REC" "$W/rec.before" && _ok || _no "the record changed on a failed backup"
else skip "no user namespaces here: the full drive is not tried"; fi

done_
