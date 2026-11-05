# two windows on each of three workspaces, then bursts at 110-120 ms with the split changed first (a hold at the
# move's start) and windows closed and opened in the middle of a move: what stripstart's loop and its re-arm touch
for t in 1 2 3; do
  chord logo "$t"; nap 0.3
  foot sh -c 'exec sleep 300' & nap 0.7
  foot sh -c 'exec sleep 300' & nap 0.7
done
chord logo 1; nap 0.8
for round in 1 2 3 4 5 6; do
  wtype -s 200 -M logo -k 2 -m logo -s 110 -M logo -k 3 -m logo -s 120 -M logo -k 1 -m logo; nap 0.9
  chord logo l; nap 0.1; chord logo l; nap 0.1
  wtype -s 100 -M logo -k 2 -m logo -s 110 -M logo -k 3 -m logo; nap 0.9
  chord logo h; nap 0.1; chord logo h; nap 0.1
  # a window closed mid-move, then one opened mid-move, then a switch turned back
  chord logo 1; nap 0.7
  wtype -s 100 -M logo -k 2 -m logo -s 60 -M logo -k q -m logo -s 60 -M logo -k 3 -m logo; nap 0.8
  foot sh -c 'exec sleep 300' & wtype -s 40 -M logo -k 1 -m logo -s 90 -M logo -k 2 -m logo; nap 0.9
  foot sh -c 'exec sleep 300' & wtype -s 40 -M logo -k 3 -m logo -s 90 -M logo -k 1 -m logo; nap 0.9
done
say burst-over
