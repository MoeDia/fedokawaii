#!/usr/bin/env bash
# tests/status/test_configs.sh — the two configs behind the bar's sound: cava.conf must give
# kawa-nowplaying exactly the frames it parses (16 bands of 0–5, ';' apart, one frame a line),
# and 60-share.conf's devices must be the ones the sound panel (kawa-quick --state sound) and the handbook treat as "Share";
# then PipeWire's 50-quality.conf (rates, period, resampler) and 60-clean-mic.conf (the clean mic).
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
case_ "60-share.conf: 'Share' is the output share_sink — the very name kawa-quick keeps out of the sound panel's list"
has "$(strip | grep -A3 'capture.props' | head -n 4)" 'node.name        = "share_sink"'
has "$(strip)" 'media.class      = "Audio/Sink"'
has "$(grep -o 'node.name"\] != "[a-z_]*"' "$REPO/bin/kawa-quick")" '"share_sink"'
case_ "60-share.conf: nothing records a sink (stream.capture.sink, the crash), no virtual source"
lacks "$(strip)" 'stream.capture.sink'; lacks "$(strip)" 'Audio/Source'; lacks "$(strip)" 'as microphone'
case_ "60-share.conf: never the default output (priority.session 0)"
eq "$(strip | grep -c 'priority.session = 0')" 1
case_ "60-share.conf: the names the handbook uses"
has "$(strip)" 'node.description = "Share"'; has "$(sed -n '1,12p' "$SHARE")" '"Monitor of Share"'

# ── what you hear, and the clean mic ─────────────────────────────────────────
PW=$REPO/configs/home/.config/pipewire
CLEAN=$PW/pipewire.conf.d/60-clean-mic.conf
nc() { sed -e 's/#.*//' "$1"; }
case_ "every PipeWire file: braces and brackets balanced (setup sets aside one PipeWire will not start with)"
for f in "$PW"/*.conf.d/*.conf; do
  eq "$(nc "$f" | tr -cd '{' | wc -c) $(nc "$f" | tr -cd '[' | wc -c)" "$(nc "$f" | tr -cd '}' | wc -c) $(nc "$f" | tr -cd ']' | wc -c)" "${f#"$PW"/}"
done
case_ "50-quality.conf: 48 kHz, the music's own rate when it plays alone (44.1 / 88.2 / 96 kHz), never below 256 samples a period"
Q=$(nc "$PW/pipewire.conf.d/50-quality.conf")
has "$Q" 'default.clock.rate          = 48000'
has "$Q" 'default.clock.allowed-rates = [ 44100 48000 88200 96000 ]'
has "$Q" 'default.clock.min-quantum   = 256'
case_ "the resampler at quality 10 wherever streams are made: PipeWire's own, Pulse programs (Brave, Steam), PipeWire programs (mpv)"
for f in pipewire.conf.d pipewire-pulse.conf.d client.conf.d; do
  eq "$(nc "$PW/$f/50-quality.conf" | grep -c 'resample.quality = 10')" 1 "$f"
done
case_ "60-clean-mic.conf: one echo-cancel module, WebRTC's (pipewire-libs' own: no extra package), in monitor mode (what you hear untouched)"
C=$(nc "$CLEAN")
eq "$(grep -c 'libpipewire-module-echo-cancel' <<<"$C")" 1
has "$C" 'library.name   = aec/libspa-aec-webrtc'; has "$C" 'monitor.mode   = true'
lacks "$C" 'libpipewire-module-filter-chain'; lacks "$C" 'ladspa'
case_ "60-clean-mic.conf: noise suppression and the high-pass on, no gain control (Brave's own: two would pump)"
has "$C" 'webrtc.noise_suppression = true'; has "$C" 'webrtc.high_pass_filter  = true'; has "$C" 'webrtc.gain_control      = false'
case_ "60-clean-mic.conf: the names kawa-quick reads (clean_mic, its capture clean_mic.capture), both streams passive (the microphone opened only while something records)"
has "$(nc "$CLEAN" | grep -A3 'source.props')" 'node.name        = "clean_mic"'
has "$(nc "$CLEAN" | grep -A3 'capture.props')" 'node.name        = "clean_mic.capture"'
eq "$(grep -c 'node.passive     = true' <<<"$C")" 2
has "$(cat "$REPO/bin/kawa-quick")" '"clean_mic.capture"'; has "$(cat "$REPO/bin/kawa-panel")" '"--target", "clean_mic"'
case_ "60-clean-mic.conf: the default input while nothing else was chosen — above every sound card's microphone (the owner's: 2009)"
p=$(sed -n 's/.*priority.session = \([0-9]*\).*/\1/p' "$CLEAN")
(( p > $(python3 -I -c 'import json,sys; print(max(n["prio"] for n in json.load(open(sys.argv[1]))["nodes"] if n["class"] == "Audio/Source"))' "$SD/fixtures/pw-owner.json") )) && _ok || _no "priority $p"

done_
