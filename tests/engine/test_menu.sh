#!/usr/bin/env bash
# tests/engine/test_menu.sh — Super+U: every entry of the menu and every `fedokawaii` command,
# used right and used wrong. Root's side is a stand-in (lib.sh): it says what it was asked
# and answers with the exit status a test gives it. The menu's rows and its right pane must
# fit their columns; the outcome line after a run must say what the run's status means.
. "$(dirname "$0")/lib.sh"

fresh() { sandbox; engine_world; }
console() { fresh; unset WAYLAND_DISPLAY; }   # (a text console: no desktop — the plain menu's place)
SECS="system update snapshots backups learning"
allrows() { local s; for s in $SECS; do fedokawaii --rows "$s"; done; }   # (every section's rows, in order)
row() { grep -m1 "^$1"$'\t' <<<"$(plain "$(allrows)")"; }
entries() { cut -f2 <<<"$1"; }   # entries ROWS — the entries' text

# ── help and misuse ──────────────────────────────────────────────────────────
fresh
case_ "help: the header, as text, for each way of asking"
for h in help --help -h; do
  out=$(fedokawaii "$h"); r=$?
  eq "$r" 0 "$h"
  has "$out" "fedokawaii update"; has "$out" "fedokawaii remind"; lacks "$out" "set -u"; lacks "$out" "# "
done
case_ "help names every command the engine answers, and every one it names is answered"
cmds=$(sed -n '/^case \${1:-} in/,/^esac/p' "$REPO/system/fedokawaii" | grep -oE '^  [a-z|-]+\)' | tr -d ' )' | tr '|' '\n' | grep -v '^-' | sort -u)
for c in $cmds; do [[ $c == help ]] && continue; has "$out" "fedokawaii $c" "help does not name: $c"; done
for c in $(grep -oE '^#   fedokawaii [a-z]+' "$REPO/system/fedokawaii" | awk '{print $3}' | sort -u); do
  grep -qx "$c" <<<"$cmds" && _ok || _no "help names $c, the engine does not answer it"
done
case_ "help says what the exit status means"
has "$out" "0 done"; has "$out" "2 misuse"

case_ "an unknown command: exit 2, and how to get help"
out=$(fedokawaii frobnicate 2>&1); eq "$?" 2; has "$out" 'unknown command "frobnicate"'; has "$out" "fedokawaii help"
rc 2 fedokawaii -x; rc 2 fedokawaii "up date"; rc 2 fedokawaii $'update\nrepair'
case_ "a command given more than it takes: exit 2, root's side never asked"
for c in update verify repair theme drift snapshots backup log status copy diff apply learn settings; do
  rc 2 fedokawaii "$c" extra
done
rc 2 fedokawaii upgrade now; rc 2 fedokawaii upgrade --now extra
eq "$(front_calls)" "" "nothing ran as root"; not_called '^sudo'
case_ "keep without a file: exit 2"
rc 2 fedokawaii keep

# ── what runs as root: sudo, from the toolkit ─────────────────────────────────
case_ "update, verify, repair, theme, drift, upgrade (--now): the toolkit's front, through sudo"
fresh
for c in update verify repair theme drift upgrade; do rc 0 fedokawaii "$c"; done
rc 0 fedokawaii upgrade --now
eq "$(front_calls)" "$(printf 'front %s\n' update verify repair theme drift upgrade 'upgrade --now')"
called "^sudo bash $R/toolkit/fedokawaii.sh update"
case_ "root's exit status comes back: 3 (it ran, things need you), 4 (drift: optional parts), 1, 130"
echo 3 >"$R/rc-repair"; rc 3 fedokawaii repair
echo 4 >"$R/rc-drift"; rc 4 fedokawaii drift
echo 1 >"$R/rc-update"; rc 1 fedokawaii update
echo 130 >"$R/rc-update"; rc 130 fedokawaii update
case_ "the toolkit missing: said, and sudo never asked for a password"
fresh; rm -f "$R/toolkit/fedokawaii.sh"
out=$(fedokawaii update 2>&1); eq "$?" 1; has "$out" "the toolkit is missing: $R/toolkit"
not_called '^sudo'
case_ "sudo refusing (a wrong password, not an administrator): it says root is needed"
fresh; : >"$R/sudo-refused"
out=$(fedokawaii repair 2>&1); eq "$?" 1
has "$out" "needs root"; eq "$(front_calls)" ""
out=$(fedokawaii snapshots 2>&1); eq "$?" 1; has "$out" "needs root"

case_ "an update already running (root's lock held): said at once — no password, no wait"
fresh; : >"$R/state/lock"
( exec 9>"$R/state/lock"; flock 9; exec sleep 30 ) >/dev/null 2>&1 & holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$R/state/lock" true || break; sleep 0.1; done
for c in update repair upgrade; do
  out=$(fedokawaii "$c" 2>&1); eq "$?" 1 "$c"; has "$out" "running now"
done
not_called '^sudo'
case_ "…while verify and drift (read-only) still run"
rc 0 fedokawaii verify; rc 0 fedokawaii drift
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
case_ "the lock let go (its run crashed, the file left behind): runs again"
reset_calls; rc 0 fedokawaii update; called '^sudo bash .*fedokawaii.sh update'

case_ "held: what the updates hold back — its count on the row, each with why in the pane (a kernel's packages as one); enter does nothing"
fresh; mkdir -p "$R/state/update"
printf '%s\n' 'mesa 26.1-1.fc44 26.0-1.fc44 2026-11-01 mesa the desktop does not start' \
  'kernel-core 7.2.13-200.fc44 7.2.11-200.fc44 2026-11-01 kernel did not reach the desktop in three starts' \
  'kernel-modules 7.2.13-200.fc44 7.2.11-200.fc44 2026-11-01 kernel did not reach the desktop in three starts' >"$R/state/update/holds"
[[ $(plain "$(fedokawaii --rows update | grep -m1 held)") == *" 2" ]] && _ok || _no "the count: $(plain "$(fedokawaii --rows update | grep -m1 held)")"
out=$(plain "$(fedokawaii --explain held)")
has "$out" "mesa 26.1-1.fc44"; has "$out" "the desktop does not start"; has "$out" "kernel 7.2.13-200.fc44"; lacks "$out" "kernel-modules"
has "$out" "did not reach the desktop in three"; lacks "$out" "…"; lacks "$out" "not yet"
(( $(widest "$(sed 1d <<<"$out")") <= 45 )) && _ok || _no "too wide: $out"   # (under its heading: the pane's own rule)
rm -f "$R/state/update/holds"; [[ $(plain "$(fedokawaii --rows update | grep -m1 held)") == *"held back"*" none" ]] && _ok || _no "none held: the row says so: $(plain "$(fedokawaii --rows update | grep -m1 held)")"
has "$(plain "$(fedokawaii --explain held)")" "nothing held back."
case_ "…sixty held at once (a whole set): the row counts sixty, the pane names three, then how many more"
fresh; mkdir -p "$R/state/update"
for i in $(seq -w 1 60); do echo "p$i 1.1-1.fc44 1.0-1.fc44 2026-11-01 p$i the desktop does not start"; done >"$R/state/update/holds"
[[ $(plain "$(fedokawaii --rows update | grep -m1 held)") == *" 60" ]] && _ok || _no "the count: $(plain "$(fedokawaii --rows update | grep -m1 held)")"
out=$(plain "$(fedokawaii --explain held)")
has "$out" "p03 1.1-1.fc44"; lacks "$out" "p04"; has "$out" "and 57 more."; lacks "$out" "…"
(( $(widest "$(sed 1d <<<"$out")") <= 45 )) && _ok || _no "too wide: $out"
rm -f "$R/state/update/holds"
case_ "an update running as a unit of its own: a press follows it — its output so far, its status; no password"
fresh; mkdir -p "$R/state/update"; echo "▸ the update on the running system" >"$R/state/update/run.log"
stub systemctl 'case "$*" in "is-active"*) exit 0 ;; *MainPID*) echo 0 ;; *ExecMainStatus*) echo 0 ;; esac'
out=$(fedokawaii update 2>&1); eq "$?" 0; has "$out" "the update on the running system"; not_called '^sudo'

# ── the menu's rows ──────────────────────────────────────────────────────────
case_ "rows: five sections, each its entries in order, each fitting the 38-column list"
fresh; rec last-update-done "$(ago_s 10)"; rec snapshots 14; rec last-verify "$(ago_s 1) 180 2 0"
for s in $SECS; do printf '%s: %s\n' "$s" "$(WAYLAND_DISPLAY=wayland-1 fedokawaii --rows "$s" | cut -f1 | tr '\n' ' ')"; done >"$TMP/secs"
eq "$(cat "$TMP/secs")" "system: status verify repair drift change asobi theme settings remind log 
update: update held 
snapshots: snapshots file 
backups: backup restore drive carry stick bring 
learning: learn chess typing keys "
out=$(WAYLAND_DISPLAY=wayland-1 allrows)
(( $(widest "$(entries "$out")") <= 38 )) && _ok || _no "a row wider than 38: $(plain "$out")"
lacks "$(plain "$out")" "╌" "no dashed line anywhere"
case_ "never again: no to-do in Super+U — it lives in Super+N alone (owner 1 Nov 22:27: \"to-do should NOT be in learning\")"
lacks "$(plain "$out")" "to-do"; [[ -z $(grep "^todo"$'\t' <<<"$out") ]] && _ok || _no "a todo row: $(grep "^todo" <<<"$out")"
case_ "rows: each entry a column in, its icon, two columns, its name; the value right-aligned a column in from the row's end (as far in as the icon, the band's symmetry), muted"
for a in update snapshots remind; do
  l=$(cut -f2 <<<"$(grep "^$a"$'\t' <<<"$out")")
  [[ $l =~ ^" "$'\e[38;5;21m'.$'\e[0m'"  "[a-z] ]] && _ok || _no "$a: $l"
  [[ $l == *$'\e[38;5;21m'*[!\ ]$'\e[0m' ]] && _ok || _no "$a: the value muted, at the end: $l"
  eq "$(widest "$l")" 37 "$a: the value's last letter a column in from the row's 38"
done
has "$(row update)" "in 4 days"; has "$(row snapshots)" "14"; has "$(row verify)" "2 to fix"; has "$(row remind)" "every 14 days"
lacks "$(row status)" "Fedora" "status: no value (the pane beside it is the status: the release is its first line)"; eq "$(row upgrade)" "" "the move is the update's: no row of its own"
case_ "rows: away from the desktop (a text console, ssh) — change, keys and the to-do are screens of the desktop"
eq "$(env -u WAYLAND_DISPLAY fedokawaii --rows system | cut -f1 | tr '\n' ' ')" "status verify repair drift theme settings remind log "
eq "$(env -u WAYLAND_DISPLAY fedokawaii --rows learning | cut -f1 | tr '\n' ' ')" "learn " "(the to-do is the notes' window: the desktop's, as change and keys)"
case_ "fzf's items: NUL-ended, one a row, no headings in the list (the tab bar heads it)"
eq "$(fedokawaii --items update | tr '\0' '\n' | cut -f1 | tr '\n' ' ')" "update held "
eq "$(fedokawaii --items system | tr -cd '\0' | wc -c)" "$(fedokawaii --rows system | wc -l)" "one item a row"
case_ "the tab bar, a heading over the list (a cell further out): the section shown — its icon in the accent's ink, its name strong, a vermilion line under the name alone; the others their icon alone, muted; every icon two columns, every gap three; a row of paper"
. "$REPO/configs/home/.config/fedokawaii/icons.sh"   # (the icons the menu draws, by name)
t=$(fedokawaii --tabs update)
eq "$(wc -l <<<"$t")" 3 "three lines"; eq "$(sed -n 3p <<<"$t")" " " "the third a row of paper"
l1=$(sed -n 1p <<<"$t"); l2=$(sed -n 2p <<<"$t")
[[ $l1 == $'\e[38;5;21m'"$ICON_TAB_SYSTEM"* ]] && _ok || _no "the first tab not at the bar's first column (a heading's): $(plain "$l1")"
has "$l1" $'\e[38;5;20m'"$ICON_TAB_UPDATE"$'\e[0m  \e[38;5;23mupdate\e[0m' "update shown: icon accent, name strong"
has "$l1" $'\e[38;5;21m'"$ICON_TAB_SYSTEM"$'\e[0m    \e[38;5;20m' "system: its icon alone, muted, two columns, then three of paper"
has "$l1" $'\e[0m   \e[38;5;21m'"$ICON_TAB_SNAPSHOTS" "three columns after the name shown"
lacks "$(plain "$l1")" "system" "no name for a tab not shown"
eq "$(plain "$l2")" "        ▔▔▔▔▔▔" "the line: under the name shown alone (6 columns), at its column"
has "$l2" $'\e[38;5;16m▔' "the line in the accent"
eq "$(plain "$(fedokawaii --tabs learning | head -n1)")" "$ICON_TAB_SYSTEM    $ICON_TAB_UPDATE    $ICON_TAB_SNAPSHOTS    $ICON_TAB_BACKUPS    $ICON_TAB_LEARNING  learning" "the last shown: no paper after it"
case_ "a job running: its row again in each frame of the hourglass turning (fields 4–9 after the name: 0 1 2 3 3 4), only its icon changed; every other row the same picture in each; none running: all alike"
printf 'repair\n' >"$R/state/lock"
( exec 9<"$R/state/lock"; flock 9; exec sleep 30 ) >/dev/null 2>&1 & holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$R/state/lock" true || break; sleep 0.1; done
rows=$(fedokawaii --rows system)
eq "$(awk -F'\t' '{print NF}' <<<"$rows" | sort -u)" 9 "nine fields a row"
IFS=$'\t' read -r -a f < <(grep -m1 $'^repair\t' <<<"$rows")
has "${f[1]}" "$ICON_HOURGLASS" "at rest: the hourglass"
k=3; for g in "$ICON_HG_0" "$ICON_HG_1" "$ICON_HG_2" "$ICON_HG_3" "$ICON_HG_3" "$ICON_HG_4"; do
  has "${f[k]}" "$g" "frame $((k - 3))"; eq "${f[k]/"$g"/$ICON_HOURGLASS}" "${f[1]}" "frame $((k - 3)): only its icon differs"; k=$((k + 1))
done
IFS=$'\t' read -r -a f < <(grep -m1 $'^verify\t' <<<"$rows")
eq "$(printf '%s\n' "${f[@]:3}" | sort -u | wc -l)" 1 "another row: one picture"; eq "${f[3]}" "${f[1]}" "another row: as it is"
eq "$(fedokawaii --items system | tr '\0' '\n' | awk -F'\t' '{print NF}' | sort -u)" 9 "fzf's items carry the frames"
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
eq "$(fedokawaii --rows system | awk -F'\t' '{ for (i = 4; i <= 9; i++) if ($i != $2) n++ } END { print n + 0 }')" 0 "none running: every frame its row"
case_ "the ticker (--tick, kawa-warm starts it as the popup shows): the list turned through the frames 6 a second while the popup shows and a job runs; the job ended: the list read again, the row at rest; one ticker at a time; not shown or nothing running: nothing"
export XDG_RUNTIME_DIR=$TMP/run; mkdir -p "$XDG_RUNTIME_DIR"
python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$XDG_RUNTIME_DIR/fedokawaii-menu.sock"
stub curl 'p=; for a; do [ "$p" = --data-binary ] && echo "$a" >>"$FK_R/curl.log"; p=$a; done'
: >"$R/curl.log"; fedokawaii --tick; eq "$(cat "$R/curl.log")" "" "not shown: nothing said"
: >"$XDG_RUNTIME_DIR/kawa-warm-system.shown"
fedokawaii --tick; eq "$(cat "$R/curl.log")" "" "shown, nothing running: nothing said"
( exec 9<"$R/state/lock"; flock 9; exec sleep 1.2 ) >/dev/null 2>&1 & holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$R/state/lock" true || break; sleep 0.1; done
fedokawaii --tick & ticker=$!; sleep 0.3
t0=$(date +%s%N); fedokawaii --tick; t1=$(date +%s%N)
(( (t1 - t0) / 1000000 < 300 )) && _ok || _no "a second ticker waited instead of leaving"
[[ -e $XDG_RUNTIME_DIR/fedokawaii-pane/on ]] && _ok || _no "turning: the panes not kept"
FZF_PREVIEW_COLUMNS=50 fedokawaii --explain update update >"$TMP/pane1"
eq "$(cat "$XDG_RUNTIME_DIR/fedokawaii-pane/update.50")" "$(cat "$TMP/pane1")" "turning: a pane made is kept, as it was shown"
wait "$ticker"; wait "$holder" 2>/dev/null
[[ ! -e $XDG_RUNTIME_DIR/fedokawaii-pane ]] && _ok || _no "the turning stopped: the kept panes still there"
n=$(grep -c '^change-with-nth([4-9])$' "$R/curl.log")
((n >= 4 && n <= 9)) && _ok || _no "turned $n times in ~1.1 s (6 a second: 5–7)"
eq "$(grep -m6 '^change-with-nth' "$R/curl.log" | tr -dc '0-9')" "456789" "each frame named, in turn (a rotation through the socket starts again at its first)"
eq "$(tail -n1 "$R/curl.log")" 'reload-sync(fedokawaii --items)+change-with-nth(2)' "the job ended: the list read again, at rest"
: >"$R/curl.log"; ( exec 9<"$R/state/lock"; flock 9; exec sleep 1 ) >/dev/null 2>&1 & holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$R/state/lock" true || break; sleep 0.1; done
fedokawaii --tick & ticker=$!; sleep 0.4; rm -f "$XDG_RUNTIME_DIR/kawa-warm-system.shown"
wait "$ticker"; kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
n=$(grep -c 'change-with-nth(4' "$R/curl.log"); ((n >= 1 && n <= 4)) && _ok || _no "put away: still turning ($n)"
lacks "$(cat "$R/curl.log")" "reload-sync" "put away: nothing read again"
stub curl 'exit 6'; unset XDG_RUNTIME_DIR
case_ "a tab: Tab / → the next, Shift+Tab / ← the one before, round the ends; a click on its icon (two columns) or its name shows it — between them, after them, or on the line under, nothing"
export FK_TAB=$TMP/tab; echo system >"$FK_TAB"
fedokawaii --tab +1; eq "$(cat "$FK_TAB")" update; fedokawaii --tab -1; fedokawaii --tab -1; eq "$(cat "$FK_TAB")" learning "round the start"
fedokawaii --tab +1; eq "$(cat "$FK_TAB")" system "round the end"
for c in 1:system 9:system 10:system 12:system 13:update 14:update 15:system 18:snapshots 19:snapshots 23:backups 24:backups 25:system 28:learning 29:learning 30:system; do
  echo system >"$FK_TAB"; fedokawaii --tab click "${c%%:*}" 1; eq "$(cat "$FK_TAB")" "${c#*:}" "a click at column ${c%%:*}"
done
echo system >"$FK_TAB"; fedokawaii --tab click 13 2; eq "$(cat "$FK_TAB")" system "a click on the line under the bar (under update's icon)"
echo bogus >"$FK_TAB"; eq "$(fedokawaii --rows | head -n1 | cut -f1)" status "a record that names no section: the first"
unset FK_TAB
case_ "change the desktop, keybindings: opened on their own, and the menu closes for them (fzf becomes the run)"
fresh; stub kawa-config; stub kawa-help
WAYLAND_DISPLAY=wayland-1 fedokawaii --run change </dev/null; WAYLAND_DISPLAY=wayland-1 fedokawaii --run keys </dev/null
for _ in 1 2 3 4 5 6 7 8 9 10; do grep -q kawa-help "$CALLS" && grep -q kawa-config "$CALLS" && break; sleep 0.1; done
called '^setsid -f kawa-config$'; called '^setsid -f kawa-help$'
case_ "…nor a way in by name: --run todo runs nothing, --explain todo is empty"
fresh; stub kawa-notes
WAYLAND_DISPLAY=wayland-1 fedokawaii --run todo </dev/null; not_called 'kawa-notes'
eq "$(fedokawaii --explain todo 2>&1)" ""
has "$(cat "$(command -v fedokawaii)")" "enter:transform:case {1} in \$PANE_ONLY) ;; \${launch}remind) echo 'execute-silent(\$self --run {1})+reload-sync(\$self --items)' ;; change|keys|chess\${pop}) echo '\${away}become("
case_ "Super+U's popup (--popup): the menu closes for a job too (fzf becomes the run, which hands it on); the lessons, the key sheet and the settings start without fzf giving up the screen, then the popup is put away (dwl fades it off: never a blank terminal); a plain menu, neither"
fresh; stub fzf 'cat >/dev/null; exit 130'
on_tty "" fedokawaii --popup >/dev/null
called "enter:transform:case \\{1\\} in held\\|typing\\) ;; learn\\|keys\\|change\\|asobi\\|chess\\) echo 'execute-silent\\([^)]* --run \\{1\\}\\)\\+execute-silent\\(kawa-warm system\\)' ;; remind\\) "
called 'remind\) echo .execute-silent\([^)]* --run \{1\}\)\+reload-sync\([^)]* --items\). ;; change\|keys\|chess\|update\|verify\|repair\|theme\|drift\|snapshots\|file\|backup\|restore\|drive\|carry\|stick\|bring\|settings\|log\) echo .become\('
reset_calls; on_tty "" fedokawaii >/dev/null; called 'enter:transform:case \{1\} in held\) ;; remind\) echo .execute-silent\([^)]*\)\+reload-sync\([^)]*\). ;; change\|keys\|chess\) echo .become\('
called 'esc,ctrl-c,ctrl-g,ctrl-q:abort' "(outside the warm window: Esc only ends it)"
case_ "…in the warm window (KAWA_WARM=system): Esc, q and a job's become put it away first — while the menu is still drawn (dwl's ghost of it fades, never a page fzf wiped)"
reset_calls; KAWA_WARM=system on_tty "" fedokawaii --popup >/dev/null
called 'esc,ctrl-c,ctrl-g,ctrl-q:execute-silent\(kawa-warm --away system\)\+abort'
called ',q:execute-silent\(kawa-warm --away system\)\+abort'
called "echo .execute-silent\\(kawa-warm --away system\\)\\+become\\("
case_ "rows: the mark at the right edge, wider with a wider window (FZF_COLUMNS)"
w=$(widest "$(entries "$(FZF_COLUMNS=120 fedokawaii --rows)")"); eq "$w" 66
w=$(widest "$(entries "$(FZF_COLUMNS=98 fedokawaii --rows)")"); eq "$w" 44 "the 100-column window (98 inside fzf's margins): 44"
w=$(widest "$(entries "$(FZF_COLUMNS=40 fedokawaii --rows)")"); eq "$w" 38 "a narrow window keeps the 38"
w=$(widest "$(entries "$(FZF_COLUMNS=garbage fedokawaii --rows </dev/null)")"); eq "$w" 38
case_ "rows at their widest: a release that settles in 180 days, an update in a year"
fedokawaii remind wait 180 >/dev/null; fedokawaii remind every 365 >/dev/null
rec release-45 "$(ago_s 0)"; rec last-update-done "$(ago_s 0)"
out=$(allrows)
has "$(row update)" "in 365 days"
(( $(widest "$(entries "$out")") <= 38 )) && _ok || _no "too wide: $(plain "$out")"
case_ "rows: due, ready (the kanji's vermilion: they need you), reminders off"
fresh; rec last-update-done "$(ago_s 200)"; rec release-45 "$(ago_s 100)"
out=$(allrows)
has "$(grep '^update' <<<"$out")" $'\e[38;5;20mdue'
fedokawaii remind off >/dev/null; has "$(row remind)" "off"
case_ "rows: a garbage snapshot count is not shown (nor makes the row too wide)"
fresh; rec snapshots "$(printf 'x%.0s' {1..80})"
lacks "$(row snapshots)" "xxx"
(( $(widest "$(entries "$(allrows)")") <= 38 )) && _ok || _no "too wide"
case_ "rows: os-release unreadable: no made-up Fedora 1"
rm -f "$R/os-release"; lacks "$(allrows)" "Fedora 1"; lacks "$(allrows)" "Fedora 0"
# the backup's mark reads kawa-backup's record (~/.local/state/fedokawaii/last-backup) and the
# toolkit's fedokawaii.conf as settings saved it (BACKUP_TARGET, BACKUP_REMIND_DAYS)
backed_up() { mkdir -p "$HOME/.local/state/fedokawaii"; printf '%s\t43.763 KiB\tKINGSTON\n' "$(ago_s "$1")" >"$HOME/.local/state/fedokawaii/last-backup"; }
case_ "rows: no backup set up (BACKUP_TARGET empty): none, in red"
fresh; has "$(grep '^backup' <<<"$(fedokawaii --rows backups)")" $'\e[38;5;20mnone'
case_ "rows: a drive named, no backup yet: never, in red; one 3 days ago: its age, grey; past the reminder's days: red"
fresh; setting BACKUP_TARGET KINGSTON
has "$(grep '^backup' <<<"$(fedokawaii --rows backups)")" $'\e[38;5;20mnever'
backed_up 3; has "$(grep '^backup' <<<"$(fedokawaii --rows backups)")" $'\e[38;5;21m3 days ago'
backed_up 7; has "$(grep '^backup' <<<"$(fedokawaii --rows backups)")" $'\e[38;5;20m7 days ago'
backed_up 0; has "$(grep '^backup' <<<"$(fedokawaii --rows backups)")" $'\e[38;5;21mtoday'
case_ "rows: BACKUP_REMIND_DAYS=0 — never red, however old"
fresh; setting BACKUP_TARGET KINGSTON; setting BACKUP_REMIND_DAYS 0; backed_up 400
has "$(grep '^backup' <<<"$(fedokawaii --rows backups)")" $'\e[38;5;21m400 days ago'
(( $(widest "$(entries "$(fedokawaii --rows backups)")") <= 38 )) && _ok || _no "too wide"
case_ "rows: a garbage record, or one holding a command: never, nothing run"
printf 'rm -rf %s\tx\n' "$TMP/pwned" >"$HOME/.local/state/fedokawaii/last-backup"; mkdir -p "$TMP/pwned"
has "$(grep '^backup' <<<"$(fedokawaii --rows backups)")" never; [[ -d $TMP/pwned ]] && _ok || _no "the record ran"
case_ "rows: a setting counts as soon as settings saves it"
fresh; setting BACKUP_TARGET KINGSTON; backed_up 3
has "$(grep '^backup' <<<"$(fedokawaii --rows backups)")" $'\e[38;5;21m3 days ago'
setting BACKUP_REMIND_DAYS 2; has "$(grep '^backup' <<<"$(fedokawaii --rows backups)")" $'\e[38;5;20m3 days ago' "2 days: late at once"
setting BACKUP_TARGET ""; has "$(grep '^backup' <<<"$(fedokawaii --rows backups)")" $'\e[38;5;20mnone' "none named: none"
case_ "rows: the toolkit's settings unreadable: none, no error"
rm -f "$R/toolkit/fedokawaii.conf"; out=$(fedokawaii --rows backups 2>&1); has "$(grep '^backup' <<<"$out")" none; lacks "$out" "No such file"

# ── the right pane ───────────────────────────────────────────────────────────
case_ "the pane, for every entry, with every record at its longest: its heading level with the tab bar, two rows of paper, then its lines level with the list's (three columns in), within the 16 rows fzf gives it (kawa-warm's 18 less fzf's margins) and ≤ 49 columns (the pane's last column paper)"
fresh
( exec 9>"$R/state/lock"; flock 9; exec sleep 30 ) >/dev/null 2>&1 & holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$R/state/lock" true || break; sleep 0.1; done
mkdir -p "$R/state/update"; rec update/last-upgrade "$(ago_s 3) 43 44 partial"; rec last-update "$(ago_s 0) stopped"; rec last-update-done "$(ago_s 100)"
rec last-verify "$(ago_s 365) 1800 0 12"; echo 6.17.10-1300.fc44.x86_64 >"$R/newest-kernel"
echo "2000000000000 12000000000" >"$R/df"; printf '%s\n' a-very-long-package-name another-long-one >"$R/state/unavailable"
printf '/etc/x.rpmnew\n' >"$R/state/rpmnew"
setting BACKUP_TARGET "a drive with a long name"; backed_up 1000
for a in status update verify repair snapshots backup theme drift change settings remind log keys learn; do
  out=$(FZF_PREVIEW_LINES=16 WAYLAND_DISPLAY=wayland-1 fedokawaii --explain "$a")
  (( $(wc -l <<<"$out") <= 16 )) && _ok || _no "$a: $(wc -l <<<"$out") lines"
  heading_ok "$(sed -n 1p <<<"$out")" 49 "$a: the pane's heading (level with the tab bar)"
  eq "$(sed -n 2,3p <<<"$out" | tr -d '\n')" "" "$a: two rows of paper under it"
  [[ $(plain "$(sed -n 4p <<<"$out")") == "   "[!\ ]* ]] && _ok || _no "$a: its first line level with the list's first row, three columns in: $(sed -n 4p <<<"$out")"
  (( $(widest "$out") <= 49 )) && _ok || _no "$a: a line of $(widest "$out")"
  has "$(plain "$out")" "running " "$a: the run going on is shown"
done
case_ "status at its fullest: the routine lines make way (kernel, disk, release, support — in that order), never one asking for you"
rec last-after-dnf "$(ago_s 1) failed"   # (one line more than the 13 under the heading)
out=$(plain "$(FZF_PREVIEW_LINES=16 WAYLAND_DISPLAY=wayland-1 fedokawaii --explain status)")
(( $(wc -l <<<"$out") <= 16 )) && _ok || _no "status: $(wc -l <<<"$out") lines"
for k in running support moved updated due verified dnf backup kernel disk retired compare; do has "$out" "   $k " "status: $k kept"; done
has "$(grep '^ *kernel ' <<<"$out")" "restart for it" "the kernel kept: a restart waits for it"
has "$(grep '^ *disk ' <<<"$out")" "· low" "the disk kept: it runs low"
lacks "$out" "   release " "the release made way (the kernel and the disk asking for you)"
out=$(plain "$(FZF_PREVIEW_LINES=40 WAYLAND_DISPLAY=wayland-1 fedokawaii --explain status)")
has "$out" "   release "; has "$out" "   support " "room enough (a taller pane): every line"
out=$(plain "$(WAYLAND_DISPLAY=wayland-1 fedokawaii --explain status)"); has "$out" "   release " "no fzf (no room said): every line"
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
case_ "status, routine: its room fits every line, nothing made way"
fresh; rec last-update-done "$(ago_s 10)"; rec last-verify "$(ago_s 1) 257 0 0"
out=$(plain "$(FZF_PREVIEW_LINES=16 fedokawaii --explain status)")
for k in release support updated due verified backup kernel disk; do has "$out" "   $k " "status: $k"; done
case_ "the pane never repeats the list beside it: the due day without its 'in N days' (update's row); the next Fedora in update's pane alone"
fresh; rec last-update-done "$(ago_s 10)"
for a in status update; do
  out=$(plain "$(WAYLAND_DISPLAY=wayland-1 fedokawaii --explain "$a")")
  lacks "$(grep '^ *due ' <<<"$out")" " · in " "$a: the due day without 'in N days'"
done
lacks "$(plain "$(fedokawaii --explain status)")" "next "
has "$(plain "$(fedokawaii --explain update)")" "due " "update: its due day all the same"
has "$(plain "$(fedokawaii --explain update)")" "next " "update: the next Fedora, what the press will do with it"
case_ "the pane for nothing, or for something unknown: empty, no error"
eq "$(fedokawaii --explain 2>&1)" ""; eq "$(fedokawaii --explain bogus 2>&1)" ""; eq "$(fedokawaii --explain - 2>&1)" "" "a heading"

# ── run: an entry chosen, its outcome, a key back ─────────────────────────────
outcome() { tty_free fedokawaii --run "$1" </dev/null 2>&1 | tail -n3; }   # (the outcome's row, a blank line, the footer)
case_ "status: shown, then finished"
fresh; out=$(tty_free fedokawaii --run status </dev/null 2>&1)
has "$out" $'\e[H\e[2J'; has "$out" "release   Fedora 44"; has "$out" "finished"; has "$out" "any key goes back to the menu"
case_ "the outcome line says what each exit status means"
for a in update verify repair theme drift; do
  echo 0 >"$R/rc-$a"; has "$(outcome "$a")" "finished" "$a 0"
  echo 1 >"$R/rc-$a"; has "$(outcome "$a")" "it ended with an error (1)" "$a 1"
done
for a in verify repair drift; do echo 3 >"$R/rc-$a"; has "$(outcome "$a")" "done · some things still need you" "$a 3"; done
echo 4 >"$R/rc-drift"; has "$(outcome drift)" "done · some things still need you" "drift 4: in sync but for optional parts"
for a in update theme; do echo 3 >"$R/rc-$a"; has "$(outcome "$a")" "error (3)" "$a 3 is no outcome of its"; done
echo 4 >"$R/rc-verify"; has "$(outcome verify)" "error (4)" "only drift has a 4"
echo 130 >"$R/rc-update"; has "$(outcome update)" "error (130)"
case_ "every line a run prints fits the 88-column window (nothing wraps)"
fresh; all=""
for a in update verify repair drift; do for r in 0 1 3 4 130; do echo "$r" >"$R/rc-$a"; all+=$(outcome "$a")$'\n'; done; done
: >"$R/sudo-refused"; all+=$(tty_free fedokawaii --run update </dev/null 2>&1)$'\n'; rm -f "$R/sudo-refused"
echo ext4 >"$R/fstype"; all+=$(tty_free fedokawaii --run snapshots </dev/null 2>&1)$'\n'
: >"$R/state/lock"; ( exec 9>"$R/state/lock"; flock 9; exec sleep 30 ) >/dev/null 2>&1 & holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$R/state/lock" true || break; sleep 0.1; done
all+=$(tty_free fedokawaii --run update </dev/null 2>&1)$'\n'; kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
all+=$(fedokawaii upgrade later 2>&1)$'\n'$(fedokawaii frobnicate 2>&1)$'\n'$(fedokawaii update now 2>&1)
all=$(sed "s|$TMP/stubs/fedokawaii: line [0-9]*: /dev/tty: No such device or address||; s|$TMP|/tmp/kawa-test.XXXXXX|g" <<<"$all")   # (the test's own noise, and its folder's name)
(( $(widest "$all") <= 88 )) && _ok || _no "a line of $(widest "$all"): $(plain "$all" | awk 'length > 88' | head -n 2)"
case_ "an unknown entry: nothing runs"
fresh; out=$(tty_free fedokawaii --run bogus </dev/null 2>&1); eq "$?" 0; eq "$(front_calls)" ""
out=$(tty_free fedokawaii --run "" </dev/null 2>&1); eq "$?" 0
case_ "the outcome waits for a key, on the terminal (not on whatever stdin is)"
out=$(on_tty "x" fedokawaii --run status); has "$out" "finished"; has "$out" "any key goes back"
eq "$?" 0
case_ "…its columns (§7): the heading's icon at the screen's first, the facts under its name (as the menu's pane), the outcome a row one cell in, the key back at the heading's column"
p=$(plain "$out"); h=$(grep -m1 '─' <<<"$p"); lh=${h%%[! ]*}
r=$(grep -m1 'release' <<<"$p"); l=${r%%[! ]*}; eq "${#l}" "$((${#lh} + 3))" "release under the heading's name: [$r] [$h]"
r=$(grep -m1 'finished' <<<"$p"); l=${r%%[! ]*}; eq "${#l}" "$((${#lh} + 1))" "the outcome's glyph one cell in: [$r]"
r=$(grep -m1 'any key' <<<"$p"); l=${r%%[! ]*}; eq "${#l}" "${#lh}" "the key back at the heading's column: [$r]"

case_ "backup: kawa-backup, as you (never through sudo); its status comes back"
fresh; stub kawa-backup 'exit "$(cat "$FK_R/rc-backup" 2>/dev/null || echo 0)"'
has "$(outcome backup)" "finished"; called '^kawa-backup $'; not_called '^sudo'
echo 1 >"$R/rc-backup"; has "$(outcome backup)" "it ended with an error (1)"
reset_calls; rc 1 fedokawaii backup; called '^kawa-backup $'; not_called '^sudo'
case_ "backup without kawa-backup installed: said plainly"
out=$(without kawa-backup -- fedokawaii backup 2>&1); eq "$?" 1; has "$out" "kawa-backup is missing"
snaplist() { stub kawa-snap 'case $1 in list) printf "1\tsingle\t2026-10-01 10:00:00\tfedokawaii baseline\t-\n41\tpre\t2026-10-15 09:00:00\tdnf install htop\t-\n42\tpost\t2026-10-15 09:01:00\tdnf install htop\t-\nold\tsingle\t2026-10-16 08:00:00\tthe system before the last restore\t-\n" ;; esac'; stub systemctl; }
case_ "snapshots: kawa-snap's list from the disk, as root (a dnf pair shown once, by its pre); enter restores none"
fresh; snaplist; out=$(outcome snapshots); has "$out" "finished"; called '^sudo kawa-snap list$'; not_called 'kawa-snap restore'
out=$(tty_free fedokawaii --run snapshots </dev/null 2>&1)
has "$out" "fedokawaii baseline"; has "$out" "dnf install htop"; eq "$(grep -c 'dnf install htop' <<<"$out")" 1
has "$out" "the system before the last restore"
# aligned SCREEN WORD — on a terminal: SCREEN's first row holding WORD starts its icon one cell in
# from the heading's (a list under its heading, design-system §7: Super+U's grid, heading x 25, rows
# x 33), and ends a cell in from the heading's rule's end (each row a line of its own)
aligned() {
  local h r lh lr; h=$(grep -m1 '─' <<<"$1"); r=$(grep -m1 -- "$2" <<<"$1")
  lh=${h%%[! ]*} lr=${r%%[! ]*}
  eq "${#lr}" "$((${#lh} + 1))" "the icon one cell in from the heading's: [$r] [$h]"
  eq "$(($(LC_ALL=C.UTF-8 wc -L <<<"$r") + 1))" "$(LC_ALL=C.UTF-8 wc -L <<<"$h")" "ending a cell in from the rule's end: [$r] [$h]"
}
case_ "snapshots on a terminal: a row a line, the icon one cell in from the heading's, the date's end one cell in from its rule's"
fresh; snaplist; out=$(plain "$(on_tty $'\n' fedokawaii --run snapshots)")
aligned "$out" "fedokawaii baseline"; aligned "$out" "the system before the last restore"
eq "$(grep -c -E 'baseline|htop|last restore' <<<"$out")" 3 "three rows, three lines"
case_ "snapshots: a long description cut at a word's end, never mid-word, never an …; the boot menu's way said"
fresh; stub kawa-snap 'case $1 in list) printf "9\tpre\t2026-10-15 09:00:00\tdnf install libreoffice-writer libreoffice-calc libreoffice-impress hunspell\t-\n" ;; esac'
out=$(plain "$(tty_free fedokawaii --run snapshots </dev/null 2>&1)")
has "$out" "9     dnf install libreoffice-writer "; lacks "$out" "libreoffice-c"; lacks "$out" "…"
has "$out" "or at power-on: hold Shift (Esc/F8) for the boot menu → snapshots"
case_ "snapshots: a number, then yes — that one restored as root, the restart asked (n: none)"
fresh; snaplist; stub mountpoint 'exit 0'; out=$(on_tty $'41\nyes\nn' fedokawaii --run snapshots)
called '^sudo kawa-snap restore 41$'; not_called '^systemctl reboot'; has "$out" "home stays as it is"
fresh; snaplist; stub mountpoint 'exit 0'; on_tty $'old\nyes\ny' fedokawaii --run snapshots >/dev/null
called '^sudo kawa-snap restore old$'; called '^systemctl reboot'
case_ "snapshots while /home is inside the system: said that his home goes back too — his yes is the consent (--with-home)"
fresh; snaplist; stub mountpoint 'exit 1'; out=$(on_tty $'41\nyes\nn' fedokawaii --run snapshots)
has "$out" "home goes back to then too"; lacks "$out" "home stays as it is"
called '^sudo kawa-snap restore 41 --with-home$'
case_ "snapshots: anything but yes, or a number not listed — nothing restored"
fresh; snaplist; on_tty $'41\nno\n' fedokawaii --run snapshots >/dev/null; not_called 'kawa-snap restore'
out=$(on_tty $'42\nyes\n' fedokawaii --run snapshots); has "$out" "no snapshot 42 in the list"; not_called 'kawa-snap restore'
# ── a file, back: /home's snapshots, as you ───────────────────────────────────
# homesnaps — three snapshots of /home (snapper's layout: N/info.xml, N/snapshot holding /home,
# your home in it under its name): 7 today 00:00 UTC, 6 yesterday 12:00, 3 five days ago; in each
# your notes as they were. kawa-pick a stand-in: logs its call and its environment, answers what
# $TMP/pick lists (a path a line, under the snapshot it was started in: @ is that start)
homesnaps() {
  local S=${HOME%/*}/.snapshots n d h
  rm -rf -- "$S"; mkdir -p "$S"
  for n in 7:"$(date -u +%F) 00:00:00" 6:"$(date -u -d yesterday +%F) 12:00:00" 3:"$(date -u -d '-5 days' +%F) 09:30:00"; do
    d=${n#*:} n=${n%%:*} h=$S/$n/snapshot/${HOME##*/}
    mkdir -p "$h/Documents/old project"
    printf '<?xml version="1.0"?>\n<snapshot>\n  <type>single</type>\n  <num>%s</num>\n  <date>%s</date>\n  <description>timeline</description>\n  <cleanup>timeline</cleanup>\n</snapshot>\n' "$n" "$d" >"$S/$n/info.xml"
    echo "notes as at $n" >"$h/Documents/notes.md"; echo "plan $n" >"$h/Documents/old project/plan.txt"
  done
  mkdir -p "$S/9"                                   # (a number with no snapshot in it: left out)
  : >"$TMP/pick"
  stub kawa-pick 'printf "%s\n" "env $KAWA_PICK_TITLE | $KAWA_PICK_ROOT" >>"$CALLS"
[ "$1" = --inside ] && [ "$2" = back ] || exit 9
sed "s|^@|$3|" "$TMP/pick" >"$4/answer"'
}
case_ "a file, back: the snapshots of your files, newest first — each its number, time and day"
fresh; homesnaps; out=$(plain "$(TZ=UTC on_tty $'\n' fedokawaii --run file)")
has "$out" "a file, back"; lacks "$out" "9    "
l=$(grep -n -E '^ +. +(7|6|3) ' <<<"$out" | cut -d: -f1 | tr '\n' ' '); [[ $(wc -w <<<"$l") == 3 ]] && _ok || _no "three rows: $out"
has "$out" "7    00:00"; has "$out" "today"; has "$out" "6    12:00"; has "$out" "yesterday"; has "$out" "3    09:30"; has "$out" "$(date -u -d '-5 days' '+%-d %b')"
[[ $(grep -n '7    00:00' <<<"$out" | cut -d: -f1) -lt $(grep -n '3    09:30' <<<"$out" | cut -d: -f1) ]] && _ok || _no "not newest first"
has "$out" "copied into"; not_called '^kawa-pick'; [[ -e $HOME/Restored ]] && _no "a folder made for nothing" || _ok
# shellcheck disable=SC2088  # (~ is the words on the screen)
has "$out" "~/Restored — what is there now stays as it is"
aligned "$out" "7    00:00"; aligned "$out" "3    09:30"; eq "$(grep -c -E '(7|6|3)    [0-9]{2}:[0-9]{2}' <<<"$out")" 3 "a row a line"
case_ "…a number: the dialog in that snapshot's home, its heading the moment; the file copied into ~/Restored/DATE/, the one now untouched"
fresh; homesnaps; mkdir -p "$HOME/Documents"; echo "notes now" >"$HOME/Documents/notes.md"
echo "@/Documents/notes.md" >"$TMP/pick"; out=$(TZ=UTC on_tty $'6\n' fedokawaii --run file)
called "^kawa-pick --inside back ${HOME%/*}/.snapshots/6/snapshot/${HOME##*/} "; called "^env as it was yesterday at 12:00 | ${HOME%/*}/.snapshots/6/snapshot/${HOME##*/}$"
r=$(find "$HOME/Restored" -name notes.md); eq "$(cat "$r")" "notes as at 6"; eq "$(cat "$HOME/Documents/notes.md")" "notes now" "the one there now"
[[ ${r#"$HOME/Restored/"} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}/notes\.md$ ]] && _ok || _no "where: $r"
has "$out" "as it was yesterday at 12:00, into ~/Restored/"; has "$out" "Documents/notes.md"
[[ -w $r ]] && _ok || _no "not yours to change: $(stat -c %A "$r")"
case_ "…today's and an older one: the heading says at, or on DAY at"
fresh; homesnaps; echo "@/Documents/notes.md" >"$TMP/pick"; TZ=UTC on_tty $'7\n' fedokawaii --run file >/dev/null; called "^env as it was at 00:00 | "
fresh; homesnaps; echo "@/Documents/notes.md" >"$TMP/pick"; TZ=UTC on_tty $'3\n' fedokawaii --run file >/dev/null
called "^env as it was on $(date -u -d '-5 days' '+%-d %b') at 09:30 | "
case_ "…a folder and two of one name: each copied whole, the second beside the first as the desktop names a second file — \"notes (1).md\" (never over it)"
fresh; homesnaps; printf '%s\n' "@/Documents/old project" "@/Documents/notes.md" "@/Documents/notes.md" >"$TMP/pick"
TZ=UTC on_tty $'7\n' fedokawaii --run file >/dev/null
d=$(find "$HOME/Restored" -mindepth 1 -maxdepth 1 -type d); eq "$(cat "$d/old project/plan.txt")" "plan 7"
eq "$(cat "$d/notes.md")" "notes as at 7"; eq "$(cat "$d/notes (1).md")" "notes as at 7"; eq "$(find "$HOME/Restored" -mindepth 1 -maxdepth 1 | grep -c .)" 1 "one folder for one taking"
case_ "…the dialog cancelled, enter for none, a number not listed, a path outside the snapshot: nothing taken, nothing made"
fresh; homesnaps; out=$(TZ=UTC on_tty $'6\n' fedokawaii --run file); has "$out" "nothing taken"; [[ -e $HOME/Restored ]] && _no "made: $(ls -R "$HOME/Restored")" || _ok
fresh; homesnaps; out=$(TZ=UTC on_tty $'8\n' fedokawaii --run file); has "$out" "no snapshot 8 in the list — nothing taken"; not_called '^kawa-pick'
fresh; homesnaps; out=$(TZ=UTC on_tty $'9\n' fedokawaii --run file); has "$out" "no snapshot 9 in the list"
fresh; homesnaps; echo "/etc/passwd" >"$TMP/pick"; TZ=UTC on_tty $'6\n' fedokawaii --run file >/dev/null
[[ -z $(find "$HOME/Restored" -type f 2>/dev/null) ]] && _ok || _no "copied from outside: $(find "$HOME/Restored" -type f)"
case_ "…snapshots you cannot read (no ACL), or none yet: said plainly, with what puts it right"
fresh; homesnaps; chmod 000 "${HOME%/*}/.snapshots"; out=$(tty_free fedokawaii --run file </dev/null 2>&1); chmod 755 "${HOME%/*}/.snapshots"
has "$out" "cannot be read here — fedokawaii repair lets you read them"; not_called '^kawa-pick'
fresh; rm -rf -- "${HOME%/*}/.snapshots"; mkdir -p "${HOME%/*}/.snapshots"; out=$(tty_free fedokawaii --run file </dev/null 2>&1); has "$out" "no snapshots of your files yet"
fresh; rm -rf -- "${HOME%/*}/.snapshots"; out=$(tty_free fedokawaii --run file </dev/null 2>&1); has "$out" "no snapshots of your files yet"; lacks "$out" "repair" "no folder at all (before the split, the first hour): none yet, not repair"
case_ "…its pane says what it does (in Super+U's popup it is a job: a window of its own, below)"
out=$(plain "$(fedokawaii --explain file)"); has "$out" "copied into"; lacks "$out" "not yet"
# shellcheck disable=SC2088  # (~ is the words on the screen)
has "$out" "~/Restored, never over what is there."
# ── restore: a backup on the drive, as you ─────────────────────────────────────
# backups — kawa-backup a stand-in: times lists three backups of your home, newest first (a1 today
# 09:00 UTC, b2 yesterday 21:00, c3 five days ago 08:15); mount DIR fills DIR/ids/ID/<home>/ with
# your notes as each held them and serves until fusermount3 (a stand-in) marks DIR unmounted;
# drive answers $TMP/drive; kawa-pick as above
backups() {
  local t1 t2 t3
  t1="$(date -u +%F)T09:00:00.5+00:00" t2="$(date -u -d yesterday +%F)T21:00:00.5+00:00" t3="$(date -u -d '-5 days' +%F)T08:15:00.5+00:00"
  printf 'a1a1a1a1\t%s\t%s\nb2b2b2b2\t%s\t%s\nc3c3c3c3\t%s\t%s\n' "$t1" "$HOME" "$t2" "$HOME" "$t3" "$HOME" >"$TMP/times"
  printf 'KINGSTON\topen\t123000000000\t500000000000\n' >"$TMP/drive"; : >"$TMP/pick"; rm -f "$TMP/mount-fails"
  stub kawa-backup 'case $1 in
  times) cat "'"$TMP"'/times" ;;
  mount) [ -e "'"$TMP"'/mount-fails" ] && { echo "restic: wrong password or no key found" >&2; exit 1; }
         for id in a1a1a1a1 b2b2b2b2 c3c3c3c3; do mkdir -p "$2/ids/$id'"$HOME"'/Documents"; echo "notes in $id" >"$2/ids/$id'"$HOME"'/Documents/notes.md"; done
         g="'"$TMP"'/unmounted.${2##*/}"; while [ ! -e "$g" ]; do sleep 0.05; done; rm -f "$g" ;;
  drive) cat "'"$TMP"'/drive" ;;
  pick)  exit 4 ;;
esac'
  # (fusermount3 as an unmount is: the folder empty again — and a word to the stand-in's mount that it is over)
  stub fusermount3 'for a; do d=$a; done; [ -d "$d/ids" ] && { rm -rf "$d/ids"; : >"'"$TMP"'/unmounted.${d##*/}"; }'
  stub kawa-pick 'printf "%s\n" "env $KAWA_PICK_TITLE | $KAWA_PICK_ROOT" >>"$CALLS"
[ "$1" = --inside ] && [ "$2" = back ] || exit 9
sed "s|^@|$3|" "$TMP/pick" >"$4/answer"'
}
mounts_left() { ls -d "$XDG_RUNTIME_DIR"/fedokawaii-back* 2>/dev/null; }
case_ "restore: the backups on the drive, newest first — each its number, time and day; enter for none: nothing opened, nothing made"
fresh; backups; out=$(plain "$(TZ=UTC on_tty $'\n' fedokawaii --run restore)")
has "$out" "restore"; has "$out" "1    09:00"; has "$out" "today"; has "$out" "2    21:00"; has "$out" "yesterday"
has "$out" "3    08:15"; has "$out" "$(date -u -d '-5 days' '+%-d %b')"
[[ $(grep -n '1    09:00' <<<"$out" | cut -d: -f1) -lt $(grep -n '3    08:15' <<<"$out" | cut -d: -f1) ]] && _ok || _no "not newest first"
aligned "$out" "1    09:00"; aligned "$out" "3    08:15"; eq "$(grep -c -E '[123]    [0-9]{2}:[0-9]{2}' <<<"$out")" 3 "a row a line"
not_called '^kawa-backup mount'; not_called '^kawa-pick'; [[ -e $HOME/Restored ]] && _no "a folder made for nothing" || _ok
case_ "…a number: that backup opened read-only, the dialog in its copy of your home under the moment; the file into ~/Restored, the one now untouched; the backup closed, nothing left"
fresh; backups; mkdir -p "$HOME/Documents"; echo "notes now" >"$HOME/Documents/notes.md"; echo "@/Documents/notes.md" >"$TMP/pick"
out=$(plain "$(TZ=UTC on_tty $'2\n' fedokawaii --run restore)")
called "^kawa-backup mount $XDG_RUNTIME_DIR/fedokawaii-backup\.[A-Za-z0-9]+$"; called "^env as it was yesterday at 21:00 \| $XDG_RUNTIME_DIR/fedokawaii-backup\.[A-Za-z0-9]+/ids/b2b2b2b2$HOME$"
r=$(find "$HOME/Restored" -name notes.md); eq "$(cat "$r")" "notes in b2b2b2b2"; eq "$(cat "$HOME/Documents/notes.md")" "notes now" "the one there now"
has "$out" "as it was yesterday at 21:00, into ~/Restored/"; has "$out" "Documents/notes.md"; has "$out" "opening the backup"
called '^fusermount3 -u'; eq "$(mounts_left)" "" "the mount and the dialog's folder gone"
case_ "…all of it back in place is not offered (restic's restore still replaces a file where the backup has a folder, and resets folders' dates: the master's T48 verdict 4) — a number goes to the dialog, nothing else"
fresh; backups; out=$(plain "$(TZ=UTC on_tty $'3\n' fedokawaii --run restore)"); lacks "$out" "all of it back"; lacks "$out" "in place"; not_called 'everything'
case_ "…a number not listed, or one written another way (08): nothing taken, nothing opened, no shell words"
fresh; backups; out=$(TZ=UTC on_tty $'4\n' fedokawaii --run restore); has "$out" "no backup 4 in the list — nothing taken"; not_called '^kawa-backup mount'
fresh; backups; out=$(TZ=UTC on_tty $'08\n' fedokawaii --run restore); has "$out" "no backup 08 in the list — nothing taken"; lacks "$out" "value too great"; not_called '^kawa-backup mount'
case_ "…q at the home's own top (the home itself): said, never \"nothing taken\" for a choice"
fresh; backups; echo "@" >"$TMP/pick"; out=$(TZ=UTC on_tty $'1\n' fedokawaii --run restore); has "$out" "the whole home is not taken in one go — mark its folders"
case_ "…a backup of last year says its year (backups live twelve months)"
fresh; backups; ly=$(( $(date -u +%Y) - 1 )); sed -i "3s/\t[0-9-]*T/\t${ly}-11-20T/" "$TMP/times"
out=$(plain "$(TZ=UTC on_tty $'\n' fedokawaii --run restore)"); has "$out" "20 Nov $ly"; has "$out" "today"
case_ "…the dialog cancelled: nothing taken, the backup closed; a backup that cannot be opened: restic's reason, nothing left"
fresh; backups; out=$(TZ=UTC on_tty $'1\n' fedokawaii --run restore); has "$out" "nothing taken"; called '^fusermount3 -u'; eq "$(mounts_left)" ""
fresh; backups; : >"$TMP/mount-fails"; out=$(TZ=UTC on_tty $'1\n' fedokawaii --run restore)
has "$out" "the backup could not be opened: restic: wrong password or no key found"; not_called '^kawa-pick'; eq "$(mounts_left)" ""
case_ "…the window closed while the backup is open (the dialog showing): the backup closed all the same — fusermount3 called, no folder left (the master's T48 should-fix 4)"
fresh; backups; stub kawa-pick 'printf "%s\n" "env $KAWA_PICK_TITLE | $KAWA_PICK_ROOT" >>"$CALLS"; sleep 30'
printf '1\n' | python3 -I "$REPO/tests/lib/pty_run.py" --stdin --hangup 3 --timeout 20 -- fedokawaii --run restore >/dev/null 2>&1
for _ in $(seq 1 50); do [[ -z $(mounts_left) ]] && break; sleep 0.1; done
called '^kawa-pick --inside back '; called '^fusermount3 -uz'; eq "$(mounts_left)" "" "the mount's folder and the dialog's gone"
case_ "…no backup there yet, or kawa-backup cannot reach it (not plugged in): said, nothing asked"
fresh; backups; : >"$TMP/times"; out=$(tty_free fedokawaii --run restore </dev/null 2>&1); has "$out" "no backup on the drive yet — back up now makes the first"
fresh; backups; stub kawa-backup 'echo "  KINGSTON is not plugged in" >&2; exit 1'; out=$(tty_free fedokawaii --run restore </dev/null 2>&1)
has "$out" "KINGSTON is not plugged in"; not_called '^kawa-pick'
case_ "the drive: its pane names it, where it is (free space while it is open) and the last backup; not plugged in, or none chosen, in vermilion"
fresh; backups; out=$(fedokawaii --explain drive); has "$(plain "$out")" "drive     KINGSTON"; has "$(plain "$out")" "plugged in · 123 GB free of 500 GB"
has "$(plain "$out")" "backup    none yet"; lacks "$(plain "$out")" "not yet"; has "$(plain "$out")" "enter: another"
mkdir -p "$HOME/.local/state/fedokawaii"; printf '%s\t1 MiB\tKINGSTON\n' "$(date +%s)" >"$HOME/.local/state/fedokawaii/last-backup"
has "$(plain "$(fedokawaii --explain drive)")" "backup    $(date '+%-d %b %Y') · today"
printf 'KINGSTON\tout\t\t\n' >"$TMP/drive"; out=$(fedokawaii --explain drive); has "$out" $'\e[38;5;20mnot plugged in'
printf '\tnone\t\t\n' >"$TMP/drive"; out=$(fedokawaii --explain drive); has "$out" $'\e[38;5;20mnone chosen yet'; lacks "$(plain "$out")" "backup    "
case_ "…a name or a path longer than the pane: in pieces at its spaces, / and : — never cut, never wider than the pane"
printf 'SanDisk Extreme Portable SSD V2 Backups\tplugged\t\t\n' >"$TMP/drive"; out=$(plain "$(fedokawaii --explain drive)")
has "$out" "drive     SanDisk Extreme Portable SSD V2"$'\n'"             Backups"$'\n'"             plugged in"; (( $(widest "$out") <= 50 )) && _ok || _no "wider than the pane: $out"
printf 'sftp:backup-user@nas.home.arpa:/srv/restic/fedokawaii\taddress\t\t\n' >"$TMP/drive"; out=$(plain "$(fedokawaii --explain drive)")
has "$out" "drive     sftp:backup-user@nas.home.arpa:/"$'\n'"             srv/restic/fedokawaii"$'\n'"             a restic address"; (( $(widest "$out") <= 50 )) && _ok || _no "wider than the pane: $out"
case_ "the drive: its row's value the drive's name — a path or an address by its last part, only where it fits (none chosen: none, in vermilion); enter: kawa-backup's picker"
fresh; backups; setting BACKUP_TARGET KINGSTON; has "$(plain "$(row drive)")" "KINGSTON"
setting BACKUP_TARGET /run/media/me/KINGSTON/fedokawaii-backup; has "$(plain "$(row drive)")" "the drive" ; [[ $(plain "$(row drive)") == *" KINGSTON" ]] && _ok || _no "$(plain "$(row drive)")"
setting BACKUP_TARGET "sftp:you@nas:/backups"; [[ $(plain "$(row drive)") == *" backups" ]] && _ok || _no "$(plain "$(row drive)")"
setting BACKUP_TARGET "/run/media/me/a drive label far too long to fit"; l=$(plain "$(row drive)"); lacks "$l" "fit" "no value cut short"; (( $(widest "$(cut -f2 <<<"$l")") <= 38 )) && _ok || _no "too wide: $l"
setting BACKUP_TARGET ""; has "$(grep -m1 "^drive"$'\t' <<<"$(allrows)")" $'\e[38;5;20mnone'
reset_calls; out=$(tty_free fedokawaii --run drive </dev/null 2>&1); called '^kawa-backup pick$'
case_ "restore: its pane says what it does — its own icon (not go back's)"
out=$(plain "$(fedokawaii --explain restore)"); has "$out" "a folder or several, copied into ~/Restored"; has "$out" "never over what is there."; lacks "$out" "in place"; lacks "$out" "not yet"
(. "$REPO/configs/home/.config/fedokawaii/icons.sh"; l=$(row restore); [[ $l == *"$ICON_UNPACK"* && $l != *"$ICON_UNDO"* ]]) && _ok || _no "restore's icon: $(row restore)"
case_ "snapshots without snapper, or on a root that is not Btrfs: said plainly"
reset_calls
out=$(without snapper -- "$SETSID" -w fedokawaii --run snapshots </dev/null 2>&1); has "$out" "snapper is not installed"; not_called '^sudo'
fresh; echo ext4 >"$R/fstype"
out=$(tty_free fedokawaii --run snapshots </dev/null 2>&1); has "$out" "/ is ext4"; has "$out" "Btrfs"; not_called '^sudo'
out=$(fedokawaii snapshots 2>&1); eq "$?" 1; has "$out" "/ is ext4"

case_ "reminders: each Enter the next step — 14, 30, 60 days, off, back to 14"
fresh
for want in "EVERY=30" "EVERY=60" "REMIND=no" "EVERY=14"; do
  tty_free fedokawaii --run remind </dev/null >/dev/null 2>&1
  has "$(cat "$HOME/.config/fedokawaii/upkeep.conf")" "$want"
done

case_ "log: root's log at its end, in less — root reads it, less runs as you (a root pager's ! would be a root shell)"
fresh; printf 'first line\nlast line\n' >"$R/fedokawaii.log"
tty_free fedokawaii --run log </dev/null >/dev/null 2>&1
called "^sudo cat -- $R/fedokawaii.log$"; called '^less \+G$'; not_called '^sudo less'
eq "$(cat "$R/less.out")" $'first line\nlast line' "less shows the log"
reset_calls; rm -f "$R/less.out"; fedokawaii log >/dev/null 2>&1; called "^sudo cat -- $R/fedokawaii.log$"; called '^less \+G$'
case_ "log with sudo refusing: said, and no pager"
fresh; : >"$R/sudo-refused"; out=$(fedokawaii log 2>&1); has "$out" "needs root"; not_called '^less'
case_ "the lessons: a window of their own, tiled (the menu never waits for it)"
fresh; export WAYLAND_DISPLAY=wayland-1; stub kawa-learn; stub kawa-term
tty_free fedokawaii --run learn </dev/null >/dev/null 2>&1; called "^setsid -f kawa-term --app kawa-learn lessons kawa-learn$"
reset_calls; fedokawaii learn; called "^setsid -f kawa-term --app kawa-learn lessons kawa-learn$"
case_ "the lessons missing, or kawa-learn: said, not a silent nothing"
rm -f "$R/toolkit/docs/learn/index.tsv"
out=$(fedokawaii learn 2>&1); eq "$?" 1; has "$out" "the lessons are missing"
fresh; export WAYLAND_DISPLAY=wayland-1
out=$(without kawa-learn -- fedokawaii learn 2>&1); eq "$?" 1; has "$out" "kawa-learn is missing"
case_ "the lessons on a text console (no desktop: the rescue screen): the next as text, no window"
fresh; unset WAYLAND_DISPLAY; stub kawa-learn; stub kawa-term
fedokawaii learn; called "^kawa-learn --text$"; not_called kawa-term
case_ "the old Guide is gone: no such command, no PDF named"
out=$(fedokawaii guide 2>&1); eq "$?" 2; has "$out" 'unknown command "guide"'
lacks "$(cat "$(command -v fedokawaii)")" "Fedokawaii-Guide"".pdf"
case_ "the row and the pane say how far: from the file kawa-learn keeps, no program started for the row"
fresh; export WAYLAND_DISPLAY=wayland-1; mkdir -p "$XDG_STATE_HOME/fedokawaii"
printf '12\t259\tthe ten keys, and how windows arrange\t4\t2200\n' >"$XDG_STATE_HOME/fedokawaii/learn.place"
stub kawa-learn
has "$(fedokawaii --rows learning | sed -n 1p)" "12 of 259"; not_called kawa-learn
out=$(plain "$(fedokawaii --explain learn)"); has "$out" "12 of 259"; has "$out" "the ten keys, and how windows"; has "$out" "arrange"; has "$out" "4 min"; has "$out" "36 h"
unset WAYLAND_DISPLAY

# ── settings: a copy edited, checked by root, only then saved ─────────────────
editor() { printf '#!/bin/sh\n%s\n' "$1" >"$TMP/ed"; chmod +x "$TMP/ed"; export VISUAL=$TMP/ed; }
case_ "settings unchanged: nothing asked of root"
fresh; editor 'true'
out=$(tty_free fedokawaii --run settings </dev/null 2>&1)
has "$out" "unchanged"; has "$out" "finished"; eq "$(front_calls)" ""
case_ "settings changed and valid: root checks the copy, saves it"
editor 'sed -i "s/^WALLPAPER_PACK=\"yes\"/WALLPAPER_PACK=\"no\"/" "$1"'
out=$(tty_free fedokawaii --run settings </dev/null 2>&1)
has "$(front_calls)" "front conf "; has "$(cat "$R/toolkit/fedokawaii.conf")" 'WALLPAPER_PACK="no"'; has "$out" "finished"
case_ "settings with a slip: not saved, the reason shown, the temp copy gone"
fresh; editor 'echo "BAD=1" >>"$1"'
out=$(tty_free fedokawaii --run settings </dev/null 2>&1)
has "$out" "not saved"; has "$out" "error (1)"; lacks "$(cat "$R/toolkit/fedokawaii.conf")" "BAD"
eq "$(find "$XDG_RUNTIME_DIR" -name 'fedokawaii.conf.*' | wc -l)" 0 "the edited copy is removed"
case_ "settings with a slip: edit it again (y) keeps your edit; fixed, it is saved"
fresh
# (first: a slip; the second time the editor sees it, it takes the slip out again)
editor 'if grep -q BAD "$1"; then sed -i "/BAD/d; s/^WALLPAPER_PACK=\"yes\"/WALLPAPER_PACK=\"no\"/" "$1"; else echo "BAD=1" >>"$1"; fi'
out=$(on_tty "yx" fedokawaii --run settings)
has "$out" "edit it again"; has "$(cat "$R/toolkit/fedokawaii.conf")" 'WALLPAPER_PACK="no"'
has "$out" "finished"
case_ "settings with a slip: n gives up — nothing saved"
fresh; editor 'echo "BAD=1" >>"$1"'
out=$(on_tty "nx" fedokawaii --run settings)
has "$out" "not saved"; lacks "$(cat "$R/toolkit/fedokawaii.conf")" "BAD"
case_ "settings: an editor that does not exist is said, nothing asked of root"
fresh; export VISUAL=/nonexistent/editor
out=$(tty_free fedokawaii --run settings </dev/null 2>&1); has "$out" "/nonexistent/editor"; lacks "$out" "unchanged"; eq "$(front_calls)" ""
case_ "settings: VISUAL with its own options (code --wait style)"
fresh; printf '#!/bin/sh\n[ "$1" = --wait ] || exit 9\nsed -i "s/^WALLPAPER_PACK=\\"yes\\"/WALLPAPER_PACK=\\"no\\"/" "$2"\n' >"$TMP/ed2"; chmod +x "$TMP/ed2"
export VISUAL="$TMP/ed2 --wait"
tty_free fedokawaii --run settings </dev/null >/dev/null 2>&1; has "$(cat "$R/toolkit/fedokawaii.conf")" 'WALLPAPER_PACK="no"'
unset VISUAL

# ── the plain menu (no fzf, a text console) ──────────────────────────────────
case_ "plain menu: the status, nineteen numbered entries; q, Q, Enter and end of input all leave"
console
for k in q Q "" ; do out=$(printf '%s\n' "$k" | tty_free fedokawaii 2>&1); eq "$?" 0 "[$k]"; done
out=$(tty_free fedokawaii </dev/null 2>&1); eq "$?" 0 "end of input"
has "$out" "FEDOKAWAII"; has "$out" "release   Fedora 44"; has "$out" " 1  status"; has "$out" " 8  log"; has "$out" " 9  update"; has "$out" "10  go back"
has "$out" "11  a file, back"; has "$out" "12  back up now"; has "$out" "13  restore"; has "$out" "14  the drive"; has "$out" "15  before you wipe"; has "$out" "16  bring back"; has "$out" "17  lessons"; lacks "$out" "soon" "nothing that is not built yet"; has "$out" "backup    no drive"
case_ "plain menu: a number runs its entry, then the menu again"
out=$(printf '9\nq\n' | tty_free fedokawaii 2>&1)
eq "$(front_calls)" "front update"; eq "$(grep -c FEDOKAWAII <<<"$out")" 2
case_ "plain menu: a wrong answer says what is wanted, and runs nothing"
console; out=$(printf '0\n20\nx\n1x\n-1\n\n' | tty_free fedokawaii 2>&1)
eq "$(grep -c '1–19, or q' <<<"$out")" 5 "each of the five wrong answers"; eq "$(front_calls)" ""
case_ "plain menu on the text console: no characters the console font may lack"
console; out=$(printf 'q\n' | TERM=linux tty_free fedokawaii 2>&1)
lacks "$out" "·"; lacks "$out" "—"; lacks "$out" "…"; lacks "$out" "→"; has "$out" "status"
out=$(TERM=linux fedokawaii status); lacks "$out" "·"
case_ "Fedora 45's text consoles are kmscon's (TERM=kmscon, TERM_SESSION_TYPE=kms or fb): the plain menu, plain characters — not fzf"
out=$(TERM=kmscon fedokawaii status); lacks "$out" "·"
out=$(TERM=xterm-256color TERM_SESSION_TYPE=fb fedokawaii status); lacks "$out" "·" "kmscon under another TERM"
console; stub fzf 'cat >/dev/null; exit 130'
out=$(TERM=kmscon TERM_SESSION_TYPE=kms on_tty "q"$'\n' fedokawaii); has "$out" "19  lessons"; lacks "$out" "·"; not_called '^fzf'
case_ "plain menu when fzf cannot run (old fzf: exit 2) on a terminal"
console; stub fzf 'exit 2'
out=$(on_tty "q"$'\n' fedokawaii); has "$out" "FEDOKAWAII"; has "$out" "19  lessons"
case_ "fzf menu: Esc closes it (exit 0)"
stub fzf 'cat >/dev/null; exit 130'; on_tty "" fedokawaii >/dev/null; eq "$?" 0; called '^fzf --read0 --ansi'
case_ "Super+U: the menu in a warm window of its own (a popup: kawa-warm's toggle)"
fresh; stub kawa-warm; fedokawaii --window; called "^kawa-warm system$"
case_ "Super+U's popup: a job is handed to a window of its own (a click outside, or Super+U again, never kills it) and the menu ends"
for a in update verify repair theme drift snapshots file backup settings log; do
  reset_calls; FEDOKAWAII_POPUP=yes tty_free fedokawaii --run "$a" </dev/null >/dev/null 2>&1; eq "$?" 0 "$a"
  called "^setsid -f .*fedokawaii --job $a$"; eq "$(front_calls)" "" "$a: not run in the popup"; not_called '^sudo'
done
case_ "Super+U's popup: a quick entry still runs in place, and comes back to the menu"
reset_calls; out=$(FEDOKAWAII_POPUP=yes tty_free fedokawaii --run status </dev/null 2>&1)
has "$out" "finished"; has "$out" "any key goes back to the menu"; not_called 'fedokawaii --job'
case_ "the job's window: a dialog, one at a time; inside, the job, then a key that closes it"
fresh; rc 0 fedokawaii --job update
called "^kawa-term --float --once system-job --dialog system · update 100x27 -- .*fedokawaii --job-run update$"; not_called '^notify-send'
out=$(FEDOKAWAII_POPUP=yes tty_free fedokawaii --job-run update </dev/null 2>&1)
eq "$(front_calls)" "front update" "run inside, never handed on again"; has "$out" "finished"; has "$out" "any key closes this window"
case_ "the job's window that cannot open, or one already running: a notice says so"
stub kawa-term 'exit 1'; reset_calls; rc 1 fedokawaii --job update
called '^notify-send -a desktop -u critical -- .*  upkeep the terminal server is not running — fedokawaii repair puts it back$'
stub kawa-term 'exit 3'; reset_calls; rc 3 fedokawaii --job backup
called '^notify-send -a desktop -- .*  upkeep a job of the system menu is running in its window'
case_ "change: the part-by-part menu"
fedokawaii change; called '^kawa-config'

case_ "the tab's record: one per menu, gone when it ends; a start removes the ones whose menu was killed (13 had piled up in a day)"
fresh; stub fzf 'cat >/dev/null; exit 130'; stub curl 'exit 7'   # (the menu's release check: no network)
R=$TMP/run; mkdir -p "$R"; sleep 0 & dead=$!; wait "$dead"
: >"$R/fedokawaii-tab.2c9cwL"; : >"$R/fedokawaii-tab.$dead"; : >"$R/fedokawaii-tab.$$"
XDG_RUNTIME_DIR=$R on_tty "" fedokawaii >/dev/null
eq "$(cd "$R" && ls fedokawaii-tab.* 2>/dev/null | paste -sd ' ')" "fedokawaii-tab.$$" "a live menu's record kept, the dead ones and its own gone"
done_
