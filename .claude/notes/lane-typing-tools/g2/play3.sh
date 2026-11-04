export XDG_STATE_HOME=$HOME/.local/state
d="$XDG_STATE_HOME/fedokawaii/typing"
LIB=/home/dia/repos/fk-typing/configs/home/.local/lib/fedokawaii
python3 -IB /dev/shm/lane-typing/gal/state.py "$d" "$LIB"
T=$XDG_STATE_HOME/fedokawaii/typing-trace.json
footclient -a float -T typing -W 79x38 -- kawa-typing --seed 3 --trace "$T" --lesson speed.30.passage.1 >/dev/null 2>>"$KIT_OUT/err.log" &
nap 2
text=$(python3 -I -c "import json,sys;print(json.load(open(sys.argv[1]))['run']['text'],end='')" "$T")
wf-recorder -y -c ffv1 -f /dev/shm/lane-typing/g2/rec-$(basename "$KIT_OUT").mkv >/dev/null 2>&1 & rec=$!
nap 0.6
wtype -s 300 -d 110 -- "${text:0:96}"
nap 0.3
kill -INT $rec; wait $rec 2>/dev/null
key Escape; nap 0.3; key Escape; nap 0.3
