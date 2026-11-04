#!/usr/bin/env python3
"""chess_sweep.py DIR — every key, in turn, on every screen of kawa-chess, at three sizes, in both moods. A screen is reached
by its keys from a prepared state; a key that leaves it is followed by coming back. No traceback, no crash file, no hang."""
import json
import pathlib
import shutil
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from chess_lib import B, crash_text, make_home, open_app, state  # noqa: E402

KEYS = ["\r", "\x1b", "\t", "\x1b[Z", "\x1b[A", "\x1b[B", "\x1b[C", "\x1b[D", "\x7f", " ", "?", "t", "q", "r", "b", "n", "x", "O", "0", "=", "+", "#", "e", "4", "8", "a", "1", "\x1b[5~", "\x1b[6~", "\x1b[H", "\x1b[F", "\x1b[3~", "\x01", "\x04", "\x0c", "\x1a", "é", "\x1b[15~", "\x1b[1;5A", "\x1bOP"]
SCREENS = {        # name → the keys that reach it from the first screen, what state it needs
    "today": "", "lessons": "\t", "puzzles": "\t\t", "games": "\t\t\t", "progress": "\t\t\t\t",
    "free": "\t\t\t\r", "lesson-find": "\r\r", "squares": "\t\t\x1b[B\r", "game": "\t\t\t\r\x1b[B\x1b[B\r", "game-menu": "\t\t\t\r\x1b[B\x1b[B\r\x1b", "session": "\t\t\r",
    "review": "@review", "report": "@report", "resume": "@resume", "replay": "@replay",
}
SIZES = ((60, 20), (126, 33), (236, 51))


def prepare(home, name):
    st = state(home)
    shutil.rmtree(st, ignore_errors=True)
    (st / "games").mkdir(parents=True)
    if name in ("@review", "@replay"):
        (st / "games/1.pgn").write_text('[White "you"]\n[Black "x"]\n[Result "0-1"]\n\n1. e4 e5 2. Qg4 Nf6 3. Qg5 Nxe4 4. d3 Nxg5 0-1\n')
        (st / "progress.json").write_text(json.dumps({"items": {"1/lesson-the-board": "x", "1/game1": "x"}, "played": {"1": {"score": "loss", "elo": 500, "t": 1, "me": 0, "times": [3] * 4, "check": "safe", "goal": "be safe"}}}))
    elif name == "@report":
        items = {f"7/{k}": "x" for k in ("lesson-the-pawn", "game13", "review13", "puzzles7", "game14", "review14")}
        (st / "progress.json").write_text(json.dumps({"day": 7, "items": items}))
    elif name == "@resume":
        spec = dict(title="x", goal="a goal", fen=B.START, line=[], colour=1, elo=500, clock=[1, 0], hints=2, threats=True, opponent="x", no=None)
        (st / "current.json").write_text(json.dumps(dict(spec=spec, moves=["e2e4"], clock=[50.0, 50.0], times=[], hints_used=0)))


def main(argv):
    root = pathlib.Path(argv[1])
    home, env = make_home(root)
    n = 0
    for mood in ("dark", "light"):
        for cols, rows in SIZES:
            for name, path in SCREENS.items():
                prepare(home, path)
                t = open_app(env, cols, rows, mood=mood)

                enter(t, path)
                for k in KEYS:
                    t.send(k)
                    t.pump(0.02)
                    n += 1
                    c = crash_text(home)
                    if c:
                        print(f"crash on {name} key {k!r}:\n{c[-1200:]}")
                        return 1
                    if not t.alive():
                        if t.status != 0:
                            print(f"died on {name} key {k!r}, status {t.status}\n{t.screen()[:400]}")
                            return 1
                        t = open_app(env, cols, rows, mood=mood)
                        enter(t, path)
                t.close()
    trace = root / "trace"
    cut = sorted({ln for ln in (trace.read_text().splitlines() if trace.exists() else []) if ln.startswith("cut\t")})
    if cut:
        print("words cut at the panel's edge:\n" + "\n".join(cut[:30]))
        return 1
    print(f"{n} keys, no crash, nothing cut")
    return 0


def enter(t, path):
    """The keys that reach a screen."""
    if path in ("@review", "@report"):
        t.send("\r")
        t.pump(0.5)
    elif path == "@replay":
        for k in ("\t", "\t", "\t", "\x1b[B", "\r"):
            t.send(k)
            t.pump(0.03)
    elif not path.startswith("@"):
        for k in _split(path):
            t.send(k)
            t.pump(0.03)
    t.pump(0.05)


def _split(path):
    """Keys of a path, escapes whole."""
    out, i = [], 0
    while i < len(path):
        if path.startswith("\x1b[", i):
            out.append(path[i:i + 3])
            i += 3
        else:
            out.append(path[i])
            i += 1
    return out


if __name__ == "__main__":
    sys.exit(main(sys.argv))
