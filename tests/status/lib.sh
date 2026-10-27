#!/usr/bin/env bash
# tests/status/lib.sh — what the bar's status and sound tests share, on top of the harness:
# a fake PipeWire (fake_pw.py: wpctl and pw-dump over one JSON machine), a notice daemon that
# hands out ids like mako, the panel's fifo that the level display (kawa-osd) asks, JSON and
# width checks.
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

# The level display (kawa-osd) asks the running panel through its fifo, one line a request:
# `level ICON PCT [off]` in $XDG_RUNTIME_DIR/kawa-panel.in. No notice, no process: the tests
# stand in for the panel by holding that fifo themselves.
#
# osd_panel — the panel running: the fifo the real kawa-panel makes (mode 600), held open here
# read and write, as the panel holds it. A request waits in it until osd/osd_raw reads it, so
# nothing is lost or merged and there is nothing to wait for, kill or clean up (the descriptor
# goes with the shell). Call it in every fresh sandbox (the old fifo went with the old one);
# `rm -f "$XDG_RUNTIME_DIR/kawa-panel.in"` afterwards is "no panel running".
osd_panel() {
  [[ -n ${OSD_FD:-} ]] && { exec {OSD_FD}>&-; OSD_FD=""; }    # (the previous one's, or this sandbox's own: a panel restarted)
  OSD_LOG=$TMP/osd.log; : >"$OSD_LOG"
  rm -f -- "$XDG_RUNTIME_DIR/kawa-panel.in"
  mkfifo -m 600 -- "$XDG_RUNTIME_DIR/kawa-panel.in" && exec {OSD_FD}<>"$XDG_RUNTIME_DIR/kawa-panel.in"
}
# osd_raw — every request made of the panel so far, as kawa-osd wrote it, one line each, oldest
# first. What waits in the fifo is read into a log first (once), so this and osd may be asked
# as often as you like, from a pipeline or not. Nothing without osd_panel. A request that came
# without its newline would leave a reader waiting for ever: one second, then it is logged with
# " (no newline)" after it, for the test to fail on.
osd_raw() {
  local l r
  [[ -n ${OSD_FD:-} ]] || return 0
  while read -r -t 0 -u "$OSD_FD"; do
    IFS= read -r -t 1 -u "$OSD_FD" l; r=$?
    ((r)) && [[ -z $l ]] && break
    ((r)) && l+=' (no newline)'
    printf '%s\n' "$l" >>"$OSD_LOG"
  done
  cat -- "$OSD_LOG" 2>/dev/null
}
# osd [N] — the Nth-last request (default the last) as "ICON|PCT|off", or "ICON|PCT|" when it is
# not off; nothing when there is no such request. A line that is not `level ICON PCT [off]`
# comes back as "bad request|LINE|", for the test to fail on.
osd() {
  local n=${1:-1} all=() l
  [[ $n =~ ^[1-9][0-9]*$ ]] || return 0
  mapfile -t all < <(osd_raw)
  ((n <= ${#all[@]})) || return 0
  l=${all[${#all[@]} - n]}
  if [[ $l =~ ^level\ ([^[:space:]]+)\ ([0-9]+)(\ off)?$ ]]; then
    printf '%s|%s|%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]# }"
  else
    printf 'bad request|%s|\n' "$l"
  fi
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
