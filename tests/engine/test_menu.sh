#!/usr/bin/env bash
# tests/engine/test_menu.sh — Super+U: every entry of the menu and every `fedokawaii` command,
# used right and used wrong. Root's side is a stand-in (lib.sh): it says what it was asked
# and answers with the exit status a test gives it. The menu's rows and its right pane must
# fit their columns; the outcome line after a run must say what the run's status means.
. "$(dirname "$0")/lib.sh"

fresh() { sandbox; engine_world; }
row() { grep -m1 "^$1"$'\t' <<<"$(plain "$(fedokawaii --rows)")"; }

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
for c in update verify repair theme drift snapshots log status copy diff apply guide settings; do
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
case_ "rows: twelve entries, in order, each fitting the 35-column list"
fresh; rec last-update-done "$(ago_s 10)"; rec snapshots 14; rec last-verify "$(ago_s 1) 180 2 0"
out=$(fedokawaii --rows)
eq "$(cut -f1 <<<"$out" | tr '\n' ' ')" "status update upgrade verify repair snapshots theme drift settings remind log guide "
(( $(widest "$(cut -f2 <<<"$out")") <= 35 )) && _ok || _no "a row wider than 35: $(plain "$out")"
has "$(row update)" "in 80 days"; has "$(row snapshots)" "14"; has "$(row verify)" "2 to fix"; has "$(row remind)" "every 90 days"
has "$(row status)" "Fedora 44"; has "$(row upgrade)" "upgrade to Fedora 45"
case_ "rows: the mark at the right edge, wider with a wider window (FZF_COLUMNS)"
w=$(widest "$(FZF_COLUMNS=120 fedokawaii --rows | cut -f2)"); eq "$w" 69
w=$(widest "$(FZF_COLUMNS=40 fedokawaii --rows | cut -f2)"); eq "$w" 35 "a narrow window keeps the 35"
w=$(widest "$(FZF_COLUMNS=garbage fedokawaii --rows | cut -f2)"); eq "$w" 35
case_ "rows at their widest: a release that settles in 180 days, an update in a year"
fedokawaii remind wait 180 >/dev/null; fedokawaii remind every 365 >/dev/null
rec release-45 "$(ago_s 0)"; rec last-update-done "$(ago_s 0)"
out=$(fedokawaii --rows)
has "$(row upgrade)" "in 180 days"; has "$(row update)" "in 365 days"
(( $(widest "$(cut -f2 <<<"$out")") <= 35 )) && _ok || _no "too wide: $(plain "$out")"
case_ "rows: due (red), ready (red), reminders off"
fresh; rec last-update-done "$(ago_s 200)"; rec release-45 "$(ago_s 100)"
out=$(fedokawaii --rows)
has "$(grep '^update' <<<"$out")" $'\e[91mdue'; has "$(grep '^upgrade' <<<"$out")" $'\e[91mready'
fedokawaii remind off >/dev/null; has "$(row remind)" "off"
case_ "rows: a garbage snapshot count is not shown (nor makes the row too wide)"
fresh; rec snapshots "$(printf 'x%.0s' {1..80})"
lacks "$(row snapshots)" "xxx"
(( $(widest "$(fedokawaii --rows | cut -f2)") <= 35 )) && _ok || _no "too wide"
case_ "rows: os-release unreadable: no made-up Fedora 1"
rm -f "$R/os-release"; lacks "$(fedokawaii --rows)" "Fedora 1"; lacks "$(fedokawaii --rows)" "Fedora 0"

# ── the right pane ───────────────────────────────────────────────────────────
case_ "the pane, for every entry, with every record at its longest: ≤ 14 lines of ≤ 44"
fresh
( exec 9>"$R/state/lock"; flock 9; exec sleep 30 ) >/dev/null 2>&1 & holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$R/state/lock" true || break; sleep 0.1; done
rec last-upgrade "$(ago_s 3) 43 44 partial"; rec last-update "$(ago_s 0) stopped"; rec last-update-done "$(ago_s 100)"
rec last-verify "$(ago_s 365) 1800 0 12"; echo 6.17.10-1300.fc44.x86_64 >"$R/newest-kernel"
echo "2000000000000 12000000000" >"$R/df"; printf '%s\n' a-very-long-package-name another-long-one >"$R/state/unavailable"
printf '/etc/x.rpmnew\n' >"$R/state/rpmnew"
for a in status update upgrade verify repair snapshots theme drift settings remind log guide; do
  out=$(fedokawaii --explain "$a")
  (( $(wc -l <<<"$out") <= 14 )) && _ok || _no "$a: $(wc -l <<<"$out") lines"
  (( $(widest "$out") <= 44 )) && _ok || _no "$a: a line of $(widest "$out")"
  has "$(plain "$out")" "running " "$a: the run going on is shown"
done
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
case_ "the pane for nothing, or for something unknown: empty, no error"
eq "$(fedokawaii --explain 2>&1)" ""; eq "$(fedokawaii --explain bogus 2>&1)" ""

# ── run: an entry chosen, its outcome, a key back ─────────────────────────────
outcome() { tty_free fedokawaii --run "$1" </dev/null 2>&1 | tail -n1; }
case_ "status: shown, then finished"
fresh; out=$(tty_free fedokawaii --run status </dev/null 2>&1)
has "$out" $'\e[H\e[2J'; has "$out" "release  Fedora 44"; has "$out" "finished — any key goes back to the menu"
case_ "the outcome line says what each exit status means"
for a in update upgrade verify repair theme drift; do
  echo 0 >"$R/rc-$a"; has "$(outcome "$a")" "finished" "$a 0"
  echo 1 >"$R/rc-$a"; has "$(outcome "$a")" "it ended with an error (1)" "$a 1"
done
for a in verify repair drift; do echo 3 >"$R/rc-$a"; has "$(outcome "$a")" "done — some things still need you" "$a 3"; done
echo 4 >"$R/rc-drift"; has "$(outcome drift)" "done — some things still need you" "drift 4: in sync but for optional parts"
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
  out=$(on_tty "x" fedokawaii --run status); has "$out" "finished — any key goes back"
  eq "$?" 0
else _ok; fi

case_ "snapshots: snapper's list, as root"
fresh; out=$(outcome snapshots); has "$out" "finished"; called '^sudo snapper -c root list'
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

case_ "log: root's log, read-only, at its end"
fresh; tty_free fedokawaii --run log </dev/null >/dev/null 2>&1
called "^sudo nvim -R \+normal G $R/fedokawaii.log"
case_ "the handbook: zathura, on its own (the menu never waits for it)"
fresh; export WAYLAND_DISPLAY=wayland-1
tty_free fedokawaii --run guide </dev/null >/dev/null 2>&1; called "^setsid -f zathura $R/toolkit/docs/Fedokawaii-Guide.pdf"
reset_calls; fedokawaii guide; called "^setsid -f zathura"
case_ "the handbook missing, or zathura: said, not a silent nothing"
rm -f "$R/toolkit/docs/Fedokawaii-Guide.pdf"
out=$(fedokawaii guide 2>&1); eq "$?" 1; has "$out" "the handbook is missing"
fresh; export WAYLAND_DISPLAY=wayland-1
out=$(without zathura -- fedokawaii guide 2>&1); eq "$?" 1; has "$out" "zathura is not installed"
case_ "the handbook on a text console (no desktop: the rescue screen): its text, in less"
fresh; unset WAYLAND_DISPLAY; printf '# Fedokawaii\n' >"$R/toolkit/docs/fedokawaii-guide.md"
fedokawaii guide; called "^less .*$R/toolkit/docs/fedokawaii-guide.md"; not_called zathura

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
case_ "plain menu: the status, twelve numbered entries; q, Q, Enter and end of input all leave"
fresh
for k in q Q "" ; do out=$(printf '%s\n' "$k" | tty_free fedokawaii 2>&1); eq "$?" 0 "[$k]"; done
out=$(tty_free fedokawaii </dev/null 2>&1); eq "$?" 0 "end of input"
has "$out" "FEDOKAWAII"; has "$out" "release  Fedora 44"; has "$out" " 1  status"; has "$out" "12  handbook"
case_ "plain menu: a number runs its entry, then the menu again"
out=$(printf '2\nq\n' | tty_free fedokawaii 2>&1)
eq "$(front_calls)" "front update"; eq "$(grep -c FEDOKAWAII <<<"$out")" 2
case_ "plain menu: a wrong answer says what is wanted, and runs nothing"
fresh; out=$(printf '0\n13\nx\n1x\n-1\n\n' | tty_free fedokawaii 2>&1)
eq "$(grep -c '1–12, or q' <<<"$out")" 5 "each of the five wrong answers"; eq "$(front_calls)" ""
case_ "plain menu on the text console: no characters the console font may lack"
fresh; out=$(printf 'q\n' | TERM=linux tty_free fedokawaii 2>&1)
lacks "$out" "·"; lacks "$out" "—"; lacks "$out" "…"; lacks "$out" "→"; has "$out" "status"
out=$(TERM=linux fedokawaii status); lacks "$out" "·"
case_ "plain menu when fzf cannot run (old fzf: exit 2) on a terminal"
if has_script; then
  fresh; stub fzf 'exit 2'
  out=$(on_tty "q"$'\n' fedokawaii); has "$out" "FEDOKAWAII"; has "$out" "12  handbook"
  case_ "fzf menu: Esc closes it (exit 0)"
  stub fzf 'cat >/dev/null; exit 130'; on_tty "" fedokawaii >/dev/null; eq "$?" 0; called '^fzf --ansi'
else _ok; fi
case_ "Super+U: the menu in a window of its own"
fresh; fedokawaii --window; called "^kawa-float --once system system 88x15 -- .*fedokawaii$"
case_ "change: the part-by-part menu"
fedokawaii change; called '^kawa-config'

done_
