#!/usr/bin/env bash
# tests/engine/test_torrra.sh — kawa-torrra (torrra with the Prowlarr key from secrets.sh,
# in memory only), its /etc/profile.d hook, and how it starts Prowlarr on demand: woken as the
# window opens, waited for and asked at the first search. torrra runs for real through
# kawa-torrra's own boot code, in a venv of the real python3 whose torrra, Textual, httpx and
# libtorrent are stand-ins (fixtures/torrra): they say what torrra would have seen — its first
# screen, its theme, each search typed (FAKE_QUERY) and what came of it.
. "$(dirname "$0")/lib.sh"
D=$(cd "$(dirname "$0")" && pwd)
KEY=a1b2c3d4e5f60718293a4b5c6d7e8f90

fresh() {
  sandbox
  V=$HOME/.local/share/uv/tools/torrra
  local pyv; pyv=$(python3 -c 'import sys; print(f"python{sys.version_info[0]}.{sys.version_info[1]}")')
  mkdir -p "$V/bin" "$V/lib/$pyv/site-packages"
  ln -s "$(command -v python3)" "$V/bin/python"
  printf 'home = %s\ninclude-system-site-packages = false\n' "$(dirname "$(command -v python3)")" >"$V/pyvenv.cfg"
  cp -r "$D/fixtures/torrra/." "$V/lib/$pyv/site-packages/"
  mkdir -p "$HOME/.config/fedokawaii"
  printf 'PROWLARR_API_KEY=%s\n' "$KEY" >"$HOME/.config/fedokawaii/secrets.sh"; chmod 600 "$HOME/.config/fedokawaii/secrets.sh"
  export FAKE_LOG=$TMP/prowlarr.log FAKE_PROWLARR=ok FAKE_QUERY="big buck bunny"   # (a search typed in the window)
  unset PROWLARR_API_KEY FAKE_LT FAKE_TORRRA FAKE_RC
  # systemd --user: Prowlarr off until started; $TMP/active when it runs
  stub systemctl 'case "$*" in
  *is-active*) [ -e "'"$TMP"'/active" ]; exit $? ;;
  *"show -p LoadState"*) [ -e "'"$TMP"'/no-unit" ] && echo not-found || echo loaded ;;
  *" start "*) [ -e "'"$TMP"'/start-fails" ] && { echo "Job for prowlarr.service failed." >&2; exit 1; }; : >"'"$TMP"'/active" ;;
  *" stop "*prowlarr.service*) rm -f "'"$TMP"'/active" ;;
esac'
  stub ss                                     # (port 9696 free)
  stub wl-copy; stub setsid; stub systemd-run; stub xdg-open
  cp "$REPO/system/kawa-torrra" "$STUBS/kawa-torrra"      # (a copy, as setup installs it: never a link into the repository)
  CFG=$HOME/.config/torrra/config.toml
}
seen() { tail -n1 <<<"$1" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d[sys.argv[1]])' "$2" 2>/dev/null; }
seenj() { tail -n1 <<<"$1" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps(d[sys.argv[1]], ensure_ascii=False))' "$2" 2>/dev/null; }

# ── a search: the key from secrets.sh, in memory only ────────────────────────
fresh
case_ "a search: Prowlarr started for it, asked with the key at the first search, torrra given the key — never on disk"
out=$(kawa-torrra 2>&1); r=$?
eq "$r" 0
called '^systemctl --user start prowlarr.service'
eq "$(cat "$FAKE_LOG")" "httpx.get http://127.0.0.1:9696/api/v1/indexer key=$KEY timeout=5
torrra's search: big buck bunny" "Prowlarr asked once, then torrra's own search"
eq "$(seenj "$out" searches)" '[["a result for big buck bunny"]]'
eq "$(seen "$out" healthy)" True "torrra's own check before its window skipped (Prowlarr still starting then): healthy"
lacks "$(cat "$FAKE_LOG")" "torrra's own health check"
lacks "$out" "starting Prowlarr" "Prowlarr's start not said in the window: it starts behind it, the search's spinner turning meanwhile"
eq "$(seen "$out" key)" "$KEY" "torrra asked for the key and got it"
lacks "$(cat "$CFG")" "$KEY" "config.toml never holds the key"
lacks "$(cat "$CFG")" "api_key"
eq "$(seen "$out" env_key)" "None" "the key is not left in torrra's environment"
case_ "…its settings put right for this desktop: Prowlarr's address, the default, the colours"
eq "$(seen "$out" url)" "http://127.0.0.1:9696"; eq "$(seen "$out" default)" prowlarr; eq "$(seen "$out" theme)" fedokawaii
case_ "…the desktop's theme, fedokawaii: built on Textual's ansi-dark (foot's 16 colours), vermilion where torrra puts its primary and secondary, the cursor's row filled in it"
eq "$(seenj "$out" drawn_with)" '{"name": "fedokawaii", "ansi": true, "dark": true, "primary": "ansi_red", "secondary": "ansi_red", "accent": "ansi_bright_cyan", "warning": "ansi_yellow", "error": "ansi_bright_red", "success": "ansi_green", "foreground": "ansi_default", "background": "ansi_default", "surface": "ansi_default", "panel": "ansi_default", "boost": "ansi_default"}'
v=$(seenj "$out" drawn_vars)
has "$v" '"from-ansi-dark": "kept"' "ansi-dark's own variables kept under ours"
has "$v" '"block-cursor-background": "ansi_red", "block-cursor-foreground": "ansi_black"'
has "$v" '"block-cursor-blurred-background": "transparent", "block-cursor-blurred-foreground": "ansi_red"'
has "$v" '"secondary-muted": "ansi_bright_black", "text-secondary": "ansi_white"'
case_ "…its first screen a text screen of ours: the download icon, torrents over the rule, what it is, the search line, the version and the indexer, the keys as rows — no banner, no emoji"
. "$REPO/configs/home/.config/fedokawaii/icons.sh"
eq "$(seenj "$out" welcome)" '["banner: [ansi_red]'"$ICON_DOWNLOAD"'[/]  torrents [ansi_bright_black]────────────────────────────────────────────────────[/]", "subtitle: search the usual sites through Prowlarr —\ndownloads go on while this window is open", "input: what to find", "version: torrra 2.5.1 · prowlarr", ": quit", "key: ctrl+q", ": colours", "key: ctrl+t", ": downloads", "key: ctrl+d", ": every key", "key: ?"]'
lacks "$(seen "$out" welcome)" "🏴"
c=$(seen "$out" css)
has "$c" "#welcome_container { max-width: 64 !important; }"; has "$c" "grid-columns: 14 1fr !important;"
eq "$(grep -c '#welcome_container' <<<"$c")" "$(grep -c '!important' <<<"$c")" "every rule of it !important (torrra's app.tcss, read after, would win every tie)"
case_ "…and a search waits a minute, once, for Prowlarr's answer (its eight sites at once): torrra's 10 s, three times over, gave up first"
eq "$(seen "$out" timeout)" 60; eq "$(seen "$out" max_retries)" 1
case_ "…a wait and tries of your own kept"
fresh; mkdir -p "${CFG%/*}"; printf '[general]\ntimeout = 25\nmax_retries = 2\n' >"$CFG"
out=$(kawa-torrra 2>&1); eq "$(seen "$out" timeout)" 25; eq "$(seen "$out" max_retries)" 2
case_ "…torrra's own defaults written in the file (an older torrra wrote them): ours instead"
fresh; mkdir -p "${CFG%/*}"; printf '[general]\ntimeout = 10\nmax_retries = 3\n' >"$CFG"
out=$(kawa-torrra 2>&1); eq "$(seen "$out" timeout)" 60; has "$(cat "$CFG")" "timeout = 60"
case_ "…and Prowlarr left to sleep 30 minutes after the window closes (a second search soon after finds it awake)"
called '^systemd-run --user --quiet --unit=prowlarr-idle --on-active=30min --timer-property=AccuracySec=30s systemctl --user stop prowlarr.service$'
not_called 'stop --no-block prowlarr.service'
case_ "Prowlarr already running (the web page open): used, left running"
fresh; : >"$TMP/active"
kawa-torrra >/dev/null 2>&1; not_called ' start prowlarr'; not_called '^systemctl --user stop prowlarr.service'; called 'systemd-run .*--on-active=30min'
case_ "a search while its sleep is planned: the sleep called off (as the window opens, and at the search), then planned anew when the window closes — last"
fresh; : >"$TMP/active"; kawa-torrra >/dev/null 2>&1
eq "$(grep 'stop prowlarr-idle.timer\|systemd-run' "$CALLS" | cut -c1-40 | uniq | tr '\n' '|')" "systemctl --user stop prowlarr-idle.time|systemd-run --user --quiet --unit=prowla|"
eq "$(grep -c 'stop prowlarr-idle.timer' "$CALLS")" 3
case_ "the key from the environment wins; secrets.sh then not even read"
fresh; chmod 644 "$HOME/.config/fedokawaii/secrets.sh"
out=$(PROWLARR_API_KEY=ffffffffffffffffffffffffffffffff kawa-torrra 2>&1); eq "$?" 0
eq "$(seen "$out" key)" ffffffffffffffffffffffffffffffff
case_ "a key an older setup left in config.toml: taken out, never put back; your other settings kept"
fresh; mkdir -p "${CFG%/*}"
printf '[general]\ntheme = "textual-dark"\ndownload_path = "/home/me/Downloads/films"\n\n[indexers.prowlarr]\napi_key = "%s"\nurl = "http://127.0.0.1:9696"\n' "$KEY" >"$CFG"
kawa-torrra >/dev/null 2>&1
lacks "$(cat "$CFG")" "$KEY"; has "$(cat "$CFG")" 'download_path = "/home/me/Downloads/films"'; has "$(cat "$CFG")" 'theme = "fedokawaii"' "textual-dark, torrra's default: ours now"
case_ "the themes earlier setups chose (ansi-dark, ansi-light) become ours; one you chose (Ctrl+T) is kept"
for t in ansi-dark ansi-light; do
  sed -i "s/theme = \".*\"/theme = \"$t\"/" "$CFG"; kawa-torrra >/dev/null 2>&1; has "$(cat "$CFG")" 'theme = "fedokawaii"' "$t"
done
sed -i 's/theme = "fedokawaii"/theme = "nord"/' "$CFG"; kawa-torrra >/dev/null 2>&1; has "$(cat "$CFG")" 'theme = "nord"'
case_ "config.toml with a slip in it: torrra on defaults, the file left exactly as it was"
fresh; mkdir -p "${CFG%/*}"; printf '[general\ntheme = \n' >"$CFG"; before=$(cat "$CFG")
out=$(kawa-torrra 2>&1); eq "$?" 0; has "$out" "config.toml does not read"; eq "$(cat "$CFG")" "$before"

# ── secrets.sh ───────────────────────────────────────────────────────────────
case_ "secrets.sh readable by others: refused, how to fix it said"
fresh; chmod 644 "$HOME/.config/fedokawaii/secrets.sh"
out=$(kawa-torrra 2>&1); eq "$?" 1; has "$out" "must be yours and private — chmod 600 it"; not_called ' start '
case_ "secrets.sh not yours: refused"
if ((EUID == 0)); then
  fresh; chown 12345 "$HOME/.config/fedokawaii/secrets.sh"
  out=$(kawa-torrra 2>&1); eq "$?" 1; has "$out" "must be yours and private"
else _ok; fi
case_ "secrets.sh missing: said as missing, and which command makes it"
fresh; rm "$HOME/.config/fedokawaii/secrets.sh"
out=$(kawa-torrra 2>&1); eq "$?" 1; has "$out" "secrets.sh is missing"; has "$out" "fedokawaii update"; not_called ' start '
case_ "a key that is not one (wrong length, not hex, empty): refused before Prowlarr starts"
for k in abc "${KEY}0" "${KEY^^}" ""; do
  fresh; printf 'PROWLARR_API_KEY="%s"\n' "$k" >"$HOME/.config/fedokawaii/secrets.sh"
  out=$(kawa-torrra 2>&1); eq "$?" 1 "[$k]"; has "$out" "no PROWLARR_API_KEY (32 hex characters)"; not_called ' start '
done
case_ "the key written as the shell would: export, quotes, a comment"
fresh; printf '# torrra\nexport PROWLARR_API_KEY='"'"'%s'"'"'   # Prowlarr\n' "$KEY" >"$HOME/.config/fedokawaii/secrets.sh"
out=$(kawa-torrra 2>&1); eq "$?" 0; eq "$(seen "$out" key)" "$KEY"
case_ "secrets.sh with your other keys (exported) beside it: only Prowlarr's is taken — the rest stay out of torrra"
fresh; printf 'export KAWA_TEST_OTHER_KEY=sk-other-123\nPROWLARR_API_KEY=%s\n' "$KEY" >"$HOME/.config/fedokawaii/secrets.sh"
out=$(env -u KAWA_TEST_OTHER_KEY kawa-torrra 2>&1); eq "$?" 0; eq "$(seen "$out" key)" "$KEY"
eq "$(seen "$out" env_other)" "None" "another key of secrets.sh reached torrra's environment"
case_ "a line in secrets.sh naming a variable that is not set: the search still runs (no 'unbound variable')"
fresh; printf 'export GH_TOKEN="$NOT_SET_ANYWHERE"\nPROWLARR_API_KEY=%s\n' "$KEY" >"$HOME/.config/fedokawaii/secrets.sh"
out=$(kawa-torrra 2>&1); eq "$?" 0; lacks "$out" "unbound variable"; eq "$(seen "$out" key)" "$KEY"

# ── Prowlarr: asked at the first search; its trouble said there (the search fails as torrra's
# own failure would: an IndexerError the window shows), the window left open ─────────────
case_ "Prowlarr not answering: said, with where to look; the search an IndexerError, the window open"
fresh; export FAKE_PROWLARR=down
out=$(kawa-torrra 2>&1); eq "$?" 0; has "$out" "torrra: Prowlarr is not answering on 127.0.0.1:9696 — systemctl --user status prowlarr"
eq "$(seenj "$out" searches)" '["IndexerError: Prowlarr is not answering on 127.0.0.1:9696 — systemctl --user status prowlarr"]'
lacks "$(cat "$FAKE_LOG")" "torrra's search" "torrra's own search not run"
called 'systemd-run .*--on-active=30min' "left to sleep 30 minutes later"
case_ "…asked again at the next search (it may answer by then); once it has, not again"
FAKE_QUERY='a|b' out=$(kawa-torrra 2>&1); eq "$(grep -c '^torrra: Prowlarr is not answering' <<<"$out")" 2
fresh; FAKE_QUERY='a|b|c' out=$(kawa-torrra 2>&1); eq "$(grep -c 'httpx.get' "$FAKE_LOG")" 1 "one answer is enough"
eq "$(seenj "$out" searches)" '[["a result for a"], ["a result for b"], ["a result for c"]]'
case_ "no search typed: Prowlarr not asked at all (only woken)"
fresh; FAKE_QUERY='' out=$(kawa-torrra 2>&1); eq "$?" 0; [[ ! -s $FAKE_LOG ]] && _ok || _no "asked: $(cat "$FAKE_LOG")"
called '^systemctl --user start prowlarr.service'
case_ "Prowlarr too slow to answer (the 5 s timeout): said the same way"
fresh; FAKE_PROWLARR=slow; out=$(kawa-torrra 2>&1); eq "$?" 0; has "$out" "not answering"; has "$(seen "$out" searches)" "IndexerError"
case_ "Prowlarr refusing the key (401): which command hands it the key again"
FAKE_PROWLARR=401; out=$(kawa-torrra 2>&1); has "$out" "refused the key in secrets.sh — run: fedokawaii update"; has "$(seen "$out" searches)" "IndexerError"
case_ "Prowlarr failing (HTTP 500): its log named"
FAKE_PROWLARR=500; out=$(kawa-torrra 2>&1); has "$out" "Prowlarr answered HTTP 500 — journalctl --user -u prowlarr -e"
case_ "Prowlarr with no indexers switched on: repair adds the usual ones, or its page"
FAKE_PROWLARR=noindexers; out=$(kawa-torrra 2>&1); has "$out" "no indexers switched on"; has "$out" "fedokawaii repair"
case_ "Prowlarr's container failing to start: said at the search, and nothing left starting"
fresh; : >"$TMP/start-fails"
out=$(kawa-torrra 2>&1); eq "$?" 0; has "$out" "torrra: Prowlarr did not start — journalctl --user -u prowlarr -e"
has "$(seen "$out" searches)" "IndexerError: Prowlarr did not start"; lacks "$(cat "$FAKE_LOG")" "httpx.get" "not asked: it is not there"
called ' stop --no-block'
case_ "no Prowlarr unit at all (podman missing, the container file gone): said, repair named"
fresh; : >"$TMP/no-unit"
out=$(kawa-torrra 2>&1); eq "$?" 1; has "$out" "Prowlarr is not set up here"; has "$out" "fedokawaii repair"; not_called ' start '
case_ "port 9696 taken by another program: said, before anything is started"
fresh; stub ss 'echo "LISTEN 0 4096 127.0.0.1:9696 0.0.0.0:*"'
out=$(kawa-torrra 2>&1); eq "$?" 1; has "$out" "port 9696"; has "$out" "another program"; not_called ' start '
case_ "the window closed (HUP) or Ctrl+C while Prowlarr starts: its sleep is planned all the same"
# (as a terminal does it: the signal to the window's whole process group — torrra, kawa-torrra,
# the start behind them — at the moment Prowlarr's start is asked; kawa-torrra in a group of its
# own, so nothing outside it is ever signalled)
for sig in HUP INT; do
  fresh; stub systemctl 'case "$*" in *is-active*) echo activating; exit 3 ;; *LoadState*) echo loaded ;; *" start "*) kill -'"$sig"' -- "-$(cat "'"$TMP"'/kt.pid")"; sleep 0.3 ;; esac'
  FAKE_HOLD=1 "$SETSID" -w bash -c 'echo "$$" >"$1"; exec kawa-torrra' _ "$TMP/kt.pid" >/dev/null 2>&1; r=$?
  [[ $r == 129 || $r == 130 ]] && _ok || _no "$sig: exit $r"
  called 'systemd-run .*--on-active=30min'
done
case_ "the window does not wait for Prowlarr: it opens while Prowlarr starts (kawa-prowlarr --busy behind it)"
fresh; stub systemctl 'case "$*" in *is-active*) exit 3 ;; *LoadState*) echo loaded ;; *" start "*) sleep 2; : >"'"$TMP"'/active" ;; esac'
t0=$EPOCHREALTIME; out=$(FAKE_QUERY='' kawa-torrra 2>&1); t=$(( (${EPOCHREALTIME/./} - ${t0/./}) / 1000 ))
eq "$(seen "$out" healthy)" True; ((t < 1500)) && _ok || _no "the window waited $t ms"
has "$(cat "$REPO/system/kawa-torrra")" 'kawa-prowlarr --busy >/dev/null 2>&1 8>&- &' "(its lock not held by the start)"
sleep 2.2

# ── what needs no key, and no lock ───────────────────────────────────────────
case_ "--version, --help, config: no key, no Prowlarr, no lock (verify runs --version)"
fresh; rm "$HOME/.config/fedokawaii/secrets.sh"
for a in --version --help -h config; do
  out=$(kawa-torrra "$a" 2>&1); eq "$?" 0 "$a"; has "$(seen "$out" argv)" "$a"
done
not_called systemctl; [[ ! -e $XDG_RUNTIME_DIR/kawa-torrra.lock ]] && _ok || _no "a lock was taken"
case_ "torrra's own exit status comes back"
fresh; FAKE_RC=3 kawa-torrra >/dev/null 2>&1; eq "$?" 3

# ── links and files (the launcher, magnet links, .torrent files) ─────────────
case_ "--open a magnet link: downloaded — no key needed, no Prowlarr"
fresh; rm "$HOME/.config/fedokawaii/secrets.sh"
out=$(kawa-torrra --open 'magnet:?xt=urn:btih:abc&dn=a b' 2>&1); eq "$?" 0
eq "$(seen "$out" argv)" "['torrra', 'download', 'magnet:?xt=urn:btih:abc&dn=a b']"; not_called systemctl
case_ "--open a magnet link with quotes, \$( ), backticks and ; in its name: handed on word for word, nothing run"
m='magnet:?xt=urn:btih:abc&dn=it'"'"'s "a" $(touch '"$TMP"'/ran) `touch '"$TMP"'/ran`; é'
out=$(kawa-torrra --open "$m" 2>&1); eq "$?" 0
eq "$(tail -n1 <<<"$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["argv"][2])')" "$m"
[[ ! -e $TMP/ran ]] && _ok || _no "a part of the link was run"
case_ "--open a URL of a .torrent"
out=$(kawa-torrra --open 'https://example.org/x.torrent' 2>&1); eq "$?" 0; has "$(seen "$out" argv)" "https://example.org/x.torrent"
case_ "--open a file:// link: spaces and accents decoded, file://localhost too"
mkdir -p "$HOME/Downloads/ma été"; : >"$HOME/Downloads/ma été/a film.torrent"
for u in "file://$HOME/Downloads/ma%20%C3%A9t%C3%A9/a%20film.torrent" "file://localhost$HOME/Downloads/ma%20%C3%A9t%C3%A9/a%20film.torrent"; do
  out=$(kawa-torrra --open "$u" 2>&1); eq "$?" 0 "$u"; has "$(seen "$out" argv)" "$HOME/Downloads/ma été/a film.torrent"
done
case_ "--open a plain path with a backslash and a percent in its name"
: >"$HOME/Downloads/100% a\\b.torrent"
out=$(kawa-torrra --open "file://$HOME/Downloads/100%25%20a%5Cb.torrent" 2>&1); eq "$?" 0; has "$(seen "$out" argv)" '100% a\\b.torrent'
case_ "--open what is not there, or not a torrent: said as a notice too (the window closes)"
out=$(kawa-torrra --open "$HOME/Downloads/gone.torrent" 2>&1); eq "$?" 1; has "$out" "no such file"
called '^notify-send -a torrra -u critical -- .*  torrra no such file'
: >"$HOME/Downloads/notes.txt"
out=$(kawa-torrra --open "$HOME/Downloads/notes.txt" 2>&1); eq "$?" 1; has "$out" "not a magnet link or a .torrent file"
case_ "--open with nothing: the search (the launcher entry)"
fresh; out=$(kawa-torrra --open 2>&1); eq "$?" 0; called ' start prowlarr'
case_ "trouble from the launcher shows as a notice; in a shell it does not"
fresh; chmod 644 "$HOME/.config/fedokawaii/secrets.sh"; reset_calls
kawa-torrra --open >/dev/null 2>&1; called '^notify-send -a torrra -u critical -- .*  torrra .*chmod 600'
reset_calls; kawa-torrra >/dev/null 2>&1; not_called notify-send
case_ "Prowlarr's trouble from the launcher: a notice as well"
fresh; export FAKE_PROWLARR=noindexers; kawa-torrra --open >/dev/null 2>&1; called '^notify-send -a torrra -u critical -- .*  torrra Prowlarr has no indexers switched on'

# ── one torrra at a time ─────────────────────────────────────────────────────
hold() { ( exec 8>"$XDG_RUNTIME_DIR/kawa-torrra.lock"; flock 8; exec sleep 30 ) >/dev/null 2>&1 & holder=$!
         for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$XDG_RUNTIME_DIR/kawa-torrra.lock" true || break; sleep 0.1; done; }
case_ "a second torrra while one is open: said, nothing started"
fresh; hold
out=$(kawa-torrra 2>&1); eq "$?" 1; has "$out" "torrra is already open in another window"; not_called ' start '
case_ "a magnet link while torrra is open: on the clipboard, and said so"
out=$(kawa-torrra --open 'magnet:?xt=urn:btih:abc' 2>&1); eq "$?" 1
called '^setsid -f wl-copy -- magnet:\?xt=urn:btih:abc'; has "$out" "it is on your clipboard"
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
case_ "the lock let go (the other window closed or crashed): runs"
rc 0 kawa-torrra
case_ "no runtime folder (not in a session: su, a cron job): said plainly"
fresh; out=$(XDG_RUNTIME_DIR='' kawa-torrra 2>&1); eq "$?" 1; has "$out" "inside your session"; lacks "$out" "line "
out=$(env -u XDG_RUNTIME_DIR kawa-torrra 2>&1); eq "$?" 1; has "$out" "inside your session"

# ── torrra itself broken ─────────────────────────────────────────────────────
case_ "torrra not installed: which command installs it"
fresh; rm -rf "$V"; out=$(kawa-torrra 2>&1); eq "$?" 1; has "$out" "not installed"; has "$out" "fedokawaii update"
case_ "libtorrent that no longer loads (a newer Python): said before anything downloads"
fresh; out=$(FAKE_LT=broken kawa-torrra --version 2>&1); eq "$?" 1; has "$out" "cannot start (libtorrent.so: undefined symbol"
case_ "a torrra that changed how it saves settings: stops rather than write the key to disk"
fresh; out=$(FAKE_TORRRA=nosave kawa-torrra 2>&1); eq "$?" 1; has "$out" "torrra changed how it saves settings"
[[ ! -e $CFG ]] || lacks "$(cat "$CFG")" "$KEY"
case_ "a home with a space in it"
fresh; mkdir -p "$TMP/my home"; cp -a "$HOME/." "$TMP/my home/"
out=$(HOME="$TMP/my home" KAWA_TORRRA_VENV="$TMP/my home/.local/share/uv/tools/torrra" kawa-torrra 2>&1); eq "$?" 0
eq "$(seen "$out" key)" "$KEY"

# ── what stopped the launcher entry: torrra quitting before its window drew ──────────────
case_ "a Textual without ansi-dark (8.0.1, the one the old pins installed): said as a notice, not a window that flashes"
fresh; out=$(FAKE_TEXTUAL=8.0.1 kawa-torrra --open 2>&1); eq "$?" 1
has "$out" "this Textual has no ansi-dark theme"
called '^notify-send -a torrra -u critical -- .*  torrra cannot start .this Textual has no ansi-dark theme to build on. — run: fedokawaii update$'
case_ "anything torrra says on stderr and exits 0 on (a theme it turns away…): the notice, status 1"
fresh; out=$(FAKE_SAY=$'\e[31minvalid theme \'nord2\' configured.\navailable themes: nord\e[0m' kawa-torrra --open 2>&1); eq "$?" 1
called "^notify-send -a torrra -u critical -- .*  torrra invalid theme 'nord2' configured. available themes: nord$"
eq "$(grep -c 'invalid theme' <<<"$out")" 1 "said once on the terminal"
case_ "…in a shell: status 1, its own words, no notice"
fresh; out=$(FAKE_SAY="Search failed" kawa-torrra 2>&1); eq "$?" 1; has "$out" "Search failed"; not_called notify-send
case_ "…and nothing said: status 0 (a window you closed)"
fresh; kawa-torrra --open >/dev/null 2>&1; eq "$?" 0; not_called notify-send

# ── the downloads centre: what its window downloads, and a notice as each finishes ─────────
case_ "every 2 s, what downloads (not a paused one) in kawa-downloads/torrra.PID; a finished one: its notice, once"
fresh; stub kawa-downloads
cat >"$TMP/dl.json" <<EOF
[[{"name": "Big Buck Bunny", "save_path": "$HOME/Downloads", "done": 10, "total": 100},
  {"name": "paused one", "save_path": "$HOME/Downloads", "done": 1, "total": 9, "paused": true}],
 [{"name": "Big Buck Bunny", "save_path": "$HOME/Downloads", "done": 100, "total": 100, "finished": true}],
 [{"name": "Big Buck Bunny", "save_path": "$HOME/Downloads", "done": 100, "total": 100, "finished": true}]]
EOF
FAKE_DL=$TMP/dl.json kawa-torrra --open >/dev/null 2>&1; eq "$?" 0
eq "$(cat "$TMP/dl.json.seen.0")" "== torrra
Big Buck Bunny	10	100	$HOME/Downloads/Big Buck Bunny" "the first moment: the one downloading"
eq "$(cat "$TMP/dl.json.seen.1")" "" "finished: listed no more"
eq "$(grep -c '^kawa-downloads notice' "$CALLS")" 1 "one notice"
called "^kawa-downloads notice torrent Big Buck Bunny 100 $HOME/Downloads/Big Buck Bunny$"
case_ "…its list gone with the window"
[[ -z $(ls -A "$XDG_RUNTIME_DIR/kawa-downloads" 2>/dev/null) ]] && _ok || _no "left: $(ls "$XDG_RUNTIME_DIR/kawa-downloads")"

# ── the profile hook: `torrra` in a shell is kawa-torrra ─────────────────────
case_ "in bash, torrra runs kawa-torrra with its words; in a shell that is not bash, nothing is defined"
fresh; stub kawa-torrra
bash -c '. "$1"; torrra search "a b"' _ "$REPO/system/kawa-torrra.profile.sh"; called '^kawa-torrra search a b$'
# (Fedora's sh is bash itself, BASH_VERSION and all: a shell without it is one that is not bash)
out=$(sh -c 'unset BASH_VERSION; . "$1"; command -v torrra || echo none' _ "$REPO/system/kawa-torrra.profile.sh"); eq "$out" none
sh -n "$REPO/system/kawa-torrra.profile.sh" && _ok || _no "not valid sh"

done_
