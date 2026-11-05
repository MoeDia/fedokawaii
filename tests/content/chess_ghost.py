#!/usr/bin/env python3
"""chess_ghost.py DIR [ROUNDS] — nothing left behind on the board. Every sixel is laid on a picture of the window as a
terminal would; after a move has landed (a key in its flight at any moment, a capture's sparks, a castling, the reply, the
machine as loaded as it is) what is on the screen must be, pixel for pixel, what a redraw of the whole board gives."""
import pathlib
import signal
import os
import random
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from chess_lib import B, crash_text, current, make_home, open_app, position_of, state  # noqa: E402

FENS = ("r3k2r/pppq1ppp/2n2n2/2bpp3/2BPP3/2N2N2/PPPQ1PPP/R3K2R w KQkq - 0 1",
        "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR w KQkq - 0 1",
        "rnbqkbnr/ppp2ppp/8/3pp3/3PP3/8/PPP2PPP/RNBQKBNR w KQkq - 0 1")


def board_box(t):
    """The picture's whole cells: the board and its frame, at the first cell (a board of 80 px squares here)."""
    size = -(-(8 * 80 + 16) // t.cw) * t.cw, -(-(8 * 80 + 16) // t.ch) * t.ch
    return 0, 0, size[0], size[1]


def compare(t):
    """What is on the screen now against a redraw of everything (SIGCONT lays the window out anew)."""
    box = board_box(t)
    t.settle(0.3, 5)
    before = t.pixels(*box)
    n = t.sixels
    os.kill(t.pid, signal.SIGCONT)
    end = 40
    while t.sixels == n and end:
        t.pump(0.05)
        end -= 1
    t.settle(0.3, 5)
    after = t.pixels(*box)
    if before == after:
        return None
    bad = [(x, y) for y, (a, b) in enumerate(zip(before, after, strict=True)) for x, (p, q) in enumerate(zip(a, b, strict=True)) if p != q]
    return len(bad), bad[:3], bad[-3:]


def fixture(home, fen, colour=0, moves=()):
    import json
    st = state(home)
    st.mkdir(parents=True, exist_ok=True)
    spec = {"title": "x", "goal": "", "fen": fen, "line": [], "colour": colour, "elo": 1500, "clock": None, "hints": 3, "threats": False, "opponent": "tengu", "no": None}
    (st / "current.json").write_text(json.dumps({"spec": spec, "moves": list(moves), "clock": None, "times": [], "hints_used": 0}))


def main(argv):
    root = pathlib.Path(argv[1])
    rounds = int(argv[2]) if len(argv) > 2 else 12
    rng = random.Random(27)
    home, env = make_home(root)
    fails = []
    done = 0
    for i in range(rounds):
        fixture(home, FENS[i % len(FENS)])
        t = open_app(env)
        t.keep_pixels()
        os.kill(t.pid, signal.SIGCONT)     # (the whole board once, on the kept picture)
        t.pump(0.1)
        t.settle(0.3, 5)
        for _ in range(4):
            saved = current(home)
            if not saved:
                break
            pos = position_of(saved)
            if pos.turn != saved["spec"]["colour"]:
                t.pump(1.6)
                saved = current(home)
                if not saved:
                    break
                pos = position_of(saved)
                if pos.turn != saved["spec"]["colour"]:
                    continue
            moves = pos.legal()
            if not moves:
                break
            # the moves that show most: a capture's sparks, a castling, the longest slide
            caps = [m for m in moves if pos.is_capture(m)]
            castles = [m for m in moves if pos.b[m & 63] & 7 == B.KING and abs((m & 63) - (m >> 6 & 63)) == 2]
            longest = max(moves, key=lambda m: abs((m & 63) % 8 - (m >> 6 & 63) % 8) + abs((m & 63) // 8 - (m >> 6 & 63) // 8))
            m = rng.choice(caps or castles or [longest]) if i % 2 else rng.choice(castles or caps or [longest])
            t.send(B.uci(m))
            t.pump(0.02)
            t.send("\r")
            # a key in its flight, at any moment of it, or none
            flight = rng.choice((None, 0.0, 0.02, 0.05, 0.09, 0.13, 0.18))
            if flight is not None:
                t.pump(flight)
                t.send("\x1b[A")
                t.pump(0.03)
                t.send("\x1b")
            t.pump(0.5)
            why = compare(t)
            done += 1
            if why:
                fails.append(f"round {i}: {B.uci(m)}, a key at {flight}: {why} pixels differ")
            t.send("\x1b")
            t.pump(0.05)
            if t.find("back to the board"):
                t.send("\x1b")
                t.pump(0.05)
        t.close()
        c = crash_text(home)
        if c:
            fails.append(c[-800:])
            break
        if len(fails) > 3:
            break
    # a man dragged: the pointer held and moved over other squares, let go on a square he can reach, on one he cannot, off the board
    fixture(home, FENS[2])
    t = open_app(env)
    t.keep_pixels()
    os.kill(t.pid, signal.SIGCONT)
    t.pump(0.1)
    t.settle(0.3, 5)

    def at(name):
        sq = B.sq_of(name)
        return 8 + sq % 8 * 80 + 41, 8 + (7 - sq // 8) * 80 + 41

    def drag(a, path, b):
        x, y = at(a)
        t.send(f"\x1b[<0;{x};{y}M")
        t.pump(0.05)
        for name in path:
            x, y = at(name)
            for k in range(3):
                t.send(f"\x1b[<32;{x + 7 * k};{y - 5 * k}M")
                t.pump(0.01)
        x, y = b if isinstance(b, tuple) else at(b)
        t.send(f"\x1b[<32;{x};{y}M")
        t.pump(0.01)
        t.send(f"\x1b[<0;{x};{y}m")
        t.pump(0.3)

    played = lambda: (current(home) or {"moves": []})["moves"]  # noqa: E731
    drag("b1", ("b2", "b3", "c3"), "a6")                         # (no such move: he goes home)
    why = compare(t)
    if why or played():
        fails.append(f"a drag let go on a square he cannot reach: {why}, {played()}")
    drag("b1", ("c2", "d3"), (2000, 500))                        # (off the board)
    why = compare(t)
    if why or played():
        fails.append(f"a drag let go off the board: {why}, {played()}")
    t.send("\x1b")                                              # (nothing in hand; the menu shut again)
    t.pump(0.1)
    if t.find("back to the board"):
        t.send("\x1b")
        t.pump(0.1)
    drag("g1", ("g2", "f2", "f3"), "f3")                         # (a move, by the pointer)
    t.pump(0.5)
    why = compare(t)
    done += 3
    if why or played()[:1] != ["g1f3"]:
        fails.append(f"a drag let go on its square: {why}, {played()}")
    t.close()
    c = crash_text(home)
    if c:
        fails.append(c[-800:])
    print(f"{done} moves looked at, {len(fails)} left something behind")
    for f in fails[:5]:
        print(f)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
