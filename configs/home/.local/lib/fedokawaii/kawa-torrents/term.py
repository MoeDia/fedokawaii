"""The terminal: raw mode, keys and the mouse as events, rows drawn only where they changed.

A row is a list of spans (text, ink, ground), the inks foot's palette past the sixteen, so words follow
a theme switch by themselves (docs/design-system.md §7, screen.sh). Only foot is spoken to: synchronized
output (2026), SGR mouse (1006) with every move (1003), focus reports (1004), bracketed paste (2004).
"""
import fcntl
import os
import re
import struct
import sys
import termios

from common import cells

# foot's colours past the sixteen (tools/build-themes.py): docs/design-system.md §1, screen.sh
ACCENT, EDGE, EDGE2, ACCENT_TEXT, MUTED, FAINT, STRONG, SELECT, ON_SELECT = 16, 18, 19, 20, 21, 22, 23, 24, 25
HP, HP_HI = 34, 35                   # (tairyoku: a meter's fill and its front, foot.ini)

_SEQ = re.compile(rb"\x1b\[([?<>=]?)([0-9;:]*)([ -/]*)([@-~])")
_KEYS = {b"A": "up", b"B": "down", b"C": "right", b"D": "left", b"H": "home", b"F": "end", b"Z": "shift-tab"}
_TILDE = {b"3": "delete", b"5": "pageup", b"6": "pagedown", b"1": "home", b"4": "end", b"7": "home", b"8": "end"}
_CTRL = {0x0d: "enter", 0x0a: "enter", 0x09: "tab", 0x7f: "backspace", 0x08: "backspace", 0x1b: "esc", 0x20: "space"}
PASTE_END = b"\x1b[201~"


def ink(fg, bg=None):
    out = "\x1b[0"
    if fg is not None:
        out += f";38;5;{fg}"
    if bg is not None:
        out += f";48;5;{bg}"
    return out + "m"


def spans_text(spans):
    """Spans → what the terminal is sent, and the columns it takes."""
    out, used = [], 0
    for s in spans:
        t, fg, bg = (s + (None, None))[:3] if isinstance(s, tuple) else (s, None, None)
        if t:
            out.append(ink(fg, bg) + t)
            used += cells(t)
    return "".join(out), used


class Term:
    """Owns the tty: enter() once, leave() always (the app wraps everything in try/finally)."""

    def __init__(self):
        self.fd_in, self.fd_out = sys.stdin.fileno(), sys.stdout.fileno()
        self.saved = None
        self.cols = self.rows = 0
        self.shown = {}                            # row → what is on the screen there
        self.buf = b""
        self.pasting = None
        self.cursor = None                         # (row, column) of the line typed on, or nothing
        self.placed = None

    def enter(self):
        self.saved = termios.tcgetattr(self.fd_in)
        new = termios.tcgetattr(self.fd_in)
        new[0] &= ~(termios.IXON | termios.ICRNL | termios.INLCR | termios.IGNCR | termios.BRKINT | termios.ISTRIP | termios.PARMRK)
        new[1] &= ~termios.OPOST
        new[3] &= ~(termios.ECHO | termios.ICANON | termios.ISIG | termios.IEXTEN)
        new[6][termios.VMIN], new[6][termios.VTIME] = 1, 0
        termios.tcsetattr(self.fd_in, termios.TCSANOW, new)
        os.set_blocking(self.fd_in, False)
        self.raw(b"\x1b[?1049h\x1b[?25l\x1b[2J\x1b[?1003h\x1b[?1006h\x1b[?1004h\x1b[?2004h")
        self.measure()
        self.shown.clear()

    def leave(self):
        try:
            self.raw(b"\x1b[?2004l\x1b[?1004l\x1b[?1006l\x1b[?1003l\x1b[0m\x1b[?25h\x1b[?1049l")
        except OSError:
            pass                                   # (the window is gone: nothing to put back)
        if self.saved is not None:
            try:
                termios.tcsetattr(self.fd_in, termios.TCSANOW, self.saved)
                os.set_blocking(self.fd_in, True)
            except (OSError, termios.error):
                pass
            self.saved = None

    def raw(self, data):
        """Written whole, now: a tty that is full is waited for, a tty that is gone raises OSError."""
        view = memoryview(data)
        while view:
            try:
                n = os.write(self.fd_out, view)
                view = view[n:]
            except BlockingIOError:
                import select
                select.select([], [self.fd_out], [], 1)

    def measure(self):
        """The window's size in cells. True if it changed."""
        rows, cols = struct.unpack("HHHH", fcntl.ioctl(self.fd_out, termios.TIOCGWINSZ, b"\0" * 8))[:2]
        changed = (cols, rows) != (self.cols, self.rows)
        self.cols, self.rows = cols, rows
        if changed:
            self.shown.clear()
        return changed

    def draw(self, frame):
        """FRAME: a list of rows, each spans. Only the rows that differ go out, in one synchronized
        update: a theme's wash, a burst of pieces or a list of a thousand never flicker."""
        out = []
        for y, spans in enumerate(frame[:self.rows]):
            text, used = spans_text(spans)
            if used > self.cols:                   # (a row never wraps: its measure was wrong, its end goes)
                text, used = clip(spans, self.cols), self.cols
            if self.shown.get(y) != text:
                self.shown[y] = text
                # (a row that fills the window leaves the cursor on its last cell: an erase there would take that cell)
                out.append(f"\x1b[{y + 1};1H{text}\x1b[0m" + ("\x1b[K" if used < self.cols else ""))
        for y in range(len(frame), self.rows):
            if self.shown.get(y):
                self.shown[y] = ""
                out.append(f"\x1b[{y + 1};1H\x1b[0m\x1b[K")
        place = "\x1b[?25l" if self.cursor is None else f"\x1b[{self.cursor[0] + 1};{self.cursor[1] + 1}H\x1b[?25h"
        if out or place != self.placed:
            self.placed = place
            self.raw(("\x1b[?2026h" + "".join(out) + place + "\x1b[?2026l").encode("utf-8", "replace"))

    # ── input ───────────────────────────────────────────────────────────────────────────────
    def read(self):
        """What came, as events: ("key", name) · ("text", letters) · ("paste", text) · ("mouse", kind, x, y) ·
        ("focus", bool). kind: move · press · release · wheel-up · wheel-down, for the left button; a right press
        is "press-right". None when the terminal has gone."""
        try:
            data = os.read(self.fd_in, 1 << 16)
        except BlockingIOError:
            return []
        except OSError:
            return None
        if not data:
            return None
        self.buf += data
        return self.parse()

    def parse(self):
        ev, b = [], self.buf
        i = 0
        while i < len(b):
            if self.pasting is not None:
                j = b.find(PASTE_END, i)
                if j < 0:                          # (the rest of it comes in the next read; a partial end marker stays)
                    keep = len(PASTE_END) - 1
                    self.pasting += b[i:max(i, len(b) - keep)]
                    i = max(i, len(b) - keep)
                    break
                self.pasting += b[i:j]
                ev.append(("paste", self.pasting.decode("utf-8", "replace")))
                self.pasting = None
                i = j + len(PASTE_END)
                continue
            c = b[i]
            if c == 0x1b:
                m = _SEQ.match(b, i)
                if m:
                    i = m.end()
                    self.csi(m, ev)
                    continue
                if b[i:i + 2] == b"\x1b[" or b[i:i + 2] == b"\x1bO":
                    if i + 2 >= len(b):
                        break                      # (cut in two: the rest comes next)
                    if b[i + 1:i + 2] == b"O":
                        ev.append(("key", _KEYS.get(b[i + 2:i + 3], "?")))
                        i += 3
                        continue
                if i + 1 < len(b) and b[i + 1] == 0x1b:
                    i += 1
                    continue
                if i + 1 < len(b):                 # (alt+key: no key here)
                    i += 2
                    continue
                ev.append(("key", "esc"))
                i += 1
                continue
            if c < 0x20 or c == 0x7f:
                name = _CTRL.get(c)
                if name:
                    ev.append(("key", name))
                else:
                    ev.append(("key", "ctrl-" + chr(c + 0x60)))
                i += 1
                continue
            if c == 0x20:
                ev.append(("key", "space"))
                i += 1
                continue
            j = i
            while j < len(b) and b[j] >= 0x21 and b[j] != 0x7f:
                j += 1
            try:
                ev.append(("text", b[i:j].decode("utf-8")))
            except UnicodeDecodeError:
                if j == len(b) and j - i < 4:      # (a letter cut in two)
                    break
                ev.append(("text", b[i:j].decode("utf-8", "replace")))
            i = j
        self.buf = b[i:]
        return ev

    def csi(self, m, ev):
        lead, params, final = m.group(1), m.group(2), m.group(4)
        if lead == b"<" and final in b"Mm":
            parts = params.split(b";")
            if len(parts) == 3:
                btn, x, y = int(parts[0]), int(parts[1]) - 1, int(parts[2]) - 1
                if btn & 64:
                    ev.append(("mouse", "wheel-up" if btn & 1 == 0 else "wheel-down", x, y))
                elif btn & 32:
                    ev.append(("mouse", "move", x, y))
                elif final == b"m":
                    ev.append(("mouse", "release", x, y))
                else:
                    ev.append(("mouse", "press" if btn & 3 == 0 else "press-right", x, y))
            return
        if final == b"~":
            n = params.split(b";")[0]
            if n == b"200":
                self.pasting = b""
                return
            name = _TILDE.get(n)
            if name:
                ev.append(("key", name))
            return
        if final == b"I":
            ev.append(("focus", True))
        elif final == b"O":
            ev.append(("focus", False))
        elif final in _KEYS:
            ev.append(("key", _KEYS[final]))


def clip(spans, n):
    """Spans cut to N columns: the text sent."""
    out, used = [], 0
    for s in spans:
        t, fg, bg = (s + (None, None))[:3] if isinstance(s, tuple) else (s, None, None)
        room = n - used
        if room <= 0 or not t:
            continue
        w = cells(t)
        if w > room:
            head, u = [], 0
            for c in t:
                cw = cells(c)
                if u + cw > room:
                    break
                head.append(c)
                u += cw
            t, w = "".join(head), u
        out.append(ink(fg, bg) + t)
        used += w
    return "".join(out)
