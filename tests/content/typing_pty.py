#!/usr/bin/env python3
"""typing_pty.py — kawa-typing in a pseudo-terminal of its own, played by a script: a typist at a known speed, a
fuzzer, or a screen read back. Keys go in as foot sends them (the Kitty keyboard protocol) or as plain bytes.

    python3 -I typing_pty.py [--size COLSxROWS] [--plain] [--seed N] [--dump FILE] [--keys "SECONDS:KEYS"]… [--end S] -- ARG…

    --keys S:KEYS        at S seconds, KEYS: Python escapes, as bytes; \\e is ESC
    --dump FILE          everything the program wrote, raw
Ends when the program does, or at --end seconds (it is then asked to leave, Ctrl+C as foot sends it). Prints one
JSON object: the exit status and what the terminal saw (mode 2026 balance, sixels, bytes). Imported by typing_cases.py
and typing_fuzz.py, which play it.
"""
import argparse
import fcntl
import json
import os
import pty
import select
import signal
import struct
import sys
import termios
import time


def key(ch, plain=False, event=1):
    """a character as foot sends it: CSI code:shifted ; mods:event ; text u (or as itself, --plain)"""
    if plain:
        return ch.encode() if event == 1 else b''
    if ch == '\n':
        return f'\x1b[13;1:{event}u'.encode()
    low = ch.lower() if ch.isalpha() else UNSHIFT.get(ch, ch)
    shifted = ch != low
    mods = 2 if shifted else 1
    code = ord(low)
    if event == 3:
        return f'\x1b[{code};{mods}:3u'.encode()
    alt = f':{ord(ch)}' if shifted else ''
    return f'\x1b[{code}{alt};{mods}:{event};{ord(ch)}u'.encode()


UNSHIFT = dict(zip('~!@#$%^&*()_+{}|:"<>?', r"`1234567890-=[]\;',./", strict=True))
SHIFT_DOWN, SHIFT_UP = b'\x1b[57447;2:1u', b'\x1b[57447;1:3u'


def wrong_for(ch):
    return 'x' if ch != 'x' else 'z'


class Pty:
    def __init__(self, argv, size, env=None, cell=(8, 20)):
        self.cell = cell
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            if env:
                os.environ.update(env)
            os.environ['TERM'] = 'foot'
            os.execv(argv[0], argv)
        cols, rows = size
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, cols * cell[0], rows * cell[1]))
        os.set_blocking(self.fd, False)   # (as foot's: both ways full is never a deadlock)
        self.out = bytearray()
        self.status = None

    def pump(self, seconds=0.0):
        """everything the program has written, for a while"""
        end = time.monotonic() + seconds
        while True:
            left = end - time.monotonic()
            r, _, _ = select.select([self.fd], [], [], max(left, 0))
            if r:
                try:
                    b = os.read(self.fd, 1 << 20)
                except BlockingIOError:
                    b = None
                except OSError:
                    b = b''
                if b == b'':
                    self.wait(1)
                    return False
                if b:
                    self.out += b
            elif left <= 0:
                return True
            if left <= 0:
                return True

    def send(self, b):
        """keys in, what it draws read meanwhile: a full terminal in either direction is no deadlock"""
        end = time.monotonic() + 5
        while b and time.monotonic() < end:
            r, w, _ = select.select([self.fd], [self.fd], [], 0.2)
            try:
                if r:
                    data = os.read(self.fd, 1 << 20)
                    if not data:
                        return
                    self.out += data
                if w:
                    b = b[os.write(self.fd, b[:4096]):]
            except BlockingIOError:
                continue
            except OSError:
                return

    def resize(self, cols, rows, cell=None):
        self.cell = cell or self.cell
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, cols * self.cell[0], rows * self.cell[1]))
        try:
            os.kill(self.pid, signal.SIGWINCH)
        except OSError:
            pass

    def wait(self, seconds):
        end = time.monotonic() + seconds
        while self.status is None and time.monotonic() < end:
            p, st = os.waitpid(self.pid, os.WNOHANG)
            if p:
                self.status = os.waitstatus_to_exitcode(st)
                return self.status
            time.sleep(0.01)
        return self.status

    def kill(self):
        if self.status is None:
            try:
                os.kill(self.pid, signal.SIGKILL)
            except OSError:
                pass
            self.wait(2)


def state_dir():
    base = os.environ.get('XDG_STATE_HOME') or os.path.expanduser('~/.local/state')
    return os.path.join(base, 'fedokawaii', 'typing')


def check_stream(raw):
    """what a terminal would object to: frames left open, sixels never closed"""
    s = bytes(raw)
    return {'bytes': len(s), 'sync_open': s.count(b'\x1b[?2026h'), 'sync_close': s.count(b'\x1b[?2026l'),
            'sixels_open': s.count(b'\x1bP'), 'sixels_close': s.count(b'\x1b\\'), 'left_screen': s.count(b'\x1b[?1049l')}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--size', default='84x31')
    ap.add_argument('--plain', action='store_true')
    ap.add_argument('--seed', type=int)
    ap.add_argument('--keys', action='append', default=[])
    ap.add_argument('--end', type=float, default=30)
    ap.add_argument('--dump')
    ap.add_argument('--bin', default=os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'bin', 'kawa-typing'))
    ap.add_argument('args', nargs='*')
    a = ap.parse_args()
    cols, rows = map(int, a.size.split('x'))
    argv = [sys.executable, '-IB', a.bin] + (['--seed', str(a.seed)] if a.seed is not None else []) + a.args
    p = Pty(argv, (cols, rows))
    t0 = time.monotonic()
    out = {}
    p.pump(0.2)
    scripted = sorted(((float(s.split(':', 1)[0]), s.split(':', 1)[1].encode().decode('unicode_escape').encode('latin1')) for s in a.keys))
    for at, data in scripted:
        while time.monotonic() - t0 < at and p.status is None:
            p.pump(0.02)
        p.send(data.replace(b'\\e', b'\x1b'))
    end = t0 + a.end
    while time.monotonic() < end and p.status is None:
        if not p.pump(0.05):
            break
    if p.status is None:
        p.send(b'\x1b[99;5:1u' if not a.plain else b'\x03')
        p.pump(0.5)
        p.wait(1)
    if p.status is None:
        p.kill()
        out['killed'] = True
    out['status'] = p.status
    out.update(check_stream(p.out))
    if a.dump:
        with open(a.dump, 'wb') as f:
            f.write(p.out)
    print(json.dumps(out))
    return 0


if __name__ == '__main__':
    sys.exit(main())
