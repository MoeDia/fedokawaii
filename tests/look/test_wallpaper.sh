#!/usr/bin/env bash
# tests/look/test_wallpaper.sh — kawa-wallpaper: each theme's own wallpaper, drawn at full
# quality at every monitor's exact size; the swap (the new swaybg up before the old one goes);
# the cache drawn ahead (every screen and the picker's previews, keyed by name and SHA-256);
# the picker; its previews. ImageMagick is the real one (the pictures are checked to the
# pixel); swaybg, the monitors (wlr-randr, the kernel's list), fzf and the picker's window are
# stand-ins (the pack's fetching: test_pack.sh).
. "$(dirname "$0")/../lib/harness.sh"

# (the colours as the palette makes them today: tools/build-themes.py's colors.sh, never a copy)
TH=$REPO/configs/home/.config/fedokawaii/themes
GD=$(sed -n 's/^C_GROUND=//p' "$TH/dark/colors.sh") GL=$(sed -n 's/^C_GROUND=//p' "$TH/light/colors.sh")
AD=$(sed -n 's/^C_ACCENT=//p' "$TH/dark/colors.sh") AL=$(sed -n 's/^C_ACCENT=//p' "$TH/light/colors.sh")
srgb() { printf 'srgb(%d,%d,%d)' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"; }   # (as ImageMagick names a pixel)
. "$(dirname "$0")/lib.sh"
need magick python3 flock

setup() {
  look
  unset WAYLAND_DISPLAY FAKE_SWAYBG
  SHARE=$HOME/.local/share/fedokawaii; PACK=$SHARE/wallpapers CACHE=$HOME/.cache/fedokawaii
  SCREENS=$CACHE/wallpaper-screens PREVIEWS=$CACHE/wallpaper-previews
  STATE=$HOME/.local/state/fedokawaii WP=$HOME/Pictures/Wallpapers
  export KAWA_SYSFS=$TMP/sys; mkdir -p "$KAWA_SYSFS/class/drm"   # (no monitor the kernel lists)
  # swaybg: keeps its arguments; loads its pictures as swaybg does (each opened, read and
  # closed — a copy kept as $TMP/seen/CALL-N.png), then waits on the compositor (in poll) for
  # ever. "up N" and "term N" go to $TMP/swap.log. FAKE_SWAYBG=dies: it ends at once; =hangs:
  # it never loads its picture
  cat >"$TMP/fake-swaybg.py" <<'PY'
import os, select, shutil, signal, sys, time
n, a, d = sys.argv[2], sys.argv[3:], os.environ["FAKE_TMP"]
def note(s):
    with open(d + "/swap.log", "a") as f:
        f.write(s + "\n")
def bye(*_):
    note("term " + n); os._exit(0)
signal.signal(signal.SIGTERM, bye)
mode = os.environ.get("FAKE_SWAYBG", "")
if mode == "dies":
    sys.exit(1)
if mode != "hangs":
    os.makedirs(d + "/seen", exist_ok=True); k = 0
    for i, x in enumerate(a):
        if x == "-i" and i + 1 < len(a):
            time.sleep(0.05)                          # (a moment to load it)
            shutil.copyfile(a[i + 1], "%s/seen/%s-%d.png" % (d, n, k)); k += 1
    note("up " + n)
select.poll().poll()
PY
  argv swaybg 'echo "swaybg $$" >>"$FAKE_PROCS"
exec python3 -I "$FAKE_TMP/fake-swaybg.py" "fake-swaybg-of-$FAKE_TMP" "$n" "$@"'
  # setsid -f CMD: CMD at once (so its arguments are there to check); plain setsid: the real one
  stub setsid '[ "$1" = -f ] && { shift; exec "$@"; }; exec /usr/bin/setsid "$@"'
  stub sleep
  screens "DP-1 1920x1080@143.981003"
  # shellcheck source=/dev/null
  . "$HOME/.config/fedokawaii/icons.sh"
}
running() { pgrep -x swaybg | wc -l; }                  # swaybg processes alive now
settled() {   # settled N — swaybg processes alive, once the killed ones are gone (5 s at most)
  local n i; for i in {1..250}; do n=$(running); ((n <= $1)) && break; /bin/sleep 0.02; done; echo "$n"
}
last() { ncalls swaybg; }
quiet() { flock "$CACHE/wallpaper-cache.lock" true 2>/dev/null; }   # the drawing in the background done
art() {   # art NAME [WxH] [GRAVITY-TEST] — a pack picture (NAME.src, as fetched: a JPEG) for the
  # current theme folder given in NAME's path; a smooth gradient, or with "split" its top
  # quarter red and the rest blue (to see which part a crop keeps)
  local f=$1 size=${2:-3840x2160}
  mkdir -p "$(dirname "$f")"
  if [[ ${3:-} == split ]]; then
    magick -size "${size%x*}x$(( ${size#*x} / 4 ))" xc:red -size "${size%x*}x$(( ${size#*x} * 3 / 4 ))" xc:blue -append "JPG:$f"
  else magick -size "$size" gradient:'#203050'-'#e0c080' "JPG:$f"; fi
}
px() { magick "$1" -format "%[pixel:p{$2,$3}]" info: 2>/dev/null; }
photo() { mkdir -p "$(dirname "$1")"; magick -size 64x40 gradient:red-blue "$1"; }   # photo FILE
shown() { printf '%s' "$TMP/seen/${1:-$(last)}-0.png"; }         # the first picture swaybg N loaded
handed() { args_of swaybg "${1:-$(last)}" | sed -n '/^-i$/{n;p}' | head -n1; }   # …the file it was given
same() { cmp -s "$1" "$2" && _ok || _no "${3:-$1 and $2 differ}"; }               # same PICTURE PICTURE [MSG]
colours() { magick "$1" -format '%k' info: 2>/dev/null; }
key_of() {   # key_of NAME [THEME] — a pack picture's key: its name, its SHA-256's first 16, its crop
  local s c; read -r s c < <(awk -v n="$1" -v m="${2:-dark}" '$1 == m && $2 == n { print $5, $4 }' "$SHARE/wallpapers.list")
  printf '%s.%s.%s' "$1" "${s:0:16}" "$c"
}
cover_of() { printf '%s' "$SCREENS/${2:-1920x1080}/$(key_of "$1").png"; }   # cover_of NAME [WxH]
list_add() { printf 'dark  %s  -  %s  %s  https://x/%s.jpg  Test\n' "$1" "${3:-center}" "${2:-0}" "$1" >>"$SHARE/wallpapers.list"; }

# ── --restore: the theme's choice, every monitor at its size ───────────────────
setup
case_ "before the pack is here: the theme's plain ground, nothing else"
rc 0 kawa-wallpaper --restore
eq "$(args_of swaybg | head -n 2 | tr '\n' ' ')" "-c #$GD " "the ground's colour"
eq "$(px "$(shown)" 0 0)" "$(srgb "$GD")" "a picture of the ground (shown as any other)"
eq "$(running)" 1 "one swaybg"

case_ "with the pack: the theme's default, drawn at the monitor's exact size at full quality"
setup
art "$PACK/dark/ink-ridges-night.src"
rc 0 kawa-wallpaper --restore
args_eq swaybg 1 -c "#$GD" -o DP-1 -i "$(handed)" -m fill
same "$(shown)" "$(cover_of ink-ridges-night)" "not the cached 1080p drawing"
[[ $(handed) == "$XDG_RUNTIME_DIR"/kawa-wallpaper/*.png ]] && _ok || _no "not handed over as a copy of its own: $(handed)"
eq "$(size_of "$(shown)")" 1920x1080
(( $(colours "$(shown)") > 500 )) && _ok || _no "only $(colours "$(shown)") colours: redrawn coarsely, not at full quality"

case_ "two monitors of different sizes, one turned, one switched off: each its own size"
setup
art "$PACK/dark/ink-ridges-night.src"
screens "DP-1 2560x1440@164.998993" "HDMI-A-1 3840x2160@60.000000" "DP-2 1920x1080 turned" "DP-3 1920x1080 off"
rc 0 kawa-wallpaper --restore
a=$(args_of swaybg)
for o in DP-1:2560x1440 HDMI-A-1:3840x2160 DP-2:1080x1920; do   # (the copies the swaybg on screen shows)
  f=$(grep -A2 -x "${o%:*}" <<<"$a" | sed -n 3p)
  eq "$(size_of "$f")" "${o#*:}" "${o%:*}"
done
lacks "$a" DP-3 "a switched-off monitor is left out"

case_ "the crop: from the middle, or towards the side the list names"
setup
list_add tall-one 0 north; list_add tall-two 0 center
art "$PACK/dark/tall-one.src" 1920x2160 split; art "$PACK/dark/tall-two.src" 1920x2160 split
kawa-wallpaper --set pack:tall-one
[[ $(px "$(shown)" 960 2) =~ ^srgb\(2[0-9][0-9],[0-9],[0-9]\)$ ]] && _ok || _no "north: the top (red) not kept: $(px "$(shown)" 960 2)"
kawa-wallpaper --set pack:tall-two
[[ $(px "$(shown)" 960 2) =~ ^srgb\([0-9],[0-9],2[0-9][0-9]\)$ ]] && _ok || _no "centre: not the middle (blue at its top edge): $(px "$(shown)" 960 2)"

case_ "a custom mode with no refresh rate; no wlr-randr at all: the plain ground"
setup
art "$PACK/dark/ink-ridges-night.src"
screens "DP-1 1920x1200@none"
kawa-wallpaper --restore
eq "$(size_of "$(shown)")" 1920x1200 "16:10: covered and cut to size"
setup; art "$PACK/dark/ink-ridges-night.src"; hide wlr-randr
kawa-wallpaper --restore
eq "$(px "$(shown)" 0 0)" "$(srgb "$GD")" "the plain ground"

case_ "drawn once: a second restore uses the same drawing, nothing redrawn"
setup
art "$PACK/dark/ink-ridges-night.src"
kawa-wallpaper --restore; first=$(cover_of ink-ridges-night); t=$(stat -c %Y "$first")
/bin/sleep 1.1; kawa-wallpaper --restore
same "$(shown 2)" "$first"; eq "$(stat -c %Y "$first")" "$t" "drawn again"
case_ "a picture replaced under the same name (newer than its drawing): drawn again"
art "$PACK/dark/ink-ridges-night.src" 3840x2160 split; touch -d '+5 seconds' "$PACK/dark/ink-ridges-night.src"
kawa-wallpaper --restore
cmp -s "$(shown 3)" "$(shown 1)" && _no "the old drawing was shown" || _ok

case_ "the light theme: its own default (ink-ridges), ground and choice"
setup
ln -sfn themes/light "$HOME/.config/fedokawaii/current"
art "$PACK/light/ink-ridges.src"
kawa-wallpaper --restore
eq "$(args_of swaybg | head -n2 | tail -n1)" "#$GL"
eq "$(size_of "$(shown)")" 1920x1080 "ink-ridges shown"
[[ ! -e $STATE/wallpaper-dark ]] && _ok || _no "the dark theme's choice was written by a light restore"

case_ "the old swaybg goes once the new one is up: one left after many changes, one copy"
setup
for _ in 1 2 3 4; do kawa-wallpaper --restore; done
eq "$(settled 1)" 1
eq "$(last)" 4
eq "$(find "$XDG_RUNTIME_DIR/kawa-wallpaper" -type f | wc -l)" 1 "only the copy the one on screen shows"

case_ "15 restores at once (quick theme switches): they queue, and one swaybg is left"
setup
pids=(); for _ in {1..15}; do kawa-wallpaper --restore & pids+=($!); done
codes=""; for p in "${pids[@]}"; do wait "$p"; codes+="$?"; done
eq "$codes" "000000000000000"
eq "$(settled 1)" 1

# ── the swap: up first, then the old one goes ───────────────────────────────────
case_ "the swap: the new swaybg has loaded its picture and waits on the compositor before the old one is told to go"
setup
art "$PACK/dark/ink-ridges-night.src" 1920x1080; art "$PACK/dark/moon-road-ink.src" 1920x1080
kawa-wallpaper --restore
rc 0 kawa-wallpaper --set pack:moon-road-ink
eq "$(grep -E '^(up|term)' "$TMP/swap.log" | tr '\n' ',')" "up 1,up 2,term 1," "up 2 before term 1"
eq "$(settled 1)" 1
case_ "--set returns with the new one on screen (kawa-theme's switch is over then)"
rc 0 kawa-wallpaper --set pack:ink-ridges-night
eq "$(tail -n 2 "$TMP/swap.log" | tr '\n' ',')" "up 3,term 2," "returned before it was up"
has "$(cat "$CACHE/wallpaper.log")" "kawa-wallpaper: set pack:ink-ridges-night on screen in" "the change's time logged"
case_ "a swaybg that ends at once: exit 1, the old one stays, the choice unchanged, no copy left"
old=$(pgrep -x swaybg)
FAKE_SWAYBG=dies rc 1 kawa-wallpaper --set pack:moon-road-ink
alive "$old" && _ok || _no "the wallpaper on screen was taken down"
eq "$(cat "$STATE/wallpaper-dark")" pack:ink-ridges-night
eq "$(find "$XDG_RUNTIME_DIR/kawa-wallpaper" -type f | wc -l)" 1
case_ "a swaybg that never draws: given up after 3 s, it goes, the old one stays"
s=$SECONDS
FAKE_SWAYBG=hangs rc 1 kawa-wallpaper --set pack:moon-road-ink
((SECONDS - s <= 6)) && _ok || _no "took $((SECONDS - s)) s"
alive "$old" && _ok || _no "the wallpaper on screen was taken down"
eq "$(settled 1)" 1 "the one that never drew is gone"

case_ "swaybg not installed: says so, exit 1, the old wallpaper stays and the choice is kept"
setup
art "$PACK/dark/moon-road-ink.src"
kawa-wallpaper --restore; old=$(pgrep -x swaybg)
echo "pack:ink-ridges-night" >"$STATE/wallpaper-dark"
hide swaybg
out=$(kawa-wallpaper --set pack:moon-road-ink 2>&1); r=$?
eq "$r" 1
has "$out" "swaybg"
alive "$old" && _ok || _no "the wallpaper on screen was taken down"
eq "$(cat "$STATE/wallpaper-dark")" "pack:ink-ridges-night"
rc 1 kawa-wallpaper --restore

# ── --set: a choice, remembered per theme ─────────────────────────────────────
case_ "a pack picture with a pair: both themes get the same place"
setup
art "$PACK/dark/ink-ridges-night.src" 1920x1080; art "$PACK/light/ink-ridges.src" 1920x1080
rc 0 kawa-wallpaper --set pack:ink-ridges-night
eq "$(cat "$STATE/wallpaper-dark")" pack:ink-ridges-night
eq "$(cat "$STATE/wallpaper-light")" pack:ink-ridges "the light theme: the same ridges by day"
art "$PACK/dark/seaside-train.src" 1920x1080
rc 0 kawa-wallpaper --set pack:seaside-train
eq "$(cat "$STATE/wallpaper-light")" pack:ink-ridges "no pair: the other theme keeps its own"

case_ "your own picture with an odd name: drawn to the screen's size (a small one enlarged to cover), remembered exactly"
setup
odd="$WP/my "'"best" it'\''s $(touch pwned) `id` ü日本 العربية -x.png'
photo "$odd"
( cd "$TMP" && kawa-wallpaper --set "$odd" ); r=$?
eq "$r" 0
eq "$(size_of "$(shown)")" 1920x1080
eq "$(cat "$STATE/wallpaper-dark")" "$odd"
[[ ! -e $TMP/pwned ]] && _ok || _no "a file name ran as a command"
kawa-wallpaper --restore
same "$(shown 2)" "$(shown 1)" "not the same drawing at login"

case_ "your own picture: keyed by its content (SHA-256, read once and remembered by size and time)"
sum=$(sha256sum <"$odd" | cut -d' ' -f1)
f=$(find "$SCREENS/1920x1080" -name "*.${sum:0:16}.center.png")
eq "$(wc -l <<<"$f")" 1 "its drawing: NAME.SHA16.center.png"
[[ ${f##*/} =~ ^[A-Za-z0-9_-]+\.[0-9a-f]{16}\.center\.png$ ]] && _ok || _no "an unsafe file name: ${f##*/}"
eq "$(grep -c "$sum" "$CACHE/wallpaper-sums")" 1 "remembered once"
grep -qF " $sum $odd" "$CACHE/wallpaper-sums" && _ok || _no "not remembered with its size and time"
cp "$odd" "$WP/copy.png"; kawa-wallpaper --set "$WP/copy.png"
eq "$(find "$SCREENS/1920x1080" -name "*.${sum:0:16}.center.png" | wc -l)" 2 "the same picture under another name: its own drawing"
photo2() { magick -size 64x40 gradient:green-yellow "$1"; }
photo2 "$odd"; touch -d '+3 seconds' "$odd"
kawa-wallpaper --set "$odd"
cmp -s "$(shown)" "$(shown 1)" && _no "changed content, the old drawing shown" || _ok

case_ "a name with a line break or a leading dash, set directly: still exact"
setup
nl="$WP/two"$'\n'"lines.png"; photo "$nl"
rc 0 kawa-wallpaper --set "$nl"
eq "$(size_of "$(shown)")" 1920x1080
eq "$(cat "$STATE/wallpaper-dark")" "$nl"
dash="$WP/-x.png"; photo "$dash"
rc 0 kawa-wallpaper --set "$dash"; eq "$(cat "$STATE/wallpaper-dark")" "$dash"

case_ "a choice that is gone: --set says no; --restore shows the default but keeps remembering it"
setup
art "$PACK/dark/ink-ridges-night.src" 1920x1080
rc 1 kawa-wallpaper --set "$WP/nothing.png"
eq "$(last)" 0 "nothing was drawn"
photo "$WP/later.png"; kawa-wallpaper --set "$WP/later.png"
mv "$WP/later.png" "$TMP/away.png"                 # (on a drive not there yet, or deleted)
rc 0 kawa-wallpaper --restore
same "$(shown 2)" "$(cover_of ink-ridges-night)" "not the default (ink-ridges-night) instead"
eq "$(cat "$STATE/wallpaper-dark")" "$WP/later.png" "the choice is still yours"
mv "$TMP/away.png" "$WP/later.png"
kawa-wallpaper --restore
same "$(shown 3)" "$(shown 1)" "not back with its picture"
echo "pack:retired-one" >"$STATE/wallpaper-dark"
rc 0 kawa-wallpaper --restore
same "$(shown 4)" "$(cover_of ink-ridges-night)" "a pack picture no longer there: not the default"

case_ "--set by hand with a name relative to the folder you are in: remembered in full"
setup
photo "$WP/rel.png"
( cd "$WP" && kawa-wallpaper --set rel.png ); r=$?
eq "$r" 0
eq "$(cat "$STATE/wallpaper-dark")" "$WP/rel.png" "a full path: --restore at login finds it from any folder"
out=$(kawa-wallpaper --set "$WP/nope.png" 2>&1); r=$?
eq "$r" 1
has "$out" "nope.png" "a choice that is not there is named"

case_ "an empty or garbled state file: the default"
setup
art "$PACK/dark/ink-ridges-night.src" 1920x1080
mkdir -p "$STATE"; : >"$STATE/wallpaper-dark"
rc 0 kawa-wallpaper --restore
same "$(shown)" "$(cover_of ink-ridges-night)"
printf '\x00\xff garbage' >"$STATE/wallpaper-dark"
rc 0 kawa-wallpaper --restore
same "$(shown 2)" "$(cover_of ink-ridges-night)"
case_ "an old choice from before (the drawn Fuji, gone): the default"
echo fuji >"$STATE/wallpaper-dark"
rc 0 kawa-wallpaper --restore
same "$(shown 3)" "$(cover_of ink-ridges-night)"

case_ "HOME with a space: everything still lands where it should"
setup
mkdir -p "$TMP/my home"; cp -a "$HOME/." "$TMP/my home/"; export HOME="$TMP/my home"
SHARE=$HOME/.local/share/fedokawaii CACHE=$HOME/.cache/fedokawaii PACK=$HOME/.local/share/fedokawaii/wallpapers SCREENS=$HOME/.cache/fedokawaii/wallpaper-screens
art "$PACK/dark/ink-ridges-night.src" 1920x1080
rc 0 kawa-wallpaper --restore
[[ -s $(cover_of ink-ridges-night) ]] && _ok || _no "not drawn into the cache"
same "$(shown)" "$(cover_of ink-ridges-night)"

case_ "no runtime folder: exit 1 with a plain message"
setup
export XDG_RUNTIME_DIR=$TMP/no-such-run
out=$(kawa-wallpaper --restore 2>&1); r=$?
eq "$r" 1
has "$out" "kawa-wallpaper:"
lacks "$out" "line "

case_ "--help, and a wrong option"
setup
out=$(kawa-wallpaper --help 2>&1); r=$?
eq "$r" 0; has "$out" "kawa-wallpaper --restore"; has "$out" "wallpaper-screens"
out=$(kawa-wallpaper --bogus 2>&1); r=$?
eq "$r" 2; has "$out" "usage: kawa-wallpaper"

# ── the cache, drawn ahead ────────────────────────────────────────────────────
# (three dark pictures and two light ones; the picker's preview area as it last measured it)
cachesetup() {
  setup
  printf '# test\n' >"$SHARE/wallpapers.list"
  for n in d1 d2 d3; do list_add "$n" "$(printf '%s' "$n" | sha256sum | cut -d' ' -f1)"; art "$PACK/dark/$n.src" 960x540; done
  for n in l1 l2; do
    printf 'light  %s  -  center  %s  https://x/%s.jpg  Test\n' "$n" "$(printf '%s' "$n" | sha256sum | cut -d' ' -f1)" "$n" >>"$SHARE/wallpapers.list"
    art "$PACK/light/$n.src" 960x540
  done
  mkdir -p "$PREVIEWS"; echo "12x26 78x17" >"$PREVIEWS/geometry"
}
pngs() { find "$SCREENS/${1:-1920x1080}" -name '*.png' 2>/dev/null | wc -l; }
sixes() { find "$PREVIEWS" -name '*.six' 2>/dev/null | wc -l; }
stamp() { find "$SCREENS" "$PREVIEWS" -type f \( -name '*.png' -o -name '*.six' \) -printf '%p %T@\n' | sort; }

case_ "--cache (a miss): every pack picture of both themes drawn for the screen, and its preview for the picker"
cachesetup
out=$(kawa-wallpaper --cache 2>&1); r=$?
eq "$r" 0
eq "$(pngs)" 5 "five drawings at 1920x1080"
eq "$(sixes)" 5 "five previews"
[[ -s $SCREENS/1920x1080/$(key_of d2).png ]] && _ok || _no "d2: no $(key_of d2).png"
[[ -s $PREVIEWS/1920x1080-12x26-$GD/$(key_of d1).78x17.six ]] && _ok || _no "d1's preview: not where the picker looks (screen-cell-ground/KEY.COLSxROWS.six)"
[[ -s $PREVIEWS/1920x1080-12x26-$GL/$(key_of l1 light).78x17.six ]] && _ok || _no "l1's preview: on its own theme's ground"
has "$out" "wallpaper cache: drawing 5 pictures for 1920x1080"
has "$out" "wallpaper cache: 5 pictures drawn for 1920x1080 in"
eq "$(size_of "$SCREENS/1920x1080/$(key_of d3).png")" 1920x1080
case_ "--cache again (all hits): nothing drawn, nothing said"
before=$(stamp)
eq "$(kawa-wallpaper --cache 2>&1)" "" "silent"
eq "$(stamp)" "$before" "nothing drawn again"
case_ "--cache-status: complete and current"
out=$(kawa-wallpaper --cache-status); r=$?
eq "$r" 0; has "$out" "wallpaper cache: all 5 pack pictures drawn and current"; has "$out" "1920x1080 · 5 files"
case_ "keyed by SHA-256: the list's checksum changed — that one drawn again under its new key, the old one tidied away"
old=$(cover_of d2)
sed -i "s/^\(dark  d2  -  center  \)[0-9a-f]*/\1$(printf x | sha256sum | cut -d' ' -f1)/" "$SHARE/wallpapers.list"
rc 1 kawa-wallpaper --cache-status
out=$(kawa-wallpaper --cache 2>&1)
has "$out" "drawing 1 pictures"
[[ -s $(cover_of d2) && $(cover_of d2) != "$old" ]] && _ok || _no "not drawn under the new key"
[[ ! -e $old ]] && _ok || _no "the old key's drawing was kept"
eq "$(pngs)" 5; eq "$(sixes)" 5
case_ "a picture retired from the list: its drawing and preview go"
sed -i '/^dark  d3 /d' "$SHARE/wallpapers.list"
kawa-wallpaper --cache >/dev/null 2>&1
eq "$(pngs)" 4; eq "$(sixes)" 4
case_ "half-made files (a drawing killed half-way) go after a minute"
: >"$SCREENS/1920x1080/x.png.123.tmp"; touch -d '5 minutes ago' "$SCREENS/1920x1080/x.png.123.tmp"
: >"$SCREENS/1920x1080/y.png.124.tmp"
sed -i "s/^\(dark  d1  -  center  \)[0-9a-f]*/\1$(printf y | sha256sum | cut -d' ' -f1)/" "$SHARE/wallpapers.list"   # (something to do)
kawa-wallpaper --cache >/dev/null 2>&1
[[ ! -e $SCREENS/1920x1080/x.png.123.tmp ]] && _ok || _no "an old half-made file stayed"
[[ -e $SCREENS/1920x1080/y.png.124.tmp ]] && _ok || _no "one being drawn now was removed"

case_ "a new screen size (kawa-display, a monitor plugged in): --restore shows it at once, the rest drawn in the background, once"
cachesetup
kawa-wallpaper --cache >/dev/null 2>&1
echo "pack:d1" >"$STATE/wallpaper-dark"
screens "DP-1 2560x1440@164.998993"
rc 0 kawa-wallpaper --restore
eq "$(size_of "$(shown)")" 2560x1440 "shown at its size at once"
quiet
eq "$(pngs 2560x1440)" 5 "every pack picture drawn for 2560x1440 in the background"
eq "$(pngs 1920x1080)" 5 "the other size kept (a monitor that comes back)"
before=$(stamp)
kawa-wallpaper --restore; quiet
eq "$(stamp)" "$before" "nothing drawn twice"
case_ "a size unused for a month goes at the next tidy"
touch -d '40 days ago' "$SCREENS/1920x1080"
sed -i "s/^\(dark  d1  -  center  \)[0-9a-f]*/\1$(printf z | sha256sum | cut -d' ' -f1)/" "$SHARE/wallpapers.list"
kawa-wallpaper --cache >/dev/null 2>&1
[[ ! -e $SCREENS/1920x1080 ]] && _ok || _no "the month-old size stayed"
[[ -d $SCREENS/2560x1440 ]] && _ok || _no "the size in use went"

case_ "no session (theme.sh before the first login): the kernel's monitors, at their preferred mode"
cachesetup; hide wlr-randr
mkdir -p "$KAWA_SYSFS/class/drm/card1-DP-1" "$KAWA_SYSFS/class/drm/card1-HDMI-A-1"
echo connected >"$KAWA_SYSFS/class/drm/card1-DP-1/status"; printf '2560x1440\n1920x1080\n' >"$KAWA_SYSFS/class/drm/card1-DP-1/modes"
echo disconnected >"$KAWA_SYSFS/class/drm/card1-HDMI-A-1/status"; printf '3840x2160\n' >"$KAWA_SYSFS/class/drm/card1-HDMI-A-1/modes"
out=$(kawa-wallpaper --cache 2>&1)
has "$out" "for 2560x1440"
eq "$(pngs 2560x1440)" 5
[[ ! -e $SCREENS/3840x2160 ]] && _ok || _no "a monitor not connected was drawn for"
case_ "no monitor at all: says so, draws nothing"
rm -rf "${KAWA_SYSFS:?}/class/drm/"*
out=$(kawa-wallpaper --cache 2>&1); r=$?
eq "$r" 0; has "$out" "no monitor found"

case_ "the picker not opened yet (its cell unknown): the drawings only; --cache-status says so"
cachesetup; rm "$PREVIEWS/geometry"
kawa-wallpaper --cache >/dev/null 2>&1
eq "$(pngs)" 5; eq "$(sixes)" 0
has "$(kawa-wallpaper --cache-status)" "the picker not opened yet"

case_ "one at a time: a second --cache waits; one in the background leaves it to the first"
cachesetup
exec 7>"$CACHE/wallpaper-cache.lock"; flock 7
s=$SECONDS; kawa-wallpaper --cache --background; r=$?
eq "$r" 0; ((SECONDS - s < 3)) && _ok || _no "the background one waited"
eq "$(pngs)" 0 "it drew nothing"
exec 7>&-

case_ "your own pictures are tidied too: deleted or changed ones forgotten, their drawings gone"
cachesetup
photo "$WP/mine.png"; kawa-wallpaper --set "$WP/mine.png"
mine=$(find "$SCREENS/1920x1080" -name 'mine.*.png'); [[ -s $mine ]] && _ok || _no "not drawn"
kawa-wallpaper --cache >/dev/null 2>&1; quiet
[[ -s $mine ]] && _ok || _no "a picture of yours still there was tidied away"
rm "$WP/mine.png"
sed -i "s/^\(dark  d1  -  center  \)[0-9a-f]*/\1$(printf q | sha256sum | cut -d' ' -f1)/" "$SHARE/wallpapers.list"
kawa-wallpaper --cache >/dev/null 2>&1
[[ ! -e $mine ]] && _ok || _no "the drawing of a deleted picture stayed"
lacks "$(cat "$CACHE/wallpaper-sums")" "mine.png" "a deleted picture is forgotten"

# ── the picker ───────────────────────────────────────────────────────────────
# fzf: keeps the rows and its options, then answers as FZF_PICK says (a row's first field,
# or "esc"); the picker's window (kawa-term --float) runs its command in place
picker() {
  argv fzf 'tee "$FAKE_TMP/all" | grep -v "^rotate	" >"$FAKE_TMP/rows"   # (the switch row apart: $TMP/all)
case ${FZF_PICK:-esc} in esc) exit 130 ;; esac
grep -m1 -F "$FZF_PICK	" "$FAKE_TMP/rows" || exit 1'
  stub kawa-term 'while [ "$1" != "--" ]; do shift; done; shift; "$@"'
  stub kawa-cell 'echo 12x24'
}
rows() { cat "$TMP/rows"; }
nrows() { wc -l <"$TMP/rows"; }
plain() { cut -f3 "$TMP/rows" | sed 's/\x1b\[[0-9;]*m//g'; }       # the rows as they read
setup; picker
case_ "before the pack, nothing of your own: no rows"
kawa-wallpaper --tui "$TMP/out"
eq "$(nrows)" 0
case_ "one picture of your own: listed (its key not known until it is first read)"
photo "$WP/only one.png"
kawa-wallpaper --tui "$TMP/out"
eq "$(cut -f1,2 "$TMP/rows")" "$WP/only one.png	"
eq "$(plain)" "  $ICON_FOLDER  only one.png"
rm "$WP/only one.png"

case_ "the pack and your own: the default first, the pack in list order, then yours"
# (the pack has one pair, the default's, listed apart: two more, of different lengths, for the ◐ column)
list_add quay-night; list_add old-pier-at-night
sed -i 's/^dark  quay-night  -/dark  quay-night  quay-day/; s/^dark  old-pier-at-night  -/dark  old-pier-at-night  old-pier/' "$SHARE/wallpapers.list"
art "$PACK/dark/ink-ridges-night.src" 64x40; art "$PACK/dark/moon-road-ink.src" 64x40; art "$PACK/dark/seaside-train.src" 64x40
art "$PACK/dark/mishima-mist.src" 64x40; art "$PACK/dark/quay-night.src" 64x40; art "$PACK/dark/old-pier-at-night.src" 64x40; art "$PACK/light/red-fuji.src" 64x40
photo "$WP/b.png"; photo "$WP/a.jpg"; photo "$WP/sub dir/c.webp"
kawa-wallpaper --tui "$TMP/out"
eq "$(cut -f1,2 "$TMP/rows" | head -n1)" "default	$(key_of ink-ridges-night)" "the default, with its key"
eq "$(cut -f1 "$TMP/rows" | tr '\n' ' ')" "default pack:moon-road-ink pack:mishima-mist pack:seaside-train pack:quay-night pack:old-pier-at-night $WP/a.jpg $WP/b.png $WP/sub dir/c.webp "
has "$(plain)" "  $ICON_FOLDER  sub dir/c.webp"
lacks "$(rows)" red-fuji "the other theme's pictures are not offered"

case_ "the rows (design system §7): two spaces, the glyph, two spaces, the name; the value right-aligned in muted"
d=$(plain | head -n1)
eq "$d" "  $ICON_TORII  ink-ridges-night$(printf '%*s' $((76 - 5 - 16 - 17)) '')current · default" "the default, shown now: 'current · default' at the last column"
eq "$(plain | grep -F "$ICON_THEME" | while IFS= read -r l; do printf '%s\n' "$(LC_ALL=C.UTF-8 wc -L <<<"$l")"; done | sort -u)" 76 "the ◐ marks: at the last column (76)"
eq "$(grep -cF "$ICON_THEME" "$TMP/rows")" 2 "quay-night and old-pier-at-night have a pair"
has "$(sed -n 1p "$TMP/rows")" $'\e[38;5;21mcurrent · default' "the value in muted (palette 21)"
has "$(sed -n 1p "$TMP/rows")" $'\e[38;5;21m'"$ICON_TORII" "the glyph in muted"
case_ "the one shown now says so: 'current' (a pair's ◐ after it); the default's own picture chosen by its name is the default, current"
eq "$(plain | grep -c 'current')" 1 "nothing chosen yet: the default, current"
echo pack:ink-ridges-night >"$STATE/wallpaper-dark"; kawa-wallpaper --tui "$TMP/out"
eq "$(plain | grep -c 'current')" 1; has "$(plain | head -n1)" "ink-ridges-night"; has "$(plain | head -n1)" "current · default"
has "$(args_of fzf "$(ncalls fzf)")" "load:pos(2)+" "the cursor on it"
echo pack:quay-night >"$STATE/wallpaper-dark"; kawa-wallpaper --tui "$TMP/out"
eq "$(plain | grep 'current' | sed 's/.*quay-night *//')" "current  $ICON_THEME" "a pack with a pair: current, its ◐ after it"
lacks "$(plain | head -n1)" "current"
rm -f "$STATE/wallpaper-dark"; kawa-wallpaper --tui "$TMP/out"
case_ "the window: the heading (壁, wallpaper, the stitch in edge2), the footer, no pointer glyph of its own"
a=$(args_of fzf "$(ncalls fzf)")
h=$(grep -A1 -x -- --header <<<"$a" | sed -n 2p; sed -n '/^--header=/p' <<<"$a")
has "$a" $'\e[38;5;20m壁'; has "$a" "wallpaper "$'\e[38;5;19m╌╌'
lacks "$a" "--pointer"; lacks "$a" "--border-label"
has "$a" "enter set"; has "$a" "esc close"
has "$a" "--with-nth=3.."

case_ "your own pictures with odd names: listed with their full path; tab and line break left out"
setup; picker
for n in "my photo.png" "ü日本 العربية.jpg" "it's \"quoted\".png" '$(touch pwned).png' '`touch pwned2`.png' \
         "-leading.png" "UPPER.PNG" $'tab\there.png' $'new\nline.png' "notes.txt" "no-ext"; do
  photo "$WP/$n" 2>/dev/null || { mkdir -p "$WP"; echo x >"$WP/$n"; }
done
kawa-wallpaper --tui "$TMP/out"
for n in "my photo.png" "ü日本 العربية.jpg" "it's \"quoted\".png" '$(touch pwned).png' '`touch pwned2`.png' "-leading.png" "UPPER.PNG"; do
  has "$(cut -f1 "$TMP/rows")" "$WP/$n"
  has "$(plain)" "  $ICON_FOLDER  $n"
done
lacks "$(rows)" "tab"; lacks "$(rows)" "line.png"; lacks "$(rows)" "notes.txt"; lacks "$(rows)" "no-ext"
eq "$(nrows)" 7
[[ ! -e $TMP/pwned && ! -e pwned && ! -e $TMP/pwned2 ]] && _ok || _no "a file name ran as a command"

case_ "1000 pictures of your own: all listed, quickly"
setup; picker
mkdir -p "$WP"; photo "$TMP/one.png"
for i in $(seq -w 1 1000); do ln "$TMP/one.png" "$WP/p$i.png"; done
start=$(date +%s%N)
kawa-wallpaper --tui "$TMP/out"
ms=$(( ($(date +%s%N) - start) / 1000000 ))
eq "$(nrows)" 1000
((ms < 10000)) && _ok || _no "the list took $ms ms"
eq "$(sed -n '1000p' "$TMP/rows" | cut -f1)" "$WP/p1000.png"

case_ "the cursor starts on the current choice"
FZF_PICK=esc kawa-wallpaper --tui "$TMP/out"
echo "$WP/p0500.png" >"$STATE/wallpaper-dark"
kawa-wallpaper --tui "$TMP/out"
has "$(args_of fzf "$(ncalls fzf)")" "load:pos(501)+unbind(load)" "(the switch row first; once the list has arrived, once only)"
lacks "$(args_of fzf "$(ncalls fzf)")" "start:pos(" "(start comes before the list: the cursor would land short)"
case_ "your own picture, shown now: 'current'"
eq "$(plain | grep -c 'current')" 1 "one row: $(plain | grep 'current')"
has "$(plain | grep 'current')" "p0500.png" "your own picture, shown now"

case_ "every 4 hours: the picker's first row is its switch (off until switched on), Enter turns it in place"
head -n1 "$TMP/all" | cut -f1 | grep -qx rotate && _ok || _no "the first row is not the switch"
has "$(head -n1 "$TMP/all" | cut -f3 | sed "s/\x1b\[[0-9;]*m//g")" "$ICON_BOX_OFF  a new one every 4 hours"
has "$(args_of fzf "$(ncalls fzf)")" "execute-silent("
rc 0 kawa-wallpaper --rotate toggle; eq "$(kawa-state get wallpaper-rotate)" on
has "$(kawa-wallpaper --rows | head -n1 | cut -f3 | sed "s/\x1b\[[0-9;]*m//g")" "$ICON_BOX_ON  a new one every 4 hours"
rc 0 kawa-wallpaper --rotate toggle; eq "$(kawa-state get wallpaper-rotate)" off
rc 2 kawa-wallpaper --rotate maybe

case_ "--next (its timer, every 4 hours): nothing while off; on, the pack's next picture after the one shown, round again at the end"
setup
art "$PACK/dark/ink-ridges-night.src" 1920x1080; art "$PACK/dark/moon-road-ink.src" 1920x1080; art "$PACK/light/ink-ridges.src" 1920x1080
kawa-state set wallpaper-rotate off; rm -f "$STATE/wallpaper-dark"
rc 0 kawa-wallpaper --next; [[ ! -e $STATE/wallpaper-dark ]] && _ok || _no "changed while off"
kawa-state set wallpaper-rotate on
rc 0 kawa-wallpaper --next; eq "$(cat "$STATE/wallpaper-dark")" pack:moon-road-ink "after the default: the next one fetched"
rc 0 kawa-wallpaper --next; eq "$(cat "$STATE/wallpaper-dark")" pack:ink-ridges-night "after the last: the first again"
eq "$(cat "$STATE/wallpaper-light")" pack:ink-ridges "a pair: both themes"
grep -q 'OnUnitActiveSec=4h' "$REPO/configs/home/.config/systemd/user/kawa-wallpaper-next.timer" && _ok || _no "the timer: not every 4 hours"
grep -q 'kawa-wallpaper-next.timer' "$REPO/configs/home/.config/dwl/autostart.sh" && _ok || _no "the timer is not started with the session"
kawa-state set wallpaper-rotate off

case_ "Super+W, Enter on an odd name: set exactly, in one frame (no fade, nothing in between)"
setup; picker
odd="$WP/\$(touch pwned) it's.png"; photo "$odd"
FZF_PICK="$odd" kawa-wallpaper; r=$?
eq "$r" 0
lacks "$(grep -v '^ *#' "$REPO/bin/kawa-wallpaper")" "kawa-veil"
eq "$(size_of "$(shown)")" 1920x1080
eq "$(cat "$STATE/wallpaper-dark")" "$odd"
[[ ! -e $TMP/pwned ]] && _ok || _no "the name ran as a command"

case_ "Esc, or the current one again: nothing changes"
reset_calls
FZF_PICK=esc kawa-wallpaper; r=$?
eq "$r" 0; eq "$(last)" 1
FZF_PICK="$odd" kawa-wallpaper
eq "$(last)" 1 "the same one: not drawn again"

case_ "Super+W again while the picker is open (kawa-term --float --once says 3): nothing"
stub kawa-term 'exit 3'; reset_calls
rc 0 kawa-wallpaper
not_called '^fzf'

# ── the preview pane ─────────────────────────────────────────────────────────
# (the picker's previews always have the cell the window measured: --tui exports it; fzf
# gives the pane's size)
export KAWA_CELL=12x26 FZF_PREVIEW_COLUMNS=78 FZF_PREVIEW_LINES=17
pane() {   # pane CHOICE — what the picker's preview command shows (fzf's own command line, run)
  local cmd; cmd=$(args_of fzf "$(ncalls fzf)" | sed -n 's/^--preview=//p')
  [[ -n $cmd ]] || { echo "no --preview"; return 1; }
  cmd=${cmd//\{1\}/$(printf %q "$1")}
  cmd=${cmd//\{2\}/$(printf %q "$(awk -F'\t' -v c="$1" '$1 == c { print $2 }' "$TMP/rows")")}
  bash -c "$cmd"
}
case_ "a preview: a sixel picture; broken or missing pictures just say 'no preview', quietly"
setup
photo "$WP/ok.png"
out=$(kawa-wallpaper --preview "$WP/ok.png" 2>"$TMP/err")
[[ $out == $'\eP'* ]] && _ok || _no "no sixel came out: ${out:0:40}"
eq "$(cat "$TMP/err")" ""
head -c 200 "$WP/ok.png" >"$WP/cut.png"; echo "not a picture" >"$WP/fake.jpg"
for f in "$WP/cut.png" "$WP/fake.jpg" "$WP/missing.png" pack:not-there ""; do
  out=$(kawa-wallpaper --preview "$f" 2>"$TMP/err")
  eq "$out" "  $ICON_PICTURE  no preview" "[$f]"
  eq "$(cat "$TMP/err")" "" "[$f]: nothing on stderr"
done
art "$PACK/dark/moon-road-ink.src" 1920x1080
out=$(kawa-wallpaper --preview pack:moon-road-ink 2>/dev/null); [[ $out == $'\eP'* ]] && _ok || _no "no pack preview"
out=$(FZF_PREVIEW_COLUMNS=1 FZF_PREVIEW_LINES=1 kawa-wallpaper --preview pack:moon-road-ink 2>"$TMP/err")
eq "$(cat "$TMP/err")" "" "a tiny pane: no error"
case_ "--preview notes the pane's size (the cache draws ahead for it)"
eq "$(cat "$PREVIEWS/geometry")" "12x26 78x17"
case_ "the preview's own size: a whole fraction of the screen, centred in the pane, clear of its last line"
f=$PREVIEWS/1920x1080-12x26-$GD/$(key_of moon-road-ink).78x17.six
[[ -s $f ]] && _ok || _no "not kept where the picker's command looks"
eq "$(head -c 40 "$f" | grep -ao '"1;1;[0-9]*;[0-9]*')" '"1;1;788;401' "640×360 (a third of 1080p) at 148,41 in a 936×442 pane"

case_ "in the picker (a cache hit): the preview is a cat of its sixel — no kawa-wallpaper run, under 100 ms"
setup; picker
# (the picker run from a copy of its own: its preview command names that copy, which can then
# be swapped for a stand-in that only says it ran)
mkdir -p "$TMP/kbin"; cp "$REPO/bin/kawa-wallpaper" "$TMP/kbin/"
art "$PACK/dark/ink-ridges-night.src" 960x540; art "$PACK/dark/moon-road-ink.src" 960x540
mkdir -p "$PREVIEWS"; echo "12x24 78x17" >"$PREVIEWS/geometry"
kawa-wallpaper --cache >/dev/null 2>&1
"$TMP/kbin/kawa-wallpaper" --tui "$TMP/out"
KAWA_CELL=12x24 kawa-wallpaper --preview pack:moon-road-ink >"$TMP/want"
printf '#!/bin/sh\necho RAN\n' >"$TMP/kbin/kawa-wallpaper"
s=$EPOCHREALTIME; out=$(pane pack:moon-road-ink); e=$EPOCHREALTIME
[[ $out == $'\eP'* ]] && _ok || _no "no sixel: ${out:0:40}"
lacks "$out" RAN "kawa-wallpaper ran: not a hit"
cmp -s <(printf '%s\n' "$out") "$TMP/want" && _ok || _no "not the same picture as --preview draws"
(( (${e/./} - ${s/./}) < 100000 )) && _ok || _no "took $(( (${e/./} - ${s/./}) / 1000 )) ms"
case_ "in the picker (a miss): --preview draws it"
rm -f "$PREVIEWS"/*/"$(key_of moon-road-ink)".*.six
eq "$(pane pack:moon-road-ink)" "RAN"
case_ "your own picture not read yet: --preview (which reads it); once read, the next picker opens on a hit"
cp "$REPO/bin/kawa-wallpaper" "$TMP/kbin/"; photo "$WP/mine.png"
"$TMP/kbin/kawa-wallpaper" --tui "$TMP/out"
eq "$(awk -F'\t' -v c="$WP/mine.png" '$1 == c { print $2 }' "$TMP/rows")" "" "no key yet"
KAWA_CELL=12x24 pane "$WP/mine.png" >/dev/null
"$TMP/kbin/kawa-wallpaper" --tui "$TMP/out"
k=$(awk -F'\t' -v c="$WP/mine.png" '$1 == c { print $2 }' "$TMP/rows")
[[ $k =~ ^mine\.[0-9a-f]{16}\.center$ ]] && _ok || _no "no key after it was read: [$k]"
[[ -s $PREVIEWS/1920x1080-12x24-$GD/$k.78x17.six ]] && _ok || _no "its preview not kept"

case_ "--warm (while the picker is open): every preview drawn ahead, nearest the cursor first"
setup
for n in a b c d e; do photo "$WP/$n.png"; done
mkdir -p "$PREVIEWS"; echo "12x26 78x17" >"$PREVIEWS/geometry"
printf '%s\0' "$WP/c.png" "$WP/d.png" "$WP/b.png" "$WP/e.png" "$WP/a.png" >"$TMP/order"
kawa-wallpaper --warm "$TMP/order"
eq "$(find "$PREVIEWS" -name '*.six' | wc -l)" 5 "the five pictures"
before=$(find "$PREVIEWS" -name '*.six' -printf '%f %T@\n' | sort)
kawa-wallpaper --preview "$WP/a.png" >/dev/null
eq "$(find "$PREVIEWS" -name '*.six' -printf '%f %T@\n' | sort)" "$before" "showing one draws nothing new: it was ready"
case_ "--warm waits for the pane's size (the first preview notes it); none for this cell: nothing"
echo "9x21 78x17" >"$PREVIEWS/geometry"; rm -f "$PREVIEWS"/*/*.six
rc 1 kawa-wallpaper --warm "$TMP/order"
eq "$(find "$PREVIEWS" -name '*.six' | wc -l)" 0

case_ "a preview killed half-way (fzf kills one you moved on from): its half-made file cleared next time"
setup
photo "$WP/a.png"; mkdir -p "$PREVIEWS/x"; echo "12x26 78x17" >"$PREVIEWS/geometry"
: >"$PREVIEWS/x/abc.six.4242.tmp"; touch -d '5 minutes ago' "$PREVIEWS/x/abc.six.4242.tmp"
: >"$PREVIEWS/x/def.six.4343.tmp"                    # (one being drawn right now: left alone)
printf '%s\0' "$WP/a.png" >"$TMP/order"
kawa-wallpaper --warm "$TMP/order"
[[ ! -e $PREVIEWS/x/abc.six.4242.tmp ]] && _ok || _no "the half-made preview stayed"
[[ -e $PREVIEWS/x/def.six.4343.tmp ]] && _ok || _no "a preview being drawn was removed"

quiet
done_
