"""iso/screens/console.py — the installer's screens: the Linux console in our grammar.

The console font is Sumi UI ×2 (14 × 28, tools/build-iso-art.py), so a screen is the design system's
text grammar (§7) at the installer's size; the colours are the dark palette's, loaded over the
console's 16. What fbcon gives: 16 inks, 8 grounds (SGR 40–47) — the roles below are placed so.
Python's standard library only: stage 2 has no stty, tput or curses screen to lean on, and first
boot runs this before anything else is installed.
"""
import contextlib
import fcntl
import glob
import os
import select
import struct
import subprocess
import termios
import time

from glyphs import COLOURS, G

HERE = os.path.dirname(os.path.abspath(__file__))
TTY = "/dev/tty8"
FONT = os.path.join(HERE, "sumi-console.psf")

# ANSI number → role, in the order glyphs.py's COLOURS has them (tools/build-iso-art.py, from the palette).
# Grounds must sit in 0–7 (SGR 40–47 reaches no others).
GROUND, SELECT, SURFACE, ACCENT, EDGE2, _5, _6, _7 = range(8)
FAINT, MUTED, TEXT, STRONG, ACCENT_TEXT, ASAGI, _14, ON_SELECT = range(8, 16)

KDSETMODE, KD_TEXT = 0x4B3A, 0
KDSKBMODE, K_UNICODE = 0x4B45, 3
VT_ACTIVATE, VT_LOCKSWITCH = 0x5606, 0x560B
WIDTH = 72                       # the content's columns, centred on any screen


def active():
    """The number of the VT that shows now."""
    with open("/sys/class/tty/tty0/active", encoding="ascii") as f:
        return int(f.read().strip()[3:])


def sgr(ink, ground=GROUND):
    bright = "1;" if ink >= 8 else ""
    return f"\033[0;{bright}{30 + (ink & 7)};{40 + ground}m"


def fbcon_bound():
    """The kernel's graphical console has taken over (its driver is bound to a VT console)."""
    for d in glob.glob("/sys/class/vtconsole/vtcon*"):
        try:
            with open(f"{d}/name", encoding="ascii") as n, open(f"{d}/bind", encoding="ascii") as b:
                if "frame buffer" in n.read() and b.read().strip() == "1":
                    return True
        except OSError:
            pass
    return False


class Screen:
    """A VT of our own, brought forward at the first page, the splash staying up to that moment. Past 6,
    so logind starts no getty on it; everything else — Anaconda, systemd, setup — writes on tty1.
    (rows and cols bring it forward: what lays a page out is about to draw it.)"""

    def __init__(self, tty=TTY, keys=True):
        self.fd = os.open(tty, os.O_RDWR | os.O_NOCTTY)
        self.tty = tty
        self.keys = keys
        self.saved = None
        self.shown = False
        self._rows, self._cols = 38, 137
        if keys:
            with contextlib.suppress(OSError):
                fcntl.ioctl(self.fd, KDSKBMODE, K_UNICODE)
            self.saved = termios.tcgetattr(self.fd)
            raw = termios.tcgetattr(self.fd)
            raw[0] &= ~(termios.ICRNL | termios.IXON | termios.INLCR | termios.IGNCR)
            raw[3] &= ~(termios.ICANON | termios.ECHO | termios.ISIG | termios.IEXTEN)
            raw[6][termios.VMIN] = 0
            raw[6][termios.VTIME] = 0
            termios.tcsetattr(self.fd, termios.TCSANOW, raw)

    @property
    def rows(self):
        self.show()
        return self._rows

    @property
    def cols(self):
        self.show()
        return self._cols

    def show(self):
        """This VT forward, for good. Font and colours only now: fbcon may not have taken over yet (it waits
        for the first letter on the VT that shows, Fedora's deferred takeover, and a font set before that
        is lost), and colours sent to a hidden VT are not applied when the splash leaves graphics mode."""
        if self.shown:
            return
        self.shown = True
        # (the splash's own VT shows for a blink as it goes: nothing on it to see)
        with contextlib.suppress(OSError), open("/dev/tty1", "w", encoding="ascii") as f:
            f.write("\033[2J\033[?25l")
        run("plymouth", "quit", timeout=10)
        with contextlib.suppress(OSError), open("/proc/sys/kernel/printk", "w", encoding="ascii") as f:
            f.write("1")         # (the kernel writes on whichever VT shows: only an emergency, here)
        n = int(self.tty.rsplit("tty", 1)[1])
        for i in range(60):
            with contextlib.suppress(OSError):
                fcntl.ioctl(self.fd, VT_ACTIVATE, n)
            if active() == n:
                break
            if i == 20:          # (a VT left in graphics mode refuses to be switched away from)
                with contextlib.suppress(OSError):
                    other = os.open(f"/dev/tty{active()}", os.O_RDWR | os.O_NOCTTY)
                    fcntl.ioctl(other, KDSETMODE, KD_TEXT)
                    os.close(other)
            time.sleep(0.05)
        with contextlib.suppress(OSError):
            fcntl.ioctl(self.fd, VT_LOCKSWITCH)      # (Alt+F2 must not show what is behind)
        self.write("\033[?25l\033[?7l" + sgr(TEXT))
        for _ in range(40):      # (the letter fbcon waits for, erased at once)
            if fbcon_bound():
                break
            self.write(".\b")
            time.sleep(0.05)
        self.dress()
        self.write(sgr(TEXT) + "\033[2J")

    def dress(self):
        """Our font and our colours on this VT, and how many cells that makes."""
        run("setfont", "-C", self.tty, FONT, timeout=10)
        self._rows, self._cols = self.size()
        self.write(self.palette())

    @staticmethod
    def palette():
        return "".join(f"\033]P{n:X}{c}" for n, c in COLOURS.items())

    def undressed(self):
        """Something reloaded the console's font (a size other than ours): dress again. True: redraw."""
        if self.size() == (self._rows, self._cols):
            return False
        self.dress()
        return True

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
        self.show()
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
