#!/usr/bin/env bash
# tests/status/test_configs.sh — the two configs behind the bar's sound: cava.conf must give
# kawa-nowplaying exactly the frames it parses (16 bands of 0–6, ';' apart, one frame a line),
# and 60-share.conf's devices must be the ones the sound panel (kawa-quick --state sound) and the handbook treat as "Share";
# then PipeWire's 50-quality.conf (rates, period, resampler) and WirePlumber's
# 50-bluetooth-quality.conf (the headphones' codecs); and the clean mic, gone: its file not
# shipped, theme.sh retiring the one an earlier install left.
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
case_ "cava.conf: the frames kawa-nowplaying reads — 16 bands, 0–9 each, ';' apart, a newline after each"
eq "$(ini general bars)" 16
eq "$(ini output method)" raw; eq "$(ini output raw_target)" /dev/stdout; eq "$(ini output data_format)" ascii
eq "$(ini output ascii_max_range)" 9 "ten heights, a pixel each, the capitals' 10 at most: eq-0 … eq-9"
eq "$(ini general sleep_timer)" 0 "never asleep: its sleep looks for sound once a second (kawa-nowplaying ends it instead)"
eq "$(ini output bar_delimiter)" 59 "';' is 59"; eq "$(ini output frame_delimiter)" 10 "a newline"
eq "$(ini output channels)" stereo "8 bands a side, mirrored"
has "$(grep -nF '${#bands[@]} == 16' "$REPO/bin/kawa-nowplaying")" "16" "kawa-nowplaying still expects 16 bands"
case_ "cava.conf: PulseAudio input (PipeWire answers it); kawa-nowplaying, not cava, quiets it when nothing plays (its GRACE)"
has "$(cat "$REPO/bin/kawa-nowplaying")" "GRACE=" "kawa-nowplaying ends cava after a while with nothing playing"
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

# ── what you hear ────────────────────────────────────────────────────────────
PW=$REPO/configs/home/.config/pipewire
nc() { sed -e 's/#.*//' "$1"; }
case_ "every PipeWire file: braces and brackets balanced (setup sets aside one PipeWire will not start with)"
for f in "$PW"/*.conf.d/*.conf; do
  eq "$(nc "$f" | tr -cd '{' | wc -c) $(nc "$f" | tr -cd '[' | wc -c)" "$(nc "$f" | tr -cd '}' | wc -c) $(nc "$f" | tr -cd ']' | wc -c)" "${f#"$PW"/}"
done
case_ "50-quality.conf: 48 kHz, the music's own rate when it plays alone (44.1 / 88.2 / 96 / 176.4 / 192 kHz), 1024 samples a period, never below 256 nor above 2048"
Q=$(nc "$PW/pipewire.conf.d/50-quality.conf")
has "$Q" 'default.clock.rate          = 48000'
has "$Q" 'default.clock.allowed-rates = [ 44100 48000 88200 96000 176400 192000 ]'
has "$Q" 'default.clock.quantum       = 1024'
has "$Q" 'default.clock.min-quantum   = 256'
has "$Q" 'default.clock.max-quantum   = 2048'
case_ "the resampler at quality 14 (the best there is) wherever streams are made: PipeWire's own, Pulse programs (Brave, Steam), PipeWire programs (mpv) — in stream.properties, nothing else set there"
for f in pipewire.conf.d pipewire-pulse.conf.d client.conf.d; do
  eq "$(nc "$PW/$f/50-quality.conf" | grep -c 'resample.quality = 14')" 1 "$f"
  eq "$(nc "$PW/$f/50-quality.conf" | grep -c 'resample.quality')" 1 "$f: one quality"
  has "$(nc "$PW/$f/50-quality.conf" | tr -s ' \n' ' ')" "stream.properties = { resample.quality = 14 }" "$f"
done
case_ "50-bluetooth-quality.conf (WirePlumber 0.5): the codecs best first down to plain SBC, SBC-XQ and mSBC on, hardware volume, LDAC at its highest rate on every Bluetooth card"
B=$(nc "$REPO/configs/home/.config/wireplumber/wireplumber.conf.d/50-bluetooth-quality.conf")
has "$B" 'bluez5.codecs = [ ldac aptx_hd aptx aac sbc_xq sbc ]'
has "$B" 'bluez5.enable-sbc-xq = true'; has "$B" 'bluez5.enable-msbc = true'; has "$B" 'bluez5.enable-hw-volume = true'
has "$(grep -A8 'monitor.bluez.rules' <<<"$B")" 'device.name = "~bluez_card.*"'
has "$(grep -A8 'monitor.bluez.rules' <<<"$B")" 'bluez5.a2dp.ldac.quality = "hq"'
eq "$(tr -cd '{' <<<"$B" | wc -c) $(tr -cd '[' <<<"$B" | wc -c)" "$(tr -cd '}' <<<"$B" | wc -c) $(tr -cd ']' <<<"$B" | wc -c)" "its brackets balanced"

# ── the clean mic: gone ──────────────────────────────────────────────────────
case_ "the clean mic is taken out: no echo-cancel module in any PipeWire file shipped, 60-clean-mic.conf not among them"
[[ ! -e $PW/pipewire.conf.d/60-clean-mic.conf ]] && _ok || _no "60-clean-mic.conf is still shipped"
eq "$(grep -rl 'libpipewire-module-echo-cancel' "$PW" 2>/dev/null)" "" "an echo-cancel module in: $(grep -rl 'libpipewire-module-echo-cancel' "$PW" 2>/dev/null)"
case_ "theme.sh retires the one an earlier install left (while it is still ours: its echo-cancel module says so)"
has "$(cat "$REPO/theme.sh")" "retire .config/pipewire/pipewire.conf.d/60-clean-mic.conf 'libpipewire-module-echo-cancel'"

done_
