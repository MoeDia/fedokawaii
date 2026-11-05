export XDG_STATE_HOME=$HOME/.local/state
d="$XDG_STATE_HOME/fedokawaii/typing"
LIB=/home/dia/repos/fk-typing/configs/home/.local/lib/fedokawaii
python3 -IB /dev/shm/lane-typing/gal/state.py "$d" "$LIB"
python3 -I - "$d" <<'PY'
import json,random,sys,time
d=sys.argv[1]; rng=random.Random(4); now=time.time()
with open(d+'/history.jsonl','a') as f:
    for i in range(24):
        f.write(json.dumps({'d':int(now-(24-i)*3000),'l':'top.ru.drill','k':'drill','w':round(14+i*.5+rng.uniform(-3,3),1),'r':30,'a':98,'s':30})+'\n')
PY
T=$XDG_STATE_HOME/fedokawaii/typing-trace.json
kt() { footclient -a float -T typing -W "$1" -- kawa-typing --seed 3 --trace "$T" "${@:2}" >/dev/null 2>>"$KIT_OUT/err.log" & nap 1.8; }
tx() { python3 -I -c "import json,sys;print(json.load(open(sys.argv[1]))['run']['text'],end='')" "$T"; }
out() { key Escape; nap 0.4; key Escape; nap 0.6; }
kt 79x38 --lesson top.ei.drill
text=$(tx)
wtype -s 300 -d 170 -- "$text"
nap 0.15
shot 40-stamping
nap 1.5
shot 41-result
key Return; nap 1.0
shot 42-next
out
rm -f "$d/resume.json"
kt 79x38 --lesson top.wo.drill
text=$(tx)
n=0; while IFS= read -r -n1 c; do [ -z "$c" ] && c=" "; n=$((n+1)); if [ $((n%4)) = 0 ]; then wtype "z"; fi; wtype -- "$c"; done <<<"$text"
nap 1.5
shot 43-failed
out
rm -f "$d/resume.json"
kt 79x38 --lesson speed.30.passage.1
text=$(tx)
wtype -s 300 -d 60 -- "${text:0:60}"
nap 0.5
shot 44-line2
wtype -s 300 -d 60 -- "${text:60:40}"
nap 0.3
shot 45-line3
out
rm -f "$d/resume.json"
footclient -a float -T typing -W 79x38 -- kawa-typing --seed 3 --trace "$T" >/dev/null 2>>"$KIT_OUT/err.log" &
nap 1.8
key Tab; nap 0.3; key Down Down Down Down Down Down Down Down; nap 0.3; key Return; nap 0.6
text=$(tx)
wtype -s 300 -d 90 -- "${text:0:150}"
nap 3
shot 46-test-result
out
