#!/usr/bin/env bash
# tools/hotplug-test.sh — a monitor dropping off the cable and coming back, for real: a test
# dwl on the graphics card the desktop does not draw on, one of that card's screen sockets
# forced connected (sysfs status "on", with the desktop monitor's own EDID: the same modes),
# then disconnected and connected again (amdgpu's trigger_hotplug sends the event: the sysfs
# write alone sends none) — the kernel's own hotplug, as when the monitor is
# switched off at its button, or drops off the cable asleep. Nothing reaches the desktop:
# another card, a runtime dir of its own, no input devices (keys go in through the virtual
# keyboard, wtype). Checks:
#   1 an X11 window asking for new sizes while no monitor is there: dwl lives (it crashed on
#     exactly that on 26 Oct 12:22 — configurex11 with no monitor — and the session ended)
#   2 the monitor comes back on the tag it showed, in its layout, at the mode it had (not
#     its preferred one)
#   3 turned off (wlopm) before it dropped off: it comes back still off (no wl_output then:
#     wlopm cannot reach it); a key let go leaves it dark, a key pressed lights it, at its
#     mode, and kawa-display --hotplug runs then — not while it stays dark
#   sudo bash tools/hotplug-test.sh [DWL]     DWL: the binary to test (default: the invoking
#                                             user's ~/.local/src/dwl/dwl)
# Exit 0 every check passed · 1 one failed (each printed) · 2 cannot run here
set -u
[[ $EUID -eq 0 ]] || { echo "hotplug-test: needs root (a card of its own, debugfs): sudo bash $0" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
user=${SUDO_USER:-$(logname 2>/dev/null)}
uhome=$(getent passwd "$user" | cut -d: -f6)
dwl=${1:-$uhome/.local/src/dwl/dwl}
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
fails=0
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
  [[ -n ${pid:-} ]] && kill "$pid" 2>/dev/null && wait "$pid" 2>/dev/null
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
cat >"$T/startup.sh" <<EOF
#!/bin/sh
"$T/xconf" >"$T/xconf.log" 2>&1 &
echo \$! >"$T/xconf.pid"
exec cat >"$T/status"
EOF
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

echo "hotplug-test: $dwl on $card ($conn${edid:+, the EDID of ${edid%/edid}}), desktop on ${live:-?}"
if ! wait_for 15 enabled yes || ! wait_for 15 grep -q mapped "$T/xconf.log"; then
  echo "hotplug-test: the test dwl did not come up — its log:" >&2; tail -n 15 "$T/dwl.err" >&2; exit 2
fi
sleep 1
# 2 (set up): a mode other than the preferred one, tag 3, the layout of Super+T
pref=$(randr | sed -n 's/^ *\([0-9]*x[0-9]*\) px, \([0-9.]*\) Hz.*preferred.*/\1@\2/p' | head -1)
kept=$(randr | sed -n 's/^ *\([0-9]*x[0-9]*\) px, \([0-9.]*\) Hz.*/\1@\2/p' | grep -v -x "$pref" | head -1)
[[ -n $kept ]] && wl wlr-randr --output "$conn" --mode "${kept%@*}@${kept#*@}Hz" 2>/dev/null
first_lt=$(last layout)
wl wtype -s 600 -M logo -k 3 -m logo 2>/dev/null
wl wtype -s 600 -M logo -k t -m logo 2>/dev/null
sleep 0.5
want_tags=$(seltags) want_lt=$(last layout) want_mode=$(current)
# (each a state the monitor would not get by itself — else a pass would prove nothing)
if [[ $want_tags != 4 || $want_lt == "$first_lt" || -z $want_mode || $want_mode == "$pref" ]]; then
  echo "hotplug-test: could not set the state up (tags ${want_tags:-?}, layout ${want_lt:-?} from ${first_lt:-?}, mode ${want_mode:-?}, preferred ${pref:-?})" >&2
  exit 2
fi

# 1 the monitor drops off; the X11 window asks for new sizes with no monitor there
unplug
wait_for 10 gone || fail "the monitor did not go when the cable said so"
kill -USR1 "$(cat "$T/xconf.pid")"
sleep 1.5
if kill -0 "$pid" 2>/dev/null; then pass "an X11 window resizing itself with no monitor: dwl lives"
else fail "dwl died with no monitor while an X11 window asked for a new size"; exit 1; fi
grep -q "^sent" "$T/xconf.log" || fail "the X11 window never sent its requests (xconf: $(tail -1 "$T/xconf.log"))"

# 2 back as it was
n=$(calls)
plug
wait_for 10 enabled yes || fail "the monitor did not come back on"
sleep 0.5
[[ $(seltags) == "$want_tags" ]] && pass "back on the tag it showed ($want_tags)" \
  || fail "back on tags $(seltags), not $want_tags"
[[ $(last layout) == "$want_lt" ]] && pass "back in its layout ($want_lt)" || fail "layout $(last layout), not $want_lt"
[[ $(current) == "$want_mode" ]] && pass "back at the mode it had ($want_mode, preferred $pref)" \
  || fail "mode $(current), not $want_mode"
wait_for 3 more "$n" && pass "kawa-display --hotplug ran as it came" || fail "kawa-display did not run"

# 3 turned off, dropped off, back: still off until woken
wl wlopm --off "$conn" >/dev/null 2>&1
wait_for 5 enabled no || fail "wlopm --off did not turn it off"
unplug; wait_for 10 gone
n=$(calls)
plug
sleep 2
enabled no && pass "back while turned off: still off" || fail "back while turned off: lit by the cable"
[[ $(calls) == "$n" ]] && pass "kawa-display waits while it is dark" || fail "kawa-display ran while it stayed dark"
wl wtype -s 600 -p Shift_L 2>/dev/null
sleep 1
enabled no && pass "a key let go leaves it dark" || fail "a key let go lit it"
wl wtype -s 600 -P Shift_L -p Shift_L 2>/dev/null
wait_for 5 enabled yes && pass "a key pressed lights it" || fail "a key pressed did not light it"
[[ $(current) == "$want_mode" ]] && pass "lit at the mode it had ($want_mode)" || fail "lit at $(current), not $want_mode"
[[ $(seltags) == "$want_tags" ]] && pass "lit on the tag it showed" || fail "lit on tags $(seltags), not $want_tags"
wait_for 3 more "$n" && pass "kawa-display --hotplug ran as it lit" || fail "kawa-display did not run as it lit"
kill -0 "$pid" 2>/dev/null || fail "dwl died"

((fails == 0)) && { echo "hotplug-test: all passed"; exit 0; }
echo "hotplug-test: $fails failed — the test dwl's log: $T/dwl.err (kept)"; trap - EXIT
kill "$pid" 2>/dev/null; restore
exit 1
