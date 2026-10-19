#!/usr/bin/env bash
# tests/status/test_brightness.sh — kawa-brightness: monitors over DDC/CI (fake_ddcutil: buses,
# dead buses, renumbering, slow answers) and a laptop's own panel through logind (fake_busctl
# over a made-up /sys, KAWA_SYSFS). The level display is the real kawa-osd.
# Turned from the display review's live runs (review12/B) into checks.
. "$(dirname "$0")/lib.sh"
setup() {
  box; notices; . "$HOME/.config/fedokawaii/icons.sh"
  export DDC=$TMP/ddc DDC_BUSES=5 DDC_DEAD="" DDC_DELAY=0 KAWA_SYSFS=$TMP/sys
  mkdir -p "$DDC" "$KAWA_SYSFS/class/drm/card1-DP-1" "$KAWA_SYSFS/class/backlight"
  echo connected >"$KAWA_SYSFS/class/drm/card1-DP-1/status"
  stub ddcutil 'exec bash '"$SD"'/fake_ddcutil "$@"'
  stub busctl 'exec bash '"$SD"'/fake_busctl "$@"'
}
b() { cat "$DDC/b$1" 2>/dev/null || echo 70; }          # b BUS — a monitor's level now
cache() { cat "$XDG_RUNTIME_DIR/kawa-ddc-buses" 2>/dev/null; }
shown() { osd | cut -d'|' -f3; }                        # the level the panel showed last
notice() { grep '^NOTICE [0-9]* desktop ' "$NOTIFY_STATE/log" 2>/dev/null | tail -n 1 | cut -d'|' -f2-; }
detects() { grep -c ' detect' "$DDC/log" 2>/dev/null || echo 0; }
# laptop NAME TYPE MAX NOW — a built-in panel (eDP, connected) and its backlight
laptop() {
  mkdir -p "$KAWA_SYSFS/class/drm/card1-eDP-1"; echo connected >"$KAWA_SYSFS/class/drm/card1-eDP-1/status"
  backlight "$@"
}
backlight() {   # backlight NAME TYPE MAX NOW — a backlight device (TYPE "" = no type file)
  local d=$KAWA_SYSFS/class/backlight/$1; mkdir -p "$d"
  [[ -n $2 ]] && echo "$2" >"$d/type"; echo "$3" >"$d/max_brightness"; echo "$4" >"$d/brightness"
}
bl() { cat "$KAWA_SYSFS/class/backlight/$1/brightness"; }

# ── one monitor ──────────────────────────────────────────────────────────────
case_ "one monitor at 70 %: +10 → 80, the panel says so; -10 → 70; 40 → 40"
setup
rc 0 kawa-brightness +10; eq "$(b 5)" 80; eq "$(osd | cut -d'|' -f2,3)" "$ICON_SUN  brightness|80%"
rc 0 kawa-brightness -10; eq "$(b 5)" 70
rc 0 kawa-brightness 40;  eq "$(b 5)" 40; eq "$(kawa-brightness --level)" 40
eq "$(shown)" 70% "a level set from quick settings pops nothing up over its meter (the -10 step's 70 % stays the last shown)"
case_ "the ends: never above 100 or below 0 (a monitor's 0 is its dimmest, not dark)"
kawa-brightness +100; eq "$(b 5)" 100; kawa-brightness +10; eq "$(b 5)" 100
kawa-brightness 150;  eq "$(b 5)" 100
kawa-brightness -100; eq "$(b 5)" 0; kawa-brightness -10; eq "$(b 5)" 0; eq "$(shown)" 0%
kawa-brightness 007;  eq "$(b 5)" 7 "a leading zero is not octal"
case_ "a monitor on its own scale (max 50): 80 % is 40 of 50, and its level read back in per cent"
setup; echo 50 >"$DDC/max5"; echo 35 >"$DDC/b5"
kawa-brightness +10; eq "$(b 5)" 40; eq "$(shown)" 80%

# ── two monitors, dead ones, renumbered ones ─────────────────────────────────
case_ "two monitors: both move together, each on its own scale"
setup; export DDC_BUSES="5 7"; echo 255 >"$DDC/max7"; echo 178 >"$DDC/b7"
kawa-brightness +10
eq "$(b 5)" 80; eq "$(b 7)" 204 "80 % of 255"
kawa-brightness 30; eq "$(b 5)" 30; eq "$(b 7)" 76
eq "$(cache)" $'5\n7' "both buses kept for the session"
case_ "one monitor with DDC/CI switched off: the other one alone, the dead one never asked again"
setup; export DDC_BUSES="5 7" DDC_DEAD=7
kawa-brightness +10; eq "$(b 5)" 80; eq "$(cache)" 5
not_called 'ddcutil --bus 7'
case_ "the bus list is kept: only the first press looks for monitors (detection takes a second)"
setup
for _ in 1 2 3; do kawa-brightness +10; done
eq "$(detects)" 1; eq "$(b 5)" 100
case_ "buses renumbered since (a monitor plugged in elsewhere): looked for again, once, and it works"
setup; echo 5 >"$XDG_RUNTIME_DIR/kawa-ddc-buses"; export DDC_BUSES=9
kawa-brightness +10; eq "$(b 9)" 80; eq "$(cache)" 9; eq "$(detects)" 1
case_ "a corrupt bus list: looked for again (no false 'no monitor' notice)"
setup; printf 'garbage\n5x\n' >"$XDG_RUNTIME_DIR/kawa-ddc-buses"
rc 0 kawa-brightness +10; eq "$(b 5)" 80; eq "$(notice)" ""; eq "$(cache)" 5

case_ "no monitor answers (DDC/CI off everywhere, or a TV): a notice that says what to do, could not (1)"
setup; export DDC_BUSES=""
rc 1 kawa-brightness +10
eq "$(notice)" " $ICON_SUN  brightness | no monitor answered over DDC/CI — turn DDC/CI on in the monitor's own menu"
eq "$(cache)" "" "nothing kept: the next press looks again"
eq "$(osd)" "" "no level shown"
case_ "… every bus there, all dead: the same"
setup; export DDC_BUSES="5 7" DDC_DEAD="5 7"
rc 1 kawa-brightness -10; has "$(notice)" "no monitor answered"
case_ "the monitor that was there stopped answering: the notice comes at the first press"
setup; echo 5 >"$XDG_RUNTIME_DIR/kawa-ddc-buses"; export DDC_BUSES=""
rc 1 kawa-brightness +10; has "$(notice)" "no monitor answered"

# ── a held key, the lock ─────────────────────────────────────────────────────
case_ "a held key (35 presses a second, monitors answering in 50 ms): repeats dropped, both monitors in step, never past 100"
setup; export DDC_BUSES="5 7" DDC_DELAY=0.05
for _ in {1..35}; do kawa-brightness +10 & /bin/sleep 0.028; done; wait
v5=$(b 5) v7=$(b 7)
eq "$v5" "$v7" "both monitors at the same level"
[[ $v5 =~ ^(80|90|100)$ ]] && _ok || _no "level $v5"
eq "$(shown)" "$v5%" "the panel shows where it ended"
eq "$(cut -d' ' -f2 "$NOTIFY_STATE/log" | sort -u)" 1 "one panel, updated in place"
case_ "… and down the same way: 0 at most, still in step"
for _ in {1..35}; do kawa-brightness -10 & /bin/sleep 0.028; done; wait
eq "$(b 5)" "$(b 7)"
case_ "quick settings' meter dragged (a level every 30 ms, monitor 200 ms a change): none queued, the last one always arrives"
setup; export DDC_DELAY=0.2; kawa-brightness --level >/dev/null; : >"$DDC/log"
for v in 10 15 20 25 30 35 40 45 50 55 60 65; do kawa-brightness "$v" & /bin/sleep 0.03; done; wait
eq "$(b 5)" 65 "the monitor ends where the meter did"
eq "$(kawa-brightness --level)" 65
n=$(grep -c setvcp "$DDC/log"); ((n >= 2 && n <= 6)) && _ok || _no "$n levels set for 12 asked (stale ones should be skipped)"
eq "$(grep -c getvcp "$DDC/log")" 0 "a level asks the monitor nothing (its scale is known)"
[[ ! -e $XDG_RUNTIME_DIR/kawa-brightness.want ]] && _ok || _no "a wanted level was left behind"
case_ "… read back while the monitor is still busy with an older level (quick settings' state): the one asked, not the old one"
setup; export DDC_DELAY=0.4; kawa-brightness --level >/dev/null
kawa-brightness 20 & /bin/sleep 0.15
kawa-brightness 90       # (handed to the run under way: back at once)
eq "$(kawa-brightness --level)" 90 "the meter is not sent back"
wait; eq "$(b 5)" 90
case_ "… one asked while another run holds the monitors (the bar reading the level): applied by that run"
setup; export DDC_DELAY=0.3; rm -f "$XDG_RUNTIME_DIR/kawa-brightness.level"
kawa-brightness --level >/dev/null & /bin/sleep 0.1
rc 0 kawa-brightness 30; wait
eq "$(b 5)" 30 "not dropped"
case_ "a key press: the level shows before the monitor has answered, and one DDC/CI conversation"
setup; kawa-brightness --level >/dev/null; : >"$DDC/log"; export DDC_DELAY=1.5
kawa-brightness +10 &
for _ in {1..60}; do [[ $(shown) == 80% ]] && break; /bin/sleep 0.02; done
eq "$(shown)" 80% "shown at once"
eq "$(b 5)" 70 "(the monitor not there yet)"
wait; eq "$(b 5)" 80
eq "$(grep -c . "$DDC/log")" 1 "one ddcutil: the change (its level known, no read first)"
called 'ddcutil --bus 5 --skip-ddc-checks setvcp 10 80 --noverify'
case_ "a stale lock from a press that was killed: the next press works"
setup; : >"$XDG_RUNTIME_DIR/kawa-ddc.lock"
rc 0 kawa-brightness +10; eq "$(b 5)" 80

# ── use ──────────────────────────────────────────────────────────────────────
case_ "no level given, or one it cannot read: exit 2, nothing touched (quick settings' meter gives one)"
setup; rc 2 kawa-brightness; rc 2 kawa-brightness menu; rc 2 kawa-brightness +x; eq "$(b 5)" 70; eq "$(osd)" ""

# ── a laptop's own panel ─────────────────────────────────────────────────────
case_ "a laptop (firmware backlight, 0–100): +10 through logind, no DDC monitor, no notice"
setup; export DDC_BUSES=""; laptop acpi_video0 firmware 100 70
rc 0 kawa-brightness +10
eq "$(bl acpi_video0)" 80; eq "$(shown)" 80%; eq "$(notice)" ""
called 'busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto org.freedesktop.login1.Session SetBrightness ssu backlight acpi_video0 80'
case_ "… 'no DDC monitor' is kept ('-'), so the next presses do not look again"
eq "$(cache)" -; kawa-brightness +10; kawa-brightness +10; eq "$(detects)" 1; eq "$(bl acpi_video0)" 100
case_ "a raw panel (0–255): its own scale both ways"
setup; export DDC_BUSES=""; laptop amdgpu_bl1 raw 255 255
kawa-brightness -10; eq "$(bl amdgpu_bl1)" 229; eq "$(shown)" 90%
kawa-brightness 50; eq "$(bl amdgpu_bl1)" 127
case_ "never 0 on a panel (that is a black screen): 0 and a step below are its lowest, 1"
kawa-brightness 0; eq "$(bl amdgpu_bl1)" 1; eq "$(kawa-brightness --level)" 0
kawa-brightness +10; eq "$(bl amdgpu_bl1)" 25 "from the lowest, one step up"
kawa-brightness -10; kawa-brightness -10; eq "$(bl amdgpu_bl1)" 1
case_ "several backlights: firmware before platform before raw (as GNOME and KDE choose), whatever their names"
setup; export DDC_BUSES=""; laptop intel_backlight raw 96000 48000; backlight acpi_video0 firmware 100 50
kawa-brightness +10; eq "$(bl acpi_video0)" 60; eq "$(bl intel_backlight)" 48000 "the raw one left alone"
setup; export DDC_BUSES=""; laptop amdgpu_bl1 raw 255 255; backlight video_fw firmware 100 50
kawa-brightness +10; eq "$(bl video_fw)" 60 "a raw one named before it"; eq "$(bl amdgpu_bl1)" 255
setup; export DDC_BUSES=""; laptop intel_backlight raw 96000 48000; backlight thinkpad_screen platform 15 7
kawa-brightness +10; eq "$(bl thinkpad_screen)" 8 "7 of 15 is 47 %; +10 → 57 % → 8 of 15"
eq "$(bl intel_backlight)" 48000
setup; export DDC_BUSES=""; laptop thinkpad_screen platform 15 7; backlight acpi_video0 firmware 100 50
kawa-brightness +10; eq "$(bl acpi_video0)" 60; eq "$(bl thinkpad_screen)" 7
case_ "a backlight without a type file: taken as raw"
setup; export DDC_BUSES=""; laptop nv_backlight "" 100 40
kawa-brightness +10; eq "$(bl nv_backlight)" 50
case_ "a laptop with a monitor on DDC/CI: both move, the step starts from the panel's level"
setup; laptop amdgpu_bl1 raw 255 127; echo 90 >"$DDC/b5"
kawa-brightness +10; eq "$(bl amdgpu_bl1)" 153; eq "$(b 5)" 60; eq "$(cache)" 5
case_ "logind refuses (the session is not the active one): written directly when the file allows it"
setup; export DDC_BUSES="" LOGIND_REFUSE=1; laptop acpi_video0 firmware 100 70; chmod 666 "$KAWA_SYSFS/class/backlight/acpi_video0/brightness"
kawa-brightness +10; eq "$(bl acpi_video0)" 80; unset LOGIND_REFUSE
case_ "a panel that cannot say its level (max 0): a key does nothing, quietly"
setup; export DDC_BUSES=""; laptop broken_bl raw 0 0
rc 0 kawa-brightness +10; eq "$(bl broken_bl)" 0; eq "$(osd)" ""
case_ "the panel's connector disconnected (lid shut, only the monitor in use): the monitor alone"
setup; laptop amdgpu_bl1 raw 255 255; echo disconnected >"$KAWA_SYSFS/class/drm/card1-eDP-1/status"
kawa-brightness -10; eq "$(b 5)" 60 "from the monitor's own 70"; eq "$(bl amdgpu_bl1)" 255
not_called SetBrightness

# ── a desktop board with a stray ACPI backlight ──────────────────────────────
case_ "a desktop with a backlight device that drives nothing (no built-in panel): never used"
setup; backlight acpi_video0 firmware 100 100
kawa-brightness -10; eq "$(b 5)" 60 "from the monitor's level, not the stray device's 100"
eq "$(bl acpi_video0)" 100; not_called SetBrightness
case_ "… and with no DDC monitor: the notice, not the stray device"
setup; export DDC_BUSES=""; backlight acpi_video0 firmware 100 100
rc 1 kawa-brightness +10; has "$(notice)" "no monitor answered"; eq "$(cache)" ""

# ── a monitor plugged in later (kawa-display --hotplug drops the bus list) ───
case_ "laptop, then a monitor plugged in: after kawa-display --hotplug the keys reach it too"
setup; export DDC_BUSES=""; laptop amdgpu_bl1 raw 255 127; echo 20 >"$DDC/b5"
kawa-brightness +10; eq "$(cache)" -
export DDC_BUSES=5 FAKE_RANDR=$TMP/randr.json
cp "$SD/fixtures/randr/1080p144.json" "$FAKE_RANDR"
stub wlr-randr 'exec python3 -I '"$SD"'/fake_randr.py "$@"'; stub kawa-wallpaper; stub sleep
rc 0 kawa-display --hotplug
eq "$(cache)" "" "the bus list dropped"
kawa-brightness +10; eq "$(cache)" 5; eq "$(b 5)" 70 "the monitor joins at the panel's 70 %"

# ── misuse, environment ──────────────────────────────────────────────────────
case_ "--help (0); misuse (2) before any monitor is asked — no notice, no wait for detection"
setup; export DDC_BUSES=""
out=$(kawa-brightness --help); r=$?; eq "$r" 0; has "$out" "kawa-brightness +10|-10"
for a in up +1000 -1000 1000 abc 4.5 '' ; do
  [[ -z $a ]] && continue
  rc 2 kawa-brightness "$a"
done
eq "$(notice)" ""; eq "$(detects)" 0
case_ "XDG_RUNTIME_DIR unset: could not (1)"
( unset XDG_RUNTIME_DIR; kawa-brightness +10 ) 2>/dev/null; eq "$?" 1

done_
