#!/usr/bin/env bash
# tests/look/test_theme.sh — kawa-theme: the two themes, switched by re-pointing one link and
# telling whatever runs to look again. The running apps are real processes of this test
# (python ones that catch SIGUSR1/2 like foot, waybar and btop do); gsettings keeps its keys
# in a file, the transition (kawa-veil) just runs the switch, mako and D-Bus are stand-ins.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
need python3 flock

setup() {
  look
  unset WAYLAND_DISPLAY KAWA_VEILED
  DIR=$HOME/.config/fedokawaii LINK=$HOME/.config/fedokawaii/current
  export GS=$TMP/gsettings; : >"$GS"
  # gsettings get/set org.gnome.desktop.interface KEY [VALUE] — kept in $GS (KEY=VALUE)
  stubf gsettings <<'EOF'
[ -e "$FAKE_TMP/gate.gs.use" ] && { echo $$ >"$FAKE_TMP/gs.pid"; : >"$FAKE_TMP/gate.gs.in"; while [ ! -e "$FAKE_TMP/gate.gs" ]; do /bin/sleep 0.02; done; }
case $1 in
  get) printf "'%s'\n" "$(sed -n "s/^$3=//p" "$GS")" ;;
  set) grep -v "^$3=" "$GS" >"$GS.n"; echo "$3=$4" >>"$GS.n"; mv "$GS.n" "$GS" ;;
esac
EOF
  stub makoctl; stub busctl
  # the wallpaper: which of the switch's lock descriptors (7, 9) it was handed
  stubf kawa-wallpaper <<'EOF'
o=""; for fd in 7 8 9; do [ -e /proc/$$/fd/$fd ] && o="$o $fd"; done
echo "fds:$o" >>"$FAKE_TMP/wallpaper.fds"
EOF
}
veil() {   # veil — the transition is installed: it runs the switch, then notes it is over
  stubf kawa-veil <<'EOF'
while [ $# -gt 0 ] && [ "$1" != "--" ]; do shift; done; shift
[ -e "$FAKE_TMP/gate.veil.use" ] && { : >"$FAKE_TMP/gate.veil.in"; while [ ! -e "$FAKE_TMP/gate.veil" ]; do /bin/sleep 0.02; done; }
"$@"; r=$?
echo "veil over" >>"$FAKE_TMP/calls.log"
exit $r
EOF
}
theme_is() {   # theme_is dark|light — the link, GTK and the icons all say so
  local m=$1 g=Fedokawaii i=Papirus
  [[ $m == dark ]] && g=Fedokawaii-dark i=Papirus-Dark
  eq "$(readlink "$LINK")" "themes/$m" "the link points to themes/$m"
  eq "$(kawa-theme get)" "$m"
  has "$(cat "$GS")" "color-scheme=prefer-$m" "GTK 4 / libadwaita: prefer-$m"
  has "$(cat "$GS")" "gtk-theme=$g" "GTK 3: $g"
  has "$(cat "$GS")" "icon-theme=$i" "icons: $i"
}
sets() { grep -c '^gsettings set' "$CALLS"; }
presses() {   # presses N — N more presses at once, each noting its exit status in $TMP/press.I
  local i; rm -f "$TMP"/press.*
  for ((i = 1; i <= $1; i++)); do ( kawa-theme >/dev/null 2>&1; echo $? >"$TMP/press.$i" ) & done
}
codes() {   # codes N — the N presses' exit statuses, once all have ended (10 s at most: a press
  local i n c=""                  # held back instead of dropped shows as a missing digit)
  for _ in {1..500}; do n=$(find "$TMP" -maxdepth 1 -name 'press.*' -size +0 | wc -l); ((n >= $1)) && break; /bin/sleep 0.02; done
  for ((i = 1; i <= $1; i++)); do c+=$(cat "$TMP/press.$i" 2>/dev/null); done
  printf '%s' "$c"
}

# ── the commands ─────────────────────────────────────────────────────────────
setup
case_ "a fresh install: dark, and get says so"
eq "$(kawa-theme get)" dark
rc 0 kawa-theme get

case_ "light, dark, then toggle twice: each one switches the link, GTK and the icons"
rc 0 kawa-theme light; theme_is light
rc 0 kawa-theme dark;  theme_is dark
rc 0 kawa-theme;       theme_is light
rc 0 kawa-theme toggle; theme_is dark

case_ "the current theme set again: nothing changes, and it is safe to repeat"
reset_calls
rc 0 kawa-theme dark; rc 0 kawa-theme dark
theme_is dark
eq "$(sets)" 0 "GTK already right: not written again"
rc 0 kawa-theme apply; theme_is dark

case_ "--help shows how to use it; a wrong word is a usage error"
out=$(kawa-theme --help 2>&1); r=$?
eq "$r" 0 "--help exits 0"
has "$out" "kawa-theme dark|light"
out=$(kawa-theme purple 2>&1); r=$?
eq "$r" 2 "a wrong word exits 2"
has "$out" "usage: kawa-theme"
theme_is dark

case_ "settings alone: GTK and icons only, the link stays"
setup
rc 0 kawa-theme settings
eq "$(readlink "$LINK")" themes/dark
has "$(cat "$GS")" "color-scheme=prefer-dark"

# ── the running apps ─────────────────────────────────────────────────────────
case_ "foot, waybar and btop are told: foot USR2 for light, USR1 for dark; waybar and btop USR2"
setup
read -r foot footlog < <(catcher foot USR1 USR2)
read -r _ barlog < <(catcher waybar USR2)
read -r _ btoplog < <(catcher btop USR2)
kawa-theme light
eq "$(got "$footlog" 1)" SIGUSR2 "foot: the light palette"
eq "$(got "$barlog" 1)" SIGUSR2 "waybar reloads its style"
eq "$(got "$btoplog" 1)" SIGUSR2 "btop reloads its theme"
kawa-theme dark
eq "$(got "$footlog" 2 | tail -n1)" SIGUSR1 "foot: the dark palette"

case_ "an app that does not catch the signal yet (just starting) is left alone, not killed"
read -r young _ < <(catcher foot)
read -r halfbar _ < <(catcher waybar USR1)
kawa-theme light; /bin/sleep 0.5        # (time for a wrongly signalled one to die)
alive "$young" && _ok || _no "a foot without its handler yet was killed by SIGUSR2"
alive "$halfbar" && _ok || _no "a waybar catching only USR1 was killed by SIGUSR2"
alive "$foot" && _ok || _no "the ready foot is gone"

case_ "mako running: makoctl reload; mako not running: makoctl is never called (it would start one)"
setup
daemon mako >/dev/null
kawa-theme light
called '^makoctl reload'
setup
kawa-theme light
not_called '^makoctl'

case_ "a failing makoctl, gsettings or busctl: the switch still completes, quietly"
setup
daemon mako >/dev/null; daemon zathura >/dev/null
stub makoctl 'echo "garbage" >&2; exit 1'
stub busctl 'echo "Call failed" >&2; exit 1'
stub gsettings 'echo "No schemas installed" >&2; exit 1'
err=$(kawa-theme light 2>&1 >/dev/null); r=$?
eq "$r" 0
eq "$err" "" "nothing on stderr"
eq "$(readlink "$LINK")" themes/light

case_ "no gsettings at all: the switch still completes; settings alone says it could not"
setup
hide gsettings
rc 0 kawa-theme light
eq "$(readlink "$LINK")" themes/light
rc 1 kawa-theme settings

case_ "zathura: each one re-reads its config over D-Bus"
setup
z=$(daemon zathura)
kawa-theme light
called "^busctl --user call org.pwmt.zathura.PID-$z /org/pwmt/zathura org.pwmt.zathura SourceConfig"

case_ "Qt: a qt6ct.conf link is replaced (qt6ct watches it); your own file is left alone"
setup
mkdir -p "$HOME/.config/qt6ct"
ln -s ../fedokawaii/current/qt6ct.conf "$HOME/.config/qt6ct/qt6ct.conf"
ino=$(stat -c %i "$HOME/.config/qt6ct/qt6ct.conf")
kawa-theme light
eq "$(readlink "$HOME/.config/qt6ct/qt6ct.conf")" ../fedokawaii/current/qt6ct.conf
[[ $(stat -c %i "$HOME/.config/qt6ct/qt6ct.conf") != "$ino" ]] && _ok || _no "the link was not replaced (qt6ct would not notice)"
rm "$HOME/.config/qt6ct/qt6ct.conf"; echo "mine" >"$HOME/.config/qt6ct/qt6ct.conf"
kawa-theme dark
eq "$(cat "$HOME/.config/qt6ct/qt6ct.conf")" mine

case_ "mpv: an open player is told to load the new colours; a crashed one's socket is cleared"
setup
python3 -I -c '
import socket, sys, os
s = socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(1); s.settimeout(10)
open(sys.argv[2] + ".up", "w").close()
c, _ = s.accept(); data = c.recv(4096)
open(sys.argv[2], "wb").write(data)' "$XDG_RUNTIME_DIR/mpv-111.sock" "$TMP/mpv.got" "$TMP" &
mpv=$!
for _ in {1..300}; do [[ -e $TMP/mpv.got.up ]] && break; /bin/sleep 0.01; done
python3 -I -c 'import socket, sys; s = socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])' "$XDG_RUNTIME_DIR/mpv-222.sock"
echo "not a socket" >"$XDG_RUNTIME_DIR/mpv-333.sock"
kawa-theme light
wait "$mpv"
has "$(cat "$TMP/mpv.got")" "{\"command\": [\"load-config-file\", \"$DIR/themes/light/mpv.conf\"]}"
[[ ! -e $XDG_RUNTIME_DIR/mpv-222.sock ]] && _ok || _no "a crashed player's socket was kept"
[[ -e $XDG_RUNTIME_DIR/mpv-333.sock ]] && _ok || _no "a file that is no socket was removed"

case_ "mpv in Syncplay (its own socket): told too; a dead one of Syncplay's is left to Syncplay"
setup
mkdir -p "$XDG_RUNTIME_DIR/syncplay-ab12" "$XDG_RUNTIME_DIR/syncplay-cd34"
python3 -I -c '
import socket, sys
s = socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(1); s.settimeout(10)
open(sys.argv[2] + ".up", "w").close()
c, _ = s.accept(); open(sys.argv[2], "wb").write(c.recv(4096))' "$XDG_RUNTIME_DIR/syncplay-ab12/mpv-socket" "$TMP/sp.got" &
mpv=$!
for _ in {1..300}; do [[ -e $TMP/sp.got.up ]] && break; /bin/sleep 0.01; done
python3 -I -c 'import socket, sys; s = socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])' "$XDG_RUNTIME_DIR/syncplay-cd34/mpv-socket"
kawa-theme light
wait "$mpv"
has "$(cat "$TMP/sp.got")" "{\"command\": [\"load-config-file\", \"$DIR/themes/light/mpv.conf\"]}"
[[ -S $XDG_RUNTIME_DIR/syncplay-cd34/mpv-socket ]] && _ok || _no "Syncplay's socket was removed"

case_ "while the screen is locked: the switch happens, the lock screen is not touched"
setup
read -r lockpid locklog < <(catcher swaylock USR1 USR2)
rc 0 kawa-theme light
theme_is light
eq "$(cat "$locklog" 2>/dev/null)" "" "swaylock got no signal"
alive "$lockpid" && _ok || _no "swaylock is gone"

# ── in a session: the transition and the wallpaper ──────────────────────────
case_ "in a session: the switch runs under the veil — rising to light, falling to dark"
setup; veil; export WAYLAND_DISPLAY=wayland-1
kawa-theme light
called '^kawa-veil --rise -- .*kawa-theme light$'
theme_is light
kawa-theme dark
called '^kawa-veil --fall -- .*kawa-theme dark$'

case_ "under the veil, the theme's wallpaper is up before the reveal — and holds neither lock"
eq "$(grep -E '^(kawa-wallpaper|veil over)' "$CALLS" | tail -n 2 | tr '\n' '|')" "kawa-wallpaper --restore|veil over|"
eq "$(sort -u "$TMP/wallpaper.fds")" "fds:" "no lock descriptor reaches the wallpaper (its swaybg lives on)"

case_ "the same theme again in a session: no transition (nothing to see), just re-applied"
reset_calls
kawa-theme dark
not_called '^kawa-veil'
for _ in {1..250}; do grep -q '^kawa-wallpaper' "$CALLS" && break; /bin/sleep 0.02; done   # (in the background)
called '^kawa-wallpaper --restore'

case_ "a session without the transition built: switched directly, the wallpaper follows"
setup; export WAYLAND_DISPLAY=wayland-1
rc 0 kawa-theme light
for _ in {1..250}; do [[ -s $TMP/wallpaper.fds ]] && break; /bin/sleep 0.02; done   # (in the background)
called '^kawa-wallpaper --restore'
eq "$(sort -u "$TMP/wallpaper.fds")" "fds:" "no lock descriptor reaches the wallpaper"
theme_is light

case_ "outside a session (theme.sh, SSH): no veil and no wallpaper (there is no screen)"
setup; veil
rc 0 kawa-theme light
not_called '^kawa-veil'; not_called '^kawa-wallpaper'

# ── one at a time ────────────────────────────────────────────────────────────
case_ "15 presses while a transition runs (a held key): exactly one switch, the rest dropped"
setup; veil; export WAYLAND_DISPLAY=wayland-1
: >"$TMP/gate.veil.use"
kawa-theme & first=$!
at_gate veil || _no "the first switch never reached the veil"
presses 14
eq "$(codes 14)" "00000000000000" "every extra press exits 0 at once, while the first still runs"
open_gate veil; wait "$first"; wait
eq "$(grep -c '^kawa-veil' "$CALLS")" 1 "one transition"
theme_is light

case_ "15 presses outside the veil while one switch is busy: exactly one switch"
setup
: >"$TMP/gate.gs.use"
kawa-theme & first=$!
at_gate gs || _no "the first switch never reached gsettings"
presses 14
eq "$(codes 14)" "00000000000000" "every extra press exits 0 at once, while the first still runs"
rm -f "$TMP/gate.gs.use"; open_gate gs; wait "$first"; wait
theme_is light

case_ "20 presses one after another: each one switches, and nothing piles up"
setup
for _ in {1..20}; do kawa-theme || _no "a press failed"; done
theme_is dark
eq "$(find "$DIR" -maxdepth 1 -name 'current*' | wc -l)" 1 "no half-made links left beside current"
eq "$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'kawa-theme*' | wc -l)" 2 "two lock files, no more"

case_ "killed mid-switch, then run again: it finishes, and everything agrees"
setup
read -r foot footlog < <(catcher foot USR1 USR2)
: >"$TMP/gate.gs.use"
setsid kawa-theme light & k=$!        # (its own process group: killed whole, like Ctrl+C or a crash)
at_gate gs || _no "never reached gsettings"
kill -9 -- -"$k"; wait "$k" 2>/dev/null
for _ in {1..200}; do kill -0 -- -"$k" 2>/dev/null || break; /bin/sleep 0.01; done
rm -f "$TMP/gate.gs.use"
eq "$(readlink "$LINK")" themes/light "(half way: the link moved, GTK did not)"
lacks "$(cat "$GS")" "prefer-light"
start=$SECONDS
rc 0 kawa-theme light
((SECONDS - start < 5)) && _ok || _no "the killed switch's locks held the next one back"
theme_is light
eq "$(got "$footlog" 2 | tail -n1)" SIGUSR2 "foot is told again"
rc 0 kawa-theme; theme_is dark

case_ "a lock file left from before (another boot, a crash) does not block"
setup
echo 12345 >"$XDG_RUNTIME_DIR/kawa-theme.busy"; echo junk >"$XDG_RUNTIME_DIR/kawa-theme.lock"
rc 0 kawa-theme light; theme_is light

# ── a broken setup ───────────────────────────────────────────────────────────
case_ "the current link missing: counts as dark, and a switch makes it again"
setup
rm "$LINK"
eq "$(kawa-theme get)" dark
rc 0 kawa-theme; theme_is light
rm "$LINK"; rc 0 kawa-theme apply; theme_is dark

case_ "the current link broken (to a theme that is gone): a switch repairs it"
setup
ln -sfn themes/sepia "$LINK"
eq "$(kawa-theme get)" dark
rc 0 kawa-theme light; theme_is light

case_ "the current link made by hand with a trailing slash still reads right"
setup
ln -sfn themes/light/ "$LINK"
eq "$(kawa-theme get)" light
rc 0 kawa-theme; theme_is dark

case_ "current is a real folder (copied by a backup tool): refused and left as it is"
setup; veil; export WAYLAND_DISPLAY=wayland-1
rm "$LINK"; cp -r "$DIR/themes/dark" "$LINK"; echo mine >"$LINK/mine"
out=$(kawa-theme light 2>&1); r=$?
eq "$r" 1 "exit 1: could not"
has "$out" "not a link"
eq "$(cat "$LINK/mine" 2>/dev/null)" mine "the folder is untouched"
eq "$(find "$DIR" -maxdepth 1 -name 'current*' | wc -l)" 1 "no half-made link left beside it"
lacks "$(cat "$GS")" "prefer-light" "GTK was not switched to a theme the apps do not show"
not_called '^kawa-veil'

case_ "a theme folder missing: says so, exits 1, changes nothing — and no transition plays"
setup; veil; export WAYLAND_DISPLAY=wayland-1
rm -r "$DIR/themes/light"
out=$(kawa-theme light 2>&1); r=$?
eq "$r" 1
has "$out" "no theme 'light'"
eq "$(readlink "$LINK")" themes/dark
not_called '^kawa-veil'
rc 1 kawa-theme

case_ "no runtime folder (XDG_RUNTIME_DIR gone): exit 1 with a plain message"
setup
export XDG_RUNTIME_DIR=$TMP/no-such-run
out=$(kawa-theme light 2>&1); r=$?
eq "$r" 1
has "$out" "kawa-theme:"
eq "$(kawa-theme get)" dark "get still works"

case_ "HOME with a space and an odd locale: still switches"
setup
mkdir -p "$TMP/my home"; cp -a "$HOME/." "$TMP/my home/"; export HOME="$TMP/my home"
LINK=$HOME/.config/fedokawaii/current DIR=$HOME/.config/fedokawaii
LC_ALL=tr_TR.UTF-8 kawa-theme light 2>/dev/null
eq "$(readlink "$LINK")" themes/light

case_ "a read-only config folder: exit 1, says it could not, the apps are not told"
setup
read -r foot footlog < <(catcher foot USR1 USR2)
if ro "$DIR"; then
  out=$(kawa-theme light 2>&1); r=$?
  rw "$DIR"
  eq "$r" 1
  has "$out" "kawa-theme: could not switch"
  eq "$(readlink "$LINK")" themes/dark
  /bin/sleep 0.3; eq "$(cat "$footlog" 2>/dev/null)" "" "foot was not switched"
  lacks "$(cat "$GS")" prefer-light "GTK was not switched"
else echo "  (skipped: no read-only folder possible here)"; fi

done_
