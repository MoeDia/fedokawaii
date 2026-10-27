#!/usr/bin/env bash
# tests/status/test_nowplaying.sh — kawa-nowplaying: its label on the right of the bar (one
# long-running script feeding waybar JSON: the cassette or the pause sign, then the words), the
# sound's wings either side of the clock (kawa-nowplaying --wing left|right, fed through their
# fifos by that same script) and the media keys (kawa-nowplaying play-pause|next|previous).
# playerctl is fake_playerctl: the players and what `--follow` reports come from a script of
# steps; cava is fake_cava (a few meter frames, then quiet). Every line the bar gets must
# parse as JSON, and its text as Pango markup.
. "$(dirname "$0")/lib.sh"
setup() {
  box; . "$HOME/.config/fedokawaii/icons.sh"
  export NP=$TMP/np; mkdir -p "$NP/steps"; : >"$NP/players"
  stub playerctl 'exec bash '"$SD"'/fake_playerctl "$@"'
  stub cava 'exec bash '"$SD"'/fake_cava "$@"'
  stub pw-metadata 'exec bash '"$SD"'/fake_pwmeta "$@"'
}
P() { printf '%s\x1f%s\x1f%s\x1f%s' "$@"; }          # P INSTANCE STATUS ARTIST TITLE — a player
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
# strip LINE — a shown label's words: its class and its ICON_BAR_* sign taken off
strip() { local t=${1#*|}; t=${t#"$ICON_BAR_CASSETTE_A"}; t=${t#"$ICON_BAR_CASSETTE_B"}; t=${t#"$ICON_BAR_PAUSE"}; printf '%s' "$t"; }
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

case_ "a song plays: the cassette, the title, then (two spaces on) the artist in the quiet ink (faint); class playing"
setup; step "$(P spotify Playing 'Mariya Takeuchi' 'Plastic Love')"
out=$(bar)
json_lines "$out"
eq "$(last "$out")" "playing|${ICON_BAR_CASSETTE_A}Plastic Love  Mariya Takeuchi"
eq "$(cat "$XDG_RUNTIME_DIR/kawa-nowplaying.player")" spotify "the player shown, kept for the keys"
eq "$(tail -n 1 <<<"$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["class"])')" "['playing', 'r3']" "its class: playing, and the last letter's own air (the i of Takeuchi: 3 px)"
setup; step "$(P mpv Playing '' 'holiday.mkv')"; eq "$(bar | tail -n 1 | python3 -c 'import json,sys; print(json.load(sys.stdin)["class"])')" "['playing', 'r1']" "no artist: the title's last letter (v: its column of air, as every letter's)"
setup; step "$(P spotify Paused 'Cool' 'Song')"; eq "$(bar | tail -n 1 | python3 -c 'import json,sys; print(json.load(sys.stdin)["class"])')" "['paused', 'r3']" "paused; l (of Cool): 3 px of air"
setup; step "$(P spotify Playing 'Mariya Takeuchi' 'Plastic Love')"; out=$(bar)
has "$(tail -n 1 <<<"$out")" "\"${ICON_BAR_CASSETTE_A}<span line_height='14336'>Plastic Love  <span color='#$(. "$HOME/.config/fedokawaii/current/colors.sh"; echo "$C_FAINT")'>Mariya Takeuchi</span></span>\"" "the artist quieter than the title"

case_ "… with sound: the meter in the wings either side of the clock (8 thin columns each, 0–12 — a pixel a level —, lowest notes nearest the clock), each column in its height's ink — edge2, faint, muted, text; the label the cassette and the words alone"
setup; printf '%s\n' "0;1;2;3;4;5;6;4;3;2;1;0;0;1;2;6;" "0;2;4;7;8;10;12;9;11;3;1;0;0;5;12;6;" >"$NP/frames"
step "$(P spotify Playing 'Mariya Takeuchi' 'Plastic Love')"
wings_up; out=$(bar); wings_down
json_lines "$out"; eq "$(last "$out")" "playing|${ICON_BAR_CASSETTE_A}Plastic Love  Mariya Takeuchi"
L=$(cat "$TMP/wing-left") Rw=$(cat "$TMP/wing-right")
json_lines "$L"; json_lines "$Rw"; markup_ok "$L"; markup_ok "$Rw"
eq "$(head -n 1 <<<"$L")" '{"text":""}' "a wing starts empty"
eq "$(last "$L")" "playing|$(EQ 0 2 4 7 8 10 12 9)" "the left wing: the left channel"
eq "$(last "$Rw")" "playing|$(EQ 11 3 1 0 0 5 12 6)" "the right wing: the right"
tiers=$(. "$HOME/.config/fedokawaii/current/colors.sh"; s=""; ink=("$C_EDGE2" "$C_FAINT" "$C_FAINT" "$C_FAINT" "$C_MUTED" "$C_MUTED" "$C_MUTED" "$C_MUTED" "$C_TEXT" "$C_TEXT" "$C_TEXT" "$C_TEXT" "$C_TEXT")
  for d in 0 2 4 7 8 10 12 9; do v=ICON_EQ_$d; s+="<span color='#${ink[d]}'>${!v}</span>"; done; printf '%s' "$s")
eq "$(tail -n 1 <<<"$L")" "{\"text\":\"$tiers\",\"class\":\"playing\"}" "every column its own span: its height's ink"
lacks "$L$Rw" "$(. "$HOME/.config/fedokawaii/current/colors.sh"; echo "$C_ACCENT")" "no vermilion peak lamp any more"; lacks "$L$Rw" "$(. "$HOME/.config/fedokawaii/current/colors.sh"; echo "$C_TEAL")" "no asagi"
case_ "the wings: a module of their own each (--wing left|right), reading a fifo of its own; another side: misuse"
for w in left right; do
  [[ -p $XDG_RUNTIME_DIR/kawa-nowplaying/wing-$w && ! -e $XDG_RUNTIME_DIR/kawa-nowplaying/wing-$w.pid ]] && _ok || _no "$w: its fifo, or a pid file left behind"
done
eq "$(stat -c %a "$XDG_RUNTIME_DIR/kawa-nowplaying")" 700
rc 2 kawa-nowplaying --wing middle; rc 2 kawa-nowplaying --wing
case_ "no wing running (the bar of a monitor without the clock): the label all the same, nothing written to a fifo nobody reads"
setup; printf '%s\n' "5;5;5;5;5;5;5;5;5;5;5;5;5;5;5;5;" >"$NP/frames"
step "$(P spotify Playing A Song)"
out=$(bar); eq "$(last "$out")" "playing|${ICON_BAR_CASSETTE_A}Song  A"; [[ ! -e $XDG_RUNTIME_DIR/kawa-nowplaying/wing-left ]] && _ok || _no "a fifo made for a wing that never ran"
case_ "… the reels turn while there is sound (every 12th frame: 5 a second at 60), not in silence"
setup; for i in {1..24}; do echo "1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;"; done >"$NP/frames"
step "$(P mpv Playing '' 'film.mkv')"
out=$(bar)
has "$out" "$ICON_BAR_CASSETTE_B"; has "$out" "$ICON_BAR_CASSETTE_A"
setup; for i in {1..24}; do echo "0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;"; done >"$NP/frames"
step "$(P mpv Playing '' 'film.mkv')"
out=$(bar); lacks "$out" "$ICON_BAR_CASSETTE_B" "silence: the reels stand still"
case_ "a frame that is not 16 bands of 0–12: ignored"
setup; printf '%s\n' "1;2;3;" "13;13;13;13;13;13;13;13;13;13;13;13;13;13;13;13;" "1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;" "a;b;c;d;e;f;g;h;i;j;k;l;m;n;o;p;" "-1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;" >"$NP/frames"
step "$(P spotify Playing Artist Song)"
wings_up; out=$(bar); wings_down; json_lines "$out"
eq "$(cat "$TMP/wing-left" "$TMP/wing-right" | grep -c "$ICON_EQ_1")" 0 "no meter in the wings"
eq "$(shown "$out" | grep -c "$ICON_EQ_1")" 0 "no meter drawn"

case_ "no artist (a video): just the title"
setup; step "$(P mpv Playing '' 'holiday.mkv')"
eq "$(last "$(bar)")" "playing|${ICON_BAR_CASSETTE_A}holiday.mkv"

case_ "paused: the pause icon, the title, class paused, the wings empty, cava stopped"
setup; printf '%s\n' "5;5;5;5;5;5;5;5;5;5;5;5;5;5;5;5;" >"$NP/frames"
step "$(P spotify Playing A Song)" "$(P spotify Playing A Song)"
step "$(P spotify Paused A Song)" "$(P spotify Paused A Song)"
wings_up; out=$(bar); wings_down
eq "$(tail -n 1 "$TMP/wing-left") $(tail -n 1 "$TMP/wing-right")" '{"text":""} {"text":""}' 
json_lines "$out"
eq "$(last "$out")" "paused|${ICON_BAR_PAUSE}Song  A"
waitfor 2 eval '! alive "$NP/cava.pids"' && _ok || _no "cava still runs while paused (2 s on)"
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
eq "$(last "$(cat "$TMP/out")")" "paused|${ICON_BAR_PAUSE}Song  A" "a click from before the player paused: not a play (its sound is the fading song)"
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
case_ "music plays, then a video in a Brave tab is paused: the music stays on the bar"
setup
step "$(P spotify Playing Artist Song)" "$(P spotify Playing Artist Song)"
step "$(P brave.instance42 Paused 'Some Channel' 'A video')" "$(P brave.instance42 Paused 'Some Channel' 'A video')" "$(P spotify Playing Artist Song)"
out=$(bar)
eq "$(last "$out")" "playing|${ICON_BAR_CASSETTE_A}Song  Artist"
eq "$(cat "$XDG_RUNTIME_DIR/kawa-nowplaying.player")" spotify
case_ "both paused: the last one paused is shown"
setup
step "$(P spotify Paused Artist Song)" "$(P spotify Paused Artist Song)"
step "$(P mpv Paused '' film.mkv)" "$(P spotify Paused Artist Song)" "$(P mpv Paused '' film.mkv)"
eq "$(last "$(bar)")" "paused|${ICON_BAR_PAUSE}film.mkv"
case_ "the player shown quits mid-song: the other one (paused) takes its place"
setup
step "$(P mpv Playing '' film.mkv)" "$(P spotify Paused Artist Song)" "$(P mpv Playing '' film.mkv)"
step "$(P spotify Paused Artist Song)" "$(P spotify Paused Artist Song)"
out=$(bar)
eq "$(last "$out")" "paused|${ICON_BAR_PAUSE}Song  Artist"
case_ "the last player quits: hidden"
setup
step "$(P mpv Playing '' film.mkv)" "$(P mpv Playing '' film.mkv)"
step ""
out=$(bar); json_lines "$out"
eq "$(tail -n 1 <<<"$out")" '{"text":""}'
case_ "a player vanishes between the event and the look at all players: no error, hidden or the rest"
setup
step "$(P mpv Paused '' film.mkv)"
out=$(bar); json_lines "$out"
eq "$(last "$out")" "paused|${ICON_BAR_PAUSE}film.mkv" "the event's own line is used"

# ── odd titles ───────────────────────────────────────────────────────────────
case_ "titles with & < > ' \" and a backslash: valid JSON, escaped markup, shown as they are"
setup
step "$(P spotify Playing "Tom & Jerry's \"Band\"" "<Live> 'Hall' \\ & more")"
out=$(bar)
json_lines "$out"; markup_ok "$out"
eq "$(last "$out")" "playing|${ICON_BAR_CASSETTE_A}<Live> 'Hall' \\ & more  Tom & Jerry's" "(an artist over 16 letters: cut at a word's end)"
case_ "… also while paused"
setup; step "$(P spotify Paused "A&B" "<x>")"
out=$(bar); json_lines "$out"; markup_ok "$out"
eq "$(last "$out")" "paused|${ICON_BAR_PAUSE}<x>  A&B"
case_ "control characters (tab, ESC, CR) in a title: spaces, still valid JSON"
setup; step "$(P spotify Playing $'Art\tist' $'Ti\x1btle\rhere')"
out=$(bar); json_lines "$out"
eq "$(last "$out")" "playing|${ICON_BAR_CASSETTE_A}Ti tle here  Art ist"
case_ "a title with a line break: the first line shown, the rest skipped, nothing stops"
setup; printf '%s\n' "1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;" >"$NP/frames"
step "$(P mpv Playing '' $'Part one\nPart two')" "$(P mpv Playing '' 'Part one')"
wings_up; out=$(bar); wings_down; json_lines "$out"
eq "$(last "$out")" "playing|${ICON_BAR_CASSETTE_A}Part one"
eq "$(last "$(cat "$TMP/wing-left")") $(last "$(cat "$TMP/wing-right")")" "playing|$(EQ 1 1 1 1 1 1 1 1) playing|$(EQ 1 1 1 1 1 1 1 1)"
case_ "a very long title: the artist cut at a word's end to 16 letters or fewer, the title to what is left of 40 (two spaces between) — never an ellipsis"
setup; step "$(P spotify Playing 'Some Extremely Long Artist Name That Goes On' 'An Even Longer Title Of A Song That Never Ends At All')"
t=$(last "$(bar)"); t=$(strip "$t")
eq "$t" "An Even Longer Title Of  Some Extremely"
((${#t} <= 40)) && _ok || _no "${#t} characters"; lacks "$t" "…"
case_ "one long word: its last letters go (never half a letter: an accent stays with its letter)"
setup; step "$(P spotify Playing '' "Abcdefghijklmnopqrstuvwxyzabcdefghijklm"$'e\u0301'"xyz")"
t=$(last "$(bar)"); t=$(strip "$t")
eq "$t" "Abcdefghijklmnopqrstuvwxyzabcdefghijklm" "the e and its accent (letters 40 and 41) go together"
case_ "Arabic and Japanese: counted in characters (never cut mid-letter), valid JSON"
setup; step "$(P spotify Playing 'فيروز' 'نسم علينا الهوى من مفرق الوادي يا هوى دخل الهوى خدني على بلادي')"
out=$(bar); json_lines "$out"
t=$(last "$out"); t=$(strip "$t")
eq "$t" "نسم علينا الهوى من مفرق الوادي يا  فيروز" "Arabic is written with spaces: cut at a word's end"
setup; step "$(P spotify Playing '竹内まりや' 'プラスティック・ラヴ（2021リマスター・エクステンデッド・クラブ・ミックス・バージョン）')"
out=$(bar); json_lines "$out"
t=$(last "$out"); t=$(strip "$t")
eq "$t" "プラスティック・ラヴ（2021リマスター・エクステンデッド・クラブ  竹内まりや" "Japanese has no spaces: cut at a character, all 40"
case_ "… also when the session's locale is C (byte counting would cut a letter in half)"
setup; step "$(P spotify Playing '竹内まりや' 'プラスティック・ラヴ（2021リマスター・エクステンデッド・クラブ・ミックス・バージョン）')"
out=$(LC_ALL=C bar); json_lines "$out"
t=$(last "$out"); t=$(strip "$t")
eq "$t" "プラスティック・ラヴ（2021リマスター・エクステンデッド・クラブ  竹内まりや"
setup; step "$(P spotify Playing 'คาราบาว' 'เมดอินไทยแลนด์เวอร์ชันพิเศษที่ยาวมากจนต้องตัดออกบ้าง')"
out=$(LC_ALL=C bar); json_lines "$out"
t=$(last "$out"); t=$(strip "$t")
eq "${#t}" 40 "Thai has no spaces either: a character's edge"; eq "$t" "เมดอินไทยแลนด์เวอร์ชันพิเศษที่ย  คาราบาว"

# ── the program around it ────────────────────────────────────────────────────
case_ "playerctl missing: the module hidden, and the script ends (waybar starts it again a second later)"
setup; rm "$STUBS/playerctl"
out=$(PATH=$(minipath bash cat timeout pkill pgrep) timeout 10 kawa-nowplaying 2>/dev/null); r=$?
eq "$out" '{"text":""}'; eq "$r" 0
case_ "cava missing: the cassette and the title, no meter"
setup; rm "$STUBS/cava"; printf '%s\n' "5;5;5;5;5;5;5;5;5;5;5;5;5;5;5;5;" >"$NP/frames"
step "$(P spotify Playing A Song)"
out=$(PATH=$(minipath bash cat timeout pkill pgrep cp cut grep head) bar)
eq "$(last "$out")" "playing|${ICON_BAR_CASSETTE_A}Song  A"
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
