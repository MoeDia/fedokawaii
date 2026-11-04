#!/usr/bin/env bash
# tests/content/test_chess.sh — kawa-chess whole, in a terminal of its own (chess_pty.py), against a stand-in Stockfish
# (fake_stockfish.py) and, when one is here, the real one (KAWA_TEST_STOCKFISH, or on PATH): the screens, a lesson, a
# game to its end and its PGN, a kill mid-game, a review, 200 puzzles, an exam, sizes from 60 × 20 to full, both moods.
. "$(dirname "$0")/lib.sh"
sandbox
export CHESS_TMP=$TMP/chess
mkdir -p "$CHESS_TMP"
REAL_SF=${KAWA_TEST_STOCKFISH:-$(command -v stockfish 2>/dev/null)}
export REAL_SF
py() { python3 -I -B - "$C" "$CHESS_TMP" "$@"; }

case_ "it opens on today's plan; every tab; Esc leaves; no traceback"
eq "$(py <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
from chess_lib import *
home, env = make_home(sys.argv[2] + "/a")
t = open_app(env)
got = [t.find("day 1 of 365"), t.find("the board"), t.find("game 1"), t.find("puzzles:")]
t.send("\t"); t.pump(0.2); got.append(t.find("the rook"))
t.send("\t"); t.pump(0.2); got.append(t.find("ten minutes"))
t.send("\t"); t.pump(0.2); got.append(t.find("a free game"))
t.send("\t"); t.pump(0.3); got.append(t.find("puzzle rating"))
t.send("\t"); t.pump(0.2); got.append(t.find("day 1 of 365"))
t.send("\x1b"); t.ended()
print(got, t.alive(), t.status, repr(crash_text(home)))
PY
)" "[True, True, True, True, True, True, True, True, True] False 0 ''"

case_ "a lesson: pages in order, squares to find, a move to find with a wrong one first; the place is kept"
eq "$(py <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
from chess_lib import *
home, env = make_home(sys.argv[2] + "/b")
t = open_app(env)
t.send("\r"); t.pump(0.3)
a = t.find("1 of 3")
t.send("\r"); t.pump(0.2)
b = t.find("e4")
t.send("a1"); t.pump(0.1)
wrong = t.find("that is a1")
for s in ("e4", "a1", "h8", "d5", "g2", "b7"):
    t.send(s); t.pump(0.04)
c = not t.find("that is")
t.close()
t = open_app(env)              # (left in the middle: the next time it opens there, the plan's row first)
t.send("\r"); t.pump(0.3)
d = t.find("2 of 3")
print(a, b, wrong, c, d, repr(crash_text(home)))
t.close()
PY
)" "True True True True True ''"

case_ "a game against the stand-in: typed moves, an illegal one, the end, the PGN; a kill -9 mid-game loses nothing"
eq "$(py <<'PY'
import os, signal, sys, json
sys.path.insert(0, sys.argv[1])
from chess_lib import *
home, env = make_home(sys.argv[2] + "/c")
t = open_app(env)
start_free_game(t)
t.send("Ke9"); t.pump(0.15)
illegal = t.find("no such move")
t.send("\x7f\x7f\x7f"); t.pump(0.1)
t.send("\x1b"); t.pump(0.1); t.send("\x1b"); t.pump(0.1)
t.send("e4"); t.pump(0.1); t.send("\r"); t.pump(1.8)
moved = current(home)
two = moved and len(moved["moves"]) >= 1
# killed outright, in the middle
os.kill(t.pid, signal.SIGKILL); t.pump(0.2); t.alive()
t = open_app(env)
back = t.find("e4")
saved = current(home)
pos = position_of(saved)
# play it out: the first legal move, every time, whatever it is
g = 0
while g < 400 and t.alive():
    saved = current(home)
    if saved is None:
        break
    pos = position_of(saved)
    if pos.turn != saved["spec"]["colour"]:
        t.pump(0.05)
        g += 1
        continue
    moves = pos.legal()
    if not moves:
        break
    t.send(B.uci(moves[-1])); t.pump(0.02); t.send("\r"); t.pump(0.3)
    g += 1
over = current(home) is None
pgn = sorted(state(home).glob("games/*.pgn"))
tags, game = B.read_pgn(pgn[0].read_text())
print(illegal, bool(two), back, over, len(pgn), tags["Result"] == game.result, game.over(), repr(crash_text(home)))
t.close()
PY
)" "True True True True 1 True True ''"

case_ "the review: the game read, your own judgement first, a move to find, the summary, what you wrote kept"
eq "$(py <<'PY'
import sys, json
sys.path.insert(0, sys.argv[1])
from chess_lib import *
home, env = make_home(sys.argv[2] + "/d")
st = state(home); (st / "games").mkdir(parents=True)
# a game in which White leaves a queen for nothing on move 3, played as White
pgn = '[Event "x"]\n[White "you"]\n[Black "opp"]\n[Result "0-1"]\n\n1. e4 e5 2. Qg4 Nf6 3. Qg5 Nxe4 4. d3 Nxg5 0-1\n'
(st / "games/1.pgn").write_text(pgn)
(st / "progress.json").write_text(json.dumps({"day": 1, "items": {"1/lesson-the-board": "x", "1/game1": "x"}, "played": {"1": {"score": "loss", "elo": 500, "t": 1, "me": 0, "times": [3, 3, 3, 3], "check": "safe", "goal": "be safe", "accuracy": None}}}))
t = open_app(env)
t.send("\r"); t.pump(2.5)
judge = t.find("take back")
t.send("\r"); t.pump(0.3)
moment = t.find("moment 1")
t.send("\x1b"); t.pump(0.2)                 # (Esc: shown at once)
shown = t.find("the move:")
for _ in range(6):
    if t.find("one thing to remember"):
        break
    t.send("\r"); t.pump(0.2)
    if t.find("find a better move"):
        t.send("\x1b"); t.pump(0.2)
sumry = t.find("accuracy") and t.find("blunders")
t.send("look at what the queen can reach"); t.pump(0.1); t.send("\r"); t.pump(0.4)
p = json.loads((st / "progress.json").read_text())
rec = p["played"]["1"]
print(judge, moment, shown, sumry, rec["accuracy"] is not None, rec["takeaway"], p["items"].get("1/review1") is not None, repr(crash_text(home)))
t.close()
PY
)" "True True True True True look at what the queen can reach True ''"

case_ "puzzles by script, right and wrong by turns: the rating moves, what was missed is due, nothing repeats early (test_chess_destroy: 200)"
eq "$(py <<'PY'
import sys, json, pathlib, time
sys.path.insert(0, sys.argv[1])
from chess_lib import *
root = pathlib.Path(sys.argv[2]) / "e"
home, env = make_home(root)
t = open_app(env)
go_to_tab(t, "puzzles"); t.send("\r"); t.pump(0.3)
trace = root / "trace"
done = 0; seen = 0; ids = []
start_r = json.loads((state(home) / "progress.json").read_text())["puzzle"]["r"] if (state(home) / "progress.json").exists() else 650
end = time.time() + 120
while done < 12 and time.time() < end and t.alive():
    t.pump(0.03)
    lines = trace.read_text().splitlines() if trace.exists() else []
    if len(lines) <= seen:
        continue
    seen = len(lines)
    _, pid, fen, moves, rating = lines[-1].split("\t")
    ids.append(pid)
    solve = done % 2 == 0
    pos = B.Position(fen)
    line = moves.split()
    pos.push(B.from_uci(line[0]))
    t.pump(0.75)                      # (the opponent's first move lands)
    if solve:
        for i in range(1, len(line), 2):
            t.send(line[i]); t.pump(0.01); t.send("\r"); t.pump(0.3)
            if i + 1 < len(line):
                t.pump(0.75)
    else:
        wrong = next(m for m in pos.legal() if B.uci(m) != line[1])
        t.send(B.uci(wrong)); t.pump(0.01); t.send("\r"); t.pump(0.05)
        t.send("\x1b"); t.pump(0.1)
        t.send("\r"); t.pump(0.15)
    done += 1
t.send("\x1b"); t.pump(0.1); t.send("\x1b"); t.pump(0.1)
t.close()
p = json.loads((state(home) / "progress.json").read_text())
print(done >= 12, p["puzzle"]["r"] != start_r, len(p["due"]) > 0, len(set(ids)) >= done - 5, p["tries"] > 0, repr(crash_text(home)))
PY
)" "True True True True True ''"

case_ "what breaks: a state file cut short, the game file garbage, puzzles and lessons damaged or gone, no Stockfish at all"
eq "$(py <<'PY'
import os, sys, json, pathlib
sys.path.insert(0, sys.argv[1])
from chess_lib import *
root = pathlib.Path(sys.argv[2]) / "f"
home, env = make_home(root)
st = state(home); st.mkdir(parents=True)
res = []
# a progress file cut short; a backup beside it
(st / "progress.json.bak").write_text(json.dumps({"day": 9}))
(st / "progress.json").write_text('{"day": 12, "items"')
t = open_app(env); res.append(t.find("day 9 of 365")); t.close()
for f in st.glob("progress*"):
    f.unlink()
(st / "progress.json").write_bytes(b"\xff\xfe\x00garbage")
t = open_app(env); res.append(t.find("day 1 of 365")); t.close()
for bad in ('{"spec": {"fen": "not a fen", "colour": 0, "elo": 500}, "moves": []}', '{"spec": 7, "moves": 9}', '[1,2]', '{"spec": {"fen": "%s", "colour": 0, "elo": 500}, "moves": ["e2e5"]}' % B.START):
    (st / "current.json").write_text(bad)
    t = open_app(env); res.append(t.find("day") and t.alive()); t.close()
    res.append(not (st / "current.json").exists() or bad == '[1,2]' or bad.startswith('{"spec": 7'))
    if (st / "current.json").exists():
        (st / "current.json").unlink()
data = home / ".local/share/fedokawaii/chess"
(data / "puzzles.tsv").write_text("# nothing\nbad line\nid\tnot a fen at all\tzz\t900\tfork\n")
t = open_app(env); go_to_tab(t, "puzzles"); t.send("\r"); t.pump(0.8); res.append(t.alive()); t.close()
(data / "puzzles.tsv").unlink()
t = open_app(env); go_to_tab(t, "puzzles"); t.send("\r"); t.pump(0.5); res.append(t.alive()); t.close()
(data / "lessons.txt").write_text("=== broken\ntitle: broken\n\n@fen zzz\n@try Zz9 | x\n@play Qq1\n---\n@unknown\n")
t = open_app(env); go_to_tab(t, "lessons"); t.send("\r"); t.pump(0.4); t.send("\r"); t.pump(0.3); res.append(t.alive()); t.close()
(data / "lessons.txt").unlink()
t = open_app(env); res.append(t.find("day") and t.alive()); go_to_tab(t, "lessons"); t.send("\r"); t.pump(0.2); res.append(t.alive()); t.close()
# no engine at all
(root / "bin/stockfish").unlink()
t = open_app(env); start_free_game(t); t.send("e4"); t.send("\r"); t.pump(2.2); res.append(t.alive()); t.close()
print(res, repr(crash_text(home)))
PY
)" "[True, True, True, True, True, True, True, True, True, True, True, True, True, True, True, True] ''"

case_ "the engine killed mid-think, or dumb for ever: the game goes on"
eq "$(py <<'PY'
import sys, pathlib
sys.path.insert(0, sys.argv[1])
from chess_lib import *
root = pathlib.Path(sys.argv[2]) / "g"
home, env = make_home(root, extra={"FAKE_SF_DIE": "1", "FAKE_SF_ONCE": str(root) + "-mark"})
t = open_app(env); start_free_game(t); t.send("e4"); t.send("\r"); t.pump(2.5)
a = len(current(home)["moves"])
t.close()
root = pathlib.Path(sys.argv[2]) / "h"
home, env = make_home(root, extra={"FAKE_SF_MUTE": "1", "FAKE_SF_ONCE": str(root) + "-mark"})
t = open_app(env); start_free_game(t); t.send("e4"); t.send("\r"); t.pump(11)
b = len(current(home)["moves"])
t.close()
print(a, b, repr(crash_text(home)))
PY
)" "2 2 ''"

case_ "sizes: 60 × 20 to full screen, and too small: nothing cut, nothing past the edge; a resize mid-game"
eq "$(py <<'PY'
import sys, pathlib
sys.path.insert(0, sys.argv[1])
from chess_lib import *
root = pathlib.Path(sys.argv[2]) / "i"
home, env = make_home(root)
res = []
for cols, rows in ((60, 20), (64, 24), (86, 24), (100, 33), (126, 33), (60, 45), (118, 50), (236, 51), (300, 80)):
    t = open_app(env, cols, rows)
    res.append(t.alive() and t.sixels >= 1 and (t.find("day 1") or t.find("today") ))
    t.close()
t = open_app(env, 40, 12); res.append(t.find("chess needs")); t.resize(126, 33); t.pump(0.4); res.append(t.find("day 1 of 365"))
t.send("\t"); t.pump(0.1); t.send("\t"); t.pump(0.1); t.send("\t"); t.pump(0.1)
t.send("\r"); t.pump(0.1); t.send("\x1b[B\x1b[B\r"); t.pump(0.3)
t.send("e4"); t.pump(0.05)
for cols, rows in ((60, 20), (200, 50), (30, 10), (126, 33)):
    t.resize(cols, rows); t.pump(0.2)
t.pump(0.5)
res.append(t.alive())
t.close()
print(res, repr(crash_text(home)))
PY
)" "[True, True, True, True, True, True, True, True, True, True, True, True] ''"

case_ "both moods: a switch redraws the board in the new inks, at once, nothing else; a paste moves nothing; a click moves"
eq "$(py <<'PY'
import sys, pathlib
sys.path.insert(0, sys.argv[1])
from chess_lib import *
root = pathlib.Path(sys.argv[2]) / "j"
home, env = make_home(root, mood="light")
t = open_app(env, mood="light")
n = t.sixels
t.send("\x1b[?997;1n"); t.pump(0.3)
one = t.sixels == n + 1
t.send("\x1b[?997;1n"); t.pump(0.2)
same = t.sixels == n + 1          # (told the same mood again: nothing)
start_free_game(t)
t.send("\x1b[200~e4\r\x1b[201~"); t.pump(0.2)
pasted = not (current(home) or {"moves": []})["moves"]
# e2 then e4 by the mouse: 80 px squares, the picture at the first cell; a pixel inside each square
def click(sq):
    f, r = sq % 8, sq // 8
    x, y = 8 + f * 80 + 40 + 1, 8 + (7 - r) * 80 + 40 + 1
    t.send(f"\x1b[<0;{x};{y}M\x1b[<0;{x};{y}m"); t.pump(0.08)
click(B.sq_of("e2")); click(B.sq_of("e4")); t.pump(0.5)
moved = current(home)["moves"][:1] == ["e2e4"]
print(one, same, pasted, moved, repr(crash_text(home)))
t.close()
PY
)" "True True True True ''"

if [[ -n $REAL_SF ]]; then
  case_ "against the real Stockfish, levels from the first to the strong: legal games, PGNs Stockfish replays to the same position"
  eq "$(python3 -I -B "$C/chess_games.py" "$CHESS_TMP/k" "$REAL_SF" 5 2>&1 | tail -1)" "games 5 replayed 5 crash ''"
else skip "no Stockfish here: only the stand-in was played"; fi
done_
