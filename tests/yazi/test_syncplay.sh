#!/usr/bin/env bash
# tests/yazi/test_syncplay.sh — watching together (Syncplay), the terminal way:
#   kawa-together   in a terminal, the form (the real fzf, driven by keys): syncplay.ini's server,
#                   room and name on the first run, the join row under the cursor (Enter alone
#                   starts); the lists: what you used newest first, once each, the last 10,
#                   Syncplay's public servers, a typed one as new at the bottom; the choice
#                   written into syncplay.ini, so Enter alone next time rejoins it; a server of
#                   your own: its password asked unseen, kept for it alone (600, in a 700
#                   folder), never on the screen, Syncplay's command line or its environment;
#                   the film from the file dialog; Esc starts nothing. RADV's "not a conformant
#                   Vulkan implementation" line: Mesa's own switch set, what else is printed
#                   still shown. Without a terminal: no form, syncplay.ini as it is
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
FZF=$(command -v fzf 2>/dev/null || true)
sandbox
INI=$HOME/.config/syncplay.ini
ST=$HOME/.local/state/fedokawaii/together
RADV="WARNING: radv is not a conformant Vulkan implementation, testing use only."

# ── kawa-together ────────────────────────────────────────────────────────────────────────
# a stand-in Syncplay: says how it was started, prints what Mesa prints when mpv starts on an
# RDNA 4 card (that line only while Mesa's switch is off, as vk_util.c does) and another
# warning, then what it reads, until "bye"
stub syncplay 'printf "args:"; printf " [%s]" "$@"; printf "\n"
case ${MESA_VK_IGNORE_CONFORMANCE_WARNING:-0} in 0|n|no|f|false) echo "'"$RADV"'" >&2 ;; esac
echo "[vo/gpu-next] another warning" >&2
echo "pw in its environment: ${KAWA_PW-none}"
while read -r l; do echo "it read: $l"; [ "$l" = bye ] && break; done'
# Syncplay's folder as lib/upstream.sh installs it: only what the form reads (its own port,
# its public servers — as in 1.7.6)
mkdir -p "$HOME/.local/share/fedokawaii/syncplay/syncplay"
: >"$HOME/.local/share/fedokawaii/syncplay/syncplay/__init__.py"
cat >"$HOME/.local/share/fedokawaii/syncplay/syncplay/constants.py" <<'EOF'
DEFAULT_PORT = 8999
FALLBACK_PUBLIC_SYNCPLAY_SERVERS = [
    ['syncplay.pl:8995 (France)', 'syncplay.pl:8995'],
    ['syncplay.pl:8997 (France)', 'syncplay.pl:8997'],
    ['syncplay.pl:8999 (France)', 'syncplay.pl:8999']]
EOF
config .config/fedokawaii/fzf.opts
# syncplay.ini as theme.sh starts it
theme_ini() { printf '[server_data]\nhost = syncplay.pl\nport = 8999\npassword = None\n\n[client_settings]\nname = kawau\nroom = kawau-3f9a\nplayerpath = /usr/bin/mpv\n' >"$INI"; chmod 600 "$INI"; }
ini() { python3 -I -c 'import configparser, sys; c = configparser.ConfigParser(); c.read(sys.argv[1]); print(c.get(sys.argv[2], sys.argv[3]))' "$INI" "$@"; }
together() { python3 "$D/drive.py" --size 100x16 --cwd "$HOME" -- "$REPO/bin/kawa-together" "$@"; }
# (its exit status, said on the screen once it has ended)
together_rc() { python3 "$D/drive.py" --size 100x16 --cwd "$HOME" -- sh -c '"$0" "$@"; echo "ended: $?"; sleep 3' "$REPO/bin/kawa-together" "$@"; }

case_ "without a terminal (piped): no form — Syncplay as syncplay.ini says, the film after --"
theme_ini
out=$(kawa-together "$TMP/x.mkv" <<<"" 2>&1)
has "$out" "args: [--no-gui] [--] [$TMP/x.mkv]"
lacks "$out" "$RADV" "Mesa's switch is set: its RADV line stays out"
has "$out" "[vo/gpu-next] another warning" "anything else on stderr still shows"
eq "$(ini client_settings room) $(ini server_data host)" "kawau-3f9a syncplay.pl" "syncplay.ini was changed"
[[ ! -e $ST ]] && _ok || _no "the form's memory was made without a form"
case_ "--help shows how to use it"
has "$(kawa-together --help)" "kawa-together [FILE]"

plain() { sed 's/\x1b\[[0-9;]*m//g'; }   # (a row without its inks)
case_ "the lists (--list, as fzf asks for them): the value now, then the ones used, newest first, once each"
mkdir -p "$ST"; printf 'b\nc\nb\nd\n' >"$ST/rooms"
eq "$(TOGETHER_NOW=c kawa-together --list rooms '' | cut -f1,2 | tr '\t\n' ':,')" "old:c,old:b,old:d,"
has "$(TOGETHER_NOW=c kawa-together --list rooms '' | plain)" "c  now"
case_ "…what you type, new, at the bottom (not when it is one of them); spaces around it trimmed"
eq "$(TOGETHER_NOW=c kawa-together --list rooms '  Movie Club 7 ' | tail -n1 | cut -f1,2)" $'new\tMovie Club 7'
has "$(TOGETHER_NOW=c kawa-together --list rooms '  Movie Club 7 ' | tail -n1 | plain)" "+  Movie Club 7  new"
lacks "$(TOGETHER_NOW=c kawa-together --list rooms 'b' | cut -f1)" "new"
case_ "…servers: Syncplay's public ones after yours; a bare host gets Syncplay's port; anything else is no server"
printf 'friends.example:9000\nsyncplay.pl:8997\n' >"$ST/servers"
pub=$'syncplay.pl:8995\tFrance\nsyncplay.pl:8997\tFrance'
srv() { TOGETHER_NOW=friends.example:9000 TOGETHER_PUBLIC=$pub TOGETHER_PORT=8999 kawa-together --list servers "$1"; }
eq "$(srv '' | cut -f2 | tr '\n' ,)" "friends.example:9000,syncplay.pl:8997,syncplay.pl:8995,"
has "$(srv '' | sed -n 2p | plain)" "syncplay.pl:8997  public, France"
eq "$(srv 'films.example' | tail -n1 | cut -f1,2)" $'new\tfilms.example:8999'
eq "$(srv '[::1]:9001' | tail -n1 | cut -f1,2)" $'new\t[::1]:9001'
eq "$(srv 'two words' | cut -f1 | sort -u | tr '\n' ,)" "bad,old,"
eq "$(srv 'host:99999' | head -n1 | cut -f1)" "bad"
rm -rf "$ST"

if [[ -z $FZF ]]; then printf '  – skipped: fzf is not installed (the form)\n'
else
ln -s "$FZF" "$STUBS/fzf"

case_ "first run: syncplay.ini's server, room and name; the join row under the cursor — Enter starts Syncplay"
theme_ini
out=$(together "$TMP/a film's.mkv" 2>&1 <<'EOF'
wait join
settle
screen
lit
key <Enter>
wait args:
key help<Enter>
wait it read: help
screen
quit bye<Enter>
EOF
); r=$?
eq "$r" 0 "the session: $out"
has "$out" "kawau-3f9a on syncplay.pl:8999 as kawau"
has "$out" "syncplay.pl:8999 · public"
lacks "$out" "password" "a public server has no password row"
has "$out" "$TMP/a film's.mkv"
has "$out" "args: [--no-gui] [--] [$TMP/a film's.mkv]" "Syncplay without its window, the film after --, nothing else"
has "$out" "it read: help" "what you type reaches Syncplay"
lacks "$out" "$RADV" "Mesa's RADV line stays out of the terminal"
has "$out" "[vo/gpu-next] another warning" "anything else Syncplay and mpv print still shows"
eq "$(cat "$ST/servers") $(cat "$ST/rooms") $(cat "$ST/names")" "syncplay.pl:8999 kawau-3f9a kawau"
eq "$(ini server_data host):$(ini server_data port) $(ini client_settings room) $(ini client_settings name)" "syncplay.pl:8999 kawau-3f9a kawau"
eq "$(ini server_data password)" "" "a public server: no password in syncplay.ini"
eq "$(ini client_settings playerpath)" "/usr/bin/mpv" "the rest of syncplay.ini stays"
eq "$(stat -c %a "$ST") $(stat -c %a "$INI")" "700 600"

case_ "the cursor starts on join (its row is the highlighted one)"
out=$(together 2>&1 <<'EOF'
wait join
settle
lit
key <Esc>
EOF
)
eq "$(grep -c . <<<"$out")" 1 "one row lit: $out"
has "$out" "kawau-3f9a on"

case_ "another room typed: offered as new, taken; Syncplay, syncplay.ini and the list agree"
out=$(together 2>&1 <<'EOF'
wait join
key <Down><Down><Enter>
wait the one your friends use
key Movie Club 7
wait +  Movie Club 7
settle
screen
key <Enter>
wait Movie Club 7 on syncplay.pl:8999 as kawau
key <Enter>
wait args:
settle
screen
quit bye<Enter>
EOF
); r=$?
eq "$r" 0 "$out"
has "$out" "+  Movie Club 7"
eq "$(ini client_settings room)" "Movie Club 7"
eq "$(tr '\n' , <"$ST/rooms")" "Movie Club 7,kawau-3f9a,"

case_ "next time: the last choice is there — Enter alone rejoins it"
out=$(together 2>&1 <<'EOF'
wait Movie Club 7 on syncplay.pl:8999 as kawau
key <Enter>
wait args:
settle
screen
quit bye<Enter>
EOF
); r=$?
eq "$r" 0 "$out"
has "$out" "args: [--no-gui]"
eq "$(ini client_settings room)" "Movie Club 7"
eq "$(tr '\n' , <"$ST/rooms")" "Movie Club 7,kawau-3f9a," "rejoined: still once"

case_ "the lists keep the last 10, newest first, each once (a doubled line in the file too)"
printf 'r1\nr2\nr3\nr2\nr4\nr5\nr6\nr7\nr8\nr9\nr10\nr11\n' >"$ST/rooms"
out=$(together 2>&1 <<'EOF'
wait join
key <Down><Down><Enter>
wait the one your friends use
settle
screen
key r5
settle
key <Enter>
wait r5 on
key <Enter>
wait args:
settle
screen
quit bye<Enter>
EOF
); r=$?
eq "$r" 0 "$out"
has "$(sed -E 's/   +/  /g' <<<"$out")" "Movie Club 7  now" "the room now, first (its note right-aligned)"
eq "$(tr '\n' , <"$ST/rooms")" "r5,r1,r2,r3,r4,r6,r7,r8,r9,r10,"

case_ "a server of your own, typed without a port: Syncplay's 8999 added, its password asked unseen"
out=$(together 2>&1 <<'EOF'
wait join
key <Down><Enter>
wait type host:port
key films.example
wait +  films.example:8999
key <Enter>
wait the password for this server
key pa55 word
settle
screen
key <Enter>
wait remembered
settle
screen
key <Enter>
wait args:
settle
screen
quit bye<Enter>
EOF
); r=$?
eq "$r" 0 "$out"
has "$out" "r5 on films.example:8999 as kawau"
lacks "$out" "pa55" "the password was shown"
has "$out" "pw in its environment: none" "the password is not in Syncplay's environment"
lacks "$out" "[--password]" "nor on its command line"
eq "$(ini server_data host) $(ini server_data port)" "films.example 8999"
eq "$(ini server_data password)" "pa55 word" "Syncplay reads it from syncplay.ini"
eq "$(stat -c %a "$INI") $(stat -c %a "$ST/passwords")" "600 600"
eq "$(cat "$ST/passwords")" $'films.example:8999\tpa55 word'
eq "$(head -n1 "$ST/servers")" "films.example:8999"

case_ "a public server again: no password row, none in syncplay.ini — and the other's stays remembered"
out=$(together 2>&1 <<'EOF'
wait remembered
key <Down><Enter>
wait type host:port
key 8997
wait syncplay.pl:8997
settle
key <Enter>
wait r5 on syncplay.pl:8997
settle
screen
key <Enter>
wait args:
settle
screen
quit bye<Enter>
EOF
); r=$?
eq "$r" 0 "$out"
lacks "$(sed -n '/on syncplay.pl:8997/,$p' <<<"$out")" "password" "a public server has no password row"
eq "$(ini server_data port) $(ini server_data password)" "8997 "
eq "$(cat "$ST/passwords")" $'films.example:8999\tpa55 word'

case_ "back to it: its password from memory, not asked again"
out=$(together 2>&1 <<'EOF'
wait join
key <Down><Enter>
wait type host:port
key films
wait films.example:8999
settle
key <Enter>
wait remembered
key <Enter>
wait args:
settle
screen
quit bye<Enter>
EOF
); r=$?
eq "$r" 0 "$out"
lacks "$out" "the password for this server"
eq "$(ini server_data password)" "pa55 word"

case_ "the password row: Enter asks again; Enter alone there: the server has none"
out=$(together 2>&1 <<'EOF'
wait remembered
key <Down><Down><Down><Down><Enter>
wait the password for this server
key <Enter>
wait none
key <Esc>
EOF
); r=$?
eq "$r" 0 "$out"
eq "$(ini server_data password)" "pa55 word" "Esc: nothing written"

case_ "the film: Enter on its row opens the file dialog where the film is; cancelled there: none"
mkdir -p "$TMP/films"; : >"$TMP/films/one.mkv"; : >"$TMP/films/two.mkv"
stub kawa-pick 'printf "%s\n" "$TMP/films/two.mkv" >"$5"'
out=$(together "$TMP/films/one.mkv" 2>&1 <<'EOF'
wait $TMP/films/one.mkv
key <Down><Down><Down><Down><Down><Enter>
wait $TMP/films/two.mkv
key <Enter>
wait args:
settle
screen
quit bye<Enter>
EOF
); r=$?
eq "$r" 0 "$out"
called "^kawa-pick 0 0 0 $TMP/films "
has "$out" "args: [--no-gui] [--] [$TMP/films/two.mkv]"
stub kawa-pick ': >"$5"'
out=$(together "$TMP/films/one.mkv" 2>&1 <<'EOF'
wait $TMP/films/one.mkv
key <Down><Down><Down><Down><Down><Enter>
wait mpv finds it by its name
key <Enter>
wait args:
settle
screen
quit bye<Enter>
EOF
); r=$?
eq "$r" 0 "$out"
has "$out" "args: [--no-gui]"; lacks "$out" "[--]" "cancelled: no film"
case_ "W on a folder: no film; the dialog starts in that folder"
reset_calls
out=$(together "$TMP/films" 2>&1 <<'EOF'
wait mpv finds it by its name
key <Down><Down><Down><Down><Down><Enter>
settle
key <Esc>
EOF
)
called "^kawa-pick 0 0 0 $TMP/films "

case_ "Esc in the form: nothing started (exit 1), nothing written"
reset_calls; sum=$(cat "$INI" "$ST"/* | cksum)
out=$(together_rc 2>&1 <<'EOF'
wait join
key <Down><Down><Enter>
wait the one your friends use
key <Esc>
wait join
key <Esc>
wait ended: 1
EOF
); r=$?
eq "$r" 0 "$out"
not_called '^syncplay'
eq "$(cat "$INI" "$ST"/* | cksum)" "$sum"

case_ "syncplay.ini that does not read, or no Syncplay folder: said, nothing started"
printf '[client_settings\nroom = x\n' >"$INI"
out=$(together_rc 2>&1 <<'EOF'
wait does not read as Syncplay's settings
key x
wait ended: 1
EOF
); r=$?
eq "$r" 0 "$out"
theme_ini; mv "$HOME/.local/share/fedokawaii/syncplay" "$TMP/sp-away"
out=$(together_rc 2>&1 <<'EOF'
wait fedokawaii repair puts it back
key x
wait ended: 1
EOF
); r=$?
eq "$r" 0 "$out"
mv "$TMP/sp-away" "$HOME/.local/share/fedokawaii/syncplay"
not_called '^syncplay'
fi

# ── the launcher and yazi ────────────────────────────────────────────────────────────────
config .local/share/applications .config/yazi
case_ "the launcher's Syncplay: kawa-together in a terminal window, no file types"
e=$(cat "$HOME/.local/share/applications/syncplay.desktop")
has "$e" "Exec=$HOME/.local/bin/kawa-term kawa-together %f"
lacks "$e" "MimeType=" "it would compete with mpv for films"
case_ "yazi: W watches the hovered film together (the real yazi: test_yazi.sh)"
has "$(cat "$HOME/.config/yazi/keymap.toml")" 'on = "W",          run = "shell --orphan -- kawa-term kawa-together %h"'
lacks "$(cat "$REPO/configs/home/.config/yazi/yazi.toml")" "[opener]" "the desktop's yazi.toml holds no opener: W is keymap.toml's alone"
case_ "W on a folder: Syncplay starts with no film (the room's is found by name)"
mkdir -p "$TMP/a folder"
printf '[client_settings]\nroom = film-night\n' >"$INI"
eq "$(kawa-together "$TMP/a folder" </dev/null 2>&1 | head -n1)" "args: [--no-gui]"

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
