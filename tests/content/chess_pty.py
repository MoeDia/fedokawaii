#!/usr/bin/env python3
"""tests/content/chess_pty.py — kawa-chess in a terminal of its own, seen as foot would show it: its text on a
grid, its sixels counted and parsed for their places. Used by test_chess*.sh and chess_fuzz.py.
"""
import fcntl
import os
import pty
import re
import select
import signal
import struct
import termios
import time

_SEQ = re.compile(rb"\x1b\[([?]?)([0-9;:]*)([ -/]*)([@-~])")
_RASTER = re.compile(rb'"(\d+);(\d+);(\d+);(\d+)')
_SIX = re.compile(rb"#(\d+)(?:;2;\d+;\d+;\d+)?|!(\d+)([?-~])|([?-~])|(\$)|(-)")


class Tty:
    def __init__(self, argv, cols=126, rows=33, env=None, cw=8, ch=20, mood="dark"):
        self.cols, self.rows, self.cw, self.ch = cols, rows, cw, ch
        self.mood = mood
        self.grid = [[" "] * cols for _ in range(rows)]
        self.ink = [[None] * cols for _ in range(rows)]
        self.cur = (0, 0)
        self.sgr = None
        self.sixels = 0
        self.six_bytes = 0
        self.fb = None
        self.pending = b""
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            if env is not None:
                os.environ.clear()
                os.environ.update(env)
            try:
                os.execvp(argv[0], argv)
            finally:
                os._exit(127)
        self.resize(cols, rows, signal_it=False)
        self.status = None
        self.log = b""
        self.keep_log = False

    def resize(self, cols, rows, signal_it=True):
        self.cols, self.rows = cols, rows
        self.grid = [[" "] * cols for _ in range(rows)]
        self.ink = [[None] * cols for _ in range(rows)]
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, cols * self.cw, rows * self.ch))
        if signal_it:
            try:
                os.kill(self.pid, signal.SIGWINCH)
            except ProcessLookupError:
                pass

    def alive(self):
        if self.status is not None:
            return False
        try:
            p, st = os.waitpid(self.pid, os.WNOHANG)
        except ChildProcessError:
            self.status = -1
            return False
        if p:
            self.status = os.waitstatus_to_exitcode(st)
            return False
        return True

    def send(self, data):
        if isinstance(data, str):
            data = data.encode()
        try:
            os.write(self.fd, data)
        except OSError:
            pass

    def pump(self, seconds=0.2):
        """Read and draw what comes for this long (or until it has been quiet that long after output)."""
        end = time.monotonic() + seconds
        while True:
            left = end - time.monotonic()
            if left <= 0:
                return
            r, _, _ = select.select([self.fd], [], [], min(left, 0.05))
            if r:
                try:
                    data = os.read(self.fd, 1 << 20)
                except OSError:
                    return
                if not data:
                    return
                if self.keep_log:
                    self.log += data
                self.feed(data)

    def settle(self, quiet=0.4, limit=12.0):
        """Pump until something came and nothing more has for `quiet` seconds: a program up and drawn, however loaded the machine."""
        end = time.monotonic() + limit
        seen = 0.0
        while time.monotonic() < end:
            r, _, _ = select.select([self.fd], [], [], quiet)
            if not r:
                if seen:
                    return
                continue
            try:
                data = os.read(self.fd, 1 << 20)
            except OSError:
                return
            if not data:
                return
            seen = time.monotonic()
            if self.keep_log:
                self.log += data
            self.feed(data)

    def wait(self, text, seconds=10.0):
        """Pump until text is on the grid; True if it came."""
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            self.pump(0.05)
            if self.find(text):
                return True
            if not self.alive():
                self.pump(0.05)
                return self.find(text)
        return False

    def ended(self, seconds=5.0):
        """Pump until the program has ended; True if it has."""
        end = time.monotonic() + seconds
        while self.alive() and time.monotonic() < end:
            self.pump(0.03)
        return not self.alive()

    def feed(self, data):
        buf = self.pending + data
        self.pending = b""
        i, n = 0, len(buf)
        while i < n:
            c = buf[i]
            if c == 0x1b:
                if i + 1 >= n:
                    self.pending = buf[i:]
                    return
                nxt = buf[i + 1]
                if nxt == 0x5b:
                    m = _SEQ.match(buf, i)
                    if not m:
                        if n - i < 64:
                            self.pending = buf[i:]
                            return
                        i += 2
                        continue
                    self._csi(m[1], m[2], m[4])
                    i = m.end()
                    continue
                if nxt == 0x50:
                    e = buf.find(b"\x1b\\", i)
                    if e < 0:
                        self.pending = buf[i:]
                        return
                    self.sixels += 1
                    self.six_bytes += e - i
                    if self.fb is not None:
                        self._lay_sixel(buf[i:e])
                    i = e + 2
                    continue
                i += 2
                continue
            if c < 0x20 or c == 0x7f:
                if c == 0x0d:
                    self.cur = (self.cur[0], 0)
                elif c == 0x0a:
                    self.cur = (min(self.rows - 1, self.cur[0] + 1), self.cur[1])
                i += 1
                continue
            # a run of text, UTF-8
            e = i
            while e < n and buf[e] >= 0x20 and buf[e] != 0x7f:
                e += 1
            run = buf[i:e]
            try:
                t = run.decode("utf-8")
            except UnicodeDecodeError as err:
                if e == n and err.start > len(run) - 4:
                    t = run[:err.start].decode("utf-8", "replace")
                    self.pending = run[err.start:]
                    e = i + err.start
                else:
                    t = run.decode("utf-8", "replace")
            r, co = self.cur
            for ch in t:
                if 0 <= r < self.rows and 0 <= co < self.cols:
                    self.grid[r][co] = ch
                    self.ink[r][co] = self.sgr
                co += 1
            self.cur = (r, min(co, self.cols - 1))
            if self.pending:
                return
            i = e

    def keep_pixels(self):
        """From now on every sixel is laid on a picture of the window as a terminal would, by its inks' numbers: self.fb."""
        self.fb_w, self.fb_h = self.cols * self.cw, self.rows * self.ch
        self.fb = bytearray(self.fb_w * self.fb_h)

    def _lay_sixel(self, dcs):
        y0, x0 = self.cur[0] * self.ch, self.cur[1] * self.cw
        W, H, fb = self.fb_w, self.fb_h, self.fb
        body = dcs[dcs.index(b"q") + 1:]
        limit_w = limit_h = None
        raster = _RASTER.match(body)
        if raster:
            limit_w, limit_h = int(raster[3]), int(raster[4])
            body = body[raster.end():]
        x = y = ink = 0
        for tok in _SIX.finditer(body):
            if tok[1] is not None:
                ink = int(tok[1])
            elif tok[2] is not None or tok[4] is not None:
                n, code = (int(tok[2]), tok[3][0]) if tok[2] is not None else (1, tok[4][0])
                bits = code - 63
                for b in range(6):
                    if bits >> b & 1 and (limit_h is None or y + b < limit_h):
                        py = y0 + y + b
                        if 0 <= py < H:
                            for k in range(n):
                                px = x0 + x + k
                                if 0 <= px < W and (limit_w is None or x + k < limit_w):
                                    fb[py * W + px] = ink
                x += n
            elif tok[5] is not None:
                x = 0
            elif tok[6] is not None:
                x = 0
                y += 6

    def pixels(self, x, y, w, h):
        """A part of self.fb, row by row."""
        return [bytes(self.fb[r * self.fb_w + x:r * self.fb_w + x + w]) for r in range(y, y + h)]

    def _csi(self, lead, params, final):
        p = [int(x or 0) for x in params.split(b";")] if params and b":" not in params else []
        if lead == b"?":
            if final == b"n" and params == b"996":     # the colour scheme asked: foot answers
                self.send(b"\x1b[?997;%dn" % (1 if self.mood == "dark" else 2))
            return
        if final == b"H":
            self.cur = ((p[0] if p else 1) - 1, (p[1] if len(p) > 1 else 1) - 1)
        elif final == b"J":
            self.grid = [[" "] * self.cols for _ in range(self.rows)]
            self.ink = [[None] * self.cols for _ in range(self.rows)]
        elif final == b"K":
            r, co = self.cur
            if 0 <= r < self.rows:
                for x in range(co, self.cols):
                    self.grid[r][x] = " "
        elif final == b"m":
            self.sgr = params.decode()

    def text(self):
        return ["".join(r).rstrip() for r in self.grid]

    def find(self, s):
        return any(s in ln for ln in self.text())

    def screen(self):
        return "\n".join(self.text())

    def close(self):
        try:
            os.kill(self.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        end = time.monotonic() + 2
        while self.alive() and time.monotonic() < end:
            self.pump(0.02)
        if self.alive():
            try:
                os.kill(self.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        try:
            os.close(self.fd)
        except OSError:
            pass
        return self.status
