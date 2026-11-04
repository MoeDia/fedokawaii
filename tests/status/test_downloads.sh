#!/usr/bin/env bash
# tests/status/test_downloads.sh — kawa-downloads, the downloads centre: what it finds of each
# source (Torrents' list, Brave's .crdownload files and its History, Steam's appmanifests),
# the bar's mark, the menu and what a click on it opens, the one notice of a finished
# download, and the watcher: woken by the kernel as a download starts or ends, quiet between.
. "$(dirname "$0")/lib.sh"
D=$HOME/Downloads B=$HOME/.config/BraveSoftware/Brave-Origin/Default L=$HOME/.local/share/Steam/steamapps
world() {
  sandbox
  D=$HOME/Downloads B=$HOME/.config/BraveSoftware/Brave-Origin/Default L=$HOME/.local/share/Steam/steamapps
  mkdir -p "$D" "$B" "$L"
  stub kawa-term; stub xdg-open; stub kawa-menu
}
brave_db() {   # brave_db CURRENT TARGET TOTAL… — Brave's History: downloads under way (state 0)
  python3 -I - "$B/History" "$@" <<'EOF'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
db.execute("CREATE TABLE IF NOT EXISTS downloads (current_path TEXT, target_path TEXT, received_bytes INTEGER, total_bytes INTEGER, state INTEGER)")
a = sys.argv[2:]
for i in range(0, len(a), 3):
    db.execute("INSERT INTO downloads VALUES (?, ?, 0, ?, 0)", (a[i], a[i + 1], int(a[i + 2])))
db.commit()
EOF
}
steam_game() {   # steam_game ID NAME DONE TOTAL — a game in Steam's library, downloading
  printf '"libraryfolders"\n{\n\t"0"\n\t{\n\t\t"path"\t\t"%s"\n\t}\n}\n' "$HOME/.local/share/Steam" >"$L/libraryfolders.vdf"
  mkdir -p "$L/downloading/$1"
  printf '"AppState"\n{\n\t"appid"\t\t"%s"\n\t"name"\t\t"%s"\n\t"StateFlags"\t\t"1026"\n\t"BytesToDownload"\t\t"%s"\n\t"BytesDownloaded"\t\t"%s"\n}\n' \
    "$1" "$2" "$4" "$3" >"$L/appmanifest_$1.acf"
}
torrent_list() {   # torrent_list PID LINE… — Torrents' list, as its engine writes it
  mkdir -p "$XDG_RUNTIME_DIR/kawa-downloads"; local p=$1; shift
  printf '%s\n' "$@" >"$XDG_RUNTIME_DIR/kawa-downloads/torrent.$p"
}
mark() { kawa-downloads bar; }

# ── the sources ──────────────────────────────────────────────────────────────────────────
case_ "nothing downloading: an empty list, the mark hidden"
world; eq "$(kawa-downloads list)" ""; eq "$(mark)" '{"text":""}'

case_ "Torrents: its engine's list (its pid alive); one left by an engine gone is taken away"
world; sleep 600 & live=$!; on_exit "kill $live 2>/dev/null"
torrent_list "$live" $'Big Buck Bunny\t250\t1000\t'"$D/Big Buck Bunny"
torrent_list 999999 $'stale\t1\t2\t/x'
eq "$(kawa-downloads list)" $'torrent\tBig Buck Bunny\t250\t1000\t'"$D/Big Buck Bunny"
[[ ! -e $XDG_RUNTIME_DIR/kawa-downloads/torrent.999999 ]] && _ok || _no "a gone engine's list stayed"

case_ "Brave: a .crdownload — what has come is its size, how much will come from its History"
world; head -c 300 /dev/zero >"$D/film.mkv.crdownload"; head -c 50 /dev/zero >"$D/Unconfirmed 1234.crdownload"
brave_db "$D/film.mkv.crdownload" "$D/film.mkv" 1200 "$D/Unconfirmed 1234.crdownload" "$D/report.pdf" 0
eq "$(kawa-downloads list | sort)" "Brave	film.mkv	300	1200	$D/film.mkv
Brave	report.pdf	50	0	$D/report.pdf"
case_ "…with no History at hand: its name from the file, the total not known yet"
rm -f "$B/History"; eq "$(kawa-downloads list | sort | head -n1)" $'Brave\tUnconfirmed 1234\t50\t0\t'"$D/Unconfirmed 1234"
case_ "…Brave's own download folder when you set one (its settings)"
mkdir -p "$TMP/elsewhere"; printf '{"download": {"default_directory": "%s"}}' "$TMP/elsewhere" >"$B/Preferences"
: >"$TMP/elsewhere/x.iso.crdownload"; eq "$(kawa-downloads list | cut -f2)" "x.iso"

case_ "Steam: a game in downloading/, how far from its appmanifest; one complete is not listed"
world; steam_game 774361 Blasphemous 400 1600
eq "$(kawa-downloads list)" $'Steam\tBlasphemous\t400\t1600\t774361'
steam_game 774361 Blasphemous 1600 1600; eq "$(kawa-downloads list)" ""

# ── the mark ─────────────────────────────────────────────────────────────────────────────
case_ "the mark: the percent of all, bytes over bytes (no count, no sizes); the mark alone while no total is known; a job of any name counts"
world; steam_game 1 Hades 400 1600
I=$(. "$HOME/.config/fedokawaii/icons.sh"; printf %s "$ICON_BAR_DL_0")   # (at rest: the arrow's first frame)
F=$(. "$HOME/.config/fedokawaii/icons.sh"; printf %s "$ICON_DL_FILL_5")   # (25 %: five steps of the tray's fill)
T=$(sed -n 's/^C_TEAL=\([0-9a-f]*\).*/\1/p' "$HOME/.config/fedokawaii/current/colors.sh")
eq "$(mark)" '{"text": "<span color='"'#$T'"'>'"$F"'</span>'"$I"'25<span fgalpha='"'"'55%'"'"'>%</span>", "class": "downloading"}'
: >"$D/a.crdownload"; brave_db "$D/a.crdownload" "$D/a" 0
out=$(mark); has "$out" "$I""25<span"; lacks "$out" count
sleep 600 & job=$!; on_exit "kill $job 2>/dev/null"; mkdir -p "$XDG_RUNTIME_DIR/kawa-downloads"
printf 'a.zip\t1600\t1600\t/tmp/a.zip\n' >"$XDG_RUNTIME_DIR/kawa-downloads/pack.$job"
has "$(mark)" "$I""62<span"
rm -f "$XDG_RUNTIME_DIR/kawa-downloads/pack.$job"; world; : >"$D/b.crdownload"
has "$(mark)" '"bare"'
case_ "…lit while its menu is open (its button's marker, its pid alive)"
sleep 600 & p=$!; on_exit "kill $p 2>/dev/null"; printf '%s kawa-downloads\n' "$p" >"$XDG_RUNTIME_DIR/kawa-drop.open"
has "$(mark)" '"active"'
printf '%s kawa-weather\n' "$p" >"$XDG_RUNTIME_DIR/kawa-drop.open"; lacks "$(mark)" '"active"' "another script's menu: not lit"
rm -f "$XDG_RUNTIME_DIR/kawa-drop.open"

case_ "the percent inside the mark: its tray filled from the left, 5 % a step (dl_fill_N, no advance, before the mark) in teal; none under 5 %, all twenty at 100 %; strong while lit; no theme at hand: the mark alone"
fill() { python3 -I -c 'import json, re, sys
t = json.loads(sys.stdin.read())["text"]; m = re.match(r"<span color=.#([0-9a-f]+).>(.)</span>", t)
print(f"{m.group(1)} {ord(m.group(2)):X}" if m else "none")'; }
code() { (. "$HOME/.config/fedokawaii/icons.sh"; v=ICON_DL_FILL_$1; printf '%X' "'${!v}"); }
S=$(sed -n 's/^C_STRONG=\([0-9a-f]*\).*/\1/p' "$HOME/.config/fedokawaii/current/colors.sh")
world; steam_game 1 Hades 40 1600; eq "$(mark | fill)" none "2 %: no fill yet"
world; steam_game 1 Hades 80 1600; eq "$(mark | fill)" "$T $(code 1)" "5 %: the first step (the first column's bottom pixel)"
world; steam_game 1 Hades 1000 1600; eq "$(mark | fill)" "$T $(code 12)" "62 %: twelve steps"
world; steam_game 1 Hades 1599 1600; eq "$(mark | fill)" "$T $(code 19)" "99 %: one short of full"
world; steam_game 1 Hades 1600 1600
sleep 600 & job2=$!; on_exit "kill $job2 2>/dev/null"; mkdir -p "$XDG_RUNTIME_DIR/kawa-downloads"
printf 'a.zip\t1600\t1600\t/tmp/a.zip\n' >"$XDG_RUNTIME_DIR/kawa-downloads/pack.$job2"; eq "$(mark | fill)" "$T $(code 20)" "100 %: all twenty"
rm -f "$XDG_RUNTIME_DIR/kawa-downloads/pack.$job2"
world; steam_game 1 Hades 1000 1600; sleep 600 & p=$!; on_exit "kill $p 2>/dev/null"
printf '%s kawa-downloads\n' "$p" >"$XDG_RUNTIME_DIR/kawa-drop.open"; eq "$(mark | fill)" "$S $(code 12)" "lit (its icon teal): the fill strong"
rm -f "$XDG_RUNTIME_DIR/kawa-drop.open"
world; steam_game 1 Hades 1000 1600; rm -f "$HOME/.config/fedokawaii/current/colors.sh"; eq "$(mark | fill)" none "no theme at hand: the mark alone, as before"
has "$(cat "$REPO/art/icons.txt")" "@dl-fill-20 adv=0 x=0" "drawn with no advance (art/icons.txt)"

case_ "bar --follow (what the bar runs): while anything downloads the arrow drops into its tray — six frames, 8 a second, each its own glyph; the percent beside it"
world; steam_game 1 Hades 400 1600
. "$HOME/.config/fedokawaii/icons.sh"
kawa-downloads bar --follow >"$TMP/follow" & f=$!; on_exit "kill $f 2>/dev/null"
sleep 1.2
n=$(grep -c . "$TMP/follow"); ((n >= 7 && n <= 12)) && _ok || _no "$n lines in 1.2 s (8 a second: about 9)"
frames=$(python3 -I -c 'import json, re, sys
for l in open(sys.argv[1]): print(re.sub(r"^<span [^>]*>.</span>", "", json.loads(l)["text"])[0])' "$TMP/follow" | sort -u | wc -l)
eq "$frames" 6 "all six frames shown (the arrow after the tray's fill)"
has "$(head -n1 "$TMP/follow")" "$ICON_BAR_DL_0""25<span" "the first at rest, then the percent"
case_ "…the files looked at every 2 s while moving (not 8 times a second): the percent follows"
steam_game 1 Hades 800 1600; sleep 2.4
has "$(tail -n1 "$TMP/follow")" '50<span' "the new percent within 2 s"
case_ "…idle: hidden, and asleep — not a line more, nothing done (a select on its fifo)"
rm -rf "$L/downloading/1" "$L/appmanifest_1.acf"; sleep 2.4
eq "$(tail -n1 "$TMP/follow")" '{"text":""}' "hidden"
c1=$(grep -c . "$TMP/follow"); sleep 1.5; eq "$(grep -c . "$TMP/follow")" "$c1" "no line while idle"
eq "$(awk '{print $3}' "/proc/$f/stat")" S "asleep (S)"
case_ "…woken by kawa-dwlstatus (the watcher's poke, a menu's wake): a download that starts shows at once"
w=$(ls "$XDG_RUNTIME_DIR"/kawa-bar.wake.* 2>/dev/null); eq "$w" "$XDG_RUNTIME_DIR/kawa-bar.wake.$f" "its fifo, named by its pid"
steam_game 2 Celeste 100 400; printf '\n' 1<>"$w"; sleep 0.4
has "$(tail -n1 "$TMP/follow")" '25<span' "shown within 0.4 s of the word"
case_ "…lit as its menu opens (woken: kawa-panel wakes the bar's long-running modules)"
sleep 600 & m=$!; on_exit "kill $m 2>/dev/null"; printf '%s kawa-downloads\n' "$m" >"$XDG_RUNTIME_DIR/kawa-drop.open"; printf '\n' 1<>"$w"; sleep 0.4
has "$(tail -n1 "$TMP/follow")" '"active"'
case_ "…ended (waybar stops it): its fifo taken away with it"
kill "$f"; wait "$f" 2>/dev/null; [[ ! -e $w ]] && _ok || _no "the fifo left behind"
rm -f "$XDG_RUNTIME_DIR/kawa-drop.open"

# ── the menu ─────────────────────────────────────────────────────────────────────────────
case_ "the menu: downloads under its arrow, a row each — its glyph, its name (a torrent's dots as spaces), how much of how much, the percent"
world; . "$HOME/.config/fedokawaii/icons.sh"
sleep 600 & live=$!; on_exit "kill $live 2>/dev/null"
torrent_list "$live" $'Big.Buck.Bunny.2008.1080p\t2500000000\t5000000000\t'"$D/Big.Buck.Bunny.2008.1080p"
steam_game 2 Celeste 0 1200000000
stub kawa-menu 'cat >"$TMP/menu.in"; echo 1'
kawa-downloads; rows=$(cat "$TMP/menu.in")
eq "$rows" "part	$ICON_DOWNLOAD	downloads
row	$ICON_DOWNLOAD	Big Buck Bunny 2008 1080p	2.5 GB of 5.0 GB	50%
row	$ICON_GAMEPAD	Celeste	0 B of 1.2 GB	0%
key	$ICON_DOWNLOAD	torrents"
called '^kawa-menu --drop --index --select 1$'
case_ "…a click on a torrent: its folder in yazi (the file under the cursor once it is there)"
called "^kawa-term yazi $D\$"
: >"$D/Big.Buck.Bunny.2008.1080p"; reset_calls; kawa-downloads; called "^kawa-term yazi $D/Big.Buck.Bunny.2008.1080p\$"
case_ "…on a Steam game: Steam's downloads page"
stub kawa-menu 'cat >/dev/null; echo 2'; kawa-downloads; called '^xdg-open steam://open/downloads$'
case_ "…the foot's torrents: a window of its own"
stub kawa-torrents; stub kawa-menu 'cat >/dev/null; echo 3'; kawa-downloads; called '^kawa-torrents --open$'
case_ "…no torrents key while that window is open (it holds the lock on kawa-torrents.window)"
exec 8>"$XDG_RUNTIME_DIR/kawa-torrents.window"; flock -n 8
stub kawa-menu 'cat >"$TMP/menu.in"'; kawa-downloads; lacks "$(cat "$TMP/menu.in")" "torrents"; exec 8>&-
case_ "…nothing downloading: said, and nothing to put the cursor on"
world; stub kawa-menu 'cat >"$TMP/menu.in"'; kawa-downloads
eq "$(sed -n 2p "$TMP/menu.in")" "off	$ICON_DOWNLOAD	nothing downloading"; called '^kawa-menu --drop --index$'
case_ "…dismissed: nothing opens"
not_called '^kawa-term'; not_called '^xdg-open'

# ── the notice ───────────────────────────────────────────────────────────────────────────
case_ "a name in the menu: a torrent's dots and underscores as spaces — a version's dots and a file's type kept —, any other download's name as its file has it; cut within 30 columns at a word, or at - _ . in a name without spaces (never …)"
world; . "$HOME/.config/fedokawaii/icons.sh"
sleep 600 & live=$!; on_exit "kill $live 2>/dev/null"
torrent_list "$live" $'ubuntu-24.04.1-desktop-amd64.iso\t1\t2\t'"$D" $'Album.Name.5.1.FLAC\t1\t2\t'"$D" $'The.Seven.Samurai.1954.1080p.BluRay.x264\t1\t2\t'"$D"
printf '%s\t1\t2\t%s\n' photos-2026.tar.zst "$D" a_very_long_file_name_without_any_spaces_at_all.pdf "$D" >"$XDG_RUNTIME_DIR/kawa-downloads/pack.$live"
stub kawa-menu 'cat >"$TMP/menu.in"; echo 0'
kawa-downloads; names=$(awk -F'\t' '$1 == "row" { print $3 }' "$TMP/menu.in" | sort)
eq "$names" "$(printf '%s\n' "Album Name 5.1.FLAC" "The Seven Samurai 1954 1080p" a_very_long_file_name_without photos-2026.tar.zst ubuntu-24.04.1-desktop-amd64 | sort)"
case_ "what Torrents' engine left for the desktop: each said, each taken away, nothing else in that folder touched"
world; sleep 600 & live=$!; on_exit "kill $live 2>/dev/null"
mkdir -p "$XDG_RUNTIME_DIR/kawa-downloads"; R=$XDG_RUNTIME_DIR/kawa-downloads
printf 'finished\tA Film\t1500000000\t%s\n' "$D/A Film" >"$R/said.$live.1"; printf 'failed\tAnother\tno space left on device\n' >"$R/said.$live.2"
printf 'finished\thalf' >"$R/said.$live.3.new"; printf 'x\t1\t2\t%s\n' "$D" >"$R/pack.$live"
stub kawa-dwlstatus
. "$HOME/.config/fedokawaii/icons.sh"; ( timeout 3 kawa-downloads watch ) >/dev/null 2>&1
/bin/sleep 0.3
[[ ! -e $R/said.$live.1 && ! -e $R/said.$live.2 ]] && _ok || _no "left there"
[[ -e $R/said.$live.3.new && -e $R/pack.$live ]] && _ok || _no "something else taken"
called "notify-send -a downloads -A default=open -- $ICON_DOWNLOAD  A Film torrent · 1.5 GB · click to open it"
called "notify-send -a downloads -u critical -- $ICON_DOWNLOAD  Another no space left on device"
case_ "a download that cannot go on: a critical notice, its name and what went wrong"
world; . "$HOME/.config/fedokawaii/icons.sh"; kawa-downloads failed "A Film" "no space left on device"
called "^notify-send -a downloads -u critical -- $ICON_DOWNLOAD  A Film no space left on device$"
case_ "a finished download's notice: its name, then SOURCE · SIZE · click to open it; a click opens it"
world; : >"$D/film.mkv"; stub notify-send 'echo default'
kawa-downloads notice Brave film.mkv 1500000000 "$D/film.mkv"
called "^notify-send -a downloads -A default=open -- $ICON_DOWNLOAD  film.mkv Brave · 1.5 GB · click to open it$"
called "^kawa-term yazi $D/film.mkv\$"
case_ "…closed unclicked: nothing opens"
world; stub notify-send; kawa-downloads notice Steam Celeste 0 2; not_called '^xdg-open'
called "^notify-send -a downloads -A default=open -- $ICON_DOWNLOAD  Celeste Steam · click to open it$"

# ── the watcher ──────────────────────────────────────────────────────────────────────────
waitfor() { local i; for ((i = 0; i < 50; i++)); do eval "$1" && return 0; sleep 0.1; done; return 1; }
case_ "the watcher: the mark poked as a Brave download starts, and as it ends"
world; stub notify-send
kawa-downloads watch & w=$!; on_exit "kill $w 2>/dev/null"
waitfor 'grep -q "^kawa-dwlstatus --poke 21$" "$CALLS"' && _ok || _no "not poked at its start"
: >"$CALLS"; head -c 10 /dev/zero >"$D/song.flac.crdownload"
waitfor 'grep -q "^kawa-dwlstatus --poke 21$" "$CALLS"' && _ok || _no "not poked as a download began"
case_ "…finished (renamed to its own name): its notice"
: >"$CALLS"; mv "$D/song.flac.crdownload" "$D/song.flac"
waitfor 'grep -q "^notify-send -a downloads .* song.flac Brave" "$CALLS"' && _ok || _no "no notice: $(cat "$CALLS")"
called '^kawa-dwlstatus --poke 21$'
case_ "…cancelled (its file gone): no notice"
: >"$D/x.zip.crdownload"; sleep 0.8; : >"$CALLS"; rm -f "$D/x.zip.crdownload"
waitfor 'grep -q "^kawa-dwlstatus --poke 21$" "$CALLS"' && _ok || _no "not poked"; sleep 0.5; not_called '^notify-send'
case_ "…idle, it sleeps: nothing done for seconds on end"
: >"$CALLS"; sleep 2.5; eq "$(cat "$CALLS")" ""
case_ "…a Steam game whose download finishes: its notice"
kill "$w"; wait "$w" 2>/dev/null; world; stub notify-send; steam_game 9 Hades 10 100
kawa-downloads watch & w=$!; on_exit "kill $w 2>/dev/null"; sleep 0.8
steam_game 9 Hades 100 100; rm -rf "$L/downloading/9"
waitfor 'grep -q "^notify-send -a downloads .* Hades Steam · 100 B" "$CALLS"' && _ok || _no "no notice: $(cat "$CALLS")"
kill "$w"; wait "$w" 2>/dev/null

case_ "--help, and wrong use: 2"
world; kawa-downloads --help | grep -q 'kawa-downloads watch' && _ok || _no "no help"
kawa-downloads nonsense 2>/dev/null; eq "$?" 2
done_
