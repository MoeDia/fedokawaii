#!/usr/bin/env bash
# tools/review-gather.sh — what the lanes have rendered for the owner's verdict (each worktree's
# .claude/review/next/), on his page: copied into .claude/review/current/ as 00z-LANE-NAME, a note beside
# each (a picture's 4× only where it is not one of many: a wallpaper's 1× is enough to judge). Run it again
# at will: a page already there is replaced, one a lane has dropped goes.
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
cur=$repo/.claude/review/current
rm -f "$cur"/00z-*
n=0
for w in "$HOME"/repos/fk-*; do
  lane=${w##*/fk-} next=$w/.claude/review/next
  [[ -d $next ]] || continue
  for f in "$next"/*; do
    b=${f##*/}
    [[ $b == *wall-*-4x* ]] && continue
    case $b in *.png|*.webp|*.jpg|*.md) cp -- "$f" "$cur/00z-$lane-$b"; n=$((n + 1)) ;; esac
  done
done
echo "review-gather: $n files"
