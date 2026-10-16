#!/usr/bin/env bash
# tests/status/test_audio.sh — kawa-audio, the volume popup (Super+A, a click on the bar's
# volume): the outputs and inputs from pw-dump, louder/quieter/mute that keep it open, a
# device picked made the default. PipeWire is fake_pw.py's machine (fixtures/pw.json: an
# analog output and input, an HDMI output, and 60-share.conf's two "Share" loopbacks, which
# wpctl lists under Filters); the menu is fake_menu (rows kept, answers from a list).
. "$(dirname "$0")/lib.sh"
setup() {
  box; pw_world; notices; . "$HOME/.config/fedokawaii/icons.sh"
  export MENU=$TMP/menu; mkdir -p "$MENU"; : >"$MENU/answers"
  stub kawa-menu 'exec bash '"$SD"'/fake_menu "$@"'; stub setsid; stub pavucontrol
}
answers() { printf '%s\n' "$@" >"$MENU/answers"; }
rows() { cat "$MENU/rows.${1:-1}" 2>/dev/null; }
opened() { cat "$MENU/n" 2>/dev/null || echo 0; }
arg() { grep -A1 -x -- "$2" "$MENU/args.$1" | sed -n 2p; }       # arg N --title → its value
note() { grep '^NOTICE [0-9]* desktop ' "$NOTIFY_STATE/log" 2>/dev/null | tail -n 1 | cut -d'|' -f2-; }
dev() { pw_edit "st['nodes'].append({'id': $1, 'class': '$2', 'name': '$3', 'desc': $4, 'prio': ${5:-100}, 'vol': 1.0})"; }
sink=alsa_output.pci-0000_0e_00.4.analog-stereo

# ── what it lists ────────────────────────────────────────────────────────────
case_ "the rows: louder, quieter, mute; the outputs (current ticked), the inputs, mic, mixer"
setup; answers esc
rc 0 kawa-audio
r=$(rows)
eq "$(sed -n 1,3p <<<"$r")" "$ICON_VOL_UP  louder"$'\n'"$ICON_VOL_DOWN  quieter"$'\n'"$ICON_SPEAKER_OFF  mute"
has "$(sed -n 4p <<<"$r")" "── output ──"
eq "$(sed -n 5p <<<"$r")" "$ICON_BOX_ON  Starship/Matisse HD Audi…" "the current output, ticked, its name cut to 25 characters"
eq "$(sed -n 6p <<<"$r")" "$ICON_BOX_OFF  Navi 31 HDMI/DP Audio Di…"
has "$(sed -n 7p <<<"$r")" "── input ──"
eq "$(sed -n 8p <<<"$r")" "$ICON_BOX_ON  Starship/Matisse HD Audi…"
eq "$(sed -n 9,10p <<<"$r")" "$ICON_MIC_OFF  mute microphone"$'\n'"$ICON_SLIDERS  mixer…"
eq "$(wc -l <<<"$r")" 10
case_ "the Filters part: Share and Share (as microphone) are never offered, nor the loopbacks' streams"
lacks "$r" "Share"; lacks "$r" "share_"
case_ "every row fits the menu (29 of its 30 columns: fuzzel keeps the last for its …), the title all 30"
fits "$r" 29
fits "$(arg 1 --title)" 30
case_ "the title: the speaker, the level bar, 40 %"
t=$(arg 1 --title)
has "$t" "$ICON_SPEAKER  "; has "$t" " 40%"
lv=""; levelbar lv 20 40; has "$t" "$lv" "the level as the menus' framed bar"

case_ "muted: 'unmute' instead of 'mute', the title says off"
setup; pw_edit "node('$sink')['mute'] = True"; answers esc
kawa-audio
has "$(rows)" "$ICON_SPEAKER  unmute"; has "$(arg 1 --title)" " off"
case_ "the microphone muted: 'unmute microphone'"
setup; pw_edit "node('alsa_input.pci-0000_0e_00.4.analog-stereo')['mute'] = True"; answers esc
kawa-audio
has "$(rows)" "$ICON_MIC  unmute microphone"

case_ "above 100 %: the title shows the real level, the bar full"
setup; pw_edit "node('$sink')['vol'] = 1.5"; answers esc
kawa-audio
t=$(arg 1 --title); has "$t" "150%"; levelbar lv 20 100; has "$t" "$lv"; fits "$t" 30

case_ "Volume: 0.00: 0 %, an empty bar"
setup; pw_edit "node('$sink')['vol'] = 0"; answers esc
kawa-audio
t=$(arg 1 --title); has "$t" "  0%"; levelbar lv 20 0; has "$t" "$lv"

# ── what each row does ───────────────────────────────────────────────────────
case_ "louder: 5 % up, the menu reopens on the same row; Esc ends it"
setup; answers 0 esc
rc 0 kawa-audio
eq "$(pw_vol sink)" 0.45; eq "$(opened)" 2
eq "$(arg 2 --select)" 0 "the same row picked again"; has "$(arg 2 --title)" " 45%"
case_ "louder, held on (tapped 15 times): stops at 100 %"
setup; answers 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 esc
kawa-audio; eq "$(pw_vol sink)" 1.00
case_ "louder above 100 %: leaves it (never pulled down)"
setup; pw_edit "node('$sink')['vol'] = 1.3"; answers 0 esc
kawa-audio; eq "$(pw_vol sink)" 1.30
case_ "quieter; mute; mute microphone — each keeps the menu open"
setup; answers 1 2 "~mute microphone" esc
kawa-audio
eq "$(pw_vol sink)" "0.35 [MUTED]"; eq "$(pw_vol source)" "0.80 [MUTED]"; eq "$(opened)" 4
has "$(rows 3)" "$ICON_SPEAKER  unmute" "the row says what it will do now"

case_ "another output picked: the default, a notice says so, the menu closes"
setup; answers "~Navi 31"
rc 0 kawa-audio
called 'wpctl set-default 73'
eq "$(note)" " $ICON_SPEAKER  Audio | Navi 31 HDMI/DP Audio Digital Stereo (HDMI) is now the output" "the full name, not the cut one"
eq "$(opened)" 1
case_ "the current output picked: nothing happens, the menu stays"
setup; answers 4 esc
kawa-audio; not_called 'set-default'; eq "$(opened)" 2
case_ "a heading picked: nothing, the menu stays"
setup; answers 3 esc
kawa-audio; not_called 'set-default'; eq "$(opened)" 2

case_ "a USB microphone picked as the input"
setup; dev 90 Audio/Source alsa_input.usb-BLUE_Yeti '"Yeti Stereo Microphone"'; answers "~Yeti"
kawa-audio
called 'wpctl set-default 90'; has "$(note)" "Yeti Stereo Microphone is now the input"

case_ "an output unplugged while the menu was open: no false notice, the menu shows what is left"
setup; answers "~Navi 31" esc
printf '%s\n' "python3 -I - <<'EOF'
import json; f='$FAKE_PW'; st=json.load(open(f))
st['nodes'] = [n for n in st['nodes'] if n['id'] != 73]; json.dump(st, open(f, 'w'))
EOF" >"$MENU/hook.1"
rc 0 kawa-audio
eq "$(note)" "" "no notice"; eq "$(opened)" 2; lacks "$(rows 2)" "Navi 31"

case_ "mixer…: pavucontrol on its own, the menu closes"
setup; answers "~mixer"
rc 0 kawa-audio; called 'setsid -f pavucontrol'; eq "$(opened)" 1

case_ "Esc: nothing changed"
setup; answers esc
rc 0 kawa-audio; not_called 'wpctl set'

# ── odd names ────────────────────────────────────────────────────────────────
odd='Tom & Jerry "Mic" <USB> $(touch /tmp/kawa-pwned) `id` \\ ü'
case_ "a name with markup, quotes, \$( ), backticks, a backslash: shown as it is, never run"
setup
pw_edit "st['nodes'].append({'id': 91, 'class': 'Audio/Sink', 'name': 'odd', 'desc': '''$odd''', 'prio': 50, 'vol': 1.0})"
answers "~Tom & Jerry"
kawa-audio
has "$(rows)" "$ICON_BOX_OFF  Tom & Jerry \"Mic\" <USB> …" "cut at 25 characters"
called 'wpctl set-default 91'
eq "$(note)" " $ICON_SPEAKER  Audio | Tom &amp; Jerry \"Mic\" &lt;USB&gt; \$(touch /tmp/kawa-pwned) \`id\` \\ ü is now the output" \
  "the notice's body escaped for mako's markup, the backslash single"
[[ ! -e /tmp/kawa-pwned ]] && _ok || { _no "a device name ran as a command"; rm -f /tmp/kawa-pwned; }

case_ "a tab or a line break in a name: one row, a space in its place"
setup; dev 92 Audio/Sink tabbed '"Desk\tSpeakers\nLeft"'; answers esc
kawa-audio
has "$(rows)" "$ICON_BOX_OFF  Desk Speakers Left"
eq "$(wc -l <"$MENU/rows.1")" 11 "still one row per device"

case_ "Arabic and Japanese names, long ones cut to 25 characters, never mid-character"
setup
dev 93 Audio/Sink bluez_output.1 '"سماعات محمد اللاسلكية الجديدة من سوني"'
dev 94 Audio/Sink bluez_output.2 '"ソニーのワイヤレスノイズキャンセリングヘッドホン"'
dev 95 Audio/Sink short '"-rf"'
answers esc
kawa-audio; r=$(rows)
has "$r" "$ICON_BOX_OFF  سماعات محمد اللاسلكية ال…"
has "$r" "$ICON_BOX_OFF  ソニーのワイヤレスノイズキャンセリングヘッドホン"
has "$r" "$ICON_BOX_OFF  -rf" "a name starting with a dash"
fits "$(grep -v ソニー <<<"$r")" 29
case_ "… also under LC_ALL=C (byte counting must not cut a letter in half)"
setup; dev 93 Audio/Sink bluez_output.1 "\"Moh's سماعات محمد اللاسلكية الجديدة\""; answers esc
LC_ALL=C kawa-audio
has "$(rows)" "$ICON_BOX_OFF  Moh's سماعات محمد اللاسل…"
[[ $(cols "$(rows)") != *bad* ]] && _ok || _no "a row is not valid UTF-8"

case_ "a very long name: cut with … to fit"
setup; dev 96 Audio/Sink long "'$(printf 'Speaker%.0s' {1..40})'"; answers esc
kawa-audio; fits "$(rows)" 29

case_ "a device with no description: its nick, else its node name"
setup
pw_edit "st['nodes'].append({'id': 97, 'class': 'Audio/Sink', 'name': 'alsa_output.usb-dac', 'prio': 50, 'vol': 1.0, 'props': {'node.nick': 'USB DAC'}})"
pw_edit "st['nodes'].append({'id': 98, 'class': 'Audio/Sink', 'name': 'bare_sink', 'prio': 50, 'vol': 1.0})"
answers esc; kawa-audio
has "$(rows)" "$ICON_BOX_OFF  USB DAC"; has "$(rows)" "$ICON_BOX_OFF  bare_sink"

# ── how many devices ─────────────────────────────────────────────────────────
case_ "one output, one input: just those two, ticked"
setup; pw_edit "st['nodes'] = [n for n in st['nodes'] if n['id'] != 73]"; answers esc
kawa-audio
eq "$(grep -c "$ICON_BOX_ON" <<<"$(rows)")" 2; eq "$(grep -c "$ICON_BOX_OFF" <<<"$(rows)")" 0
case_ "Bluetooth headphones connected: listed, and ticked (WirePlumber made them the default)"
setup; pw_edit "st['nodes'].append($BT)"; answers esc
kawa-audio
has "$(rows)" "$ICON_BOX_ON  WH-1000XM4"; has "$(rows)" "$ICON_BOX_OFF  Starship"
has "$(arg 1 --title)" " 35%" "the title is the headphones' level"
case_ "no sound card at all (Share is the default then): no device rows, Share still not offered, nothing breaks"
setup; pw_edit "st['nodes'] = [n for n in st['nodes'] if not n['name'].startswith('alsa')]"; answers 0 esc
rc 0 kawa-audio
lacks "$(rows)" "$ICON_BOX_ON"; lacks "$(rows)" "$ICON_BOX_OFF"; lacks "$(rows)" Share
eq "$(wc -l <"$MENU/rows.1")" 7 "the volume rows, two headings, mic, mixer"
case_ "no output and no default at all: the menu opens, the title says 0 %"
setup; pw_edit "st['nodes'] = [n for n in st['nodes'] if n['class'] != 'Audio/Sink']"; answers 0 esc
rc 0 kawa-audio
has "$(arg 1 --title)" "  0%"

case_ "an echo-cancel filter (WirePlumber lists it under Filters too): its sink and source are choices, its streams are not"
setup
dev 100 Audio/Sink echo-cancel-sink '"Echo-Cancel Sink"' 50
dev 101 Audio/Source echo-cancel-source '"Echo-Cancel Source"' 50
dev 102 Stream/Input/Audio echo-cancel-capture '"Echo-Cancel Capture"'
dev 103 Stream/Output/Audio echo-cancel-playback '"Echo-Cancel Playback"'
answers esc; kawa-audio
has "$(rows)" "$ICON_BOX_OFF  Echo-Cancel Sink"; has "$(rows)" "$ICON_BOX_OFF  Echo-Cancel Source"
lacks "$(rows)" Capture; lacks "$(rows)" Playback

case_ "PipeWire not running: a notice says so, no menu, could not (1)"
setup; pw_edit "st['running'] = False"
rc 1 kawa-audio
has "$(note)" "PipeWire is not running"; eq "$(opened)" 0

# ── misuse, environment ──────────────────────────────────────────────────────
case_ "--help (0) and an unknown argument (2): no menu"
setup
out=$(kawa-audio --help); r=$?
eq "$r" 0; has "$out" "kawa-audio"
rc 2 kawa-audio --frobnicate
eq "$(opened)" 0

case_ "Turkish and Arabic locales: the title's level is still 45 %"
for loc in tr_TR.UTF-8 ar_EG.UTF-8; do
  setup; pw_edit "node('$sink')['vol'] = 0.45"; answers esc
  locale_ok "$loc" || { skip "no $loc here"; continue; }
  LC_ALL=$loc kawa-audio 2>/dev/null
  has "$(arg 1 --title)" " 45%" "$loc"
done

done_
