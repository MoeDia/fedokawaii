#!/usr/bin/env bash
# tests/content/test_brave.sh — brave-origin, the launcher in ~/.local/bin that Super+B, links
# and a shell all go through: Brave started with the PulseAudio loopback for screen sharing
# (the "Also share system audio" switch) and its password store pinned to the basic one, a
# feature list of your own joined to it, every other argument passed on as it is; Brave missing. Brave is a stand-in at each place the
# package may put it, under a made-up root (the launcher is run as a copy looking there).
. "$(dirname "$0")/lib.sh"

setup() {   # setup — a sandbox, nothing installed yet under $R
  sandbox
  R=$TMP/root; mkdir -p "$R/usr/bin" "$R/opt/brave.com/brave-origin"
  sed -e "2,\$ s#/usr/bin/#$R/usr/bin/#g" -e "2,\$ s#/opt/#$R/opt/#g" "$REPO/bin/brave-origin" >"$TMP/brave-origin"   # (not the #! line)
  chmod +x "$TMP/brave-origin"
  export ARGS=$TMP/args
}
install_at() {   # install_at PATH [STATUS] — a stand-in Brave: its name, then each argument on a line
  mkdir -p "${1%/*}"
  printf '#!/bin/sh\nprintf "%%s\\n" "$0" "$@" >"$ARGS"\nexit %s\n' "${2:-0}" >"$1"; chmod +x "$1"
}
got() { cat "$ARGS" 2>/dev/null; }
B() { "$TMP/brave-origin" "$@"; }
FEAT=--enable-features=PulseaudioLoopbackForScreenShare PS=--password-store=basic

case_ "the copy looks only under the made-up root"
setup
eq "$(grep -c "$R" "$TMP/brave-origin")" "$(tail -n +2 "$REPO/bin/brave-origin" | grep -cE '/usr/bin/|/opt/')"

case_ "not installed: says so and how to get it, status 127, nothing started"
setup
out=$(B https://example.com 2>&1); r=$?
eq "$r" 127; has "$out" "Brave Origin is not installed (sudo dnf install brave-origin)"
eq "$(got)" ""

case_ "installed: started with the screen-share sound feature and the basic password store, the link after them"
setup; install_at "$R/usr/bin/brave-origin-stable"
rc 0 B https://example.com
eq "$(got)" "$R/usr/bin/brave-origin-stable
$FEAT
$PS
https://example.com"
case_ "no arguments (Super+B): just the feature and the store"
B; eq "$(got)" "$R/usr/bin/brave-origin-stable
$FEAT
$PS"
case_ "a password store of your own comes after the pinned one (Chromium keeps a switch's last value)"
B --password-store=gnome-libsecret; eq "$(got | tail -n +3)" "$PS
--password-store=gnome-libsecret"

case_ "where the package puts it: brave-origin-stable first, then /opt, then brave-origin"
setup; install_at "$R/usr/bin/brave-origin"; install_at "$R/opt/brave.com/brave-origin/brave-origin"
B; eq "$(got | head -n1)" "$R/opt/brave.com/brave-origin/brave-origin"
install_at "$R/usr/bin/brave-origin-stable"; B; eq "$(got | head -n1)" "$R/usr/bin/brave-origin-stable"
setup; install_at "$R/usr/bin/brave-origin"; B; eq "$(got | head -n1)" "$R/usr/bin/brave-origin"
case_ "a file there that cannot run is passed over"
setup; install_at "$R/usr/bin/brave-origin"; : >"$R/usr/bin/brave-origin-stable"
B; eq "$(got | head -n1)" "$R/usr/bin/brave-origin"

case_ "your own feature list is joined to it, once, whatever its place"
setup; install_at "$R/usr/bin/brave-origin-stable"
B --incognito --enable-features=VaapiVideoDecoder,WebRTCPipeWireCapturer https://a.example
eq "$(got | tail -n +2)" "$FEAT,VaapiVideoDecoder,WebRTCPipeWireCapturer
$PS
--incognito
https://a.example"
B --enable-features=A --enable-features=B
eq "$(got | tail -n +2)" "$FEAT,A,B
$PS" "two lists: both joined, one switch"
eq "$(got | grep -c -- --enable-features)" 1

case_ "everything else reaches Brave exactly as given (order, spaces, quotes, \$(…), unicode, a leading dash)"
setup; install_at "$R/usr/bin/brave-origin-stable"
B --new-window "https://example.com/a b?q=\"x\"&y='z'" '$(touch nope)' '`id`' 'مرحبا 日本' -- --enable-features=X
eq "$(got | tail -n +2)" "$FEAT
$PS
--new-window
https://example.com/a b?q=\"x\"&y='z'
\$(touch nope)
\`id\`
مرحبا 日本
--
--enable-features=X" "(after --, Chromium takes nothing as a switch: not joined either)"
B ''; eq "$(got | wc -l)" 4 "an empty argument kept"
[[ ! -e nope && ! -e $TMP/nope ]] && _ok || _no "an argument ran"
case_ "--help and --version are Brave's (not the launcher's)"
B --help; eq "$(got | tail -n +4)" "--help"
B --version; eq "$(got | tail -n +4)" "--version"

case_ "Brave's own exit status comes back"
setup; install_at "$R/usr/bin/brave-origin-stable" 3
rc 3 B

case_ "a home with a space and an accent (links open from there)"
setup; install_at "$R/usr/bin/brave-origin-stable"
odd_home; cp "$TMP/brave-origin" "$HOME/.local/bin/brave-origin"
"$HOME/.local/bin/brave-origin" "file://$HOME/page.html"
eq "$(got | tail -n1)" "file://$HOME/page.html"

done_
