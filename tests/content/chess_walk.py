#!/usr/bin/env python3
"""chess_walk.py DIR — every lesson of the year walked through the keyboard, as a learner would: every square found, every
move to find found (a wrong one first where there is one), every drill entered and left; a lesson done is marked done."""
import json
import pathlib
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from chess_lib import B, LIB, crash_text, go_to_tab, make_home, open_app, state  # noqa: E402

sys.path.insert(0, str(LIB))


def main(argv):
    root = pathlib.Path(argv[1])
    home, env = make_home(root)
    import lesson as L
    lib = L.Library(str(home / ".local/share/fedokawaii/chess/lessons.txt"))
    t = open_app(env)
    go_to_tab(t, "lessons")
    bad = []
    t0 = time.time()
    for n, lid in enumerate(lib.index):
        if n:
            t.send("\x1b[B")
            t.pump(0.02)
        t.send("\r")
        t.pump(0.08)
        _, pages = lib.read(lid)
        pos = None
        for pn, pg in enumerate(pages):
            if pg.fen:
                pos = B.Position(pg.fen)
            if pg.plays:
                t.pump(0.05)
                t.send("\r")         # (they land at once)
                t.pump(0.05)
                for san in pg.plays:
                    m = pos.parse_san(san)
                    pos.push(m)
            if pg.find:
                for sq in pg.find:
                    t.send(sq)
                    t.pump(0.015)
            if pg.tries:
                good = pos.parse_san(pg.tries[0])
                wrong = next((m for m in pos.legal() if B.uci(m) not in [B.uci(pos.parse_san(s)) for s in pg.tries]), None)
                if wrong is not None and pn % 2 == 0:
                    t.send(B.uci(wrong))
                    t.pump(0.01)
                    t.send("\r")
                    t.pump(0.03)
                t.send(B.uci(good))
                t.pump(0.01)
                t.send("\r")
                t.pump(0.28)
                pos.push(good)
            if pg.drill:
                if not t.wait("to solve", 15):      # (the bank read the first time: however long the machine takes)
                    bad.append(f"{lid} p{pn + 1}: no drill on the screen")
                for _ in range(40):     # (Esc: the answer, then on, then out: until the lesson is back)
                    t.send("\x1b")
                    t.settle(0.1, 1.0)
                    if not t.find("to solve"):
                        break
            t.send("\r")
            t.pump(0.03)
        t.pump(0.05)
        if not t.alive():
            bad.append(f"{lid}: the program ended")
            break
    t.pump(0.2)
    t.send("\x1b")
    t.pump(0.3)
    t.close()
    p = json.loads((state(home) / "progress.json").read_text())
    undone = [x for x in lib.index if p["lessons"].get(x) != "done"]
    print(f"{len(lib.index)} lessons in {time.time() - t0:.0f} s; not done: {undone[:8]} ({len(undone)}); {bad[:5]}; crash {crash_text(home)!r}")
    return 1 if undone or bad or crash_text(home) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
