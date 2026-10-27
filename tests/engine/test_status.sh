#!/usr/bin/env bash
# tests/engine/test_status.sh — `fedokawaii status`, `remind` and the season's records, as
# root's runs leave them: none yet, good ones, stopped ones (a power cut mid-update), corrupt
# ones, a run going on right now. What the user reads must be true, fit its column, and never
# run anything a record says.
. "$(dirname "$0")/lib.sh"

fresh() { sandbox; engine_world; }
line() { grep -m1 "^$1 " <<<"$2"; }          # line KEY STATUS → that key's line

# ── a new install ────────────────────────────────────────────────────────────
fresh
out=$(fedokawaii status 2>&1); r=$?
case_ "first run after setup: nothing recorded yet"
eq "$r" 0
has "$(line release "$out")" "Fedora 44"
has "$(line updated "$out")" "none since setup"
has "$(line verified "$out")" "not yet"
has "$(line due "$out")" "in 60 days" "the season counts from setup (30 days ago, every 90)"
has "$(line kernel "$out")" "6.17.1-300.fc44.x86_64"
has "$(line disk "$out")" "641 GB free of 2.0 TB"
has "$(line backup "$out")" "no drive · quick settings → backup"; lacks "$(line backup "$out")" "BACKUP_TARGET" "(no setting's name on the screen)"
lacks "$out" "running"; lacks "$out" "low"
case_ "every status line fits the menu's pane (9 + 35 characters)"
(( $(widest "$out") <= 44 )) && _ok || _no "a line of $(widest "$out") characters: $out"

case_ "the state folder missing entirely (setup never ran here): no error"
rm -rf "$R/state"
out=$(fedokawaii status 2>&1); r=$?
eq "$r" 0; has "$out" "none since setup"; lacks "$out" "No such file"

# ── updates recorded ─────────────────────────────────────────────────────────
case_ "an update 10 days ago: its day, and the next one in 80 days"
fresh; rec last-update "$(ago_s 10) ok"; rec last-update-done "$(ago_s 10)"
out=$(fedokawaii status)
has "$(line updated "$out")" "$(date -d "@$(ago_s 10)" '+%-d %b %Y') · 10 days ago"
has "$(line due "$out")" "in 80 days"
case_ "an update with parts left, one whose checks failed: said under it"
rec last-update "$(ago_s 1) partial"; has "$(fedokawaii status)" "some parts left for the next one"
rec last-update "$(ago_s 1) checks"; has "$(fedokawaii status)" "verify found problems: repair"
case_ "…and a clean verify since: answered, no longer said (one before it, or one finding something, still is)"
rec last-verify "$(( $(date +%s) - 60 )) 257 0 0"; lacks "$(fedokawaii status)" "verify found problems"
rec last-verify "$(( $(ago_s 1) - 60 )) 257 0 0"; has "$(fedokawaii status)" "verify found problems: repair"
rec last-verify "$(( $(date +%s) - 60 )) 250 7 0"; has "$(fedokawaii status)" "verify found problems: repair"
rm -f "$R/state/last-verify"; rec last-after-dnf "$(ago_s 1) failed"; has "$(line dnf "$(fedokawaii status)")" "left something · repair"
rec last-verify "$(( $(date +%s) - 60 )) 257 0 0"; lacks "$(fedokawaii status)" "left something"

case_ "an update cut off (power cut) after a good one: the good one is the last update"
fresh; rec last-update-done "$(ago_s 100)"; rec last-update "$(ago_s 0) stopped"
out=$(fedokawaii status)
has "$(line updated "$out")" "100 days ago" "the date of the last update that finished"
lacks "$(line updated "$out")" "today" "a run that stopped is not an update"
has "$out" "stopped" "the try that stopped is still mentioned"
has "$(line due "$out")" "now" "still due: the stopped run did not count"
(( $(widest "$out") <= 44 )) && _ok || _no "too wide: $out"
case_ "the menu agrees: update is due, the title names the last finished update"
rows=$(plain "$(fedokawaii --rows update)")   # (the update tab)
has "$(grep -m1 '^update' <<<"$rows")" "due"

case_ "an update cut off with none before it: none since setup, and the try mentioned"
fresh; rec last-update "$(ago_s 2) stopped"
out=$(fedokawaii status)
has "$(line updated "$out")" "none since setup"; has "$out" "stopped"
case_ "an old install (no last-update-done record): a finished last-update counts"
fresh; rec last-update "$(ago_s 20) ok"
has "$(line due "$(fedokawaii status)")" "in 70 days"

case_ "corrupt records: garbage, empty, a cut-off line, binary — read as none, quietly"
for bad in "garbage here" "" "17" $'\x01\x02\xff\xfe' "$(ago_s 3)"; do
  fresh; printf '%s' "$bad" >"$R/state/last-update"; printf '%s' "$bad" >"$R/state/last-update-done"
  printf '%s' "$bad" >"$R/state/last-verify"; printf '%s' "$bad" >"$R/state/snapshots"
  out=$(fedokawaii status 2>&1); r=$?
  eq "$r" 0 "status failed on [$bad]"
  lacks "$out" "syntax error"; lacks "$out" "line "; lacks "$out" "integer"
  (( $(widest "$out") <= 44 )) && _ok || _no "too wide with [$bad]: $out"
done
case_ "a record from a clock that ran ahead never puts the season off"
fresh; rec last-update-done $(( $(date +%s) + 400 * DAY ))
has "$(line due "$(fedokawaii status)")" "in 90 days"

# ── verify's outcome ─────────────────────────────────────────────────────────
case_ "verify's outcome: passed, passed with warnings, things to fix"
fresh; rec last-verify "$(ago_s 2) 180 0 0";  has "$(line verified "$(fedokawaii status)")" "180 checks passed · 2 days ago"
rec last-verify "$(ago_s 0) 180 0 1";         has "$(line verified "$(fedokawaii status)")" "passed, 1 warning · today"
rec last-verify "$(ago_s 0) 180 0 3";         has "$(line verified "$(fedokawaii status)")" "passed, 3 warnings"
rec last-verify "$(ago_s 1) 170 4 0";         has "$(line verified "$(fedokawaii status)")" "4 to fix · yesterday (repair)"
case_ "a record that holds a command is never run (arithmetic on it is guarded)"
for w in 'a[$(touch "$FK_R/pwned")]' '1a' 'x'; do
  rec last-verify "$(ago_s 0) 180 0 $w"
  out=$(fedokawaii status 2>&1)
  [[ ! -e $R/pwned ]] && _ok || { _no "a record ran a command ($w)"; rm -f "$R/pwned"; }
  lacks "$out" "error" "[$w] made noise"
done
rm -f "$R/pwned"

# ── the machine ──────────────────────────────────────────────────────────────
case_ "a newer kernel installed: restart for it (its name fits)"
fresh; echo 6.17.10-1300.fc44.x86_64 >"$R/newest-kernel"
has "$(line kernel "$(fedokawaii status)")" "6.17.10-1300.fc44 · restart for it"
case_ "little room left: low"
echo "2000000000000 12000000000" >"$R/df"
has "$(line disk "$(fedokawaii status)")" "12 GB free of 2.0 TB · low"
case_ "df failing: no disk line, no noise"
stub df 'exit 1'; out=$(fedokawaii status 2>&1); lacks "$out" "disk"; eq "$?" 0
case_ "rpm missing (or failing): the running kernel"
stub rpm 'exit 127'; has "$(line kernel "$(fedokawaii status)")" "6.17.1-300.fc44.x86_64"

case_ "packages Fedora no longer has: whole names while they fit, then how many more — never a name cut, never an ellipsis"
fresh; printf '%s\n' libfoo-tools some-long-retired-package-name another-one >"$R/state/unavailable"
l=$(line retired "$(fedokawaii status)")
has "$l" "libfoo-tools +2"; lacks "$l" "…"; lacks "$l" "some-long"
(( ${#l} <= 44 )) && _ok || _no "retired line too long: $l"
printf '%s\n' gtk2 libfoo >"$R/state/unavailable"
has "$(line retired "$(fedokawaii status)")" "gtk2 libfoo"
printf '%s\n' python3-a-package-name-far-too-long-for-the-line >"$R/state/unavailable"
has "$(line retired "$(fedokawaii status)")" "1 package"
printf '%s\n' python3-a-package-name-far-too-long-for-the-line libfoo >"$R/state/unavailable"
has "$(line retired "$(fedokawaii status)")" "2 packages"
printf '\n\n' >"$R/state/unavailable"
lacks "$(fedokawaii status)" "retired"
case_ "config files to compare after a move: counted, the list named"
printf '/etc/a.rpmnew\n/etc/b.rpmsave\n' >"$R/state/rpmnew"
out=$(fedokawaii status); has "$out" "2 config files after the move"; has "$out" "(the list: $R/state/rpmnew)"
printf '/etc/a.rpmnew\n' >"$R/state/rpmnew"; has "$(fedokawaii status)" "1 config file after the move"

# ── Fedora's releases ────────────────────────────────────────────────────────
case_ "support known from os-release: the day, and how far"
fresh; out=$(fedokawaii status)
has "$(line support "$out")" "until 19 May 2027 · in"
has "$(line next "$out")" "Fedora 45"
case_ "support ended: move on"
sed -i 's/^SUPPORT_END=.*/SUPPORT_END=2026-01-01/' "$R/os-release"
has "$(line support "$(fedokawaii status)")" "ended 1 Jan 2026 — move on"
case_ "no SUPPORT_END: estimated (about)"
sed -i '/^SUPPORT_END/d' "$R/os-release"
has "$(line support "$(fedokawaii status)")" "until about"
case_ "the next release out 70 days ago (recorded by an update): ready to move"
fresh; rec release-45 "$(ago_s 70)"
has "$(line next "$(fedokawaii status)")" "Fedora 45 · ready to move to"
case_ "out 10 days ago: offered once settled (60 days)"
rec release-45 "$(ago_s 10)"; has "$(line next "$(fedokawaii status)")" "offered in 50 days"
case_ "os-release unreadable: no made-up release or dates"
fresh; rm -f "$R/os-release"
out=$(fedokawaii status 2>&1); r=$?
eq "$r" 0; lacks "$out" "Fedora 0"; lacks "$out" "Fedora 1 "
has "$(line release "$out")" "unknown"
case_ "a move between releases: told for two months, then not"
fresh; rec last-upgrade "$(ago_s 3) 43 44 ok"
has "$(line moved "$(fedokawaii status)")" "Fedora 43 → 44 ·"
rec last-upgrade "$(ago_s 3) 43 44 failed"; has "$(line moved "$(fedokawaii status)")" "to Fedora 44 failed"
rec last-upgrade "$(ago_s 3) 43 44 partial"; has "$(line moved "$(fedokawaii status)")" "· repair"
rec last-upgrade "$(ago_s 61) 43 44 ok"; lacks "$(fedokawaii status)" "moved"

# ── a run going on (root's lock) ─────────────────────────────────────────────
case_ "an update running now (its lock held): said first, and in the menu"
fresh; : >"$R/state/lock"
( exec 9>"$R/state/lock"; flock 9; exec sleep 30 ) >/dev/null 2>&1 & holder=$!   # (sleep itself holds it)
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$R/state/lock" true || break; sleep 0.1; done
out=$(fedokawaii status)
eq "$(head -n1 <<<"$out")" "running   an update or a repair, now" "(the keys' column two clear of the longest, verified)"
has "$(grep -m1 '^update' <<<"$(plain "$(fedokawaii --rows update)")")" "running"
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
case_ "a stale lock (left by a run that crashed: the file, nobody holding it) is not a run"
out=$(fedokawaii status); lacks "$out" "running"
case_ "a lock file root keeps private: not a run, no error"
chmod 000 "$R/state/lock"; out=$(fedokawaii status 2>&1); [[ $EUID == 0 ]] || lacks "$out" "Permission"; lacks "$out" "running"

# ── the environment ──────────────────────────────────────────────────────────
case_ "the user's locale (Turkish, Arabic) changes nothing: English dates, same width"
fresh; rec last-update "$(ago_s 10) ok"; rec last-update-done "$(ago_s 10)"
ref=$(fedokawaii status 2>/dev/null)
for loc in tr_TR.UTF-8 ar_EG.UTF-8; do eq "$(LC_ALL=$loc LANG=$loc fedokawaii status 2>/dev/null)" "$ref" "$loc"; done
case_ "a home with a space, no XDG folders, no runtime folder: still works"
mkdir -p "$TMP/my home"; out=$(HOME="$TMP/my home" XDG_CONFIG_HOME='' XDG_CACHE_HOME='' XDG_RUNTIME_DIR='' fedokawaii status 2>&1); r=$?
eq "$r" 0; has "$out" "release"

# ── reminders ────────────────────────────────────────────────────────────────
case_ "remind check: nothing due"
fresh; rec last-update-done "$(ago_s 10)"; rec last-update "$(ago_s 10) ok"
has "$(fedokawaii remind check)" "nothing due — the next update in 80 days"
eq "$(fedokawaii remind)" "$(fedokawaii remind check)" "check is the default"
case_ "remind check: due — how long since the last update"
rec last-update-done "$(ago_s 95)"; has "$(fedokawaii remind check)" "the update season is here: 95 days since the last update"
case_ "remind check: a new Fedora has settled"
rec release-45 "$(ago_s 70)"; has "$(fedokawaii remind check)" "Fedora 45 has settled"
case_ "remind check: support ends within a month comes first"
sed -i "s/^SUPPORT_END=.*/SUPPORT_END=$(date -d '+20 days' +%F)/" "$R/os-release"
has "$(fedokawaii remind check)" "Fedora 44's support ends"

case_ "remind quiet (the session's timer): one notice a day, as the desktop's"
fresh; rec last-update-done "$(ago_s 95)"
fedokawaii remind quiet
called 'notify-send -a desktop -- .*  upkeep the update season is here'
reset_calls; fedokawaii remind quiet; not_called 'notify-send'
case_ "remind quiet twenty times at once (timers piling up after a suspend): one notice"
fresh; rec last-update-done "$(ago_s 95)"
for _ in $(seq 1 20); do fedokawaii remind quiet & done; wait
eq "$(grep -c '^notify-send' "$CALLS")" 1
reset_calls; fedokawaii remind quiet; not_called 'notify-send'
case_ "remind quiet: a notice that could not be shown is shown at the next look"
fresh; rec last-update-done "$(ago_s 95)"; stub notify-send 'exit 1'
fedokawaii remind quiet; stub notify-send; reset_calls
fedokawaii remind quiet; called 'notify-send -a desktop -- .*  upkeep'
case_ "remind quiet with reminders off: silent; nothing due: silent"
fresh; rec last-update-done "$(ago_s 95)"; fedokawaii remind off >/dev/null; reset_calls
fedokawaii remind quiet; not_called 'notify-send'
fresh; rec last-update-done "$(ago_s 5)"; fedokawaii remind quiet; not_called 'notify-send'

# ── the backup (kawa-backup's record, the theme's env) ───────────────────────
backed_up() { mkdir -p "$HOME/.local/state/fedokawaii"; printf '%s\t43.763 KiB\tKINGSTON\n' "$(ago_s "$1")" >"$HOME/.local/state/fedokawaii/last-backup"; }
case_ "status: a drive named, no backup yet — said, with where to start it; then its day and age"
fresh; setting BACKUP_TARGET KINGSTON
out=$(fedokawaii status); has "$(line backup "$out")" "none yet · quick settings → backup"
(( $(widest "$out") <= 44 )) && _ok || _no "a line of $(widest "$out") characters: $out"
backed_up 3; out=$(fedokawaii status)
has "$(line backup "$out")" "$(date -d "@$(ago_s 3)" '+%-d %b %Y') · 3 days ago"
backed_up 0; has "$(line backup "$(fedokawaii status)")" "· today"
case_ "status: a corrupt backup record (garbage, a command, empty): none yet, nothing run"
printf 'rm -rf %s\n' "$TMP/pwned" >"$HOME/.local/state/fedokawaii/last-backup"; mkdir -p "$TMP/pwned"
has "$(line backup "$(fedokawaii status)")" "none yet"; [[ -d $TMP/pwned ]] && _ok || _no "the record ran"
: >"$HOME/.local/state/fedokawaii/last-backup"; has "$(line backup "$(fedokawaii status)")" "none yet"
case_ "remind check: no backup for 7 days (BACKUP_REMIND_DAYS) — said, after the season's line, naming the drive"
fresh; setting BACKUP_TARGET KINGSTON; backed_up 7
out=$(fedokawaii remind check)
eq "$(grep -c . <<<"$out")" 2; has "$(head -n1 <<<"$out")" "nothing due"
has "$(tail -n1 <<<"$out")" "the last backup was 7 days ago — plug in KINGSTON, then quick settings → backup"
backed_up 6; eq "$(grep -c . <<<"$(fedokawaii remind check)")" 1 "6 days: not yet"
rm -f "$HOME/.local/state/fedokawaii/last-backup"; has "$(fedokawaii remind check)" "no backup yet — plug in KINGSTON"
case_ "remind check: no drive named, or BACKUP_REMIND_DAYS=0 — no backup line"
fresh; eq "$(grep -c . <<<"$(fedokawaii remind check)")" 1
fresh; setting BACKUP_TARGET KINGSTON; setting BACKUP_REMIND_DAYS 0; backed_up 400
eq "$(grep -c . <<<"$(fedokawaii remind check)")" 1
case_ "remind check: BACKUP_REMIND_DAYS=30 — late at 30, not at 29"
fresh; setting BACKUP_TARGET KINGSTON; setting BACKUP_REMIND_DAYS 30
backed_up 29; eq "$(grep -c . <<<"$(fedokawaii remind check)")" 1; backed_up 30; has "$(fedokawaii remind check)" "30 days ago"
case_ "remind quiet: the backup's notice, once a day, on its own day count (an upkeep notice the same day does not hide it)"
fresh; setting BACKUP_TARGET KINGSTON; backed_up 10; rec last-update-done "$(ago_s 95)"
fedokawaii remind quiet
called 'notify-send -a desktop -- .*  upkeep the update season is here'; called 'notify-send -a backup -- .*  backup the last backup was 10 days ago — plug in KINGSTON'
reset_calls; fedokawaii remind quiet; not_called 'notify-send'
case_ "remind quiet: a backup notice that could not be shown is shown at the next look; reminders off: silent"
fresh; setting BACKUP_TARGET KINGSTON; backed_up 10; stub notify-send 'exit 1'
fedokawaii remind quiet; stub notify-send; reset_calls; fedokawaii remind quiet; called 'notify-send -a backup -- .*  backup'
fedokawaii remind off >/dev/null; rm -f "$HOME/.cache/fedokawaii/reminded-backup"; reset_calls
fedokawaii remind quiet; not_called 'notify-send'
case_ "a garbage BACKUP_REMIND_DAYS (fedokawaii.conf edited by hand, as root): the default, 7"
fresh; setting BACKUP_TARGET KINGSTON; setting BACKUP_REMIND_DAYS soon; backed_up 7
has "$(fedokawaii remind check)" "7 days ago"

case_ "status and remind: a drive named in settings counts at once (fedokawaii.conf, its one place)"
fresh; setting BACKUP_TARGET KINGSTON; lacks "$(cat "$HOME/.config/fedokawaii/env")" 'BACKUP_' "the theme's env holds no copy"
has "$(line backup "$(fedokawaii status)")" "none yet"; has "$(fedokawaii remind check)" "no backup yet — plug in KINGSTON"
setting BACKUP_REMIND_DAYS 0; eq "$(grep -c . <<<"$(fedokawaii remind check)")" 1 "0: off, at once"
case_ "…the toolkit's fedokawaii.conf unreadable: none — no other copy is read"
fresh; backed_up 3; rm -f "$R/toolkit/fedokawaii.conf"
has "$(line backup "$(fedokawaii status)")" "no drive"; lacks "$(fedokawaii remind check)" "plug in"
case_ "a value in fedokawaii.conf holding a command: read as text, never run"
fresh; setting BACKUP_TARGET "\$(touch $TMP/ran)"; fedokawaii status >/dev/null; fedokawaii remind check >/dev/null; fedokawaii --rows >/dev/null
[[ ! -e $TMP/ran ]] && _ok || _no "a setting was run"

case_ "a move's outcome: told once at the next login, critical when it failed"
fresh; rec last-upgrade "$(ago_s 0) 43 44 failed"; rec last-update-done "$(ago_s 0)"
fedokawaii remind quiet; called 'notify-send -a desktop -u critical -- .*  upkeep the move to Fedora 44 did not complete'
reset_calls; fedokawaii remind quiet; not_called 'notify-send'
fresh; rec last-upgrade "$(ago_s 1) 43 44 ok"; fedokawaii remind quiet; called 'Fedora 44 is in place — the move finished'
fresh; rec last-upgrade "$(ago_s 90) 43 44 ok"; fedokawaii remind quiet; not_called 'in place'

case_ "remind settings: every, wait, on, off — saved, read back"
fresh
eq "$(fedokawaii remind every 30)" "an update every 30 days"
eq "$(fedokawaii remind wait 0)" "a new release is offered 0 days after it is out"
f=$HOME/.config/fedokawaii/upkeep.conf
has "$(cat "$f")" "EVERY=30"; has "$(cat "$f")" "WAIT=0"; has "$(cat "$f")" "REMIND=yes"
eq "$(fedokawaii remind off)" "reminders off"; has "$(cat "$f")" "REMIND=no"
eq "$(fedokawaii remind on)" "reminders on — every 30 days"
eq "$(fedokawaii remind every 08)" "an update every 8 days" "08 is eight, not octal"
case_ "remind misuse: out of range, not a number, unknown — exit 2, nothing saved"
before=$(cat "$f")
rc 2 fedokawaii remind every 6; rc 2 fedokawaii remind every 366; rc 2 fedokawaii remind every 1e3
rc 2 fedokawaii remind every; rc 2 fedokawaii remind every -- ; rc 2 fedokawaii remind wait 181
rc 2 fedokawaii remind wait x; rc 2 fedokawaii remind sometimes
eq "$(cat "$f")" "$before"
case_ "upkeep.conf as a person might leave it: spaces, quotes, CRLF, no last newline, zeros"
fresh; mkdir -p "$HOME/.config/fedokawaii"
printf 'EVERY="30"\r\nWAIT=0009\nREMIND=no' >"$HOME/.config/fedokawaii/upkeep.conf"
out=$(fedokawaii remind check 2>&1)
lacks "$out" "base" "no arithmetic error"; lacks "$out" "line "
rec last-update-done "$(ago_s 40)"
has "$(fedokawaii remind check 2>&1)" "the update season is here: 40 days" "EVERY=\"30\" with a CR is 30"
rec last-update-done "$(ago_s 40)"; reset_calls; fedokawaii remind quiet; not_called 'notify-send' "REMIND=no on the last line, without a newline"
case_ "upkeep.conf garbage or out of range: the defaults"
printf 'EVERY=3\nWAIT=999\nREMIND=maybe\n$(touch x)\n' >"$HOME/.config/fedokawaii/upkeep.conf"
rec last-update-done "$(ago_s 40)"; has "$(fedokawaii remind check)" "nothing due — the next update in 50 days"

# ── the look outside: whether the next Fedora is out (once a day, never waited on) ──
wait_for() { local _; for _ in $(seq 1 50); do [[ -e $1 ]] && return 0; sleep 0.05; done; return 1; }
case_ "status asks Fedora's servers once a day: out → recorded for the menu"
fresh
stub curl 'printf "HTTP/2 200\r\nlast-modified: Tue, 14 Apr 2026 10:00:00 GMT\r\n\r\n"'
fedokawaii status >/dev/null
wait_for "$HOME/.cache/fedokawaii/release-45" && _ok || _no "release-45 not recorded"
called 'curl -fsSI --proto =https --max-time 10 https://dl.fedoraproject.org/pub/fedora/linux/releases/45/'
has "$(line next "$(fedokawaii status)")" "Fedora 45 · ready to move to" "released in April + a week, settled 60 days"
case_ "…and not again the same day"
reset_calls; fedokawaii status >/dev/null; sleep 0.3; not_called 'curl'
case_ "offline (or not out yet): nothing recorded, no noise, no wait"
fresh; stub curl 'exit 6'
t0=$(date +%s%N); out=$(fedokawaii status 2>&1); t1=$(date +%s%N)
wait_for "$HOME/.cache/fedokawaii/checked"
[[ ! -e $HOME/.cache/fedokawaii/release-45 ]] && _ok || _no "recorded while offline"
(( (t1 - t0) / 1000000 < 3000 )) && _ok || _no "status waited on the network"
case_ "a slow network never holds status up"
fresh; stub curl 'sleep 5'
t0=$(date +%s%N); fedokawaii status >/dev/null 2>&1; t1=$(date +%s%N)
(( (t1 - t0) / 1000000 < 3000 )) && _ok || _no "status waited $(( (t1 - t0) / 1000000 )) ms for curl"
case_ "a nonsense date from the server: the day it was seen, never later"
fresh; stub curl 'printf "HTTP/2 200\r\nlast-modified: someday\r\n\r\n"'
fedokawaii status >/dev/null; wait_for "$HOME/.cache/fedokawaii/release-45"
v=$(cat "$HOME/.cache/fedokawaii/release-45" 2>/dev/null)
[[ $v =~ ^[0-9]+$ ]] && (( v <= $(date +%s) )) && _ok || _no "release day [$v]"

done_
