#!/usr/bin/env bash
# tools/hotplug-test.sh — a monitor dropping off the cable and coming back, for real: a test
# dwl on the graphics card the desktop does not draw on, one of that card's screen sockets
# forced connected (sysfs status "on", with the desktop monitor's own EDID: the same modes),
# then disconnected and connected again (amdgpu's trigger_hotplug sends the event: the sysfs
# write alone sends none) — the kernel's own hotplug, as when the monitor is switched off at
# its button, or drops off the cable asleep. Nothing reaches the desktop: another card, a
# runtime dir of its own, no input devices (keys go in through the virtual keyboard, wtype).
# Three X11 windows (tools/xconf.c) on tag 3: A and B tiled, C floating at a place it asked
# for, focused. Checks, CYCLES times (default 5):
#   1 the X11 windows asking for new sizes while no monitor is there: dwl lives (it crashed on
#     exactly that on 26 Oct 12:22 — configurex11 with no monitor — and the session ended)
#   2 the monitor comes back on the tag it showed, in its layout, at the mode it had (not its
#     preferred one), the same window focused, the floating one where it was; and (once, at
#     the end) the spiral's mfact as it was set (A's width)
#   3 turned off (wlopm) before it dropped off: it comes back still off (no wl_output then:
#     wlopm cannot reach it); a key let go leaves it dark, a key pressed lights it, at its
#     mode, and kawa-display --hotplug runs then — not while it stays dark
#   sudo bash tools/hotplug-test.sh [DWL]     DWL: the binary to test (default: the invoking
#                                             user's ~/.local/src/dwl/dwl); CYCLES=N in the env
# Exit 0 every check passed · 1 one failed (each printed) · 2 cannot run here
set -u
[[ $EUID -eq 0 ]] || { echo "hotplug-test: needs root (a card of its own, debugfs): sudo bash $0" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
user=${SUDO_USER:-$(logname 2>/dev/null)}
uhome=$(getent passwd "$user" | cut -d: -f6)
dwl=${1:-$uhome/.local/src/dwl/dwl}
cycles=${CYCLES:-5}
[[ -x $dwl ]] || { echo "hotplug-test: no dwl at $dwl" >&2; exit 2; }
for t in wlr-randr wlopm wtype cc; do
  command -v "$t" >/dev/null || { echo "hotplug-test: $t is missing" >&2; exit 2; }
done

# the card the desktop draws on (its dwl's WLR_DRM_DEVICES) is left alone; the test takes
# another, one nothing has open, and a socket of it with nothing plugged in
livepid=$(pgrep -u "$user" -xo dwl)
live=$( [[ -n $livepid ]] && tr '\0' '\n' <"/proc/$livepid/environ" | sed -n 's/^WLR_DRM_DEVICES=//p')
card="" conn=""
for d in /sys/class/drm/card[0-9]*; do
  c=${d##*/}
  [[ $c == *-* || /dev/dri/$c == "$live" ]] && continue
  fuser -s "/dev/dri/$c" 2>/dev/null && continue
  for k in "$d"-HDMI-A-* "$d"-DP-*; do
    [[ -e $k/status && $(<"$k/status") == disconnected ]] || continue
    card=$c conn=${k##*/"$c"-}
    break 2
  done
done
[[ -n $card ]] || { echo "hotplug-test: no free card with an empty screen socket (the desktop uses ${live:-?})" >&2; exit 2; }
status=/sys/class/drm/$card-$conn/status
dbg=/sys/kernel/debug/dri/${card#card}/$conn
[[ -e $dbg/edid_override ]] || { echo "hotplug-test: no debugfs for $card $conn" >&2; exit 2; }
edid=""
for e in /sys/class/drm/"${live##*/}"-*/edid; do      # (sysfs says size 0: read a byte)
  [[ -n $(head -c1 "$e" 2>/dev/null | od -An) ]] && { edid=$e; break; }
done

T=$(mktemp -d /tmp/hotplug.XXXXXX)
fails=0 pid=""
declare -A xp
plug() { echo on >"$status"; echo 1 >"$dbg/trigger_hotplug"; }
unplug() { echo off >"$status"; echo 0 >"$dbg/trigger_hotplug"; }
# the socket as it was: no EDID of its own, its state asked of the cable ("detect": amdgpu
# keeps the forced screen's stand-in until an unplug event clears it) — disconnected
restore() {
  printf reset >"$dbg/edid_override" 2>/dev/null
  echo detect >"$status" 2>/dev/null
  echo 0 >"$dbg/trigger_hotplug" 2>/dev/null
}
cleanup() {
  [[ -n $pid ]] && kill "$pid" 2>/dev/null && wait "$pid" 2>/dev/null
  restore
  rm -rf "$T"
}
trap cleanup EXIT
pass() { printf '  ✔ %s\n' "$1"; }
fail() { printf '  ✘ %s\n' "$1"; fails=$((fails + 1)); }
# wait_for SECONDS COMMAND… — until the command succeeds (0) or the time is up (1)
wait_for() {
  local end=$((SECONDS + $1)); shift
  until "$@"; do ((SECONDS >= end)) && return 1; sleep 0.1; done
}

cc -O2 -o "$T/xconf" "$here/xconf.c" -lxcb || exit 2
mkdir -p "$T/bin"
# kawa-display stands in: each call noted (dwl runs it when a monitor comes, or lights)
printf '#!/bin/sh\necho "$*" >>%q/kawa-display.calls\n' "$T" >"$T/bin/kawa-display"
chmod +x "$T/bin/kawa-display"
printf '#!/bin/sh\necho "$DISPLAY" >%q/display\nexec cat >%q/status\n' "$T" "$T" >"$T/startup.sh"
chmod +x "$T/startup.sh"
chmod 700 "$T"

[[ -n $edid ]] && cat "$edid" >"$dbg/edid_override"
plug
env -i PATH="$T/bin:/usr/local/bin:/usr/bin:/bin" HOME="$T" XDG_RUNTIME_DIR="$T" \
  LIBSEAT_BACKEND=noop WLR_BACKENDS=drm WLR_DRM_DEVICES="/dev/dri/$card" WLR_RENDERER=gles2 \
  "$dwl" -s "$T/startup.sh" >"$T/dwl.out" 2>"$T/dwl.err" &
pid=$!
wl() { local s; for s in "$T"/wayland-[0-9]; do break; done; WAYLAND_DISPLAY=${s##*/} XDG_RUNTIME_DIR=$T "$@"; }
randr() { wl wlr-randr 2>/dev/null | awk -v o="$conn" '$1 == o { on = 1; next } /^[^ ]/ { on = 0 } on'; }
enabled() { randr | grep -q "Enabled: $1"; }
current() { randr | sed -n 's/^ *\([0-9]*x[0-9]*\) px, \([0-9.]*\) Hz.*current.*/\1@\2/p'; }
last() { grep "^$conn $1 " "$T/status" 2>/dev/null | tail -1 | cut -d' ' -f3-; }
seltags() { last tags | cut -d' ' -f2; }
calls() { if [[ -e $T/kawa-display.calls ]]; then wc -l <"$T/kawa-display.calls"; else echo 0; fi; }
gone() { ! randr | grep -q Enabled; }
more() { (($(calls) > $1)); }
key() { wl wtype -s 600 "$@" 2>/dev/null; }
geoms() { grep -c '^geom' "$T/x.$1" 2>/dev/null; }
newer() { (($(geoms "$1") > $2)); }
# geom NAME — where window NAME is (its xconf prints it on SIGUSR2)
geom() {
  local n
  n=$(geoms "$1")
  kill -USR2 "${xp[$1]}"
  wait_for 3 newer "$1" "${n:-0}"
  grep '^geom' "$T/x.$1" | tail -1 | cut -d' ' -f2-
}
xwin() {     # xwin NAME — a window titled NAME, mapped
  DISPLAY=$(cat "$T/display") "$T/xconf" "$1" >"$T/x.$1" 2>&1 &
  xp[$1]=$!
  wait_for 10 grep -qs mapped "$T/x.$1"
}

echo "hotplug-test: $dwl on $card ($conn${edid:+, the EDID of ${edid%/edid}}), desktop on ${live:-?}, $cycles cycles"
if ! wait_for 15 enabled yes || ! wait_for 10 test -s "$T/display"; then
  echo "hotplug-test: the test dwl did not come up — its log:" >&2; tail -n 15 "$T/dwl.err" >&2; exit 2
fi
sleep 1
# (set up) a mode other than the preferred one; tag 3; A and B tiled in the spiral, its mfact
# raised twice; C floating at x 300 y 200, focused; the layout of Super+T
pref=$(randr | sed -n 's/^ *\([0-9]*x[0-9]*\) px, \([0-9.]*\) Hz.*preferred.*/\1@\2/p' | head -1)
kept=$(randr | sed -n 's/^ *\([0-9]*x[0-9]*\) px, \([0-9.]*\) Hz.*/\1@\2/p' | grep -v -x "$pref" | head -1)
[[ -n $kept ]] && wl wlr-randr --output "$conn" --mode "${kept%@*}@${kept#*@}Hz" 2>/dev/null
first_lt=$(last layout)
key -M logo -k 3 -m logo
{ xwin A && xwin B; } || { echo "hotplug-test: the X11 windows did not map" >&2; exit 2; }
sleep 0.5
a0=$(geom A)
key -M logo -k l -m logo; key -M logo -k l -m logo; sleep 0.5
a_mfact=$(geom A)
xwin C || exit 2
sleep 0.5
key -M logo -M shift -k space -m shift -m logo; sleep 0.3
kill -HUP "${xp[C]}"; sleep 0.5
key -M logo -k t -m logo; sleep 0.5
want_tags=$(seltags) want_lt=$(last layout) want_mode=$(current) want_title=$(last title) want_c=$(geom C)
# (each a state the monitor would not get by itself — else a pass would prove nothing)
if [[ $want_tags != 4 || $want_lt == "$first_lt" || -z $want_mode || $want_mode == "$pref" \
      || $want_title != C || $a_mfact == "$a0" || -z $want_c ]]; then
  echo "hotplug-test: could not set the state up (tags ${want_tags:-?}, layout ${want_lt:-?} from ${first_lt:-?}, mode ${want_mode:-?}, preferred ${pref:-?}, focus ${want_title:-?}, A ${a0:-?} → ${a_mfact:-?}, C ${want_c:-?})" >&2
  exit 2
fi
echo "  (state: tag 3, layout $want_lt, $want_mode, focus C at $want_c, A $a_mfact)"

for i in $(seq "$cycles"); do
  # 1 the monitor drops off; the X11 windows ask for new sizes with no monitor there
  unplug
  wait_for 10 gone || fail "cycle $i: the monitor did not go when the cable said so"
  for w in A B C; do kill -USR1 "${xp[$w]}"; done
  sleep 1.5
  if kill -0 "$pid" 2>/dev/null; then pass "cycle $i: X11 windows resizing with no monitor: dwl lives"
  else fail "cycle $i: dwl died with no monitor while X11 windows asked for new sizes"; exit 1; fi
  # 2 back as it was
  n=$(calls)
  plug
  wait_for 10 enabled yes || fail "cycle $i: the monitor did not come back on"
  sleep 0.7
  got="tags $(seltags) · $(last layout) · $(current) · focus $(last title) · C at $(geom C)"
  if [[ $got == "tags $want_tags · $want_lt · $want_mode · focus $want_title · C at $want_c" ]]; then
    pass "cycle $i: back as it was ($got)"
  else
    fail "cycle $i: back as $got"
  fi
  wait_for 3 more "$n" || fail "cycle $i: kawa-display did not run as it came"
done
grep -q '^sent' "$T/x.A" || fail "the X11 windows never sent their requests (xconf: $(tail -1 "$T/x.A"))"
key -M logo -k s -m logo; sleep 0.6
a_end=$(geom A)
[[ $a_end == "$a_mfact" ]] && pass "the spiral's mfact kept (A at $a_end; $a0 before Super+L)" \
  || fail "mfact lost: A at $a_end, was $a_mfact"

# 3 turned off, dropped off, back: still off until woken
wl wlopm --off "$conn" >/dev/null 2>&1
wait_for 5 enabled no || fail "wlopm --off did not turn it off"
unplug; wait_for 10 gone
n=$(calls)
plug
sleep 2
enabled no && pass "back while turned off: still off" || fail "back while turned off: lit by the cable"
[[ $(calls) == "$n" ]] && pass "kawa-display waits while it is dark" || fail "kawa-display ran while it stayed dark"
key -p Shift_L
sleep 1
enabled no && pass "a key let go leaves it dark" || fail "a key let go lit it"
key -P Shift_L -p Shift_L
wait_for 5 enabled yes && pass "a key pressed lights it" || fail "a key pressed did not light it"
[[ $(current) == "$want_mode" ]] && pass "lit at the mode it had ($want_mode)" || fail "lit at $(current), not $want_mode"
[[ $(seltags) == "$want_tags" ]] && pass "lit on the tag it showed" || fail "lit on tags $(seltags), not $want_tags"
wait_for 3 more "$n" && pass "kawa-display --hotplug ran as it lit" || fail "kawa-display did not run as it lit"
kill -0 "$pid" 2>/dev/null || fail "dwl died"

((fails == 0)) && { echo "hotplug-test: all passed"; exit 0; }
echo "hotplug-test: $fails failed — the test dwl's log: $T/dwl.err (kept)"; trap - EXIT
kill "$pid" 2>/dev/null; restore
exit 1
