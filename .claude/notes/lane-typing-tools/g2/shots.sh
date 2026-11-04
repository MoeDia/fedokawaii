#!/usr/bin/env bash
cd /home/dia/repos/fk-typing; export PATH=$HOME/.local/bin:$PATH
for m in ${1:-dark light}; do
  o=/dev/shm/lane-typing/g2/$m; rm -rf "$o"; mkdir -p "$o"
  bash tools/kit.sh --theme "$m" --bin bin --out "$o" --time 200 --play /dev/shm/lane-typing/g2/${PLAY:-play.sh} play 2>&1 | tail -2 | cut -c1-200
  tail -5 "$o/err.log" 2>/dev/null | cut -c1-300
  for f in "$o"/[0-9]*.png; do python3 -I /dev/shm/lane-typing/scratch/crop.py "$f" "${f%.png}.c.png" >/dev/null; done
  ls "$o" | wc -l
done
