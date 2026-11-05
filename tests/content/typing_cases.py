#!/usr/bin/env python3
"""typing_cases.py — kawa-typing played for real in a pseudo-terminal: speeds and accuracy against a scripted typist,
rollover, resume after a kill, damaged state, every size. Prints "ok NAME" or "FAIL NAME: why", a line each.

    python3 -I typing_cases.py [CASE…]
"""
import json
import math
import os
import re
import shutil
import signal
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from typing_pty import Pty, SHIFT_DOWN, SHIFT_UP, key, state_dir, wrong_for   # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
BIN = os.environ.get('TYPING_BIN') or os.path.join(HERE, '..', '..', 'bin', 'kawa-typing')
TEXT = ('the quiet river runs past the old stone bridge and the small bird sits on the bell above it while snow '
        'comes down on the hill and the lantern burns low in the hall before the sun comes up over the valley again ' * 3).strip()
FAILS = []


def report(name, ok, why=''):
    print(f'ok {name}' if ok else f'FAIL {name}: {why}', flush=True)
    if not ok:
        FAILS.append(name)


def trace():
    return os.path.join(state_dir(), '..', 'typing-trace.json')


def fresh(baseline=40, lessons=None, day=None):
    d = state_dir()
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    if os.path.exists(trace()):
        os.unlink(trace())
    state = {'lessons': lessons or {}, 'baseline': baseline}
    if day:
        state['day'] = day
    with open(os.path.join(d, 'progress.json'), 'w') as f:
        json.dump(state, f)
    return d


def start(size=(100, 32), *args, env=None):
    argv = [sys.executable, '-IB', BIN, '--seed', '7', '--trace', trace(), *args]
    p = Pty(argv, size, env)
    for _ in range(200):       # (its first frame: a key sent before raw mode is the line discipline's, and is flushed)
        p.pump(0.05)
        if b'\x1b[?2026l' in p.out or p.status is not None:
            break
    p.pump(0.05)
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
    """the run under way, any kind (--trace)"""
    with open(trace()) as f:
        return json.load(f)


def kept():
    """what stays for later: a course's lesson"""
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
    d = resume()['run']
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
    d = resume()['run']
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
    d = resume()['run']
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
    fresh(lessons={'home.fj.meet': {'seals': 0, 'best': 0, 'tries': 1}})
    p = start((100, 32), '--lesson', 'home.fj.words')
    d = wait_resume(p)
    text = d['run']['text']
    type_at(p, text[:45], 90)
    p.pump(0.4)
    os.kill(p.pid, signal.SIGKILL)
    p.wait(1)
    d = kept()['run']
    report('a kill leaves the lesson on disk', d['pos'] >= 25 and d['text'] == text, str(d['pos']))
    p = start()                  # (started again: the tabs, its row first)
    press(p, ENTER)
    p.pump(0.3)
    type_at(p, text[d['pos']:], 90)
    p.pump(0.5)
    finish(p)
    h = history()
    report('...Enter goes on from there, to the end', len(h) == 1 and h[0]['l'] == 'home.fj.words', str(h))
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
    d = kept()['run']
    report('Esc in a lesson keeps it', d['pos'] == 10 and d['text'] == text, str(d['pos']))
    press(p, ENTER)    # (the first row is its "go on")
    p.pump(0.3)
    type_at(p, text[10:], 120)
    p.pump(0.5)
    finish(p)
    h = history()
    report('...and finishes where it stopped', len(h) == 1 and h[0]['l'] == 'home.fj.drill', str(h))


def case_kept_is_not_lost():
    """a kept lesson survives the practice tab, a file, and another lesson opened and left untouched"""
    fresh(lessons={'home.fj.meet': {'seals': 0, 'best': 0, 'tries': 1}})
    p = start()
    press(p, ENTER)
    d = wait_resume(p)
    text = d['run']['text']
    type_at(p, text[:10], 120)
    p.send(b'\x1b[27;1:1u')       # (kept)
    p.pump(0.2)
    press(p, TAB)
    p.pump(0.05)
    press(p, ENTER)                # (a practice run, typed in and left)
    d2 = wait_resume(p)
    for ch in d2['run']['text'][:5]:
        p.send(key(ch))
        p.send(key(ch, False, 3))
    p.pump(0.2)
    p.send(b'\x1b[27;1:1u')
    p.pump(0.2)
    report('a practice run opened and left: the kept lesson stays', kept()['run']['pos'] == 10 and kept()['run']['text'] == text, str(kept()['run']['pos']))
    finish(p)
    p = start((100, 32), '--lesson', 'home.dk.drill')    # (another lesson, left untouched)
    p.pump(0.3)
    p.send(b'\x1b[27;1:1u')
    p.pump(0.2)
    report('...another lesson opened and left untouched: it stays', kept()['lesson'] == 'home.fj.drill', str(kept()['lesson']))
    finish(p)
    p = start((100, 32), '--lesson', 'home.fj.drill')    # (its own row in the list: where it stood, not afresh)
    d = wait_resume(p)
    report('...the lesson opened from its row goes on where it stood', d['run']['pos'] == 10, str(d['run']['pos']))
    finish(p)


def case_file_names():
    """a file is a file, whatever it is called"""
    for name in ('test', 'code', 'words', 'passage', 'weak', 'warmup', 'baseline'):
        fresh()
        path = os.path.join(os.environ.get('TMP') or '/tmp', name)
        with open(path, 'w') as f:
            f.write('the quiet river runs')
        p = start((100, 32), path)
        d = wait_resume(p)
        st = finish(p)
        ok = st == 0 and d['run']['text'] == 'the quiet river runs' and d['title'] == name
        with open(os.path.join(state_dir(), 'progress.json')) as f:
            ok = ok and json.load(f)['baseline'] == 40
        os.unlink(path)
        if not ok:
            report(f'a file called {name}', False, f'{st} {d}')
            return
    report('a file called test, code, words, baseline ...: typed as what it is', True)


def case_eye_stays():
    """the eye keeps its row: from a notice that ends, in a window with no keyboard; a theme switch keeps the text dim"""
    fresh()
    p = start((30, 12), '--eye', '1', '--lesson', 'sent.1')      # (no room for the keyboard)
    d = wait_resume(p)
    text = d['run']['text']
    p.send(key(text[0]))
    p.send(key(text[0], False, 3))
    p.pump(1.6)
    n = len(p.out)
    p.pump(0.3)
    report('a small window: the eye is drawn and says tab', b'tab' in bytes(p.out), '')
    p.pump(2.2)
    p.send(b'\x1b[?997;2n')       # (the theme, while dimmed)
    p.pump(0.3)
    p.send(key('q'))
    p.pump(0.2)
    press(p, TAB)
    p.pump(0.2)
    p.send(b'\x1b[27;1:1u')
    p.pump(0.2)
    d = resume()['run']
    report('...dimmed through a theme switch: keys still wait, Tab answers', d['pos'] == 1 and d['correct'] == 1 and d['wrong'] == 0, str((d['pos'], d['wrong'])))
    st = finish(p)
    report('...no traceback', st == 0 and n > 0, str(st))


def case_caps_off():
    fresh()
    p = start((100, 32), '--lesson', 'sent.1')
    d = wait_resume(p)
    text = d['run']['text']
    p.send(b'\x1b[57358;1:1u\x1b[57358;65:3u')     # (caps lock on)
    p.pump(0.1)
    p.send(key(text[0]).replace(b';1:1;', b';65:1;'))
    p.pump(0.1)
    p.send(b'\x1b[57358;65:1u\x1b[57358;1:3u')     # (and off again)
    p.pump(0.1)
    p.send(key(text[0]))
    p.send(key(text[0], False, 3))
    p.pump(0.2)
    p.send(b'\x1b[27;1:1u')
    p.pump(0.2)
    d = resume()['run']
    report('caps lock off again: the next key counts at once', d['pos'] == 1 and d['correct'] == 1, str((d['pos'], d['correct'])))
    finish(p)


def case_landmark_words():
    fresh(baseline=20)
    p = start()
    text = timed_test(p)
    type_at(p, text[:130], 120)    # (13 s of keys; its clock runs out 2 s later)
    p.pump(3)
    finish(p)
    s = bytes(p.out)
    report('the crossover is said on the result', b'past your old way' in s, str(history()))
    fresh(baseline=20, day={'date': time.strftime('%Y-%m-%d'), 'seconds': 1300.0, 'warm': True, 'test': False})
    p = start()
    press(p, ENTER)
    d = wait_resume(p)
    report('the day\'s test comes first', d['lesson'] == 'free.test', str(d['lesson']))
    finish(p)


def case_practice_returns():
    """Enter on a practice run's result goes back to the practice tab, not on into the course"""
    fresh()
    p = start()
    text = timed_test(p)
    type_at(p, text[:130], 120)
    p.pump(3)                      # (its clock runs out)
    n = len(p.out)
    press(p, ENTER)
    p.pump(0.4)
    report('a test from the practice tab: Enter goes back there', b'practice' in bytes(p.out[n:]) and not os.path.exists(os.path.join(state_dir(), 'resume.json')), '')
    finish(p)


# ── state that cannot be read ────────────────────────────────────────────────
def case_corrupt():
    samples = {
        'progress.json': [b'', b'{', b'[1,2]', b'\xff\xfe\x00', b'{"baseline":1' + b'0' * 400 + b'}', b'[' * 100000, b'{"lessons":{"x":1},"baseline":"a","day":7}', b'{"lessons":{"a":{"seals":"x"}}}', b'null', b'{"lessons":' * 2000],
        'keys.json': [b'{', b'{"keys":{"a":[1]},"pairs":3}', b'{"keys":{"a":["x",1,2,3]}}', b'{"keys":{"a":[1e400,1,2,3]}}'],
        'resume.json': [b'{', b'{"run":{}}', b'{"run":{"text":"","pos":0,"got":[],"flow":true,"correct":0,"wrong":0}}', b'{"run":{"text":"abc","pos":99,"got":3,"flow":1}}',
                        b'{"lesson":"nope","index":99999,"run":{"text":"abc def","pos":2,"got":["a","b"],"flow":true,"correct":2,"wrong":0}}', b'{"run":7,"lesson":[]}',
                        b'{"lesson":"home.fj.drill","index":1,"run":{"text":"abc","pos":1,"got":["a"],"flow":true,"correct":1,"wrong":0,"limit":"x"}}',
                        b'{"lesson":"home.fj.drill","index":1,"run":{"text":"abc","pos":Infinity,"got":["a"],"flow":true,"correct":1,"wrong":0}}'],
        'history.jsonl': [b'\xff\xff\n{"d":1}\nnot json\n{"d":1,"k":"test","w":"x","a":2}\n', b'{"d":1,"k":"test","w":1e999,"a":2}\n', b'[' * 100000 + b'\n',
                          b'{"d":1,"k":"test","w":1' + b'0' * 400 + b',"a":2}\n'],
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
    sizes = ((8, 3), (12, 4), (20, 5), (30, 8), (38, 9), (40, 14), (60, 20), (70, 24), (80, 39), (84, 31), (100, 32), (130, 48), (200, 50), (236, 52))
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
    p = start((100, 32), '--lesson', 'home.anchor.j')
    d = wait_resume(p)
    text = d['run']['text']
    p.send(b'\x1b[?31u')                # (the terminal says it took the flags: releases will come)
    p.pump(0.1)
    p.send(key(text[0]))
    p.send(key(text[0], False, 3))
    p.pump(0.2)
    p.send(b'\x1b[27;1:1u')
    p.pump(0.2)
    d = resume()['run']
    report('an anchor lesson: nothing counts until j is held', d['correct'] + d['wrong'] == 0, str(d['correct']))
    finish(p)
    fresh()
    p = start((100, 32), '--lesson', 'home.anchor.j')
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
    p = start((100, 32), '--eye', '1', '--lesson', 'sent.1')
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
    p = start((100, 32), '--eye', '1', '--lesson', 'sent.1')
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
    p = start()
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


def case_indent():
    """code: a line's indent is the editor's work: not typed, and no speed from it"""
    fresh()
    body = 'def add(a, b):\n    return a + b\n\nprint(add(1, 2))'
    path = text_file(body)
    p = start((100, 32), path)
    d = wait_resume(p)
    report('the file as typed text', d['run']['text'] == body, repr(d['run']['text'][:40]))
    typed = ''.join(body.split('    '))     # (no indent)
    n, _, _ = type_at(p, typed, 60)
    p.pump(0.4)
    finish(p)
    h = history()
    report('...every line ends with Enter, the indent is skipped, all of it right', h and h[-1]['a'] == 100.0 and n == len(typed), str(h and h[-1]))
    report('...and 60 wpm typed measures 60, not more for the indent', h and abs(h[-1]['w'] - 60) <= 1.5, str(h and h[-1]))


def demo_state():
    """three weeks of practice, as the app itself would have kept them"""
    d = fresh(baseline=30, lessons={'home.fj.meet': {'seals': 0, 'best': 0, 'tries': 1}, 'home.fj.drill': {'seals': 3, 'best': 21.5, 'tries': 2}})
    now = int(time.time())
    with open(os.path.join(d, 'history.jsonl'), 'w') as f:
        for k in range(40):
            f.write(json.dumps({'d': now - (40 - k) * 40000, 'l': 'free.test', 'k': 'test', 'w': 20 + k, 'r': 22 + k, 'a': 97.5, 's': 60.0, 'c': 70.0, 'o': 10.0}) + '\n')
    keys_ = {c: [200, 2 + 40 * (c in 'qz'), 180.0 + 200 * (c in 'qzp'), 170.0] for c in 'abcdefghijklmnopqrstuvwxyz'}
    with open(os.path.join(d, 'keys.json'), 'w') as f:
        json.dump({'keys': keys_, 'pairs': {'th': [50, 0, 300.0, 0.0], 'he': [50, 0, 100.0, 0.0]}}, f)
    return d


def case_screens():
    """every row of every tab opened, typed in and left; every stage opened; the pages with data on them"""
    down = b'\x1b[1;1:1B'
    bad = []
    for size in ((80, 39), (60, 21), (130, 49)):
        demo_state()
        p = start(size)
        for _ in range(3):
            for _ in range(12):        # (every row: down and Enter, a few keys, Esc, back to the tab)
                p.send(down)
                p.pump(0.01)
            press(p, TAB)
            p.pump(0.05)
        for i in range(11):            # (the practice tab's rows, each one started)
            press(p, TAB)              # (course → practice)
            p.pump(0.03)
            for _ in range(i):
                p.send(down)
                p.pump(0.005)
            press(p, ENTER)
            p.pump(0.1)
            try:
                d = resume()['run']
                for ch in d['text'][:4]:
                    p.send(key(ch))
                    p.send(key(ch, False, 3))
            except (OSError, ValueError, KeyError):
                bad.append(f'row {i}: no run')
            p.pump(0.05)
            p.send(b'\x1b[27;1:1u')     # (Esc: to the course tab)
            p.pump(0.05)
        for s in range(9):             # (every stage opened, Esc back)
            for _ in range(s + 1):
                p.send(down)
                p.pump(0.005)
            press(p, ENTER)
            p.pump(0.05)
            p.send(b'\x1b[1;1:1F')      # (to its last lesson)
            p.send(b'\x1b[1;1:1H')
            p.pump(0.02)
            p.send(b'\x1b[27;1:1u')
            p.pump(0.03)
        st = finish(p)
        if st != 0 or b'Traceback' in bytes(p.out):
            bad.append(f'{size}: status {st}: {bytes(p.out[-300:])!r}')
    report('every row, tab and stage, at three sizes, with three weeks of data', not bad, '; '.join(bad)[:500])


def case_pacer():
    fresh()
    p = start((100, 33), '--lesson', 'speed.30.pacer')
    d = wait_resume(p)
    text = d['run']['text']
    n = len(p.out)
    type_at(p, text[:6], 30)
    p.pump(1.5)        # (the pacer walks on, a letter every 0.4 s)
    grew = len(p.out) - n
    st = finish(p)
    report('the pacer walks while the caret waits', st == 0 and grew > 1000 and b'Traceback' not in bytes(p.out), f'{grew} bytes, status {st}')


def timed_test(p):
    press(p, TAB)
    p.pump(0.1)
    for _ in range(8):
        p.send(b'\x1b[1;1:1B')
        p.pump(0.01)
    press(p, ENTER)
    return wait_resume(p)['run']['text']


def case_clock_runs_out():
    """a timed test ends on its clock, with keys or without them in its last seconds; a real pause stops it"""
    fresh()
    p = start()
    text = timed_test(p)
    type_at(p, text[:160], 150)     # (12.8 s of keys, then nothing)
    p.pump(3.5)
    st = finish(p)
    h = history()
    report('a 15 s test whose last keys came early ends on its clock', len(h) == 1 and abs(h[0]['s'] - 15) < 0.5, str(h))
    report('...measured over its 15 s', h and abs(h[0]['w'] - (160 - 1) / 5 / 0.25) < 3 and st == 0, str((h, st)))
    fresh()
    p = start()
    text = timed_test(p)
    type_at(p, text[:30], 150)      # (2.4 s, then more than 5 s of nothing: the clock stops)
    p.pump(9)
    report('...more than 5 s without a key: it waits, it does not end', not history(), str(history()))
    st = finish(p)
    report('...and can still be left', st == 0, str(st))


def case_tables():
    """the seals' table and the measures, as curriculum.md writes them"""
    sys.path.insert(0, os.path.join(HERE, '..', '..', 'configs/home/.local/lib/fedokawaii'))
    from kawatype.app import fit_power, seals_for, wrap
    from kawatype.metrics import Run, kogasa
    rows = [(96.9, 50, 12, 0), (97, 4, 12, 0), (97, 5, 12, 1), (97, 7.34, 12, 2), (97, 9.7, 12, 3), (98.9, 12, 12, 4), (99, 12, 12, 5), (99.9, 18, 12, 5), (100, 18, 12, 6)]
    bad = [r for r in rows if seals_for(r[1], r[0], 5, r[2]) != r[3]]
    report('the seals as curriculum.md\'s table', not bad, str(bad))
    report('consistency: kogasa(0) = 100, Monkeytype\'s formula', abs(kogasa(0) - 100) < 1e-9 and abs(kogasa(1) - 8.9) < 0.3, str(kogasa(1)))
    r = Run('ab cd', flow=True)
    for t, c in ((0.0, 'a'), (0.1, 'x'), (0.2, ' '), (0.3, 'c'), (0.4, 'd')):
        r.press(c, t)
    report('flowing: a word with a wrong letter does not count, the partial last word does', r.standing() == 2, str(r.standing()))
    r = Run('abc def', flow=True)
    for t, c in ((0.0, 'a'), (0.1, 'b'), (0.2, 'c'), (10.0, ' '), (10.1, 'd')):
        r.press(c, t)
    report('a gap over 5 s is out of the clock', abs(r.active() - 0.3) < 1e-6, str(r.active()))
    r = Run('abcdef' * 10)
    for i, c in enumerate('abcdef' * 5):
        r.press(c, i * 0.2)
    report('(C − 1) / 5 / minutes: 200 ms a key is 60.0 wpm whatever the length', abs(r.net() - 60) < 1e-6, str(r.net()))
    lines = wrap('the quick brown fox\njumps over', 10)
    report('wrap: at words and at Enter, nothing lost', ''.join('the quick brown fox\njumps over'[a:b] for a, b in lines) == 'the quick brown fox\njumps over'
           and all(b - a <= 11 for a, b in lines), str(lines))
    from kawatype import canvas
    pic = canvas.Picture(40, 20, (8, 20))    # (the eye's: a row, five cells)
    pic.fill(0, 0, 40, 20, 1)
    out = pic.send(3, 9, {1: b'1;2;3'})
    report('a picture\'s erase is its own cells: never what lies below it', out.count(b'X') == 1 and b'\x1b[9;3H\x1b[5X' in out, repr(out[:40]))
    day = 86400
    tests = [{'d': 1000000 + i * day, 'w': 20 + 2 * i} for i in range(20)]
    when = fit_power(tests)
    report('the line to 100 wpm: a rising curve reaches it, later than its last test', when is not None and when > tests[-1]['d'], str(when))
    report('...a flat one, or too little data: no promise', fit_power([{'d': 1000000 + i * day, 'w': 40} for i in range(20)]) is None and fit_power(tests[:5]) is None, '')
    back = [{'d': 2000000 - i * day, 'w': 20 + i} for i in range(20)]     # (a clock set back: dates out of order)
    report('...dates out of order are no crash', fit_power(back) is None or fit_power(back) > 0, '')
    r = Run('abcdef ghijkl', flow=True)
    for t, c in ((0.0, 'a'), (1.0, 'b'), (2.0, 'c')):
        r.press(c, t)
    for t in (5.0, 8.0):
        r.backspace(t)
    r.press('b', 11.0)
    report('corrections keep the clock going: 3 s between them is no pause', abs(r.active() - 11.0) < 1e-6, str(r.active()))
    from kawatype.app import percent
    report('96.97 % reads 96.9, under the bar it missed', percent(64 / 66 * 100) == '96.9' and percent(100) == '100.0', percent(64 / 66 * 100))


def case_quiet():
    """Ctrl+K: the next key's light off, remembered; the keyboard itself stays"""
    fresh()
    p = start((100, 33), '--lesson', 'home.fj.drill')
    p.pump(0.2)
    n = len(p.out)
    p.send(b'\x1b[107;5:1u')
    p.pump(0.2)
    report('Ctrl+K repaints the keyboard', len(p.out) > n, '')
    st = finish(p)
    with open(os.path.join(state_dir(), 'progress.json')) as f:
        report('...and is remembered', json.load(f)['quiet'] is True and st == 0, str(st))


def case_mouse():
    """the pointer on the tabs and the rows (§5: hover is the cursor, a click is Enter)"""
    fresh()
    p = start((80, 39))
    n = len(p.out)
    p.send(b'\x1b[<35;10;7M')        # (over the third row)
    p.pump(0.1)
    report('hover moves the cursor', len(p.out) > n, '')
    p.send(b'\x1b[<0;10;5M\x1b[<0;10;5m')   # (a click on the first row: the first lesson)
    d = wait_resume(p)
    report('a click on a row goes', d['lesson'] == 'home.fj.meet', str(d['lesson']))
    st = finish(p)
    fresh()
    p = start((80, 39))
    n = len(p.out)
    p.send(b'\x1b[<0;15;2M\x1b[<0;15;2m')   # (a click on the next tab's icon: the course tab takes columns 2–10, then a gap of 3)
    p.pump(0.2)
    report('a click on a tab changes it', b'practice' in bytes(p.out[n:]), '')
    report('...no traceback', finish(p) == 0 and st == 0, '')


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


class NoTerminal:
    """what a screen writes, kept: its layout and drawing played in this process"""

    def __init__(self):
        self.out = []

    def write(self, b):
        self.out.append(b if isinstance(b, str) else b.decode('latin-1'))

    def flush(self):
        pass

    def mouse_on(self, on):
        pass


def no_terminal():
    sys.path.insert(0, os.path.join(HERE, '..', '..', 'configs/home/.local/lib/fedokawaii'))
    from kawatype import app, art, canvas, course, term
    return app, art, canvas, course, term


def case_verdict_of_a_check():
    """a check passed: its stage is yours, in so many words; a band of the speed stage, that band"""
    A, _, _, course, term = no_terminal()
    said = {}
    for lid, want in (('sent.check', 'first sentences: yours.'), ('speed.30.check', '30 wpm: yours.')):
        fresh(baseline=999, lessons={'home.fj.meet': {'seals': 0, 'best': 0, 'tries': 1}})
        a = A.App(NoTerminal(), {'seed': 3})
        a.size = (80, 39, 8, 20)
        ls = A.LessonScreen(a, course.BY_ID[lid])
        a.screen = ls
        ls.layout()
        now = time.monotonic()
        for i, c in enumerate(ls.run.text[:60]):
            ls.key(term.Key('press', 'space' if c == ' ' else c.lower(), c, 0, now + i * 0.3))     # (40 wpm: past no landmark)
            ls.key(term.Key('release', 'space' if c == ' ' else c.lower(), '', 0, now + i * 0.3 + 0.03))
        ls.finish(now + 18)
        said[lid] = a.screen.verdict(), want
    report('a check passed says its stage is yours', all(a == b for a, b in said.values()), str(said))


def case_geometry():
    """every size and cell, with no terminal at all: each screen's column and pictures inside the window, nothing written past
    its edges (a terminal would pile it up on the last row or column), the words over the keyboard, never under it"""
    A, art, canvas, course, term = no_terminal()
    fresh(lessons={'home.fj.meet': {'seals': 0, 'best': 0, 'tries': 1}})
    cup = re.compile(r'\x1b\[(\d+);(\d+)H')
    sends = []
    real_send = canvas.Picture.send

    def send(pic, col, row, palette):
        sends.append((pic, col, row))
        return real_send(pic, col, row, palette)

    canvas.Picture.send = send
    t = NoTerminal()
    a = A.App(t, {'seed': 3})
    bad = set()
    checked = 0

    def look(name, cols, rows, cw, ch):
        for m in cup.finditer(''.join(t.out)):
            r, c = int(m[1]), int(m[2])
            if not (1 <= r <= rows and 1 <= c <= cols):
                bad.add(f'{name} {cols}x{rows} cell {cw}x{ch}: written at row {r} col {c}')
        for pic, col, row in sends:
            if pic.w and (col < 1 or row < 1 or col - 1 + math.ceil(pic.w / cw) > cols or row - 1 + math.ceil(pic.h / ch) > rows):
                bad.add(f'{name} {cols}x{rows} cell {cw}x{ch}: a picture {pic.w}x{pic.h} at {col},{row} passes the edge')
        t.out.clear()
        sends.clear()

    many = (1, 2, 3, 5, 8, 12, 20, 30, 38, 39, 40, 41, 42, 44, 60, 79, 80, 84, 100, 130, 160, 200, 236, 300)
    tall = (1, 2, 3, 4, 5, 8, 9, 10, 14, 20, 21, 24, 31, 33, 38, 48, 52, 60, 90)
    for cw, ch in ((8, 20), (9, 22), (10, 25), (16, 40), (7, 15), (1, 1)):
        for cols in many if (cw, ch) == (8, 20) else many[::2]:
            for rows in tall if (cw, ch) == (8, 20) else tall[::2]:
                a.size = (cols, rows, cw, ch)
                checked += 1
                pl = A.Stage(a)
                if pl.scale:
                    n = (art.KEY_W * pl.scale, (art.KEY_H + (art.HANDS_H if pl.with_hands else 0)) * pl.scale)
                    if pl.pic_x < 0 or pl.pic_y < 0 or pl.pic_x * cw + n[0] > cols * cw or pl.pic_y * ch + n[1] > (rows - 1) * ch:
                        bad.add(f'stage {cols}x{rows} cell {cw}x{ch}: the picture outside the window')
                    if pl.words_y >= pl.pic_y:
                        bad.add(f'stage {cols}x{rows} cell {cw}x{ch}: the words on the keyboard')
                if pl.x < 0 or pl.x + pl.W > cols:
                    bad.add(f'stage {cols}x{rows} cell {cw}x{ch}: the column {pl.x}+{pl.W} outside the window')
                for tab in A.TABS:
                    a.screen = A.Home(a, tab)
                    a.screen.layout()
                    a.screen.draw()
                    look('home ' + tab, cols, rows, cw, ch)
                ls = A.LessonScreen(a, course.BY_ID['speed.30.passage.1'])
                a.screen = ls
                ls.layout()
                ls.draw()
                look('lesson', cols, rows, cw, ch)
                if ls.scale and ls.text_y + math.ceil(ls.lines_n * ls.letters.h / ch) > ls.notice_y:
                    bad.add(f'lesson {cols}x{rows} cell {cw}x{ch}: the text runs into the row under it')
                now = time.monotonic()
                for i, c in enumerate(ls.run.text[:40]):
                    ls.key(term.Key('press', 'space' if c == ' ' else c.lower(), c, 0, now + i * 0.1))
                ls.tick(now + 4)
                t.out.clear()
                sends.clear()
                ls.finish(now + 4.1)
                a.screen.draw()
                look('result', cols, rows, cw, ch)
    canvas.Picture.send = real_send
    # its own window: an even width and an odd height (every popup's, centred to the pixel: test_term_float), the keyboard in it
    # at ×2 with equal margins, and whole cells at every multiple
    with open(os.path.join(HERE, '..', '..', 'configs/home/.local/share/applications/kawa-typing.desktop')) as f:
        m = re.search(r'--dialog typing (\d+)x(\d+)', f.read())
    cols, rows = int(m[1]), int(m[2])
    a.size = (cols, rows, 8, 20)
    pl = A.Stage(a)
    if cols % 2 or not rows % 2:
        bad.add(f'the window {cols}x{rows}: not even by odd')
    if (pl.scale, pl.with_hands) != (2, True) or pl.pic_x * 2 + pl.pic_w != cols or pl.pic_w * 8 != art.KEY_W * 2:
        bad.add(f'the window {cols}x{rows}: the keyboard at ×{pl.scale}, from column {pl.pic_x}, {pl.pic_w} wide')
    if any(art.KEY_W * k % 8 for k in (1, 2, 3)):
        bad.add('the keyboard not whole cells at every multiple')
    if A.CALENDAR_WEEKS * A.CALENDAR_PITCH - 2 != art.KEY_W:
        bad.add('the days calendar not from edge to edge of the keyboard')
    seen, short = set(), []       # (one line for each screen in each window, the first thing wrong there)
    for b_ in sorted(bad):
        k = b_.split(':')[0]
        if k not in seen:
            seen.add(k)
            short.append(b_)
    report(f'{checked} sizes and cells, every screen inside its window', not bad, f'{len(short)} windows: ' + '; '.join(short[:60]))


CASES = {k[5:]: v for k, v in list(globals().items()) if k.startswith('case_')}


def main():
    names = sys.argv[1:] or list(CASES)
    for n in names:
        CASES[n]()
    print(f'{len(FAILS)} failed')
    return 1 if FAILS else 0


if __name__ == '__main__':
    sys.exit(main())
