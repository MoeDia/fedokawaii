#!/usr/bin/env bash
# tests/status/test_nowplaying.sh — kawa-nowplaying: its label on the right of the bar (one
# long-running script feeding waybar JSON: the picture — the cassette for sound, the television
# for a video, standing still while paused —, then the title, a red rule and the artist), the
# sound's wings either side of the clock (kawa-nowplaying --wing left|right, fed through their
# fifos by that same script) and the media keys (kawa-nowplaying play-pause|next|previous).
# playerctl is fake_playerctl: the players and what `--follow` reports come from a script of
# steps; cava is fake_cava (the meter frames in $NP/frames, however many, then quiet). Every
# line the bar gets must parse as JSON, and its text as Pango markup.
. "$(dirname "$0")/lib.sh"
setup() {
  box; . "$HOME/.config/fedokawaii/icons.sh"
  export NP=$TMP/np; mkdir -p "$NP/steps"; : >"$NP/players"
  stub playerctl 'exec bash '"$SD"'/fake_playerctl "$@"'
  stub cava 'exec bash '"$SD"'/fake_cava "$@"'
  stub pw-metadata 'exec bash '"$SD"'/fake_pwmeta "$@"'
}
# P INSTANCE STATUS ARTIST TITLE [URL [ART]] — a player as playerctl's format prints it: six
# fields, its address (xesam:url) and its picture's address (mpris:artUrl) empty unless given
P() { printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s' "$1" "$2" "$3" "$4" "${5:-}" "${6:-}"; }
FILM=file:///home/dia/Videos/film.mkv                 # a video's address, as mpv gives it
step() {   # step EMIT [PLAYER…] — the follow stream prints EMIT ("" = no player); the players then
  local n; n=$(printf '%02d' $(($(find "$NP/steps" -name '*.emit' | wc -l) + 1)))
  printf '%s\n' "$1" >"$NP/steps/$n.emit"; shift
  : >"$NP/steps/$n.state"; local p; for p; do printf '%s\n' "$p" >>"$NP/steps/$n.state"; done
}
bar() { timeout 20 kawa-nowplaying 2>"$TMP/err"; }   # the bar's lines, once the follow stream ends
# shown OUT — each line as "class|text" with the markup taken off (the meter's glyphs stay)
shown() {
  python3 -I -c '
import json, sys, xml.dom.minidom as X
def text(n): return "".join(c.data if c.nodeType == c.TEXT_NODE else text(c) for c in n.childNodes)
for l in sys.argv[1].splitlines():
    j = json.loads(l)
    try: t = text(X.parseString("<m>" + j["text"] + "</m>").documentElement)
    except Exception as e: t = "BAD MARKUP: " + j["text"]
    c = j.get("class", "")
    print((c[0] if isinstance(c, list) else c) + "|" + t)' "$1"
}
markup_ok() { [[ $(shown "$1") != *"BAD MARKUP"* ]] && _ok || _no "not Pango markup: $(shown "$1" | grep 'BAD MARKUP' | head -n 2)"; }
last() { shown "$1" | tail -n 1; }
# minipath TOOL… — a PATH of the stubs, the repository's helpers and just these tools (so a
# real playerctl or cava installed on this machine is never reached)
minipath() {
  mkdir -p "$TMP/bin"; local c; for c; do ln -sf "$(command -v "$c")" "$TMP/bin/$c"; done
  printf '%s' "$STUBS:$REPO/bin:$TMP/bin"
}
alive() { local p; for p in $(cat "$@" 2>/dev/null); do kill -0 "$p" 2>/dev/null && return 0; done; return 1; }
clean() { local p; for p in $(cat "$NP/pids" "$NP/cava.pids" "$NP/pwmeta.pids" 2>/dev/null); do kill "$p" 2>/dev/null; done; }
# strip LINE — a shown label's words: its class and its ICON_BAR_* picture taken off
strip() {
  local t=${1#*|} v
  for v in ICON_BAR_CASSETTE_A ICON_BAR_CASSETTE_B ICON_BAR_TV_{0..3}; do [[ $t == "${!v}"* ]] && { t=${t#"${!v}"}; break; }; done
  printf '%s' "$t"
}
# pic LINE — the picture a shown label (class|text) starts with: 0–3 the television's four
# frames, a b the cassette's two, - none of them
pic() {
  local t=${1#*|} v n k=-
  for n in 0 1 2 3; do v=ICON_BAR_TV_$n; [[ $t == "${!v}"* ]] && k=$n; done
  [[ $t == "$ICON_BAR_CASSETTE_A"* ]] && k=a
  [[ $t == "$ICON_BAR_CASSETTE_B"* ]] && k=b
  printf '%s' "$k"
}
# pics OUT — the picture of every label the bar sent, in order (the hidden lines left out)
pics() { local l s=""; while IFS= read -r l; do [[ -n ${l#*|} ]] && s+=$(pic "$l"); done < <(shown "$1"); printf '%s' "$s"; }
# cava_frames N [LEVEL] — what the fake cava gives: N meter frames, every band at LEVEL (1)
cava_frames() { local f="" i; for i in {1..16}; do f+="${2:-1};"; done; for ((i = 0; i < ${1:?}; i++)); do printf '%s\n' "$f"; done >"$NP/frames"; }
# png W H FILE — a real PNG, W by H pixels (one bit deep, all white: a few hundred bytes);
# art W H — a player's picture: the file:// address of a PNG that size, made in the sandbox
png() {
  python3 -I -c '
import struct, sys, zlib
w, h, f = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
raw = (b"\0" + b"\xff" * ((w + 7) // 8)) * h
open(f, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 1, 0, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))' "$1" "$2" "$3"
}
art() { local f=$TMP/art-$1x$2.png; [[ -e $f ]] || png "$1" "$2" "$f"; printf 'file://%s' "$f"; }
# colour NAME [THEME] — that colour (C_FAINT …) in the theme in use, or in THEME (dark, light);
# columns HEIGHT… — the wings' markup for those column heights, in the theme in use: each one's
# eq icon in its height's ink (colors.sh: C_WING, one ink a height, 1 to 10 px)
colour() (
  local d=current; [[ -n ${2:-} ]] && d=themes/$2
  # shellcheck source=/dev/null
  . "$HOME/.config/fedokawaii/$d/colors.sh"; printf '%s' "${!1}"
)
columns() {
  local ink s="" d v; read -r -a ink <<<"$(colour C_WING)"
  for d; do v=ICON_EQ_$d; s+="<span color='#${ink[d]}'>${!v}</span>"; done
  printf '%s' "$s"
}
# wings_up — both wings' modules running, as waybar runs them (their lines in $TMP/wing-left,
# $TMP/wing-right); wings_down — ended, as waybar ends them
wings_up() {
  local s; for s in left right; do kawa-nowplaying --wing "$s" >"$TMP/wing-$s" 2>&1 & WINGS+=($!); done
  for _ in {1..100}; do [[ -s $XDG_RUNTIME_DIR/kawa-nowplaying/wing-left.pid && -s $XDG_RUNTIME_DIR/kawa-nowplaying/wing-right.pid ]] && break; sleep 0.02; done
}
wings_down() { local p; sleep 0.3; for p in "${WINGS[@]}"; do kill "$p" 2>/dev/null; wait "$p" 2>/dev/null; done; WINGS=(); }
WINGS=()
EQ() { local s="" c; for c; do s+=$(eval "printf %s \"\$ICON_EQ_$c\""); done; printf '%s' "$s"; }

# ── no player, one player ────────────────────────────────────────────────────
case_ "no player: one empty line (the module hidden), then nothing more"
setup; step ""
out=$(bar); r=$?
eq "$out" '{"text":""}'; eq "$r" 0 "ends when the player watcher ends (waybar starts it again)"

case_ "a song plays: the cassette, the title, a red rule, then the artist in the quiet ink (faint); class playing"
setup; step "$(P spotify Playing 'Mariya Takeuchi' 'Plastic Love')"
out=$(bar)
json_lines "$out"; markup_ok "$out"
eq "$(last "$out")" "playing|${ICON_BAR_CASSETTE_A}Plastic Love${ICON_NP_RULE}Mariya Takeuchi"
eq "$(cat "$XDG_RUNTIME_DIR/kawa-nowplaying.player")" spotify "the player shown, kept for the keys"
eq "$(tail -n 1 <<<"$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["class"])')" "['playing', 'r3']" "its class: playing, and the last letter's own air (the i of Takeuchi: 3 px)"
setup; step "$(P mpv Playing '' 'holiday.mkv')"; eq "$(bar | tail -n 1 | python3 -c 'import json,sys; print(json.load(sys.stdin)["class"])')" "['playing', 'r1']" "no artist: the title's last letter (v: its column of air, as every letter's)"
setup; step "$(P spotify Paused 'Cool' 'Song')"; eq "$(bar | tail -n 1 | python3 -c 'import json,sys; print(json.load(sys.stdin)["class"])')" "['paused', 'r3']" "paused; l (of Cool): 3 px of air"
setup; step "$(P spotify Playing 'Mariya Takeuchi' 'Plastic Love')"; out=$(bar)
has "$(tail -n 1 <<<"$out")" "\"${ICON_BAR_CASSETTE_A}<span line_height='14336'>Plastic Love<span color='#$(colour C_ACCENT_TEXT)'>${ICON_NP_RULE}</span><span color='#$(colour C_FAINT)'>Mariya Takeuchi</span></span>\"" "the rule in the accent text colour, the artist quieter than the title"

case_ "… with sound: the meter in the wings either side of the clock (8 thin columns each, 0–9 — a pixel a level, 1 to 10 px —, lowest notes nearest the clock), each column in its height's ink — our red rising, dim at the floor to bright at the top; the label the cassette and the words alone"
setup; printf '%s\n' "0;1;2;3;4;5;6;4;3;2;1;0;0;1;2;6;" "0;2;4;7;8;9;6;3;9;3;1;0;0;5;8;6;" >"$NP/frames"
step "$(P spotify Playing 'Mariya Takeuchi' 'Plastic Love')"
wings_up; out=$(bar); wings_down
json_lines "$out"; eq "$(last "$out")" "playing|${ICON_BAR_CASSETTE_A}Plastic Love${ICON_NP_RULE}Mariya Takeuchi"
L=$(cat "$TMP/wing-left") Rw=$(cat "$TMP/wing-right")
json_lines "$L"; json_lines "$Rw"; markup_ok "$L"; markup_ok "$Rw"
eq "$(head -n 1 <<<"$L")" '{"text":""}' "a wing starts empty"
eq "$(last "$L")" "playing|$(EQ 0 2 4 7 8 9 6 3)" "the left wing: the left channel"
eq "$(last "$Rw")" "playing|$(EQ 9 3 1 0 0 5 8 6)" "the right wing: the right"
read -r -a ladder <<<"$(colour C_WING)"
eq "${#ladder[@]}" 10 "the theme gives ten inks: one a height, 1 to 10 px"
eq "${ladder[9]}" "$(colour C_ACCENT)" "the highest column in the accent itself"
eq "$(tail -n 1 <<<"$L")" "{\"text\":\"$(columns 0 2 4 7 8 9 6 3)\",\"class\":\"playing\"}" "every column its own span: its height's ink"
eq "$(tail -n 1 <<<"$Rw")" "{\"text\":\"$(columns 9 3 1 0 0 5 8 6)\",\"class\":\"playing\"}" "… in the right wing too"
eq "$(grep -o "color='#[0-9a-f]*'" <<<"$L$Rw" | sed "s/color='#//;s/'//" | sort -u)" "$(tr ' ' '\n' <<<"${ladder[*]}" | sort -u)" "heights 0 to 9 all drawn, in the ladder's ten inks and no other (no extra peak lamp, no asagi)"
case_ "… in the light theme: the wings in its own ten reds, the rule and the artist in its inks, nothing of the dark theme's"
setup; ln -sfn themes/light "$HOME/.config/fedokawaii/current"
printf '%s\n' "0;2;4;7;8;9;6;3;9;3;1;0;0;5;8;6;" >"$NP/frames"
step "$(P spotify Playing 'Mariya Takeuchi' 'Plastic Love')"
wings_up; out=$(bar); wings_down
L=$(cat "$TMP/wing-left") Rw=$(cat "$TMP/wing-right")
dark=$(. "$HOME/.config/fedokawaii/themes/dark/colors.sh"; printf '%s %s %s' "$C_WING" "$C_FAINT" "$C_ACCENT_TEXT")
eq "$(tail -n 1 <<<"$L")" "{\"text\":\"$(columns 0 2 4 7 8 9 6 3)\",\"class\":\"playing\"}" "the left wing: the light ladder"
eq "$(tail -n 1 <<<"$Rw")" "{\"text\":\"$(columns 9 3 1 0 0 5 8 6)\",\"class\":\"playing\"}" "the right wing: the light ladder"
has "$(tail -n 1 <<<"$out")" "Plastic Love<span color='#$(colour C_ACCENT_TEXT)'>${ICON_NP_RULE}</span><span color='#$(colour C_FAINT)'>Mariya Takeuchi</span>" "the light accent text and the light faint"
for c in $dark; do lacks "$out$L$Rw" "$c" "the dark theme's $c"; done
case_ "… a switch from the dark theme to the light while it runs: the next label and the wings are in the new theme's inks (read again)"
setup; : >"$NP/hold"; printf '%s\n' "0;2;4;7;8;9;6;3;9;3;1;0;0;5;8;6;" >"$NP/frames"
step "$(P spotify Playing 'Mariya Takeuchi' 'Plastic Love')" "$(P spotify Playing 'Mariya Takeuchi' 'Plastic Love')"
step "$(P spotify Playing 'Mariya Takeuchi' 'Plastic Love II')" "$(P spotify Playing 'Mariya Takeuchi' 'Plastic Love II')"
read -r -a dk <<<"$(colour C_WING dark)"; read -r -a lt <<<"$(colour C_WING light)"
wings_up; ( export NP_GAP=2; exec kawa-nowplaying ) >"$TMP/out" 2>/dev/null & np=$!
waitfor 3 eval 'grep -q "\"playing\"" "$TMP/wing-right"' && _ok || _no "no meter frame in the first 3 s"
ln -sfn themes/light "$HOME/.config/fedokawaii/current"
waitfor 5 eval 'grep -q "Love II" "$TMP/out" && [[ $(tail -n 1 "$TMP/wing-right") == *"${lt[9]}"* ]]' && _ok || _no "the label or the wing never followed the switch"
kill -TERM "$np"; wait "$np" 2>/dev/null; wings_down; clean
first=$(grep -m 1 '"playing"' "$TMP/wing-right"); later=$(tail -n 1 "$TMP/wing-right")
has "$first" "<span color='#${dk[9]}'>$ICON_EQ_9</span>" "the wing's first frame: the dark ladder"
has "$later" "<span color='#${lt[9]}'>$ICON_EQ_9</span>" "the wing after the switch: the light ladder"
lacks "$later" "${dk[9]}" "nothing of the dark ladder left"
has "$(grep -m 1 'Plastic Love<' "$TMP/out")" "<span color='#$(colour C_FAINT dark)'>Mariya" "the label before: the dark faint"
has "$(grep 'Love II' "$TMP/out" | tail -n 1)" "<span color='#$(colour C_FAINT light)'>Mariya" "the label after: the light faint"
case_ "the wings: a module of their own each (--wing left|right), reading a fifo of its own; another side: misuse"
for w in left right; do
  [[ -p $XDG_RUNTIME_DIR/kawa-nowplaying/wing-$w && ! -e $XDG_RUNTIME_DIR/kawa-nowplaying/wing-$w.pid ]] && _ok || _no "$w: its fifo, or a pid file left behind"
done
eq "$(stat -c %a "$XDG_RUNTIME_DIR/kawa-nowplaying")" 700
rc 2 kawa-nowplaying --wing middle; rc 2 kawa-nowplaying --wing
case_ "no wing running (the bar of a monitor without the clock): the label all the same, nothing written to a fifo nobody reads"
setup; printf '%s\n' "5;5;5;5;5;5;5;5;5;5;5;5;5;5;5;5;" >"$NP/frames"
step "$(P spotify Playing A Song)"
out=$(bar); eq "$(last "$out")" "playing|${ICON_BAR_CASSETTE_A}Song${ICON_NP_RULE}A"; [[ ! -e $XDG_RUNTIME_DIR/kawa-nowplaying/wing-left ]] && _ok || _no "a fifo made for a wing that never ran"
case_ "… the reels turn while there is sound (every 12th frame: 5 a second at 60), not in silence"
setup; cava_frames 24
step "$(P spotify Playing A Song)"
out=$(bar)
has "$out" "$ICON_BAR_CASSETTE_B"; has "$out" "$ICON_BAR_CASSETTE_A"
eq "$(pics "$out")" aba "the first reel, the second at the 12th frame, the first again at the 24th"
setup; cava_frames 11; step "$(P spotify Playing A Song)"
eq "$(pics "$(bar)")" a "11 frames: the reels wait"
setup; cava_frames 12; step "$(P spotify Playing A Song)"
eq "$(pics "$(bar)")" ab "the 12th frame turns them"
setup; cava_frames 24 0
step "$(P spotify Playing A Song)"
out=$(bar); lacks "$out" "$ICON_BAR_CASSETTE_B" "silence: the reels stand still"
case_ "a video: the television's picture moves while there is sound (every 10th frame: 6 a second at 60) — its frames 0, 1, 2, 3, then round again —, not in silence"
setup; cava_frames 41; step "$(P mpv Playing '' film.mkv "$FILM")"
eq "$(pics "$(bar)")" 01230 "a new frame at the 10th, 20th, 30th and 40th cava frame"
setup; cava_frames 9; step "$(P mpv Playing '' film.mkv "$FILM")"
eq "$(pics "$(bar)")" 0 "9 frames: it waits"
setup; cava_frames 10; step "$(P mpv Playing '' film.mkv "$FILM")"
eq "$(pics "$(bar)")" 01 "the 10th frame moves it"
setup; cava_frames 41 0; step "$(P mpv Playing '' film.mkv "$FILM")"
eq "$(pics "$(bar)")" 0 "silence: the picture stands still"
setup; cava_frames 9; step "$(P brave.instance1234 Playing Channel 'A video' '' "$(art 1280 720)")"
eq "$(pics "$(bar)")" 0 "a video in a browser (a wide picture): 9 frames, it waits"
setup; cava_frames 10; step "$(P brave.instance1234 Playing Channel 'A video' '' "$(art 1280 720)")"
eq "$(pics "$(bar)")" 01 "… and the 10th frame moves it, as mpv's"
case_ "a frame that is not 16 bands of 0–9 (a band of 10, 11 or 12 too): ignored — a frame of nines, the top, is drawn"
setup; printf '%s\n' "1;2;3;" "10;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;" "1;1;1;1;1;1;1;1;1;1;1;11;1;1;1;1;" "1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;12;" "13;13;13;13;13;13;13;13;13;13;13;13;13;13;13;13;" "1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;" "a;b;c;d;e;f;g;h;i;j;k;l;m;n;o;p;" "-1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;" "9;9;9;9;9;9;9;9;9;9;9;9;9;9;9;9;" >"$NP/frames"
step "$(P spotify Playing Artist Song)"
wings_up; out=$(bar); wings_down; json_lines "$out"
eq "$(cat "$TMP/wing-left" "$TMP/wing-right" | grep -c "$ICON_EQ_1")" 0 "no meter in the wings"
eq "$(shown "$out" | grep -c "$ICON_EQ_1")" 0 "no meter drawn"
eq "$(grep -c '"playing"' "$TMP/wing-left")" 1 "one frame drawn in the left wing: the last"
eq "$(last "$(cat "$TMP/wing-left")") $(last "$(cat "$TMP/wing-right")")" "playing|$(EQ 9 9 9 9 9 9 9 9) playing|$(EQ 9 9 9 9 9 9 9 9)" "the frame of nines: the top of the range"

case_ "no artist (a video): the television and just the title — no rule"
setup; step "$(P mpv Playing '' 'holiday.mkv' file:///home/dia/Videos/holiday.mkv)"
out=$(bar); eq "$(last "$out")" "playing|${ICON_BAR_TV_0}holiday.mkv"; lacks "$out" "$ICON_NP_RULE" "no artist, no rule"

# ── a video or sound ─────────────────────────────────────────────────────────
# One run of the bar over many players, each playing a title of its own (k1, k2 …: no two labels
# alike, so none is dropped as a repeat): kind WANT WHY INSTANCE [URL [ART]] adds one player,
# kinds_check runs the bar and compares each label's picture (pic) with its WANT.
KW=() KY=()
kind() { local n=$((${#KW[@]} + 1)); step "$(P "$3" Playing '' "k$n" "${4:-}" "${5:-}")"; KW+=("$1"); KY+=("$2"); }
kinds_check() {
  local out l t i; local -A got=()
  out=$( export NP_GAP=0.05; bar ); json_lines "$out"
  while IFS= read -r l; do t=${l#*|}; [[ -n $t ]] && got[${t:5}]=$(pic "$l"); done < <(shown "$out")
  for i in "${!KW[@]}"; do eq "${got[k$((i + 1))]:-none}" "${KW[i]}" "${KY[i]}"; done
  KW=() KY=()
}
case_ "mpv: a video or sound by the file's address — an audio file's extension (mp3 flac ogg oga opus m4a wav aac wma ape alac aiff mka, in any case) or no address is sound, any other address a video; its picture is never looked at"
setup
kind 0 "a .mkv file: the television" mpv "$FILM"
for e in mp4 webm avi mov; do kind 0 "a .$e file: the television" mpv "file:///home/dia/Videos/clip.$e"; done
kind 0 "a web address (a stream): the television" mpv 'https://www.youtube.com/watch?v=abc'
kind 0 "a second mpv window (mpv.instance4242): the same" mpv.instance4242 "$FILM"
kind a "no address: the cassette" mpv
for e in mp3 flac ogg oga opus m4a wav aac wma ape alac aiff mka; do kind a "a .$e file: the cassette" mpv "file:///home/dia/Music/song.$e"; done
kind a "capitals (SONG.FLAC): the cassette" mpv file:///home/dia/Music/SONG.FLAC
kind a "a name with spaces (%20): the cassette" mpv 'file:///home/dia/Music/My%20Song.mp3'
kind a "a song with a wide cover: the address says song" mpv file:///home/dia/Music/song.flac "$(art 1280 720)"
kind 0 "a video with a square picture: the address says video" mpv "$FILM" "$(art 640 640)"
kinds_check
case_ "any other player (a browser): a video or sound by its picture — a PNG file wider than 5:4 (width×4 above height×5) is a video's frame, any other shape, or no picture to read, is sound; its address means nothing"
setup
kind 0 "brave.instance1234, a 1280×720 picture: the television" brave.instance1234 '' "$(art 1280 720)"
kind a "a 640×640 sleeve: the cassette" brave.instance1234 '' "$(art 640 640)"
kind a "a portrait 720×1280 picture: the cassette" brave.instance1234 '' "$(art 720 1280)"
kind a "exactly 5:4 (1280×1024): not wide, the cassette" brave.instance1234 '' "$(art 1280 1024)"
kind 0 "a hair wider than 5:4 (1281×1024): the television" brave.instance1234 '' "$(art 1281 1024)"
kind 0 "firefox.instance99, 1920×1080: the same (any player that is not mpv)" firefox.instance99 '' "$(art 1920 1080)"
kind a "no picture at all: the cassette" brave.instance1234
kind a "a picture on the web (http): not read, the cassette" brave.instance1234 '' https://i.ytimg.com/vi/abc/maxresdefault.jpg
kind a "a picture file that is not there: the cassette" brave.instance1234 '' "file://$TMP/no-such.png"
: >"$TMP/empty.png"; kind a "an empty picture file: the cassette" brave.instance1234 '' "file://$TMP/empty.png"
printf '\x89PNG\r\n\x1a\n' >"$TMP/cut.png"; kind a "a picture cut off after its signature: the cassette" brave.instance1234 '' "file://$TMP/cut.png"
kind a "vlc playing a .mkv (only mpv's address is read): the cassette" vlc "$FILM"
kind a "a video's address and a square picture, in a browser: the picture decides" brave.instance1234 "$FILM" "$(art 640 640)"
python3 -I -c 'from PIL import Image; import sys; Image.new("RGB", (1280, 720)).save(sys.argv[1], "WEBP")' "$TMP/wide.webp"
kind a "a wide picture that is not a PNG (WebP): its bytes there are not a size — the cassette" brave.instance1234 '' "file://$TMP/wide.webp"
kinds_check
case_ "the next track is of the other kind: the picture follows it (a song, a video, a song again)"
setup
step "$(P mpv Playing '' one.flac file:///home/dia/Music/one.flac)"
step "$(P mpv Playing '' two.mkv file:///home/dia/Videos/two.mkv)"
step "$(P mpv Playing '' three.mp3 file:///home/dia/Music/three.mp3)"
eq "$(pics "$(bar)")" a0a "the cassette, the television, the cassette"
case_ "…the same name, now a video (mpv: its address is part of what makes a track new): the television"
setup
step "$(P mpv Playing '' film file:///home/dia/Music/film.flac)"
step "$(P mpv Playing '' film file:///home/dia/Videos/film.mkv)"
eq "$(pics "$(bar)")" a0 "the cassette, then the television"

case_ "paused: the same picture as playing, standing still at its first frame (no pause sign) — the cassette for sound —, the title, the rule and the artist, class paused, the wings empty, cava stopped"
setup; printf '%s\n' "5;5;5;5;5;5;5;5;5;5;5;5;5;5;5;5;" >"$NP/frames"
step "$(P spotify Playing A Song)" "$(P spotify Playing A Song)"
step "$(P spotify Paused A Song)" "$(P spotify Paused A Song)"
wings_up; out=$(bar); wings_down
eq "$(tail -n 1 "$TMP/wing-left") $(tail -n 1 "$TMP/wing-right")" '{"text":""} {"text":""}' 
json_lines "$out"
eq "$(last "$out")" "paused|${ICON_BAR_CASSETTE_A}Song${ICON_NP_RULE}A"
waitfor 2 eval '! alive "$NP/cava.pids"' && _ok || _no "cava still runs while paused (2 s on)"
case_ "paused after the picture had moved: back to its first frame and still — the reels (sound), the television (video)"
setup; cava_frames 12
step "$(P spotify Playing A Song)" "$(P spotify Playing A Song)"
step "$(P spotify Paused A Song)" "$(P spotify Paused A Song)"
out=$( export NP_GAP=0.8; bar ); json_lines "$out"
eq "$(pics "$out")" aba "playing: the second reel at the 12th frame; paused: the first again"
eq "$(last "$out")" "paused|${ICON_BAR_CASSETTE_A}Song${ICON_NP_RULE}A"
setup; cava_frames 20
step "$(P mpv Playing '' film.mkv "$FILM")" "$(P mpv Playing '' film.mkv "$FILM")"
step "$(P mpv Paused '' film.mkv "$FILM")" "$(P mpv Paused '' film.mkv "$FILM")"
out=$( export NP_GAP=0.8; bar ); json_lines "$out"
eq "$(pics "$out")" 0120 "playing: frame 1 at the 10th cava frame, 2 at the 20th; paused: frame 0 again"
eq "$(last "$out")" "paused|${ICON_BAR_TV_0}film.mkv" "a paused video: the television, still, at its first frame"
case_ "cava ready before play is pressed: started for a paused player, kept through a pause, ended once nothing has played for GRACE seconds"
setup; : >"$NP/hold"
step "$(P spotify Paused A Song)" "$(P spotify Paused A Song)"
KAWA_NOWPLAYING_GRACE=2 kawa-nowplaying >"$TMP/out" 2>/dev/null & np=$!
waitfor 3 test -s "$NP/cava.pids" && _ok || _no "no cava for a paused player"
sleep 1; alive "$NP/cava.pids" && _ok || _no "cava gone before its grace"
waitfor 4 eval '! alive "$NP/cava.pids"' && _ok || _no "cava still runs after 2 s of nothing playing"
kill -TERM "$np"; wait "$np" 2>/dev/null; clean
setup; : >"$NP/hold"; printf '%s\n' "4;4;4;4;4;4;4;4;4;4;4;4;4;4;4;4;" >"$NP/frames"
step "$(P spotify Playing A Song)" "$(P spotify Playing A Song)"
step "$(P spotify Paused A Song)" "$(P spotify Paused A Song)"
step "$(P spotify Playing A Song)" "$(P spotify Playing A Song)"
kawa-nowplaying >"$TMP/out" 2>/dev/null & np=$!
sleep 1.5; eq "$(wc -l <"$NP/cava.pids")" 1 "playing, paused, playing again: one cava all along (no half-second start)"
kill -TERM "$np"; wait "$np" 2>/dev/null
waitfor 3 eval '! alive "$NP/pids" "$NP/cava.pids"' && _ok || { _no "cava outlived the script"; clean; }
case_ "cava ending by itself (PipeWire restarted): back on its own, the meter goes on"
setup; : >"$NP/hold"; printf '%s\n' "2;2;2;2;2;2;2;2;2;2;2;2;2;2;2;2;" >"$NP/frames"
step "$(P spotify Playing A Song)" "$(P spotify Playing A Song)"
kawa-nowplaying >"$TMP/out" 2>/dev/null & np=$!
waitfor 3 test -s "$NP/cava.pids"; kill "$(head -n 1 "$NP/cava.pids")"
waitfor 3 eval '(($(wc -l <"$NP/cava.pids") == 2))' && _ok || _no "cava not back"
kill -TERM "$np"; wait "$np" 2>/dev/null
waitfor 3 eval '! alive "$NP/pids" "$NP/cava.pids"' && _ok || { _no "cava outlived the script"; clean; }
case_ "a click on play: the wings rise with the first sound, before the player says it plays; never confirmed, back to paused"
setup; : >"$NP/hold"; printf '%s\n' "0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;" "6;6;6;6;6;6;6;6;6;6;6;6;6;6;6;6;" >"$NP/frames"
printf '%s\n' "$(P spotify Paused A Song)" >"$NP/players"
step "$(P spotify Paused A Song)" "$(P spotify Paused A Song)"
mkdir -p "$XDG_RUNTIME_DIR/kawa-nowplaying"; printf '%s\n' "${EPOCHREALTIME/./}" >"$XDG_RUNTIME_DIR/kawa-nowplaying/click"
wings_up; kawa-nowplaying >"$TMP/out" 2>/dev/null & np=$!
waitfor 3 test -s "$NP/cava.pids"; sleep 0.5
eq "$(last "$(cat "$TMP/out")")" "paused|${ICON_BAR_CASSETTE_A}Song${ICON_NP_RULE}A" "a click from before the player paused: not a play (its sound is the fading song)"
printf '%s\n' "${EPOCHREALTIME/./}" >"$XDG_RUNTIME_DIR/kawa-nowplaying/click"
kill "$(head -n 1 "$NP/cava.pids")"                 # (cava again: its frames, the sound, come after the click)
waitfor 3 eval 'grep -q "\"playing\"" "$TMP/out"' && _ok || _no "the label did not follow the click's sound"
has "$(cat "$TMP/wing-left")" "$ICON_EQ_6" "the wing lit at once"
waitfor 4 eval '[[ $(last "$(cat "$TMP/out")") == paused* ]]' && _ok || _no "still playing, the player never said so: $(last "$(cat "$TMP/out")")"
kill -TERM "$np"; wait "$np" 2>/dev/null; wings_down; clean
case_ "… the click itself: noted for the bar only when it plays (the player shown paused), then sent to the player shown"
setup; printf '%s\n' "$(P spotify Paused A Song)" >"$NP/players"; echo spotify >"$XDG_RUNTIME_DIR/kawa-nowplaying.player"
rm -f "$XDG_RUNTIME_DIR/kawa-nowplaying/click"; kawa-nowplaying next
[[ ! -e $XDG_RUNTIME_DIR/kawa-nowplaying/click ]] && _ok || _no "next noted as a click on play"
kawa-nowplaying play-pause; [[ $(cat "$XDG_RUNTIME_DIR/kawa-nowplaying/click") =~ ^[0-9]{16}$ ]] && _ok || _no "no click noted"
eq "$(tail -n 1 "$NP/acted")" "play-pause spotify"
rm -f "$XDG_RUNTIME_DIR/kawa-nowplaying/click"; printf '%s\n' "$(P spotify Playing A Song)" >"$NP/players"
kawa-nowplaying play-pause; [[ ! -e $XDG_RUNTIME_DIR/kawa-nowplaying/click ]] && _ok || _no "a press that pauses noted as a play"
case_ "a meter frame repeated (a pause sends zeros at 60 a second): drawn once"
setup; for i in {1..30}; do echo "0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;"; done >"$NP/frames"
step "$(P spotify Playing A Song)" "$(P spotify Playing A Song)"
wings_up; out=$(bar); wings_down
eq "$(grep -c "\"playing\"" "$TMP/wing-left")" 1 "thirty frames alike: one drawn"

case_ "stopped, or no title yet: hidden"
setup; step "$(P spotify Stopped A Song)" "$(P spotify Stopped A Song)"
eq "$(last "$(bar)")" "|"
setup; step "$(P brave Playing 'Some Channel' '')" "$(P brave Playing 'Some Channel' '')"
eq "$(last "$(bar)")" "|"

# ── several players ──────────────────────────────────────────────────────────
case_ "music plays, then a video in a Brave tab (a wide picture) is paused: the music stays on the bar, its cassette"
setup; bv=$(P brave.instance42 Paused 'Some Channel' 'A video' '' "$(art 1280 720)")
step "$(P spotify Playing Artist Song)" "$(P spotify Playing Artist Song)"
step "$bv" "$bv" "$(P spotify Playing Artist Song)"
out=$(bar)
eq "$(last "$out")" "playing|${ICON_BAR_CASSETTE_A}Song${ICON_NP_RULE}Artist"
eq "$(cat "$XDG_RUNTIME_DIR/kawa-nowplaying.player")" spotify
case_ "both paused: the last one paused is shown (a video: its television, still)"
setup; fv=$(P mpv Paused '' film.mkv "$FILM")
step "$(P spotify Paused Artist Song)" "$(P spotify Paused Artist Song)"
step "$fv" "$(P spotify Paused Artist Song)" "$fv"
eq "$(last "$(bar)")" "paused|${ICON_BAR_TV_0}film.mkv"
case_ "the player shown quits mid-song: the other one (paused) takes its place — with its own picture (the video's television, then the song's cassette)"
setup; mv=$(P mpv Playing '' film.mkv "$FILM")
step "$mv" "$(P spotify Paused Artist Song)" "$mv"
step "$(P spotify Paused Artist Song)" "$(P spotify Paused Artist Song)"
out=$(bar)
has "$(shown "$out")" "playing|${ICON_BAR_TV_0}film.mkv" "the video first"
eq "$(last "$out")" "paused|${ICON_BAR_CASSETTE_A}Song${ICON_NP_RULE}Artist"
case_ "the last player quits: hidden"
setup
step "$(P mpv Playing '' film.mkv)" "$(P mpv Playing '' film.mkv)"
step ""
out=$(bar); json_lines "$out"
eq "$(tail -n 1 <<<"$out")" '{"text":""}'
case_ "a player vanishes between the event and the look at all players: no error, hidden or the rest"
setup
step "$(P mpv Paused '' film.mkv "$FILM")"
out=$(bar); json_lines "$out"
eq "$(last "$out")" "paused|${ICON_BAR_TV_0}film.mkv" "the event's own line is used (its address too)"

# ── odd titles ───────────────────────────────────────────────────────────────
case_ "titles with & < > ' \" and a backslash: valid JSON, escaped markup, shown as they are"
setup
step "$(P spotify Playing "Tom & Jerry's \"Band\"" "<Live> 'Hall' \\ & more")"
out=$(bar)
json_lines "$out"; markup_ok "$out"
eq "$(last "$out")" "playing|${ICON_BAR_CASSETTE_A}<Live> 'Hall' \\ & more${ICON_NP_RULE}Tom & Jerry's" "(an artist over 16 letters: cut at a word's end)"
case_ "… also while paused"
setup; step "$(P spotify Paused "A&B" "<x>")"
out=$(bar); json_lines "$out"; markup_ok "$out"
eq "$(last "$out")" "paused|${ICON_BAR_CASSETTE_A}<x>${ICON_NP_RULE}A&B"
case_ "control characters (tab, ESC, CR) in a title: spaces, still valid JSON"
setup; step "$(P spotify Playing $'Art\tist' $'Ti\x1btle\rhere')"
out=$(bar); json_lines "$out"
eq "$(last "$out")" "playing|${ICON_BAR_CASSETTE_A}Ti tle here${ICON_NP_RULE}Art ist"
case_ "a title with a line break: the first line shown, the rest skipped, nothing stops"
setup; printf '%s\n' "1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;" >"$NP/frames"
step "$(P mpv Playing '' $'Part one\nPart two')" "$(P mpv Playing '' 'Part one')"
wings_up; out=$(bar); wings_down; json_lines "$out"
eq "$(last "$out")" "playing|${ICON_BAR_CASSETTE_A}Part one"
eq "$(last "$(cat "$TMP/wing-left")") $(last "$(cat "$TMP/wing-right")")" "playing|$(EQ 1 1 1 1 1 1 1 1) playing|$(EQ 1 1 1 1 1 1 1 1)"
case_ "a very long title: the artist cut at a word's end to 16 letters or fewer, the title to what is left of 40 (the rule between them counts for two) — never an ellipsis"
setup; step "$(P spotify Playing 'Some Extremely Long Artist Name That Goes On' 'An Even Longer Title Of A Song That Never Ends At All')"
t=$(last "$(bar)"); t=$(strip "$t")
eq "$t" "An Even Longer Title Of${ICON_NP_RULE}Some Extremely"
((${#t} + 1 <= 40)) && _ok || _no "${#t} characters and the rule, which counts for two"; lacks "$t" "…"
case_ "one long word: its last letters go (never half a letter: an accent stays with its letter)"
setup; step "$(P spotify Playing '' "Abcdefghijklmnopqrstuvwxyzabcdefghijklm"$'e\u0301'"xyz")"
t=$(last "$(bar)"); t=$(strip "$t")
eq "$t" "Abcdefghijklmnopqrstuvwxyzabcdefghijklm" "the e and its accent (letters 40 and 41) go together"
case_ "Arabic and Japanese: counted in characters (never cut mid-letter), valid JSON"
setup; step "$(P spotify Playing 'فيروز' 'نسم علينا الهوى من مفرق الوادي يا هوى دخل الهوى خدني على بلادي')"
out=$(bar); json_lines "$out"
t=$(last "$out"); t=$(strip "$t")
eq "$t" "نسم علينا الهوى من مفرق الوادي يا${ICON_NP_RULE}فيروز" "Arabic is written with spaces: cut at a word's end"
setup; step "$(P spotify Playing '竹内まりや' 'プラスティック・ラヴ（2021リマスター・エクステンデッド・クラブ・ミックス・バージョン）')"
out=$(bar); json_lines "$out"
t=$(last "$out"); t=$(strip "$t")
eq "$t" "プラスティック・ラヴ（2021リマスター・エクステンデッド・クラブ${ICON_NP_RULE}竹内まりや" "Japanese has no spaces: cut at a character, all 33 that are left of the 40 (the artist 5, the rule 2)"
case_ "… also when the session's locale is C (byte counting would cut a letter in half)"
setup; step "$(P spotify Playing '竹内まりや' 'プラスティック・ラヴ（2021リマスター・エクステンデッド・クラブ・ミックス・バージョン）')"
out=$(LC_ALL=C bar); json_lines "$out"
t=$(last "$out"); t=$(strip "$t")
eq "$t" "プラスティック・ラヴ（2021リマスター・エクステンデッド・クラブ${ICON_NP_RULE}竹内まりや"
setup; step "$(P spotify Playing 'คาราบาว' 'เมดอินไทยแลนด์เวอร์ชันพิเศษที่ยาวมากจนต้องตัดออกบ้าง')"
out=$(LC_ALL=C bar); json_lines "$out"
t=$(last "$out"); t=$(strip "$t")
eq "${#t}" 39 "Thai has no spaces either: a character's edge (31 of the title, the rule, 7 of the artist)"; eq "$t" "เมดอินไทยแลนด์เวอร์ชันพิเศษที่ย${ICON_NP_RULE}คาราบาว"

# ── the program around it ────────────────────────────────────────────────────
case_ "playerctl missing: the module hidden, and the script ends (waybar starts it again a second later)"
setup; rm "$STUBS/playerctl"
out=$(PATH=$(minipath bash cat timeout pkill pgrep) timeout 10 kawa-nowplaying 2>/dev/null); r=$?
eq "$out" '{"text":""}'; eq "$r" 0
case_ "cava missing: the cassette and the title, no meter"
setup; rm "$STUBS/cava"; printf '%s\n' "5;5;5;5;5;5;5;5;5;5;5;5;5;5;5;5;" >"$NP/frames"
step "$(P spotify Playing A Song)"
out=$(PATH=$(minipath bash cat timeout pkill pgrep cp cut grep head) bar)
eq "$(last "$out")" "playing|${ICON_BAR_CASSETTE_A}Song${ICON_NP_RULE}A"
case_ "the bar goes away (waybar killed: SIGPIPE ignored, the next write fails): the script ends, playerctl and cava with it"
setup; : >"$NP/hold"; printf '%s\n' "1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;" >"$NP/frames"
step "$(P spotify Playing A Song)" "$(P spotify Playing A Song)"
step "$(P spotify Paused A Song)" "$(P spotify Paused A Song)"
step "$(P spotify Playing A Song)" "$(P spotify Playing A Song)"
( trap '' PIPE; exec timeout 20 kawa-nowplaying ) | head -n 1 >/dev/null
waitfor 3 eval '! alive "$NP/pids" "$NP/cava.pids"' && _ok || { _no "playerctl or cava outlived the bar"; clean; }
case_ "… also when it happens just as cava starts for a song (12 tries at random moments)"
left=0
for i in {1..12}; do
  setup; : >"$NP/hold"; printf '%s\n' "1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;" >"$NP/frames"
  step "$(P spotify Playing A Song)" "$(P spotify Playing A Song)"
  step "$(P spotify Paused A Song)" "$(P spotify Paused A Song)"
  step "$(P spotify Playing A Song)" "$(P spotify Playing A Song)"
  ( trap '' PIPE; export NP_GAP=0.02; exec timeout 20 kawa-nowplaying ) 2>/dev/null | head -n $((i % 3 + 1)) >/dev/null
  waitfor 3 eval '! alive "$NP/pids" "$NP/cava.pids"' || { left=$((left + 1)); clean; }
done
eq "$left" 0 "runs that left cava or playerctl behind"
case_ "killed by waybar (SIGTERM): playerctl and cava go too"
setup; : >"$NP/hold"; printf '%s\n' "1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;" >"$NP/frames"
step "$(P spotify Playing A Song)" "$(P spotify Playing A Song)"
kawa-nowplaying >"$TMP/out" 2>/dev/null & np=$!
waitfor 3 test -s "$NP/cava.pids"
kill -TERM "$np"; wait "$np" 2>/dev/null
waitfor 3 eval '! alive "$NP/pids" "$NP/cava.pids"' && _ok || { _no "playerctl or cava outlived the script"; clean; }
json_lines "$(cat "$TMP/out")"

case_ "the default output changes while a song plays (headphones, a headset): cava starts again on it, the one before gone"
setup; : >"$NP/hold"; printf '%s\n' "1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;" >"$NP/frames"; echo headset >"$NP/sink-later"
step "$(P spotify Playing A Song)" "$(P spotify Playing A Song)"
kawa-nowplaying >"$TMP/out" 2>/dev/null & np=$!
waitfor 5 eval '(($(cat "$NP/cava.pids" 2>/dev/null | wc -l) == 2))' && _ok || _no "cava not started again ($(wc -l <"$NP/cava.pids" 2>/dev/null) start(s))"
eq "$(cat "$NP/pwmeta.args")" "-n default -m" "PipeWire's default output, watched"
waitfor 3 eval '! kill -0 "$(head -n 1 "$NP/cava.pids")" 2>/dev/null' && _ok || _no "the first cava still runs"
kill -TERM "$np"; wait "$np" 2>/dev/null
waitfor 3 eval '! alive "$NP/pids" "$NP/cava.pids" "$NP/pwmeta.pids"' && _ok || { _no "playerctl, cava or pw-metadata outlived the script"; clean; }
case_ "… the same output said again (another key changed): cava left running"
setup; : >"$NP/hold"; printf '%s\n' "1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;" >"$NP/frames"; echo speakers >"$NP/sink-later"
step "$(P spotify Playing A Song)" "$(P spotify Playing A Song)"
kawa-nowplaying >"$TMP/out" 2>/dev/null & np=$!
waitfor 3 test -s "$NP/cava.pids"; sleep 1.5
eq "$(wc -l <"$NP/cava.pids")" 1 "one cava"
kill -TERM "$np"; wait "$np" 2>/dev/null
waitfor 3 eval '! alive "$NP/pids" "$NP/cava.pids" "$NP/pwmeta.pids"' && _ok || { _no "something outlived the script"; clean; }

# ── the media keys ───────────────────────────────────────────────────────────
keys() { printf '%s\n' "$@" >"$NP/players"; }
acted() { cat "$NP/acted" 2>/dev/null; }
case_ "play-pause with music playing and a video paused (the video started first): the music"
setup; keys "$(P brave.instance42 Paused Ch Video)" "$(P spotify Playing A Song)"
rc 0 kawa-nowplaying play-pause
eq "$(acted)" "play-pause spotify"
case_ "next / previous: to the player that plays"
: >"$NP/acted"; kawa-nowplaying next; kawa-nowplaying previous
eq "$(acted)" "next spotify"$'\n'"previous spotify"
case_ "two playing: the one the bar shows"
setup; keys "$(P mpv Playing '' film)" "$(P spotify Playing A Song)"; echo spotify >"$XDG_RUNTIME_DIR/kawa-nowplaying.player"
kawa-nowplaying play-pause; eq "$(acted)" "play-pause spotify"
case_ "nothing playing: the one the bar shows (the last paused), not the first player"
setup; keys "$(P brave Paused Ch Video)" "$(P spotify Paused A Song)"; echo spotify >"$XDG_RUNTIME_DIR/kawa-nowplaying.player"
kawa-nowplaying play-pause; eq "$(acted)" "play-pause spotify"
case_ "the bar's player has quit since: playerctl's own pick"
setup; keys "$(P brave Paused Ch Video)"; echo spotify >"$XDG_RUNTIME_DIR/kawa-nowplaying.player"
rc 0 kawa-nowplaying play-pause; eq "$(acted)" "play-pause brave"
case_ "the bar not running (no file): a playing one, else playerctl's own pick"
setup; keys "$(P brave Paused Ch Video)" "$(P mpv Playing '' film)"
kawa-nowplaying play-pause; eq "$(acted)" "play-pause mpv"
case_ "no player at all: could not (1)"
setup
rc 1 kawa-nowplaying play-pause
case_ "playerctl missing: could not (1)"
setup; rm "$STUBS/playerctl"
PATH=$(minipath bash cat timeout) kawa-nowplaying play-pause 2>/dev/null; eq "$?" 1
case_ "a player name with spaces or a leading dash is passed as one argument"
setup; keys "$(P '-weird player' Playing A Song)"
kawa-nowplaying next; eq "$(acted)" "next -weird player"

case_ "misuse (2); --help (0)"
setup
rc 2 kawa-nowplaying stop
rc 2 kawa-nowplaying --frobnicate
out=$(kawa-nowplaying --help); r=$?
eq "$r" 0; has "$out" "kawa-nowplaying play-pause|next|previous"

done_
