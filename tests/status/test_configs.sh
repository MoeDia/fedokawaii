#!/usr/bin/env bash
# tests/status/test_configs.sh — the two configs behind the bar's sound: cava.conf must give
# kawa-nowplaying exactly the frames it parses (16 bands of 0–5, ';' apart, one frame a line),
# and 60-share.conf's devices must be the ones kawa-audio and the handbook treat as "Share".
# (That PipeWire 1.0 loads 60-share.conf and lists both under Filters was checked live.)
. "$(dirname "$0")/lib.sh"
box
CAVA=$REPO/configs/home/.config/fedokawaii/cava.conf
SHARE=$REPO/configs/home/.config/pipewire/pipewire.conf.d/60-share.conf
ini() {   # ini SECTION KEY — a value of cava.conf (';' comments, as cava's iniparser reads it)
  python3 -I - "$CAVA" "$1" "$2" <<'EOF'
import configparser, sys
c = configparser.ConfigParser(comment_prefixes=(";", "#"), inline_comment_prefixes=(";",), strict=True)
c.read(sys.argv[1])
print(c.get(sys.argv[2], sys.argv[3], fallback="(none)"))
EOF
}

case_ "cava.conf parses, every section once"
python3 -I -c 'import configparser,sys; c=configparser.ConfigParser(comment_prefixes=(";","#"),strict=True); c.read(sys.argv[1]); print(" ".join(c.sections()))' "$CAVA" >"$TMP/sections" 2>&1
eq "$(cat "$TMP/sections")" "general input output smoothing"
case_ "cava.conf: the frames kawa-nowplaying reads — 16 bands, 0–5 each, ';' apart, a newline after each"
eq "$(ini general bars)" 16
eq "$(ini output method)" raw; eq "$(ini output raw_target)" /dev/stdout; eq "$(ini output data_format)" ascii
eq "$(ini output ascii_max_range)" 5
eq "$(ini output bar_delimiter)" 59 "';' is 59"; eq "$(ini output frame_delimiter)" 10 "a newline"
eq "$(ini output channels)" stereo "8 bands a side, mirrored"
has "$(grep -n 'bands:0:8\|bands:8:8\|#frame} == 16\|\[!0-5\]' "$REPO/bin/kawa-nowplaying")" "16" "kawa-nowplaying still expects 16 bands"
case_ "cava.conf: quiet when nothing plays (sleep_timer), PulseAudio input (PipeWire answers it)"
[[ $(ini general sleep_timer) =~ ^[1-9][0-9]*$ ]] && _ok || _no "sleep_timer [$(ini general sleep_timer)]"
eq "$(ini input method)" pulse

strip() { sed -e 's/#.*//' "$SHARE"; }
case_ "60-share.conf: one loopback, braces and brackets balanced"
eq "$(strip | grep -c 'libpipewire-module-loopback')" 1 "one loopback only (a second, recording Share, crashed PipeWire 1.6)"
eq "$(strip | tr -cd '{' | wc -c)" "$(strip | tr -cd '}' | wc -c)" "{ }"
eq "$(strip | tr -cd '[' | wc -c)" "$(strip | tr -cd ']' | wc -c)" "[ ]"
case_ "60-share.conf: 'Share' is the output share_sink — the very name kawa-audio keeps out of its list"
has "$(strip | grep -A3 'capture.props' | head -n 4)" 'node.name        = "share_sink"'
has "$(strip)" 'media.class      = "Audio/Sink"'
has "$(grep -o 'node.name"\] != "[a-z_]*"' "$REPO/bin/kawa-audio")" '"share_sink"'
case_ "60-share.conf: nothing records a sink (stream.capture.sink, the crash), no virtual source"
lacks "$(strip)" 'stream.capture.sink'; lacks "$(strip)" 'Audio/Source'; lacks "$(strip)" 'as microphone'
case_ "60-share.conf: never the default output (priority.session 0)"
eq "$(strip | grep -c 'priority.session = 0')" 1
case_ "60-share.conf: the names the handbook uses"
has "$(strip)" 'node.description = "Share"'; has "$(sed -n '1,12p' "$SHARE")" '"Monitor of Share"'

done_
