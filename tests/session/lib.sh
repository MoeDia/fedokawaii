# shellcheck shell=bash
# tests/session/lib.sh — what the session tests share: dwl's status stream (recorded from the
# real patched dwl 0.9, or written here line by line the way its printstatus() prints it), a
# stand-in waybar that counts the signals it is poked with, and checks on the bar's files.
# Sourced after tests/lib/harness.sh. (The helpers that poll fork nothing: the sandbox is slow
# at starting programs when other work runs, and these loops run hundreds of times.)
SD=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BG_PIDS=()

# session_sandbox — a sandbox in which kawa-dwlstatus is the repository's own, waybar is not
# running (pgrep finds only the stand-in: never another session's real waybar), and every
# process a test starts in the background ends with the test
session_sandbox() {
  sandbox
  rm -f "$STUBS/kawa-dwlstatus"
  trap 'kill_bg; [[ -n $TMP ]] && rm -rf "$TMP"; [[ -n ${LOCDIR:-} ]] && rm -rf "$LOCDIR"' EXIT
  BAR=$XDG_RUNTIME_DIR/dwl-bar WBLOG=$TMP/waybar.log WBPID=""
  : >"$WBLOG"
  # pgrep -nxu UID waybar → the stand-in's PID while it runs; nothing else is ever found
  stub pgrep 'case " $* " in *" waybar "*) p=$(cat "'"$TMP"'/waybar.pid" 2>/dev/null) && [ -n "$p" ] && kill -0 "$p" 2>/dev/null && echo "$p" && exit 0 ;; esac
exit 1'
  export XKB_DEFAULT_LAYOUT=us,ara
  mkfifo "$TMP/.nap"; exec 5<>"$TMP/.nap"     # nap: a timed read nobody answers
}
kill_bg() { local p; for p in "${BG_PIDS[@]}"; do kill "$p" 2>/dev/null; done; BG_PIDS=(); }
nap() { read -rt "$1" -u 5 _; }                # nap SECONDS — a pause without starting sleep
count() {   # count VAR WORD — how many lines of the stand-in's log are WORD
  local -a L; local l c=0
  mapfile -t L <"$WBLOG"; for l in "${L[@]}"; do [[ $l == "$2" ]] && ((c++)); done
  printf -v "$1" '%s' "$c"
}

# waybar_up [catch|ignore] — the stand-in waybar, ready for signals once this returns
waybar_up() {
  local i n m; count n ready
  # (it keeps none of the test's pipes open: a reader waiting for their end would wait forever)
  python3 -I "$SD/fake_waybar.py" "$WBLOG" "${1:-catch}" 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&- &
  WBPID=$!; BG_PIDS+=("$WBPID"); echo "$WBPID" >"$TMP/waybar.pid"
  for ((i = 0; i < 1000; i++)); do count m ready; ((m > n)) && return 0; nap 0.01; done
  echo "lib: the stand-in waybar did not start" >&2; return 1
}
waybar_down() { [[ -n $WBPID ]] && kill "$WBPID" 2>/dev/null; wait "$WBPID" 2>/dev/null; WBPID=""; rm -f "$TMP/waybar.pid"; }

# pokes — the signals waybar got since the last call, sorted: "8 9 10" (empty: none)
pokes() {
  local n m i l f=0 out="" ; local -a L cnt=()
  count n flush
  kill -s RTMAX "$WBPID" 2>/dev/null || { echo "lib: waybar is gone" >&2; return 1; }
  for ((i = 0; i < 1000; i++)); do count m flush; ((m > n)) && break; nap 0.01; done
  mapfile -t L <"$WBLOG"
  for l in "${L[@]}"; do
    if [[ $l == flush ]]; then ((f++)); elif ((f == n)) && [[ $l =~ ^[0-9]+$ ]]; then ((cnt[l]++)); fi
  done
  for i in "${!cnt[@]}"; do for ((m = 0; m < cnt[i]; m++)); do out+="$i "; done; done   # (indices come sorted)
  printf '%s' "${out% }"
}

# block MON SELMON OCC SEL URG LAYOUT KB [TITLE] — one monitor's lines as dwl prints them
# (src/dwl/dwl.patch printstatus: title, appid, fullscreen, floating, selmon, tags, layout,
# kblayout); with no TITLE the monitor has no focused window
block() {
  local mon=$1 sel=$2 occ=$3 tags=$4 urg=$5 lt=$6 kb=$7
  if (($# >= 8)); then
    printf '%s title %s\n%s appid foot\n%s fullscreen 0\n%s floating 0\n' "$mon" "$8" "$mon" "$mon" "$mon"
  else
    printf '%s title \n%s appid \n%s fullscreen \n%s floating \n' "$mon" "$mon" "$mon" "$mon"
  fi
  printf '%s selmon %s\n%s tags %s %s %s %s\n%s layout %s\n%s kblayout %s\n' \
    "$mon" "$sel" "$mon" "$occ" "$tags" "$((occ & tags))" "$urg" "$mon" "$lt" "$mon" "$kb"
}

# status FILE… — kawa-dwlstatus reads these, one after the other, as one stream
status() { cat "$@" | kawa-dwlstatus; }

# rd VAR [MON/]FILE — a file the bar reads, into VAR ("" when missing); bar [MON/]FILE prints it
rd() { local l=""; { IFS= read -r l <"$BAR/$2.json"; } 2>/dev/null; printf -v "$1" '%s' "$l"; }
bar() { local b; rd b "$1"; printf '%s' "$b"; }
# jtext [MON/]FILE — the text waybar gets from one of the bar's files (its JSON string decoded:
# kawa-dwlstatus escapes only \ and "; json_ok checks the files with a real JSON parser)
jtext() {
  local j; rd j "$1"; j=${j#'{"text":"'}; j=${j%'"}'}; j=${j%'","class":'*}
  j=${j//\\\\/$'\x01'}; j=${j//\\\"/\"}; printf '%s\n' "${j//$'\x01'/\\}"
}
# tagrow [MON/] — the nine workspaces as the bar shows them: "1:sel 2:occ 3:emp 4:- …" (- hidden;
# each is its kanji numeral on the bar)
KANJI_DIGITS=(一 二 三 四 五 六 七 八 九)
tagrow() {
  local i j c out=""
  for i in 1 2 3 4 5 6 7 8 9; do
    rd j "${1:-}tag$i"
    if [[ $j == '{"text":""}' ]]; then c=-
    elif [[ $j =~ \"class\":\[\"tag\",\"([a-z]+)\"\] && $j == *"\"text\":\"${KANJI_DIGITS[i - 1]}\""* ]]; then c=${BASH_REMATCH[1]:0:3}
    else c="?"; fi
    out+="$i:$c "
  done
  printf '%s' "${out% }"
}
# json_ok — every file in the bar's folder parses as JSON with a string "text" (and a string or
# list "class"), as waybar's custom modules need; no half-written .tmp file is left behind
json_ok() {
  python3 -I - "$BAR" <<'EOF'
import json, pathlib, sys
bad = []
for f in sorted(pathlib.Path(sys.argv[1]).rglob("*")):
    if f.is_dir():
        continue
    if f.suffix != ".json":
        bad.append(f"{f.name}: not a .json file"); continue
    raw = f.read_bytes()
    try:
        j = json.loads(raw.decode("utf-8"))
        assert isinstance(j, dict) and isinstance(j.get("text"), str), "no text"
        assert set(j) <= {"text", "class"}, f"keys {sorted(j)}"
        c = j.get("class", "")
        assert isinstance(c, str) or (isinstance(c, list) and all(isinstance(x, str) for x in c)), "class"
        assert raw.count(b"\n") == 1 and raw.endswith(b"\n"), "not one line"
    except Exception as e:
        bad.append(f"{f.relative_to(sys.argv[1])}: {e}: {raw[:120]!r}")
print("\n".join(bad))
EOF
}
