#!/usr/bin/env python3
"""chess_puzzles200.py DIR [N] — N puzzles (200) solved and failed by script through the keyboard: right, wrong, right, wrong; the
rating must move both ways, what is missed must be due, nothing must repeat; prints the numbers (T25b's acceptance)."""
import json
import pathlib
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from chess_lib import B, crash_text, go_to_tab, make_home, open_app, state  # noqa: E402


def main(argv):
    root = pathlib.Path(argv[1])
    goal = int(argv[2]) if len(argv) > 2 else 200
    home, env = make_home(root)
    t = open_app(env)
    trace = root / "trace"
    done = seen = 0
    ids, rat = [], []
    while done < goal and t.alive():
        go_to_tab(t, "puzzles")
        t.send("\r")
        t.pump(0.2)
        end = time.time() + 590     # (a sitting is ten minutes: a new one when it is over)
        while done < goal and time.time() < end and t.alive():
            t.pump(0.02)
            lines = trace.read_text().splitlines() if trace.exists() else []
            if len(lines) <= seen:
                continue
            seen = len(lines)
            _, pid, fen, moves, _rating = lines[-1].split("\t")
            ids.append(pid)
            line = moves.split()
            pos = B.Position(fen)
            pos.push(B.from_uci(line[0]))
            t.pump(0.72)
            if done % 2 == 0:
                for i in range(1, len(line), 2):
                    t.send(line[i])
                    t.pump(0.005)
                    t.send("\r")
                    t.pump(0.2)
                    if i + 1 < len(line):
                        t.pump(0.65)
            else:
                wrong = next(m for m in pos.legal() if B.uci(m) != line[1])
                t.send(B.uci(wrong))
                t.pump(0.005)
                t.send("\r")
                t.pump(0.03)
                t.send("\x1b")
                t.pump(0.03)
                t.send("\r")
                t.pump(0.05)
            done += 1
            if done % 20 == 0:
                p = json.loads((state(home) / "progress.json").read_text())
                rat.append(round(p["puzzle"]["r"]))
        t.send("\x1b")
        t.pump(0.1)
        t.send("\x1b")
        t.pump(0.1)
    t.close()
    p = json.loads((state(home) / "progress.json").read_text())
    print(f"{done} puzzles; {len(set(ids))} different; tries {p['tries']}, right the first time {p['first_try']}; rating every 20: {rat}; due {len(p['due'])}; crash {crash_text(home)!r}")
    return 0 if done >= goal and not crash_text(home) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
