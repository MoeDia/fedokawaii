"""iso/screens/console.py — the installer's screens: the Linux console in our grammar.

The console font is Sumi UI ×2 (14 × 28, tools/build-iso-art.py), so a screen is the design system's
text grammar (§7) at the installer's size; the colours are the dark palette's, loaded over the
console's 16. What fbcon gives: 16 inks, 8 grounds (SGR 40–47) — the roles below are placed so.
Python's standard library only: stage 2 has no stty, tput or curses screen to lean on, and first
boot runs this before anything else is installed.
"""
import fcntl
import os
import select
import shutil
import struct
import subprocess
import termios
import time

from glyphs import G

HERE = os.path.dirname(os.path.abspath(__file__))
TTY = "/dev/tty1"
FONT = os.path.join(HERE, "sumi-console.psf")

# ANSI number → role. Grounds must sit in 0–7 (SGR 40–47 reaches no others).
GROUND, SELECT, SURFACE, ACCENT, EDGE2, _5, _6, _7 = range(8)
FAINT, MUTED, TEXT, STRONG, ACCENT_TEXT, ASAGI, _14, ON_SELECT = range(8, 16)
PALETTE = {GROUND: "181715", SELECT: "82241f", SURFACE: "1c1916", ACCENT: "eb5324", EDGE2: "3c2f22",
           _5: "2d251e", _6: "2d251e", _7: "e7cfa1",
           FAINT: "907e5d", MUTED: "cab596", TEXT: "e7cfa1", STRONG: "f5ecc2", ACCENT_TEXT: "f47b58",
           ASAGI: "82c1b4", _14: "e2b540", ON_SELECT: "f5ecc2"}

KDSETMODE, KD_TEXT = 0x4B3A, 0
KDSKBMODE, K_UNICODE = 0x4B45, 3
VT_ACTIVATE, VT_WAITACTIVE = 0x5606, 0x5607
WIDTH = 72                       # the content's columns, centred on any screen


def sgr(ink, ground=GROUND):
    bright = "1;" if ink >= 8 else ""
    return f"\033[0;{bright}{30 + (ink & 7)};{40 + ground}m"


class Screen:
    def __init__(self, tty=TTY, keys=True):
        self.fd = os.open(tty, os.O_RDWR | os.O_NOCTTY)
        self.tty = tty
        self.keys = keys
        self.saved = None
        try:                     # (the screen is ours: plymouth may have left it in graphics, or on another VT)
            n = int(tty.rsplit("tty", 1)[1])
            fcntl.ioctl(self.fd, VT_ACTIVATE, n)
            fcntl.ioctl(self.fd, VT_WAITACTIVE, n)
            fcntl.ioctl(self.fd, KDSETMODE, KD_TEXT)
            if keys:
                fcntl.ioctl(self.fd, KDSKBMODE, K_UNICODE)
        except OSError:
            pass
        subprocess.run(["setfont", "-C", tty, FONT], check=False, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL)
        if keys:
            self.saved = termios.tcgetattr(self.fd)
            raw = termios.tcgetattr(self.fd)
            raw[0] &= ~(termios.ICRNL | termios.IXON | termios.INLCR | termios.IGNCR)
            raw[3] &= ~(termios.ICANON | termios.ECHO | termios.ISIG | termios.IEXTEN)
            raw[6][termios.VMIN] = 0
            raw[6][termios.VTIME] = 0
            termios.tcsetattr(self.fd, termios.TCSANOW, raw)
        self.rows, self.cols = self.size()
        out = "".join(f"\033]P{n:X}{c}" for n, c in PALETTE.items())
        self.write(out + "\033[?25l\033[?7l" + sgr(TEXT) + "\033[2J")

    def size(self):
        s = fcntl.ioctl(self.fd, termios.TIOCGWINSZ, b"\0" * 8)
        rows, cols = struct.unpack("HHHH", s)[:2]
        return (rows or 38), (cols or 137)

    def write(self, s):
        data = s.encode("utf-8")
        while data:
            n = os.write(self.fd, data)
            data = data[n:]

    def at(self, row, col, text, ink=TEXT, ground=GROUND):
        self.write(f"\033[{row + 1};{col + 1}H{sgr(ink, ground)}{text}")

    def clear(self):
        self.write(sgr(TEXT) + "\033[2J")

    def clear_row(self, row, col=0, width=None):
        self.at(row, col, " " * (width if width is not None else self.cols - col))

    @property
    def left(self):
        return (self.cols - WIDTH) // 2

    def torii(self, row):
        """The torii as on the splash, centred, and our name under it: 5 rows."""
        t = G["torii_big"]
        col = (self.cols - 7) // 2
        for r in range(4):
            self.at(row + r, col, t[r * 7:(r + 1) * 7], ACCENT)
        name = "fedokawaii"
        self.at(row + 4, (self.cols - len(name)) // 2, name, MUTED)

    def heading(self, row, icon, name, width=WIDTH, col=None):
        """§7: the icon at column 0, its name from column 3, a rule to the last column."""
        c = self.left if col is None else col
        self.at(row, c, G[icon], ACCENT_TEXT)
        self.at(row, c + 3, name, STRONG)
        self.at(row, c + 4 + len(name), "─" * (width - 4 - len(name)), EDGE2)

    def meter(self, row, col, done, total, cells=WIDTH):
        n = (done * cells) // max(total, 1)
        self.at(row, col, G["seg_on"] * n, ACCENT_TEXT)
        self.at(row, col + n, G["seg_off"] * (cells - n), EDGE2)

    def key(self, timeout=None):
        """One key: a character, or a name (up, down, left, right, enter, esc, backspace, tab, f2);
        None when nothing came within timeout."""
        r, _, _ = select.select([self.fd], [], [], timeout)
        if not r:
            return None
        b = os.read(self.fd, 8)
        if not b:
            return None
        table = {b"\r": "enter", b"\n": "enter", b"\x7f": "backspace", b"\x08": "backspace", b"\t": "tab",
                 b"\x1b": "esc", b"\x1b[A": "up", b"\x1b[B": "down", b"\x1b[C": "right", b"\x1b[D": "left",
                 b"\x1b[[B": "f2", b"\x1bOQ": "f2", b"\x1b[Z": "backtab", b"\x1b[3~": "delete",
                 b"\x1b[5~": "pgup", b"\x1b[6~": "pgdn", b"\x1b[1~": "home", b"\x1b[4~": "end"}
        if b in table:
            return table[b]
        if b[:1] == b"\x1b":     # (a key of no use here)
            return ""
        try:
            s = b.decode("utf-8")
        except UnicodeDecodeError:
            return ""
        return s if s.isprintable() else ""

    def close(self):
        if self.saved:
            termios.tcsetattr(self.fd, termios.TCSANOW, self.saved)
        os.close(self.fd)


def message_page(s, icon, title, lines, row=None):
    """A page of its own: the torii, a heading, a paragraph at the heading's column."""
    s.clear()
    top = row if row is not None else max(1, (s.rows - 9 - len(lines) - 2) // 2)
    s.torii(top)
    r = top + 7
    s.heading(r, icon, title)
    r += 2
    for line in lines:
        s.at(r, s.left, line, TEXT)
        r += 1
    return r


def wrap(text, width=WIDTH):
    """At a word, never with an ellipsis."""
    out, line = [], ""
    for w in text.split():
        if line and len(line) + 1 + len(w) > width:
            out.append(line)
            line = w
        else:
            line = f"{line} {w}" if line else w
    if line:
        out.append(line)
    return out


def run(*cmd, timeout=None):
    try:
        return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
                              timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return subprocess.CompletedProcess(cmd, 127, "", "")


def power_off():
    run("systemctl", "poweroff")
    time.sleep(60)


def restart():
    run("systemctl", "reboot")
    time.sleep(60)


def tty_ready():
    return shutil.which("setfont") is not None
