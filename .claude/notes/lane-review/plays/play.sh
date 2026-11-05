OUT=/dev/shm/lane-review/m1
panel; warm; nap 1.5
chord logo Return; nap 1.5; text 'ls -a'; key Return; nap 0.8
chord logo Return; nap 1.5
chord logo 2; nap 1
chord logo Return; nap 1.2; text 'cal'; key Return; nap 0.6
chord logo 3; nap 1
chord logo Return; nap 1.2; text 'date'; key Return; nap 0.6
chord logo 1; nap 1.2
rec() { wf-recorder -y -c ffv1 -f "$1" >/dev/null 2>&1 & R=$!; nap 1; }
fin() { kill -INT "$R"; wait "$R" 2>/dev/null; }
rec "$OUT/a-clean.mkv"
chord logo 2; nap 1.0
fin
chord logo 1; nap 1.2
rec "$OUT/b-reverse.mkv"
chord logo 2 & sleep 0.18; chord logo 1 & nap 1.4
fin
nap 0.8
rec "$OUT/c-rapid.mkv"
chord logo 2 & sleep 0.12; chord logo 3 & sleep 0.12; chord logo 4 & sleep 0.12; chord logo 5 & nap 1.6
fin
chord logo 1; nap 1.2
rec "$OUT/d-open.mkv"
chord logo Return; nap 1.0
fin
rec "$OUT/e-close.mkv"
chord logo q; nap 1.0
fin
say done
