#!/usr/bin/env bash
# tools/away.sh — the round's heavy or visible work (a VM proof that downloads gigabytes, an apply,
# a session restart, the saver's long-absence test) waits until the owner is away from the PC,
# then runs. Away: no key, click or move for MIN minutes — dwl's own count (ext-idle-notify,
# through swayidle, read only: nothing is drawn, nothing locks), which a playing video's idle
# inhibitor holds back — and at that moment no microphone running (a call: PipeWire's source node
# in use; the bar's visualizer listens to a sink's monitor, not a source) and no game (Steam's
# reaper). His session found as the bar's (waybar's environment); a new session (a login, a
# restart) is followed. Logs one line a change to stderr.
#   bash tools/away.sh [--min M] [--hours H] -- COMMAND [ARG…]
#     --min    minutes without input (default 30)
#     --hours  the longest it waits for that (default 20): then it gives up (exit 3)
# Exit: COMMAND's status · 3 never away within H hours · 2 misuse.
set -uo pipefail
min=30 hours=20
while (($#)); do
  case $1 in
    --min) min=${2:?}; shift 2 ;;
    --hours) hours=${2:?}; shift 2 ;;
    --) shift; break ;;
    *) echo "usage: away.sh [--min M] [--hours H] -- COMMAND [ARG…]" >&2; exit 2 ;;
  esac
done
(($#)) || { echo "away.sh: no command" >&2; exit 2; }
say() { printf '%s away.sh: %s\n' "$(date +%T)" "$*" >&2; }
flag=$(mktemp -u "${TMPDIR:-/tmp}/away.XXXXXX")
probe="" bar=""
trap '[[ -n $probe ]] && kill "$probe" 2>/dev/null; rm -f "$flag"' EXIT
mic_open() {   # (his PipeWire: the session's runtime dir, exported below)
  pw-dump 2>/dev/null | jq -e 'any(.[]; .type == "PipeWire:Interface:Node"
    and ((.info.props["media.class"] // "") | startswith("Audio/Source")) and .info.state == "running")' >/dev/null
}
end=$((SECONDS + hours * 3600))
while ((SECONDS < end)); do
  b=$(pgrep -x waybar | sed -n 1p)
  if [[ $b != "$bar" ]]; then   # (his session: first seen, or new)
    [[ -n $probe ]] && kill "$probe" 2>/dev/null
    probe="" bar=$b
    rm -f "$flag"
    if [[ -n $bar ]]; then
      while IFS= read -r -d '' kv; do
        case $kv in WAYLAND_DISPLAY=* | XDG_RUNTIME_DIR=* | DBUS_SESSION_BUS_ADDRESS=*) export "${kv?}" ;; esac
      done </proc/"$bar"/environ
      swayidle timeout $((min * 60)) "touch '$flag'" resume "rm -f '$flag'" >/dev/null 2>&1 &
      probe=$!
      say "watching his session (waybar $bar): $min min without input"
    fi
  fi
  if [[ -e $flag ]] && ! mic_open && ! pgrep -x reaper >/dev/null; then
    say "away: $min min without input, no call, no game — running: $*"
    kill "$probe" 2>/dev/null
    probe=""
    "$@"
    exit
  fi
  sleep 30
done
say "never away within $hours h"
exit 3
