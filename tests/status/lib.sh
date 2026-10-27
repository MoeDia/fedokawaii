#!/usr/bin/env bash
# tests/status/lib.sh — what the bar's status and sound tests share, on top of the harness:
# a fake PipeWire (fake_pw.py: wpctl and pw-dump over one JSON machine), a notice daemon that
# hands out ids like mako, JSON and width checks.
# shellcheck source=../lib/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"
SD=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# pw_world — the fixture machine (fixtures/pw.json): a sound card's analog output and input,
# the graphics card's HDMI output, and the two "Share" loopbacks of 60-share.conf
pw_world() {
  cp "$SD/fixtures/pw.json" "$TMP/pw.json"
  export FAKE_PW=$TMP/pw.json
  stub wpctl 'exec python3 -I '"$SD"'/fake_pw.py wpctl "$@"'
  stub pw-dump 'exec python3 -I '"$SD"'/fake_pw.py pw-dump "$@"'
  stub pw-metadata 'exec python3 -I '"$SD"'/fake_pw.py pw-metadata "$@"'
}
# pw_edit PYTHON — change the machine: `st` is the state, `node(name)` finds a node
pw_edit() {
  python3 -I - "$FAKE_PW" "$1" <<'EOF'
import json, sys
f, code = sys.argv[1:]
st = json.load(open(f))
def node(name): return next(n for n in st["nodes"] if n["name"] == name or n.get("desc") == name)
exec(code)
json.dump(st, open(f, "w"), ensure_ascii=False)
EOF
}
# pw_vol sink|source — the default device's level as wpctl prints it ("0.40", "1.00 [MUTED]")
pw_vol() {
  local w; w=$(wpctl get-volume "@DEFAULT_AUDIO_${1^^}@" 2>/dev/null); w=${w#Volume: }; printf '%s' "$w"
}
# shellcheck disable=SC2034  # (the test files use it)
BT='{"id": 81, "class": "Audio/Sink", "name": "bluez_output.AC_80_0A_12_34_56.1", "desc": "WH-1000XM4", "prio": 1010, "vol": 0.35, "props": {"device.api": "bluez5"}}'

# notices: mako's way with ids — a new notice gets the next id; -r ID of a notice still
# shown keeps that id, -r of one long gone (mako restarted) gets a new one; -p prints the id.
# $NOTIFY_DOWN set: no daemon (notify-send fails, but prints an id all the same, as
# libnotify 0.8 does). $NOTIFY_SLOW: seconds each notice takes.
notices() {
  export NOTIFY_STATE=$TMP/notify; mkdir -p "$NOTIFY_STATE"; : >"$NOTIFY_STATE/live"; echo 0 >"$NOTIFY_STATE/n"
  stub notify-send 'exec bash '"$SD"'/fake_notify "$@"'
}

# json_lines TEXT — every line parses as JSON (what waybar reads)
json_lines() {
  local bad
  bad=$(printf '%s\n' "$1" | python3 -I -c '
import json, sys
for i, l in enumerate(sys.stdin.read().splitlines(), 1):
    try: json.loads(l)
    except Exception as e: print(f"line {i}: {e}: {l[:200]}")')
  [[ -z $bad ]] && _ok || _no "${2:-not JSON} — $bad"
}
# cols TEXT — the menu columns of each line of TEXT (width.py), one per line
cols() { printf '%s\n' "$1" | python3 -I "$SD/width.py" "$REPO"; }
# fits TEXT N [MSG] — every line of TEXT takes at most N columns, and is valid UTF-8
fits() {
  local w over
  w=$(cols "$1")
  over=$(paste <(printf '%s\n' "$w") <(printf '%s\n' "$1") | awk -F'\t' -v n="$2" '$1 == "bad" || $1 + 0 > n + 0.001')
  [[ -z $over ]] && _ok || _no "${3:-wider than $2 columns}: $over"
}
# text_of JSON — the "text" of a waybar line, decoded
text_of() { python3 -I -c 'import json,sys; print(json.loads(sys.argv[1]).get("text",""))' "$1"; }
# waitfor SECONDS CMD… — poll until CMD succeeds (0.05 s steps); fails when time runs out
waitfor() {
  local i n=$(( $1 * 20 )); shift
  for ((i = 0; i < n; i++)); do "$@" && return 0; /bin/sleep 0.05; done
  return 1
}

# osd [N] — the Nth-last level display shown (default the last), as "ID|ICON LABEL|VALUE|LIT/12":
# VALUE is the number or "off", LIT the meter's lit squares (hollow ones too, while muted);
# the body must be well-formed Pango markup, or "bad markup" comes back
osd() {
  local l; l=$(grep '^NOTICE [0-9]* osd ' "$NOTIFY_STATE/log" 2>/dev/null | tail -n "${1:-1}" | head -n 1)
  [[ -n $l ]] || return 0
  python3 -I - "$l" <<'EOF2'
import sys, xml.dom.minidom as X
line = sys.argv[1]
head, summary, body = line.split(" | ", 2)
nid = head.split()[1]
try:
    d = X.parseString("<m>" + body + "</m>").documentElement
except Exception:
    print(f"{nid}|{summary}|bad markup|"); sys.exit()
def text(n): return "".join(c.data if c.nodeType == c.TEXT_NODE else text(c) for c in n.childNodes)
# kawa-osd's row: one span (the 24 px row) holding the glyph, the name, the slider (the span
# in the icon font: the fill, the knob, the track, its 2 px of air) and the value (the last).
# The slider read back into pixels from icons.sh's lv-* parts: where its knob starts, and its
# whole width ("131/192")
import os, re
sh = open(os.path.expanduser("~/.config/fedokawaii/icons.sh")).read()
px = {}
for name, esc in re.findall(r"^ICON_(LV_[A-Z]+(?:_\d+)?|GAP1|GAP)='?\$'([^']*)'", sh, re.M):
    ch = bytes(int(h, 16) for h in re.findall(r"\\x([0-9a-f]{2})", esc)).decode()
    n = name.rsplit("_", 1)
    px[ch] = 1 if name in ("GAP1", "LV_TICK") else 2 if name == "GAP" else 4 if name == "LV_KNOB" else int(n[1])
row = [c for c in d.childNodes if c.nodeType == c.ELEMENT_NODE][0]
spans = [c for c in row.childNodes if c.nodeType == c.ELEMENT_NODE]
slider = [s for s in spans if s.getAttribute("font").startswith("Sumi Icons ")][0]
parts = [c for c in slider.childNodes if c.nodeType == c.ELEMENT_NODE]
w = lambda t: sum(px.get(ch, 1000) for ch in t)
knob = w(text(parts[0])); total = w(text(slider))
value = text(spans[-1]).strip()
print(f"{nid}|{summary}|{value}|{knob}/{total}")
EOF2
}

# box — sandbox, and also the compiled locales (locale_ok) go when the test file ends
LOCDIR=""
box() { sandbox; trap '[[ -n $TMP ]] && rm -rf "$TMP"; [[ -n $LOCDIR ]] && rm -rf "$LOCDIR"' EXIT; }
# locale_ok NAME — NAME (tr_TR.UTF-8, ar_EG.UTF-8) can be used: installed, or compiled from
# glibc's sources once per test file (LOCPATH points there). Fails if neither can be done:
# the caller then skips that check and says so.
locale_ok() {
  local l=$1 c=${1%%.*}
  locale -a 2>/dev/null | grep -qix "$c.utf8" && return 0
  [[ -z $LOCDIR ]] && LOCDIR=$(mktemp -d "${TMPDIR:-/tmp}/kawa-test-loc.XXXXXX")
  if [[ ! -d $LOCDIR/$l ]]; then
    [[ -e /usr/share/i18n/locales/$c ]] && command -v localedef >/dev/null || return 1
    localedef -i "$c" -f UTF-8 "$LOCDIR/$l" >/dev/null 2>&1
    [[ -d $LOCDIR/$l ]] || return 1
  fi
  export LOCPATH=$LOCDIR
}
skip() { printf '  (skipped: %s — %s)\n' "${H_CASE:-?}" "$1"; }
