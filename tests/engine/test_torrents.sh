#!/usr/bin/env bash
# tests/engine/test_torrents.sh — kawa-torrents: its engine on a real libtorrent swarm over the loopback, its window on a
# pseudo-terminal read back cell by cell, Prowlarr's side against a stand-in. Each scenario (torrents_checks.py) runs in
# a process and a throw-away home of its own, so that nothing of one leans on another. Needs rb_libtorrent-python3 (the manifest's).
. "$(dirname "$0")/lib.sh"
D=$(cd "$(dirname "$0")" && pwd)
export REPO

scenario() {   # scenario NAME "what it shows"
  sandbox
  stub kawa-downloads
  stub kawa-prowlarr
  stub kawa-play
  stub kawa-term
  stub wl-copy
  stub systemctl
  stub notify-send
  stub wl-paste '[ -e "$TMP/clip" ] && cat "$TMP/clip"'
  case_ "$2"
  local out
  # (a group of its own: an engine or a window left by a failure ends with it)
  if out=$(timeout -k 2 200 python3 "$D/torrents_checks.py" "$1" 2>&1 </dev/null); then _ok
  else _no "$(tail -n 14 <<<"$out")"; fi
}

case_ "libtorrent is there to test against (rb_libtorrent-python3)"
if python3 -c 'import libtorrent' 2>/dev/null; then _ok; else _no "not installed: fedokawaii repair puts it back"; done_; exit 1; fi

# the engine, on a real swarm
scenario magnet_to_done   "a magnet to its files: one notice; five reopens with the seeder gone: nothing fetched or hashed, no notice"
scenario file_and_links   "a .torrent, a duplicate, what is no torrent, nonsense on the socket: answered in words, the engine going on"
scenario files_gone       "a finished torrent's files moved away: never fetched anew unasked; asked, they come, with a notice"
scenario keep_and_remove  "a pause across a restart; a removal leaves the files and no file of ours; delete takes them; no .parts file left"
scenario choose_files     "only what is kept comes; choosing more makes it a download again, and tells of it again"
scenario stream           "a file over HTTP while it comes: ranges, its tail first, every byte right; a wrong token; the rush undone after"
scenario real_player      "mpv itself plays a film not yet here, and jumps past what has come"
scenario stream_from_search "a magnet pasted from a page's source, v at once: played the moment its files are known"
scenario url_links        "a link of Prowlarr's: a row at once, the torrent after; a site's trouble asked again, said in words; no key on disk"
scenario idle_and_marks   "ends by itself, saved, when nothing is wanted; never while downloading; the bar's list and the login's mark"
scenario crash_midway     "killed halfway: the next start goes on, the file right, one notice"
scenario many             "two hundred torrents: quick to add, quick to come back"
scenario socket_started   "as systemd starts it: on the first connection, by its socket; it ends by itself, saved"
scenario disk_full        "a really full disk: the row says so, one critical notice, p goes on once there is room"
scenario inherit          "torrra's list taken over: chosen files, pauses, those it had told of stay told"

# words and numbers
scenario words            "what is a link, in any text; names from strangers; the columns of a kanji; never an ellipsis"

# the window, on the mock engine
scenario layout           "to the column: tabs, headings, rows, values ending together, the cursor's fill, a kanji's two cells, the meter"
scenario every_size       "from 2 x 2 to 70 x 400, both tabs: no crash, nothing past the edge, no ellipsis"
scenario keys_            "every key on the list, the filter, the add line, a paste, the mouse"
scenario play_key         "v: with its files not asked for yet, it goes on by itself; many videos: the files' page"
scenario details          "the details beside the list, their own page when narrow; files kept and skipped; a video played"
scenario find             "sites one by one, a slow one holding up nothing; sorted; copied; added from the hash, no site, no key"
scenario no_key_no_prowlarr "what stops a search is said where its results would be"
scenario prowlarr_down    "Prowlarr that will not start: said at once"
scenario first_view       "nothing downloaded yet: it opens on the search"
scenario offers           "the clipboard's magnet and a fresh .torrent offered; Enter adds, x leaves it, none offered twice"
scenario hand_over        "a link opened: a window for it, or added to the one open with a notice: never two windows"
scenario engine_lost      "the engine gone: said, its place kept, back the moment the engine is"
scenario hostile_names    "a name's escapes and overrides never reach the terminal"
scenario single_window    "the window's lock: held while open, gone with it however it ends"
scenario terminal_restored "q, Ctrl+Q, TERM, a hang-up: the terminal put back each time"

# Prowlarr's side
scenario prowlarr_tend    "what fails is rested and tried again; yours stays yours; a whole network down rests nothing"
scenario prowlarr_add     "the usual sites once each; Tokyo Toshokan out; one out of reach saved rested"
scenario prowlarr_search  "the key only from a private file, only a real one"

# the desktop's own: the container that keeps its page free of warnings
sandbox
case_ "Prowlarr's container: its warning's causes dealt with, for good (no warning on its page: its health list empty, 4 Nov)"
c=$(cat "$REPO/system/prowlarr.container")
has "$c" 'PROWLARR__SERVER__ALLOWEDHOSTS=localhost,127.0.0.1' "Allowed Hosts set"
has "$c" 'DNS=1.1.1.1' "public resolvers for its sites"
has "$c" 'PublishPort=127.0.0.1:9696:9696' "on this computer only"

case_ "the engine's unit: socket-started, walled in, your keys out of its sight"
u=$(cat "$REPO/configs/home/.config/systemd/user/kawa-torrents.service")
has "$u" 'ProtectSystem=strict' "read-only but what it needs"
has "$u" 'ProtectHome=tmpfs' "of your home, only what it names"
lacks "$u" '.config' "your settings and keys out of its sight"
[[ -x $REPO/bin/kawa-torrents ]] && _ok || _no "the program is not executable: its unit could not start it"
has "$(cat "$REPO/configs/home/.config/systemd/user/kawa-torrents.socket")" 'ListenStream=%t/kawa-torrents.sock' "the socket the window asks at"
has "$(cat "$REPO/configs/home/.config/dwl/autostart.sh")" 'systemctl --user start kawa-torrents.socket' "with the session"

done_
