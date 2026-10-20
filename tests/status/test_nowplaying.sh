#!/usr/bin/env bash
# tests/status/test_nowplaying.sh — kawa-nowplaying, the middle of the bar (one long-running
# script feeding waybar JSON) and the media keys (kawa-nowplaying play-pause|next|previous).
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
    print(j.get("class", "") + "|" + t)' "$1"
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
EQ() { local s="" c; for c; do case $c in 5) s+=$ICON_EQ_5$ICON_EQ_CAP ;; *) s+=$(eval "printf %s \"\$ICON_EQ_$c\"") ;; esac; done; printf '%s' "$s"; }

# ── no player, one player ────────────────────────────────────────────────────
case_ "no player: one empty line (the module hidden), then nothing more"
setup; step ""
out=$(bar); r=$?
eq "$out" '{"text":""}'; eq "$r" 0 "ends when the player watcher ends (waybar starts it again)"

case_ "a song plays: the cassette, 'artist — title', class playing"
setup; step "$(P spotify Playing 'Mariya Takeuchi' 'Plastic Love')"
out=$(bar)
json_lines "$out"
eq "$(last "$out")" "playing|$ICON_CASSETTE_A  Mariya Takeuchi — Plastic Love"
eq "$(cat "$XDG_RUNTIME_DIR/kawa-nowplaying.player")" spotify "the player shown, kept for the keys"

case_ "… with sound: the meter around it, lowest notes nearest the title, a full column's top lit vermilion"
setup; printf '%s\n' "0;1;2;3;4;5;5;4;3;2;1;0;0;1;2;3;" >"$NP/frames"
step "$(P spotify Playing 'Mariya Takeuchi' 'Plastic Love')"
out=$(bar)
json_lines "$out"; markup_ok "$out"
eq "$(last "$out")" "playing|$(EQ 0 1 2 3 4 5 5 4)  $ICON_CASSETTE_A  Mariya Takeuchi — Plastic Love  $(EQ 3 2 1 0 0 1 2 3)"
has "$(tail -n 1 <<<"$out")" "<span color='#$(. "$HOME/.config/fedokawaii/current/colors.sh"; echo "$C_ACCENT")'>$ICON_EQ_CAP</span>" "the peak lamp"
case_ "… the reels turn while there is sound (every 12th frame: 5 a second at 60), not in silence"
setup; for i in {1..24}; do echo "1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;"; done >"$NP/frames"
step "$(P mpv Playing '' 'film.mkv')"
out=$(bar)
has "$out" "$ICON_CASSETTE_B"; has "$out" "$ICON_CASSETTE_A"
setup; for i in {1..24}; do echo "0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;"; done >"$NP/frames"
step "$(P mpv Playing '' 'film.mkv')"
out=$(bar); lacks "$out" "$ICON_CASSETTE_B" "silence: the reels stand still"
case_ "a frame that is not 16 bands of 0–5: ignored"
setup; printf '%s\n' "1;2;3;" "9;9;9;9;9;9;9;9;9;9;9;9;9;9;9;9;" "a;b;c;d;e;f;g;h;i;j;k;l;m;n;o;p;" >"$NP/frames"
step "$(P spotify Playing Artist Song)"
out=$(bar); json_lines "$out"
eq "$(shown "$out" | grep -c "$ICON_EQ_1")" 0 "no meter drawn"

case_ "no artist (a video): just the title"
setup; step "$(P mpv Playing '' 'holiday.mkv')"
eq "$(last "$(bar)")" "playing|$ICON_CASSETTE_A  holiday.mkv"

case_ "paused: the pause icon, the title, class paused, no meter, cava stopped"
setup; printf '%s\n' "5;5;5;5;5;5;5;5;5;5;5;5;5;5;5;5;" >"$NP/frames"
step "$(P spotify Playing A Song)" "$(P spotify Playing A Song)"
step "$(P spotify Paused A Song)" "$(P spotify Paused A Song)"
out=$(bar)
json_lines "$out"
eq "$(last "$out")" "paused|$ICON_PAUSE  A — Song"
alive "$NP/cava.pids" && _no "cava still runs while paused" || _ok
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
eq "$(last "$out")" "playing|$ICON_CASSETTE_A  Artist — Song"
eq "$(cat "$XDG_RUNTIME_DIR/kawa-nowplaying.player")" spotify
case_ "both paused: the last one paused is shown"
setup
step "$(P spotify Paused Artist Song)" "$(P spotify Paused Artist Song)"
step "$(P mpv Paused '' film.mkv)" "$(P spotify Paused Artist Song)" "$(P mpv Paused '' film.mkv)"
eq "$(last "$(bar)")" "paused|$ICON_PAUSE  film.mkv"
case_ "the player shown quits mid-song: the other one (paused) takes its place"
setup
step "$(P mpv Playing '' film.mkv)" "$(P spotify Paused Artist Song)" "$(P mpv Playing '' film.mkv)"
step "$(P spotify Paused Artist Song)" "$(P spotify Paused Artist Song)"
out=$(bar)
eq "$(last "$out")" "paused|$ICON_PAUSE  Artist — Song"
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
eq "$(last "$out")" "paused|$ICON_PAUSE  film.mkv" "the event's own line is used"

# ── odd titles ───────────────────────────────────────────────────────────────
case_ "titles with & < > ' \" and a backslash: valid JSON, escaped markup, shown as they are"
setup
step "$(P spotify Playing "Tom & Jerry's \"Band\"" "<Live> 'Hall' \\ & more")"
out=$(bar)
json_lines "$out"; markup_ok "$out"
eq "$(last "$out")" "playing|$ICON_CASSETTE_A  Tom & Jerry's \"Band\" — <Live> 'Hall' \\ & more"
case_ "… also while paused"
setup; step "$(P spotify Paused "A&B" "<x>")"
out=$(bar); json_lines "$out"; markup_ok "$out"
eq "$(last "$out")" "paused|$ICON_PAUSE  A&B — <x>"
case_ "control characters (tab, ESC, CR) in a title: spaces, still valid JSON"
setup; step "$(P spotify Playing $'Art\tist' $'Ti\x1btle\rhere')"
out=$(bar); json_lines "$out"
eq "$(last "$out")" "playing|$ICON_CASSETTE_A  Art ist — Ti tle here"
case_ "a title with a line break: the first line shown, the rest skipped, nothing stops"
setup; printf '%s\n' "1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;1;" >"$NP/frames"
step "$(P mpv Playing '' $'Part one\nPart two')" "$(P mpv Playing '' 'Part one')"
out=$(bar); json_lines "$out"
eq "$(last "$out")" "playing|$(EQ 1 1 1 1 1 1 1 1)  $ICON_CASSETTE_A  Part one  $(EQ 1 1 1 1 1 1 1 1)"
case_ "a very long title: cut at a word's end, to 48 characters or fewer; a long artist to 20 — never an ellipsis"
setup; step "$(P spotify Playing 'Some Extremely Long Artist Name That Goes On' 'An Even Longer Title Of A Song That Never Ends At All')"
t=$(last "$(bar)"); t=${t#*  }
eq "$t" "Some Extremely Long — An Even Longer Title Of A"
((${#t} <= 48)) && _ok || _no "${#t} characters"; lacks "$t" "…"
case_ "one long word: its last letters go (never half a letter: an accent stays with its letter)"
setup; step "$(P spotify Playing '' "Abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstue"$'\u0301'"xyz")"
t=$(last "$(bar)"); t=${t#*  }
eq "$t" "Abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstu" "the e and its accent go together"
case_ "Arabic and Japanese: counted in characters (never cut mid-letter), valid JSON"
setup; step "$(P spotify Playing 'فيروز' 'نسم علينا الهوى من مفرق الوادي يا هوى دخل الهوى خدني على بلادي')"
out=$(bar); json_lines "$out"
t=$(last "$out"); t=${t#*  }
eq "$t" "فيروز — نسم علينا الهوى من مفرق الوادي يا هوى" "Arabic is written with spaces: cut at a word's end"
setup; step "$(P spotify Playing '竹内まりや' 'プラスティック・ラヴ（2021リマスター・エクステンデッド・クラブ・ミックス・バージョン）')"
out=$(bar); json_lines "$out"
t=$(last "$out"); t=${t#*  }
eq "$t" "竹内まりや — プラスティック・ラヴ（2021リマスター・エクステンデッド・クラブ・ミックス・バ" "Japanese has no spaces: cut at a character, all 48"
case_ "… also when the session's locale is C (byte counting would cut a letter in half)"
setup; step "$(P spotify Playing '竹内まりや' 'プラスティック・ラヴ（2021リマスター・エクステンデッド・クラブ・ミックス・バージョン）')"
out=$(LC_ALL=C bar); json_lines "$out"
t=$(last "$out"); t=${t#*  }
eq "$t" "竹内まりや — プラスティック・ラヴ（2021リマスター・エクステンデッド・クラブ・ミックス・バ"
setup; step "$(P spotify Playing 'คาราบาว' 'เมดอินไทยแลนด์เวอร์ชันพิเศษที่ยาวมากจนต้องตัดออกบ้าง')"
out=$(LC_ALL=C bar); json_lines "$out"
t=$(last "$out"); t=${t#*  }
eq "${#t}" 48 "Thai has no spaces either: a character's edge"; has "$t" "คาราบาว — เมดอินไทยแลนด์"

# ── the program around it ────────────────────────────────────────────────────
case_ "playerctl missing: the module hidden, and the script ends (waybar retries in 5 s)"
setup; rm "$STUBS/playerctl"
out=$(PATH=$(minipath bash cat timeout pkill pgrep) timeout 10 kawa-nowplaying 2>/dev/null); r=$?
eq "$out" '{"text":""}'; eq "$r" 0
case_ "cava missing: the cassette and the title, no meter"
setup; rm "$STUBS/cava"; printf '%s\n' "5;5;5;5;5;5;5;5;5;5;5;5;5;5;5;5;" >"$NP/frames"
step "$(P spotify Playing A Song)"
out=$(PATH=$(minipath bash cat timeout pkill pgrep cp cut grep head) bar)
eq "$(last "$out")" "playing|$ICON_CASSETTE_A  A — Song"
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
