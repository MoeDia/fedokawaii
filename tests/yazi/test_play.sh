#!/usr/bin/env bash
# tests/yazi/test_play.sh — kawa-play: a film opened goes to the mpv window already open
# (Syncplay's first, else the one started last), the first file replacing what plays and the
# rest queued after it; with none open, or with --new, a new window. The open players are
# the real mpv (no picture, no sound card, driven over their sockets); a new window is a
# stand-in mpv that keeps what it was given. Skipped (not failed) without mpv.
. "$(dirname "$0")/../lib/harness.sh"
D=$(cd "$(dirname "$0")" && pwd)
MPV=$(command -v mpv 2>/dev/null) || { printf '  – skipped: mpv is not installed\n'; done_; exit; }
sandbox
export XDG_RUNTIME_DIR=$TMP/run; mkdir -m 700 -p "$XDG_RUNTIME_DIR"
stub mpv                                   # (a new window: only what it was handed)
for n in one two "a film — 映画"; do
  python3 - "$TMP/$n.wav" <<'PY'
import struct, sys, wave
w = wave.open(sys.argv[1], "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(8000)
w.writeframes(struct.pack("<h", 0) * 8000 * 5); w.close()
PY
done
PIDS=()
player() {   # player SOCKET — a real mpv, idle, answering on SOCKET
  mkdir -p "$(dirname "$1")"
  "$MPV" --no-config --no-terminal --idle=yes --ao=null --vo=null --pause --input-ipc-server="$1" \
    --log-file="$TMP/mpv-${#PIDS[@]}.log" & PIDS+=($!)
  python3 "$D/mpvipc.py" "$1" wait 10 || _no "mpv did not start on $1"
}
ipc() { python3 "$D/mpvipc.py" "$@"; }
path() { ipc "$1" get path 2>/dev/null | tr -d '"'; }
quit_all() { local p; for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; wait "$p" 2>/dev/null; done; PIDS=(); rm -rf "$XDG_RUNTIME_DIR"/*; }
trap 'quit_all' EXIT

case_ "no mpv open: a new window, the file made whole (the player runs elsewhere)"
cd "$TMP" && rc 0 kawa-play one.wav
called "^mpv --player-operation-mode=pseudo-gui -- $TMP/one.wav\$"
case_ "one open: the film goes there — no new window, it plays (unpaused)"
A=$XDG_RUNTIME_DIR/mpv-100.sock; player "$A"; reset_calls
rc 0 kawa-play "$TMP/a film — 映画.wav"
ipc "$A" until path "\"$TMP/a film — 映画.wav\"" 5 >/dev/null && _ok || _no "not playing there: [$(path "$A")]"
ipc "$A" until pause false 5 >/dev/null && _ok || _no "still paused"
not_called '^mpv'
case_ "several: the first replaces what plays, the others queued after it"
rc 0 kawa-play "$TMP/one.wav" "$TMP/two.wav"
ipc "$A" until playlist-count 2 5 >/dev/null && _ok || _no "playlist: $(ipc "$A" get playlist-count)"
ipc "$A" until path "\"$TMP/one.wav\"" 5 >/dev/null && _ok || _no "the first is not playing: [$(path "$A")]"
case_ "two open: the one started last takes it"
sleep 1.1; B=$XDG_RUNTIME_DIR/mpv-200.sock; player "$B"
rc 0 kawa-play "$TMP/two.wav"
ipc "$B" until path "\"$TMP/two.wav\"" 5 >/dev/null && _ok || _no "not in the newest: [$(path "$B")]"
eq "$(path "$A")" "$TMP/one.wav" "the older one plays on"
case_ "Syncplay's player open: it takes the film, whichever started last (Syncplay tells the room)"
S=$XDG_RUNTIME_DIR/syncplay-xyz/mpv-socket; player "$S"
rc 0 kawa-play "$TMP/one.wav"
ipc "$S" until path "\"$TMP/one.wav\"" 5 >/dev/null && _ok || _no "not in Syncplay's: [$(path "$S")]"
eq "$(path "$B")" "$TMP/two.wav" "the other players are left alone"
case_ "--new: a window of its own, whatever is open; a link passes as it is"
reset_calls; rc 0 kawa-play --new -- "https://example.org/v.mp4" "$TMP/two.wav"
called "^mpv --player-operation-mode=pseudo-gui -- https://example.org/v.mp4 $TMP/two.wav\$"
case_ "a socket left by a crashed mpv: passed over"
quit_all; reset_calls
python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])' "$XDG_RUNTIME_DIR/mpv-300.sock"
rc 0 kawa-play "$TMP/one.wav"; called "^mpv --player-operation-mode=pseudo-gui -- $TMP/one.wav\$"
case_ "nothing to play: exit 2"
rc 2 kawa-play; rc 2 kawa-play --new

case_ "the ways a film opens: xdg-open (mimeapps.list), Enter in yazi — in the window open; Alt+Enter: a new one"
m=$(cat "$REPO/configs/home/.config/mimeapps.list")
for t in video/mp4 video/x-matroska video/webm audio/mpeg audio/flac audio/x-mpegurl; do has "$m" "$t=kawa-play.desktop"; done
lacks "$m" "=mpv.desktop" "something still opens a new mpv each time"
e=$(cat "$REPO/configs/home/.local/share/applications/kawa-play.desktop")
has "$e" 'Exec=@HOME@/.local/bin/kawa-play %U'; has "$e" 'NoDisplay=true'
for t in $(sed -n 's/=kawa-play.desktop$//p' <<<"$m"); do has "$e" "$t;" "kawa-play.desktop does not say it opens $t"; done
has "$(cat "$REPO/configs/home/.config/yazi/plugins/smart-enter.yazi/main.lua")" '"kawa-play -- " .. table.concat(films, " ")'
has "$(cat "$REPO/configs/home/.config/yazi/keymap.toml")" 'on = "<A-Enter>",  run = "shell --orphan -- kawa-play --new -- %s"'
done_
