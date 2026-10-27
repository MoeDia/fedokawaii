#!/usr/bin/env bash
# tests/look/test_pack.sh — kawa-wallpaper --pack: the wallpaper pack fetched from GitHub,
# checked by SHA-256 and kept as it came, then drawn for the screen ahead of time, in
# parallel, with its progress in the log (the cache itself: test_wallpaper.sh). curl is a
# stand-in that serves pictures made here (nothing is ever downloaded); ImageMagick is the
# real one; no monitor unless a case gives one.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
need magick python3

setup() {
  look
  SHARE=$HOME/.local/share/fedokawaii; PACK=$SHARE/wallpapers CACHE=$HOME/.cache/fedokawaii
  SCREENS=$CACHE/wallpaper-screens LIST=$SHARE/wallpapers.list
  export KAWA_SYSFS=$TMP/sys; mkdir -p "$KAWA_SYSFS/class/drm"   # (no monitor the kernel lists)
}
art() {   # art FILE — a pack file already here
  mkdir -p "$(dirname "$1")"
  magick -size 64x36 pattern:gray50 "JPG:$1"
}
size_of() { magick "$1" -format '%wx%h' info: 2>/dev/null; }

# ── --pack: fetched, checked, drawn ───────────────────────────────────────────
# curl: answers from $TMP/net ("URL CODE [FILE]"): CODE 0 hands FILE over, anything else is
# that curl error; an URL not listed is "could not resolve host" (6). Nothing is downloaded.
packsetup() {   # packsetup N — a list of N pictures (p1…pN), each served correctly
  setup
  : >"$TMP/net"; mkdir -p "$TMP/src"
  { echo "# test list"; echo; } >"$LIST"
  local i
  for ((i = 1; i <= $1; i++)); do
    magick -size 800x500 "gradient:rgb($((i * 20)),40,90)-rgb(250,$((i * 20)),30)" "$TMP/src/p$i.jpg"
    printf 'dark  p%s  -  center  %s  https://raw.githubusercontent.com/someone/pics/abc/p%s.jpg  Test (CC0)\n' \
      "$i" "$(sha256sum <"$TMP/src/p$i.jpg" | cut -d' ' -f1)" "$i" >>"$LIST"
    echo "https://raw.githubusercontent.com/someone/pics/abc/p$i.jpg 0 $TMP/src/p$i.jpg" >>"$TMP/net"
  done
  export TMPDIR=$TMP/tmpdir; mkdir -p "$TMPDIR"
  stubf curl <<'EOF'
o="" u=""
while [ $# -gt 0 ]; do case $1 in -o) o=$2; shift ;; -*) ;; *) u=$1 ;; esac; shift; done
[ -e "$FAKE_TMP/gate.curl.use" ] && grep -q "^$u" "$FAKE_TMP/gate.curl.use" && { : >"$FAKE_TMP/gate.curl.in"; while [ ! -e "$FAKE_TMP/gate.curl" ]; do [ -d "$FAKE_TMP" ] || exit 6; /bin/sleep 0.02; done; }
line=$(grep -m1 "^$u " "$FAKE_TMP/net") || exit 6
set -- $line
[ "$2" = 0 ] || exit "$2"
cp "$3" "$o"
EOF
}
net() { sed -i "s|/p$1.jpg .*|/p$1.jpg $2 ${3:-$TMP/src/p$1.jpg}|" "$TMP/net"; }   # net N CODE [FILE]
pics() { find "$PACK" -name '*.src' 2>/dev/null | wc -l; }
packline() { grep '^wallpaper pack:' <<<"$1"; }       # packline OUTPUT — the fetch's own summary

case_ "online: every picture fetched, checked and kept exactly as it came (nothing redrawn)"
packsetup 4
out=$(kawa-wallpaper --pack 2>&1); r=$?
eq "$r" 0
eq "$(packline "$out")" "wallpaper pack: 4 fetched, 0 already here, 0 failed"
cmp -s "$PACK/dark/p1.src" "$TMP/src/p1.jpg" && _ok || _no "the picture was changed"
eq "$(size_of "$PACK/dark/p2.src")" 800x500
case_ "run again: nothing fetched"
reset_calls
eq "$(packline "$(kawa-wallpaper --pack 2>&1)")" "wallpaper pack: 0 fetched, 4 already here, 0 failed"
not_called '^curl'
eq "$(ls -A "$TMPDIR")" "" "no temporary folders left"

case_ "offline: three that cannot reach GitHub, and the rest wait for the next run"
packsetup 10
: >"$TMP/net"
start=$SECONDS
out=$(kawa-wallpaper --pack 2>&1); r=$?
eq "$r" 1
eq "$(grep -c '^curl' "$CALLS")" 3 "three tries, not ten"
has "$out" "no connection to raw.githubusercontent.com — 7 more not tried"
eq "$(packline "$out")" "wallpaper pack: 0 fetched, 0 already here, 10 failed"
((SECONDS - start < 10)) && _ok || _no "took $((SECONDS - start)) s"
eq "$(pics)" 0

case_ "timeouts count as offline too; a missing file (HTTP 404) does not stop the rest"
packsetup 6
for i in 1 2 3; do net $i 28; done
kawa-wallpaper --pack >/dev/null 2>&1
eq "$(grep -c '^curl' "$CALLS")" 3
packsetup 6
for i in 1 2 3 4; do net $i 22; done
out=$(kawa-wallpaper --pack 2>&1)
eq "$(grep -c '^curl' "$CALLS")" 6 "all six tried"
eq "$(packline "$out")" "wallpaper pack: 2 fetched, 0 already here, 4 failed"

case_ "a connection that comes and goes: only three failures in a row give up"
packsetup 7
net 1 6; net 2 7; net 4 6; net 5 56; net 6 35
kawa-wallpaper --pack >/dev/null 2>&1
eq "$(grep -c '^curl' "$CALLS")" 6 "the success at 3 resets the count; 4, 5, 6 fail; 7 waits"
eq "$(pics)" 1

case_ "a picture whose checksum does not match: refused, nothing half-made left, the rest go on"
packsetup 3
echo "tampered" >"$TMP/src/bad.jpg"; net 2 0 "$TMP/src/bad.jpg"
out=$(kawa-wallpaper --pack 2>&1); r=$?
eq "$r" 1
has "$out" "could not fetch or draw 'p2'"
eq "$(packline "$out")" "wallpaper pack: 2 fetched, 0 already here, 1 failed"
[[ ! -e $PACK/dark/p2.src ]] && _ok || _no "the tampered picture was kept"
eq "$(find "$PACK" -name '*.tmp*' | wc -l)" 0 "no half-made files"

case_ "a download that is no picture (but matches): refused the same way"
packsetup 2
echo "<html>rate limited</html>" >"$TMP/src/html.jpg"
sed -i "s|^\(dark  p1  -  center  \)[0-9a-f]*|\1$(sha256sum <"$TMP/src/html.jpg" | cut -d' ' -f1)|" "$LIST"; net 1 0 "$TMP/src/html.jpg"
out=$(kawa-wallpaper --pack 2>&1)
eq "$(packline "$out")" "wallpaper pack: 1 fetched, 0 already here, 1 failed"
[[ ! -e $PACK/dark/p1.src ]] && _ok || _no "a page kept as a picture"
eq "$(find "$PACK" -name '*.tmp*' | wc -l)" 0

case_ "partly there already: only the missing ones are fetched"
packsetup 4
kawa-wallpaper --pack >/dev/null 2>&1
rm "$PACK/dark/p2.src" "$PACK/dark/p4.src"; reset_calls
eq "$(packline "$(kawa-wallpaper --pack 2>&1)")" "wallpaper pack: 2 fetched, 2 already here, 0 failed"
eq "$(grep -c '^curl' "$CALLS")" 2

case_ "interrupted (Ctrl+C) mid-fetch, then run again: it picks up where it was, nothing left over"
packsetup 4
echo "https://raw.githubusercontent.com/someone/pics/abc/p3.jpg" >"$TMP/gate.curl.use"
setsid kawa-wallpaper --pack >/dev/null 2>&1 & k=$!
at_gate curl || _no "never reached the third picture"
kill -INT -- -"$k"; kill -TERM "$k"; wait "$k" 2>/dev/null
for _ in {1..200}; do kill -0 -- -"$k" 2>/dev/null || break; /bin/sleep 0.01; done
rm -f "$TMP/gate.curl.use"
eq "$(pics)" 2 "two fetched before the stop"
eq "$(ls -A "$TMPDIR")" "" "its temporary folder went with it"
eq "$(packline "$(kawa-wallpaper --pack 2>&1)")" "wallpaper pack: 2 fetched, 2 already here, 0 failed"

case_ "a half-moved file from a crash: cleared quietly, the picture fetched again"
packsetup 2
kawa-wallpaper --pack >/dev/null 2>&1
rm "$PACK/dark/p2.src"; echo junk >"$PACK/dark/p2.src.tmp"
eq "$(packline "$(kawa-wallpaper --pack 2>&1)")" "wallpaper pack: 1 fetched, 1 already here, 0 failed"
[[ ! -e $PACK/dark/p2.src.tmp ]] && _ok || _no "the half-moved file is still there"

case_ "pictures the list no longer names, and the old pack's redrawn copies: removed, with the screen-sized drawings"
packsetup 1
kawa-wallpaper --pack >/dev/null 2>&1
art "$PACK/dark/old-one.src"; art "$PACK/light/old-two.src"; art "$PACK/dark/p1.png"   # (the pack before: NAME.png)
mkdir -p "$SCREENS/1920x1080"; : >"$SCREENS/1920x1080/old-one.0123456789abcdef.center.png"
eq "$(packline "$(kawa-wallpaper --pack 2>&1)")" "wallpaper pack: 0 fetched, 1 already here, 0 failed, 3 retired"
[[ ! -e $PACK/dark/old-one.src && ! -e $PACK/light/old-two.src && ! -e $PACK/dark/p1.png ]] && _ok || _no "not retired"
[[ -e $PACK/dark/p1.src ]] && _ok || _no "a listed picture went too"
[[ ! -e $SCREENS/1920x1080/old-one.0123456789abcdef.center.png ]] && _ok || _no "the drawings of retired pictures stayed"

# ── drawn ahead, once fetched ────────────────────────────────────────────────
case_ "with a monitor: the fetched pictures drawn for it, in parallel, the progress and the summary in the log"
packsetup 4
screens "DP-1 1920x1080@143.981003"
out=$(kawa-wallpaper --pack 2>&1); r=$?
eq "$r" 0
eq "$(packline "$out")" "wallpaper pack: 4 fetched, 0 already here, 0 failed"
has "$out" "wallpaper cache: drawing 4 pictures for 1920x1080"
has "$out" "wallpaper cache: 2/4" "a progress line"
has "$out" "wallpaper cache: 4 pictures drawn for 1920x1080 in"
eq "$(find "$SCREENS/1920x1080" -name 'p*.png' | wc -l)" 4
eq "$(sed -n '/^wallpaper pack:/=' <<<"$out")" 1 "the fetch's summary first, then the drawing"
case_ "run again (theme.sh again, or the first login): nothing drawn twice"
out=$(kawa-wallpaper --pack 2>&1)
eq "$out" "wallpaper pack: 0 fetched, 4 already here, 0 failed"
case_ "no monitor yet (setup, before the first login, no monitor the kernel lists): it says so"
packsetup 2
out=$(kawa-wallpaper --pack 2>&1)
has "$out" "wallpaper cache: no monitor found — the pack is drawn for it at the first login"

case_ "an empty list (comments only) retires nothing; a missing list says so"
setup; art "$PACK/dark/seaside-train.src"; printf '# nothing\n\n' >"$LIST"
eq "$(packline "$(kawa-wallpaper --pack 2>&1)")" "wallpaper pack: 0 fetched, 0 already here, 0 failed"
[[ -e $PACK/dark/seaside-train.src ]] && _ok || _no "an empty list wiped the pack"
rm "$LIST"
out=$(kawa-wallpaper --pack 2>&1); r=$?
eq "$r" 1; has "$out" "is missing (run theme.sh)"

done_
