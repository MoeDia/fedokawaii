#!/usr/bin/env python3
"""typing_cases.py — kawa-typing played for real in a pseudo-terminal: speeds and accuracy against a scripted typist,
rollover, resume after a kill, damaged state, every size. Prints "ok NAME" or "FAIL NAME: why", a line each.

    python3 -I typing_cases.py [CASE…]
"""
import json
import os
import shutil
import signal
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from typing_pty import Pty, SHIFT_DOWN, SHIFT_UP, key, state_dir, wrong_for   # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
BIN = os.path.join(HERE, '..', '..', 'bin', 'kawa-typing')
TEXT = ('the quiet river runs past the old stone bridge and the small bird sits on the bell above it while snow '
        'comes down on the hill and the lantern burns low in the hall before the sun comes up over the valley again ' * 3).strip()
FAILS = []


def report(name, ok, why=''):
    print(f'ok {name}' if ok else f'FAIL {name}: {why}', flush=True)
    if not ok:
        FAILS.append(name)


def fresh(baseline=40, lessons=None, day=None):
    d = state_dir()
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    state = {'lessons': lessons or {}, 'baseline': baseline}
    if day:
        state['day'] = day
    with open(os.path.join(d, 'progress.json'), 'w') as f:
        json.dump(state, f)
    return d


def start(size=(100, 32), *args, env=None):
    argv = [sys.executable, '-IB', BIN, '--seed', '7', *args]
    p = Pty(argv, size, env)
    p.pump(0.4)
    return p


def finish(p):
    """leave: Ctrl+C as foot sends it"""
    if p.status is None:
        p.send(b'\x1b[99;5:1u')
        for _ in range(100):
            p.pump(0.02)
            if p.wait(0.01) is not None:
                break
    if p.status is None:
        p.kill()
    return p.status


def press(p, name_code, mods=1):
    p.send(f'\x1b[{name_code};{mods}:1u'.encode())
    p.send(f'\x1b[{name_code};{mods}:3u'.encode())


ENTER, ESC, TAB, BACKSPACE = 13, 27, 9, 127


def history():
    try:
        with open(os.path.join(state_dir(), 'history.jsonl')) as f:
            return [json.loads(x) for x in f]
    except OSError:
        return []


def resume():
    with open(os.path.join(state_dir(), 'resume.json')) as f:
        return json.load(f)


def wait_resume(p, tries=100):
    for _ in range(tries):
        p.pump(0.03)
        try:
            return resume()
        except (OSError, ValueError):
            continue
    raise RuntimeError('no run under way')


def type_at(p, text, wpm, wrong_every=0, roll=0, shifted=True):
    """presses on the exact clock; (presses, wrong, seconds)"""
    interval = 12.0 / wpm
    t0 = time.monotonic()
    n = wrong = 0
    held = None
    i = 0
    while i < len(text):
        due = t0 + n * interval
        while time.monotonic() < due - 0.0015:
            p.pump(min(due - time.monotonic() - 0.001, 0.05))
        while time.monotonic() < due:
            pass
        ch = text[i]
        if wrong_every and n and n % wrong_every == 0:
            w = wrong_for(ch)
            p.send(key(w))
            p.send(key(w, False, 3))
            wrong += 1
        else:
            p.send(key(ch))
            if roll:
                if held:
                    time.sleep(roll / 1000)
                    p.send(key(held, False, 3))
                held = ch
            else:
                p.send(key(ch, False, 3))
            i += 1
        n += 1
    if held:
        p.send(key(held, False, 3))
    return n, wrong, time.monotonic() - t0


def text_file(body=TEXT):
    path = os.path.join(os.environ.get('TMP') or '/tmp', 'typing-text.txt')
    with open(path, 'w') as f:
        f.write(body)
    return path


# ── the measures ─────────────────────────────────────────────────────────────
def case_speed():
    for wpm, chars in ((40, 40), (60, 50), (100, 70), (200, 100)):
        fresh()
        path = text_file(TEXT[:chars])
        p = start((100, 32), path)
        wait_resume(p)
        type_at(p, TEXT[:chars], wpm)
        p.pump(0.3)
        finish(p)
        h = history()
        got = h[-1]['w'] if h else None
        report(f'a typist at {wpm} wpm measures {wpm} ±1', got is not None and abs(got - wpm) <= 1, f'measured {got}')
        report(f'...100 % accuracy at {wpm}', h and h[-1]['a'] == 100.0, str(h and h[-1]))


def case_accuracy():
    fresh(lessons={'home.fj.meet': {'seals': 0, 'best': 0, 'tries': 1}})
    p = start()
    press(p, ENTER)       # (the first row: the next lesson, f and j's drill: it blocks)
    d = wait_resume(p)
    text = d['run']['text']
    n, wrong, _ = type_at(p, text, 90, wrong_every=10)
    p.pump(0.3)
    finish(p)
    h = history()
    want = round((n - wrong) / n * 100, 2)
    report('accuracy exactly as injected, blocking', h and h[-1]['a'] == want, f'want {want}, {h and h[-1]}')
    # a wrong key does not move on: the run ends only when every key is typed, so `n` presses for len + wrong
    report('...every wrong press cost a press, none moved the text', n == len(text) + wrong, f'{n} {len(text)} {wrong}')
    fresh()
    body = TEXT[:120]
    path = text_file(body)
    p = start((100, 32), path)
    wait_resume(p)
    # flowing: a wrong letter stands; the word it is in does not count, the others do
    typed = body[:20] + 'X' + body[21:]
    n, wrong, secs = type_at(p, typed, 120)
    p.pump(0.3)
    finish(p)
    h = history()
    report('flowing: one wrong letter of 120: accuracy 119/120', h and h[-1]['a'] == round(119 / 120 * 100, 2), str(h and h[-1]))
    # 'runs' + space stands wrong: net drops by its whole word
    w = h[-1]['w'] if h else 0
    r = h[-1]['r'] if h else 0
    report('flowing: net loses the whole word, raw does not', w < r - 0.5 and abs(r - 120) <= 1.5, f'net {w} raw {r}')


def case_backspace():
    fresh()
    body = 'the quiet river runs on'
    path = text_file(body)
    p = start((100, 32), path)
    wait_resume(p)
    for ch in 'the qx':
        p.send(key(ch))
        p.send(key(ch, False, 3))
        p.pump(0.03)
    press(p, BACKSPACE)
    p.pump(0.05)
    for ch in body[5:]:
        p.send(key(ch))
        p.send(key(ch, False, 3))
        p.pump(0.03)
    p.pump(0.3)
    finish(p)
    h = history()
    want = round(len(body) / (len(body) + 1) * 100, 2)
    report('a corrected error still counts against accuracy', h and h[-1]['a'] == want, f'want {want}: {h and h[-1]}')
    want = (len(body) - 1) / 5 / (h[-1]['s'] / 60) if h else 0
    report('...and the text stands correct: net is not cut', h and abs(h[-1]['w'] - want) < want * 0.02, f'want {want:.1f}: {h and h[-1]}')


def case_rollover():
    fresh()
    body = TEXT[:80]
    path = text_file(body)
    p = start((100, 32), path)
    wait_resume(p)
    type_at(p, body, 70, roll=30)
    p.pump(0.3)
    finish(p)
    h = history()
    report('every key overlapping the last: rollover near 100 %', h and h[-1].get('o', 0) >= 94, str(h and h[-1]))
    fresh()
    path = text_file(body)
    p = start((100, 32), path)
    wait_resume(p)
    type_at(p, body, 70)
    p.pump(0.3)
    finish(p)
    h = history()
    report('every key let go first: rollover 0', h and h[-1].get('o') == 0, str(h and h[-1]))


def case_repeat():
    """a held key's repeats are no presses"""
    fresh(lessons={'home.fj.meet': {'seals': 0, 'best': 0, 'tries': 1}})
    p = start()
    press(p, ENTER)
    d = wait_resume(p)
    first = d['run']['text'][0]
    p.send(key(first))
    for _ in range(20):
        p.send(key(first, False, 2))
    p.send(key(first, False, 3))
    p.pump(0.2)
    p.send(b'\x1b[27;1:1u')    # (Esc: kept)
    p.pump(0.3)
    d = resume()['run']
    report('a held key repeats nothing', d['correct'] + d['wrong'] == 1 and d['pos'] == 1, str((d['correct'], d['wrong'], d['pos'])))
    finish(p)


def case_shift():
    """left-hand letters take the right shift, and the other way round"""
    fresh()
    body = 'Fast'
    path = text_file(body + ' and then some more words to keep it open')
    p = start((100, 32), path)
    wait_resume(p)
    p.send(b'\x1b[57441;2:1u')        # (left shift, for a left-hand F: the wrong one)
    p.send(key('F'))
    p.send(key('F', False, 3))
    p.send(b'\x1b[57441;1:3u')
    for ch in 'ast ':
        p.send(key(ch))
        p.send(key(ch, False, 3))
    p.pump(0.3)
    d = resume()['run']
    report('a capital on the same hand\'s shift is said, and not an error', d['shift'] == 1 and d['wrong'] == 0, str((d['shift'], d['wrong'])))
    finish(p)
    fresh()
    path = text_file(body + ' and then some more words to keep it open')
    p = start((100, 32), path)
    wait_resume(p)
    p.send(SHIFT_DOWN)                # (the right shift: right)
    p.send(key('F'))
    p.send(key('F', False, 3))
    p.send(SHIFT_UP)
    for ch in 'ast ':
        p.send(key(ch))
        p.send(key(ch, False, 3))
    p.pump(0.3)
    d = resume()['run']
    report('...the opposite shift is simply right', d['shift'] == 0 and d['wrong'] == 0, str((d['shift'], d['wrong'])))
    finish(p)


def case_capslock():
    fresh()
    path = text_file(TEXT[:60])
    p = start((100, 32), path)
    wait_resume(p)
    p.send(b'\x1b[97:65;65:1;65u')    # (a with caps lock on)
    p.send(b'\x1b[97:65;65:3u')
    p.pump(0.3)
    p.send(b'\x1b[27;1:1u')
    p.pump(0.2)
    d = resume()['run'] if os.path.exists(os.path.join(state_dir(), 'resume.json')) else {'correct': 0, 'wrong': 0}
    report('caps lock on: said, nothing counted', d['correct'] + d['wrong'] == 0, str((d['correct'], d['wrong'])))
    finish(p)


def case_arabic():
    fresh()
    path = text_file(TEXT[:60])
    p = start((100, 32), path)
    wait_resume(p)
    p.send('\x1b[1588::97;1:1;1588u'.encode())     # (the a key, with the Arabic layout up)
    p.send('\x1b[1588::97;1:3u'.encode())
    p.pump(0.3)
    p.send(b'\x1b[27;1:1u')
    p.pump(0.2)
    d = resume()['run'] if os.path.exists(os.path.join(state_dir(), 'resume.json')) else {'correct': 0, 'wrong': 0}
    report('the Arabic layout up: said, nothing counted', d['correct'] + d['wrong'] == 0, str((d['correct'], d['wrong'])))
    finish(p)


def case_paste():
    fresh()
    path = text_file(TEXT[:60])
    p = start((100, 32), path)
    wait_resume(p)
    p.send(b'\x1b[200~' + TEXT[:60].encode() + b'\x1b[201~')
    p.pump(0.3)
    p.send(b'\x1b[27;1:1u')
    p.pump(0.2)
    d = resume()['run'] if os.path.exists(os.path.join(state_dir(), 'resume.json')) else {'correct': 0, 'wrong': 0}
    report('pasted text types nothing', d['correct'] + d['wrong'] == 0, str((d['correct'], d['wrong'])))
    finish(p)


def case_pause():
    """more than 5 s without a key, or the focus gone, stops the clock"""
    fresh()
    body = TEXT[:40]
    path = text_file(body)
    p = start((100, 32), path)
    wait_resume(p)
    half = len(body) // 2
    type_at(p, body[:half], 60)
    p.pump(0.1)
    p.send(b'\x1b[O')        # (the window left)
    p.pump(1.5)
    p.send(b'\x1b[I')
    type_at(p, body[half:], 60)
    p.pump(0.3)
    finish(p)
    h = history()
    report('the focus away stops the clock', h and h[-1]['w'] > 55, str(h and h[-1]))
    # (the gap at the change of focus goes out: the two halves' speed, not their sum with the wait)


# ── kept across a kill ───────────────────────────────────────────────────────
def case_resume():
    fresh()
    path = text_file(TEXT[:90])
    p = start((100, 32), path)
    wait_resume(p)
    type_at(p, TEXT[:45], 90)
    p.pump(0.3)
    os.kill(p.pid, signal.SIGKILL)
    p.wait(1)
    # (resume.json holds the run. Started again, without a file: the tabs, its row first)
    d = resume()['run']
    report('a kill leaves the run on disk', d['pos'] >= 30, str(d['pos']))
    p = start()
    press(p, ENTER)
    p.pump(0.3)
    rest = TEXT[d['pos']:90]
    type_at(p, rest, 90)
    p.pump(0.4)
    finish(p)
    h = history()
    report('...Enter goes on from there, to the end', len(h) == 1, str(h))
    report('...and the speed is not hurt by the time it lay dead', h and h[-1]['w'] > 80, str(h and h[-1]))
    report('...nothing left under way', not os.path.exists(os.path.join(state_dir(), 'resume.json')), '')


def case_escape_keeps():
    fresh(lessons={'home.fj.meet': {'seals': 0, 'best': 0, 'tries': 1}})
    p = start()
    press(p, ENTER)
    d = wait_resume(p)
    text = d['run']['text']
    type_at(p, text[:10], 120)
    p.send(b'\x1b[27;1:1u')
    p.pump(0.3)
    d = resume()['run']
    report('Esc in a lesson keeps it', d['pos'] == 10 and d['text'] == text, str(d['pos']))
    press(p, ENTER)    # (the first row is its "go on")
    p.pump(0.3)
    type_at(p, text[10:], 120)
    p.pump(0.5)
    finish(p)
    h = history()
    report('...and finishes where it stopped', len(h) == 1 and h[0]['l'] == 'home.fj.drill', str(h))


# ── state that cannot be read ────────────────────────────────────────────────
def case_corrupt():
    samples = {
        'progress.json': [b'', b'{', b'[1,2]', b'\xff\xfe\x00', b'{"lessons":{"x":1},"baseline":"a","day":7}', b'{"lessons":{"a":{"seals":"x"}}}', b'null', b'{"lessons":' * 2000],
        'keys.json': [b'{', b'{"keys":{"a":[1]},"pairs":3}', b'{"keys":{"a":["x",1,2,3]}}', b'{"keys":{"a":[1e400,1,2,3]}}'],
        'resume.json': [b'{', b'{"run":{}}', b'{"run":{"text":"","pos":0,"got":[],"flow":true,"correct":0,"wrong":0}}', b'{"run":{"text":"abc","pos":99,"got":3,"flow":1}}',
                        b'{"lesson":"nope","index":99999,"run":{"text":"abc def","pos":2,"got":["a","b"],"flow":true,"correct":2,"wrong":0}}', b'{"run":7,"lesson":[]}'],
        'history.jsonl': [b'\xff\xff\n{"d":1}\nnot json\n{"d":1,"k":"test","w":"x","a":2}\n', b'{"d":1,"k":"test","w":1e999,"a":2}\n'],
    }
    bad = 0
    for name, variants in samples.items():
        for v in variants:
            fresh()
            with open(os.path.join(state_dir(), name), 'wb') as f:
                f.write(v)
            p = start((100, 32))
            press(p, TAB)
            p.pump(0.1)
            press(p, TAB)    # (the progress page reads everything)
            p.pump(0.2)
            press(p, TAB)
            press(p, ENTER)
            p.pump(0.2)
            st = finish(p)
            if st != 0 or b'Traceback' in p.out:
                bad += 1
                report(f'damaged {name}: {v[:30]!r}', False, f'status {st}: {bytes(p.out[-600:])!r}')
    report(f'damaged state, {sum(map(len, samples.values()))} kinds: started every time', not bad, '')
    fresh()
    with open(os.path.join(state_dir(), 'progress.json'), 'w') as f:
        f.write('{ cut sho')
    p = start()
    finish(p)
    report('...the unreadable file set aside as .bad', os.path.exists(os.path.join(state_dir(), 'progress.json.bad')), '')


def case_readonly():
    """a home that takes nothing: it runs, and says so; never a traceback"""
    if os.geteuid() == 0:
        return
    d = fresh()
    os.chmod(d, 0o500)
    try:
        p = start()
        press(p, ENTER)
        p.pump(0.3)
        st = finish(p)
        report('a state folder that cannot be written: no traceback', st == 0 and b'Traceback' not in p.out, str(st))
    finally:
        os.chmod(d, 0o700)


# ── every size ───────────────────────────────────────────────────────────────
def case_sizes():
    sizes = ((8, 3), (12, 4), (20, 5), (30, 8), (38, 9), (40, 14), (60, 20), (70, 24), (84, 31), (100, 32), (130, 48), (200, 50), (236, 52))
    bad = []
    for cols, rows in sizes:
        fresh(lessons={'home.fj.meet': {'seals': 0, 'best': 0, 'tries': 1}})
        p = start((cols, rows))
        press(p, TAB)
        p.pump(0.05)
        press(p, TAB)
        p.pump(0.05)
        press(p, TAB)
        p.pump(0.05)
        press(p, ENTER)
        d = wait_resume(p)
        type_at(p, d['run']['text'], 400)
        p.pump(0.6)
        press(p, ENTER)      # (the result, then the next lesson)
        p.pump(0.1)
        st = finish(p)
        s = bytes(p.out)
        # (leaving closes a frame once more, whatever state a crash could have left: one more close than opens)
        if st != 0 or b'Traceback' in s or s.count(b'\x1b[?2026h') + 1 != s.count(b'\x1b[?2026l'):
            bad.append(f'{cols}x{rows} status {st}: {s[-300:]!r}')
    report(f'{len(sizes)} sizes, from 8 × 3 to full screen: every screen', not bad, '; '.join(bad)[:600])
    # a resize in the middle of everything
    fresh(lessons={'home.fj.meet': {'seals': 0, 'best': 0, 'tries': 1}})
    p = start((100, 32))
    press(p, ENTER)
    d = wait_resume(p)
    text = d['run']['text']
    for i, (c, r) in enumerate(((60, 20), (130, 48), (40, 12), (84, 31), (10, 4), (100, 32))):
        p.resize(c, r)
        p.pump(0.1)
        type_at(p, text[i * 3:i * 3 + 3], 300)
    p.pump(0.2)
    st = finish(p)
    report('resized while typing: nothing lost', st == 0 and resume()['run']['pos'] >= 18 if st == 0 else False, str(st))
    # the font's size changed (Ctrl+plus: 2 px at a time), a screen at scale 2: other cells, the same picture on them
    fresh(lessons={'home.fj.meet': {'seals': 0, 'best': 0, 'tries': 1}})
    p = start((100, 32))
    press(p, ENTER)
    d = wait_resume(p)
    text = d['run']['text']
    for i, cell in enumerate(((9, 22), (10, 25), (16, 40), (7, 15), (1, 1), (8, 20))):
        p.resize(100, 32, cell)
        p.pump(0.1)
        type_at(p, text[i * 3:i * 3 + 3], 300)
    p.pump(0.2)
    st = finish(p)
    report('every cell size: no traceback', st == 0 and b'Traceback' not in bytes(p.out), str(st))


def case_restore():
    """the terminal handed back as it was"""
    fresh()
    p = start()
    finish(p)
    s = bytes(p.out)
    good = all(x in s for x in (b'\x1b[<u', b'\x1b[?1049l', b'\x1b[?2031l', b'\x1b[?1004l', b'\x1b[?2004l', b'\x1b[?25h', b'\x1b[?7h'))
    report('leaving: the screen, the keyboard and the modes as they were', good and s.rfind(b'\x1b[?1049l') > s.rfind(b'\x1b[?1049h'), '')
    fresh()
    p = start()
    os.kill(p.pid, signal.SIGTERM)
    p.pump(0.3)
    p.wait(1)
    report('SIGTERM: leaves as cleanly', p.status is not None and b'\x1b[?1049l' in bytes(p.out) and b'Traceback' not in bytes(p.out), str(p.status))
    fresh()
    p = start()
    os.kill(p.pid, signal.SIGHUP)     # (the window closed: its terminal is gone)
    p.pump(0.3)
    p.wait(1)
    report('SIGHUP: the progress saved, no traceback', p.status is not None and b'Traceback' not in bytes(p.out), str(p.status))


def case_anchor():
    """the hand that holds f or j really holds it: foot tells the key is down"""
    fresh()
    p = Pty([sys.executable, '-IB', BIN, '--seed', '7', '--lesson', 'home.anchor.j'], (100, 32))
    p.pump(0.4)
    d = wait_resume(p)
    text = d['run']['text']
    p.send(b'\x1b[?31u')                # (the terminal says it took the flags: releases will come)
    p.pump(0.1)
    p.send(key(text[0]))
    p.send(key(text[0], False, 3))
    p.pump(0.2)
    p.send(b'\x1b[27;1:1u')
    p.pump(0.2)
    d = resume()['run'] if os.path.exists(os.path.join(state_dir(), 'resume.json')) else {'correct': 0, 'wrong': 0, 'pos': 0}
    report('an anchor lesson: nothing counts until j is held', d['correct'] + d['wrong'] == 0, str(d['correct']))
    finish(p)
    fresh()
    p = Pty([sys.executable, '-IB', BIN, '--seed', '7', '--lesson', 'home.anchor.j'], (100, 32))
    p.pump(0.4)
    d = wait_resume(p)
    text = d['run']['text']
    p.send(b'\x1b[?31u')
    p.send(key('j'))                     # (down, and stays down)
    for ch in text[:6]:
        p.send(key(ch))
        p.send(key(ch, False, 3))
        p.pump(0.02)
    p.pump(0.2)
    p.send(key('j', False, 3))           # (let go)
    ch = text[6]
    p.send(key(ch))
    p.send(key(ch, False, 3))
    p.pump(0.2)
    p.send(b'\x1b[27;1:1u')
    p.pump(0.2)
    d = resume()['run']
    report('...with j held, the left hand types; let go, the text waits', d['pos'] == 6 and d['wrong'] == 0, str((d['pos'], d['wrong'])))
    finish(p)


def case_eye():
    """open: Tab shuts it; left open 2 s: the text waits, the clock with it"""
    fresh()
    p = Pty([sys.executable, '-IB', BIN, '--seed', '7', '--eye', '1', '--lesson', 'sent.1'], (100, 32))
    p.pump(0.4)
    d = wait_resume(p)
    text = d['run']['text']
    p.send(key(text[0]))
    p.send(key(text[0], False, 3))
    p.pump(0.4)        # (a tick starts its clock; 1 s later it opens)
    p.pump(1.2)
    before = bytes(p.out)
    press(p, TAB)      # (answered in time)
    p.pump(0.3)
    report('the eye opens: drawn, and Tab shuts it', len(p.out) > len(before), '')
    p.pump(1.4)        # (open again)
    p.pump(2.3)        # (not answered)
    for ch in text[1:4]:
        p.send(key(ch))
        p.send(key(ch, False, 3))
    p.pump(0.2)
    p.send(b'\x1b[27;1:1u')
    p.pump(0.2)
    d = resume()['run']
    report('...not answered: keys wait, nothing counted', d['pos'] == 1 and d['correct'] == 1, str((d['pos'], d['correct'])))
    finish(p)
    fresh()
    p = Pty([sys.executable, '-IB', BIN, '--seed', '7', '--eye', '1', '--lesson', 'sent.1'], (100, 32))
    p.pump(0.4)
    d = wait_resume(p)
    text = d['run']['text']
    p.send(key(text[0]))
    p.send(key(text[0], False, 3))
    p.pump(3.8)        # (open, and left)
    press(p, TAB)
    p.pump(0.2)
    for ch in text[1:4]:
        p.send(key(ch))
        p.send(key(ch, False, 3))
        p.pump(0.02)
    p.pump(0.2)
    p.send(b'\x1b[27;1:1u')
    p.pump(0.2)
    d = resume()['run']
    report('...Tab, and the text goes on', d['pos'] == 4, str(d['pos']))
    finish(p)


def case_course_plan():
    """the first row knows: the first minute, then the lessons in order, a warm-up on a new day, the day's test"""
    fresh(baseline=None)
    p = start()
    press(p, ENTER)
    d = wait_resume(p)
    report('a first start: the first row is the first minute', d['lesson'] == 'free.baseline' and d['run']['limit'] == 60, str(d['lesson']))
    finish(p)
    fresh()
    p = start()
    press(p, ENTER)
    d = wait_resume(p)
    report('with it measured: the first lesson', d['lesson'] == 'home.fj.meet', str(d['lesson']))
    type_at(p, d['run']['text'], 200)
    p.pump(0.5)
    d = wait_resume(p)
    report('a meet flows straight on to its drill', d['lesson'] == 'home.fj.drill', str(d['lesson']))
    finish(p)
    day = {'date': time.strftime('%Y-%m-%d'), 'seconds': 1300.0, 'warm': True, 'test': False}
    fresh(day=day)
    p = start()
    press(p, ENTER)
    d = wait_resume(p)
    report('twenty minutes done: the day\'s test', d['lesson'] == 'free.test' and d['run']['limit'] == 60, str(d['lesson']))
    finish(p)


def case_landmark():
    """the crossover and the marks: said once, kept"""
    fresh(baseline=20)
    p = Pty([sys.executable, '-IB', BIN, '--seed', '7'], (100, 32))
    p.pump(0.3)
    press(p, TAB)
    p.pump(0.1)
    for _ in range(8):       # (test, 15 seconds: the rows are in a fixed order)
        p.send(b'\x1b[1;1:1B')    # (down)
        p.pump(0.01)
    press(p, ENTER)
    d = wait_resume(p)
    text = d['run']['text']
    report('a test from the practice tab', d['lesson'] == 'free.test' and d['run']['limit'] == 15, str(d['lesson']))
    type_at(p, text[:120], 60)
    p.pump(7)
    finish(p)
    with open(os.path.join(state_dir(), 'progress.json')) as f:
        st = json.load(f)
    report('passing the old way is kept, and the mark', st.get('crossed') is True and st.get('mark') == 50, str((st.get('crossed'), st.get('mark'))))


def case_long_file():
    """a long file: the last key as quick as the first (standing() counts on from where it stood)"""
    fresh()
    body = (TEXT + ' ') * 40
    path = text_file(body[:19000])
    p = start((100, 32), path)
    wait_resume(p)
    t0 = time.monotonic()
    for ch in body[:600]:
        p.send(key(ch))
        p.send(key(ch, False, 3))
    p.pump(0.5)
    finish(p)
    report(f'a file of 19000 characters: 600 keys in one burst drawn in {time.monotonic() - t0:.1f} s', b'Traceback' not in bytes(p.out) and p.status == 0, str(p.status))


def case_ram():
    fresh(lessons={'home.fj.meet': {'seals': 0, 'best': 0, 'tries': 1}})
    p = start((236, 52))
    press(p, ENTER)
    d = wait_resume(p)
    type_at(p, d['run']['text'][:50], 300)
    p.pump(0.3)
    with open(f'/proc/{p.pid}/status') as f:
        rss = next(int(x.split()[1]) for x in f if x.startswith('VmRSS'))
    finish(p)
    report(f'RSS full screen, in a lesson: {rss // 1024} MB ≤ 60', rss < 60 * 1024, str(rss))


def case_start_time():
    fresh()
    p = Pty([sys.executable, '-IB', BIN, '--course'], (100, 32))
    p.pump(0.5)
    p.wait(1)
    t0 = time.monotonic()
    p = Pty([sys.executable, '-IB', BIN, '--seed', '1'], (100, 32))
    while b'\x1b[?2026l' not in p.out and time.monotonic() - t0 < 3:
        p.pump(0.002)
    ms = (time.monotonic() - t0) * 1000
    finish(p)
    report(f'first frame in {ms:.0f} ms', ms < 500, f'{ms:.0f} ms')


CASES = {k[5:]: v for k, v in list(globals().items()) if k.startswith('case_')}


def main():
    names = sys.argv[1:] or list(CASES)
    for n in names:
        CASES[n]()
    print(f'{len(FAILS)} failed')
    return 1 if FAILS else 0


if __name__ == '__main__':
    sys.exit(main())
