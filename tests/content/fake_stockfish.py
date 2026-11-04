#!/usr/bin/env python3
"""A stand-in for Stockfish that speaks enough UCI for the tests: legal moves from the program's own rules, in a
fixed order, scores by material; answers at once. FAKE_SF_DIE=N: dies at the Nth `go` (the engine killed mid-think).
FAKE_SF_MUTE=N: never answers the Nth `go`. Each of them once: FAKE_SF_ONCE=FILE is the mark that it has happened."""
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.environ["KAWA_CHESS_LIB"])
import board as B  # noqa: E402


def material(pos, side):
    return sum(B.VALUE[p & 7] for p in pos.b if p and p >> 3 & 1 == side and p & 7 != B.KING)


def main():
    pos, multipv, gos = None, 1, 0
    die, mute = int(os.environ.get("FAKE_SF_DIE", 0)), int(os.environ.get("FAKE_SF_MUTE", 0))
    for line in sys.stdin:
        t = line.split()
        if not t:
            continue
        if t[0] == "uci":
            print("id name fake\nuciok", flush=True)
        elif t[0] == "isready":
            print("readyok", flush=True)
        elif t[0] == "setoption" and "MultiPV" in t:
            multipv = int(t[-1])
        elif t[0] == "position":
            fen = " ".join(t[2:8])
            pos = B.Position(fen)
            if "moves" in t:
                for u in t[t.index("moves") + 1:]:
                    pos.push(B.from_uci(u))
        elif t[0] == "go":
            gos += 1
            once = os.environ.get("FAKE_SF_ONCE")
            fresh = not once or not os.path.exists(once)
            if (die and gos == die or mute and gos == mute) and fresh:
                if once:
                    open(once, "w").close()
                if die:
                    os._exit(9)
                continue
            moves = pos.legal()
            if not moves:
                print("info depth 0 score cp 0\nbestmove (none)", flush=True)
                continue
            scored = []
            me = pos.turn
            for m in moves:
                pos.push(m)
                if pos.in_check() and not pos.has_legal():
                    s = 30000
                else:
                    s = 100 * (material(pos, me) - material(pos, 1 - me))
                pos.pop()
                scored.append((-s, B.uci(m)))
            scored.sort()
            for i, (s, u) in enumerate(scored[:multipv], 1):
                print(f"info depth 1 multipv {i} score cp {-s} nodes 1 pv {u}")
            print(f"bestmove {scored[0][1]}", flush=True)
        elif t[0] == "quit":
            return


main()
