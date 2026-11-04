#!/usr/bin/env bash
# tests/content/test_browser.sh — kawa-browser, the launcher in ~/.local/bin that Super+B, links
# and a shell all go through: Helium started with the PulseAudio loopback for screen sharing (its
# switch on from the first) and its password store pinned to the basic one, a feature list of your
# own joined to it, every other argument passed on as it is; Widevine's hint; Helium missing. Helium
# is a stand-in at the package's one launcher, under a made-up root (the launcher is run as a copy
# looking there).
. "$(dirname "$0")/lib.sh"

setup() {   # setup — a sandbox, nothing installed yet under $R
  sandbox
  R=$TMP/root; mkdir -p "$R/usr/bin"
  sed -e "2,\$ s#/usr/bin/#$R/usr/bin/#g; s#/usr/local/lib/#$R/usr/local/lib/#g" "$REPO/bin/kawa-browser" >"$TMP/kawa-browser"   # (not the #! line)
  chmod +x "$TMP/kawa-browser"
  export ARGS=$TMP/args
}
install_at() {   # install_at PATH [STATUS] — a stand-in Helium: its name, then each argument on a line
  mkdir -p "${1%/*}"
  printf '#!/bin/sh\nprintf "%%s\\n" "$0" "$@" >"$ARGS"\nexit %s\n' "${2:-0}" >"$1"; chmod +x "$1"
}
got() { cat "$ARGS" 2>/dev/null; }
B() { "$TMP/kawa-browser" "$@"; }
FEAT=--enable-features=PulseaudioLoopbackForScreenShare,AcceleratedVideoEncoder,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL PS=--password-store=basic
OFF=--disable-features=WebRtcAllowInputVolumeAdjustment
SYS=--system-audio-capture-default_checked
CACHE=--disk-cache-size=1073741824

case_ "the copy looks only under the made-up root"
setup
eq "$(grep -c "$R" "$TMP/kawa-browser")" "$(tail -n +2 "$REPO/bin/kawa-browser" | grep -cE '/usr/bin/|/usr/local/lib/')"

case_ "not installed: says so and how to get it, status 127, nothing started"
setup
out=$(B https://example.com 2>&1); r=$?
eq "$r" 127; has "$out" "Helium is not installed (sudo dnf install helium-bin)"
eq "$(got)" ""

case_ "installed: started with the screen-share sound feature and the basic password store, the link after them"
setup; install_at "$R/usr/bin/helium"
rc 0 B https://example.com
eq "$(got)" "$R/usr/bin/helium
$FEAT
$OFF
$PS
$SYS
$CACHE
https://example.com"
case_ "no arguments (Super+B): just the feature and the store"
B; eq "$(got)" "$R/usr/bin/helium
$FEAT
$OFF
$PS
$SYS
$CACHE"
case_ "a password store of your own comes after the pinned one (Chromium keeps a switch's last value)"
B --password-store=gnome-libsecret; eq "$(got | tail -n +4)" "$PS
$SYS
$CACHE
--password-store=gnome-libsecret"

case_ "only its one launcher: a helium under another name is not it"
setup; install_at "$R/usr/bin/helium-browser"; rc 127 B; eq "$(got)" ""

case_ "your own feature list is joined to it, once, whatever its place"
setup; install_at "$R/usr/bin/helium"
B --incognito --enable-features=VaapiVideoDecoder,Other https://a.example
eq "$(got | tail -n +2)" "$FEAT,VaapiVideoDecoder,Other
$OFF
$PS
$SYS
$CACHE
--incognito
https://a.example"
B --enable-features=A --enable-features=B
eq "$(got | tail -n +2)" "$FEAT,A,B
$OFF
$PS
$SYS
$CACHE" "two lists: both joined, one switch"
eq "$(got | grep -c -- --enable-features)" 1

case_ "a call never moves the microphone's level (Chromium's input volume adjustment off); your own --disable-features joined to it"
setup; install_at "$R/usr/bin/helium"
B --disable-features=A,B https://a.example
eq "$(got | tail -n +2)" "$FEAT
$OFF,A,B
$PS
$SYS
$CACHE
https://a.example"
eq "$(got | grep -c -- --disable-features)" 1

case_ "everything else reaches Helium exactly as given (order, spaces, quotes, \$(…), unicode, a leading dash)"
setup; install_at "$R/usr/bin/helium"
B --new-window "https://example.com/a b?q=\"x\"&y='z'" '$(touch nope)' '`id`' 'مرحبا 日本' -- --enable-features=X
eq "$(got | tail -n +2)" "$FEAT
$OFF
$PS
$SYS
$CACHE
--new-window
https://example.com/a b?q=\"x\"&y='z'
\$(touch nope)
\`id\`
مرحبا 日本
--
--enable-features=X" "(after --, Chromium takes nothing as a switch: not joined either)"
B ''; eq "$(got | wc -l)" 7 "an empty argument kept"
[[ ! -e nope && ! -e $TMP/nope ]] && _ok || _no "an argument ran"
case_ "--help and --version are Helium's (not the launcher's)"
B --help; eq "$(got | tail -n +7)" "--help"
B --version; eq "$(got | tail -n +7)" "--version"

case_ "Helium's own exit status comes back"
setup; install_at "$R/usr/bin/helium" 3
rc 3 B

case_ "a home with a space and an accent (links open from there)"
setup; install_at "$R/usr/bin/helium"
odd_home; cp "$TMP/kawa-browser" "$HOME/.local/bin/kawa-browser"
"$HOME/.local/bin/kawa-browser" "file://$HOME/page.html"
eq "$(got | tail -n1)" "file://$HOME/page.html"

case_ "Widevine: the toolkit's module named in the hint file before the start, with the browser closed; no module, no hint"
setup; install_at "$R/usr/bin/helium"
C=${XDG_CONFIG_HOME:-$HOME/.config}/net.imput.helium H=$C/WidevineCdm/latest-component-updated-widevine-cdm
rm -rf "$C"; B; [[ -e $H ]] && _no "a hint with no module" || _ok
mkdir -p "$R/usr/local/lib/fedokawaii-widevine"; echo '{"version":"1"}' >"$R/usr/local/lib/fedokawaii-widevine/manifest.json"
B; eq "$(cat "$H")" "{\"Path\":\"$R/usr/local/lib/fedokawaii-widevine\"}" "a first start: the hint made"
case_ "…a hint already there is left be (Helium's own updater may name a newer one)"
printf '{"Path":"/somewhere/newer"}' >"$H"; B; eq "$(cat "$H")" '{"Path":"/somewhere/newer"}'
case_ "…open with this profile (Chromium's SingletonLock, a link to HOST-PID, its process alive): nothing written; a stale mark (a crash): written"
rm -f "$H"; sleep 30 & live=$!; ln -sfn "fedokawaii-$live" "$C/SingletonLock"; B
[[ -e $H ]] && _no "written while open" || _ok
kill "$live"; wait "$live" 2>/dev/null; B; [[ -s $H ]] && _ok || _no "the mark's process gone: no hint"
rm -f "$C/SingletonLock"
case_ "--is-open: the one check Theme and kawa-tidy ask — 0 open (the lock's process alive), 1 not (no lock, or a stale one); the browser never started"
sleep 30 & live=$!; ln -sfn "fedokawaii-$live" "$C/SingletonLock"; rm -f "$ARGS"
B --is-open; eq "$?" 0 "open"
kill "$live"; wait "$live" 2>/dev/null
B --is-open; eq "$?" 1 "a stale lock: not open"
rm -f "$C/SingletonLock"; B --is-open; eq "$?" 1 "no lock: not open"
[[ -e $ARGS ]] && _no "the browser started by a question" || _ok

case_ "--warm: no window, kept by a pipe only it holds (its fds 3 and 4), no port; with one up already nothing"
setup; install_at "$R/usr/bin/helium"; C=${XDG_CONFIG_HOME:-$HOME/.config}/net.imput.helium; rm -rf "$C"
cat >"$R/usr/bin/helium" <<'STAND'
#!/bin/bash
printf "%s\n" "$0" "$@" >"$ARGS"; [[ -e /proc/$$/fd/3 && -e /proc/$$/fd/4 ]] && readlink /proc/$$/fd/3 /proc/$$/fd/4 >"$ARGS.fds"
exit 0
STAND
chmod +x "$R/usr/bin/helium"
B --warm; has "$(got)" --remote-debugging-pipe; has "$(got)" --no-startup-window; has "$(got)" "$CACHE"
has "$(cat "$ARGS.fds")" "kawa-browser.pipe."; has "$(cat "$ARGS.fds")" "(deleted)" "a fifo no name reaches"; has "$(cat "$ARGS.fds")" /dev/null; lacks "$(got)" remote-debugging-port
ls "$XDG_RUNTIME_DIR"/kawa-browser.pipe.* >/dev/null 2>&1 && _no "its fifo left behind" || _ok
mkdir -p "$C"; sleep 30 & live=$!; ln -sfn "fedokawaii-$live" "$C/SingletonLock"; rm -f "$ARGS"
B --warm; eq "$?" 0 "up already"; [[ -e $ARGS ]] && _no "a second one started" || _ok
kill "$live"; wait "$live" 2>/dev/null; rm -f "$C/SingletonLock"
case_ "a press with the browser warm: a word on its socket, the window at once, no second program; a link, the web apps' --app the same, as they were given"
listener() {   # a stand-in for the running browser: each word into $TMP/word, answered ACK
  python3 -I -c 'import socket, sys
s = socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(5); print("up", flush=True)
while True:
    c, _ = s.accept(); b = b""
    while True:
        d = c.recv(65536)
        if not d: break
        b += d
    open(sys.argv[2], "wb").write(b); c.sendall(b"ACK"); c.close()' "$C/SingletonSocket" "$TMP/word" >"$TMP/l.up" &
  LP=$!; for _ in {1..100}; do [[ -S $C/SingletonSocket ]] && break; sleep 0.05; done
}
setup; install_at "$R/usr/bin/helium"; C=${XDG_CONFIG_HOME:-$HOME/.config}/net.imput.helium; mkdir -p "$C"; rm -f "$C/SingletonSocket"; listener; ln -sfn "fedokawaii-$LP" "$C/SingletonLock"; rm -f "$ARGS"
cd "$TMP" || exit 1
B; eq "$(tr '\0' '|' <"$TMP/word")" "START|$TMP|$R/usr/bin/helium|" "a window"; [[ -e $ARGS ]] && _no "a second program started" || _ok
B "https://a.example/x y"; eq "$(tr '\0' '|' <"$TMP/word")" "START|$TMP|$R/usr/bin/helium|https://a.example/x y|" "a link"
B --app=https://open.spotify.com; eq "$(tr '\0' '|' <"$TMP/word")" "START|$TMP|$R/usr/bin/helium|--app=https://open.spotify.com|" "a web app"
case_ "…what asks for its own profile, a port, a batch job or the program's answers goes as it is"
for a in --user-data-dir=/x --headless --remote-debugging-port=0 --version --help --dump-dom; do
  rm -f "$ARGS"; B "$a"; has "$(got)" "$a" "$a: started"
done
case_ "…the browser gone with its socket left (a crash): started anew, not lost"
kill "$LP"; wait "$LP" 2>/dev/null; rm -f "$ARGS"; B https://b.example; has "$(got)" https://b.example
rm -f "$C/SingletonLock" "$C/SingletonSocket"; cd "$REPO" || exit 1
case_ "the desktop's small extension loaded, and the program it tells named in the profile, this home's path; none there: neither"
setup; install_at "$R/usr/bin/helium"; C=${XDG_CONFIG_HOME:-$HOME/.config}/net.imput.helium; rm -rf "$C"; B
lacks "$(got)" --load-extension; [[ -e $C/NativeMessagingHosts/fedokawaii.downloads.json ]] && _no "a host for no extension" || _ok
mkdir -p "$HOME/.local/share/fedokawaii/browser"; cp "$REPO"/configs/home/.local/share/fedokawaii/browser/* "$HOME/.local/share/fedokawaii/browser/"; B
has "$(got)" "--load-extension=$HOME/.local/share/fedokawaii/browser"
eq "$(jq -r .path "$C/NativeMessagingHosts/fedokawaii.downloads.json")" "$HOME/.local/bin/kawa-downloads"
id=$(python3 -I -c 'import base64, hashlib, json, sys
k = json.load(open(sys.argv[1]))["key"]; d = hashlib.sha256(base64.b64decode(k)).hexdigest()[:32]
print("".join(chr(97 + int(c, 16)) for c in d))' "$HOME/.local/share/fedokawaii/browser/manifest.json")
eq "$(jq -r '.allowed_origins[0]' "$C/NativeMessagingHosts/fedokawaii.downloads.json")" "chrome-extension://$id/" "only this extension, by the key in its manifest"
eq "$(jq -c .permissions "$HOME/.local/share/fedokawaii/browser/manifest.json")" '["downloads","nativeMessaging"]' "nothing more than it needs"

done_
