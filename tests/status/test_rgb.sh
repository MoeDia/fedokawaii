#!/usr/bin/env bash
# tests/status/test_rgb.sh — kawa-rgb against a made-up machine (KAWA_RGB_ROOT: sysfs, /dev, the
# marks and the conf in a throw-away tree; regular files take the writes): one steady red and then
# nothing on the wire, the lock's fade, screens off and a sleep, the switch kept in the hardware's
# memory too, each device's memory read first and written only when it differs, a device failing
# and coming back, nothing found, a broken conf. It runs in real time.
. "$(dirname "$0")/lib.sh"
sandbox
BIN=$TMP/kawa-rgb
make -s -C "$REPO/src/kawa-rgb" O="$TMP" CFLAGS="-O1 -g" 2>&1 | grep -v '^$' && _no "the build says something" || _ok
[[ -x $BIN ]] || { echo "kawa-rgb did not build" >&2; exit 1; }

machine() {   # a fresh machine in $M: every device there, screen on, the switch never touched
  M=$(mktemp -d "$TMP/m.XXXXXX")
  mkdir -p "$M"/{dev,etc/fedokawaii,var/lib/fedokawaii-greeter,var/lib/kawa-rgb,run/kawa-rgb}
  mkdir -p "$M"/sys/class/{hidraw,i2c-dev/i2c-6/device,hwmon/hwmon4,drm/card0-HDMI-A-1}
  cat >"$M/etc/fedokawaii/rgb.conf" <<'EOF'
# a comment
motherboard 200 10 0
keyboard 255 0 0
card 240 0 20
dim 30
EOF
  hid hidraw1 0000258A 00000049 usb-0000:15:00.4-1/input1
  hid hidraw0 0000258A 00000049 usb-0000:15:00.4-1/input0
  hid hidraw4 00000DB0 00000076 usb-0000:13:00.0-7/input0
  hid hidraw6 00001A2C 00004184 usb-0000:13:00.0-12/input1
  hid hidraw5 00001A2C 00004184 usb-0000:13:00.0-12/input0
  blocks "$M/dev/hidraw1" 12
  head -c 185 /dev/zero >"$M/dev/hidraw4"                 # (the board's packet as it comes)
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
blocks() {   # blocks FILE EFFECT [R G B] — the K617's memory as it reads back (a test's file answers from its start)
  python3 -I - "$@" <<'PY'
import sys
f, eff = sys.argv[1], int(sys.argv[2])
b = bytearray(1032); b[14] = 0x5a; b[15] = 0xa5; b[21] = eff; b[100] = 0x77
if len(sys.argv) > 3:
    b[29:32] = bytes(map(int, sys.argv[3:6])); b[38] = 0; b[39] = 4
open(f, "wb").write(b)
PY
}
start() { KAWA_RGB_ROOT=$M setsid "$BIN" run --trace "$M/trace" >"$M/out" 2>&1 & PID=$!; }
stop() { [[ -n ${PID:-} ]] && { kill "$PID" 2>/dev/null; wait "$PID" 2>/dev/null; }; PID=""; }
on_exit '[[ -n ${PID:-} ]] && kill "$PID" 2>/dev/null'
secs() { /bin/sleep "$1"; }
K() { KAWA_RGB_ROOT=$M "$BIN" "$@"; }
col() { awk -v k="$1" '{ for (i = 1; i <= NF; i++) if (index($i, k "=") == 1) { sub(/^[a-z]*=/, "", $i); print $i } }' "$M/trace"; }
now_of() { col "$1" | tail -n 1; }
size() { stat -c %s "$M/dev/$1"; }
bytes_at() { od -An -tx1 -j "$2" -N "$3" "$M/dev/$1" | tr -d ' \n'; }
sizes() { echo "$(size hidraw4) $(size hidraw1) $(size i2c-6)"; }
state() { K status | sed -n 1p; }

case_ "one steady red, each device its own value; then nothing at all on the wire"
machine; start; secs 3
eq "$(now_of motherboard)" 200,10,0; eq "$(now_of keyboard)" 255,0,0; eq "$(now_of card)" 240,0,20
eq "$(state)" "lights full"
a=$(sizes); secs 3; eq "$(sizes)" "$a" "not one write while nothing changes"
s=$(K status); has "$s" "motherboard ok"; has "$s" "keyboard ok"; has "$s" "card ok"; has "$s" "display ok"
stop

case_ "the wire: the keyboard's live frame, its memory (read, then written whole), its frame again"
eq "$(bytes_at hidraw1 1032 7)" 080a7a01ff0000 "the live frame"
# (the head, a frame, its four blocks selected, the first select again, four whole blocks, a frame)
start_=$((1032 + 382 + 6 * 4 + 6))
eq "$(size hidraw1)" "$((start_ + 4 * 1032 + 382))"
eq "$(bytes_at hidraw1 "$start_" 5)" 0608b80040 "MODE's head"
eq "$(bytes_at hidraw1 "$((start_ + 1032))" 5)" 0609bc0040 "CANVAS's head"
eq "$(bytes_at hidraw1 "$((start_ + 2064))" 5)" 0609c00040 "ROUTING's head"
ex=$((start_ + 3096))
eq "$(bytes_at hidraw1 "$ex" 5)" 0603b60000 "EXEC's head, last"
eq "$(bytes_at hidraw1 "$((ex + 21))" 1)" 01 "fixed-on"
eq "$(bytes_at hidraw1 "$((ex + 38))" 2)" 0004 "one colour, the highest brightness"
eq "$(bytes_at hidraw1 "$((ex + 14))" 2)" 5aa5 "its commit mark kept"
eq "$(bytes_at hidraw1 "$((start_ + 29))" 3)" ff0000 "the colour"
eq "$(bytes_at hidraw1 "$((start_ + 100))" 1)" 77 "its own bytes kept"
eq "$(bytes_at hidraw1 "$((start_ + 4 * 1032))" 7)" 080a7a01ff0000 "the live frame again"

case_ "the wire: the board: a packet, its memory (the old state, then the new, saved), a packet"
eq "$(size hidraw4)" "$((185 * 5))"
eq "$(bytes_at hidraw4 $((185 + 184)) 1)" 00 "the live packet: never saved"
eq "$(bytes_at hidraw4 $((185 + 32)) 4)" c80a0028 "the same on the ARGB header"
eq "$(bytes_at hidraw4 $((185 * 2 + 184)) 1)" 01 "the old state saved"
eq "$(bytes_at hidraw4 $((185 * 3 + 184)) 1)" 01 "the new state saved"
eq "$(bytes_at hidraw4 $((185 * 3 + 1)) 5)" 01c80a0028 "static, its value, full"
eq "$(bytes_at hidraw4 $((185 * 4 + 184)) 1)" 00 "the live packet again, not saved"

case_ "the wire: the card: the ask; the logo; its six zones and a save; the logo, then the others (whole 64-byte writes)"
eq "$(bytes_at i2c-6 0 2)" 1001 "the presence ask first"
eq "$(bytes_at i2c-6 64 8)" 120101010af00014 "static, the slowest, full, its value"
eq "$(bytes_at i2c-6 73 1)" 03 "the logo's zone first"
eq "$(bytes_at i2c-6 $((64 * 8)) 2)" 1301 "the save"
eq "$(bytes_at i2c-6 $((64 * 9 + 9)) 1)" 03 "the logo's zone again"
eq "$(bytes_at i2c-6 $((64 * 10 + 9)) 1)" 05 "then the others, not the logo's twice"
eq "$(size i2c-6)" "$((64 * (1 + 1 + 6 + 1 + 6)))" "each zone once"
eq "$(cat "$M/var/lib/kawa-rgb/card")" f00014 "its mark: it answers nothing back"

case_ "the cooler's display: the CPU's temperature, its vendor's report"
n=$(size hidraw6); ((n >= 64 && n % 64 == 0)) && _ok || _no "the display got $n bytes"
eq "$(tail -c 64 "$M/dev/hidraw6" | head -c 6 | od -An -tx1 | tr -d ' \n')" 07ffff000601 "07 ff ff 0 6 1 (61 °C)"
machine; echo 100500 >"$M/sys/class/hwmon/hwmon4/temp1_input"; start; secs 1.2; stop
eq "$(head -c 6 "$M/dev/hidraw6" | od -An -tx1 | tr -d ' \n')" 07ffff010001 "three digits: 101"

case_ "the memories read first: already so, nothing is written, the service only sends its frame"
machine; blocks "$M/dev/hidraw1" 1 255 0 0
python3 -I - "$M/dev/hidraw4" <<'PY'
import sys
d = bytearray(185)
for off in (1, 11, 21, 31, 42, 74, 174):
    d[off:off + 9] = bytes((1, 200, 10, 0, 40, 200, 10, 0, 0x80))
open(sys.argv[1], "wb").write(d)
PY
echo f00014 >"$M/var/lib/kawa-rgb/card"
start; secs 2; stop
eq "$(size hidraw1)" "$((1032 + 382 + 6 * 4))" "keyboard: only the frame and its selects"
eq "$(size hidraw4)" "$((185 * 2))" "board: only the frame"
eq "$(size i2c-6)" "$((64 * (1 + 6)))" "card: the ask and the zones, no save"
eq "$(cat "$M/out")" "" "and nothing to say"

case_ "a keyboard whose memory is not what we know: left alone (no burst), said once; its live frame still goes"
machine; head -c 1032 /dev/zero >"$M/dev/hidraw1"; start; secs 2; stop
eq "$(size hidraw1)" "$((1032 + 382 + 6 * 4))"
has "$(cat "$M/out")" "keyboard's memory"; eq "$(grep -c memory "$M/out")" 1 "once"

case_ "the lock screen: a fade to about 30 % (of what it looks: 7 % of the value), and back"
machine; start; secs 2; b=$(wc -l <"$M/trace"); K lock; secs 2.5
eq "$(now_of keyboard)" 18,0,0; eq "$(now_of motherboard)" 14,1,0; eq "$(now_of card)" 17,0,1; eq "$(state)" "lights dim"
# a fade, not a jump: a few steps, about a second
steps=$(col keyboard | tail -n +"$b" | uniq | wc -l); ((steps >= 5 && steps <= 8)) && _ok || _no "$steps steps down"
a=$(sizes); secs 1.5; eq "$(sizes)" "$a" "steady at the lock: nothing sent"
K unlock; secs 2.2; stop
eq "$(now_of keyboard)" 255,0,0 "unlocked: full"; eq "$(state)" "lights full"

case_ "the lock's mark left by a boot before this one: not locked"
machine; K lock; touch -d '2000-01-01' "$M/var/lib/fedokawaii-greeter/rgb-locked"; start; secs 1.5; stop
eq "$(now_of keyboard)" 255,0,0

case_ "screens off: off, then nothing sent; back: a fade up; locked meanwhile: back to the lock's level"
machine; start; secs 2; echo Off >"$M/sys/class/drm/card0-HDMI-A-1/dpms"; secs 2.5
eq "$(now_of keyboard)" 0,0,0; eq "$(now_of motherboard)" 0,0,0; eq "$(now_of card)" 0,0,0; eq "$(state)" "lights off, screens off"
a=$(sizes); d=$(size hidraw6); secs 1.5; eq "$(sizes)" "$a" "off: nothing sent"; eq "$(size hidraw6)" "$d" "the display left alone"
eq "$(tail -c 64 "$M/dev/i2c-6" | od -An -tx1 -j 2 -N 1 | tr -d ' \n')" 00 "the card's own off mode"
eq "$(tail -c 185 "$M/dev/hidraw4" | od -An -tx1 -j 1 -N 1 | tr -d ' \n')" 00 "the board's own off effect"
K lock; echo On >"$M/sys/class/drm/card0-HDMI-A-1/dpms"; secs 2; eq "$(now_of keyboard)" 18,0,0 "lit on the lock: dim"
K unlock; echo disconnected >"$M/sys/class/drm/card0-HDMI-A-1/status"; secs 2.5; eq "$(now_of keyboard)" 0,0,0 "the monitor gone from the cable: off"
stop

case_ "a sleep: out at once and the unit waits for it; awake: back"
machine; start; secs 1.5; a=$(date +%s%N); K sleep; b=$(date +%s%N)
((b - a < 1600000000)) && _ok || _no "the sleep's unit waited $(((b - a) / 1000000)) ms"
eq "$(state)" "lights off, asleep"; secs 0.8; eq "$(now_of keyboard)" 0,0,0
eq "$(col keyboard | tail -n 3 | sort -u | wc -l)" 1 "no fade: it goes at once"
K wake; secs 2; stop; eq "$(now_of keyboard)" 255,0,0; eq "$(state)" "lights full"
case_ "…with no service: the sleep's unit does not hang"
machine; a=$(date +%s); K sleep; rc 0 K wake; b=$(date +%s); ((b - a <= 3)) && _ok || _no "$((b - a)) s"

case_ "the switch: off for everything, in the hardware's memory too, and kept"
machine; eq "$(K state)" on "untouched: on"; start; secs 2
k=$(size hidraw1); K off; eq "$(K state)" off; eq "$(cat "$M/var/lib/fedokawaii-greeter/rgb")" off "in a file"; secs 4
eq "$(now_of keyboard)" 0,0,0; eq "$(state)" "lights switched off"
# (the keyboard's stored effect: off; in this test's file, its reads stay what they were)
t=$(od -An -tx1 -v -j "$k" "$M/dev/hidraw1" | tr -d ' \n'); has "$t" "0603b60000" "the burst came"
ex=$(python3 -I -c 'import sys
d = open(sys.argv[1], "rb").read()
i = d.rfind(bytes.fromhex("0603b60000"))
print("%02x" % d[i + 21])' "$M/dev/hidraw1"); eq "$ex" 16 "its effect: off"
sv=$(python3 -I -c 'import sys
d = open(sys.argv[1], "rb").read()
print(max(d[i + 184] for i in range(0, len(d), 185)))' "$M/dev/hidraw4"); eq "$sv" 1 "the board saved"
eq "$(cat "$M/var/lib/kawa-rgb/card")" 000000 "the card told, its mark too"
stop
case_ "…kept across a restart: stays off, no frame of light"
: >"$M/trace"; start; secs 1.5; stop
eq "$(col keyboard | sort -u)" 0,0,0 "never lit"
case_ "…and on again, the memories too; toggle"
start; secs 0.8; K on; eq "$(K state)" on; secs 5; eq "$(now_of keyboard)" 255,0,0; eq "$(state)" "lights full"
eq "$(cat "$M/var/lib/kawa-rgb/card")" f00014 "the card's memory back"
K toggle; eq "$(K state)" off; K toggle; eq "$(K state)" on; stop
lacks "$(cat "$M/out")" "kawa-rgb: card"

case_ "a device failing (a write error) is let go, and found again"
machine; rm "$M/dev/hidraw1"; ln -s /dev/full "$M/dev/hidraw1"; start; secs 3
has "$(K status)" "keyboard missing"; has "$(K status)" "motherboard ok"
rm "$M/dev/hidraw1"; blocks "$M/dev/hidraw1" 1 255 0 0; secs 3
has "$(K status)" "keyboard ok"
eq "$(bytes_at hidraw1 1032 7)" 080a7a01ff0000 "its colour sent again"
stop

case_ "a device gone (replugged), on the same node and on a new one: found, its colour sent again"
machine; start; secs 1.5; a=$(size hidraw4); cp "$M/dev/hidraw4" "$M/hold"; rm "$M/dev/hidraw4"; cp "$M/hold" "$M/dev/hidraw4"; secs 4.5
[[ $(size hidraw4) -gt $a ]] && _ok || _no "the board got nothing after coming back"
has "$(K status)" "motherboard ok"
rm -r "$M/sys/class/hidraw/hidraw1" "$M/dev/hidraw1"; secs 3; has "$(K status)" "keyboard missing"
hid hidraw9 0000258A 00000049 usb-0000:15:00.4-3/input1; blocks "$M/dev/hidraw9" 1 255 0 0; secs 3; stop
[[ $(size hidraw9) -gt 1032 ]] && _ok || _no "not found on hidraw9"

case_ "the card's bus failing: let go, found again, all its zones told"
machine; rm "$M/dev/i2c-6"; ln -s /dev/full "$M/dev/i2c-6"; start; secs 3
has "$(K status)" "card missing"
rm "$M/dev/i2c-6"; : >"$M/dev/i2c-6"; secs 3.5; stop
has "$(K status)" "card ok"
eq "$(bytes_at i2c-6 0 2)" 1001 "the ask again"

case_ "nothing there (a VM): it runs, finds nothing, says so, writes nothing"
machine; rm -r "$M/sys/class/hidraw" "$M/sys/class/i2c-dev" "$M/dev"/*; start; secs 2
s=$(K status); has "$s" "keyboard missing"; has "$s" "card missing"; has "$s" "display missing"; has "$s" "motherboard missing"
kill -0 "$PID" && _ok || _no "it died"; stop; eq "$(cat "$M/out")" "" "silent"

case_ "another card's OEM bus, a keyboard of another make: not touched"
machine; echo 0x1002 >"$M/sys/class/i2c-dev/i2c-6/subsystem_vendor"
sed -i 's/0000258A/0000BEEF/' "$M/sys/class/hidraw/hidraw1/device/uevent"; a=$(size hidraw1); start; secs 2; stop
eq "$(size i2c-6) $(size hidraw1)" "0 $a"

case_ "a conf it cannot use: says so and stops (no default colour)"
machine; printf 'motherboard 255 0 0\nkeyboard 255 0\ncard 255 0 0\ndim 30\n' >"$M/etc/fedokawaii/rgb.conf"; rc 1 K run
has "$(K run 2>&1)" "needs a line for each"
printf 'motherboard 300 0 0\nkeyboard 255 0 0\ncard 255 0 0\ndim 30\n' >"$M/etc/fedokawaii/rgb.conf"; rc 1 K run
printf 'motherboard 255 0 0\nkeyboard 255 0 0\ncard 255 0 0\n' >"$M/etc/fedokawaii/rgb.conf"; rc 1 K run
rm "$M/etc/fedokawaii/rgb.conf"; rc 1 K run

case_ "the repo's conf: every device, in range"
machine; cp "$REPO/configs/system/etc/fedokawaii/rgb.conf" "$M/etc/fedokawaii/rgb.conf"; start; secs 1; stop; eq "$(cat "$M/out")" ""
has "$(state)" "lights full"

case_ "the command line; a status with no service; a switch it cannot write"
rc 2 "$BIN"; rc 2 "$BIN" nonsense; rc 2 "$BIN" run --trace; rc 2 "$BIN" on off
machine; rc 1 K status
rm -r "$M/var/lib/fedokawaii-greeter"; rc 1 K off; rc 1 K lock; rc 0 K unlock; eq "$(K state)" on
done_
