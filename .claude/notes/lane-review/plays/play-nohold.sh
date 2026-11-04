# two windows on each of three workspaces; the split changed on 1, so 2's windows must draw a new size: a hold at the move's start
for t in 1 2 3; do
  chord logo "$t"; nap 0.3
  foot sh -c 'exec sleep 300' & nap 0.8
  foot sh -c 'exec sleep 300' & nap 0.8
done
chord logo 1; nap 1
nap 0.8
wf-recorder -c rawvideo -f "$KIT_OUT/hold.nut" -m nut >/dev/null 2>&1 & rec=$!
nap 0.6
wtype -s 300 -M logo -k 2 -m logo -s 110 -M logo -k 3 -m logo; nap 1.2
kill -INT "$rec"; wait "$rec" 2>/dev/null
