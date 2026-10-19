#!/usr/bin/env bash
# tests/menus/test_steam.sh — kawa-steam closing Steam properly (--quit: Steam's own
# -shutdown, which sends the games' saves to Steam Cloud first, waited for and written to the
# journal) and its guard for the session (--guard: logind's delay lock on shutdown, the quit
# done when logind says the computer is about to stop). steam, pgrep, logger, gdbus and
# systemd-inhibit are stand-ins: the fake Steam runs while $TMP/steam-up exists and leaves
# $STEAM_TAKES seconds after it is asked to quit.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
setup() {
  menus_sandbox
  stub steam 'case "$1" in -shutdown) (sleep "${STEAM_TAKES:-0.3}"; [ -e "$TMP/steam-stays" ] || rm -f "$TMP/steam-up") >/dev/null 2>&1 & ;; esac'
  stub pgrep 'case "$*" in "-xu '"$UID"' steam") [ -e "$TMP/steam-up" ]; exit $? ;; esac; exit 1'
  stub logger; stub makoctl; stub notify-send 'echo 42'
  : >"$TMP/steam-up"
}
journal() { grep '^logger -t kawa-steam -- ' "$CALLS" | sed 's/^logger -t kawa-steam -- //'; }

case_ "--quit, Steam running: asked as its own Exit asks (steam -shutdown), waited for, the journal says how long"
setup; rc 0 kawa-steam --quit logout
called '^steam -shutdown$'
[[ ! -e $TMP/steam-up ]] && _ok || _no "returned before Steam was gone"
has "$(journal)" "asking Steam to quit (logout): it sends your saves to Steam Cloud first"
[[ $(journal | tail -n 1) =~ ^asked\ Steam\ to\ quit\ \(logout\),\ done\ in\ 0\.[0-9]\ s$ ]] && _ok || _no "the journal's last line: $(journal | tail -n 1)"
case_ "…a notice meanwhile, taken away once Steam is gone"
called '^notify-send -a desktop -p -t 0 -- .*Steam closing — your saves go to Steam Cloud first$'; called '^makoctl dismiss -n 42$'
case_ "--quit, Steam not running: nothing asked, nothing said"
setup; rm "$TMP/steam-up"; rc 0 kawa-steam --quit logout
not_called '^steam'; eq "$(journal)" ""
case_ "--quit, Steam still running after the wait: could not (1), the journal says so"
setup; : >"$TMP/steam-stays"; KAWA_STEAM_QUIT_WAIT=1 kawa-steam --quit shutdown; eq "$?" 1
eq "$(journal | tail -n 1)" "Steam still runs 1 s after it was asked to quit (shutdown) — left as it is"
case_ "the gamepad menu's quit Steam: the same proper close"
setup; answer "pick quit Steam"; kawa-steam --menu; called '^steam -shutdown$'; has "$(journal)" "(menu), done in"

case_ "--guard: a delay lock on shutdown for the session; logind's warning (PrepareForShutdown true) closes Steam, then the lock goes"
setup
stub systemd-inhibit 'while [ "${1#--}" != "$1" ]; do shift; done; exec "$@"'
stub gdbus 'printf "%s\n" "/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)" "/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForShutdown (true,)"; exec sleep 30'
rc 0 timeout 10 kawa-steam --guard
called '^systemd-inhibit --what=shutdown --mode=delay --who=Steam --why=Steam sends your saves to Steam Cloud before the computer stops .*kawa-steam --guard-wait$'
called '^gdbus monitor --system --dest org.freedesktop.login1 --object-path /org/freedesktop/login1$'
has "$(journal)" "asked Steam to quit (shutdown), done in"
[[ $(grep -c '^steam -shutdown' "$CALLS") == 1 ]] && _ok || _no "a sleep's warning closed Steam too"
case_ "…the wait for logind's word never outlives the guard"
waitfor() { local i; for ((i = 0; i < 40; i++)); do "$@" && return 0; /bin/sleep 0.05; done; return 1; }
waitfor eval '! /usr/bin/pgrep -u "$UID" -f "^sleep 30$" >/dev/null 2>&1' && _ok || _no "gdbus monitor left running"
case_ "--guard with no Steam installed: nothing held"
setup; stub systemd-inhibit; PATH=$(without steam) kawa-steam --guard; eq "$?" 0; not_called '^systemd-inhibit'

case_ "misuse (2); --help (0)"
setup; rc 2 kawa-steam --frobnicate
has "$(kawa-steam --help)" "kawa-steam --quit [WHY]"
done_
