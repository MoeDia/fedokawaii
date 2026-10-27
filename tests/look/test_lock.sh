#!/usr/bin/env bash
# tests/look/test_lock.sh — kawa-lock (Super+Escape, before sleep, the power menu), its keeper
# (gtklock started again should it ever stop without the password, the desktop locked
# meanwhile) and the idle chain autostart.sh sets up: the screensaver and the lock at 15 min, the screens off at 30, nothing
# else. gtklock is a stand-in that keeps its arguments and environment, runs its
# --lock-command (the moment a real one has locked every screen) and runs on as the lock does:
# until "$TMP/unlock" is there (the password) or SIGTERM (gtklock's own way out), both a clean
# exit; SIGKILL stands for a crash. The journal lines are logger's (a stand-in).
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
need python3 flock setsid

# the stand-in gtklock's body (sh): its environment and inherited locks noted, the lock taken,
# then running until unlocked (BODY_PRE runs first: a gate, a crash at start…)
FAKE_LOCK='echo "LANGUAGE=$LANGUAGE LC_TIME=$LC_TIME" >>"$FAKE_TMP/gtklock.env"
[ -e /proc/$$/fd/9 ] && echo "busy lock held" >>"$FAKE_TMP/fd9"
[ -e /proc/$$/fd/8 ] && echo "keeper lock held" >>"$FAKE_TMP/fd8"
trap "exit 0" TERM
echo "gtklock $$" >>"$FAKE_PROCS"
while [ $# -gt 0 ]; do [ "$1" = --lock-command ] && sh -c "$2"; shift; done
while [ ! -e "$FAKE_TMP/unlock" ]; do /bin/sleep 0.05; done
exit 0'
setup() {
  look
  config .config/fedokawaii/lock.ui .local/share/fedokawaii/dark .local/share/fedokawaii/light
  SHARE=$HOME/.local/share/fedokawaii CSS=$HOME/.config/fedokawaii/current/gtklock.css
  UI=$XDG_RUNTIME_DIR/kawa-lock.ui
  argv gtklock "$FAKE_LOCK"
  argv wlopm
  stub logger
  MOD=$HOME/.local/lib/fedokawaii/kawa-lockmod.so   # (theme.sh builds it: src/kawa-lockmod)
  mkdir -p "${MOD%/*}"; : >"$MOD"
  # pkill -xu UID gtklock: this sandbox's stand-ins only (SIGTERM, as the real one sends)
  stub pkill 'while read -r n p; do [ "$n" = gtklock ] && kill "$p" 2>/dev/null; done <"$FAKE_PROCS"'
  daemon dwl >/dev/null                             # the desktop runs
  # shellcheck source=/dev/null
  . "$HOME/.config/fedokawaii/icons.sh"
}
locks() { grep -c '^gtklock' "$CALLS"; }              # (counted safely when two run at once)
waitfor() { local i; for i in {1..50}; do eval "$1" && return 0; /bin/sleep 0.1; done; return 1; }
lastlock() { awk '$1 == "gtklock" { p = $2 } END { print p }' "$FAKE_PROCS"; }   # the newest gtklock's pid
keeping() { ! flock -n "$XDG_RUNTIME_DIR/kawa-lock.held" true; }                 # the keeper runs
said() { grep -E "^logger -t kawa-lock -- $1" "$CALLS"; }
unlock() { : >"$TMP/unlock"; waitfor '! keeping'; rm -f "$TMP/unlock"; }       # the password

# ── a lock ───────────────────────────────────────────────────────────────────
setup
case_ "Super+Escape: gtklock with the theme's stylesheet and the layout, the date in English, the desktop's words"
rc 0 kawa-lock
eq "$(locks)" 1
args_eq gtklock 1 -s "$CSS" -x "$UI" -m "$MOD" --date-format '%a %d %b' --time-format '%I:%M' --lock-command "kawa-lock --up"
eq "$(cat "$TMP/gtklock.env")" "LANGUAGE=fk LC_TIME=C" "LANGUAGE=fk (ちがう · wrong password), LC_TIME=C"
[[ ! -e $TMP/fd9 ]] && _ok || _no "gtklock keeps kawa-lock's lock: every later call would wait"
[[ ! -e $TMP/fd8 ]] && _ok || _no "gtklock keeps its keeper's lock: the desktop would look locked after the password"
case_ "… it runs under its keeper, and the journal says the lock is up"
keeping && _ok || _no "no keeper holds the lock"
[[ -e $XDG_RUNTIME_DIR/kawa-lock.locked ]] && _ok || _no "not marked locked"
called '^logger -t kawa-lock -- lock up$'
case_ "the password: gtklock ends well, the keeper with it — unlocked, said so, and the next press locks anew"
unlock
called '^logger -t kawa-lock -- unlocked$'
[[ ! -e $XDG_RUNTIME_DIR/kawa-lock.locked ]] && _ok || _no "still marked locked after the password"
rc 0 kawa-lock; eq "$(locks)" 2 "a new lock"; unlock

case_ "the layout: today's seal and the theme's padlock filled in, every id gtklock reads present"
day=$(date +%u)
has "$(cat "$UI")" "$SHARE/dark/seal-$day.png"
has "$(cat "$UI")" "$SHARE/dark/padlock.png"
lacks "$(cat "$UI")" "{SEAL}"
for f in "$SHARE/dark/seal-$day.png" "$SHARE/dark/padlock.png"; do [[ -s $f ]] && _ok || _no "missing $f"; done
for id in window-box info-box time-box clock-label date-label body-revealer body-grid input-label input-field \
          message-revealer message-scrolled-window message-box unlock-button error-label warning-label; do
  grep -q "id=\"$id\"" "$UI" && _ok || _no "the layout has no $id"
done
python3 -c 'import sys, xml.dom.minidom as m; m.parse(sys.argv[1])' "$UI" && _ok || _no "the layout is not well-formed XML"
grep -q '<property name="invisible-char">◆</property>' "$UI" && _ok || _no "the box's dots are not ◆ (GtkBuilder reads a gunichar as the character itself)"

case_ "the light theme: its own stylesheet link and pictures"
setup
ln -sfn themes/light "$HOME/.config/fedokawaii/current"
kawa-lock --now
has "$(cat "$UI")" "$SHARE/light/padlock.png"
args_eq gtklock 1 -s "$CSS" -x "$UI" -m "$MOD" --date-format '%a %d %b' --time-format '%I:%M' --lock-command "kawa-lock --up"

case_ "already locked (a second press, idle while locked): nothing more"
setup
kawa-lock --now
rc 0 kawa-lock; rc 0 kawa-lock --now
eq "$(locks)" 1

case_ "two at once (a double press while the first is still starting): one lock"
setup
argv gtklock "$(wait_gate gtklock)
$FAKE_LOCK"
gate gtklock
kawa-lock & a=$!
at_gate gtklock || _no "the first never started gtklock"
kawa-lock & b=$!
/bin/sleep 0.3
eq "$(locks)" 1 "the second waits for the first"
open_gate gtklock
wait "$a"; ra=$?; wait "$b"; rb=$?
eq "$ra$rb" 00
eq "$(locks)" 1 "one gtklock"

case_ "a held key (20 presses in a row): one lock"
setup
for _ in {1..20}; do kawa-lock --now; done
eq "$(locks)" 1

# ── the keeper: the lock holds whatever happens to gtklock ──────────────────────
case_ "gtklock crashing while locked (a screen gone as the machine slept): started again at once, the desktop locked all along"
setup
kawa-lock; first=$(lastlock)
kill -KILL "$first"
waitfor '(( $(locks) == 2 ))' || _no "gtklock was not started again"
waitfor 'said "lock up" | sed -n 2p | grep -q .' || _no "the second gtklock did not lock"
keeping && _ok || _no "the keeper is gone: the desktop would sit locked with no lock screen"
[[ -e $XDG_RUNTIME_DIR/kawa-lock.locked ]] && _ok || _no "no longer marked locked"
called '^logger -t kawa-lock -- locker exited rc=137 — the desktop stays locked: started again$'
case_ "… a press meanwhile finds it locked (no second lock), and the password still ends it"
rc 0 kawa-lock; eq "$(locks)" 2
unlock; called '^logger -t kawa-lock -- unlocked$'
case_ "gtklock crashing again and again: started again each time, never faster than once a second"
setup
argv gtklock 'echo "gtklock $$" >>"$FAKE_PROCS"
while [ $# -gt 0 ]; do [ "$1" = --lock-command ] && sh -c "$2"; shift; done
n=$(cat "$FAKE_TMP/n" 2>/dev/null || echo 0); echo $((n + 1)) >"$FAKE_TMP/n"
[ "$n" -lt 3 ] && kill -KILL $$
while [ ! -e "$FAKE_TMP/unlock" ]; do /bin/sleep 0.05; done'
start=$SECONDS; rc 0 kawa-lock
for _ in {1..150}; do (( $(locks) >= 4 )) && break; /bin/sleep 0.1; done   # (three pauses of a second: up to 15 s on a busy machine)
(( $(locks) >= 4 )) || _no "not started again each time: $(locks)"
/bin/sleep 0.5; eq "$(locks)" 4 "four starts: the crash, two more, the one that holds"
keeping && _ok || _no "the keeper gave up"
((SECONDS - start >= 2)) && _ok || _no "restarted in a busy loop"
unlock
case_ "gtklock gone because the desktop has ended (dwl gone): the keeper ends too, nothing started again"
setup
kawa-lock; pid=$(awk '$1 == "dwl" { print $2 }' "$FAKE_PROCS"); kill "$pid"
kill -KILL "$(lastlock)"
waitfor '! keeping' || _no "the keeper outlived the desktop"
eq "$(locks)" 1
called '^logger -t kawa-lock -- locker exited rc=137 — the desktop has ended$'

case_ "the machine wakes (swayidle's after-resume): the screens lit, the journal says whether it is locked"
setup
rc 0 kawa-lock --resumed; called '^logger -t kawa-lock -- resumed — not locked$'
args_eq wlopm 1 --on '*'; eq "$(cat "$XDG_RUNTIME_DIR/kawa-screens")" on "the lock screen's note: lit"
kawa-lock --now; reset_calls
rc 0 kawa-lock --resumed; called '^logger -t kawa-lock -- resumed — locked$'
eq "$(locks)" 0 "it only looks: it never locks"

# ── the screens: dark before a sleep's lock, and the note the lock screen's wake guard reads ──
case_ "--now (before every sleep): the screens go dark first, then the lock comes up on them — no lock shows before the sleep"
setup
rc 0 kawa-lock --now
eq "$(grep -E '^(wlopm|gtklock)' "$CALLS" | cut -d' ' -f1-2 | tr '\n' '|')" "wlopm --off|gtklock -s|" "dark, then locked"
eq "$(cat "$XDG_RUNTIME_DIR/kawa-screens")" off "the note says dark (the lock screen only wakes at a key)"
called '^logger -t kawa-lock -- screens off$'
case_ "… a plain lock (Super+Escape) stays in sight: the screens untouched"
setup; rc 0 kawa-lock; not_called '^wlopm'
case_ "--screens off|on: wlopm, and the note written before they go dark and after they are lit"
setup
argv wlopm 'echo "note: $(cat "$XDG_RUNTIME_DIR/kawa-screens" 2>/dev/null)" >>"$FAKE_TMP/notes"'
rc 0 kawa-lock --screens off; rc 0 kawa-lock --screens on
args_eq wlopm 1 --off '*'; args_eq wlopm 2 --on '*'
eq "$(tr '\n' '|' <"$TMP/notes")" "note: off|note: off|" "off before the dark; on only once lit"
eq "$(cat "$XDG_RUNTIME_DIR/kawa-screens")" on
rc 2 kawa-lock --screens; rc 2 kawa-lock --screens dim
case_ "the module (the keys, the wake guard) missing: it still locks, and says what to repair"
setup; rm "$MOD"
rc 0 kawa-lock; eq "$(locks)" 1
called "notify-send -a desktop -u critical -- .*lock screen .*kawa-lockmod.so.*fedokawaii repair"
case_ "autostart clears the note at login (a session that ended in the dark leaves none behind)"
grep -q '"$XDG_RUNTIME_DIR/kawa-screens"' "$REPO/configs/home/.config/dwl/autostart.sh" && _ok || _no "kawa-screens is not cleared at login"

# ── kawa-lockmod: the wake guard and the keys (built here with GTK 3's headers, if present) ──
case_ "the wake guard: dark, and 2 s after the screens are lit, keys and clicks only wake; a stale dark holds 2 s"
if command -v cc >/dev/null && pkg-config --exists gtk+-3.0 2>/dev/null; then
  cat >"$TMP/guard.c" <<'EOF'
#include "kawa-lockmod.c"
#include <stdio.h>
#include <utime.h>
static void note(const char *s, long ago_s) {
	FILE *f = fopen(screens, "w"); fputs(s, f); fclose(f);
	struct utimbuf t = { time(NULL) - ago_s, time(NULL) - ago_s }; utime(screens, &t);
}
int main(void) {
	on_activation(NULL, 0);
	printf("none %d|", guarded());
	note("off\n", 3600); printf("dark %d %d|", guarded(), guarded());
	note("on\n", 0); printf("just lit %d|", guarded());
	note("on\n", 3); printf("lit 3 s ago %d|", guarded());
	note("off\n", 7200); printf("stale dark %d, ", guarded());
	off_first -= 3 * G_USEC_PER_SEC; printf("3 s on %d|", guarded());
	note("off\n", 10); printf("dark anew %d|", guarded());
	return 0;
}
EOF
  # (the module's own source, with GTK's headers; only its guard runs: no display needed)
  # shellcheck disable=SC2046  # (pkg-config's words)
  if cc -std=gnu11 -I"$REPO/src/kawa-lockmod" $(pkg-config --cflags gtk+-3.0) -o "$TMP/guard" "$TMP/guard.c" $(pkg-config --libs gtk+-3.0) 2>"$TMP/cc.log"; then
    eq "$(XDG_RUNTIME_DIR=$TMP "$TMP/guard")" "none 0|dark 1 1|just lit 1|lit 3 s ago 0|stale dark 1, 3 s on 0|dark anew 1|"
  else _no "kawa-lockmod.c does not build: $(head -n 3 "$TMP/cc.log")"; fi
else echo "  (no cc or GTK 3 headers here: the guard's run skipped)"; fi
case_ "kawa-lockmod: an empty Enter is no try; every key, release and click passes the guard; theme.sh builds it"
L=$REPO/src/kawa-lockmod/kawa-lockmod.c
grep -q 'gtk_entry_get_text_length(GTK_ENTRY(win->input_field)) == 0' "$L" && _ok || _no "the empty Enter"
for e in key-press-event key-release-event button-press-event button-release-event; do
  grep -q "\"$e\"" "$L" && _ok || _no "$e does not pass the guard"
done
grep -q 'module_major_version = 4;' "$L" && _ok || _no "not a gtklock 4 module"
grep -q 'TOOLS=(.*kawa-lockmod' "$REPO/theme.sh" && _ok || _no "theme.sh does not build it"

# ── a lock you asked for: sleep 90 s later ─────────────────────────────────────
case_ "Super+Escape (--sleep): locked, and still locked when the time is up — the computer sleeps"
setup; stub systemctl
KAWA_LOCK_SLEEP=1 kawa-lock --sleep; r=$?
eq "$r" 0; eq "$(locks)" 1
waitfor 'grep -q "^systemctl suspend" "$CALLS"'
called '^systemctl suspend$'
called '^logger -t kawa-lock -- still locked after 1 s: sleep$'
case_ "--sleep, unlocked before the time is up: it stays awake"
setup; stub systemctl
KAWA_LOCK_SLEEP=2 kawa-lock --sleep
unlock
/bin/sleep 3
not_called '^systemctl suspend'
case_ "--sleep: gtklock crashing and started again meanwhile is still the same lock — the computer sleeps"
setup; stub systemctl
KAWA_LOCK_SLEEP=2 kawa-lock --sleep
kill -KILL "$(lastlock)"
waitfor 'grep -q "^systemctl suspend" "$CALLS"' || _no "no sleep after a restarted gtklock"
case_ "--sleep: 90 s unless KAWA_LOCK_SLEEP says otherwise (0: never); --now and a plain lock never sleep"
grep -q 'sleep_after=90' "$REPO/bin/kawa-lock" && _ok || _no "the default is not 90 s"
setup; stub systemctl
KAWA_LOCK_SLEEP=0 kawa-lock --sleep; /bin/sleep 1.5; not_called '^systemctl'
setup; stub systemctl
KAWA_LOCK_SLEEP=1 kawa-lock --now; /bin/sleep 1.5; not_called '^systemctl'
setup; stub systemctl
KAWA_LOCK_SLEEP=1 kawa-lock; /bin/sleep 1.5; not_called '^systemctl'
case_ "the key and the power menu's lock ask for it (--sleep); the power menu's sleep and the Sleep key do not wait"
grep -q 'XKB_KEY_Escape, *spawn, *SHCMD("kawa-lock --sleep")' "$REPO/src/dwl/config.h" && _ok || _no "Super+Escape"
grep -q '1) exec kawa-lock --sleep ;;' "$REPO/bin/kawa-power" && _ok || _no "power menu lock"
grep -q '2) sleep_now ;;' "$REPO/bin/kawa-power" && _ok || _no "power menu sleep"
grep -q 'sleep) sleep_now; exit ;;' "$REPO/bin/kawa-power" && _ok || _no "the Sleep key (kawa-power sleep)"
grep -q 'kawa-lock --now || ' "$REPO/bin/kawa-power" && _ok || _no "kawa-power sleeps only once kawa-lock has locked (on dark screens)"

# ── when it cannot lock: said, and never a sleep unlocked ───────────────────────
case_ "gtklock missing: says so (a notice too) and fails, so the power menu does not suspend"
setup
hide gtklock
out=$(kawa-lock 2>&1); r=$?
eq "$r" 1
has "$out" "gtklock is not installed"
called "^notify-send -a desktop -u critical -- $ICON_LOCK  could not lock the screen"
called '^logger -t kawa-lock -- could not lock: gtklock is not installed'
case_ "gtklock stopping before it locks (a crash at start): failed within about a second, not 10 — and not started again"
setup; stub systemctl
argv gtklock 'exit 1'
start=$SECONDS; KAWA_LOCK_SLEEP=1 kawa-lock --sleep; r=$?; took=$((SECONDS - start))
eq "$r" 1
((took <= 3)) && _ok || _no "it waited $took s for a gtklock that had stopped"
/bin/sleep 1.5; not_called '^systemctl'
has "$(grep notify-send "$CALLS")" "gtklock stopped before it locked"
eq "$(locks)" 1 "a gtklock that never locked is not started again"
called '^logger -t kawa-lock -- locker exited rc=1 before it locked$'
case_ "gtklock running but never locking: given up after 10 s, failed (kawa-lock && suspend would not suspend)"
setup
argv gtklock 'trap "exit 0" TERM; echo "gtklock $$" >>"$FAKE_PROCS"; while :; do /bin/sleep 0.05; done'
out=$( { kawa-lock && echo suspended; } 2>/dev/null)
eq "$out" "" "a lock that never came does not suspend"
waitfor '! keeping' || _no "its keeper stayed"
eq "$(locks)" 1
case_ "the layout missing: it still locks (plain: gtklock's own look) and says what to repair — a sleep never finds it unlocked"
setup
rm "$HOME/.config/fedokawaii/lock.ui"
out=$(kawa-lock 2>&1); r=$?
eq "$r" 0; eq "$(locks)" 1; called 'notify-send .*lock screen .*lock.ui.*fedokawaii repair'
lacks "$(grep "^gtklock" "$CALLS")" " -x "

case_ "HOME with a space: the stylesheet and picture paths arrive whole"
setup
mkdir -p "$TMP/my home"; cp -a "$HOME/." "$TMP/my home/"; export HOME="$TMP/my home"
kawa-lock --now
args_eq gtklock 1 -s "$HOME/.config/fedokawaii/current/gtklock.css" -x "$UI" -m "$HOME/.local/lib/fedokawaii/kawa-lockmod.so" --date-format '%a %d %b' --time-format '%I:%M' --lock-command "kawa-lock --up"
has "$(cat "$UI")" "$HOME/.local/share/fedokawaii/dark/padlock.png"

case_ "--help shows how it is used"
setup
out=$(kawa-lock --help 2>&1); r=$?
eq "$r" 0; has "$out" "kawa-lock --now"; has "$out" "journalctl -t kawa-lock"
eq "$(locks)" 0 "--help does not lock"

# ── the idle chain (autostart.sh's swayidle line) ─────────────────────────────
# swayidle here: runs each timeout's command in order (as sh -c, which is bash on Fedora),
# then the screens' resume, then before-sleep — the order an idle hour and a suspend give
idle() {   # idle — autostart.sh's own swayidle arguments, played through
  local block
  block=$(sed -n '/^keep swayidle/,/<\/dev\/null &$/p' "$REPO/configs/home/.config/dwl/autostart.sh" | sed 's|</dev/null &$||')
  [[ -n $block ]] || { _no "no swayidle line in autostart.sh"; return; }
  keep() { "$@"; }
  swayidle() {
    local t=() c=() r=() bs="" ar="" i
    while (($#)); do
      case $1 in
        -w) shift ;;
        timeout) t+=("$2") c+=("$3"); r+=(""); shift 3
                 [[ ${1:-} == resume ]] && { r[${#r[@]} - 1]=$2; shift 2; } ;;
        before-sleep) bs=$2; shift 2 ;;
        after-resume) ar=$2; shift 2 ;;
        *) _no "swayidle: unknown argument $1"; return ;;
      esac
    done
    printf '%s\n' "${t[@]}" >"$TMP/idle.times"
    for i in "${!t[@]}"; do echo "idle ${t[i]}s" >>"$CALLS"; bash -c "${c[i]}"; done
    for i in "${!t[@]}"; do [[ -n ${r[i]} ]] && { echo "resume" >>"$CALLS"; bash -c "${r[i]}"; }; done
    [[ -n $bs ]] && { echo "before-sleep" >>"$CALLS"; bash -c "$bs"; }
    [[ -n $ar ]] && { echo "after-resume" >>"$CALLS"; bash -c "$ar"; }
  }
  eval "$block"
  unset -f keep swayidle
}
case_ "away: 15 min the screensaver and the lock behind it, 30 min the screens dark; nothing sleeps"
setup
argv kawa-saver
argv notify-send
stub playerctl; stub systemd-inhibit                # (nothing playing, nothing holding idle)
idle
eq "$(tr '\n' ' ' <"$TMP/idle.times")" "900 1800 " "15 minutes, then 30"
called '^kawa-saver --idle$' "15 min: the screensaver, the lock behind it (kawa-saver --idle)"
eq "$(locks)" 1 "locked only for the sleep (below) here: the stand-in screensaver never locks"
not_called '^systemctl'
args_eq wlopm 1 --off '*'
args_eq wlopm 2 --on '*'
args_eq wlopm 3 --off '*'
args_eq wlopm 4 --on '*'
eq "$(grep -E '^(idle|kawa-saver|resume|before|after|notify|gtklock|wlopm)' "$CALLS" | cut -d' ' -f1-2 | tr '\n' '|')" \
  "idle 900s|kawa-saver --idle|idle 1800s|wlopm --off|resume|resume|wlopm --on|before-sleep|wlopm --off|gtklock -s|after-resume|wlopm --on|" \
  "screensaver, screens off, on again at a key; before a sleep: dark, then locked; awake again: the screens on, said"
called '^logger -t kawa-lock -- resumed — locked$' "the wake in the journal, the lock still up"
case_ "a suspend while unlocked: locked at once before the machine sleeps"
setup
idle_bs=$(sed -n "s/^  before-sleep '\(.*\)' <\/dev\/null &\$/\1/p" "$REPO/configs/home/.config/dwl/autostart.sh")
eq "$idle_bs" "kawa-lock --now"
bash -c "$idle_bs"
eq "$(locks)" 1
[[ -e $XDG_RUNTIME_DIR/kawa-lock.locked ]] && _ok || _no "not locked before the sleep"
case_ "the machine awake again: swayidle's after-resume tells the journal (the health report reads it)"
grep -qF "  after-resume 'kawa-lock --resumed' \\" "$REPO/configs/home/.config/dwl/autostart.sh" && _ok || _no "no after-resume line"

case_ "the password's line: each ◆ at 28 px (Sumi UI at twice its pixels), 8 px apart, no caret; the hint a 14 px label of its own over the empty line (lock and login alike)"
for t in dark light; do
  c=$(sed -n '/^#input-field {/,/^}/p' "$REPO/configs/home/.config/fedokawaii/themes/$t/gtklock.css")
  has "$c" "font-size: 28px;" "$t"; has "$c" "letter-spacing: 8px;" "$t"; has "$c" "caret-color: transparent;" "$t"
  grep -q '^#input-label, #input-hint { color: #' "$REPO/configs/home/.config/fedokawaii/themes/$t/gtklock.css" && _ok || _no "$t: the hint's ink"
done
m=$(sed -n '/^static void hint_add/,/^}/p' "$REPO/src/kawa-lockmod/kawa-lockmod.c")
has "$m" 'gtk_overlay_set_overlay_pass_through(GTK_OVERLAY(ov), hint, TRUE);' "clicks reach the line"
has "$m" 'gtk_entry_set_placeholder_text(GTK_ENTRY(entry), NULL);' "the entry's own placeholder (it would grow) gone"
has "$m" 'g_signal_connect(entry, "changed", G_CALLBACK(hint_update), hint);'
has "$(sed -n '/^void on_window_create/,/^}/p' "$REPO/src/kawa-lockmod/kawa-lockmod.c")" "hint_add(win->input_field);"
g=$(cat "$REPO/system/kawa-greet")
has "$g" 'hint = Gtk.Label(name="input-hint"'; has "$g" 'line.set_overlay_pass_through(hint, True)'; lacks "$g" "placeholder_text=" "the login screen's twin"
done_
