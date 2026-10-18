#!/usr/bin/env bash
# tests/status/test_audio.sh — kawa-audio, the volume popup (Super+A, a click on the bar's
# volume): the outputs and inputs from pw-dump, louder/quieter/mute that keep it open, a
# device picked made the default. PipeWire is fake_pw.py's machine (fixtures/pw.json: an
# analog output and input, an HDMI output, and 60-share.conf's two "Share" loopbacks, which
# wpctl lists under Filters); the menu is fake_menu (rows kept, answers from a list). Then the
# mixer, wiremix: opened in a floating terminal (kawa-float), its theme files, the manifest.
. "$(dirname "$0")/lib.sh"
setup() {
  box; pw_world; notices; . "$HOME/.config/fedokawaii/icons.sh"
  export MENU=$TMP/menu; mkdir -p "$MENU"; : >"$MENU/answers"
  stub kawa-menu 'exec bash '"$SD"'/fake_menu "$@"'; stub setsid; stub kawa-float
}
answers() { printf '%s\n' "$@" >"$MENU/answers"; }
rows() { cat "$MENU/rows.${1:-1}" 2>/dev/null; }
opened() { cat "$MENU/n" 2>/dev/null || echo 0; }
hd() { ( . "$HOME/.config/fedokawaii/width.sh"; heading "$@" ); }   # hd KANJI NAME W — a heading, as width.sh makes it (in a subshell: its cols is not the tests')
arg() { grep -A1 -x -- "$2" "$MENU/args.$1" | sed -n 2p; }       # arg N --title → its value
note() { grep '^NOTICE [0-9]* desktop ' "$NOTIFY_STATE/log" 2>/dev/null | tail -n 1 | cut -d'|' -f2-; }
dev() { pw_edit "st['nodes'].append({'id': $1, 'class': '$2', 'name': '$3', 'desc': $4, 'prio': ${5:-100}, 'vol': 1.0})"; }
sink=alsa_output.pci-0000_0e_00.4.analog-stereo

# ── what it lists ────────────────────────────────────────────────────────────
case_ "the rows: the sound part (louder, quieter, mute, mixer), the outputs (current ticked), the inputs and the microphone — each part headed"
setup; answers esc
rc 0 kawa-audio
r=$(rows)
eq "$(sed -n 1p <<<"$r")" "$(hd 音 sound 34)" "the first part headed too, as Super+U's first"
eq "$(sed -n 2,5p <<<"$r")" "$ICON_VOL_UP  louder"$'\n'"$ICON_VOL_DOWN  quieter"$'\n'"$ICON_SPEAKER_OFF  mute"$'\n'"$ICON_SLIDERS  mixer…"
eq "$(sed -n 6p <<<"$r")" "" "an empty row above each heading but the first"
eq "$(sed -n 7p <<<"$r")" "$(hd 出 output 34)" "a heading as Super+U's: kanji, name, a rule of en dashes (one column each in the font)"
has "$(sed -n 7p <<<"$r")" "出${ICON_GAP}  output –"
eq "$(sed -n 8p <<<"$r")" "$ICON_BOX_ON  Starship/Matisse HD Audio…" "the current output, ticked, its name cut to 28 columns (… is two)"
eq "$(sed -n 9p <<<"$r")" "$ICON_BOX_OFF  Navi 31 HDMI/DP Audio Digi…" "no space before the …"
eq "$(sed -n 10p <<<"$r")" ""
eq "$(sed -n 11p <<<"$r")" "$(hd 入 input 34)"
eq "$(sed -n 12p <<<"$r")" "$ICON_BOX_ON  Starship/Matisse HD Audio…"
eq "$(sed -n 13p <<<"$r")" "$ICON_MIC_OFF  mute microphone"
eq "$(wc -l <<<"$r")" 13
eq "$(arg 1 --select)" 1 "it opens on louder, not on the heading"
case_ "the Filters part: Share is never offered, nor its loopback's stream"
lacks "$r" "Share"; lacks "$r" "share_"
case_ "every row fits the menu (its 34 columns, less the last pixels fuzzel keeps for its …)"
rows_fit "$r" 34
case_ "no title: the level is the bar's, right above the menu"
eq "$(arg 1 --title)" "" "no --title"; lacks "$(cat "$MENU/args.1")" "--title"

case_ "muted: 'unmute' instead of 'mute'"
setup; pw_edit "node('$sink')['mute'] = True"; answers esc
kawa-audio
has "$(rows)" "$ICON_SPEAKER  unmute"
case_ "muted, then louder: unmuted and up a step — as the volume key (kawa-volume, one tool)"
setup; pw_edit "node('$sink')['mute'] = True"; answers 1 esc
kawa-audio; eq "$(pw_vol sink)" 0.45 "unmuted, 5 % up"
case_ "the microphone muted: 'unmute microphone'"
setup; pw_edit "node('alsa_input.pci-0000_0e_00.4.analog-stereo')['mute'] = True"; answers esc
kawa-audio
has "$(rows)" "$ICON_MIC  unmute microphone"


# ── what each row does ───────────────────────────────────────────────────────
case_ "louder: 5 % up, the menu reopens on the same row; Esc ends it"
setup; answers 1 esc
rc 0 kawa-audio
eq "$(pw_vol sink)" 0.45; eq "$(opened)" 2
eq "$(arg 2 --select)" 1 "the same row picked again"
case_ "louder, held on (tapped 15 times): stops at 100 %"
setup; answers 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 esc
kawa-audio; eq "$(pw_vol sink)" 1.00
case_ "louder above 100 %: leaves it (never pulled down)"
setup; pw_edit "node('$sink')['vol'] = 1.3"; answers 1 esc
kawa-audio; eq "$(pw_vol sink)" 1.30
case_ "quieter; mute; mute microphone — each keeps the menu open"
setup; answers 2 3 "~mute microphone" esc
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
setup; answers 7 esc
kawa-audio; not_called 'set-default'; eq "$(opened)" 2
case_ "a heading picked: nothing, the menu stays"
setup; answers 6 esc
kawa-audio; not_called 'set-default'; eq "$(opened)" 2
eq "$(arg 2 --select)" 7 "again, on its part's first entry (the current output)"

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

case_ "mixer…: wiremix in a floating terminal of its own, one at a time; the menu closes"
setup; answers "~mixer"
rc 0 kawa-audio; called '^kawa-float --once mixer mixer 96x29 -- wiremix$'; eq "$(opened)" 1
not_called 'setsid|pavucontrol'
case_ "…while the mixer is open already: nothing more opens (kawa-float's 3 is passed on)"
setup; answers "~mixer"; stub kawa-float 'exit 3'
rc 3 kawa-audio; eq "$(opened)" 1

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
has "$(rows)" "$ICON_BOX_OFF  Tom & Jerry \"Mic\" <USB> \$(…" "cut at 28 columns"
called 'wpctl set-default 91'
eq "$(note)" " $ICON_SPEAKER  Audio | Tom &amp; Jerry \"Mic\" &lt;USB&gt; \$(touch /tmp/kawa-pwned) \`id\` \\ ü is now the output" \
  "the notice's body escaped for mako's markup, the backslash single"
[[ ! -e /tmp/kawa-pwned ]] && _ok || { _no "a device name ran as a command"; rm -f /tmp/kawa-pwned; }

case_ "a tab or a line break in a name: one row, a space in its place"
setup; dev 92 Audio/Sink tabbed '"Desk\tSpeakers\nLeft"'; answers esc
kawa-audio
has "$(rows)" "$ICON_BOX_OFF  Desk Speakers Left"
eq "$(wc -l <"$MENU/rows.1")" 14 "still one row per device"

case_ "Arabic and Japanese names, long ones cut to 28 columns (a Japanese letter is two), never mid-character"
setup
dev 93 Audio/Sink bluez_output.1 '"سماعات محمد اللاسلكية الجديدة من سوني"'
dev 94 Audio/Sink bluez_output.2 '"ソニーのワイヤレスノイズキャンセリングヘッドホン"'
dev 95 Audio/Sink short '"-rf"'
answers esc
kawa-audio; r=$(rows)
has "$r" "$ICON_BOX_OFF  سماعات محمد اللاسلكية الجد…"
has "$r" "$ICON_BOX_OFF  ソニーのワイヤレスノイズキ…"
has "$r" "$ICON_BOX_OFF  -rf" "a name starting with a dash"
rows_fit "$r" 34
case_ "… also under LC_ALL=C (byte counting must not cut a letter in half)"
setup; dev 93 Audio/Sink bluez_output.1 "\"Moh's سماعات محمد اللاسلكية الجديدة\""; answers esc
LC_ALL=C kawa-audio
has "$(rows)" "$ICON_BOX_OFF  Moh's سماعات محمد اللاسلكي…"
[[ $(cols "$(rows)") != *bad* ]] && _ok || _no "a row is not valid UTF-8"

case_ "a very long name: cut with … to fit"
setup; dev 96 Audio/Sink long "'$(printf 'Speaker%.0s' {1..40})'"; answers esc
kawa-audio; rows_fit "$(rows)" 34

case_ "a name with letters the font draws two columns wide (® — ™): cut by the font's columns, so it still fits"
setup; dev 99 Audio/Sink logi '"Logitech® G Pro™ X — Wireless Gaming Headset"'; answers esc
kawa-audio; rows_fit "$(rows)" 34; has "$(rows)" "$ICON_BOX_OFF  Logitech® G Pro™ X — Wi…"
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
case_ "no sound card at all (Share is the default then): no device rows, Share still not offered, nothing breaks"
setup; pw_edit "st['nodes'] = [n for n in st['nodes'] if not n['name'].startswith('alsa')]"; answers 1 esc
rc 0 kawa-audio
lacks "$(rows)" "$ICON_BOX_ON"; lacks "$(rows)" "$ICON_BOX_OFF"; lacks "$(rows)" Share
eq "$(wc -l <"$MENU/rows.1")" 10 "the sound part, two headings (each with a gap above), the microphone"
case_ "no output and no default at all: the menu opens, louder does no harm"
setup; pw_edit "st['nodes'] = [n for n in st['nodes'] if n['class'] != 'Audio/Sink']"; answers 1 esc
rc 0 kawa-audio; eq "$(opened)" 2

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

case_ "Turkish and Arabic locales: the level is still read right (louder from 95 % stops at 100 %)"
for loc in tr_TR.UTF-8 ar_EG.UTF-8; do
  setup; pw_edit "node('$sink')['vol'] = 0.95"; answers 1 1 esc
  locale_ok "$loc" || { skip "no $loc here"; continue; }
  LC_ALL=$loc kawa-audio 2>/dev/null
  eq "$(pw_vol sink)" 1.00 "$loc"
done

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
has "$(grep -F "footclient -a \"\$app\"" "$REPO/bin/kawa-float")" "-a \"\$app\""; has "$(grep -E "^once=.* app=float" "$REPO/bin/kawa-float")" "app=float"
case_ "the manifest: wiremix installed, pavucontrol never again (forbidden) and handed back to dnf (retired)"
m() { (STEAM=yes SPOTIFY=yes; . "$REPO/lib/manifest.sh"; eval "$1"); }
has " $(m 'manifest_all amd' | tr '\n' ' ') " " wiremix "; lacks " $(m 'manifest_all amd' | tr '\n' ' ') " " pavucontrol "
has " $(m 'echo "${FORBIDDEN_PKGS[*]}"') " " pavucontrol "; has " $(m 'echo "${RETIRED_PKGS[*]}"') " " pavucontrol "
has "$(grep -E '^wiremix ' "$REPO/tests/static/fixtures/programs.txt")" "manifest  wiremix"
lacks "$(cat "$REPO/tests/static/fixtures/programs.txt")" pavucontrol

done_
