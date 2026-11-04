#!/usr/bin/env bash
# tests/status/test_rgb.sh — kawa-rgb against a made-up machine (KAWA_RGB_ROOT: sysfs, /dev, the
# mood and the conf in a throw-away tree; regular files take the writes): one breath for all,
# the mood's colours and the fade, screens off = the fire banked and nothing sent, the keyboard
# holding its breath while typed on and walking back, flash never written by the service, a
# device failing and coming back, nothing found, a broken conf. It runs in real time (8 Hz).
. "$(dirname "$0")/lib.sh"
sandbox
BIN=$TMP/kawa-rgb
make -s -C "$REPO/src/kawa-rgb" O="$TMP" CFLAGS="-O1 -g" 2>&1 | grep -v '^$' && _no "the build says something" || _ok
[[ -x $BIN ]] || { echo "kawa-rgb did not build" >&2; exit 1; }

machine() {   # a fresh machine in $M: every device there, screen on, dark
  M=$(mktemp -d "$TMP/m.XXXXXX")
  mkdir -p "$M"/{dev,etc/fedokawaii,var/lib/fedokawaii-greeter,run/kawa-rgb}
  mkdir -p "$M"/sys/class/{hidraw,i2c-dev/i2c-6/device,hwmon/hwmon4,drm/card0-HDMI-A-1}
  cat >"$M/etc/fedokawaii/rgb.conf" <<'EOF'
dark eb5324 12 55 3.5 5.5
light a84222 35 80 3 4
EOF
  echo dark >"$M/var/lib/fedokawaii-greeter/theme"
  hid hidraw1 0000258A 00000049 usb-0000:15:00.4-1/input1
  hid hidraw0 0000258A 00000049 usb-0000:15:00.4-1/input0
  hid hidraw4 00000DB0 00000076 usb-0000:13:00.0-7/input0
  hid hidraw6 00001A2C 00004184 usb-0000:13:00.0-12/input1
  hid hidraw5 00001A2C 00004184 usb-0000:13:00.0-12/input0
  head -c 185 /dev/zero >"$M/dev/hidraw4"                 # (the board's packet as it comes)
  echo 100 >"$M/sys/class/hidraw/urbnum"                  # (hidrawN/device/../.. here)
  echo 'AMDGPU DM i2c OEM bus' >"$M/sys/class/i2c-dev/i2c-6/name"
  echo 0x1458 >"$M/sys/class/i2c-dev/i2c-6/subsystem_vendor"
  echo 0x2429 >"$M/sys/class/i2c-dev/i2c-6/subsystem_device"
  : >"$M/dev/i2c-6"
  echo k10temp >"$M/sys/class/hwmon/hwmon4/name"
  echo 61375 >"$M/sys/class/hwmon/hwmon4/temp1_input"
  echo connected >"$M/sys/class/drm/card0-HDMI-A-1/status"
  echo On >"$M/sys/class/drm/card0-HDMI-A-1/dpms"
}
hid() {   # hid NODE VID PID PHYS
  mkdir -p "$M/sys/class/hidraw/$1/device"
  printf 'HID_ID=0003:%s:%s\nHID_NAME=x\nHID_PHYS=%s\n' "$2" "$3" "$4" >"$M/sys/class/hidraw/$1/device/uevent"
  : >"$M/dev/$1"
}
start() { KAWA_RGB_ROOT=$M setsid "$BIN" run --trace "$M/trace" >"$M/out" 2>&1 & PID=$!; }
stop() { kill "$PID" 2>/dev/null; wait "$PID" 2>/dev/null; PID=""; }
on_exit '[[ -n ${PID:-} ]] && kill "$PID" 2>/dev/null'
secs() { /bin/sleep "$1"; }
col() { awk -v k="$1" '{ for (i = 1; i <= NF; i++) if (index($i, k "=") == 1) { split(substr($i, length(k) + 2), a, ","); print a[1] + 0, a[2] + 0, a[3] + 0 } }' "${2:-$M/trace}"; }
size() { stat -c %s "$M/dev/$1"; }

case_ "one breath: rises and falls between the floor and the peak, every device the same"
machine; start; secs 10; stop
r=$(col motherboard | awk '{ if (min == "" || $1 < min) min = $1; if ($1 > max) max = $1 } END { print min, max }')
# (the accent decoded: 213 at full; 12 % and 55 % of it, the first ticks walking up from the floor)
read -r lo hi <<<"$r"
if ((lo >= 24 && lo <= 29 && hi >= 112 && hi <= 118)); then _ok; else _no "motherboard's red ran $lo–$hi, wanted about 26–117"; fi
eq "$(col motherboard | tail -n +30 | md5sum)" "$(col card | tail -n +30 | md5sum)" "the card follows the motherboard, tick for tick"
eq "$(col motherboard | tail -n +30 | md5sum)" "$(col keyboard | tail -n +30 | md5sum)" "the keyboard follows too"

case_ "an ember: dimmer is redder (green falls faster than red)"
read -r r g _ <<<"$(col card | sort -n | tail -n 1)"; ((g * 100 / r <= 10)) && _ok || _no "at the peak $r,$g"
read -r r g _ <<<"$(col card | sort -n | head -n 1)"; ((g * 100 / r <= 5)) && _ok || _no "at the floor $r,$g"

case_ "the wire: the keyboard's live frame, the board's packet, the card's write"
n=$(size hidraw1); eq "$((n % 382))" 0 "keyboard writes are whole frames"
eq "$(head -c 4 "$M/dev/hidraw1" | od -An -tx1 | tr -d ' \n')" 080a7a01
n=$(($(size hidraw4) - 185)); eq "$((n % 185))" 0 "board writes are whole packets"
# flash is never written by the service: save_data (byte 184) stays 0 in every packet
sv=$(python3 -I -c 'import sys
d = open(sys.argv[1], "rb").read()
print(sum(d[i + 184] for i in range(0, len(d), 185)))' "$M/dev/hidraw4")
eq "$sv" 0 "save_data never set"
# (the card: its presence ask, then writes of 64 bytes to the logo's zone, mode static)
sz=$(size i2c-6); eq "$((sz % 64))" 0 "card writes are 64 bytes each"
eq "$(od -An -tx1 -j 0 -N 2 "$M/dev/i2c-6" | tr -d ' \n')" 1001 "the presence ask first"
eq "$(od -An -tx1 -j 64 -N 5 "$M/dev/i2c-6" | tr -d ' \n')" 120101010a "then the mode register: static"
eq "$(od -An -tx1 -j 73 -N 1 "$M/dev/i2c-6" | tr -d ' \n')" 03 "the logo's zone"

case_ "the cooler's display: the CPU's temperature, its vendor's report"
n=$(size hidraw6); ((n >= 64)) && _ok || _no "the display got $n bytes"
eq "$(tail -c 64 "$M/dev/hidraw6" | head -c 6 | od -An -tx1 | tr -d ' \n')" 07ffff000601 "07 ff ff 0 6 1 (61 °C)"
has "$(KAWA_RGB_ROOT=$M "$BIN" status)" "display ok"

case_ "status: every device found"
s=$(KAWA_RGB_ROOT=$M "$BIN" status)
has "$s" "mood dark"; has "$s" "screens on"; has "$s" "motherboard ok"; has "$s" "keyboard ok"; has "$s" "card ok"

case_ "the mood: light's numbers, reached through a fade of 10 ticks"
machine; start; secs 3; echo light >"$M/var/lib/fedokawaii-greeter/theme"; secs 8; stop
has "$(tail -n 1 "$M/trace")" " light "
# (light's accent a84222 decoded: 102; its peak 80 %: 82)
hi=$(col motherboard | tail -n 40 | sort -n | tail -n 1 | cut -d' ' -f1)
if ((hi >= 40 && hi <= 84)); then _ok; else _no "light's red peaked at $hi"; fi
eq "$(KAWA_RGB_ROOT=$M "$BIN" status 2>&1 | sed -n 1p)" "mood light"

case_ "screens off: the fire banked at the floor, and then nothing is sent"
machine; start; secs 2; echo Off >"$M/sys/class/drm/card0-HDMI-A-1/dpms"; secs 4
a=$(size hidraw4); b=$(size hidraw1); c=$(size i2c-6); secs 2
eq "$(size hidraw4) $(size hidraw1) $(size i2c-6)" "$a $b $c" "no traffic while banked"
has "$(tail -n 1 "$M/trace")" " banked "
read -r r _ <<<"$(col motherboard | tail -n 1)"; ((r >= 24 && r <= 29)) && _ok || _no "banked at $r"
case_ "…and the screens back: it walks up from the floor, no jump"
echo On >"$M/sys/class/drm/card0-HDMI-A-1/dpms"; secs 6; stop
jump=$(col motherboard | awk 'NR > 1 { d = $1 - p; if (d < 0) d = -d; if (d > m) m = d } { p = $1 } END { print m + 0 }')
((jump <= 13)) && _ok || _no "a jump of $jump in one tick"

case_ "typed on: the keyboard holds its breath, the others go on, then it walks back"
machine; start; secs 2
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do echo $(($(cat "$M/sys/class/hidraw/urbnum") + 50)) >"$M/sys/class/hidraw/urbnum"; secs 0.2; done
b=$(size hidraw1); a=$(size hidraw4); secs 1.2
eq "$(size hidraw1)" "$b" "no frame to the keyboard while it is typed on"
[[ $(size hidraw4) -gt $a ]] && _ok || _no "the motherboard stopped too"
grep -q 'keyboard=[0-9,]*H' "$M/trace" && _ok || _no "the trace shows no hold"
secs 5; stop
[[ $(size hidraw1) -gt $b ]] && _ok || _no "it never came back"
jump=$(col keyboard | awk 'NR > 1 { d = $1 - p; if (d < 0) d = -d; if (d > m) m = d } { p = $1 } END { print m + 0 }')
((jump <= 13)) && _ok || _no "the keyboard jumped by $jump"
eq "$(col keyboard | tail -n 2 | head -n 1)" "$(col motherboard | tail -n 2 | head -n 1)" "back in step with the others"

case_ "a device failing (a write error) is let go, and found again"
machine; rm "$M/dev/hidraw1"; ln -s /dev/full "$M/dev/hidraw1"; start; secs 3
has "$(KAWA_RGB_ROOT=$M "$BIN" status)" "keyboard missing"
has "$(KAWA_RGB_ROOT=$M "$BIN" status)" "motherboard ok"
rm "$M/dev/hidraw1"; : >"$M/dev/hidraw1"; secs 3
has "$(KAWA_RGB_ROOT=$M "$BIN" status)" "keyboard ok"
[[ $(size hidraw1) -gt 0 ]] && _ok || _no "no frames after it came back"
stop

case_ "a replugged device on a new node: found"
machine; start; secs 1; stop; rm -r "$M/sys/class/hidraw/hidraw1" "$M/dev/hidraw1"; hid hidraw9 0000258A 00000049 usb-0000:15:00.4-3/input1; start; secs 3; stop
[[ $(size hidraw9) -gt 0 ]] && _ok || _no "not found on hidraw9"

case_ "nothing there (a VM): it runs, finds nothing, says so, writes nothing"
machine; rm -r "$M/sys/class/hidraw" "$M/sys/class/i2c-dev" "$M/dev"/*; start; secs 2
s=$(KAWA_RGB_ROOT=$M "$BIN" status)
has "$s" "keyboard missing"; has "$s" "card missing"; has "$s" "display missing"
kill -0 "$PID" && _ok || _no "it died"; stop; eq "$(cat "$M/out")" "" "silent"

case_ "another card's OEM bus, a keyboard of another make: not touched"
machine; echo 0x1002 >"$M/sys/class/i2c-dev/i2c-6/subsystem_vendor"
sed -i 's/0000258A/0000BEEF/' "$M/sys/class/hidraw/hidraw1/device/uevent"; start; secs 2; stop
eq "$(size i2c-6) $(size hidraw1)" "0 0"

case_ "a conf it cannot use: says so and stops (no default colour)"
machine; echo 'dark nonsense' >"$M/etc/fedokawaii/rgb.conf"; rc 1 env KAWA_RGB_ROOT="$M" "$BIN" run
has "$(KAWA_RGB_ROOT=$M "$BIN" run 2>&1)" "needs a dark and a light line"
rm "$M/etc/fedokawaii/rgb.conf"; rc 1 env KAWA_RGB_ROOT="$M" "$BIN" run

case_ "the command line"
rc 2 "$BIN"; rc 2 "$BIN" nonsense; rc 2 "$BIN" run --trace
machine; rc 1 env KAWA_RGB_ROOT="$M" "$BIN" status
done_
