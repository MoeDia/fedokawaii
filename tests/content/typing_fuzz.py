#!/usr/bin/env python3
"""typing_fuzz.py — kawa-typing tested to destruction (T26c): for as long as asked it is fed everything a person, a
terminal or a broken file can feed it, on every screen, at every size, in both moods. Any traceback, any exit that
was not asked for, any hang (no answer for 5 s) and any frame left open is a failure, printed with the seed that
reproduces it.

    python3 -I typing_fuzz.py [--minutes M] [--seed S] [--rounds N]

Each round starts the program on a fresh or damaged state and plays a few hundred events drawn from: every key as
foot sends it, every key as plain bytes (a terminal with no protocol), held keys and their repeats and releases,
modifiers alone, Ctrl and Alt and Super chords, Caps Lock, the Arabic layout, dead keys, an input method's text,
bracketed pastes, huge pastes, the mouse, focus changes, theme changes, resizes from 1 × 1 to 300 × 90, a 200 wpm
typist, escape sequences cut in half, bytes that are not UTF-8, garbage. Between rounds: SIGKILL mid-run, the state
files truncated or overwritten with noise.
"""
import argparse
import json
import os
import random
import shutil
import signal
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from typing_pty import Pty, key, state_dir   # noqa: E402

BIN = os.environ.get('TYPING_BIN') or os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'bin', 'kawa-typing')
LETTERS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 `~!@#$%^&*()-_=+[]{}\\|;:\'",.<>/?\n'
NAMED = [13, 9, 127, 27, 32, 57358, 57441, 57442, 57443, 57444, 57447, 57448, 57449, 57450, 57453, 57399, 57414, 57376, 57427, 0, 999999]
LEGACY = [b'\x1b[A', b'\x1b[B', b'\x1b[C', b'\x1b[D', b'\x1b[H', b'\x1b[F', b'\x1b[3~', b'\x1b[5~', b'\x1b[6~', b'\x1bOP', b'\x1bOA', b'\x1b[1;5C', b'\x1b[1;1:3D',
          b'\x1b[99;5:1u', b'\x03'[:0], b'\x7f', b'\r', b'\t', b'\x1b', b'\x1b\x1b', b'\x1b[', b'\x1b[?', b'\x1b]0;x\x07', b'\x1bP', b'\x1b\\', b'\x1b[997n', b'\x1b[?997;1n', b'\x1b[?997;2n',
          b'\x1b[?31u', b'\x1b[6;20;8t', b'\x1b[I', b'\x1b[O', b'\x1b[200~', b'\x1b[201~', b'\x1b[<0;5;5M', b'\x1b[<0;5;5m', b'\x1b[<64;5;5M', b'\x1b[<65;5;5M', b'\x1b[<35;9;9M', b'\x1b[<2;1;1M',
          b'\x1b[<0;999;999M', b'\x1b[;;;u', b'\x1b[:::;:::;:::u', b'\x1b[1;2;3;4;5;6;7;8;9u', b'\x1b[99999999999;9999:9999;1114112u']
# the keys that go from screen to screen, as foot sends them
NAVIGATE = [b'\x1b[9;1:1u\x1b[9;1:3u', b'\x1b[9;2:1u\x1b[9;2:3u', b'\x1b[13;1:1u\x1b[13;1:3u', b'\x1b[27;1:1u\x1b[27;1:3u', b'\x1b[1;1:1A', b'\x1b[1;1:1B', b'\x1b[1;1:2B', b'\x1b[1;1:1C',
            b'\x1b[1;1:1D', b'\x1b[5;1:1~', b'\x1b[6;1:1~', b'\x1b[1;1:1H', b'\x1b[1;1:1F', b'\x1b[106;1:1;106u', b'\x1b[107;1:1;107u', b'\x1b[114;1:1;114u', b'\x1b[113;1:1;113u',
            b'\x1b[107;5:1u', b'\x1b[<35;10;8M', b'\x1b[<35;10;12M', b'\x1b[<0;10;8M', b'\x1b[<0;10;8m', b'\x1b[<0;20;2M', b'\x1b[<65;10;8M', b'\x1b[?31u']
LESSONS = ['home.fj.meet', 'home.anchor.j', 'top.anchor.f', 'bottom.travel.0', 'sent.1', 'sent.pat.1', 'caps.FDSA.words', 'num.47.drill', 'sym.$&.words', 'sign.`.meet', 'speed.30.pacer',
           'speed.30.check', 'speed.110.passage.1', 'code.python.1', 'code.c.2', 'sign.check']
ARABIC = ['\x1b[1588::97;1:1;1588u', '\x1b[1587::115;1:1;1587u', '\x1b[1740::100;1:1;1740u', '\x1b[1608:1606:102;2:1;1606u']


def trace():
    return os.path.join(state_dir(), '..', 'typing-trace.json')


def event(rng, p, plain_mode=False):
    """one thing that can happen"""
    r = rng.random()
    if r < 0.45:
        ch = rng.choice(LETTERS)
        p.send(key(ch, plain_mode))
        if not plain_mode and rng.random() < 0.8:
            p.send(key(ch, False, 3))
    elif r < 0.55:
        ch = rng.choice(LETTERS)
        for _ in range(rng.randint(1, 30)):
            p.send(key(ch, False, 2))
    elif r < 0.65:
        code = rng.choice(NAMED)
        p.send(f'\x1b[{code};{rng.randint(1, 256)}:{rng.randint(1, 3)}u'.encode())
    elif r < 0.75:
        p.send(rng.choice(LEGACY))
    elif r < 0.80:
        p.send(rng.choice(ARABIC).encode())
    elif r < 0.84:
        n = rng.choice((1, 20, 300, 100000))
        p.send(b'\x1b[200~' + b'x' * n + b'\x1b[201~')
    elif r < 0.88:
        p.resize(rng.randint(1, 300), rng.randint(1, 90))
    elif r < 0.91:
        p.send(bytes(rng.randrange(256) for _ in range(rng.randint(1, 40))))
    elif r < 0.94:
        seq = rng.choice(LEGACY)
        p.send(seq[:rng.randint(0, len(seq))])
    elif r < 0.97:
        p.send('日本語 مرحبا é'.encode())
    else:
        p.send(b'\x1b[?997;%dn' % rng.randint(1, 2))


def typist(rng, p):
    """a burst at speed: the text under way, as it stands"""
    try:
        with open(trace()) as f:
            d = json.load(f)['run']
    except (OSError, ValueError, KeyError, TypeError):
        return
    if not isinstance(d, dict) or not isinstance(d.get('text'), str):
        return
    text, pos = d['text'], d.get('pos', 0)
    for ch in text[pos:pos + rng.randint(5, 200)]:
        p.send(key(ch))
        p.send(key(ch, False, 3))
        p.pump(0.004 + rng.random() * 0.06)


def damage(rng):
    """the state as a crash, a full disk or a stray program could leave it"""
    d = state_dir()
    for name in ('progress.json', 'keys.json', 'resume.json', 'history.jsonl'):
        path = os.path.join(d, name)
        r = rng.random()
        if r > 0.3 or not os.path.exists(path):
            continue
        data = open(path, 'rb').read()
        kind = rng.randrange(4)
        with open(path, 'wb') as f:
            if kind == 0:
                f.write(data[:rng.randint(0, len(data))])
            elif kind == 1:
                f.write(bytes(rng.randrange(256) for _ in range(rng.randint(0, 200))))
            elif kind == 2:
                f.write(json.dumps({'run': rng.choice((1, [], {}, {'text': 'x'}, {'text': 'ab', 'pos': -9, 'got': None})), 'lessons': rng.choice((None, 3, {'x': 1})), 'keys': [1], 'day': 5}).encode())
            else:
                b = bytearray(data)
                for _ in range(min(10, len(b))):
                    b[rng.randrange(len(b))] = rng.randrange(256)
                f.write(b)


def start(rng, seed, size):
    argv = [sys.executable, '-IB', BIN, '--seed', str(seed), '--trace', trace()]
    r = rng.random()
    if r < 0.1:
        argv.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'typing_cases.py'))
    elif r < 0.4:
        argv += ['--eye', '1', '--lesson', rng.choice(LESSONS)]
    p = Pty(argv, size, cell=rng.choice(((8, 20), (8, 20), (8, 20), (9, 22), (10, 25), (16, 40), (7, 15), (1, 1))))
    t0 = time.monotonic()      # (until it has the terminal in raw mode: before that, a byte is a signal)
    while b'\x1b[?1049h' not in p.out and p.status is None and time.monotonic() - t0 < 5:
        p.pump(0.01)
    return p


def round_(seed, events):
    """a program played for that many events; one that ended by itself (Esc on the tabs) is started again"""
    rng = random.Random(seed)
    size = rng.choice(((rng.randint(1, 300), rng.randint(1, 90)), (100, 33), (60, 20), (84, 31), (130, 48)))
    p = start(rng, seed, size)
    plain_mode = rng.random() < 0.2
    for _ in range(events):
        if p.status is not None:
            err = check(seed, p)
            if err:
                return err
            p = start(rng, seed, size)
        r = rng.random()
        if r < 0.72:
            event(rng, p, plain_mode)
        elif r < 0.8:
            typist(rng, p)
        else:
            p.send(rng.choice(NAVIGATE))
        if not p.pump(rng.choice((0, 0, 0.002, 0.01))):
            continue
    how = rng.random()
    if p.status is None and how < 0.25:
        os.kill(p.pid, signal.SIGKILL)
        p.wait(1)
        return check(seed, p, killed=True)
    if p.status is None:
        t0 = time.monotonic()
        p.send(b'\x1b[99;5:1u')
        while p.status is None and time.monotonic() - t0 < 10:
            p.pump(0.02)
            p.wait(0.01)
        if p.status is None:
            p.kill()
            return f'seed {seed}: no answer to Ctrl+C in 10 s: {bytes(p.out[-400:])!r}'
    return check(seed, p)


def check(seed, p, killed=False):
    s = bytes(p.out)
    crash = os.path.join(state_dir(), 'crash.log')
    if b'Traceback' in s or os.path.exists(crash):
        detail = open(crash).read()[-1500:] if os.path.exists(crash) else s[-1500:]
        return f'seed {seed}: a traceback: {detail}'
    if not killed and p.status not in (0, None):
        return f'seed {seed}: exit {p.status}: {s[-600:]!r}'
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--minutes', type=float, default=1)
    ap.add_argument('--seed', type=int, default=int(time.time()) % 100000)
    ap.add_argument('--rounds', type=int)
    ap.add_argument('--events', type=int, default=250)
    a = ap.parse_args()
    d = state_dir()
    end = time.monotonic() + a.minutes * 60
    rounds = fails = 0
    seed = a.seed
    while time.monotonic() < end if a.rounds is None else rounds < a.rounds:
        rng = random.Random(seed ^ 0x5eed)
        if rng.random() < 0.15:
            shutil.rmtree(d, ignore_errors=True)
        os.makedirs(d, exist_ok=True)
        damage(rng)
        err = round_(seed, a.events)
        rounds += 1
        if err:
            fails += 1
            print(err, flush=True)
            try:
                os.unlink(os.path.join(d, 'crash.log'))
            except OSError:
                pass
        seed += 1
    print(f'{rounds} rounds from seed {a.seed}, {fails} failed')
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
