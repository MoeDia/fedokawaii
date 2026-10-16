#!/usr/bin/env bash
# tests/yazi/test_syncplay.sh — watching together (Syncplay), the terminal way:
#   kawa-together   asks for the room (the last one offered), then Syncplay without its window
#                   in that terminal, your typing reaching it; without a terminal the room from
#                   syncplay.ini; no room at all: exit 2
#   the launcher    Syncplay's entry opens kawa-together in a terminal window and claims no file
#                   types (films keep opening in mpv)
#   yazi            W on a film starts it (keymap.toml; with the real yazi: test_yazi.sh); on a
#                   folder Syncplay starts with no film
#   kawa-resume.lua in a player Syncplay started (its syncplayintf.lua loaded) a spot you saved
#                   watching alone is not opened, and none is kept — with the real mpv
#   for real        with syncplay (as lib/upstream.sh installs it: no Qt), ffmpeg and mpv 0.38
#                   or later installed: a server on 127.0.0.1 and two friends, each in a home
#                   with the desktop's mpv config (syncplay_pair.py): joining, ready, pause,
#                   seek, chat, a different file, the shared playlist, a server restart — and
#                   no jump to anyone's own spot; all on a Python without PySide6
# Skipped (not failed) where those programs are missing.
. "$(dirname "$0")/../lib/harness.sh"
D=$(cd "$(dirname "$0")" && pwd)
MPV=$(command -v mpv 2>/dev/null || true)
SP=$(command -v syncplay 2>/dev/null || true)
FFMPEG=$(command -v ffmpeg 2>/dev/null || true)
sandbox
INI=$HOME/.config/syncplay.ini

# ── kawa-together ────────────────────────────────────────────────────────────────────────
# a stand-in Syncplay: says how it was started, then what it reads (a command, then "bye")
stub syncplay 'printf "args:"; printf " [%s]" "$@"; printf "\n"; read -r l; echo "it read: $l"; read -r l'
printf '[client_settings]\nname = kawau\nroom = film-night\nroomlist = []\n' >"$INI"
together() { python3 "$D/drive.py" --size 200x12 --cwd "$HOME" -- "$REPO/bin/kawa-together" "$@"; }

case_ "in a terminal: it asks for the room, the last one offered — Enter keeps it"
out=$(together "$TMP/a film's.mkv" <<'EOF'
wait room (the one your friends use): film-night
key <Enter>
wait args:
key help<Enter>
wait it read: help
screen
quit bye<Enter>
EOF
); rc=$?
eq "$rc" 0 "the session: $out"
has "$out" "args: [--no-gui] [--room] [film-night] [--] [$TMP/a film's.mkv]" "Syncplay without its window, the file after --"
has "$out" "it read: help" "what you type reaches Syncplay"

case_ "another room typed over the last one"
out=$(together <<'EOF'
wait film-night
key <C-u>Movie Club 7<Enter>
wait args:
screen
key list<Enter>
quit bye<Enter>
EOF
)
has "$out" "args: [--no-gui] [--room] [Movie Club 7]" "$out"
lacks "$out" "[--]" "no file: none passed"

case_ "an empty answer asks again; Ctrl+D gives up (exit 2), Syncplay never started"
reset_calls
out=$(together <<'EOF'
wait film-night
key <C-u><Enter>
wait room (the one your friends use):
key <C-d>
sleep 0.5
screen
EOF
)
not_called '^syncplay'

case_ "without a terminal (piped): the remembered room; none remembered: exit 2, said"
eq "$(kawa-together "$TMP/x.mkv" <<<"" 2>&1 | head -n1)" "args: [--no-gui] [--room] [film-night] [--] [$TMP/x.mkv]"
printf '[client_settings]\nname = kawau\n' >"$INI"
out=$(kawa-together </dev/null 2>&1); rc=$?
eq "$rc" 2; has "$out" "no room"
rm -f "$INI"; rc 2 kawa-together </dev/null
case_ "--help shows how to use it"
has "$(kawa-together --help)" "kawa-together [FILE]"

# ── the launcher and yazi ────────────────────────────────────────────────────────────────
config .local/share/applications .config/yazi
case_ "the launcher's Syncplay: kawa-together in a terminal window, no file types"
e=$(cat "$HOME/.local/share/applications/syncplay.desktop")
has "$e" "Exec=$HOME/.local/bin/kawa-term kawa-together %f"
lacks "$e" "MimeType=" "it would compete with mpv for films"
case_ "yazi: W watches the hovered film together (the real yazi: test_yazi.sh)"
has "$(cat "$HOME/.config/yazi/keymap.toml")" 'on = "W",          run = "shell --orphan -- kawa-term kawa-together %h"'
[[ ! -e $HOME/.config/yazi/yazi.toml ]] && _ok || _no "yazi.toml is yours (§10.3): the desktop ships none"
case_ "W on a folder: Syncplay starts with no film (the room's is found by name)"
mkdir -p "$TMP/a folder"
printf '[client_settings]\nroom = film-night\n' >"$INI"
eq "$(kawa-together "$TMP/a folder" </dev/null 2>&1 | head -n1)" "args: [--no-gui] [--room] [film-night]"

# ── kawa-resume.lua in a player Syncplay started ─────────────────────────────────────────
if [[ -z $MPV ]]; then printf '  – skipped: mpv is not installed (kawa-resume.lua and the real session)\n'; done_; exit; fi
config .config/mpv
TONE=$TMP/tone.wav WL=$TMP/watch_later SOCK=$TMP/mpv.sock
python3 - "$TONE" <<'EOF'
import math, struct, sys, wave
w = wave.open(sys.argv[1], "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(8000)
w.writeframes(b"".join(struct.pack("<h", int(8000 * math.sin(i * 2 * math.pi * 440 / 8000))) for i in range(8000 * 4)))
w.close()
EOF
mkdir -p "$TMP/syncplay"; echo "-- Syncplay's interface script, as a stand-in" >"$TMP/syncplay/syncplayintf.lua"
ipc() { python3 "$D/mpvipc.py" "$SOCK" "$@"; }
play() {   # play [OPTION…] — the tone, as mpv.conf sets it up (saving on quit), paused
  rm -f "$SOCK"
  "$MPV" --no-config --no-terminal --ao=null --vo=null --pause --keep-open=yes --save-position-on-quit=yes \
    --watch-later-dir="$WL" --script="$HOME/.config/mpv/scripts/kawa-resume.lua" --input-ipc-server="$SOCK" \
    --log-file="$TMP/mpv.log" "$@" "$TONE" &
  MPV_PID=$!
  ipc wait 10 || _no "mpv did not start"
  ipc until seeking false 5 >/dev/null
}
bye() { ipc run quit >/dev/null 2>&1; wait "$MPV_PID" 2>/dev/null; }
spot() { cat "$WL"/* 2>/dev/null | sed -n 's/^start=//p' | awk '{ printf "%.0f\n", $1 }'; }
pos() { ipc get time-pos | awk '{ printf "%.0f\n", $1 }'; }

case_ "kawa-resume.lua in Syncplay's player: your own spot is not opened, and none is kept"
play; ipc run seek 2 absolute >/dev/null; ipc near time-pos 2 5 >/dev/null; bye
eq "$(spot)" 2 "(set up: watched alone up to 2 s)"
play --script="$TMP/syncplay/syncplayintf.lua"
eq "$(pos)" 0 "it opened at the spot saved watching alone"
eq "$(ipc get resume-playback) $(ipc get save-position-on-quit)" "false false"
ipc run seek 3 absolute >/dev/null; ipc near time-pos 3 5 >/dev/null; bye
eq "$(spot)" 2 "the spot was replaced by the one watched together"
case_ "…while any other player still opens it (the spot is there)"
play; eq "$(pos)" 2; bye

# ── for real: two friends and a server ───────────────────────────────────────────────────
VER=$("$MPV" --no-config --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
if [[ -z $SP ]]; then printf '  – skipped: syncplay is not installed (the real session)\n'; done_; exit; fi
if [[ $(printf '%s\n' "$VER" 0.38 | sort -V | head -n1) != 0.38 ]]; then
  printf '  – skipped: mpv %s is older than 0.38 (the real session; Fedora 44 has 0.41)\n' "$VER"; done_; exit
fi
if [[ -z $FFMPEG ]]; then printf '  – skipped: ffmpeg is not installed (it makes the films)\n'; done_; exit; fi
SPD=$(dirname "$(readlink -f "$SP")")
[[ -x $SPD/syncplay-server ]] || SPD=$(dirname "$SP")
# (a socket's path has room for 107 bytes: Syncplay's goes in $XDG_RUNTIME_DIR/syncplay-xxxxxxxx)
if ((${#XDG_RUNTIME_DIR} > 60)); then
  printf '  – skipped: the runtime folder %s is too long a path for a socket\n' "$XDG_RUNTIME_DIR"; done_; exit
fi
case_ "the syncplay installed runs on a Python without PySide6 (no Qt), and always without its window"
if grep -q '^py=' "$SP"; then
  py=$(eval "$(grep -m1 '^py=' "$SP")"; printf %s "$py")
  "$py" -I -c 'import importlib.util, sys; sys.exit(importlib.util.find_spec("PySide6") is not None)' && _ok \
    || _no "$py finds PySide6: this session would not show that Syncplay runs without Qt"
  has "$(grep '^exec' "$SP")" '"$dir" --no-gui "$@"'
else printf '  – skipped: %s is not the starter lib/upstream.sh writes (the session below still runs)\n' "$SP"; fi
# (src/syncplay/syncplay.patch's two fixes, in the copy that starter runs)
if grep -q '^py=' "$SP"; then
  spdir=$(dir=""; eval "$(grep -m1 '^py=' "$SP")"; printf %s "$dir")   # (the starter's py= dir= line)
  while IFS= read -r ln; do
    case $ln in
      "case "*) case_ "${ln#case }" ;;
      ok) _ok ;;
      "no "*) _no "${ln#no }" ;;
    esac
  done < <("$py" -I "$D/syncplay_ipc.py" "$spdir" 2>"$TMP/ipc.err")
  grep -q Traceback "$TMP/ipc.err" && _no "syncplay_ipc.py: $(tail -n 3 "$TMP/ipc.err")"
fi
mkdir -p "$TMP/media"
"$FFMPEG" -loglevel error -f lavfi -i testsrc=size=160x120:rate=25:duration=60 -f lavfi -i sine=frequency=440:duration=60 \
  -c:v libx264 -preset ultrafast -g 25 -c:a aac -shortest "$TMP/media/film.mkv" \
  && "$FFMPEG" -loglevel error -f lavfi -i testsrc2=size=160x120:rate=25:duration=50 -f lavfi -i sine=frequency=330:duration=50 \
  -c:v libx264 -preset ultrafast -g 25 -c:a aac -shortest "$TMP/media/other.mkv" || _no "ffmpeg made no films"
rm -rf "$WL"
while IFS= read -r ln; do
  case $ln in
    "case "*) case_ "${ln#case }" ;;
    ok) _ok ;;
    "no "*) _no "${ln#no }" ;;
  esac
done < <(python3 "$D/syncplay_pair.py" "$HOME" "$TMP/media" "$SPD" "$MPV" "$REPO/bin/kawa-together" 2>"$TMP/pair.err")
[[ -s $TMP/pair.err ]] && grep -q Traceback "$TMP/pair.err" && _no "the driver: $(tail -n 3 "$TMP/pair.err")"

done_
