"""The terminal: raw mode, keys and the mouse as events, text rows drawn only where they changed.

Rows are made of spans (text, ink, ground); inks are foot's palette past the sixteen, so words follow
a theme switch by themselves (docs/design-system.md §7). Only foot is spoken to: synchronized output
(2026), SGR pixel mouse (1016), colour-scheme reports (2031), sixels.
"""
import fcntl
import os
import re
import select
import signal
import struct
import sys
import termios
import time

# foot's colours past the sixteen (tools/build-themes.py): docs/design-system.md §1, screen.sh
ACCENT, EDGE, EDGE2, ACCENT_TEXT, MUTED, FAINT, STRONG, SELECT, ON_SELECT = 16, 18, 19, 20, 21, 22, 23, 24, 25
TEXT = None                # (the terminal's own foreground)
RED, GREEN, YELLOW, BLUE, TEAL = 1, 2, 3, 4, 14
_CSI = re.compile(rb"\x1b\[([?<>=]?)([0-9;:]*)([ -/]*)([@-~])")
_KEYS = {b"A": "up", b"B": "down", b"C": "right", b"D": "left", b"H": "home", b"F": "end", b"Z": "shift-tab"}
_TILDE = {b"3": "delete", b"5": "pageup", b"6": "pagedown", b"1": "home", b"4": "end", b"7": "home", b"8": "end"}


def ink_seq(fg, bg=None, bold=False, under=False):
    out = "\x1b[0"
    if fg is not None:
        out += f";38;5;{fg}"
    if bg is not None:
        out += f";48;5;{bg}"
    if bold:
        out += ";1"
    if under:
        out += ";4"
    return out + "m"


class Term:
    """Owns the tty: enter() once, leave() always (the app wraps everything in try/finally)."""

    def __init__(self):
        self.fd_in = sys.stdin.fileno()
        self.fd_out = sys.stdout.fileno()
        self.saved = None
        self.cols = self.rows = 0
        self.cw, self.ch = 8, 20
        self.frame = []                # what the next flush writes, in order
        self.shown = {}                # (row, col) → the row's text as drawn
        self.buf = b""
        self.gone = False
        self.pasting = False
        self.paste_since = 0.0
        self.buf_since = 0.0

    def enter(self):
        self.saved = termios.tcgetattr(self.fd_in)
        new = termios.tcgetattr(self.fd_in)
        new[0] &= ~(termios.IXON | termios.ICRNL | termios.INLCR | termios.IGNCR | termios.BRKINT | termios.ISTRIP | termios.PARMRK)
        new[1] &= ~termios.OPOST
        new[3] &= ~(termios.ECHO | termios.ICANON | termios.ISIG | termios.IEXTEN)
        new[6][termios.VMIN], new[6][termios.VTIME] = 1, 0
        termios.tcsetattr(self.fd_in, termios.TCSANOW, new)
        os.set_blocking(self.fd_in, False)
        self.raw(b"\x1b[?1049h\x1b[?25l\x1b[?7l\x1b[2J\x1b[?1003h\x1b[?1006h\x1b[?1016h\x1b[?1004h\x1b[?2004h\x1b[?2031h\x1b[?996n\x1b]2;chess\x1b\\")
        self.measure()

    def leave(self):
        self.raw(b"\x1b[?2031l\x1b[?2004l\x1b[?1004l\x1b[?1016l\x1b[?1006l\x1b[?1003l\x1b[0m\x1b[?7h\x1b[?25h\x1b[?1049l")
        if self.saved is not None:
            try:
                termios.tcsetattr(self.fd_in, termios.TCSANOW, self.saved)
                os.set_blocking(self.fd_in, True)
            except (OSError, termios.error):
                pass
            self.saved = None

    def raw(self, data):
        """Written whole, now: a tty that is full is waited for; a tty that is gone (its window closed) ends
        the program in its own time: `gone`, and everything written after that is nothing."""
        view = memoryview(data)
        while view and not self.gone:
            try:
                n = os.write(self.fd_out, view)
                view = view[n:]
            except BlockingIOError:
                select.select([], [self.fd_out], [], 1)
            except OSError:
                self.gone = True

    def measure(self):
        """The window's size in cells and the cell's in pixels. True if either changed."""
        try:
            size = fcntl.ioctl(self.fd_out, termios.TIOCGWINSZ, b"\0" * 8)
        except OSError:
            self.gone = True
            return False
        rows, cols, xp, yp = struct.unpack("HHHH", size)
        cw = xp // cols if cols and xp else 8
        ch = yp // rows if rows and yp else 20
        changed = (cols, rows, cw, ch) != (self.cols, self.rows, self.cw, self.ch)
        self.cols, self.rows, self.cw, self.ch = cols, rows, cw, ch
        return changed

    def clear(self):
        self.frame.append(b"\x1b[0m\x1b[2J")
        self.shown.clear()

    def text(self, row, col, spans, width=None):
        """Spans at row, col (from 0), the rest of `width` cells cleared; nothing if it is what's there."""
        if row < 0 or row >= self.rows or col >= self.cols:
            return
        room = self.cols - col
        width = room if width is None else min(width, room)
        line, used = [], 0
        for span in spans:
            t, fg, bg = (span + (None, None))[:3] if isinstance(span, tuple) else (span, None, None)
            if used >= width or not t:
                continue
            t = t[:width - used]
            used += len(t)
            line.append(ink_seq(fg, bg) + t)
        if used < width:
            line.append("\x1b[0m" + " " * (width - used))
        s = "".join(line)
        if self.shown.get((row, col)) == s:
            return
        self.shown[(row, col)] = s
        self.frame.append(f"\x1b[{row + 1};{col + 1}H{s}".encode())

    def picture(self, row, col, sixel):
        """A sixel with its top-left at the cell: it stays until a new picture or words cover it."""
        self.frame.append(b"\x1b[%d;%dH" % (row + 1, col + 1))
        self.frame.append(sixel)

    def forget(self, row, col):
        self.shown.pop((row, col), None)

    def flush(self):
        """All of it as one frame: foot shows it at once or not at all (mode 2026)."""
        if not self.frame:
            return
        data = b"\x1b[?2026h" + b"".join(self.frame) + b"\x1b[0m\x1b[?2026l"
        self.frame.clear()
        self.raw(data)

    def stale(self):
        """A sequence begun and never ended, old enough to give up on: what lay after it, as events."""
        if self.buf and time.monotonic() - self.buf_since > 0.25:
            self.buf = self.buf[1:]
            out = self._parse()
            if self.buf:
                self.buf_since = time.monotonic()
            return out
        return []

    def read(self):
        """What has come in → events: ('key', name) · ('text', chars) · ('paste', text)
        · ('mouse', kind, button, x_px, y_px) · ('focus', bool) · ('mood', 'dark'|'light') ·
        ('eof',) when the terminal is gone."""
        try:
            data = os.read(self.fd_in, 65536)
        except BlockingIOError:
            return []
        except OSError:
            return [("eof",)]
        if not data:
            return [("eof",)]
        now = time.monotonic()
        fresh = not self.buf
        self.buf += data
        out = self._parse()
        if self.buf and fresh:
            self.buf_since = now
        return out

    def _parse(self):
        out = []
        buf = self.buf
        i, n = 0, len(buf)
        while i < n:
            c = buf[i]
            if self.pasting and time.monotonic() - self.paste_since > 2.0:
                self.pasting = False     # (a paste that never ended: foot never does that, but keys must not die)
                continue
            if self.pasting:
                e = buf.find(b"\x1b[201~", i)
                if e < 0:
                    # (an end marker may be split across reads: hold what could be its start)
                    keep = max(i, n - 5)
                    out.append(("paste", buf[i:keep].decode("utf-8", "replace")))
                    i = keep
                    break
                out.append(("paste", buf[i:e].decode("utf-8", "replace")))
                i = e + 6
                self.pasting = False
                continue
            if c == 0x1b:
                if i + 1 >= n:
                    out.append(("key", "esc"))    # (a lone ESC: sequences arrive whole from foot)
                    i += 1
                    continue
                nxt = buf[i + 1]
                if nxt == 0x5b:                   # CSI
                    m = _CSI.match(buf, i)
                    if not m:
                        if n - i < 64:
                            break                 # (cut by a read: the rest comes next time)
                        i += 1
                        continue
                    i = m.end()
                    ev = self._csi(m[1], m[2], m[4])
                    if ev:
                        out.append(ev)
                    continue
                if nxt == 0x4f:                   # SS3: arrows in application mode, F1–F4
                    if i + 2 >= n:
                        break
                    name = _KEYS.get(buf[i + 2:i + 3])
                    if name:
                        out.append(("key", name))
                    i += 3
                    continue
                if nxt in (0x50, 0x5d, 0x5e, 0x5f):   # DCS, OSC, PM, APC: skipped to their end
                    e = buf.find(b"\x1b\\", i + 2)
                    b = buf.find(b"\x07", i + 2)
                    if e < 0 and b < 0:
                        if n - i < 65536:
                            break
                        i = n
                        continue
                    i = min(x for x in (e + 2 if e >= 0 else n + 1, b + 1 if b >= 0 else n + 1))
                    continue
                if nxt == 0x1b:
                    out.append(("key", "esc"))
                    i += 1
                    continue
                # Alt+key: the same key, its Alt ignored
                i += 1
                continue
            if c < 0x20 or c == 0x7f:
                i += 1
                name = {0x0d: "enter", 0x0a: "enter", 0x09: "tab", 0x7f: "backspace", 0x08: "backspace"}.get(c)
                out.append(("key", name or "ctrl-" + chr(c + 96 if c else 32)))
                continue
            e = i
            while e < n and buf[e] >= 0x20 and buf[e] != 0x7f:
                e += 1
            # (UTF-8 cut by the read: wait for the rest)
            chunk = buf[i:e]
            try:
                t = chunk.decode("utf-8")
            except UnicodeDecodeError as err:
                if err.start > 0:
                    t = chunk[:err.start].decode("utf-8")
                    e = i + err.start
                elif e == n and len(chunk) < 4:
                    break
                else:
                    t = chunk.decode("utf-8", "replace")
            out.append(("text", t))
            i = e
        self.buf = buf[i:]
        return out

    def _csi(self, lead, params, final):
        if lead == b"<" and final in b"Mm":          # SGR mouse (pixels: mode 1016)
            try:
                b, x, y = (int(v or 0) for v in params.split(b";")[:3])
            except ValueError:
                return None
            kind = "up" if final == b"m" else "move" if b & 32 else "wheel" if b & 64 else "down"
            return ("mouse", kind, b & 3 if kind != "wheel" else b & 1, x, y)
        if lead == b"?" and final == b"n":           # 997;1 dark, 997;2 light
            if params.startswith(b"997;"):
                return ("mood", "dark" if params.endswith(b"1") else "light")
            return None
        if lead == b"" and final in b"IO" and not params:
            return ("focus", final == b"I")
        if lead == b"" and final == b"~":
            first = params.split(b";")[0]
            if first == b"200":
                self.pasting = True
                self.paste_since = time.monotonic()
                return None
            name = _TILDE.get(first)
            return ("key", name) if name else None
        if lead == b"" and final == b"u":            # (a kitty-style key, should one come)
            return None
        name = _KEYS.get(final)
        return ("key", name) if name and lead == b"" else None


class Wakeups:
    """Signals (the window resized, a request to stop) as a byte on a pipe the loop selects on."""

    def __init__(self):
        self.r, self.w = os.pipe()
        os.set_blocking(self.r, False)
        os.set_blocking(self.w, False)
        signal.set_wakeup_fd(self.w, warn_on_full_buffer=False)
        self.caught = []
        for sig in (signal.SIGWINCH, signal.SIGTERM, signal.SIGHUP, signal.SIGCONT):
            signal.signal(sig, self._note)

    def _note(self, sig, _frame):
        self.caught.append(sig)

    def take(self):
        try:
            os.read(self.r, 4096)
        except BlockingIOError:
            pass
        out, self.caught = self.caught, []
        return out
