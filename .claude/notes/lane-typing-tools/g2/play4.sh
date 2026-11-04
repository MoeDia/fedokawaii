export XDG_STATE_HOME=$HOME/.local/state
d="$XDG_STATE_HOME/fedokawaii/typing"
LIB=/home/dia/repos/fk-typing/configs/home/.local/lib/fedokawaii
python3 -IB /dev/shm/lane-typing/gal/state.py "$d" "$LIB"
T=$XDG_STATE_HOME/fedokawaii/typing-trace.json
footclient -a float -T typing -W 79x38 -- kawa-typing --seed 3 --trace "$T" --lesson speed.30.passage.1 >/dev/null 2>>"$KIT_OUT/err.log" &
nap 2
text=$(python3 -I -c "import json,sys;print(json.load(open(sys.argv[1]))['run']['text'],end='')" "$T")
wtype -s 300 -d 60 -- "${text:0:110}" &
nap 6
shot 50-motes
wait
nap 0.2
shot 51-motes
key Escape; nap 0.3; key Escape; nap 0.3
