export XDG_STATE_HOME=$HOME/.local/state
d="$XDG_STATE_HOME/fedokawaii/typing"
LIB=/home/dia/repos/fk-typing/configs/home/.local/lib/fedokawaii
python3 -IB /dev/shm/lane-typing/gal/state.py "$d" "$LIB"
T=$XDG_STATE_HOME/fedokawaii/typing-trace.json
kt() { footclient -a float -T typing -W "$1" -- kawa-typing --seed 3 --trace "$T" "${@:2}" >/dev/null 2>>"$KIT_OUT/err.log" & nap 1.8; }
tx() { python3 -I -c "import json,sys;print(json.load(open(sys.argv[1]))['run']['text'],end='')" "$T"; }
out() { key Escape; nap 0.4; key Escape; nap 0.6; }
kt 79x38
shot 01-course
key Down Down; nap 0.3
shot 02-stagerow
key Return; nap 0.4
shot 03-stage
key Escape; nap 0.3
key Tab; nap 0.4
shot 04-practice
key Tab; nap 0.5
shot 05-progress
out
rm -f "$d/resume.json"
kt 79x38 --lesson home.fj.meet
shot 10-meet
out
rm -f "$d/resume.json"
kt 79x38 --lesson top.ru.drill
text=$(tx)
wtype -s 300 -d 60 -- "${text:0:8}"
nap 0.2
wtype -s 300 -- "z"
nap 0.03
shot 11-drill-wrong
out
rm -f "$d/resume.json"
kt 79x38 --lesson caps.FDSA.words
shot 12-caps
out
rm -f "$d/resume.json"
kt 79x38 --lesson sent.3
text=$(tx)
wtype -s 300 -d 60 -- "${text:0:20}qq"
nap 0.2
shot 13-sentence-wrong
out
rm -f "$d/resume.json"
kt 79x38 --lesson speed.30.pacer
text=$(tx)
wtype -s 300 -d 110 -- "${text:0:14}"
nap 0.5
shot 14-pacer
out
rm -f "$d/resume.json"
kt 79x38 --lesson code.python.1
text=$(tx)
wtype -s 300 -d 40 -- "${text:0:30}"
nap 0.3
shot 15-code
out
rm -f "$d/resume.json"
printf '{"baseline":38,"lessons":{"home.fj.meet":{"seals":0,"best":0,"tries":1}}}' > "$d/progress.json"
kt 79x38 --lesson 'home.a;.words'
text=$(tx)
wtype -s 300 -d 170 -- "$text"
nap 1.6
shot 20-result
out
python3 -IB /dev/shm/lane-typing/gal/state.py "$d" "$LIB"
rm -f "$d/resume.json"
for size in 60x21 130x49 79x38 150x30; do
  kt $size
  shot 30-home-$size
  key Tab; nap 0.5; key Tab; nap 0.5
  shot 31-progress-$size
  out
  rm -f "$d/resume.json"
  kt $size --lesson sent.3
  text=$(tx)
  wtype -s 300 -d 60 -- "${text:0:12}"
  nap 0.3
  shot 32-lesson-$size
  out
  rm -f "$d/resume.json"
done
