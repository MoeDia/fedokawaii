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
py() { python3 -I -B - "$C" "$CHESS_TMP"; }

case_ "it opens on today's plan; every tab; Esc leaves; no traceback"
eq "$(py <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
from chess_lib import *
home, env = make_home(sys.argv[2] + "/a")
t = open_app(env)
got = [t.find("day 1 of 365"), t.find("the board"), t.find("game 1"), t.find("the squares")]
t.send("\t"); t.pump(0.2); got.append(t.find("the bishop"))
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
a = t.find("1 of 6")
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
d = t.find("2 of 6")
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
t.send("Kf"); t.pump(0.15)
illegal = t.find("no such move")
t.send("\x7f\x7f\x7f"); t.pump(0.1)
t.send("e4"); t.pump(0.1); t.send("\r"); t.pump(1.8)
moved = current(home)
two = moved and len(moved["moves"]) >= 1
# killed outright, in the middle
os.kill(t.pid, signal.SIGKILL); t.pump(0.2); t.alive()
t = open_app(env)
back = t.find("e4")
saved = current(home)
pos = position_of(saved)
# twelve moves more, then the menu: resign (back, turn round, a hint, a draw, resign, leave)
for _ in range(12):
    saved = current(home)
    pos = position_of(saved)
    if pos.turn != saved["spec"]["colour"]:
        t.pump(1.6)
        continue
    t.send(B.uci(pos.legal()[-1])); t.pump(0.02); t.send("\r"); t.pump(0.3)
t.pump(1.6)
t.send("\x1b"); t.pump(0.1)
t.send("\x1b[B\x1b[B\x1b[B\x1b[B"); t.pump(0.1); t.send("\r"); t.pump(0.3)
over = current(home) is None
pgn = sorted(state(home).glob("games/*.pgn"))
tags, game = B.read_pgn(pgn[0].read_text())
print(illegal, bool(two), back, over, len(pgn), tags["Result"] == game.result, t.find("you resigned"), repr(crash_text(home)))
t.close()
PY
)" "True True True True 1 True True ''"

case_ "a wrong key stays wrong: Kf3 with no king move is never f3; Enter plays nothing while the line says no such move"
eq "$(py <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
from chess_lib import *
home, env = make_home(sys.argv[2] + "/c2")
t = open_app(env)
start_free_game(t)
played = lambda: (current(home) or {"moves": []})["moves"]
t.send("Kf3"); t.pump(0.2)
a = t.find("Kf3") and t.find("no such move")
t.send("\r"); t.pump(0.5)
b = not played()
t.send("\x7f"); t.pump(0.2)
c = not t.find("no such move")
t.send("Nf"); t.pump(0.1); t.send("4"); t.pump(0.2)
d = t.find("Nf4") and t.find("no such move")
t.send("\r"); t.pump(0.5)
e = not played()
t.send("\x7f"); t.pump(0.1); t.send("3"); t.pump(0.1); t.send("\r"); t.pump(0.8)
f = played()[:1] == ["g1f3"]
print(a, b, c, d, e, f, repr(crash_text(home)))
t.close()
PY
)" "True True True True True True ''"

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
t.send("\r")
judge = t.wait("take back", 90)              # (a real engine reads the game: on a busy PC, a while)
t.send("\r")
moment = t.wait("moment 1", 10)
t.send("\x1b")                               # (Esc: shown at once)
shown = t.wait("the move:", 10)
bad_word = t.find(": a inaccuracy")
for _ in range(6):
    t.send("\r")
    for _wait in range(200):
        if t.find("find a better move") or t.find("one thing to remember"):
            break
        t.pump(0.05)
    if t.find("one thing to remember"):
        break
    bad_word = bad_word or t.find(": a inaccuracy")
    t.send("\x1b"); t.wait("the move:", 10)
    bad_word = bad_word or t.find(": a inaccuracy")
sumry = t.find("accuracy") and t.find("blunders")
t.send("look at what the queen can reach"); t.pump(0.1); t.send("\r"); t.pump(0.4)
p = json.loads((st / "progress.json").read_text())
rec = p["played"]["1"]
print(judge, moment, shown, sumry, not bad_word, rec["accuracy"] is not None, rec["takeaway"], p["items"].get("1/review1") is not None, repr(crash_text(home)))
t.close()
PY
)" "True True True True True True look at what the queen can reach True ''"

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

case_ "the plan holds: an exam failed stays open, sixteen of twenty passes; a gate game lost is played again"
eq "$(py <<'PY'
import sys, json, pathlib, time
sys.path.insert(0, sys.argv[1])
from chess_lib import *
root = pathlib.Path(sys.argv[2]) / "x"
home, env = make_home(root)
st = state(home); st.mkdir(parents=True)
items = {f"28/{k}": "x" for k in ("game55", "review55", "puzzles28", "game56", "review56")}
(st / "progress.json").write_text(json.dumps({"day": 28, "items": items}))
trace = root / "trace"
def play_exam(right):
    """Twenty puzzles: the first `right` solved, the rest given up."""
    seen = len(trace.read_text().splitlines()) if trace.exists() else 0
    for n in range(20):
        end = time.time() + 12
        while time.time() < end:
            t.pump(0.03)
            lines = trace.read_text().splitlines() if trace.exists() else []
            if len(lines) > seen:
                break
        seen = len(lines)
        _, pid, fen, moves, rating = lines[-1].split("\t")
        line = moves.split()
        t.pump(0.8)
        if n < right:
            for i in range(1, len(line), 2):
                t.send(line[i]); t.pump(0.01); t.send("\r"); t.pump(0.25)
                if i + 1 < len(line):
                    t.pump(0.65)
        else:
            t.send("\x1b"); t.pump(0.1); t.send("\r"); t.pump(0.1)
    t.pump(0.3)
t = open_app(env)
a = t.find("the exam of these four weeks")
t.send("\r"); t.pump(0.3)
play_exam(0)
t.send("\r"); t.pump(0.2)
fail = t.find("sixteen to pass") and not json.loads((st / "progress.json").read_text())["items"].get("28/exam4")
t.send("\r"); t.pump(0.3)
play_exam(20)
t.send("\r"); t.pump(0.3)
ok = bool(json.loads((st / "progress.json").read_text())["items"].get("28/exam4"))
t.close()
# a gate: king and queen in under twenty, game 43 is the first of week 4's: resign it, it stays open
(st / "progress.json").write_text(json.dumps({"day": 22, "items": {"22/lesson-the-back-rank": "x"}}))
t = open_app(env); t.send("\r"); t.pump(0.5)
t.send("\x1b"); t.pump(0.1); t.send("\x1b[B\x1b[B\x1b[B\x1b[B\r"); t.pump(0.4); t.send("\r"); t.pump(0.3)
p = json.loads((st / "progress.json").read_text())
gate_open = "22/game43" not in p["items"]
said = t.find("played again")
t.close()
print(a, fail, ok, gate_open, said, repr(crash_text(home)))
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

case_ "a click (§7): on a tab goes there; on a key's tile or its words is that key; on the paper beside them, nothing"
eq "$(py <<'PY'
import json, sys, pathlib
sys.path.insert(0, sys.argv[1])
from chess_lib import *
root = pathlib.Path(sys.argv[2]) / "k"
home, env = make_home(root)
t = open_app(env)
def where(word):
    for r, row in enumerate(t.grid):
        s = "".join(row)
        if word in s:
            return r, s.index(word)
    return None
def key(k):
    return "".join(chr(0xff000 + ord(c)) for c in k)
def click(r, c):
    x, y = c * t.cw + t.cw // 2 + 1, r * t.ch + t.ch // 2 + 1
    t.send(f"\x1b[<0;{x};{y}M\x1b[<0;{x};{y}m"); t.pump(0.3)
r, c = where("today")
click(r, c - 3 + 8 + 3)                  # (the second tab's picture: today's picture, name and gap before it)
lessons = t.find("of 154")
r, c = where(key("tab"))
click(r, c)
puzzles = t.find("ten minutes, mixed")
r, c = where(" next")
click(r, c + 2)                          # (its words too)
games = t.find("a free game")
r, c = where(key("esc"))
click(r, c + 30)
kept = t.alive() and t.find("a free game")
click(r, c)
t.ended()
gone = not t.alive()
t.close()
st = state(home)
spec = dict(title="x", goal="", fen="r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3", line=[], colour=0, elo=500, clock=None, hints=3, threats=False, opponent="x", no=None)
(st / "current.json").write_text(json.dumps(dict(spec=spec, moves=[], clock=None, times=[], hints_used=0)))
t = open_app(env)
r, c = where(key("?"))
click(r, c)
hint = t.wait("hint  2", 5)
print(lessons, puzzles, games, kept, gone, hint, repr(crash_text(home)))
t.close()
PY
)" "True True True True True True ''"

case_ "the grammar: the cursor's row tinted, its name in the ink on it, a value its own; a key a tile; the footer on the last line, what does not fit left out"
eq "$(py <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
from chess_lib import LIB
sys.path.insert(0, str(LIB))
import term as T
import ui as U
U.ICONS.update(BOOK="b")
row = U.Row("BOOK", "the rook", "5 min").spans(20, True)
tinted = all(s[2] == T.SELECT for s in row)
words = "".join(s[0] for s in row)
inks = {s[0].strip(): s[1] for s in row if s[0].strip()}
own = inks["5 min"] == T.MUTED and inks["the rook"] == T.ON_SELECT and inks["b"] == T.ON_SELECT
keys = U.keys_line(16, ("enter", "open"), ("tab", "next"))
tile = keys[0] == ("\U000ff001" + "".join(chr(0xff000 + ord(c)) for c in "enter") + "\U000ff002", T.MUTED) and U.span_len(keys) <= 16 and U.span_len(U.keys_line(40, ("enter", "open"), ("tab", "next"))) == 24
foot = U.footed(["a", "b", "c", "d", "e"], 5, keys)
last = foot[-1] is keys and foot[:3] == ["a", "b", "c"] and foot[3] == "" and len(foot) == 5
head = U.heading("BOOK", "the rook", 30, right="week 1")
stack = U.span_len(head) == 30 and head[-1] == " " and head[-2] == ("week 1", T.MUTED)
print(tinted, repr(words), own, tile, last, stack)
PY
)" "True ' b  the rook  5 min ' True True True True"

if [[ -n $REAL_SF ]]; then
  case_ "against the real Stockfish, levels from the first to the strong: legal games, PGNs Stockfish replays to the same position"
  eq "$(python3 -I -B "$C/chess_games.py" "$CHESS_TMP/k" "$REAL_SF" 5 2>&1 | tail -1)" "games 5 replayed 5 crash ''"
else skip "no Stockfish here: only the stand-in was played"; fi
done_
