#!/usr/bin/env python3
"""chess_games.py DIR STOCKFISH N — N free games through the keyboard against the real Stockfish, from the lowest level
up: a move picked by rule for White or Black by turns; each PGN then replayed into Stockfish, which must arrive at the same
position (it stops silently at an illegal move). Prints: games N replayed M crash '…'."""
import pathlib
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from chess_lib import B, crash_text, current, make_home, open_app, start_free_game, state  # noqa: E402


def main(argv):
    root, sf_path, n = pathlib.Path(argv[1]), argv[2], int(argv[3])
    home, env = make_home(root, real_engine=sf_path)
    played = 0
    steps_list = [-16, -14, -12, -10, -8, -6, -4, -2, 0, 2, 4, 6, 8, -15, -13, -11, -9, -7, -5, -3]
    for i in range(n):
        t = open_app(env)
        start_free_game(t, colour=i % 2, level_steps=steps_list[i % len(steps_list)])
        end = time.time() + 75
        while time.time() < end and t.alive():
            saved = current(home)
            if saved is None:
                if t.find("you won") or t.find("you lost") or t.find("a draw"):
                    played += 1
                    t.send("\r")
                    t.pump(0.2)
                    t.send("\r")          # (the review, left at once)
                    t.pump(0.1)
                    t.send("\x1b")
                    t.pump(0.1)
                    break
                t.pump(0.05)
                continue
            pos = B.Position(saved["spec"]["fen"])
            for u in saved["moves"]:
                pos.push(B.from_uci(u))
            if pos.turn == saved["spec"]["colour"] and pos.has_legal():
                ms = pos.legal()
                # (a capture if there is one, else by turns through the list: games that end)
                caps = [m for m in ms if pos.is_capture(m)]
                m = caps[0] if caps else ms[len(saved["moves"]) * 7 % len(ms)]
                t.send(B.uci(m))
                t.pump(0.01)
                t.send("\r")
                t.pump(0.26)
            else:
                t.pump(0.06)
        else:
            # (out of time: it stays open, resign it)
            t.send("\x1b")
            t.pump(0.1)
            t.send("\x1b[A\x1b[A\r")
            t.pump(0.2)
            played += 1 if current(home) is None else 0
        t.close()
    sf = subprocess.Popen([sf_path], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
    good = 0
    pgns = list(state(home).glob("games/*.pgn"))
    for f in pgns:
        _, g = B.read_pgn(f.read_text())
        sf.stdin.write(f"position fen {g.start} moves {' '.join(B.uci(m) for m in g.moves)}\nd\n")
        sf.stdin.flush()
        while True:
            line = sf.stdout.readline()
            if line.startswith("Fen:"):
                good += line.split()[1:3] == g.pos.fen().split()[:2]
                break
    sf.kill()
    print(f"games {len(pgns)} replayed {good} crash {crash_text(home)!r}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
