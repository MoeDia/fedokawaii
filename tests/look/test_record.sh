#!/usr/bin/env bash
# tests/look/test_record.sh — kawa-record: Super+Shift+R asks whole screen or a region, sound
# or none, records with wf-recorder on the graphics card (H.264 through VA-API), shows 録 and
# the time in the bar while it runs, and the same key (or the mark's click) stops it: the file
# in ~/Videos/Recordings, its path on the clipboard, a notice whose click opens it.
# wf-recorder is a stand-in that keeps its arguments, writes a file and ends on SIGINT.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
need flock python3

setup() {
  look
  VID=$HOME/Videos/Recordings
  # kawa-menu --drop --index: the line picked ($TMP/pick), or dismissed (none)
  argv kawa-menu 'cat >"$FAKE_TMP/menu.in"; [ -s "$FAKE_TMP/pick" ] || exit 1; cat "$FAKE_TMP/pick"'
  argv slurp 'echo "10,20 640x480"'
  stub wlr-randr 'echo "[{\"name\":\"DP-1\",\"enabled\":true}]"'
  # wf-recorder: its arguments kept; the file given to -f written; ends on SIGINT (as it does)
  cat >"$STUBS/wf-recorder" <<'EOF'
#!/usr/bin/env python3
import os, signal, sys, time
a = sys.argv[1:]
open(os.environ["FAKE_TMP"] + "/wf.args", "w").write("\0".join(a))
if os.path.exists(os.environ["FAKE_TMP"] + "/wf.fail"):
    print("Failed to create hw encoding device /dev/dri/renderD128: Invalid argument", file=sys.stderr); sys.exit(1)
f = a[a.index("-f") + 1]
open(f, "wb").write(b"\0" * 64)
signal.signal(signal.SIGINT, lambda s, fr: sys.exit(0))
while True: time.sleep(0.05)
EOF
  chmod 755 "$STUBS/wf-recorder"
  argv wl-copy 'cat >"$FAKE_TMP/clip"'
  stub wl-paste '[ "$1" = --list-types ] && [ -e "$FAKE_TMP/clip" ] && echo "text/plain;charset=utf-8"'
  argv notify-send '[ -e "$FAKE_TMP/click" ] && echo default; exit 0'
  argv xdg-open
}
wf_args() { tr '\0' '\n' <"$TMP/wf.args" 2>/dev/null; }
until_() { local i; for i in {1..750}; do eval "$1" && return 0; /bin/sleep 0.02; done; return 1; }
recording() {   # recording ARG… — kawa-record run ARG… in the background, until its state is written
  kawa-record run "$@" >/dev/null 2>&1 & RPID=$!
  until_ '[[ -s $XDG_RUNTIME_DIR/kawa-record && -s $TMP/wf.args ]]' || _no "it never started"
}
stopped() { kawa-record stop; until_ '! kill -0 $RPID 2>/dev/null'; wait "$RPID" 2>/dev/null; }

# ── the key: the menu, then a recording ──────────────────────────────────────────────────
setup
case_ "the key: a dropdown under the bar — the camera, record; whole screen or a region, sound or none"
echo 2 >"$TMP/pick"; rc 0 kawa-record
args_eq kawa-menu 1 --drop --index
m=$(cat "$TMP/menu.in"); has "$m" "part	$(. "$REPO/configs/home/.config/fedokawaii/icons.sh"; printf %s "$ICON_RECORD")	record"; has "$m" "whole screen"; has "$m" "a region"; has "$m" "with sound"
until_ '[[ -s $XDG_RUNTIME_DIR/kawa-record ]]' && _ok || _no "no recording started"
case_ "whole screen with sound: H.264 on the card, the default output's monitor, a dated .mp4"
until_ '[[ -s $TMP/wf.args ]]'
a=$(wf_args); has "$a" $'-c\nh264_vaapi'; has "$a" "--audio=@DEFAULT_MONITOR@"; lacks "$a" "-g"; lacks "$a" "-o"
[[ $a =~ -f$'\n'"$VID"/[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}\.mp4 ]] && _ok || _no "file: $a"
case_ "while it runs: the bar's 録 and the time, lit; the key again stops it"
b=$(kawa-record bar); has "$b" '"text":"録 00:0'; has "$b" '"class":"rec"'
pid=$(cut -d' ' -f1 <"$XDG_RUNTIME_DIR/kawa-record")
rc 0 kawa-record
until_ '! kill -0 '"$pid"' 2>/dev/null' && _ok || _no "wf-recorder still runs"
until_ '[[ ! -e $XDG_RUNTIME_DIR/kawa-record ]]' && _ok || _no "the state was left"
eq "$(kawa-record bar)" '{"text":""}' "hidden once stopped"
case_ "stopped: its path on the clipboard, a notice (click: open)"
until_ '[[ $(ncalls notify-send) -ge 1 ]]'
f=$(find "$VID" -name '*.mp4'); [[ -s $f ]] && _ok || _no "no file"
eq "$(cat "$TMP/clip")" "$f"
n=$(args_of notify-send 1); has "$n" "-A"; has "$n" "default=open"; has "$n" "recording saved · its path copied"; has "$n" "~/Videos/Recordings/"

# ── run: the choices ─────────────────────────────────────────────────────────────────────
setup
case_ "a region without sound: slurp's geometry, no audio"
recording region silent "10,20 640x480"; a=$(wf_args); has "$a" $'-g\n10,20 640x480'; lacks "$a" "--audio"
stopped
case_ "the notice clicked: the recording opens"
setup; : >"$TMP/click"; recording whole silent; stopped
until_ '[[ $(ncalls xdg-open) -ge 1 ]]' && _ok || _no "not opened"
[[ $(args_of xdg-open 1) == "$VID"/*.mp4 ]] && _ok || _no "opened: $(args_of xdg-open 1)"
case_ "the menu dismissed: nothing recorded"
setup; rc 0 kawa-record; /bin/sleep 0.2; [[ ! -e $TMP/wf.args ]] && _ok || _no "recorded"

# ── when it cannot ───────────────────────────────────────────────────────────────────────
case_ "the encoder fails: a critical notice with wf-recorder's reason, no file left"
setup; : >"$TMP/wf.fail"; rc 1 kawa-record run whole silent
n=$(args_of notify-send 1); has "$n" "critical"; has "$n" "did not start: Failed to create hw encoding device"
eq "$(find "$VID" -name '*.mp4' 2>/dev/null)" ""
case_ "the whole screen with two monitors on: a click picks which (slurp -o), recorded by its name"
setup; stub wlr-randr 'echo "[{\"name\":\"DP-1\",\"enabled\":true},{\"name\":\"HDMI-A-1\",\"enabled\":true}]"'
argv slurp 'echo HDMI-A-1'; echo 1 >"$TMP/pick"; rc 0 kawa-record
until_ '[[ -s $TMP/wf.args ]]'; has "$(wf_args)" $'-o\nHDMI-A-1'; has "$(args_of slurp 1)" "%o"
kawa-record stop; until_ '[[ ! -e $XDG_RUNTIME_DIR/kawa-record ]]'
case_ "misuse: an unknown word, a bad region"
setup; rc 2 kawa-record frob; rc 2 kawa-record run whole loud; rc 2 kawa-record run region silent "x"; rc 2 kawa-record run whole silent "a b"
case_ "stop with nothing running: a notice says so at once; the bar stays empty"
setup; rc 0 kawa-record stop; has "$(args_of notify-send 1)" "nothing is being recorded"; eq "$(kawa-record bar)" '{"text":""}'
# ── pause: parts, 3-2-1 on the bar, one file ─────────────────────────────────────────────
case_ "pause: wf-recorder ends its part, the bar says 録 停 and the time, muted; nothing records"
setup; argv ffmpeg 'for a; do o=$a; done; echo joined >"$o"'
recording whole silent; w1=$(pgrep -f -n "$STUBS/wf-recorder")
rc 0 kawa-record pause
until_ '[[ $(kawa-record bar) == *paused* ]]' && _ok || _no "not paused: $(kawa-record bar)"
has "$(kawa-record bar)" '"text":"録 停 00:0'
until_ '! kill -0 '"$w1"' 2>/dev/null' && _ok || _no "wf-recorder still records while paused"
case_ "pause again: 3, 2, 1 on the bar (a second each), then a new part records"
rc 0 kawa-record pause
until_ '[[ $(kawa-record bar) == *\"録\ 3\"* ]]' && _ok || _no "no 3: $(kawa-record bar)"
until_ '[[ $(kawa-record bar) == *\"録\ 1\"* ]]' && _ok || _no "no 1"
until_ '[[ $(kawa-record bar) == *\"class\":\"rec\"* ]]' && _ok || _no "not on again"
until_ '[[ $(wf_args) == *"$VID/."* ]]'; has "$(wf_args)" "$VID/."
case_ "stopped after a pause: the parts joined by ffmpeg as they are (concat, no re-encode), only the file left"
stopped; until_ '[[ $(ncalls notify-send) -ge 1 ]]'
has "$(args_of ffmpeg 1)" "concat"; has "$(args_of ffmpeg 1)" "copy"
eq "$(find "$VID" -name '.*' | wc -l)" 0 "parts left: $(ls -a "$VID")"
eq "$(find "$VID" -name '*.mp4' | wc -l)" 1
case_ "the encoder told the monitor's refresh rate (-B)"
setup; stub wlr-randr 'echo "[{\"name\":\"DP-1\",\"enabled\":true,\"modes\":[{\"refresh\":143.912,\"current\":true}]}]"'
recording whole silent; has "$(wf_args)" $'-B\n143'; stopped
case_ "pause with nothing recording: said"
setup; rc 0 kawa-record pause; has "$(args_of notify-send 1)" "nothing is being recorded"
case_ "stop while recording: the bar's mark goes at once, the file is finished after"
setup; recording whole silent; kawa-record stop; eq "$(kawa-record bar)" '{"text":""}'
until_ '! kill -0 $RPID 2>/dev/null'; wait "$RPID" 2>/dev/null
[[ -s $(find "$VID" -name '*.mp4' | head -n1) ]] && _ok || _no "no file"

done_
