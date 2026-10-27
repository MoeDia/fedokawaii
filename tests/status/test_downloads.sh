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
torrra_list() {   # torrra_list PID LINE… — Torrents' list, as kawa-torrra writes it
  mkdir -p "$XDG_RUNTIME_DIR/kawa-downloads"; local p=$1; shift
  printf '%s\n' "$@" >"$XDG_RUNTIME_DIR/kawa-downloads/torrra.$p"
}
mark() { kawa-downloads bar; }

# ── the sources ──────────────────────────────────────────────────────────────────────────
case_ "nothing downloading: an empty list, the mark hidden"
world; eq "$(kawa-downloads list)" ""; eq "$(mark)" '{"text":""}'

case_ "Torrents: its window's list (its pid alive); one left by a window gone is taken away"
world; sleep 600 & live=$!; on_exit "kill $live 2>/dev/null"
torrra_list "$live" $'Big Buck Bunny\t250\t1000\t'"$D/Big Buck Bunny"
torrra_list 999999 $'stale\t1\t2\t/x'
eq "$(kawa-downloads list)" $'torrent\tBig Buck Bunny\t250\t1000\t'"$D/Big Buck Bunny"
[[ ! -e $XDG_RUNTIME_DIR/kawa-downloads/torrra.999999 ]] && _ok || _no "a gone window's list stayed"

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
I=$(. "$HOME/.config/fedokawaii/icons.sh"; printf %s "$ICON_BAR_DOWNLOAD")
eq "$(mark)" '{"text": "'"$I"'25<span fgalpha='"'"'55%'"'"'>%</span>", "class": "downloading"}'
: >"$D/a.crdownload"; brave_db "$D/a.crdownload" "$D/a" 0
out=$(mark); has "$out" "\"$I""25<span"; lacks "$out" count
sleep 600 & job=$!; on_exit "kill $job 2>/dev/null"; mkdir -p "$XDG_RUNTIME_DIR/kawa-downloads"
printf 'a.zip\t1600\t1600\t/tmp/a.zip\n' >"$XDG_RUNTIME_DIR/kawa-downloads/pack.$job"
has "$(mark)" "\"$I""62<span"
rm -f "$XDG_RUNTIME_DIR/kawa-downloads/pack.$job"; world; : >"$D/b.crdownload"
has "$(mark)" '"bare"'
case_ "…through kawa-bar: lit while its menu is open (its button's marker)"
sleep 600 & p=$!; on_exit "kill $p 2>/dev/null"; printf '%s kawa-downloads\n' "$p" >"$XDG_RUNTIME_DIR/kawa-drop.open"
has "$(kawa-bar downloads -- kawa-downloads bar)" '"active"'

# ── the menu ─────────────────────────────────────────────────────────────────────────────
case_ "the menu: downloads under its arrow, a row each — its glyph, its name (a torrent's dots as spaces), how much of how much, the percent"
world; . "$HOME/.config/fedokawaii/icons.sh"
sleep 600 & live=$!; on_exit "kill $live 2>/dev/null"
torrra_list "$live" $'Big.Buck.Bunny.2008.1080p\t2500000000\t5000000000\t'"$D/Big.Buck.Bunny.2008.1080p"
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
case_ "…the foot's torrents: the search, in a window of its own"
stub kawa-menu 'cat >/dev/null; echo 3'; kawa-downloads; called '^kawa-term kawa-torrra --open$'
case_ "…no torrents key while that window is open (it holds kawa-torrra's lock)"
exec 8>"$XDG_RUNTIME_DIR/kawa-torrra.lock"; flock -n 8
stub kawa-menu 'cat >"$TMP/menu.in"'; kawa-downloads; lacks "$(cat "$TMP/menu.in")" "torrents"; exec 8>&-
case_ "…nothing downloading: said, and nothing to put the cursor on"
world; stub kawa-menu 'cat >"$TMP/menu.in"'; kawa-downloads
eq "$(sed -n 2p "$TMP/menu.in")" "off	$ICON_DOWNLOAD	nothing downloading"; called '^kawa-menu --drop --index$'
case_ "…dismissed: nothing opens"
not_called '^kawa-term'; not_called '^xdg-open'

# ── the notice ───────────────────────────────────────────────────────────────────────────
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
