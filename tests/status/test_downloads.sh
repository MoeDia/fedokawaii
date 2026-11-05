#!/usr/bin/env bash
# tests/status/test_downloads.sh — kawa-downloads, the downloads centre: what it finds of each
# source (Torrents' list, any job's, the browser's .crdownload files and what it says of their size,
# a download tool's file in a terminal),
# the bar's mark, the menu and what a click on it opens, the one notice of a finished
# download, and the watcher: woken by the kernel as a download starts or ends, quiet between.
. "$(dirname "$0")/lib.sh"
D=$HOME/Downloads B=$HOME/.config/net.imput.helium/Default
world() {
  sandbox
  D=$HOME/Downloads B=$HOME/.config/net.imput.helium/Default
  mkdir -p "$D" "$B"
  stub kawa-term; stub xdg-open; stub kawa-menu
}
browser_says() {   # browser_says FILE TOTAL — the browser's word, as Chromium's native messaging brings it: a length, then JSON
  local m; m=$(jq -nc --arg f "$1" --argjson t "$2" '{file: $f, total: $t}')
  python3 -I -c 'import sys; m = sys.argv[1].encode(); sys.stdout.buffer.write(len(m).to_bytes(4, "little") + m)' "$m" \
    | kawa-downloads chrome-extension://mnilamabopllcgmiodochnjmpkiohpie/ --parent-window=0 >"$TMP/host.out"
}
dl() {   # dl NAME DONE TOTAL — a browser download under way: DONE bytes of TOTAL (the mark and the menu take every source alike)
  head -c "$2" /dev/zero >"$D/$1.crdownload"
  browser_says "$D/$1" "$3"
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

case_ "the browser: a .crdownload — what has come is its size, how much will come what it said (its extension, native messaging: answered, in its framing)"
world; head -c 300 /dev/zero >"$D/film.mkv.crdownload"; head -c 50 /dev/zero >"$D/Unconfirmed 1234.crdownload"
browser_says "$D/film.mkv" 1200
eq "$(kawa-downloads list | sort)" "browser	Unconfirmed 1234	50	0	$D/Unconfirmed 1234
browser	film.mkv	300	1200	$D/film.mkv"
eq "$(od -An -c "$TMP/host.out" | tr -s ' ' | cut -c1-30)" " 002 \\0 \\0 \\0 { }" "its answer: two bytes, {}"
case_ "…its word again (the size known later): the last one holds; a total of -1 (not known): no percent"
browser_says "$D/film.mkv" 1500; eq "$(kawa-downloads list | grep film | cut -f4)" 1500
browser_says "$D/film.mkv" -1; eq "$(kawa-downloads list | grep film | cut -f4)" 0
case_ "…saved elsewhere (Save as): found by what it said, wherever the folder"
mkdir -p "$TMP/other"; head -c 70 /dev/zero >"$TMP/other/a b.iso.crdownload"; browser_says "$TMP/other/a b.iso" 700
eq "$(kawa-downloads list | grep 'a b.iso' | cut -f3,4)" $'70\t700'
case_ "…those that ended leave its record, one by one, never the one just said"
rm -f "$TMP/other/a b.iso.crdownload"; browser_says "$D/film.mkv" 1200
lacks "$(cat "$XDG_RUNTIME_DIR/kawa-downloads/browser.totals")" 'a b.iso'
case_ "…the browser's own download folder when you set one (its settings)"
mkdir -p "$TMP/elsewhere"; printf '{"download": {"default_directory": "%s"}}' "$TMP/elsewhere" >"$B/Preferences"
: >"$TMP/elsewhere/x.iso.crdownload"; has "$(kawa-downloads list | cut -f2)" "x.iso"

case_ "a download tool in a terminal: the file it writes (of yours, open for writing), past 1 MB; how much will come is its own: no total; a part's name without .part"
world
fake_tool() {   # fake_tool NAME FILE BYTES — a process of that name writing FILE
  mkdir -p "$TMP/tools"; printf '#!/bin/bash\nexec 3>"$1"; head -c "$2" /dev/zero >&3; while :; do sleep 1; done\n' >"$TMP/tools/$1"; chmod +x "$TMP/tools/$1"
  "$TMP/tools/$1" "$2" "$3" & TOOL=$!; on_exit "kill $TOOL 2>/dev/null"
  local i; for ((i = 0; i < 100; i++)); do (($(stat -c %s "$2" 2>/dev/null || echo 0) >= $3)) && break; sleep 0.1; done; sleep 0.1
}
fake_tool curl "$HOME/big.iso" 2000000
eq "$(kawa-downloads list)" $'curl\tbig.iso\t2000000\t0\t'"$HOME/big.iso"
kill "$TOOL"; wait "$TOOL" 2>/dev/null
fake_tool yt-dlp "$HOME/film.mp4.part" 1500000
eq "$(kawa-downloads list)" $'yt-dlp\tfilm.mp4\t1500000\t0\t'"$HOME/film.mp4"
kill "$TOOL"; wait "$TOOL" 2>/dev/null
case_ "…under 1 MB (a page, an API's answer), under ~/.cache, in /tmp, a program of another name: none of it counts"
fake_tool curl "$HOME/small.json" 1000; eq "$(kawa-downloads list)" ""; kill "$TOOL"; wait "$TOOL" 2>/dev/null
mkdir -p "$HOME/.cache"; fake_tool wget "$HOME/.cache/x.bin" 2000000; eq "$(kawa-downloads list)" ""; kill "$TOOL"; wait "$TOOL" 2>/dev/null
fake_tool curl "/tmp/kawa-test-$$.bin" 2000000; eq "$(kawa-downloads list)" ""; kill "$TOOL"; wait "$TOOL" 2>/dev/null; rm -f "/tmp/kawa-test-$$.bin"
fake_tool rsync "$HOME/copy.iso" 2000000; eq "$(kawa-downloads list)" ""; kill "$TOOL"; wait "$TOOL" 2>/dev/null

# ── the mark ─────────────────────────────────────────────────────────────────────────────
case_ "the mark: the percent of all, bytes over bytes (no count, no sizes); the mark alone while no total is known; a job of any name counts"
world; dl Hades 400 1600
I=$(. "$HOME/.config/fedokawaii/icons.sh"; printf %s "$ICON_BAR_DL_0")   # (at rest: the arrow's first frame)
F=$(. "$HOME/.config/fedokawaii/icons.sh"; printf %s "$ICON_DL_FILL_5")   # (25 %: five steps of the tray's fill)
T=$(sed -n 's/^C_TEAL=\([0-9a-f]*\).*/\1/p' "$HOME/.config/fedokawaii/current/colors.sh")
eq "$(mark)" '{"text": "<span color='"'#$T'"'>'"$F"'</span>'"$I"'25<span fgalpha='"'"'55%'"'"'>%</span>", "class": "downloading"}'
: >"$D/a.crdownload"
out=$(mark); has "$out" "$I""25<span"; lacks "$out" count
sleep 600 & job=$!; on_exit "kill $job 2>/dev/null"; mkdir -p "$XDG_RUNTIME_DIR/kawa-downloads"
printf 'a.zip\t1600\t1600\t/tmp/a.zip\n' >"$XDG_RUNTIME_DIR/kawa-downloads/pack.$job"
has "$(mark)" "$I""62<span"
rm -f "$XDG_RUNTIME_DIR/kawa-downloads/pack.$job"; world; : >"$D/b.crdownload"
has "$(mark)" '"bare"'
case_ "…under 10 %: an unseen digit before it, so the tile keeps its width as the percent grows"
world; dl Hades 80 1600; has "$(mark)" "$I<span fgalpha='1'>0</span>5<span"
world; dl Hades 400 1600; lacks "$(mark)" "fgalpha='1'"
case_ "…lit while its menu is open (its button's marker, its pid alive)"
sleep 600 & p=$!; on_exit "kill $p 2>/dev/null"; printf '%s kawa-downloads\n' "$p" >"$XDG_RUNTIME_DIR/kawa-drop.open"
has "$(mark)" '"active"'
printf '%s kawa-weather\n' "$p" >"$XDG_RUNTIME_DIR/kawa-drop.open"; lacks "$(mark)" '"active"' "another script's menu: not lit"
rm -f "$XDG_RUNTIME_DIR/kawa-drop.open"

case_ "the percent inside the mark: its tray filled from the left, 5 % a step (dl_fill_N, no advance, before the mark) in a meter's inks — asagi, the 17th–18th step flame, the 19th–20th the accent; none under 5 %; strong while lit"
fills() { python3 -I -c 'import json, re, sys
t = json.loads(sys.stdin.read())["text"]
print(" ".join(f"{c}:{ord(g):X}" for c, g in re.findall(r"<span color=.#([0-9a-f]+).>(.)</span>", t)) or "none")'; }
code() { (. "$HOME/.config/fedokawaii/icons.sh"; v=ICON_DL_FILL_$1; printf '%X' "'${!v}"); }
col() { sed -n "s/^$1=\([0-9a-f]*\).*/\1/p" "$HOME/.config/fedokawaii/current/colors.sh"; }
world; T=$(col C_TEAL) FL=$(col C_FLAME) A=$(col C_ACCENT) S=$(col C_STRONG)
[[ -n $FL ]] && _ok || _no "no C_FLAME in colors.sh"
world; dl Hades 40 1600; eq "$(mark | fills)" none "2 %: no fill yet"
world; dl Hades 80 1600; eq "$(mark | fills)" "$T:$(code 1)" "5 %: the first step (the first column's bottom pixel)"
world; dl Hades 1000 1600; eq "$(mark | fills)" "$T:$(code 12)" "62 %: twelve steps"
world; dl Hades 1280 1600; eq "$(mark | fills)" "$T:$(code 16)" "80 %: sixteen, all asagi"
world; dl Hades 1360 1600; eq "$(mark | fills)" "$FL:$(code 17) $T:$(code 16)" "85 %: the flame beneath, asagi over it"
world; dl Hades 1599 1600; eq "$(mark | fills)" "$A:$(code 19) $FL:$(code 18) $T:$(code 16)" "99 %: one short of full, its last column the accent's"
world; dl Hades 1600 1600; eq "$(mark | fills)" "$A:$(code 20) $FL:$(code 18) $T:$(code 16)" "100 %: all twenty"
world; dl Hades 1000 1600; sleep 600 & p=$!; on_exit "kill $p 2>/dev/null"
printf '%s kawa-downloads\n' "$p" >"$XDG_RUNTIME_DIR/kawa-drop.open"; eq "$(mark | fills)" "$S:$(code 12)" "lit (its icon teal): the fill strong"
rm -f "$XDG_RUNTIME_DIR/kawa-drop.open"
world; dl Hades 1000 1600; rm -f "$HOME/.config/fedokawaii/current/colors.sh"; eq "$(mark | fills)" none "no theme at hand: the mark alone, as before"
has "$(cat "$REPO/art/icons.txt")" "@dl-fill-20 adv=0 x=0" "drawn with no advance (art/icons.txt)"

case_ "bar --follow (what the bar runs): while anything downloads the arrow drops into its tray — six frames, 8 a second, each its own glyph; the percent beside it"
world; dl Hades 400 1600
. "$HOME/.config/fedokawaii/icons.sh"
kawa-downloads bar --follow >"$TMP/follow" & f=$!; on_exit "kill $f 2>/dev/null"
sleep 1.2
n=$(grep -c . "$TMP/follow"); ((n >= 7 && n <= 12)) && _ok || _no "$n lines in 1.2 s (8 a second: about 9)"
frames=$(python3 -I -c 'import json, re, sys
for l in open(sys.argv[1]): print(re.sub(r"^<span [^>]*>.</span>", "", json.loads(l)["text"])[0])' "$TMP/follow" | sort -u | wc -l)
eq "$frames" 6 "all six frames shown (the arrow after the tray's fill)"
has "$(head -n1 "$TMP/follow")" "$ICON_BAR_DL_0""25<span" "the first at rest, then the percent"
case_ "…the files looked at every 2 s while moving (not 8 times a second): the percent follows"
dl Hades 800 1600; sleep 2.4
has "$(tail -n1 "$TMP/follow")" '50<span' "the new percent within 2 s"
case_ "…idle: hidden, and asleep — not a line more, nothing done (a select on its fifo)"
rm -f "$D/Hades.crdownload"; sleep 2.4
eq "$(tail -n1 "$TMP/follow")" '{"text":""}' "hidden"
c1=$(grep -c . "$TMP/follow"); sleep 1.5; eq "$(grep -c . "$TMP/follow")" "$c1" "no line while idle"
eq "$(awk '{print $3}' "/proc/$f/stat")" S "asleep (S)"
case_ "…woken by kawa-dwlstatus (the watcher's poke, a menu's wake): a download that starts shows at once"
w=$(ls "$XDG_RUNTIME_DIR"/kawa-bar.wake.* 2>/dev/null); eq "$w" "$XDG_RUNTIME_DIR/kawa-bar.wake.$f" "its fifo, named by its pid"
dl Celeste 100 400; printf '\n' 1<>"$w"; sleep 0.4
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
dl Celeste 0 1200000000
stub kawa-menu 'cat >"$TMP/menu.in"; echo 1'
kawa-downloads; rows=$(cat "$TMP/menu.in")
eq "$rows" "part	@arrow-down	downloads
row	@magnet	Big Buck Bunny 2008 1080p	2.5 GB of 5.0 GB	50%
row	@globe	Celeste	0 B of 1.2 GB	0%
row	@magnet	torrents			t"
called '^kawa-menu --drop --index --select 1$'
case_ "…a click on a torrent: its folder in yazi (the file under the cursor once it is there)"
called "^kawa-term yazi $D\$"
: >"$D/Big.Buck.Bunny.2008.1080p"; reset_calls; kawa-downloads; called "^kawa-term yazi $D/Big.Buck.Bunny.2008.1080p\$"
case_ "…on a browser download: where it lands (its folder, until the file has its own name)"
reset_calls; stub kawa-menu 'cat >/dev/null; echo 2'; kawa-downloads; called "^kawa-term yazi $D\$"; not_called '^xdg-open'
case_ "…the foot's torrents: a window of its own"
stub kawa-torrents; stub kawa-menu 'cat >/dev/null; echo 3'; kawa-downloads; called '^kawa-torrents --open$'
case_ "…no torrents key while that window is open (it holds the lock on kawa-torrents.window)"
exec 8>"$XDG_RUNTIME_DIR/kawa-torrents.window"; flock -n 8
stub kawa-menu 'cat >"$TMP/menu.in"'; kawa-downloads; lacks "$(cat "$TMP/menu.in")" "torrents"; exec 8>&-
case_ "…nothing downloading: said, and nothing to put the cursor on"
world; stub kawa-menu 'cat >"$TMP/menu.in"'; kawa-downloads
eq "$(sed -n 2p "$TMP/menu.in")" "off	@arrow-down	nothing downloading"; called '^kawa-menu --drop --index$'
case_ "…dismissed: nothing opens"
not_called '^kawa-term'; not_called '^xdg-open'

# ── the notice ───────────────────────────────────────────────────────────────────────────
case_ "a name in the menu: a torrent's dots and underscores as spaces — a version's dots and a file's type kept —, any other download's name as its file has it; cut within 30 columns at a word, or at - _ . in a name without spaces (never …)"
world; . "$HOME/.config/fedokawaii/icons.sh"
sleep 600 & live=$!; on_exit "kill $live 2>/dev/null"
torrent_list "$live" $'ubuntu-24.04.1-desktop-amd64.iso\t1\t2\t'"$D" $'Album.Name.5.1.FLAC\t1\t2\t'"$D" $'The.Seven.Samurai.1954.1080p.BluRay.x264\t1\t2\t'"$D"
printf '%s\t1\t2\t%s\n' photos-2026.tar.zst "$D" a_very_long_file_name_without_any_spaces_at_all.pdf "$D" >"$XDG_RUNTIME_DIR/kawa-downloads/pack.$live"
stub kawa-menu 'cat >"$TMP/menu.in"; echo 0'
kawa-downloads; names=$(awk -F'\t' '$1 == "row" && $3 != "torrents" { print $3 }' "$TMP/menu.in" | sort)
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
kawa-downloads notice browser film.mkv 1500000000 "$D/film.mkv"
called "^notify-send -a downloads -A default=open -- $ICON_DOWNLOAD  film.mkv browser · 1.5 GB · click to open it$"
called "^kawa-term yazi $D/film.mkv\$"
case_ "…closed unclicked: nothing opens"
world; stub notify-send; kawa-downloads notice curl celeste.iso 0 "$D/celeste.iso"; not_called '^kawa-term'
called "^notify-send -a downloads -A default=open -- $ICON_DOWNLOAD  celeste.iso curl · click to open it$"

# ── the watcher ──────────────────────────────────────────────────────────────────────────
waitfor() { local i; for ((i = 0; i < 50; i++)); do eval "$1" && return 0; sleep 0.1; done; return 1; }
case_ "the watcher: the mark poked as a browser download starts, and as it ends"
world; stub notify-send
kawa-downloads watch & w=$!; on_exit "kill $w 2>/dev/null"
waitfor 'grep -q "^kawa-dwlstatus --poke 21$" "$CALLS"' && _ok || _no "not poked at its start"
: >"$CALLS"; head -c 10 /dev/zero >"$D/song.flac.crdownload"
waitfor 'grep -q "^kawa-dwlstatus --poke 21$" "$CALLS"' && _ok || _no "not poked as a download began"
case_ "…finished (renamed to its own name): its notice"
: >"$CALLS"; mv "$D/song.flac.crdownload" "$D/song.flac"
waitfor 'grep -q "^notify-send -a downloads .* song.flac browser" "$CALLS"' && _ok || _no "no notice: $(cat "$CALLS")"
called '^kawa-dwlstatus --poke 21$'
case_ "…cancelled (its file gone): no notice"
: >"$D/x.zip.crdownload"; sleep 0.8; : >"$CALLS"; rm -f "$D/x.zip.crdownload"
waitfor 'grep -q "^kawa-dwlstatus --poke 21$" "$CALLS"' && _ok || _no "not poked"; sleep 0.5; not_called '^notify-send'
case_ "…idle, it sleeps: nothing done for seconds on end"
: >"$CALLS"; sleep 2.5; eq "$(cat "$CALLS")" ""
case_ "…a download tool: its file noticed once it counts, its notice at the end"
kill "$w"; wait "$w" 2>/dev/null; world; stub notify-send; : >"$CALLS"
kawa-downloads watch & w=$!; on_exit "kill $w 2>/dev/null"; sleep 0.6
# (the fake's file is not /usr/bin/wget, whose opening wakes it: any word of the kernel's will do; tools/regress/downloads-tools.sh has the real one)
fake_tool wget "$HOME/d.iso" 2000000; t=$TOOL; : >"$CALLS"; : >"$D/a word"
waitfor 'grep -q "^kawa-dwlstatus --poke 21$" "$CALLS"' && _ok || _no "not poked: $(cat "$CALLS")"
: >"$CALLS"; kill "$t"; wait "$t" 2>/dev/null
waitfor 'grep -q "^notify-send -a downloads .* d.iso wget · 2.0 MB" "$CALLS"' || sleep 5
grep -q "^notify-send -a downloads .* d.iso wget · 2.0 MB" "$CALLS" && _ok || _no "no notice: $(cat "$CALLS")"
kill "$w"; wait "$w" 2>/dev/null

case_ "--help, and wrong use: 2"
world; kawa-downloads --help | grep -q 'kawa-downloads watch' && _ok || _no "no help"
kawa-downloads nonsense 2>/dev/null; eq "$?" 2
done_
