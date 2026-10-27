#!/usr/bin/env bash
# tests/status/test_volume.sh — the volume keys (kawa-volume up|down|mute|mic) and Super+scroll
# (src/dwl/config.h's axes, run as dwl runs them: sh -c) against a fake PipeWire: the machine
# of fixtures/pw.json, wpctl answering as WirePlumber 0.5's does (fake_pw.py). The level
# display is the real kawa-osd, asking lib.sh's stand-in for the panel: osd is the last thing
# asked of it, as ICON|PCT|off (the speaker for the level, the number, "off" while muted).
# A key sends no notice.
. "$(dirname "$0")/lib.sh"
setup() { box; pw_world; osd_panel; . "$HOME/.config/fedokawaii/icons.sh"; }
level() { pw_edit "node('$1')['vol'] = $2"; }                      # level NODE 0.40
sink=alsa_output.pci-0000_0e_00.4.analog-stereo
# the Super+scroll commands, word for word from config.h
axis() { sed -n "s/.*{ MODKEY, Axis$1, *spawn, SHCMD(\"\\(.*\\)\") },.*/\\1/p" "$REPO/src/dwl/config.h"; }
UP=$(axis Up) DOWN=$(axis Down)

# ── wpctl's answers, as the keys read them ───────────────────────────────────
case_ "Volume: 0.40 → up: 0.45, the panel is asked to show 45 % (the speaker with two waves, as the sound panel's meter), and no notice is sent"
setup
rc 0 kawa-volume up
eq "$(pw_vol sink)" 0.45
eq "$(osd)" "$ICON_VOL_2|45|"
not_called '^notify-send '
case_ "… down: 0.40 again"
rc 0 kawa-volume down
eq "$(pw_vol sink)" 0.40; eq "$(osd)" "$ICON_VOL_2|40|"

case_ "Volume: 0.40 [MUTED] → mute: unmuted, the level shows; again: muted, 'off'"
setup; pw_edit "node('$sink')['mute'] = True"
rc 0 kawa-volume mute
eq "$(pw_vol sink)" 0.40; eq "$(osd)" "$ICON_VOL_2|40|"
rc 0 kawa-volume mute
eq "$(pw_vol sink)" "0.40 [MUTED]"; eq "$(osd)" "$ICON_VOL_MUTE|40|off"

case_ "muted, then up: unmuted and one step louder"
rc 0 kawa-volume up
eq "$(pw_vol sink)" 0.45; eq "$(osd)" "$ICON_VOL_2|45|" "no 'off' any more"
case_ "muted, then down: quieter, still muted ('off')"
pw_edit "node('$sink')['mute'] = True"
rc 0 kawa-volume down
eq "$(pw_vol sink)" "0.40 [MUTED]"; eq "$(osd)" "$ICON_VOL_MUTE|40|off"

case_ "Volume: 1.50 (the mixer goes to 153 %) → up leaves it there, never pulled down to 100"
setup; level "$sink" 1.5
rc 0 kawa-volume up
eq "$(pw_vol sink)" 1.50; eq "$(osd)" "$ICON_VOL_4|150|"
not_called 'wpctl set-volume -l'
case_ "… muted at 150 %: up unmutes it, still 150"
pw_edit "node('$sink')['mute'] = True"
rc 0 kawa-volume up
eq "$(pw_vol sink)" 1.50; eq "$(osd)" "$ICON_VOL_4|150|"
case_ "… down from 150: 145"
rc 0 kawa-volume down
eq "$(pw_vol sink)" 1.45

case_ "Volume: 0.97 → up stops at 1.00; at 1.00, up does nothing"
setup; level "$sink" 0.97
kawa-volume up; eq "$(pw_vol sink)" 1.00
kawa-volume up; eq "$(pw_vol sink)" 1.00; eq "$(osd)" "$ICON_VOL_4|100|"

case_ "Volume: 0.00 → down stays 0, the speaker without a wave; up: 5 %, one wave"
setup; level "$sink" 0
kawa-volume down; eq "$(pw_vol sink)" 0.00; eq "$(osd)" "$ICON_VOL_0|0|"
kawa-volume up; eq "$(pw_vol sink)" 0.05; eq "$(osd)" "$ICON_VOL_1|5|"

case_ "the speaker for the level: none at 0, one to 25 %, two to 50, three to 75, four above (as the bar's and the sound panel's), at every edge; crossed out while muted"
setup
for t in 0.00:up:5:1 0.20:up:25:1 0.21:up:26:2 0.45:up:50:2 0.46:up:51:3 0.70:up:75:3 0.71:up:76:4 0.99:up:100:4 \
         0.05:down:0:0 0.30:down:25:1 0.31:down:26:2 0.55:down:50:2 0.56:down:51:3 0.80:down:75:3 0.81:down:76:4; do
  IFS=: read -r from key pct icon <<<"$t"
  level "$sink" "$from"; kawa-volume "$key"
  v=ICON_VOL_$icon
  eq "$(osd)" "${!v}|$pct|" "$key from $from"
done
level "$sink" 0.40; pw_edit "node('$sink')['mute'] = True"; kawa-volume down
eq "$(osd)" "$ICON_VOL_MUTE|35|off" "muted: crossed out, whatever the level"

# ── a held key ───────────────────────────────────────────────────────────────
case_ "a held key, 20 presses in a row from 40 %: 100 % exactly, never above; the panel asked once a press, each time the level it left, no notice"
setup
peak=0
for _ in {1..20}; do
  kawa-volume up
  v=$(pw_vol sink); v=${v/./}; ((10#$v > peak)) && peak=$((10#$v))
done
eq "$(pw_vol sink)" 1.00; eq "$peak" 100 "the highest level reached"
eq "$(osd_raw | awk '{ print $3 }' | tr '\n' ' ')" "45 50 55 60 65 70 75 80 85 90 95 100 100 100 100 100 100 100 100 100 " "20 requests, in order"
not_called '^notify-send '
eq "$(osd)" "$ICON_VOL_4|100|"
case_ "… and 20 down: 0, never below"
for _ in {1..20}; do kawa-volume down; done
eq "$(pw_vol sink)" 0.00; eq "$(osd)" "$ICON_VOL_0|0|"; eq "$(osd_raw | wc -l)" 40 "one request a press"

case_ "20 presses at once (the key repeats faster than wpctl answers): extra ones dropped, asking nothing; the last request is where it ended"
setup
for _ in {1..20}; do kawa-volume up & done; wait
v=$(pw_vol sink)
[[ $v =~ ^0\.(4[05]|[5-9][05])$|^1\.00$ ]] && _ok || _no "level $v is not 40 % plus whole steps, at most 100"
eq "$(osd | cut -d'|' -f2)" "$((10#${v/./}))" "the last request is the level it ended at"
n=$(grep -c 'set-volume' "$FAKE_PW.log")
eq "$(osd_raw | wc -l)" "$n" "one request per change that went through"

case_ "no panel running (kawa-osd finds no fifo: 1): the level still changes, and that is done (0)"
setup; rm -f "$XDG_RUNTIME_DIR/kawa-panel.in"
rc 0 kawa-volume up
eq "$(pw_vol sink)" 0.45
eq "$(osd_raw)" "" "nothing was asked of anyone"

case_ "a stale lock from a run that was killed mid-way: the next press works"
setup; : >"$XDG_RUNTIME_DIR/kawa-volume.lock"
rc 0 kawa-volume up; eq "$(pw_vol sink)" 0.45

# ── devices coming and going ─────────────────────────────────────────────────
case_ "Bluetooth headphones connect: the keys follow them, the speakers keep their level"
setup
pw_edit "st['nodes'].append($BT)"
kawa-volume up
eq "$(pw_vol sink)" 0.40 "the headphones: 35 → 40"
eq "$(wpctl get-volume 62)" "Volume: 0.40" "the speakers untouched"
case_ "… and disconnect: the keys go back to the speakers"
pw_edit "st['nodes'] = [n for n in st['nodes'] if not n['name'].startswith('bluez')]"
kawa-volume up
eq "$(pw_vol sink)" 0.45
case_ "… gone between reading the level and showing it: nothing to show, no error"
setup
stub wpctl 'case "$*" in "get-volume @DEFAULT_AUDIO_SINK@") [ -e "$TMP/gone" ] && exit 0; : >"$TMP/gone" ;; esac
exec python3 -I '"$SD"'/fake_pw.py wpctl "$@"'
kawa-volume up 2>/dev/null; r=$?
[[ $r == [01] ]] && _ok || _no "exit $r"
eq "$(osd)" "" "nothing asked"

case_ "no sound card (only the Share loopback is left, WirePlumber makes it the default): the keys work on it"
setup
pw_edit "st['nodes'] = [n for n in st['nodes'] if not n['name'].startswith('alsa')]"
rc 0 kawa-volume up
eq "$(wpctl get-volume 37)" "Volume: 1.00" "Share stays at 100"

case_ "no output at all (wpctl: no default): could not (1), nothing shown"
setup
pw_edit "st['nodes'] = [n for n in st['nodes'] if n['class'] != 'Audio/Sink']"
rc 1 kawa-volume up
rc 1 kawa-volume down
rc 1 kawa-volume mute
eq "$(osd)" ""

case_ "PipeWire not running: could not (1), nothing shown"
setup; pw_edit "st['running'] = False"
rc 1 kawa-volume up
rc 1 kawa-volume mic
eq "$(osd)" ""

# ── the microphone ───────────────────────────────────────────────────────────
case_ "mic: muted, the crossed-out microphone and 'off'; again: back on at its level"
setup
rc 0 kawa-volume mic
eq "$(pw_vol source)" "0.80 [MUTED]"
eq "$(osd)" "$ICON_MIC_OFF|80|off"
rc 0 kawa-volume mic
eq "$(osd)" "$ICON_MIC|80|"
eq "$(pw_vol sink)" 0.40 "the output untouched"

case_ "mic with no microphone (Share's monitor is never the default): could not (1), nothing shown"
setup
pw_edit "st['nodes'] = [n for n in st['nodes'] if n['class'] != 'Audio/Source']"
rc 1 kawa-volume mic
eq "$(wpctl get-volume 37)" "Volume: 1.00" "Share untouched"
eq "$(osd)" ""

# ── Super+scroll (config.h) ──────────────────────────────────────────────────
case_ "Super+scroll: the commands are in config.h"
[[ -n $UP && -n $DOWN ]] && _ok || _no "no AxisUp/AxisDown spawn line found"
case_ "Super+scroll up from 40 %: 42 %; from 99 %: 100 %; from 100 %: stays"
setup
sh -c "$UP"; eq "$(pw_vol sink)" 0.42
level "$sink" 0.99; sh -c "$UP"; eq "$(pw_vol sink)" 1.00
sh -c "$UP"; eq "$(pw_vol sink)" 1.00
case_ "Super+scroll up above 100 % (only from 0.xx): 150 % stays 150 %"
level "$sink" 1.5; sh -c "$UP"; eq "$(pw_vol sink)" 1.50
case_ "Super+scroll down: 2 % quieter, also above 100 %; never below 0"
sh -c "$DOWN"; eq "$(pw_vol sink)" 1.48
level "$sink" 0.01; sh -c "$DOWN"; eq "$(pw_vol sink)" 0.00
case_ "Super+scroll up, muted: unmuted and 2 % louder, like the up key"
level "$sink" 0.5; pw_edit "node('$sink')['mute'] = True"
sh -c "$UP"; eq "$(pw_vol sink)" "0.52"
case_ "Super+scroll asks for the level display too (also in fullscreen, where the bar is hidden)"
setup; sh -c "$UP"; eq "$(osd)" "$ICON_VOL_2|42|"
case_ "a step of its own: only after up or down, 1–99"
rc 2 kawa-volume up 0; rc 2 kawa-volume up 100; rc 2 kawa-volume down x; rc 2 kawa-volume mute 2
rc 2 kawa-volume up 2 3
eq "$(pw_vol sink)" 0.42 "a refused step changes nothing"

# ── misuse, environment ──────────────────────────────────────────────────────
case_ "misuse: no command, an unknown one (2); --help (0) — nothing changed"
setup
rc 2 kawa-volume
rc 2 kawa-volume sideways
out=$(kawa-volume --help); r=$?
eq "$r" 0; has "$out" "kawa-volume up|down [STEP] | mute | mic"
eq "$(pw_vol sink)" 0.40; not_called 'wpctl set'

case_ "XDG_RUNTIME_DIR unset: could not (1)"
( unset XDG_RUNTIME_DIR; kawa-volume up ) 2>/dev/null; eq "$?" 1

case_ "Turkish and Arabic locales: the same steps and the same request"
for loc in tr_TR.UTF-8 ar_EG.UTF-8; do
  setup
  locale_ok "$loc" || { skip "no $loc here"; continue; }
  LC_ALL=$loc kawa-volume up
  eq "$(pw_vol sink)" 0.45 "$loc"; eq "$(osd)" "$ICON_VOL_2|45|" "$loc"
done

done_
