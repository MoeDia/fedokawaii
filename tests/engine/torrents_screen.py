"""tests/engine/torrents_screen.py — kawa-torrents' window on a pseudo-terminal, read back as cells: what stands in
each column, in which ink, on which ground, as foot would draw it. Keys go in as a terminal sends them."""
import fcntl
import os
import pty
import re
import select
import signal
import struct
import termios
import time
import unicodedata

CSI = re.compile(rb"\x1b\[([?]?)([0-9;:]*)([ -/]*)([@-~])")


def width(c):
    if unicodedata.category(c) in ("Mn", "Me", "Cf"):
        return 0
    return 2 if unicodedata.east_asian_width(c) in ("W", "F") else 1


class Screen:
    """The little of VT that the window speaks: cursor moves, SGR, erase to the end of the line, 2026."""

    def __init__(self, rows, cols):
        self.resize(rows, cols)
        self.fg = self.bg = None
        self.y = self.x = 0
        self.modes = set()
        self.buf = b""
        self.cursor_on = True
        self.updates = 0

    def resize(self, rows, cols):
        self.rows, self.cols = rows, cols
        self.cells = [[(" ", None, None) for _ in range(cols)] for _ in range(rows)]
        self.y = self.x = 0

    def feed(self, data):
        b = self.buf + data
        i = 0
        while i < len(b):
            if b[i] == 0x1b:
                m = CSI.match(b, i)
                if not m:
                    if len(b) - i < 32:
                        break
                    i += 1
                    continue
                self.csi(m)
                i = m.end()
            elif b[i] in (0x0d, 0x0a, 0x08, 0x07):
                i += 1
            else:
                j = i
                while j < len(b) and b[j] != 0x1b and b[j] >= 0x20:
                    j += 1
                try:
                    text = b[i:j].decode("utf-8")
                except UnicodeDecodeError:
                    if j == len(b) and j - i < 4:
                        break
                    text = b[i:j].decode("utf-8", "replace")
                self.text(text)
                i = j
        self.buf = b[i:]

    def text(self, s):
        for c in s:
            w = width(c)
            if not w:
                continue
            if self.x + w > self.cols:             # (a row that would wrap: never allowed)
                self.overflow = True
                continue
            if self.y < self.rows:
                self.cells[self.y][self.x] = (c, self.fg, self.bg)
                if w == 2:
                    self.cells[self.y][self.x + 1] = ("", self.fg, self.bg)
            self.x += w

    def csi(self, m):
        lead, params, final = m.group(1), m.group(2).decode(), m.group(4)
        if final == b"H":
            p = (params.split(";") + ["1", "1"])[:2]
            self.y, self.x = int(p[0] or 1) - 1, int(p[1] or 1) - 1
        elif final == b"m":
            self.sgr(params)
        elif final == b"K":
            for x in range(self.x, self.cols):
                self.cells[self.y][x] = (" ", None, None)
        elif final == b"J":
            self.cells = [[(" ", None, None) for _ in range(self.cols)] for _ in range(self.rows)]
        elif final in (b"h", b"l") and lead == b"?":
            for n in params.split(";"):
                (self.modes.add if final == b"h" else self.modes.discard)(int(n))
            if params == "2026" and final == b"l":
                self.updates += 1

    def sgr(self, params):
        p = [int(x or 0) for x in params.split(";")] if params else [0]
        k = 0
        while k < len(p):
            if p[k] == 0:
                self.fg = self.bg = None
            elif p[k] == 38 and p[k + 1] == 5:
                self.fg = p[k + 2]
                k += 2
            elif p[k] == 48 and p[k + 1] == 5:
                self.bg = p[k + 2]
                k += 2
            k += 1

    def line(self, y):
        return "".join(c for c, _, _ in self.cells[y])

    def lines(self):
        return [self.line(y) for y in range(self.rows)]

    def dump(self):
        return "\n".join(f"{y:2} |{self.line(y)}|" for y in range(self.rows))

    def find(self, word):
        for y in range(self.rows):
            x = self.line(y).find(word)
            if x >= 0:
                return y, x
        return None

    def ink_at(self, y, x):
        return self.cells[y][x][1:]


class Window:
    """The window itself, from bin/kawa-torrents, on a pty of ROWS × COLS."""

    def __init__(self, cmd, rows=30, cols=100, env=None):
        self.screen = Screen(rows, cols)
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.environ.update(env or {})
            os.execvp(cmd[0], cmd)
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
        self.dead = False

    def pump(self, wait=0.05):
        r, _, _ = select.select([self.fd], [], [], wait)
        if r:
            try:
                data = os.read(self.fd, 1 << 18)
            except OSError:
                self.dead = True
                return False
            if not data:
                self.dead = True
                return False
            self.screen.feed(data)
            return True
        return False

    def settle(self, seconds=0.25):
        """What comes until the screen has been quiet for SECONDS."""
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            if self.pump(0.02):
                end = time.monotonic() + seconds

    def until(self, cond, seconds=15, what="it"):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            self.pump(0.05)
            if cond(self.screen):
                return True
        raise TimeoutError(f"waited {seconds} s for {what}\n{self.screen.dump()}")

    def has(self, word, seconds=15):
        return self.until(lambda s: s.find(word), seconds, repr(word))

    def keys(self, *keys):
        for k in keys:
            os.write(self.fd, k.encode() if isinstance(k, str) else k)
            self.settle(0.08)

    def paste(self, text):
        os.write(self.fd, b"\x1b[200~" + text.encode() + b"\x1b[201~")
        self.settle(0.08)

    def click(self, y, x, button=0):
        os.write(self.fd, f"\x1b[<{button};{x + 1};{y + 1}M\x1b[<{button};{x + 1};{y + 1}m".encode())
        self.settle(0.08)

    def hover(self, y, x):
        os.write(self.fd, f"\x1b[<35;{x + 1};{y + 1}M".encode())
        self.settle(0.08)

    def wheel(self, y, x, up=False):
        os.write(self.fd, f"\x1b[<{64 if up else 65};{x + 1};{y + 1}M".encode())
        self.settle(0.08)

    def resize(self, rows, cols):
        self.screen.resize(rows, cols)
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
        os.kill(self.pid, signal.SIGWINCH)
        self.settle(0.15)

    def close(self, sig=signal.SIGTERM):
        try:
            os.kill(self.pid, sig)
        except ProcessLookupError:
            pass
        end = time.monotonic() + 5
        status = None
        while time.monotonic() < end:
            self.pump(0.02)
            p, status = os.waitpid(self.pid, os.WNOHANG)
            if p:
                os.close(self.fd)
                return status
        os.kill(self.pid, signal.SIGKILL)
        os.waitpid(self.pid, 0)
        os.close(self.fd)
        raise TimeoutError("the window did not end")
