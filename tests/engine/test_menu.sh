#!/usr/bin/env bash
# tests/engine/test_menu.sh — Super+U: every entry of the menu and every `fedokawaii` command,
# used right and used wrong. Root's side is a stand-in (lib.sh): it says what it was asked
# and answers with the exit status a test gives it. The menu's rows and its right pane must
# fit their columns; the outcome line after a run must say what the run's status means.
. "$(dirname "$0")/lib.sh"

fresh() { sandbox; engine_world; }
row() { grep -m1 "^$1"$'\t' <<<"$(plain "$(fedokawaii --rows)")"; }
entries() { grep -v '^-' <<<"$1" | cut -f2; }   # entries ROWS — the entries' text, no headings

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
for c in update verify repair theme drift snapshots backup log status copy diff apply guide settings; do
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

# ── the menu's rows ──────────────────────────────────────────────────────────
case_ "rows: on the desktop sixteen entries in three parts, in order, each fitting the 38-column list"
fresh; rec last-update-done "$(ago_s 10)"; rec snapshots 14; rec last-verify "$(ago_s 1) 180 2 0"
out=$(WAYLAND_DISPLAY=wayland-1 fedokawaii --rows)
eq "$(cut -f1 <<<"$out" | tr '\n' ' ')" "- status update pull upgrade verify repair drift snapshots backup - change theme settings remind - keys guide log "
eq "$(grep '^-' <<<"$(plain "$out")" | cut -f2 | sed 's/ ╌*$//' | tr '\n' '|')" "守  upkeep|卓  desktop|案  help|" "the headings: a kanji, two spaces, the part's name"
eq "$(grep '^-' <<<"$(plain "$out")" | cut -f2 | python3 -I -c 'import sys, unicodedata
print(" ".join(str(sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in l)) for l in sys.stdin.read().splitlines()))')" "38 38 38" \
   "…then a space and the stitch to the values' edge (38 columns)"
(( $(widest "$(entries "$out")") <= 38 )) && _ok || _no "a row wider than 38: $(plain "$out")"
while IFS=$'\t' read -r a l _; do [[ $a == - ]] && heading_ok "$l" 38 "the heading's grammar"; done <<<"$out"
case_ "rows: each entry two spaces in, its glyph, two spaces, its name; the value right-aligned at the list's last column, muted"
for a in update snapshots remind; do
  l=$(cut -f2 <<<"$(grep "^$a"$'\t' <<<"$out")")
  [[ $l =~ ^"  "$'\e[38;5;21m'.$'\e[0m'"  "[a-z] ]] && _ok || _no "$a: $l"
  [[ $l == *$'\e[38;5;21m'*[!\ ]$'\e[0m' ]] && _ok || _no "$a: the value muted, at the end: $l"
  eq "$(widest "$l")" 38 "$a: the value's last letter in the list's last column"
done
has "$(row update)" "in 80 days"; has "$(row snapshots)" "14"; has "$(row verify)" "2 to fix"; has "$(row remind)" "every 90 days"
lacks "$(row status)" "Fedora" "status: no value (the pane beside it is the status: the release is its first line)"; has "$(row upgrade)" "upgrade to Fedora 45"
case_ "rows: away from the desktop (a text console, ssh) fourteen — change and keybindings are menus by the bar"
out=$(env -u WAYLAND_DISPLAY fedokawaii --rows)
eq "$(cut -f1 <<<"$out" | tr '\n' ' ')" "- status update pull upgrade verify repair drift snapshots backup - theme settings remind - guide log "
case_ "fzf's items: NUL-ended, every heading after the first with an empty line above it, never one at the end"
items=$(plain "$(WAYLAND_DISPLAY=wayland-1 fedokawaii --items | tr '\0' '\n')")
items=$(sed 's/ ╌*\t$//' <<<"$items")
eq "$(head -n1 <<<"$items")" $'-\t守  upkeep' "the first heading: its own line, at the top"
eq "$(grep -B1 -E '^(卓  desktop|案  help)$' <<<"$items" | tr '\n' '|')" $'-\t|卓  desktop|--|-\t|案  help|' "the others under a gap"
eq "$(fedokawaii --items | tr '\0' '\n' | tail -n1 | cut -f1)" log "never a heading at the end"
eq "$(plain "$(fedokawaii --items | tr '\0' '\n')" | grep -c $'^-\t$')" 2 "two headings after a gap"
eq "$(fedokawaii --items | tr -cd '\0' | wc -c)" "$(fedokawaii --rows | wc -l)" "one item a row"
case_ "change the desktop, keybindings: opened on their own, and the menu closes for them (fzf becomes the run)"
fresh; stub kawa-config; stub kawa-help
WAYLAND_DISPLAY=wayland-1 fedokawaii --run change </dev/null; WAYLAND_DISPLAY=wayland-1 fedokawaii --run keys </dev/null
for _ in 1 2 3 4 5 6 7 8 9 10; do grep -q kawa-help "$CALLS" && grep -q kawa-config "$CALLS" && break; sleep 0.1; done
called '^setsid -f kawa-config$'; called '^setsid -f kawa-help$'
has "$(cat "$(command -v fedokawaii)")" "enter:transform:case {1} in -) ;; change|keys\${pop}) echo 'become("
case_ "Super+U's popup (--popup): the menu closes for a job too (fzf becomes the run, which hands it on); a plain menu, not"
if has_script; then
  fresh; stub fzf 'cat >/dev/null; exit 130'
  on_tty "" fedokawaii --popup >/dev/null; called 'enter:transform:case \{1\} in -\) ;; change\|keys\|update\|pull\|upgrade\|verify\|repair\|theme\|drift\|snapshots\|backup\|settings\|log\) echo .become\('
  reset_calls; on_tty "" fedokawaii >/dev/null; called 'enter:transform:case \{1\} in -\) ;; change\|keys\) echo .become\('
else _ok; fi
case_ "rows: the mark at the right edge, wider with a wider window (FZF_COLUMNS)"
w=$(widest "$(entries "$(FZF_COLUMNS=120 fedokawaii --rows)")"); eq "$w" 68
w=$(widest "$(entries "$(FZF_COLUMNS=98 fedokawaii --rows)")"); eq "$w" 46 "the 100-column window (98 inside fzf's margins): 46"
w=$(widest "$(entries "$(FZF_COLUMNS=40 fedokawaii --rows)")"); eq "$w" 38 "a narrow window keeps the 38"
w=$(widest "$(entries "$(FZF_COLUMNS=garbage fedokawaii --rows </dev/null)")"); eq "$w" 38
case_ "rows at their widest: a release that settles in 180 days, an update in a year"
fedokawaii remind wait 180 >/dev/null; fedokawaii remind every 365 >/dev/null
rec release-45 "$(ago_s 0)"; rec last-update-done "$(ago_s 0)"
out=$(fedokawaii --rows)
has "$(row upgrade)" "in 180 days"; has "$(row update)" "in 365 days"
(( $(widest "$(entries "$out")") <= 38 )) && _ok || _no "too wide: $(plain "$out")"
case_ "rows: due, ready (the kanji's vermilion: they need you), reminders off"
fresh; rec last-update-done "$(ago_s 200)"; rec release-45 "$(ago_s 100)"
out=$(fedokawaii --rows)
has "$(grep '^update' <<<"$out")" $'\e[38;5;20mdue'; has "$(grep '^upgrade' <<<"$out")" $'\e[38;5;20mready'
fedokawaii remind off >/dev/null; has "$(row remind)" "off"
case_ "rows: a garbage snapshot count is not shown (nor makes the row too wide)"
fresh; rec snapshots "$(printf 'x%.0s' {1..80})"
lacks "$(row snapshots)" "xxx"
(( $(widest "$(entries "$(fedokawaii --rows)")") <= 38 )) && _ok || _no "too wide"
case_ "rows: os-release unreadable: no made-up Fedora 1"
rm -f "$R/os-release"; lacks "$(fedokawaii --rows)" "Fedora 1"; lacks "$(fedokawaii --rows)" "Fedora 0"
# the backup's mark reads kawa-backup's record (~/.local/state/fedokawaii/last-backup) and the
# toolkit's fedokawaii.conf as settings saved it (BACKUP_TARGET, BACKUP_REMIND_DAYS)
backed_up() { mkdir -p "$HOME/.local/state/fedokawaii"; printf '%s\t43.763 KiB\tKINGSTON\n' "$(ago_s "$1")" >"$HOME/.local/state/fedokawaii/last-backup"; }
case_ "rows: no backup set up (BACKUP_TARGET empty): none, in red"
fresh; has "$(grep '^backup' <<<"$(fedokawaii --rows)")" $'\e[38;5;20mnone'
case_ "rows: a drive named, no backup yet: never, in red; one 3 days ago: its age, grey; past the reminder's days: red"
fresh; setting BACKUP_TARGET KINGSTON
has "$(grep '^backup' <<<"$(fedokawaii --rows)")" $'\e[38;5;20mnever'
backed_up 3; has "$(grep '^backup' <<<"$(fedokawaii --rows)")" $'\e[38;5;21m3 days ago'
backed_up 7; has "$(grep '^backup' <<<"$(fedokawaii --rows)")" $'\e[38;5;20m7 days ago'
backed_up 0; has "$(grep '^backup' <<<"$(fedokawaii --rows)")" $'\e[38;5;21mtoday'
case_ "rows: BACKUP_REMIND_DAYS=0 — never red, however old"
fresh; setting BACKUP_TARGET KINGSTON; setting BACKUP_REMIND_DAYS 0; backed_up 400
has "$(grep '^backup' <<<"$(fedokawaii --rows)")" $'\e[38;5;21m400 days ago'
(( $(widest "$(entries "$(fedokawaii --rows)")") <= 38 )) && _ok || _no "too wide"
case_ "rows: a garbage record, or one holding a command: never, nothing run"
printf 'rm -rf %s\tx\n' "$TMP/pwned" >"$HOME/.local/state/fedokawaii/last-backup"; mkdir -p "$TMP/pwned"
has "$(grep '^backup' <<<"$(fedokawaii --rows)")" never; [[ -d $TMP/pwned ]] && _ok || _no "the record ran"
case_ "rows: a setting counts as soon as settings saves it"
fresh; setting BACKUP_TARGET KINGSTON; backed_up 3
has "$(grep '^backup' <<<"$(fedokawaii --rows)")" $'\e[38;5;21m3 days ago'
setting BACKUP_REMIND_DAYS 2; has "$(grep '^backup' <<<"$(fedokawaii --rows)")" $'\e[38;5;20m3 days ago' "2 days: late at once"
setting BACKUP_TARGET ""; has "$(grep '^backup' <<<"$(fedokawaii --rows)")" $'\e[38;5;20mnone' "none named: none"
case_ "rows: the toolkit's settings unreadable: none, no error"
rm -f "$R/toolkit/fedokawaii.conf"; out=$(fedokawaii --rows 2>&1); has "$(grep '^backup' <<<"$out")" none; lacks "$out" "No such file"

# ── the right pane ───────────────────────────────────────────────────────────
case_ "the pane, for every entry, with every record at its longest: its heading, then ≤ 15 of ≤ 49 (four columns in, then 45; the pane's last column paper)"
fresh
( exec 9>"$R/state/lock"; flock 9; exec sleep 30 ) >/dev/null 2>&1 & holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$R/state/lock" true || break; sleep 0.1; done
rec last-upgrade "$(ago_s 3) 43 44 partial"; rec last-update "$(ago_s 0) stopped"; rec last-update-done "$(ago_s 100)"
rec last-verify "$(ago_s 365) 1800 0 12"; echo 6.17.10-1300.fc44.x86_64 >"$R/newest-kernel"
echo "2000000000000 12000000000" >"$R/df"; printf '%s\n' a-very-long-package-name another-long-one >"$R/state/unavailable"
printf '/etc/x.rpmnew\n' >"$R/state/rpmnew"
setting BACKUP_TARGET "a drive with a long name"; backed_up 1000
for a in status update pull upgrade verify repair snapshots backup theme drift change settings remind log keys guide; do
  out=$(fedokawaii --explain "$a")
  (( $(wc -l <<<"$out") <= 16 )) && _ok || _no "$a: $(wc -l <<<"$out") lines"
  heading_ok "$(sed -n 1p <<<"$out" | cut -c3-)" 47 "$a: the pane's heading (level with the list's first)"
  [[ $(plain "$(sed -n 2p <<<"$out")") == "    "[!\ ]* ]] && _ok || _no "$a: under the heading at once, two columns in from it: $(sed -n 2p <<<"$out")"
  (( $(widest "$out") <= 49 )) && _ok || _no "$a: a line of $(widest "$out")"
  has "$(plain "$out")" "running " "$a: the run going on is shown"
done
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
case_ "the pane never repeats the list beside it: no next Fedora (the upgrade's row), the due day without its 'in N days' (update's)"
fresh; rec last-update-done "$(ago_s 10)"
for a in status update upgrade; do
  out=$(plain "$(WAYLAND_DISPLAY=wayland-1 fedokawaii --explain "$a")")
  lacks "$out" "next " "$a: no next line"; lacks "$(grep '^ *due ' <<<"$out")" " · in " "$a: the due day without 'in N days'"
done
has "$(plain "$(fedokawaii --explain update)")" "due " "update: its due day all the same"
case_ "the pane for nothing, or for something unknown: empty, no error"
eq "$(fedokawaii --explain 2>&1)" ""; eq "$(fedokawaii --explain bogus 2>&1)" ""; eq "$(fedokawaii --explain - 2>&1)" "" "a heading"

# ── run: an entry chosen, its outcome, a key back ─────────────────────────────
outcome() { tty_free fedokawaii --run "$1" </dev/null 2>&1 | tail -n3; }   # (the outcome's row, a blank line, the footer)
case_ "status: shown, then finished"
fresh; out=$(tty_free fedokawaii --run status </dev/null 2>&1)
has "$out" $'\e[H\e[2J'; has "$out" "release   Fedora 44"; has "$out" "finished"; has "$out" "any key goes back to the menu"
case_ "the outcome line says what each exit status means"
for a in update upgrade verify repair theme drift; do
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
if has_script; then
  out=$(on_tty "x" fedokawaii --run status); has "$out" "finished"; has "$out" "any key goes back"
  eq "$?" 0
else _ok; fi

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
case_ "snapshots: a long description cut at a word's end, never mid-word, never an …; the boot menu's way said"
fresh; stub kawa-snap 'case $1 in list) printf "9\tpre\t2026-10-15 09:00:00\tdnf install libreoffice-writer libreoffice-calc libreoffice-impress hunspell\t-\n" ;; esac'
out=$(plain "$(tty_free fedokawaii --run snapshots </dev/null 2>&1)")
has "$out" "9     dnf install libreoffice-writer "; lacks "$out" "libreoffice-c"; lacks "$out" "…"
has "$out" "or at power-on: hold Shift (Esc/F8) for the boot menu → snapshots"
if has_script; then
  case_ "snapshots: a number, then yes — that one restored as root, the restart asked (n: none)"
  fresh; snaplist; out=$(on_tty $'41\nyes\nn' fedokawaii --run snapshots)
  called '^sudo kawa-snap restore 41$'; not_called '^systemctl reboot'
  fresh; snaplist; on_tty $'old\nyes\ny' fedokawaii --run snapshots >/dev/null
  called '^sudo kawa-snap restore old$'; called '^systemctl reboot'
  case_ "snapshots: anything but yes, or a number not listed — nothing restored"
  fresh; snaplist; on_tty $'41\nno\n' fedokawaii --run snapshots >/dev/null; not_called 'kawa-snap restore'
  out=$(on_tty $'42\nyes\n' fedokawaii --run snapshots); has "$out" "no snapshot 42 in the list"; not_called 'kawa-snap restore'
fi
case_ "snapshots without snapper, or on a root that is not Btrfs: said plainly"
reset_calls
out=$(without snapper -- "$SETSID" -w fedokawaii --run snapshots </dev/null 2>&1); has "$out" "snapper is not installed"; not_called '^sudo'
fresh; echo ext4 >"$R/fstype"
out=$(tty_free fedokawaii --run snapshots </dev/null 2>&1); has "$out" "/ is ext4"; has "$out" "Btrfs"; not_called '^sudo'
out=$(fedokawaii snapshots 2>&1); eq "$?" 1; has "$out" "/ is ext4"

case_ "reminders: each Enter the next step — 60, 90, 120 days, off, back to 60"
fresh
for want in "EVERY=120" "REMIND=no" "EVERY=60" "EVERY=90"; do
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
case_ "the learning guide: zathura, on its own (the menu never waits for it)"
fresh; export WAYLAND_DISPLAY=wayland-1
tty_free fedokawaii --run guide </dev/null >/dev/null 2>&1; called "^setsid -f zathura $R/toolkit/docs/Fedokawaii-Learn.pdf"
reset_calls; fedokawaii guide; called "^setsid -f zathura"
case_ "the learning guide missing, or zathura: said, not a silent nothing"
rm -f "$R/toolkit/docs/Fedokawaii-Learn.pdf"
out=$(fedokawaii guide 2>&1); eq "$?" 1; has "$out" "the learning guide is missing"
fresh; export WAYLAND_DISPLAY=wayland-1
out=$(without zathura -- fedokawaii guide 2>&1); eq "$?" 1; has "$out" "zathura is not installed"
case_ "the learning guide on a text console (no desktop: the rescue screen): its text, in less"
fresh; unset WAYLAND_DISPLAY; printf '# Fedokawaii\n' >"$R/toolkit/docs/fedokawaii-learn.md"
fedokawaii guide; called "^less .*$R/toolkit/docs/fedokawaii-learn.md"; not_called zathura
case_ "the full handbook stays in the repository: the menu never opens it"
fresh; export WAYLAND_DISPLAY=wayland-1; printf '%%PDF-1.4 the handbook\n' >"$R/toolkit/docs/Fedokawaii-Guide.pdf"
fedokawaii guide; not_called "Fedokawaii-Guide.pdf"; called "^setsid -f zathura $R/toolkit/docs/Fedokawaii-Learn.pdf"; unset WAYLAND_DISPLAY

# ── settings: a copy edited, checked by root, only then saved ─────────────────
editor() { printf '#!/bin/sh\n%s\n' "$1" >"$TMP/ed"; chmod +x "$TMP/ed"; export VISUAL=$TMP/ed; }
case_ "settings unchanged: nothing asked of root"
fresh; editor 'true'
out=$(tty_free fedokawaii --run settings </dev/null 2>&1)
has "$out" "unchanged"; has "$out" "finished"; eq "$(front_calls)" ""
case_ "settings changed and valid: root checks the copy, saves it"
editor 'sed -i "s/^STEAM=\"yes\"/STEAM=\"no\"/" "$1"'
out=$(tty_free fedokawaii --run settings </dev/null 2>&1)
has "$(front_calls)" "front conf "; has "$(cat "$R/toolkit/fedokawaii.conf")" 'STEAM="no"'; has "$out" "finished"
case_ "settings with a slip: not saved, the reason shown, the temp copy gone"
fresh; editor 'echo "BAD=1" >>"$1"'
out=$(tty_free fedokawaii --run settings </dev/null 2>&1)
has "$out" "not saved"; has "$out" "error (1)"; lacks "$(cat "$R/toolkit/fedokawaii.conf")" "BAD"
eq "$(find "$XDG_RUNTIME_DIR" -name 'fedokawaii.conf.*' | wc -l)" 0 "the edited copy is removed"
case_ "settings with a slip: edit it again (y) keeps your edit; fixed, it is saved"
if has_script; then
  fresh
  # (first: a slip; the second time the editor sees it, it takes the slip out again)
  editor 'if grep -q BAD "$1"; then sed -i "/BAD/d; s/^STEAM=\"yes\"/STEAM=\"no\"/" "$1"; else echo "BAD=1" >>"$1"; fi'
  out=$(on_tty "yx" fedokawaii --run settings)
  has "$out" "edit it again"; has "$(cat "$R/toolkit/fedokawaii.conf")" 'STEAM="no"'
  has "$out" "finished"
  case_ "settings with a slip: n gives up — nothing saved"
  fresh; editor 'echo "BAD=1" >>"$1"'
  out=$(on_tty "nx" fedokawaii --run settings)
  has "$out" "not saved"; lacks "$(cat "$R/toolkit/fedokawaii.conf")" "BAD"
else _ok; fi
case_ "settings: an editor that does not exist is said, nothing asked of root"
fresh; export VISUAL=/nonexistent/editor
out=$(tty_free fedokawaii --run settings </dev/null 2>&1); has "$out" "/nonexistent/editor"; lacks "$out" "unchanged"; eq "$(front_calls)" ""
case_ "settings: VISUAL with its own options (code --wait style)"
fresh; printf '#!/bin/sh\n[ "$1" = --wait ] || exit 9\nsed -i "s/^STEAM=\\"yes\\"/STEAM=\\"no\\"/" "$2"\n' >"$TMP/ed2"; chmod +x "$TMP/ed2"
export VISUAL="$TMP/ed2 --wait"
tty_free fedokawaii --run settings </dev/null >/dev/null 2>&1; has "$(cat "$R/toolkit/fedokawaii.conf")" 'STEAM="no"'
unset VISUAL

# ── the plain menu (no fzf, a text console) ──────────────────────────────────
case_ "plain menu: the status, fourteen numbered entries; q, Q, Enter and end of input all leave"
fresh
for k in q Q "" ; do out=$(printf '%s\n' "$k" | tty_free fedokawaii 2>&1); eq "$?" 0 "[$k]"; done
out=$(tty_free fedokawaii </dev/null 2>&1); eq "$?" 0 "end of input"
has "$out" "FEDOKAWAII"; has "$out" "release   Fedora 44"; has "$out" " 1  status"; has "$out" "13  learn"; has "$out" "14  log"; has "$out" " 3  update fedokawaii"
has "$out" " 9  backup"; lacks "$out" "upkeep"; has "$out" "backup    not set up"
case_ "plain menu: a number runs its entry, then the menu again"
out=$(printf '2\nq\n' | tty_free fedokawaii 2>&1)
eq "$(front_calls)" "front update"; eq "$(grep -c FEDOKAWAII <<<"$out")" 2
case_ "plain menu: a wrong answer says what is wanted, and runs nothing"
fresh; out=$(printf '0\n15\nx\n1x\n-1\n\n' | tty_free fedokawaii 2>&1)
eq "$(grep -c '1–14, or q' <<<"$out")" 5 "each of the five wrong answers"; eq "$(front_calls)" ""
case_ "plain menu on the text console: no characters the console font may lack"
fresh; out=$(printf 'q\n' | TERM=linux tty_free fedokawaii 2>&1)
lacks "$out" "·"; lacks "$out" "—"; lacks "$out" "…"; lacks "$out" "→"; has "$out" "status"
out=$(TERM=linux fedokawaii status); lacks "$out" "·"
case_ "Fedora 45's text consoles are kmscon's (TERM=kmscon, TERM_SESSION_TYPE=kms or fb): the plain menu, plain characters — not fzf"
out=$(TERM=kmscon fedokawaii status); lacks "$out" "·"
out=$(TERM=xterm-256color TERM_SESSION_TYPE=fb fedokawaii status); lacks "$out" "·" "kmscon under another TERM"
if has_script; then
  fresh; stub fzf 'cat >/dev/null; exit 130'
  out=$(TERM=kmscon TERM_SESSION_TYPE=kms on_tty "q"$'\n' fedokawaii); has "$out" "13  learn"; lacks "$out" "·"; not_called '^fzf'
else _ok; fi
case_ "plain menu when fzf cannot run (old fzf: exit 2) on a terminal"
if has_script; then
  fresh; stub fzf 'exit 2'
  out=$(on_tty "q"$'\n' fedokawaii); has "$out" "FEDOKAWAII"; has "$out" "13  learn"
  case_ "fzf menu: Esc closes it (exit 0)"
  stub fzf 'cat >/dev/null; exit 130'; on_tty "" fedokawaii >/dev/null; eq "$?" 0; called '^fzf --read0 --ansi'
else _ok; fi
case_ "Super+U: the menu in a warm window of its own (a popup: kawa-warm's toggle)"
fresh; stub kawa-warm; fedokawaii --window; called "^kawa-warm system$"
case_ "Super+U's popup: a job is handed to a window of its own (a click outside, or Super+U again, never kills it) and the menu ends"
for a in update upgrade verify repair theme drift snapshots backup settings log; do
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

done_
