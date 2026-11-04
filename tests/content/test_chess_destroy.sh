#!/usr/bin/env bash
# tests/content/test_chess_destroy.sh — kawa-chess tested to destruction: every lesson walked by keyboard; every odd rule through
# the real input path (promotion typed, cursor, click; en passant; threefold, fifty moves, stalemate, flag fall with nothing
# left); every key on every screen; then the fuzz (chess_fuzz.py). KAWA_CHESS_LONG=1: 30 minutes of fuzz; chess_puzzles200.py: the 200 puzzles.
. "$(dirname "$0")/lib.sh"
sandbox
export CHESS_TMP=$TMP/chess
mkdir -p "$CHESS_TMP"
REAL_SF=${KAWA_TEST_STOCKFISH:-$(command -v stockfish 2>/dev/null)}
py() { python3 -I -B - "$C" "$CHESS_TMP" "$@"; }

case_ "every lesson of the year walked by keyboard: squares found, moves found, drills entered, each marked done"
out=$(python3 -I -B "$C/chess_walk.py" "$CHESS_TMP/w" 2>&1) && _ok || _no "$(tail -c 800 <<<"$out")"

case_ "the odd rules through the keyboard and the mouse: promotion three ways, en passant, three times, fifty moves, stalemate, the flag"
eq "$(py <<'PY'
import json, sys, pathlib, time
sys.path.insert(0, sys.argv[1])
from chess_lib import *
root = pathlib.Path(sys.argv[2]) / "r"
home, env = make_home(root)
st = state(home); st.mkdir(parents=True)
def fixture(fen, colour=0, moves=(), clock=None, elo=500):
    spec = dict(title="x", goal="", fen=fen, line=[], colour=colour, elo=elo, clock=clock, hints=0, threats=False, opponent="x", no=None)
    (st / "current.json").write_text(json.dumps(dict(spec=spec, moves=list(moves), clock=[clock[0] * 60.0] * 2 if clock else None, times=[], hints_used=0)))
out = []
last = lambda: (current(home) or {"moves": ["(over)"]})["moves"][:1]
# promotion: typed with the piece
fixture("7k/P7/8/8/8/8/7P/K7 w - - 0 1")
t = open_app(env); t.send("a8=N"); t.pump(0.05); t.send("\r"); t.pump(0.4); out.append(last() ); t.close()
# typed without it: asked; a letter
fixture("7k/P7/8/8/8/8/7P/K7 w - - 0 1")
t = open_app(env); t.send("a8"); t.pump(0.05); t.send("\r"); t.pump(0.1); a = t.find("q r b n"); t.send("r"); t.pump(0.4); out += [a, last()]; t.close()
# by the arrows: asked; Enter is the queen
fixture("7k/P7/8/8/8/8/7P/K7 w - - 0 1")
t = open_app(env)
t.send("\x1b[A"); t.pump(0.03)       # (the cursor starts at e2: walk to a7)
for _ in range(5):
    t.send("\x1b[A"); t.pump(0.02)
for _ in range(4):
    t.send("\x1b[D"); t.pump(0.02)
t.send("\r"); t.pump(0.03); t.send("\x1b[A"); t.pump(0.03); t.send("\r"); t.pump(0.08); b = t.find("q r b n"); t.send("\r"); t.pump(0.4); out += [b, last()]; t.close()
# en passant
fixture("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2")
t = open_app(env); t.send("exd6"); t.pump(0.03); t.send("\r"); t.pump(0.4); out.append(last()); t.close()
# fifty moves: the last quiet move ends it
fixture("7k/8/8/8/8/8/8/K5Q1 w - - 99 80")
t = open_app(env); t.send("Qg2"); t.pump(0.03); t.send("\r"); t.pump(0.5); out.append(t.find("the fifty-move rule")); t.close()
# stalemate by your own hand
fixture("7k/8/6K1/8/8/8/5Q2/8 w - - 0 1")
t = open_app(env); t.send("Qf7"); t.pump(0.03); t.send("\r"); t.pump(0.5); out.append(t.find("stalemate")); t.close()
# three times: the last king move, yours, brings the position back the third time
g = B.Game("7k/8/8/8/8/8/8/K5Q1 w - - 0 1")
for mv in "Qg2 Kh7 Qg1 Kh8 Qg2 Kh7 Qg1".split():
    g.play(g.pos.parse_san(mv))
fixture(g.start, colour=1, moves=[B.uci(m) for m in g.moves])
t = open_app(env); t.send("Kh8"); t.pump(0.03); t.send("\r"); t.pump(0.5); out.append(t.find("threefold repetition")); t.close()
# the flag: on time with something left; with nothing left to mate, a draw
fixture("7k/7p/8/8/8/8/P7/K7 w - - 0 1", clock=(0, 0))
t = open_app(env); t.pump(0.4); out.append(t.find("on time")); t.close()
fixture("7k/8/8/8/8/8/P7/K7 w - - 0 1", clock=(0, 0))
t = open_app(env); t.pump(0.4); out.append(t.find("nothing left to mate")); t.close()
print(out, repr(crash_text(home)))
PY
)" "[['a7a8n'], True, ['a7a8r'], True, ['a7a8q'], ['e5d6'], True, True, True, True, True] ''"

case_ "the review and the puzzles when things fail under them: no engine, an empty game, a game too short to judge"
eq "$(py <<'PY'
import json, sys, pathlib
sys.path.insert(0, sys.argv[1])
from chess_lib import *
root = pathlib.Path(sys.argv[2]) / "v"
home, env = make_home(root, fake=False)
st = state(home); (st / "games").mkdir(parents=True)
(st / "games/1.pgn").write_text('[Event "x"]\n\n*\n')
(st / "games/2.pgn").write_text("garbage")
(st / "progress.json").write_text(json.dumps({"played": {"1": {"score": "draw", "me": 0}, "2": {"score": "win", "me": 1}}, "items": {"1/lesson-the-board": "x", "1/game1": "x"}}))
t = open_app(env); t.send("\r"); t.pump(1.0); a = t.alive(); t.send("\x1b"); t.pump(0.2)
go_to_tab(t, "games"); t.send("\x1b[B\r"); t.pump(0.3); t.send("\x1b"); t.pump(0.1); t.send("\x1b[B\r"); t.pump(0.3); b = t.alive(); t.close()
print(a, b, repr(crash_text(home)))
PY
)" "True True ''"

case_ "nothing left behind: a key at any moment of a move's flight, sparks, a castling: the screen is what a whole redraw gives, pixel for pixel"
out=$(python3 -I -B "$C/chess_ghost.py" "$CHESS_TMP/gh" 6 2>&1) && _ok || _no "$(tail -c 800 <<<"$out")"

case_ "every key on every screen, at three sizes, in both moods"
out=$(python3 -I -B "$C/chess_sweep.py" "$CHESS_TMP/s" 2>&1) && _ok || _no "$(tail -c 1200 <<<"$out")"
printf '    (%s)\n' "$(tail -1 <<<"$out" | cut -c1-120)"

secs=${KAWA_CHESS_FUZZ:-25}
if [[ ${KAWA_CHESS_LONG:-} == 1 ]]; then secs=1800; fi
case_ "the fuzz: every key, floods, pastes, clicks, resizes, the engine killed, the program killed, its files damaged ($secs s)"
out=$(python3 -I -B "$C/chess_fuzz.py" "$CHESS_TMP/f" "$secs" "${KAWA_CHESS_SEED:-$RANDOM}" ${KAWA_CHESS_FUZZ_REAL:+"$REAL_SF"} 2>&1); r=$?
if ((r == 0)); then _ok; printf '    (%s)\n' "$(tail -1 <<<"$out")"; else _no "$(tail -c 1500 <<<"$out")"; fi
done_
