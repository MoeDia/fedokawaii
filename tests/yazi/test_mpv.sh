#!/usr/bin/env bash
# tests/yazi/test_mpv.sh — mpv's two scripts, with the real mpv (no picture, no sound card:
# a generated tone, the null outputs, driven over its IPC socket):
#   kawa-resume.lua  quitting halfway keeps the spot; a file watched to the end opens at
#                    the start next time (keep-open would otherwise save its last frame);
#                    seeking back in from the end keeps the spot again; Q at the end drops it
#   kawa-ipc.lua     every player answers on $XDG_RUNTIME_DIR/mpv-<pid>.sock (kawa-theme
#                    reaches it there), gone when it quits; a player with its own socket keeps it
# Skipped (not failed) where mpv is not installed. Fedora 44's mpv 0.41 also reads the whole
# mpv.conf without a complaint; an older mpv (the test sandbox's) only runs the scripts.
. "$(dirname "$0")/../lib/harness.sh"
D=$(cd "$(dirname "$0")" && pwd)
MPV=$(command -v mpv 2>/dev/null) || { printf '  – skipped: mpv is not installed\n'; done_; exit; }
sandbox
config .config/mpv
SCRIPTS=$HOME/.config/mpv/scripts WL=$TMP/watch_later SOCK=$TMP/mpv.sock
VER=$("$MPV" --no-config --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
TONE="$TMP/a tone — 音.wav"
python3 - "$TONE" <<'EOF'
import math, struct, sys, wave
w = wave.open(sys.argv[1], "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(8000)
w.writeframes(b"".join(struct.pack("<h", int(8000 * math.sin(i * 2 * math.pi * 440 / 8000))) for i in range(8000 * 4)))
w.close()
EOF
cp "$TONE" "$TMP/second.wav"

play() {   # play [OPTION…] FILE… — mpv in the background as the desktop sets it up (mpv.conf's
           # keep-open and save-position-on-quit, the resume script), paused, its IPC at $SOCK
  rm -f "$SOCK"
  "$MPV" --no-config --no-terminal --ao=null --vo=null --pause --keep-open=yes --save-position-on-quit=yes \
    --watch-later-dir="$WL" --script="$SCRIPTS/kawa-resume.lua" --input-ipc-server="$SOCK" \
    --log-file="$TMP/mpv.log" "$@" &
  MPV_PID=$!
  ipc wait 10 || _no "mpv did not start: $(tail -n 3 "$TMP/mpv.log" 2>/dev/null)"
  ipc until seeking false 5 >/dev/null
}
ipc() { python3 "$D/mpvipc.py" "$SOCK" "$@"; }
bye() {    # bye [COMMAND] — quit (or quit-watch-later), and wait for mpv to be gone
  ipc run "${1:-quit}" >/dev/null 2>&1
  local _; for _ in {1..100}; do kill -0 "$MPV_PID" 2>/dev/null || break; sleep 0.05; done
  kill -0 "$MPV_PID" 2>/dev/null && { kill -9 "$MPV_PID"; _no "mpv did not quit"; }
  wait "$MPV_PID" 2>/dev/null
}
seek() { ipc run seek "$1" absolute >/dev/null; ipc near time-pos "$1" 5 || _no "the seek to $1 never landed"; }
to_end() { ipc run seek 3.95 absolute >/dev/null; ipc run set_property pause false >/dev/null
           ipc until eof-reached true 5 || _no "the end was never reached"; }
# the spots mpv keeps (its "redirect" entries, which only point at a file, are left out)
saved() { cat "$WL"/* 2>/dev/null | sed -n 's/^start=//p'; }
at() {     # at SECONDS — the one spot saved is there (within a quarter of a second)
  local s; s=$(saved)
  awk -v s="$s" -v w="$1" 'BEGIN { exit !(s != "" && s - w < 0.25 && w - s < 0.25) }' && _ok \
    || _no "the saved spot is [${s//$'\n'/ }], not $1 s"
}
spots() { grep -l '^start=' "$WL"/* 2>/dev/null | wc -l; }
pos() { ipc get time-pos | awk '{ printf "%.0f\n", $1 }'; }
lua_errors() { grep -iE 'kawa_resume|kawa_ipc' "$TMP/mpv.log" | grep -iE 'error|traceback|attempt' || true; }

# ── kawa-resume.lua ──────────────────────────────────────────────────────────────────────
case_ "quitting halfway keeps the spot, and the next start is there"
play "$TONE"; seek 1.5; bye
at 1.5
play "$TONE"; ipc near time-pos 1.5 2 && _ok || _no "it did not start at 1.5 s"; bye

case_ "a file watched to the end opens at the beginning next time (not on its last frame)"
play "$TONE"; ipc near time-pos 1.5 2 && _ok || _no "(it should resume the spot saved above)"
to_end
bye
eq "$(ls -A "$WL" | wc -l)" 0 "the saved spot is dropped (and mpv's pointers to it)"
play "$TONE"; eq "$(pos)" 0 "from the start"; bye

case_ "at the end, then back into it: quitting keeps the spot again"
play "$TONE"; to_end
ipc run set_property pause true >/dev/null; seek 2
ipc until eof-reached false 5 || _no "still at the end"
eq "$(ipc get save-position-on-quit)" true "saving on quit is back on"
bye; at 2

case_ "Q (quit-watch-later) at the end: dropped as the file closes; Q halfway keeps it"
rm -rf "$WL"
play "$TONE"; to_end; bye quit-watch-later
eq "$(spots)" 0
play "$TONE"; seek 1; bye quit-watch-later
at 1

case_ "save-position-on-quit=no (your own choice): the script never turns it on"
rm -rf "$WL"
play --save-position-on-quit=no "$TONE"; seek 1; to_end
seek 1; ipc until eof-reached false >/dev/null
eq "$(ipc get save-position-on-quit)" false; bye
eq "$(spots)" 0 "nothing saved"

case_ "two files in a row: the first one's end does not touch the second's spot"
rm -rf "$WL"
play --pause=no "$TMP/second.wav" "$TONE"
ipc run seek 3.9 absolute >/dev/null
ipc until playlist-pos 1 6 || _no "the second file never started"
ipc run set_property pause true >/dev/null; seek 2
bye
at 2; eq "$(spots)" 1 "one spot: the second file's"

case_ "the scripts ran without a Lua error"
eq "$(lua_errors)" ""

# ── kawa-ipc.lua ─────────────────────────────────────────────────────────────────────────
ipcplay() {   # ipcplay [OPTION…] — mpv with kawa-ipc.lua only, idle, in the background
  "$MPV" --no-config --no-terminal --ao=null --vo=null --idle=yes --script="$SCRIPTS/kawa-ipc.lua" \
    --log-file="$TMP/mpv.log" "$@" &
  MPV_PID=$!
}
case_ "every player answers on \$XDG_RUNTIME_DIR/mpv-<pid>.sock, and takes the theme's colours there"
ipcplay; SOCK=$XDG_RUNTIME_DIR/mpv-$MPV_PID.sock
ipc wait 10 && _ok || _no "no socket at $SOCK"
eq "$(stat -c %a "$XDG_RUNTIME_DIR")" 700 "(in a folder only you can open)"
if [[ $(printf '%s\n' "$VER" 0.38 | sort -V | head -n1) == 0.38 ]]; then   # (load-config-file: mpv 0.38)
  # the very files kawa-theme hands over, dark then light: the on-screen colour (mpv answers
  # #AARRGGBB) and the controller's colours (script-opt, each one added to the list) switch
  for m in dark light; do
    t=$REPO/configs/home/.config/fedokawaii/themes/$m/mpv.conf
    ipc run load-config-file "$t" && _ok || _no "load-config-file refused ($m)"
    want=$(sed -n 's/^osd-color="#\([0-9a-fA-F]\{6\}\)"$/\1/p' "$t" | tr a-f A-F)
    eq "$(ipc get osd-color)" "\"#FF$want\"" "$m: the on-screen colour taken"
    eq "$(ipc get script-opts | python3 -c 'import json, sys; o = json.load(sys.stdin); print(len(o), o.get("osc-background_color"))')" \
       "$(grep -c '^script-opt=' "$t") $(sed -n 's/^script-opt="osc-background_color=\(.*\)"$/\1/p' "$t")" \
       "$m: every controller colour taken (none replacing the others)"
  done
  eq "$(grep -E '\]\[(e|w)\]' "$TMP/mpv.log")" "" "no error or warning from either file"
else printf '  – skipped: mpv %s has no load-config-file yet (0.38 and later: Fedora 44 has 0.41)\n' "$VER"; fi
bye
[[ ! -e $SOCK ]] && _ok || _no "the socket stayed after mpv quit"

case_ "a player started with its own --input-ipc-server keeps it (Syncplay, umpv…)"
ipcplay --input-ipc-server="$TMP/own.sock"; SOCK=$TMP/own.sock
ipc wait 10 && _ok || _no "its own socket is gone"
[[ ! -e $XDG_RUNTIME_DIR/mpv-$MPV_PID.sock ]] && _ok || _no "a second socket was made"
bye

case_ "XDG_RUNTIME_DIR unset: no socket, no error (mpv plays on)"
(unset XDG_RUNTIME_DIR; "$MPV" --no-config --no-terminal --ao=null --vo=null --idle=no --frames=1 \
  --script="$SCRIPTS/kawa-ipc.lua" --log-file="$TMP/mpv2.log" "$TONE"); rc=$?
eq "$rc" 0; lacks "$(grep -i kawa_ipc "$TMP/mpv2.log")" "rror"

# ── the whole mpv.conf, with Fedora 44's mpv ─────────────────────────────────────────────
case_ "mpv.conf and the theme's colours load without a complaint (mpv 0.41)"
if [[ $(printf '%s\n' "$VER" 0.41 | sort -V | head -n1) == 0.41 ]]; then
  "$MPV" --config-dir="$HOME/.config/mpv" --no-terminal --ao=null --vo=null --idle=no --frames=1 \
    --log-file="$TMP/mpv3.log" "$TONE"; eq "$?" 0
  # (option errors only: a machine without VA-API, say, may well warn about hwdec)
  eq "$(grep -iE 'error parsing option|option not found|setting option .* failed|unknown option|deprecated' \
        "$TMP/mpv3.log" | head -n 5)" ""
  lacks "$(grep -iE 'kawa_(resume|ipc)' "$TMP/mpv3.log")" "rror" "the scripts load with the whole config"
else
  printf '  – skipped: mpv %s is older than Fedora 44'"'"'s 0.41 (its options would be refused)\n' "$VER"
fi

done_
