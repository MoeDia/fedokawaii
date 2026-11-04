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
https://example.com"
case_ "no arguments (Super+B): just the feature and the store"
B; eq "$(got)" "$R/usr/bin/helium
$FEAT
$OFF
$PS
$SYS"
case_ "a password store of your own comes after the pinned one (Chromium keeps a switch's last value)"
B --password-store=gnome-libsecret; eq "$(got | tail -n +4)" "$PS
$SYS
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
--incognito
https://a.example"
B --enable-features=A --enable-features=B
eq "$(got | tail -n +2)" "$FEAT,A,B
$OFF
$PS
$SYS" "two lists: both joined, one switch"
eq "$(got | grep -c -- --enable-features)" 1

case_ "a call never moves the microphone's level (Chromium's input volume adjustment off); your own --disable-features joined to it"
setup; install_at "$R/usr/bin/helium"
B --disable-features=A,B https://a.example
eq "$(got | tail -n +2)" "$FEAT
$OFF,A,B
$PS
$SYS
https://a.example"
eq "$(got | grep -c -- --disable-features)" 1

case_ "everything else reaches Helium exactly as given (order, spaces, quotes, \$(…), unicode, a leading dash)"
setup; install_at "$R/usr/bin/helium"
B --new-window "https://example.com/a b?q=\"x\"&y='z'" '$(touch nope)' '`id`' 'مرحبا 日本' -- --enable-features=X
eq "$(got | tail -n +2)" "$FEAT
$OFF
$PS
$SYS
--new-window
https://example.com/a b?q=\"x\"&y='z'
\$(touch nope)
\`id\`
مرحبا 日本
--
--enable-features=X" "(after --, Chromium takes nothing as a switch: not joined either)"
B ''; eq "$(got | wc -l)" 6 "an empty argument kept"
[[ ! -e nope && ! -e $TMP/nope ]] && _ok || _no "an argument ran"
case_ "--help and --version are Helium's (not the launcher's)"
B --help; eq "$(got | tail -n +6)" "--help"
B --version; eq "$(got | tail -n +6)" "--version"

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

done_
