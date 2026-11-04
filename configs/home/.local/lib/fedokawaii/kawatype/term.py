"""term.py — the terminal: foot in raw mode, its keyboard as real presses and releases (the Kitty keyboard
protocol: `man foot-ctlseqs`), its theme and focus changes, the mouse on the screens that want it; output
gathered and shown as one frame (mode 2026), so nothing is ever seen half drawn.

What a key sends with flags 1 + 2 + 4 + 8 + 16:  CSI code:shifted:base ; mods:event ; text u
    code     the key's own letter in the layout in use, unshifted (a modifier has a code of its own)
    shifted  what shift makes of it, base  the same key in the first layout (us), when they differ
    mods     1 + shift 1, alt 2, ctrl 4, super 8, caps lock 64, num lock 128
    event    1 press, 2 repeat, 3 release       text  what it types, as code points
Text with no key behind it (an input method's) comes as plain UTF-8 and is read as presses.
"""
import fcntl
import os
import re
import select
import signal
import struct
import termios
import time
import tty
from collections import namedtuple

# what the program is told, in order of arrival (t: time.monotonic of the read)
Key = namedtuple('Key', 'kind name text mods t')   # kind press · repeat · release; name: below; text: what it types
Focus = namedtuple('Focus', 'on t')
Mood = namedtuple('Mood', 'dark')
Mouse = namedtuple('Mouse', 'kind col row button')  # kind press · release · move · wheel (button -1 up, +1 down)
Resize = namedtuple('Resize', '')
Pasted = namedtuple('Pasted', '')
Flags = namedtuple('Flags', 'value')               # the keyboard protocol's flags the terminal took

SHIFT, ALT, CTRL, SUPER, CAPS = 1, 2, 4, 8, 64
# (keys by their protocol numbers)
NAMES = {
    13: 'enter', 9: 'tab', 127: 'backspace', 27: 'escape', 32: 'space',
    57358: 'caps', 57441: 'lshift', 57442: 'lctrl', 57443: 'lalt', 57444: 'lsuper',
    57447: 'rshift', 57448: 'rctrl', 57449: 'ralt', 57450: 'rsuper', 57453: 'ralt',
    57399: '0', 57400: '1', 57401: '2', 57402: '3', 57403: '4', 57404: '5', 57405: '6', 57406: '7', 57407: '8',
    57408: '9', 57409: '.', 57410: '/', 57411: '*', 57412: '-', 57413: '+', 57414: 'enter',
}
FINALS = {'A': 'up', 'B': 'down', 'C': 'right', 'D': 'left', 'H': 'home', 'F': 'end'}
TILDES = {'3': 'delete', '5': 'pageup', '6': 'pagedown', '1': 'home', '4': 'end', '7': 'home', '8': 'end', '2': 'insert'}
CSI = re.compile(r'\x1b\[([<?>=]?)([0-9;:]*)([ -/]*)([@-~])')

ENTER = ('\x1b[?1049h'  # the screen of its own
         '\x1b[22;2t\x1b]2;typing\x1b\\'  # the window's title, the old one kept: Super+/ knows the app by it
         '\x1b[?2031h\x1b[?1004h\x1b[?2004h'  # theme changes, focus, pasted text marked
         '\x1b[>31u\x1b[?u'  # real presses and releases, and whether it heard that
         '\x1b[?996n'  # the theme now
         '\x1b[?7l'  # no wrap at the right edge
         '\x1b[2J')
LEAVE = ('\x1b[?1003l\x1b[?1006l\x1b[?2026l\x1b[?7h\x1b[0m\x1b[?25h\x1b[<u\x1b[?2004l\x1b[?1004l\x1b[?2031l\x1b[23;2t\x1b[?1049l')
MOUSE_ON, MOUSE_OFF = '\x1b[?1003h\x1b[?1006h', '\x1b[?1003l\x1b[?1006l'


class Term:
    def __init__(self, fd_in=0, fd_out=1):
        self.fd, self.out = fd_in, fd_out
        self.buf = ''
        self.bytes = b''
        self.pending = []
        self.frame = []
        self.pasting = False
        self.esc_at = None
        self.saved = None
        self.pipe_r, self.pipe_w = os.pipe()
        os.set_blocking(self.pipe_r, False)
        os.set_blocking(self.pipe_w, False)
        self.mouse = False
        self.resized = False

    def start(self):
        self.saved = termios.tcgetattr(self.fd)
        tty.setraw(self.fd)
        signal.signal(signal.SIGWINCH, lambda *_: self._resized())
        self.write_now(ENTER)

    def stop(self):
        if self.saved is not None:
            self.write_now(LEAVE)
            try:
                termios.tcsetattr(self.fd, termios.TCSADRAIN, self.saved)
            except termios.error:
                pass
            self.saved = None

    def poke(self):
        """read() returns now"""
        try:
            os.write(self.pipe_w, b'.')
        except OSError:
            pass

    def _resized(self):
        self.resized = True
        self.poke()

    def size(self):
        """columns, rows, a cell's width and height in pixels (8 × 20 where the terminal does not say)"""
        try:
            rows, cols, xp, yp = struct.unpack('HHHH', fcntl.ioctl(self.out, termios.TIOCGWINSZ, b'\0' * 8))
        except OSError:
            rows, cols, xp, yp = 24, 80, 0, 0
        rows, cols = max(rows, 1), max(cols, 1)
        cw, ch = (xp // cols, yp // rows) if xp and yp else (8, 20)
        return cols, rows, max(cw, 1), max(ch, 1)

    # ── output ───────────────────────────────────────────────────────────────
    def write(self, data):
        self.frame.append(data.encode() if isinstance(data, str) else data)

    def write_now(self, data):
        data = data.encode() if isinstance(data, str) else data
        while data:
            try:
                data = data[os.write(self.out, data):]
            except InterruptedError:
                continue
            except BlockingIOError:
                select.select([], [self.out], [], 1)
            except OSError:
                return   # (the window went: nothing left to draw on)

    def flush(self):
        """what was written since the last frame, shown at once as one frame"""
        if self.frame:
            data = b''.join(self.frame)
            self.frame.clear()
            self.write_now(b'\x1b[?2026h' + data + b'\x1b[?2026l')

    def mouse_on(self, on):
        if on != self.mouse:
            self.mouse = on
            self.write(MOUSE_ON if on else MOUSE_OFF)

    # ── input ────────────────────────────────────────────────────────────────
    def read(self, timeout):
        """the events waiting, or those of the next that comes within timeout seconds (None: wait on)"""
        if self.esc_at is not None:
            timeout = 0.03 if timeout is None else min(timeout, 0.03)
        try:
            ready, _, _ = select.select([self.fd, self.pipe_r], [], [], timeout)
        except InterruptedError:
            ready = []
        events = []
        now = time.monotonic()
        if self.pipe_r in ready:
            try:
                os.read(self.pipe_r, 512)
            except OSError:
                pass
            if self.resized:
                self.resized = False
                events.append(Resize())
        if self.fd in ready:
            try:
                data = os.read(self.fd, 65536)
            except OSError:
                data = b''
            if not data:
                raise EOFError
            self.bytes += data
            # (a character cut between two reads waits for the rest)
            try:
                text = self.bytes.decode()
                self.bytes = b''
            except UnicodeDecodeError as e:
                keep = len(self.bytes) - e.start
                if keep < 4 and e.reason == 'unexpected end of data':
                    text, self.bytes = self.bytes[:e.start].decode(), self.bytes[e.start:]
                else:
                    text, self.bytes = self.bytes.decode(errors='replace'), b''
            self.buf += text
            self.esc_at = None
            self._parse(events, now)
        elif self.esc_at is not None and now - self.esc_at >= 0.03:
            # (ESC with nothing after it: the key, when no protocol reports it)
            self.buf, self.esc_at = '', None
            events.append(Key('press', 'escape', '', 0, now))
        return events

    def _parse(self, events, now):
        s = self.buf
        i = 0
        n = len(s)
        while i < n:
            c = s[i]
            if c != '\x1b':
                if not self.pasting:
                    self._plain(c, events, now)
                i += 1
                continue
            if i + 1 >= n:
                self.esc_at = now
                break
            if s[i + 1] == '[':
                m = CSI.match(s, i)
                if not m:
                    if not re.search(r'[@-~]', s[i + 2:]) and n - i < 64:
                        break   # (cut between two reads)
                    i += 2
                    continue
                self._csi(m, events, now)
                i = m.end()
            elif s[i + 1] == 'O' and i + 2 < n:
                name = FINALS.get(s[i + 2])
                if name:
                    events.append(Key('press', name, '', 0, now))
                i += 3
            elif s[i + 1] in 'P]_^':   # (a string the terminal answers with: skipped whole)
                end = s.find('\x1b\\', i + 2)
                if end < 0:
                    if n - i < 4096:
                        break
                    i = n
                else:
                    i = end + 2
            else:
                events.append(Key('press', 'escape', '', ALT if s[i + 1] != '\x1b' else 0, now))
                i += 2 if s[i + 1] != '\x1b' else 1
        self.buf = s[i:]

    def _plain(self, c, events, now):
        o = ord(c)
        if c in '\r\n':
            events.append(Key('press', 'enter', '', 0, now))
        elif c == '\t':
            events.append(Key('press', 'tab', '', 0, now))
        elif c in '\x7f\x08':
            events.append(Key('press', 'backspace', '', 0, now))
        elif o < 32:
            letter = chr(o + 96)
            events.append(Key('press', letter if letter.isalpha() else 'ctrl', '', CTRL, now))
        elif o != 127:
            low = c.lower() if c.isascii() else c
            mods = SHIFT if c.isascii() and c != low else 0
            events.append(Key('press', 'space' if c == ' ' else low, c, mods, now))

    def _csi(self, m, events, now):
        lead, params, final = m[1], m[2], m[4]
        if lead == '?':
            if final == 'n' and params.startswith('997;'):
                events.append(Mood(params.endswith('1')))
            elif final == 'u':
                events.append(Flags(_int(params, 0)))
            return
        if lead == '<':
            self._mouse(params, final, events)
            return
        if lead:
            return
        if final == 'I':
            events.append(Focus(True, now))
            return
        if final == 'O':
            events.append(Focus(False, now))
            return
        if final == '~' and params in ('200', '201'):
            self.pasting = params == '200'
            if params == '201':
                events.append(Pasted())
            return
        # (while pasting, only plain text is the paste: foot takes every escape out of what it pastes, so a sequence is
        # a real key — a paste that never ends can never lock the keyboard out)
        fields = params.split(';') if params else ['']
        first = fields[0].split(':')
        mods, event = 0, 1
        if len(fields) > 1 and fields[1]:
            sub = fields[1].split(':')
            mods = _int(sub[0], 1) - 1
            event = _int(sub[1], 1) if len(sub) > 1 else 1
        kind = {1: 'press', 2: 'repeat', 3: 'release'}.get(event, 'press')
        if final == 'u':
            code = _int(first[0], 0)
            base = _int(first[2], 0) if len(first) > 2 else 0
            shifted = _int(first[1], 0) if len(first) > 1 else 0
            text = ''
            if len(fields) > 2:
                try:
                    text = ''.join(chr(_int(t, 0)) for t in fields[2].split(':') if t and 32 <= _int(t, 0) < 0x110000)
                except ValueError:
                    text = ''
            if not text and kind != 'release' and code >= 32 and code != 127 and code < 57344 and not mods & (CTRL | ALT | SUPER):
                # (a shifted key whose text was left out: what shift makes of it)
                text = chr(shifted) if shifted and mods & SHIFT else chr(code) if not mods & SHIFT else chr(code).upper()
            key = base or code
            name = NAMES.get(key) or (chr(key) if 32 < key < 57344 else 'other')
            if name == 'other' and key == 0:
                return
            events.append(Key(kind, name, text, mods, now))
        elif final in FINALS:
            events.append(Key(kind, FINALS[final], '', mods, now))
        elif final == '~':
            name = TILDES.get(first[0])
            if name:
                events.append(Key(kind, name, '', mods, now))

    @staticmethod
    def _mouse_args(params):
        return [_int(p, 0) for p in params.split(';')]

    def _mouse(self, params, final, events):
        p = self._mouse_args(params)
        if len(p) < 3 or final not in 'Mm':
            return
        b, col, row = p[:3]
        if b & 64:
            events.append(Mouse('wheel', col, row, -1 if not b & 1 else 1))
        elif b & 32:
            events.append(Mouse('move', col, row, 0))
        else:
            events.append(Mouse('press' if final == 'M' else 'release', col, row, b & 3))


def _int(s, default):
    try:
        return int(s) if s else default
    except ValueError:
        return default
