#!/usr/bin/env bash
# tests/engine/test_torrra.sh — kawa-torrra (torrra with the Prowlarr key from secrets.sh,
# in memory only), its /etc/profile.d hook, and how it starts Prowlarr on demand. torrra runs
# for real through kawa-torrra's own boot code, in a venv of the real python3 whose torrra,
# httpx and libtorrent are stand-ins (fixtures/torrra): they say what torrra would have seen.
. "$(dirname "$0")/lib.sh"
D=$(cd "$(dirname "$0")" && pwd)
KEY=a1b2c3d4e5f60718293a4b5c6d7e8f90

fresh() {
  sandbox
  V=$HOME/.local/share/pipx/venvs/torrra
  local pyv; pyv=$(python3 -c 'import sys; print(f"python{sys.version_info[0]}.{sys.version_info[1]}")')
  mkdir -p "$V/bin" "$V/lib/$pyv/site-packages"
  ln -s "$(command -v python3)" "$V/bin/python"
  printf 'home = %s\ninclude-system-site-packages = false\n' "$(dirname "$(command -v python3)")" >"$V/pyvenv.cfg"
  cp -r "$D/fixtures/torrra/." "$V/lib/$pyv/site-packages/"
  mkdir -p "$HOME/.config/fedokawaii"
  printf 'PROWLARR_API_KEY=%s\n' "$KEY" >"$HOME/.config/fedokawaii/secrets.sh"; chmod 600 "$HOME/.config/fedokawaii/secrets.sh"
  export FAKE_LOG=$TMP/prowlarr.log FAKE_PROWLARR=ok
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

# ── a search: the key from secrets.sh, in memory only ────────────────────────
fresh
case_ "a search: Prowlarr started for it, asked with the key, torrra given the key — never on disk"
out=$(kawa-torrra 2>&1); r=$?
eq "$r" 0
has "$out" "starting Prowlarr"
called '^systemctl --user start prowlarr.service'
has "$(cat "$FAKE_LOG")" "httpx.get http://127.0.0.1:9696/api/v1/indexer key=$KEY timeout=5"
eq "$(seen "$out" key)" "$KEY" "torrra asked for the key and got it"
lacks "$(cat "$CFG")" "$KEY" "config.toml never holds the key"
lacks "$(cat "$CFG")" "api_key"
eq "$(seen "$out" env_key)" "None" "the key is not left in torrra's environment"
case_ "…its settings put right for this desktop: Prowlarr's address, the default, the colours"
eq "$(seen "$out" url)" "http://127.0.0.1:9696"; eq "$(seen "$out" default)" prowlarr; eq "$(seen "$out" theme)" ansi-dark
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
case_ "a search while its sleep is planned: the sleep called off, then planned anew when the window closes"
fresh; : >"$TMP/active"; kawa-torrra >/dev/null 2>&1
eq "$(grep -n 'stop prowlarr-idle.timer\|systemd-run' "$CALLS" | cut -d: -f2- | cut -c1-40 | tr '\n' '|')" "systemctl --user stop prowlarr-idle.time|systemctl --user stop prowlarr-idle.time|systemd-run --user --quiet --unit=prowla|"
case_ "the key from the environment wins; secrets.sh then not even read"
fresh; chmod 644 "$HOME/.config/fedokawaii/secrets.sh"
out=$(PROWLARR_API_KEY=ffffffffffffffffffffffffffffffff kawa-torrra 2>&1); eq "$?" 0
eq "$(seen "$out" key)" ffffffffffffffffffffffffffffffff
case_ "a key an older setup left in config.toml: taken out, never put back; your other settings kept"
fresh; mkdir -p "${CFG%/*}"
printf '[general]\ntheme = "textual-dark"\ndownload_path = "/home/me/Downloads/films"\n\n[indexers.prowlarr]\napi_key = "%s"\nurl = "http://127.0.0.1:9696"\n' "$KEY" >"$CFG"
kawa-torrra >/dev/null 2>&1
lacks "$(cat "$CFG")" "$KEY"; has "$(cat "$CFG")" 'download_path = "/home/me/Downloads/films"'; has "$(cat "$CFG")" 'theme = "ansi-dark"'
case_ "a theme you chose (Ctrl+T) is kept"
sed -i 's/theme = "ansi-dark"/theme = "nord"/' "$CFG"; kawa-torrra >/dev/null 2>&1; has "$(cat "$CFG")" 'theme = "nord"'
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

# ── Prowlarr ─────────────────────────────────────────────────────────────────
case_ "Prowlarr not answering: said, with where to look"
fresh; export FAKE_PROWLARR=down
out=$(kawa-torrra 2>&1); eq "$?" 1; has "$out" "Prowlarr is not answering on 127.0.0.1:9696"
called 'systemd-run .*--on-active=30min' "left to sleep 30 minutes later"
case_ "Prowlarr too slow to answer (the 5 s timeout): said the same way"
FAKE_PROWLARR=slow; out=$(kawa-torrra 2>&1); eq "$?" 1; has "$out" "not answering"
case_ "Prowlarr refusing the key (401): which command hands it the key again"
FAKE_PROWLARR=401; out=$(kawa-torrra 2>&1); eq "$?" 1; has "$out" "refused the key"; has "$out" "fedokawaii update"
case_ "Prowlarr failing (HTTP 500): its log named"
FAKE_PROWLARR=500; out=$(kawa-torrra 2>&1); eq "$?" 1; has "$out" "Prowlarr answered HTTP 500"
case_ "Prowlarr with no indexers switched on: repair adds the usual ones, or its page"
FAKE_PROWLARR=noindexers; out=$(kawa-torrra 2>&1); eq "$?" 1; has "$out" "no indexers switched on"; has "$out" "fedokawaii repair"
case_ "Prowlarr's container failing to start: said, and nothing left starting"
fresh; : >"$TMP/start-fails"
out=$(kawa-torrra 2>&1); eq "$?" 1; has "$out" "Prowlarr did not start"; has "$out" "journalctl --user -u prowlarr"
called ' stop --no-block'
case_ "no Prowlarr unit at all (podman missing, the container file gone): said, repair named"
fresh; : >"$TMP/no-unit"
out=$(kawa-torrra 2>&1); eq "$?" 1; has "$out" "Prowlarr is not set up here"; has "$out" "fedokawaii repair"; not_called ' start '
case_ "port 9696 taken by another program: said, before anything is started"
fresh; stub ss 'echo "LISTEN 0 4096 127.0.0.1:9696 0.0.0.0:*"'
out=$(kawa-torrra 2>&1); eq "$?" 1; has "$out" "port 9696"; has "$out" "another program"; not_called ' start '
case_ "the window closed (HUP) or Ctrl+C while Prowlarr starts: its sleep is planned all the same"
for sig in HUP INT; do
  fresh; stub systemctl 'case "$*" in *is-active*) echo activating; exit 3 ;; *LoadState*) echo loaded ;; *" start "*) kill -'"$sig"' $(ps -o ppid= -p $PPID); sleep 0.3 ;; esac'   # (kawa-torrra: kawa-prowlarr starts it
  kawa-torrra >/dev/null 2>&1; r=$?
  [[ $r == 129 || $r == 130 ]] && _ok || _no "$sig: exit $r"
  called 'systemd-run .*--on-active=30min'
done
case_ "Prowlarr's start is said in the window before it is waited for"
fresh; has "$(kawa-torrra 2>&1)" "starting Prowlarr… (a few seconds)"

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
out=$(HOME="$TMP/my home" KAWA_TORRRA_VENV="$TMP/my home/.local/share/pipx/venvs/torrra" kawa-torrra 2>&1); eq "$?" 0
eq "$(seen "$out" key)" "$KEY"

# ── the profile hook: `torrra` in a shell is kawa-torrra ─────────────────────
case_ "in bash, torrra runs kawa-torrra with its words; in sh, nothing is defined"
fresh; stub kawa-torrra
bash -c '. "$1"; torrra search "a b"' _ "$REPO/system/kawa-torrra.profile.sh"; called '^kawa-torrra search a b$'
out=$(sh -c '. "$1"; command -v torrra || echo none' _ "$REPO/system/kawa-torrra.profile.sh"); eq "$out" none
sh -n "$REPO/system/kawa-torrra.profile.sh" && _ok || _no "not valid sh"

done_
