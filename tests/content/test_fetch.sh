#!/usr/bin/env bash
# tests/content/test_fetch.sh — fetch, the system summary, in a terminal of its own from 20 to
# 300 columns: the picture beside the facts only where both fit, never a wrapped line; its ten
# pictures checked pixel by pixel against the desktop's palette; odd facts (no os-release, a
# long host name, single quotes, a fresh boot, a day's uptime); misuse. The machine's facts
# come from a made-up root: fetch is run as a copy reading its files there.
. "$(dirname "$0")/lib.sh"

setup() {   # setup — a sandbox and a made-up machine in $R (fetch's copy: $TMP/fetch)
  sandbox
  R=$TMP/root; mkdir -p "$R/etc" "$R/usr/lib" "$R/proc/sys/kernel"
  printf 'NAME="Fedora Linux"\nVERSION="44 (Forty Four)"\nID=fedora\nVERSION_ID=44\nPRETTY_NAME="Fedora Linux 44 (Forty Four)"\n' >"$R/usr/lib/os-release"
  ln -s ../usr/lib/os-release "$R/etc/os-release"
  echo 6.17.1-300.fc44.x86_64 >"$R/proc/sys/kernel/osrelease"
  echo fedora >"$R/proc/sys/kernel/hostname"
  echo "11523.47 40000.00" >"$R/proc/uptime"                     # 3h 12m
  printf 'MemTotal:       16252928 kB\nMemFree:         9000000 kB\nMemAvailable:   12897484 kB\n' >"$R/proc/meminfo"
  # the copy: every file fetch reads, read under $R — and nothing else read from / at all
  sed -e "s#/etc/os-release#$R/etc/os-release#g" \
      -e "s#/proc/#$R/proc/#g" "$REPO/bin/fetch" >"$TMP/fetch"
  chmod +x "$TMP/fetch"
  export USER=kawau XDG_SESSION_DESKTOP=dwl TERM=foot TERM_PROGRAM=
  unset COLORTERM
}
F() { "$TMP/fetch" "$@"; }
# fetch in a terminal COLS wide: its lines, colours gone, one per line (no CR)
at() { local c=$1; shift; tty_run "$c" "$TMP/fetch" "$@" | tr -d '\r' | sed 's/\x1b\[[0-9;]*m//g'; }
# the widest line, in columns (the Sumi icons are one column to the terminal; the picture's
# half blocks one each)
widest() { python3 -I -c 'import sys, unicodedata
print(max([sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in l) for l in sys.stdin.read().split("\n")] or [0]))'; }
has_picture() { grep -q '[▀▄]' <<<"$1"; }

case_ "the copy reads only the made-up machine (fetch reads nothing else from /)"
setup
eq "$(grep -c "$R" "$TMP/fetch")" "$(grep -cE '/etc/os-release|/proc/' "$REPO/bin/fetch")"
eq "$(grep -oE '<[[:space:]]*/[^ ;)]+' "$TMP/fetch" | grep -v "^<$R/")" "" "a file read from / that the test does not stand in for"

# ── the facts ────────────────────────────────────────────────────────────────
case_ "the facts: you@the host (no spaces), the system, the kernel, the uptime, the session, bash, memory, the colours"
setup
out=$(F neko | sed 's/\x1b\[[0-9;]*m//g')
has "$out" "kawau@fedora"; lacks "$out" "kawau @"; has "$out" "fedora 44"; has "$out" " 6.17.1"
has "$out" "3h 12m"; has "$out" "dwl · foot"; has "$out" "bash ${BASH_VERSION%%(*}"
has "$out" "3.2 / 15.5 GiB"; has "$out" "● ● ● ● ● ● ● ●"
eq "$(F neko | grep -c .)" 8 "eight lines between two blank ones"
case_ "the desktop's icons in foot, none in another terminal"
. "$HOME/.config/fedokawaii/icons.sh"
has "$(F neko)" "$ICON_USER"
lacks "$(TERM=xterm-256color F neko)" "$ICON_USER"
case_ "uptime: minutes after a fresh boot, days after a long one"
echo "59.9 1.0" >"$R/proc/uptime"; has "$(F neko | sed 's/\x1b\[[0-9;]*m//g')" " 0m"
echo "90061.0 1.0" >"$R/proc/uptime"; has "$(F neko | sed 's/\x1b\[[0-9;]*m//g')" " 1d 1h 1m"
echo "86460.0 1.0" >"$R/proc/uptime"; has "$(F neko | sed 's/\x1b\[[0-9;]*m//g')" " 1d 1m"

case_ "os-release: quotes of either kind, a field missing (NAME's own default: Linux)"
setup
printf "NAME='Fedora Linux'\nVERSION_ID='44'\n" >"$R/usr/lib/os-release"
out=$(F neko 2>&1 | sed 's/\x1b\[[0-9;]*m//g'); has "$out" " fedora 44"; lacks "$out" "'"
printf 'NAME="Fedora Linux"\n' >"$R/usr/lib/os-release"
out=$(F neko 2>&1 | sed 's/\x1b\[[0-9;]*m//g'); has "$out" " fedora"$'\n' "no version: no trailing space"
printf 'VERSION_ID=45\n' >"$R/usr/lib/os-release"
out=$(F neko 2>&1 | sed 's/\x1b\[[0-9;]*m//g'); has "$out" " linux 45"

case_ "no USER, no session (a TTY, ssh): the rest still there"
setup; out=$(env -u USER -u XDG_SESSION_DESKTOP "$TMP/fetch" neko | sed 's/\x1b\[[0-9;]*m//g')
has "$out" "?@fedora"; has "$out" "tty · foot"

# ── the width ────────────────────────────────────────────────────────────────
# the facts here are 18 columns at most (+1 for an icon drawn two wide): the picture needs
# 2 + 20 + 3 + 18 + 1 = 44 columns → beside them from 43 (an icon may spill into the last)
case_ "20 to 300 columns: never a line wider than the terminal; the picture only where it fits"
setup
for c in 20 25 30 35 40 41 42 43 44 50 60 80 100 120 200 300; do
  out=$(at "$c" neko)
  w=$(widest <<<"$out")
  ((w <= c)) && _ok || _no "$c columns: a line of $w"
  if ((c >= 43)); then has_picture "$out" && _ok || _no "$c columns: no picture"
  else has_picture "$out" && _no "$c columns: the picture (it would wrap)" || _ok; fi
done
case_ "under 42 columns: the facts alone, all eight"
out=$(at 41 neko); eq "$(grep -c . <<<"$out")" 8
case_ "a long host name: the picture gives way sooner, still nothing wraps"
echo "a-really-quite-long-hostname.example" >"$R/proc/sys/kernel/hostname"
for c in 60 70 80; do
  out=$(at "$c" neko); w=$(widest <<<"$out")
  ((w <= c)) && _ok || _no "$c columns: a line of $w"
done
has_picture "$(at 60 neko)" && _no "60 columns: the picture beside a 49-column fact" || _ok
has_picture "$(at 80 neko)" && _ok || _no "80 columns: no picture"
case_ "piped (fetch | less -R): the picture stays (the width is not known)"
setup; has_picture "$(F neko)" && _ok || _no "no picture when piped"
case_ "a terminal without 24-bit colour: the facts alone; COLORTERM=truecolor: the picture"
has_picture "$(TERM=xterm-256color F neko)" && _no "a picture in 256 colours" || _ok
has_picture "$(TERM=xterm-256color COLORTERM=truecolor F neko)" && _ok || _no "no picture with COLORTERM"

# ── the pictures ─────────────────────────────────────────────────────────────
case_ "every picture: 20 × 16 pixels, every letter in its palette, every colour the desktop's own"
python3 -I - "$REPO/bin/fetch" "$REPO/tools/wada-palette.py" <<'EOF' >"$TMP/art.txt"
import importlib.util, re, sys
src = open(sys.argv[1]).read()
spec = importlib.util.spec_from_file_location("wp", sys.argv[2]); wp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wp)
own = set(wp.W.values())                  # (the desktop's own: Wada's swatches and every token made of them)
def add(v):
    if isinstance(v, str) and re.fullmatch(r"[0-9a-f]{6}", v): own.add(v)
    elif isinstance(v, tuple) and len(v) in (3, 4) and all(isinstance(x, int) for x in v): own.add("%02x%02x%02x" % v[:3])
    elif isinstance(v, (tuple, list)): [add(x) for x in v]
    elif isinstance(v, dict): [add(x) for x in v.values()]
add(wp.palette())
names = re.search(r"^NAMES=\(([^)]*)\)", src, re.M).group(1).split()
arts = dict(re.findall(r"^ART_(\w+)=\(\n(.*?)\n\)", src, re.M | re.S))
print("names", " ".join(sorted(names)) == " ".join(sorted(arts)))
for n in names:
    rows = re.findall(r'"([^"]*)"', arts[n])
    pal = dict(kv.split("=") for kv in rows[0].split())
    grid = rows[1:]
    bad = [c for r in grid for c in r if c != "." and c not in pal]
    foreign = [v for v in pal.values() if v.lower() not in own]
    print(n, len(grid), {len(r) for r in grid} == {20}, not bad, foreign or "ok")
EOF
has "$(cat "$TMP/art.txt")" "names True" "NAMES and the ART_ arrays list the same ten"
eq "$(grep -cE '^[a-z]+ 16 True True ok$' "$TMP/art.txt")" 10 "$(grep -vE ' 16 True True ok$|^names' "$TMP/art.txt" | tr '\n' ' ')"
case_ "each picture drawn: 8 lines of 20 cells, two pixels per cell in 24-bit colour"
for n in neko daruma torii pc fuji onigiri chochin cassette kitsune ramen; do
  out=$(F "$n")
  eq "$(grep -c $'\e\\[0;38;2;\\|\e\\[38;2;' <<<"$out")" 8 "$n"
  lacks "$out" "38;2;;" "$n: a colour missing"
done
case_ "no name: one of the ten, every time (30 runs)"
bad=0; for _ in {1..30}; do [[ $(F | grep -c $'38;2;') == 8 ]] || bad=$((bad + 1)); done
eq "$bad" 0

case_ "misuse and help"
rc 2 F nyan; has "$(F nyan 2>&1)" "pictures are: neko daruma"
rc 2 F neko extra
rc 0 F --help; has "$(F --help)" "fetch NAME"

done_
