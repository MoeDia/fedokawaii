#!/usr/bin/env bash
# tools/fixer-frames.sh MODEL [ARGS…] — does the local AI fixer make the desktop stutter? dwl's own
# frame log (tools/framestat.py, never a recorder) of a headless dwl on the same card, a terminal
# scrolling flat out in it: first the card as it is, then with the model generating (at the low
# priority it always runs at: system/kawa-fixer). ARGS go to llama-server (--reasoning-budget …).
# Nothing of the session is touched (tools/hl-dwl.sh: its own runtime dir, no input devices).
#   Env: FRAMES_S the seconds of each run (30) · D the folder for the logs (a temp one)
# Exit: 0 both runs measured · 2 misuse or a run that could not start
set -u
R=$(cd "$(dirname "$0")/.." && pwd)
model=${1:?usage: bash tools/fixer-frames.sh MODEL [ARGS…]}; shift
secs=${FRAMES_S:-30} D=${D:-$(mktemp -d /tmp/fixer-frames.XXXXXX)}
mkdir -p "$D"
inner=$D/inner.sh
cat >"$inner" <<EOF
foot -e sh -c 'i=0; while :; do i=\$((i + 1)); echo "\$i \$(date +%N) the quick brown fox jumps over the lazy dog"; done' &
sleep $secs
EOF
run() { bash "$R/tools/hl-dwl.sh" "$inner" --dwl /usr/local/bin/dwl --time $((secs + 20)) --keep "$D/$1" >"$D/$1.out" 2>&1
        [[ -s $D/$1/frames.log ]] || { echo "fixer-frames: no frame log in the $1 run: $(tail -n2 "$D/$1.out")" >&2; exit 2; }
        python3 -B -I "$R/tools/framestat.py" "$D/$1/frames.log" --hz 144 >"$D/$1.txt"; }
echo "== the card as it is"; run base; cat "$D/base.txt"
sock=$D/server.lnk
python3 -B -I "$R/system/kawa-fixer" serve --sock "$sock" --model "$model" --ctx 16384 --log "$D/server.log" -- "$@" &
srv=$!
trap 'kill "$srv" 2>/dev/null; wait "$srv" 2>/dev/null' EXIT
for _ in $(seq 240); do curl -fsS -m 2 --unix-socket "$sock" http://fixer/health >/dev/null 2>&1 && break; sleep 1; done
curl -fsS -m 2 --unix-socket "$sock" http://fixer/health >/dev/null 2>&1 || { echo "fixer-frames: the model did not load" >&2; exit 2; }
# (it generates for the whole run: long answers, one after another, a long prompt now and then)
( while :; do
    curl -fsS -m 120 --unix-socket "$sock" http://fixer/v1/chat/completions -H 'Content-Type: application/json' \
      -d "{\"messages\":[{\"role\":\"user\",\"content\":\"Write a very long story about a ronin and a shrine priest. $(head -c 6000 /usr/share/doc/foot/CHANGELOG.md | tr -cd 'a-zA-Z ' )\"}],\"max_tokens\":1500,\"cache_prompt\":false}" >/dev/null 2>&1 || sleep 1
  done ) &
gen=$!
trap 'kill "$gen" 2>/dev/null; kill "$srv" 2>/dev/null; wait "$srv" 2>/dev/null' EXIT
sleep 5
echo "== the model generating"; run model; cat "$D/model.txt"
echo "logs: $D"
