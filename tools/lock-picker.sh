#!/usr/bin/env bash
# tools/lock-picker.sh HI — the owner's pick of the lock (r28 l4), sets L (dark) and L2 (light) in HI: for each of the
# 4 + 4 walls the whole proof of tools/lock-samurai-proof.sh (the real gtklock and module, headless), its recording as
# an MP4 of the reactions and its fullest frame as a PNG, then picker.json. A proof that fails stops the pack.
set -eu
hi=$1
repo=$(cd "$(dirname "$0")/.." && pwd)
pack() {
  local mood=$1 n=$2 map=$3 name W
  name=$4-$n-$mood W=/dev/shm/r28/l3/$mood
  bash "$repo/tools/lock-samurai-proof.sh" "$mood" "$map"
  mkdir -p "/dev/shm/r28/l4"
  cp "$W/report.txt" "/dev/shm/r28/l4/$name.txt"
  grep -q "pointer box 98,100 16x23," "$W/report.txt"
  ffmpeg -nostdin -loglevel error -y -ss 1.5 -i "$W/rec.mkv" -i "$W/art/lock-scene.png" \
    -filter_complex "[1:v]scale=1920:1080:flags=neighbor,crop=16:23:98:100[p];[0:v][p]overlay=98:100,fps=60" -c:v libx264 -preset slow -crf 20 -tune animation \
    -pix_fmt yuv420p -movflags +faststart -an "$hi/$name.mp4"
  python3 -B "$repo/tools/lock-picker.py" still "$W" "$hi/$name.png"
  rm -rf "$W/frames"
}
n=0; for map in shiro kozan suichu kaji; do n=$((n + 1)); pack dark $n $map L; done
n=0; for map in haru kumo yu yuki; do n=$((n + 1)); pack light $n $map L2; done
python3 -B "$repo/tools/lock-picker.py" picker "$hi"
