#!/usr/bin/env bash
# tests/status/test_audio.sh — the sound panel's machine side (kawa-panel --sound draws it,
# Super+A or a click on the bar's volume; kawa-quick knows the machine): what --state sound
# says — the output's level and mute, the microphone's, every output and input from pw-dump
# with the default ticked, never "Share" — and what each --do does: an output or input picked
# made the default (wpctl set-default), mute and the microphone's mute switched over, the
# mixer opened. PipeWire is fake_pw.py's machine (fixtures/pw.json: an analog output and
# input, an HDMI output, and 60-share.conf's two "Share" loopbacks, which wpctl lists under
# Filters). Then the mixer, wiremix: its theme files, its window, the manifest. And the old
# sound menu, kawa-audio: gone, its installed copy retired.
. "$(dirname "$0")/lib.sh"
setup() {
  box; pw_world; . "$HOME/.config/fedokawaii/icons.sh"
  stub kawa-term; stub kawa-brightness
}
sq() { kawa-quick --state sound; }
sv() { sq | sed -n "s/^$1\t//p"; }                       # sv KEY — its value now
devs() { sq | grep -E $'^(output|input)\t' | cut -f1-4; }   # the device lines: kind, id, default, description
names() {   # the short names the panel shows (kawa-panel's parse_sound of what --state sound says)
  sq | python3 -I -c 'import importlib.machinery as m, importlib.util as u, sys
sys.dont_write_bytecode = True
l = m.SourceFileLoader("kp", sys.argv[1]); k = u.module_from_spec(u.spec_from_loader("kp", l)); l.exec_module(k)
s = k.parse_sound(sys.stdin.read())
print(" | ".join(n + ("*" if d else "") for _, d, n in s["outputs"]), "/", " | ".join(n + ("*" if d else "") for _, d, n in s["inputs"]))' "$REPO/bin/kawa-panel"
}
dev() { pw_edit "st['nodes'].append({'id': $1, 'class': '$2', 'name': '$3', 'desc': $4, 'prio': ${5:-100}, 'vol': 1.0})"; }
sink=alsa_output.pci-0000_0e_00.4.analog-stereo

# ── what it says ─────────────────────────────────────────────────────────────
case_ "--state sound: the level, mute, the microphone, then the outputs and the inputs (the default ticked: 1)"
setup
rc 0 kawa-quick --state sound
eq "$(sq | cut -f1-4)" "$(printf '%s\n' $'sound\t40%' $'muted\toff' $'mic\ton' \
  $'output\t62\t1\tStarship/Matisse HD Audio Controller Analog Stereo' \
  $'output\t73\t0\tNavi 31 HDMI/DP Audio Digital Stereo (HDMI)' \
  $'input\t67\t1\tStarship/Matisse HD Audio Controller Analog Stereo')"
eq "$(sq | grep -c $'^output\t[0-9]*\t[01]\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*$')" 2 "each device: nine fields (the description, port, nick, card, profile, API after it)"
case_ "the owner's machine (his report: an MSI board's ALC1220 on the Ryzen's HD audio controller, an RX 9060 XT's HDMI to an LG ULTRAGEAR): each device with its port, nick, card, profile"
box; export FAKE_PW=$TMP/pw.json; cp "$SD/fixtures/pw-owner.json" "$FAKE_PW"
stub wpctl 'exec python3 -I '"$SD"'/fake_pw.py wpctl "$@"'; stub pw-dump 'exec python3 -I '"$SD"'/fake_pw.py pw-dump "$@"'
eq "$(sq | grep -E $'^(output|input)\t')" "$(printf '%s\n' \
  $'output\t62\t1\tRyzen HD Audio Controller Analog Stereo\tLine Out\tALC1220 Analog\tRyzen HD Audio Controller\tAnalog Stereo\talsa' \
  $'output\t73\t0\tNavi 48 HDMI/DP Audio Controller Digital Stereo (HDMI)\tHDMI / DisplayPort\tLG ULTRAGEAR\tNavi 48 HDMI/DP Audio Controller\tDigital Stereo (HDMI)\talsa' \
  $'input\t67\t1\tRyzen HD Audio Controller Analog Stereo\tRear Microphone\tALC1220 Analog\tRyzen HD Audio Controller\tAnalog Stereo\talsa')" \
  "the port is the card's active route for that node (its direction and card.profile.device)"
eq "$(names)" "line out · analog* | LG ULTRAGEAR · HDMI / rear mic*" "… and the panel's short names of them"
case_ "headphones plugged in the front: the route changes, so does the name; a front microphone of its own"
pw_edit "st['devices'][0]['routes'][0].update(name='analog-output-headphones', description='Headphones')"
pw_edit "st['devices'][0]['routes'].append({'direction': 'Input', 'device': 5, 'name': 'analog-input-front-mic', 'description': 'Front Microphone'})"
pw_edit "st['nodes'].append(dict(node('alsa_input.pci-0000_15_00.6.analog-stereo'), id=68, name='alsa_input.pci-0000_15_00.6.analog-stereo-front', prio=100, props=dict(node('alsa_input.pci-0000_15_00.6.analog-stereo')['props'], **{'card.profile.device': 5})))"
eq "$(names)" "headphones · analog* | LG ULTRAGEAR · HDMI / rear mic* | front mic"
case_ "a node whose card pw-dump does not list (or a null device): the port, nick and card empty, nothing breaks"
setup; eq "$(sq | grep $'^output\t73' | cut -f5-9)" $'\tDELL S2721DGF\t\t\talsa'
eq "$(names)" "analog* | DELL S2721DGF · HDMI / analog*"
case_ "the Filters part: Share is never offered, nor its loopback's stream"
lacks "$(sq)" "Share"; lacks "$(sq)" "share_"
case_ "muted: the level still said (the panel keeps its squares, hollow), muted on; the microphone muted"
setup; pw_edit "node('$sink')['mute'] = True"; pw_edit "node('alsa_input.pci-0000_0e_00.4.analog-stereo')['mute'] = True"
eq "$(sv sound) $(sv muted) $(sv mic)" "40% on muted"
case_ "above 100 % (set in the mixer): said as it is"
setup; pw_edit "node('$sink')['vol'] = 1.3"; eq "$(sv sound)" 130%
case_ "--state brightness: the slider's one line"
setup; stub kawa-brightness '[ "$1" = --level ] && echo 55'
eq "$(kawa-quick --state brightness)" $'brightness\t55%'
stub kawa-brightness 'exit 1'; eq "$(kawa-quick --state brightness)" $'brightness\tno DDC/CI'

# ── what each does ───────────────────────────────────────────────────────────
case_ "output ID, input ID: made the default (wpctl set-default ID), --state then ticks it"
setup; rc 0 kawa-quick --do output 73
grep -q '^wpctl set-default 73$' "$FAKE_PW.log" && _ok || _no "no wpctl set-default 73"
eq "$(devs | grep $'^output\t73')" $'output\t73\t1\tNavi 31 HDMI/DP Audio Digital Stereo (HDMI)'
eq "$(devs | grep -c $'\t1\t')" 2 "one output and one input ticked"
setup; dev 90 Audio/Source alsa_input.usb-BLUE_Yeti '"Yeti Stereo Microphone"'
rc 0 kawa-quick --do input 90; eq "$(devs | grep $'^input\t90')" $'input\t90\t1\tYeti Stereo Microphone'
case_ "a device unplugged since the panel read it: could not (1), nothing else changed"
setup; rc 1 kawa-quick --do output 99; eq "$(devs | grep $'\t1\t' | cut -f2 | tr '\n' ' ')" "62 67 "
case_ "an id that is not a number: wrong use (2), wpctl never asked"
setup; for a in x 7x '' -1 '$(id)'; do rc 2 kawa-quick --do output "$a"; done
rc 2 kawa-quick --do input; rc 2 kawa-quick --do output 73 74
grep -qs 'set-default' "$FAKE_PW.log" && _no "wpctl asked" || _ok
case_ "mute, micmute: switched over (wpctl set-mute … toggle), and back"
setup; rc 0 kawa-quick --do mute; eq "$(pw_vol sink)" "0.40 [MUTED]"; eq "$(sv muted)" on
rc 0 kawa-quick --do mute; eq "$(pw_vol sink)" 0.40
rc 0 kawa-quick --do micmute; eq "$(pw_vol source)" "0.80 [MUTED]"; eq "$(sv mic)" muted
rc 2 kawa-quick --do mute extra
case_ "volume N while muted: unmuted and set (the panel's meter)"
setup; pw_edit "node('$sink')['mute'] = True"; rc 0 kawa-quick --do volume 55; eq "$(pw_vol sink)" 0.55
case_ "mixer: wiremix in a floating terminal of its own, one at a time (kawa-term --float's 3 passed on)"
setup; rc 0 kawa-quick --do mixer; called '^kawa-term --float --once mixer mixer 96x29 -- wiremix$'
not_called 'pavucontrol'
stub kawa-term 'exit 3'; rc 3 kawa-quick --do mixer
case_ "sound: the sound panel (kawa-panel --sound)"
setup; stub kawa-panel; rc 0 kawa-quick --do sound
for _ in {1..100}; do grep -q '^kawa-panel' "$CALLS" && break; sleep 0.02; done   # (setsid -f: detached)
called '^kawa-panel --sound$'

# ── odd names ────────────────────────────────────────────────────────────────
odd='Tom & Jerry "Mic" <USB> $(touch /tmp/kawa-pwned) `id` \\ ü'
case_ "a name with markup, quotes, \$( ), backticks, a backslash: said as it is, never run"
setup
pw_edit "st['nodes'].append({'id': 91, 'class': 'Audio/Sink', 'name': 'odd', 'desc': '''$odd''', 'prio': 50, 'vol': 1.0})"
has "$(devs)" $'output\t91\t0\tTom & Jerry "Mic" <USB> $(touch /tmp/kawa-pwned) `id` \\ ü'
[[ ! -e /tmp/kawa-pwned ]] && _ok || { _no "a device name ran as a command"; rm -f /tmp/kawa-pwned; }
case_ "a tab or a line break in a name: one line, a space in its place"
setup; dev 92 Audio/Sink tabbed '"Desk\tSpeakers\nLeft"'
has "$(devs)" $'output\t92\t0\tDesk Speakers Left'; eq "$(devs | wc -l)" 4 "still one line per device"
case_ "Arabic and Japanese names: whole (the panel cuts them to its width, by the font)"
setup; dev 93 Audio/Sink bluez_output.1 '"سماعات محمد اللاسلكية الجديدة من سوني"'; dev 94 Audio/Sink bluez_output.2 '"ソニーのワイヤレスノイズキャンセリングヘッドホン"'
has "$(devs)" $'\tسماعات محمد اللاسلكية الجديدة من سوني'; has "$(devs)" $'\tソニーのワイヤレスノイズキャンセリングヘッドホン'
case_ "a device with no description: its nick, else its node name"
setup
pw_edit "st['nodes'].append({'id': 97, 'class': 'Audio/Sink', 'name': 'alsa_output.usb-dac', 'prio': 50, 'vol': 1.0, 'props': {'node.nick': 'USB DAC'}})"
pw_edit "st['nodes'].append({'id': 98, 'class': 'Audio/Sink', 'name': 'bare_sink', 'prio': 50, 'vol': 1.0})"
has "$(devs)" $'output\t97\t0\tUSB DAC'; has "$(devs)" $'output\t98\t0\tbare_sink'

# ── how many devices ─────────────────────────────────────────────────────────
case_ "Bluetooth headphones connected: listed, and ticked (WirePlumber made them the default)"
setup; pw_edit "st['nodes'].append($BT)"
has "$(devs)" $'output\t81\t1\tWH-1000XM4'; has "$(devs)" $'output\t62\t0\tStarship'
case_ "no sound card at all (Share is the default then): no devices, Share still not offered"
setup; pw_edit "st['nodes'] = [n for n in st['nodes'] if not n['name'].startswith('alsa')]"
eq "$(devs)" ""; lacks "$(sq)" Share; eq "$(sv mic)" none "no microphone: none"
case_ "no output and no default at all: no output, nothing breaks"
setup; pw_edit "st['nodes'] = [n for n in st['nodes'] if n['class'] != 'Audio/Sink']"
rc 0 kawa-quick --state sound; eq "$(sv sound)" "no output"; eq "$(devs | cut -f1 | tr '\n' ' ')" "input "
case_ "an echo-cancel filter: its sink and source are choices, its streams are not"
setup
dev 100 Audio/Sink echo-cancel-sink '"Echo-Cancel Sink"' 50
dev 101 Audio/Source echo-cancel-source '"Echo-Cancel Source"' 50
dev 102 Stream/Input/Audio echo-cancel-capture '"Echo-Cancel Capture"'
dev 103 Stream/Output/Audio echo-cancel-playback '"Echo-Cancel Playback"'
has "$(devs)" $'output\t100\t0\tEcho-Cancel Sink'; has "$(devs)" $'input\t101\t0\tEcho-Cancel Source'
lacks "$(devs)" Capture; lacks "$(devs)" Playback
case_ "PipeWire not running: no output, no microphone, no devices — said, not failed (the panel shows it)"
setup; pw_edit "st['running'] = False"
rc 0 kawa-quick --state sound
eq "$(sq)" "$(printf '%s\n' $'sound\tno output' $'muted\toff' $'mic\tnone')"

# ── an input picked: what records moves with it ──────────────────────────────────────────────
# the owner's machine with Brave in a Meet call recording the default input (a site that names
# its microphone: such a stream does not follow the default alone), and a front microphone
# beside the rear one
call_world() {
  box; export FAKE_PW=$TMP/pw.json; cp "$SD/fixtures/pw-owner.json" "$FAKE_PW"
  stub wpctl 'exec python3 -I '"$SD"'/fake_pw.py wpctl "$@"'; stub pw-dump 'exec python3 -I '"$SD"'/fake_pw.py pw-dump "$@"'
  stub pw-metadata 'exec python3 -I '"$SD"'/fake_pw.py pw-metadata "$@"'
  pw_edit "st['devices'][0]['routes'].append({'direction': 'Input', 'device': 5, 'name': 'analog-input-front-mic', 'description': 'Front Microphone'})
st['nodes'] += [dict(node('alsa_input.pci-0000_15_00.6.analog-stereo'), id=68, name='front', prio=100, props=dict(node('alsa_input.pci-0000_15_00.6.analog-stereo')['props'], **{'card.profile.device': 5})),
  {'id': 120, 'class': 'Stream/Input/Audio', 'name': 'Chromium input', 'desc': 'meet.google.com', 'vol': 1.0, 'props': {'application.name': 'Brave', 'target.object': 'alsa_input.pci-0000_15_00.6.analog-stereo'}}]
st['links'] = [[67, 120]]"
}
brave_from() { python3 -I -c 'import json, sys; st = json.load(open(sys.argv[1])); print(*[o for o, n in st["links"] if n == 120])' "$FAKE_PW"; }
case_ "an input picked while a call records: that microphone the default, the call moved to it at once (still recording: it goes on), the old one's mute carried over"
call_world; pw_edit "node('alsa_input.pci-0000_15_00.6.analog-stereo')['mute'] = True"
eq "$(brave_from)" 67 "Brave records the rear mic"
rc 0 kawa-quick --do input 68
grep -q '^wpctl set-default 68$' "$FAKE_PW.log" && _ok || _no "no set-default 68"
grep -q '^pw-metadata 120 target.object front$' "$FAKE_PW.log" && _ok || _no "Brave not moved"
eq "$(brave_from)" 68 "Brave records the front mic now"
eq "$(devs | grep $'^input' | cut -f2,3 | tr '\n' ' ')" $'67\t0 68\t1 ' "the front mic ticked"
eq "$(sv mic)" muted "muted stays muted"
case_ "…and back: the same the other way; only the call's stream moves, never a card's node or a loopback's"
rc 0 kawa-quick --do input 67; eq "$(brave_from)" 67 "Brave records the rear mic again"
eq "$(grep -c '^pw-metadata' "$FAKE_PW.log")" 2 "one move each way, nothing else"
case_ "an input picked keeps nothing of its own in kawa-state (the default is WirePlumber's: it keeps it across restarts)"
setup; rc 0 kawa-quick --do input 67; eq "$(kawa-state list)" ""
case_ "an input picked with nothing recording: the default, no move asked; a gone id: 1"
setup; rc 0 kawa-quick --do input 67; grep -qs '^pw-metadata' "$FAKE_PW.log" && _no "moved" || _ok
rc 1 kawa-quick --do input 73   # (an output's id is no input)
case_ "test mic: 5 s from the default input (pw-record, stopped by SIGINT so the file is whole), played back, then gone; a notice each half"
setup; notices
stub pw-record 'eval "f=\${$#}"; printf RIFFdata >"$f"; echo "$*" >>"$TMP/rec.args"'
stub pw-play 'cp "$1" "$TMP/played"'
rc 0 kawa-quick --do mictest
eq "$(cat "$TMP/rec.args")" "--channels 1 ${XDG_RUNTIME_DIR:-/run/user/$UID}/kawa-mictest.wav"
eq "$(cat "$TMP/played" 2>/dev/null)" RIFFdata "what was recorded is what plays"
[[ ! -e ${XDG_RUNTIME_DIR:-/run/user/$UID}/kawa-mictest.wav ]] && _ok || _no "the recording left behind"
has "$(cat "$NOTIFY_STATE/log")" "recording 5 seconds"
case_ "test mic: nothing recorded (no microphone): said, 1, nothing played"
setup; notices; stub pw-record 'exit 1'; stub pw-play 'touch "$TMP/played"'
rc 1 kawa-quick --do mictest; [[ ! -e $TMP/played ]] && _ok || _no "played nothing"
has "$(cat "$NOTIFY_STATE/log")" "nothing recorded"

# ── use ──────────────────────────────────────────────────────────────────────
case_ "--state takes sound or brightness, nothing else"
setup; rc 2 kawa-quick --state bogus; rc 2 kawa-quick --state sound extra; rc 2 kawa-quick --state ''
case_ "Turkish and Arabic locales: the level still read right"
for loc in tr_TR.UTF-8 ar_EG.UTF-8; do
  setup; pw_edit "node('$sink')['vol'] = 0.95"
  locale_ok "$loc" || { skip "no $loc here"; continue; }
  eq "$(LC_ALL=$loc kawa-quick --state sound 2>/dev/null | sed -n 's/^sound\t//p')" 95% "$loc"
done

# ── the old sound menu: gone ─────────────────────────────────────────────────
case_ "kawa-audio, the fuzzel sound menu, is gone: nothing runs it; theme.sh retires the copy an earlier version installed"
[[ ! -e $REPO/bin/kawa-audio ]] && _ok || _no "bin/kawa-audio still there"
eq "$(grep -rlw 'kawa-audio' "$REPO/bin" "$REPO/configs" "$REPO/src" 2>/dev/null)" "" "no script, config or key runs it"
has "$(cat "$REPO/theme.sh")" "retire .local/bin/kawa-audio 'kawa-audio — the sound menu'"

# ── the mixer itself: wiremix 0.11.0 (Fedora 44's), its theme files and its place ───────────
case_ "the two wiremix.toml are TOML; the theme named is the one defined; only wiremix's own style keys"
# (the style keys of wiremix 0.11.0's [themes.*] — tsowell/wiremix wiremix.toml at v0.11.0; an
# unknown one makes wiremix refuse to start)
keys="default_device default_stream selector tab tab_selected tab_marker list_more node_title node_target volume
volume_empty volume_filled meter_inactive meter_active meter_overload meter_center_inactive meter_center_active
config_device config_profile dropdown_icon dropdown_border dropdown_item dropdown_selected dropdown_more
help_border help_item help_more"
for m in dark light; do
  f=$REPO/configs/home/.config/fedokawaii/themes/$m/wiremix.toml
  out=$(python3 -I - "$f" "$keys" <<'EOF'
import sys, tomllib
f, keys = sys.argv[1], set(sys.argv[2].split())
c = tomllib.load(open(f, "rb"))
t = c["themes"][c["theme"]]
bad = sorted(set(t) - keys)
print("unknown keys:" if bad else "keys ok", *bad)
print("esc exits" if {"key": "Esc", "action": "Exit"} in c["keybindings"] else "no Esc binding")
print("max enforced" if c.get("enforce_max_volume") is True else "max not enforced")
print(len(t), "styles")
EOF
  )
  has "$out" "keys ok" "$m: $out"; has "$out" "esc exits" "$m"; has "$out" "max enforced" "$m"; has "$out" "27 styles" "$m: every key styled"
done
case_ "every colour in them is the palette's of that theme (tools/build-themes.py), and the two differ"
out=$(python3 -I - "$REPO" <<'EOF'
import sys, re, pathlib, importlib.util, tomllib
sys.dont_write_bytecode = True                 # (-I ignores PYTHONDONTWRITEBYTECODE: no __pycache__ in tools/)
repo = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("bt", repo / "tools/build-themes.py")
bt = importlib.util.module_from_spec(spec); spec.loader.exec_module(bt)
for m in ("dark", "light"):
    f = repo / f"configs/home/.config/fedokawaii/themes/{m}/wiremix.toml"
    known = {v for v in bt.P[m].values() if isinstance(v, str) and re.fullmatch(r"[0-9a-f]{6}", v)}
    used = set(re.findall(r'"#([0-9a-fA-F]{6})"', f.read_text()))
    bad = sorted(c for c in used if c.lower() not in known)
    print(m, "ok" if not bad else "foreign: " + " ".join(bad), len(used), "colours")
d = (repo / "configs/home/.config/fedokawaii/themes/dark/wiremix.toml").read_text()
l = (repo / "configs/home/.config/fedokawaii/themes/light/wiremix.toml").read_text()
print("differ" if d != l else "the same file twice")
EOF
)
has "$out" "dark ok"; has "$out" "light ok"; has "$out" "differ"
case_ "wiremix reads ~/.config/wiremix/wiremix.toml: theme.sh links it into the theme in use"
has "$(grep -F 'LINKS=(' -A5 "$REPO/theme.sh")" '"../fedokawaii/current/wiremix.toml:.config/wiremix/wiremix.toml"'
case_ "the window: app-id float, which dwl floats (config.h); the old GUI rules are gone"
has "$(grep -E '^\s*\{ "=float",' "$REPO/src/dwl/config.h")" '1,           -1'
lacks "$(cat "$REPO/src/dwl/config.h")" pavucontrol; lacks "$(cat "$REPO/src/dwl/config.h")" blueman
has "$(grep -F "footclient -a \"\$app\"" "$REPO/bin/kawa-term")" "-a \"\$app\""; has "$(grep -E "^once=.* app=float" "$REPO/bin/kawa-term")" "app=float"
case_ "the manifest: wiremix installed, pavucontrol never again (forbidden) and handed back to dnf (retired)"
m() { (STEAM=yes; . "$REPO/lib/manifest.sh"; eval "$1"); }
has " $(m 'manifest_all amd' | tr '\n' ' ') " " wiremix "; lacks " $(m 'manifest_all amd' | tr '\n' ' ') " " pavucontrol "
has " $(m 'echo "${FORBIDDEN_PKGS[*]}"') " " pavucontrol "; has " $(m 'echo "${RETIRED_PKGS[*]}"') " " pavucontrol "
has "$(grep -E '^wiremix ' "$REPO/tests/static/fixtures/programs.txt")" "manifest  wiremix"
lacks "$(cat "$REPO/tests/static/fixtures/programs.txt")" pavucontrol

done_
