#!/usr/bin/env python3
"""tests/yazi/drive.py — a terminal program driven by keys, the way a person at foot would.

    python3 drive.py [--size 100x30] [--cwd DIR] -- PROGRAM ARG… <<'EOF'
    wait TEXT            until TEXT is on the screen (5 s, else a failure with the screen)
    gone TEXT            until TEXT is no longer on the screen
    key KEYS             keys: plain text, or <Enter> <Esc> <Down> <Up> <Left> <Right> <Tab>
                         <Space> <Backspace> <C-a>…; nothing else is sent with them
    settle               until the screen has not changed for 0.15 s
    resize COLSxROWS     the terminal takes that size (as a tiled window does when windows
                         come and go): what was on the screen stays where it fits, the
                         program is told (SIGWINCH) and redraws
    waitfile PATH        until PATH exists
    ($VARIABLES in a step's argument are the environment's)
    screen               print the screen (one line per row, trailing spaces cut)
    lit                  print, per row, the text drawn on a coloured ground (highlights)
    quit [KEY]           KEY (default q), then wait for the program to end (3 s, else killed)
    EOF

The screen is a small VT: cursor moves, erasing, wide (CJK) characters, the alternate
screen; colours are only kept as "on a coloured ground or not". Of the program's questions
only "who are you" (DA1) is answered — a VT220 without pictures; yazi waits 5 s for that
answer when it ends, as it would on a terminal that never says.
Exit status: 0 every step held; 1 a step timed out (the screen goes to stderr); 2 misuse.
"""
import os
import pty
import re
import select
import signal
import struct
import sys
import termios
import fcntl
import codecs
import time
import unicodedata

KEYS = {"Enter": "\r", "Esc": "\x1b", "Down": "\x1b[B", "Up": "\x1b[A", "Right": "\x1b[C",
        "Left": "\x1b[D", "Tab": "\t", "Space": " ", "Backspace": "\x7f", "lt": "<"}


def width(ch):
    if unicodedata.combining(ch) or ch in "​‍️":
        return 0
    return 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1


class Screen:
    def __init__(self, cols, rows):
        self.cols, self.rows = cols, rows
        self.clear()
        self.x = self.y = 0
        self.bg = False
        self.saved = (0, 0)
        self.pending = ""
        self.replies = []        # answers owed to the program's questions
        self.dec = codecs.getincrementaldecoder("utf-8")(errors="replace")
        self.changed = time.time()

    def clear(self):
        self.cells = [[" "] * self.cols for _ in range(self.rows)]
        self.lit = [[False] * self.cols for _ in range(self.rows)]

    def put(self, ch):
        w = width(ch)
        if w == 0:
            return
        if self.x + w > self.cols:
            self.x, self.y = 0, min(self.y + 1, self.rows - 1)
        self.cells[self.y][self.x] = ch
        self.lit[self.y][self.x] = self.bg
        if w == 2 and self.x + 1 < self.cols:
            self.cells[self.y][self.x + 1] = ""
            self.lit[self.y][self.x + 1] = self.bg
        self.x += w

    def sgr(self, params):
        ps = [int(p) if p.isdigit() else 0 for p in (params or "0").replace(":", ";").split(";")]
        i = 0
        while i < len(ps):
            p = ps[i]
            if p == 0 or p == 49:
                self.bg = False
            elif 40 <= p <= 47 or 100 <= p <= 107 or p == 7:
                self.bg = True
            elif p == 48:
                self.bg = True
                i += 4 if i + 1 < len(ps) and ps[i + 1] == 2 else 2
            elif p == 38:
                i += 4 if i + 1 < len(ps) and ps[i + 1] == 2 else 2
            elif p == 27:
                self.bg = False
            i += 1

    CSI = re.compile(r"\x1b\[([0-?]*)[ -/]*([@-~])")
    STR = re.compile(r"\x1b[\]P_^].*?(\x07|\x1b\\)", re.S)

    def feed(self, data):
        text = self.pending + self.dec.decode(data)
        self.pending = ""
        i, n = 0, len(text)
        while i < n:
            c = text[i]
            if c == "\x1b":
                if i + 1 >= n:
                    self.pending = text[i:]; break
                nxt = text[i + 1]
                if nxt == "[":
                    m = self.CSI.match(text, i)
                    if not m:
                        self.pending = text[i:]; break      # (the rest comes with the next read)
                    self.csi(m.group(1), m.group(2))
                    i = m.end()
                    continue
                if nxt in "]P_^":
                    m = self.STR.match(text, i)
                    if not m:
                        self.pending = text[i:]; break
                    i = m.end()
                    continue
                if nxt == "7":
                    self.saved = (self.x, self.y)
                elif nxt == "8":
                    self.x, self.y = self.saved
                i += 2
                continue
            if c == "\r":
                self.x = 0
            elif c == "\n":
                self.y = min(self.y + 1, self.rows - 1)
            elif c == "\b":
                self.x = max(0, self.x - 1)
            elif c >= " ":
                self.put(c)
            i += 1
        self.changed = time.time()

    def csi(self, params, final):
        priv = params.startswith(("?", ">", "<", "=", "!"))
        nums = [int(p) if p.isdigit() else None for p in params.lstrip("?><=!").split(";")] if params else []
        a = nums[0] if nums and nums[0] is not None else None
        if priv:
            if final in "hl" and params[1:] in ("1049", "47", "1047"):
                self.clear()
            return
        if final == "c" and params in ("", "0"):          # who are you? — a VT220 (no pictures)
            self.replies.append(b"\x1b[?62;22c")
            return
        if final == "H" or final == "f":
            r = nums[0] if nums and nums[0] else 1
            c = nums[1] if len(nums) > 1 and nums[1] else 1
            self.y, self.x = min(r, self.rows) - 1, min(c, self.cols) - 1
        elif final == "A":
            self.y = max(0, self.y - (a or 1))
        elif final == "B":
            self.y = min(self.rows - 1, self.y + (a or 1))
        elif final == "C":
            self.x = min(self.cols - 1, self.x + (a or 1))
        elif final == "D":
            self.x = max(0, self.x - (a or 1))
        elif final == "G":
            self.x = min(self.cols, a or 1) - 1
        elif final == "d":
            self.y = min(self.rows, a or 1) - 1
        elif final == "J":
            if a == 2 or a == 3:
                self.clear()
            elif not a:
                for x in range(self.x, self.cols):
                    self.cells[self.y][x] = " "
                for y in range(self.y + 1, self.rows):
                    self.cells[y] = [" "] * self.cols
        elif final == "K":
            rng = range(self.x, self.cols) if not a else range(0, self.x + 1) if a == 1 else range(self.cols)
            for x in rng:
                self.cells[self.y][x] = " "
                self.lit[self.y][x] = self.bg
        elif final == "X":
            for x in range(self.x, min(self.cols, self.x + (a or 1))):
                self.cells[self.y][x] = " "
        elif final == "m":
            self.sgr(params)
        elif final == "s":
            self.saved = (self.x, self.y)
        elif final == "u":
            self.x, self.y = self.saved

    def resize(self, cols, rows):
        cells, lit = self.cells, self.lit
        self.cols, self.rows = cols, rows
        self.clear()
        for y in range(min(rows, len(cells))):
            for x in range(min(cols, len(cells[y]))):
                self.cells[y][x], self.lit[y][x] = cells[y][x], lit[y][x]
        self.x, self.y = min(self.x, cols - 1), min(self.y, rows - 1)
        self.changed = time.time()

    def text(self):
        return "\n".join("".join(r).rstrip() for r in self.cells)

    def lit_text(self):
        out = []
        for y in range(self.rows):
            s = "".join(c if self.lit[y][x] else "\x00" for x, c in enumerate(self.cells[y]))
            parts = [p.strip() for p in s.split("\x00") if p.strip()]
            out.append(" | ".join(parts))
        return "\n".join(out)


def keys(spec):
    def one(m):
        k = m.group(1)
        if k in KEYS:
            return KEYS[k]
        if k.startswith("C-") and len(k) == 3:
            return chr(ord(k[2].lower()) - 96)
        return m.group(0)
    return re.sub(r"<([\w-]+)>", one, spec)


def main(argv):
    size, cwd = "100x30", None
    while argv and argv[0] != "--":
        if argv[0] == "--size":
            size = argv[1]; argv = argv[2:]
        elif argv[0] == "--cwd":
            cwd = argv[1]; argv = argv[2:]
        else:
            print(f"drive.py: unknown option {argv[0]}", file=sys.stderr); return 2
    if not argv[1:]:
        print("usage: drive.py [--size COLSxROWS] [--cwd DIR] -- PROGRAM ARG…", file=sys.stderr)
        return 2
    cols, rows = map(int, size.split("x"))
    script = sys.stdin.read().splitlines()
    pid, fd = pty.fork()
    if pid == 0:
        if cwd:
            os.chdir(cwd)
            os.environ["PWD"] = cwd           # (yazi starts where $PWD says, as a shell's child would)
        os.environ.setdefault("TERM", "xterm-256color")
        try:
            os.execvp(argv[1], argv[1:])
        except OSError as e:
            print(e); os._exit(127)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    scr = Screen(cols, rows)
    alive = [True]

    def pump(t):
        end = time.time() + t
        while True:
            left = end - time.time()
            r, _, _ = select.select([fd], [], [], max(0, min(left, 0.02)))
            if r:
                try:
                    d = os.read(fd, 65536)
                except OSError:
                    d = b""
                if not d:
                    alive[0] = False
                    return
                scr.feed(d)
                while scr.replies:
                    os.write(fd, scr.replies.pop(0))
            if time.time() >= end:
                return

    def ended():
        """the program itself has ended (whatever it left running still holding the terminal)"""
        if alive[0]:
            try:
                if os.waitpid(pid, os.WNOHANG)[0] == pid:
                    alive[0] = False
                    alive.append("reaped")
            except ChildProcessError:
                alive[0] = False
        return not alive[0]

    def until(cond, t=5.0):
        end = time.time() + t
        while time.time() < end:
            if cond():
                return True
            pump(0.03)
            if not alive[0]:
                return cond()
        return cond()

    def fail(why):
        print(f"drive.py: {why}\n--- screen ---\n{scr.text()}\n--------------", file=sys.stderr)
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        return 1

    def squash(s):
        return re.sub(r"\s+", "", s)

    pump(0.05)
    for ln in script:
        ln = ln.strip()
        if not ln or ln.startswith("#"):
            continue
        cmd, _, arg = ln.partition(" ")
        arg = os.path.expandvars(arg)
        if cmd == "wait":
            if not until(lambda: squash(arg) in squash(scr.text())):
                return fail(f"never on the screen: {arg}")
        elif cmd == "gone":
            if not until(lambda: squash(arg) not in squash(scr.text())):
                return fail(f"still on the screen: {arg}")
        elif cmd == "key":
            os.write(fd, keys(arg).encode())
            pump(0.08)
        elif cmd == "settle":
            until(lambda: time.time() - scr.changed > 0.15, 5)
        elif cmd == "resize":
            cols, rows = map(int, arg.split("x"))
            scr.resize(cols, rows)
            fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
            pump(0.1)
        elif cmd == "sleep":
            pump(float(arg))
        elif cmd == "waitfile":
            if not until(lambda: os.path.exists(arg)):
                return fail(f"never made: {arg}")
        elif cmd == "screen":
            print(scr.text())
        elif cmd == "lit":
            print(scr.lit_text())
        elif cmd == "quit":
            os.write(fd, keys(arg or "q").encode())
            if not until(ended, 3):
                return fail("did not end")
        else:
            print(f"drive.py: unknown step {ln}", file=sys.stderr)
            os.kill(pid, signal.SIGKILL)
            return 2
    if alive[0]:
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    if "reaped" not in alive:
        try:
            os.waitpid(pid, 0)
        except ChildProcessError:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
