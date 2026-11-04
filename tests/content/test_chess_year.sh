#!/usr/bin/env bash
# tests/content/test_chess_year.sh — the year as kawa-chess hands it out: all 365 days read from the course (every row, every
# game's start, clock and goal, what each lesson and sitting asks of the files), days opened row by row in the real program, the
# year's last words. Its own file: tests/run.sh gives a file 15 minutes, and test_chess_destroy.sh needs them on a busy PC.
. "$(dirname "$0")/lib.sh"
sandbox
export CHESS_TMP=$TMP/chess
mkdir -p "$CHESS_TMP"

case_ "the year as it is handed out: all 365 days read, every game's start, clock and goal; days opened row by row; the year's last words"
out=$(python3 -I -B "$C/chess_year.py" "$CHESS_TMP/y" 2>&1) && _ok || _no "$(tail -c 800 <<<"$out")"

done_
