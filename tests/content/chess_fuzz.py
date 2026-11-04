#!/usr/bin/env python3
"""chess_fuzz.py DIR SECONDS SEED [STOCKFISH] — kawa-chess under everything a keyboard, a mouse, a window manager and a bad
day can do: random keys and floods, pastes, clicks, drags and wheels in every place, focus and theme reports, resizes from
nothing to huge, legal moves too so that games really advance, its engine killed, the program killed and restarted, its
files damaged between runs. Fails on a traceback, a crash file, a hang (no answer to a resize) or an exit it was not asked for.
"""
import json
import os
import pathlib
import random
import signal
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from chess_lib import B, crash_text, current, make_home, open_app, state  # noqa: E402

KEYS = ["\r", "\x1b", "\t", "\x1b[Z", "\x1b[A", "\x1b[B", "\x1b[C", "\x1b[D", "\x7f", " ", "?", "t", "\x1b[5~", "\x1b[6~", "\x1b[H", "\x1b[F", "\x1b[3~", "\x1bOA", "\x1b[1;5C", "\x1b[15~"]
WORDS = ["e4", "Nf3", "nf3", "O-O", "oo", "0-0-0", "exd5", "a8=Q", "Qxf7#", "hello", "é", "日本語", "🙂", "\x00", "\x07", "\x1b]0;x\x07", "\x1bP1;2q\x1b\\", "\x1b[?997;1n", "\x1b[?997;2n", "\x1b[I", "\x1b[O", "\x1b[999;999H", "\x1b[<0;1;1M", "\x1b[<99;9999;9999M", "\x1b[<0;;M", "\x1b[200~", "\x1b[201~"]
SIZES = [(60, 20), (61, 21), (64, 24), (80, 24), (86, 24), (100, 33), (126, 33), (60, 45), (118, 50), (236, 51), (40, 12), (10, 5), (1, 1), (300, 90), (59, 19), (42, 17), (43, 18)]


def children(pid):
    """This program's own child processes: its engine."""
    try:
        return [int(x) for x in pathlib.Path(f"/proc/{pid}/task/{pid}/children").read_text().split()]
    except OSError:
        return []


class Fuzz:
    def __init__(self, root, seed, engine=None):
        self.rng = random.Random(seed)
        self.root = pathlib.Path(root)
        self.home, self.env = make_home(self.root, real_engine=engine)
        self.t = None
        self.actions = self.restarts = 0
        self.fail = []
        self.start_app()

    def start_app(self):
        size = self.rng.choice(SIZES[:10])
        self.t = open_app(self.env, *size, mood=self.rng.choice(("dark", "light")))
        self.t.keep_log = True
        self.restarts += 1

    def check(self):
        t = self.t
        if b"Traceback" in t.log or b"Error:" in t.log:
            i = t.log.find(b"Traceback")
            self.fail.append("traceback on screen: " + t.log[max(0, i):i + 800].decode("utf-8", "replace"))
        t.log = t.log[-200:]
        c = crash_text(self.home)
        if c:
            self.fail.append("crash.log: " + c[-1500:])

    def legal_move(self):
        saved = current(self.home)
        if not saved:
            return None
        try:
            pos = B.Position(saved["spec"]["fen"])
            for u in saved["moves"]:
                pos.push(B.from_uci(u))
        except (ValueError, KeyError, TypeError):
            return None
        ms = pos.legal()
        return B.uci(self.rng.choice(ms)) if ms and pos.turn == saved["spec"].get("colour") else None

    def step(self):
        r = self.rng.random()
        t = self.t
        self.actions += 1
        if r < 0.40:
            t.send(self.rng.choice(KEYS))
        elif r < 0.55:
            t.send(self.rng.choice(WORDS))
        elif r < 0.65:
            m = self.legal_move()
            if m:
                t.send(m + "\r")
                t.pump(0.05)
        elif r < 0.75:
            x, y = self.rng.randrange(1, t.cols * 8 + 40), self.rng.randrange(1, t.rows * 20 + 40)
            b = self.rng.choice((0, 0, 0, 1, 2, 32, 35, 64, 65))
            t.send(f"\x1b[<{b};{x};{y}{self.rng.choice('Mm')}")
        elif r < 0.80:
            t.send(bytes(self.rng.randrange(256) for _ in range(self.rng.randrange(1, 300))))
        elif r < 0.84:
            t.send("".join(self.rng.choice(KEYS) for _ in range(self.rng.randrange(5, 120))))
        elif r < 0.87:
            t.send("\x1b[200~" + "".join(self.rng.choice("e4 Nf3\n\r\t?é日") for _ in range(self.rng.randrange(200))) + "\x1b[201~")
        elif r < 0.93:
            t.resize(*self.rng.choice(SIZES))
        elif r < 0.95:
            for c in children(t.pid):
                try:
                    os.kill(c, signal.SIGKILL)
                except ProcessLookupError:
                    pass
        elif r < 0.96:
            try:
                os.kill(t.pid, signal.SIGSTOP)
                time.sleep(0.05)
                os.kill(t.pid, signal.SIGCONT)
            except ProcessLookupError:
                pass
        elif r < 0.985:
            self.tour()
        else:
            self.restart(self.rng.choice(("kill", "term", "ctrl-c", "hup")))
        t.pump(self.rng.choice((0.0, 0.0, 0.01, 0.03, 0.1)))
        self.check()
        if not t.alive() and t.status not in (0,):
            # (killed by the fuzz; or a control key of its own in the instant before the tty is raw: Ctrl+C, Ctrl+\\)
            if t.status not in (-9, -15, -3, -2, -1, 137, 143):
                self.fail.append(f"died by itself: status {t.status}\n" + t.screen()[:400])
            self.start_app()
        elif not t.alive():
            self.start_app()

    def tour(self):
        """Into whichever screen comes: lessons, puzzles, games; deep, with the keys that go forward."""
        t = self.t
        for _ in range(self.rng.randrange(1, 5)):
            t.send("\t")
        for _ in range(self.rng.randrange(0, 12)):
            t.send("\x1b[B")
        t.send("\r")
        t.pump(0.05)
        for _ in range(self.rng.randrange(1, 15)):
            t.send(self.rng.choice(("\r", " ", "\x1b[C", "a1", "e4", "\x1b")))
            t.pump(0.02)

    def restart(self, how):
        t = self.t
        try:
            os.kill(t.pid, signal.SIGCONT)   # (stopped by a Ctrl+Z of the fuzz before the tty was raw)
        except ProcessLookupError:
            pass
        if how == "kill":
            os.kill(t.pid, signal.SIGKILL)
        elif how == "term":
            os.kill(t.pid, signal.SIGTERM)
        elif how == "hup":
            os.kill(t.pid, signal.SIGHUP)
        else:
            t.send("\x1b[201~")    # (a paste left open by the fuzz ends first: foot's always end)
            t.pump(0.05)
            t.send("\x03")
        t.pump(0.3)
        end = time.time() + 4
        while t.alive() and time.time() < end:
            t.pump(0.05)
        self.check()
        if t.alive():
            self.fail.append(f"did not stop on {how}\n" + t.screen()[:300])
            os.kill(t.pid, signal.SIGKILL)
            t.pump(0.1)
        self.damage()
        self.start_app()

    def damage(self):
        """Between runs: a state file cut, swapped for garbage, of the wrong shape; a game of nonsense."""
        st = state(self.home)
        if not st.exists() or self.rng.random() < 0.5:
            return
        name = self.rng.choice(("progress.json", "current.json", "progress.json.bak", "current.json.bak"))
        p = st / name
        k = self.rng.randrange(6)
        try:
            if k == 0 and p.exists():
                b = p.read_bytes()
                p.write_bytes(b[:self.rng.randrange(len(b) + 1)])
            elif k == 1:
                p.write_bytes(bytes(self.rng.randrange(256) for _ in range(200)))
            elif k == 2:
                p.write_text(self.rng.choice(("[]", "{}", "null", "7", '"x"', '{"day": "x", "items": 3, "game": [], "played": 9, "due": 1, "history": 2}',
                                              '{"day": 100000}', '{"day": -3, "seen": [1, 2], "puzzle": {"r": "x"}}',
                                              '{"due": {"x": 5}, "played": {"1": 7}, "history": [1, [2], "x"]}', '{"lessons": {"the-rook": 999}}',
                                              '{"spec": {"fen": "8/8/8/8/8/8/8/8 w - - 0 1", "colour": 0, "elo": 500}, "moves": []}',
                                              '{"spec": {"fen": "7k/8/8/8/8/8/8/K5Q1 w - - 0 1", "colour": 3, "elo": "x"}, "moves": "e2e4"}',
                                              '{"spec": {"fen": "7k/8/8/8/8/8/8/K5Q1 w - - 0 1", "colour": 0, "elo": 500, "clock": "x", "line": [9]}, "moves": []}')))
            elif k == 3 and p.exists():
                p.unlink()
            elif k == 4:
                games = list(st.glob("games/*.pgn"))
                if games:
                    self.rng.choice(games).write_bytes(b"\xff not a game \x00")
            elif k == 5:
                j = {"spec": {"title": "x", "fen": "4k3/1P5P/8/8/8/8/p6p/4K3 w - - 98 80", "colour": 0, "elo": 300, "clock": [0, 0], "hints": 9}, "moves": [], "clock": [0.5, 0.5]}
                (st / "current.json").write_text(json.dumps(j))
        except OSError:
            pass


def main(argv):
    root, seconds, seed = argv[1], float(argv[2]), int(argv[3])
    f = Fuzz(root, seed, argv[4] if len(argv) > 4 else None)
    end = time.time() + seconds
    while time.time() < end and not f.fail:
        f.step()
    f.t.close()
    print(f"fuzz: {f.actions} actions, {f.restarts} runs, {len(f.fail)} failures")
    for x in f.fail[:3]:
        print(x)
    return 1 if f.fail else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
