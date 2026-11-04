"""course.py — every lesson of docs/learn/typing/curriculum.md, built from one table, and the words each one
types, drawn fresh at each attempt (no lesson can be learned by heart). Real words wherever the letters allow
them; pseudo-words only while fewer than 15 real ones exist (keybr's rule).
"""
import os
import random
import re
from collections import namedtuple

HERE = os.path.dirname(os.path.abspath(__file__))
Lesson = namedtuple('Lesson', 'id stage kind title keys known low goal flow size limit extra')
#   id     stable: what progress is kept under
#   kind   meet drill mix words anchor travel review check sentences patterns lines passage pacer code
#   keys   what it brings in; known: the characters it may use
#   low, goal   the speeds of its seals (0: no score); flow: wrong letters stand; size: its length in characters
#   limit  seconds, for a check; extra: what its kind needs

LETTERS = (
    ('home row', 'home', ('fj', 'dk', 'sl', 'a;', 'gh'), 5, 12),
    ('top row', 'top', ('ru', 'ei', 'wo', 'qp', 'ty'), 6, 15),
    ('bottom row', 'bottom', ('vm', 'c,', 'z/', 'bn', 'x.'), 8, 18),
)
TRAVELS = ('frfvf juj mj', 'ded cd kik ,k', 'sws xs lol .l', 'aqa za ;p; /;', 'ftf gbg gtg', 'jyj hnh jnj')
CAPITALS = ('FDSA', 'JKL:', 'GHTY', 'RUEI', 'WOQP', 'VMC?', 'ZNXB', "'\"-")
NUMBERS = ('47', '38', '29', '10', '56')
SYMBOLS = ('$&', '#*', '@(', ')!', '%^')
SIGNS = ('[]', '\\|', '_+', '=<', '>~', '`{', '}')
# a sign among words, as it is used: W a word, N a number
HABITS = {'$': '$N', '&': 'W & W', '#': '#N', '*': 'N * N', '@': 'W@W.org', '(': '(W W)', ')': '(W W)', '!': 'W!', '%': 'N%',
          '^': 'N^N', '[': 'W[N]', ']': 'W[N]', '\\': 'W\\W', '|': 'W | W', '_': 'W_W', '+': 'N + N', '=': 'W = N', '<': 'N < N',
          '>': 'N > N', '~': '~/W', '`': '`W`', '{': '{W}', '}': '{W}', ':': 'W: W', '?': 'W?', "'": "W's", '"': '"W"', '-': 'W-W'}
BANDS = range(30, 111, 5)
CODE_AFTER = {40: 'bash', 50: 'git', 60: 'python', 70: 'rust', 80: 'c'}
STAGE_NAMES = ('home row', 'top row', 'bottom row', 'first sentences', 'capitals', 'numbers', 'symbols', 'more symbols', 'speed')


def said(g):
    return ' '.join(g[:-1]) + ' and ' + g[-1] if len(g) > 1 else g


def build():
    out = []

    def add(id_, stage, kind, title, keys='', known='', low=0, goal=0, flow=False, size=60, limit=None, extra=None):
        out.append(Lesson(id_, stage, kind, title, keys, known, low, goal, flow, size, limit, extra))
    known = ''
    for s, (name, tag, groups, low, goal) in enumerate(LETTERS):
        before = known
        for g in groups:
            known += g
            k = f'{tag}.{g}'
            add(k + '.meet', s, 'meet', f'meet {said(g)}', g, known, size=30)
            add(k + '.drill', s, 'drill', f'drill {said(g)}', g, known, low, goal, size=60)
            # (no vowel yet, no words: the same drill, longer)
            add(k + '.mix', s, 'mix', f'{said(g)} among the rest' if known != g else f'drill {said(g)}, longer', g, known, low, goal, size=80)
            add(k + '.words', s, 'words', f'words with {said(g)}' if set(known) & set('aeiou') else f'drill {said(g)}, longest', g, known, low, goal, size=100)
        stage_keys = known[len(before):]
        if s < 2:
            left = ''.join(c for c in known if c in 'qwertasdfgzxcvb')
            right = ''.join(c for c in known if c in 'yuiophjkl;nm,./')
            add(f'{tag}.anchor.j', s, 'anchor', 'hold j, the left hand types', stage_keys, left, low, goal, size=70, extra='j')
            add(f'{tag}.anchor.f', s, 'anchor', 'hold f, the right hand types', stage_keys, right, low, goal, size=70, extra='f')
        else:
            for i in range(3):
                add(f'{tag}.travel.{i}', s, 'travel', f'up and down the columns, {i + 1} of 3', stage_keys, known, low, goal, size=70, extra=TRAVELS[2 * i:2 * i + 2])
        add(f'{tag}.review.1', s, 'review', 'review, your weakest keys', stage_keys, known, low, goal, size=120)
        add(f'{tag}.review.2', s, 'review', 'review, your weakest keys again', stage_keys, known, low, goal, size=120)
        add(f'{tag}.check', s, 'check', f'{name}, the check', stage_keys, known, low, goal, flow=True, limit=60)
    letters = known + ' '
    # 4: first sentences
    for i in range(12):
        low, goal = 10 + i // 3 * 2, 20 + i // 3 * 2
        add(f'sent.{i + 1}', 3, 'sentences', f'sentences, {i + 1} of 12', '', letters, low, goal, flow=True, size=120 + 10 * i, extra='plain')
    for i in range(6):
        add(f'sent.pat.{i + 1}', 3, 'patterns', f'common patterns, {i + 1} of 6', '', letters, 12, 22, flow=True, size=120, extra=i)
    add('sent.review', 3, 'review', 'review, your weakest keys', '', letters, 12, 22, flow=True, size=160)
    add('sent.check', 3, 'check', 'first sentences, the check', '', letters, 15, 25, flow=True, limit=60)
    # 5: capitals, the marks that take a shift, and the numbers and signs: meet · drill · words each
    seen = letters

    def groups_of(tag, stage, groups, low, goal):
        nonlocal seen
        for g in groups:
            seen += g
            k = f'{tag}.{g}'
            add(k + '.meet', stage, 'meet', f'meet {said(g)}', g, seen, size=30)
            add(k + '.drill', stage, 'drill', f'drill {said(g)}', g, seen, low, goal, size=60)
            add(k + '.words', stage, 'habits', f'words with {said(g)}', g, seen, low, goal, flow=True, size=90)
    groups_of('caps', 4, CAPITALS, 8, 20)
    for i in range(5):
        add(f'caps.sent.{i + 1}', 4, 'sentences', f'sentences with capitals, {i + 1} of 5', '', seen, 12, 20, flow=True, size=140 + 15 * i, extra='capitals')
    add('caps.check', 4, 'check', 'capitals, the check', '', seen, 12, 20, flow=True, limit=60, extra='capitals')
    groups_of('num', 5, NUMBERS, 5, 20)
    for i in range(5):
        add(f'num.sent.{i + 1}', 5, 'sentences', f'sentences with numbers, {i + 1} of 5', '', seen, 10, 20, flow=True, size=120 + 10 * i, extra='numbers')
    add('num.check', 5, 'check', 'numbers, the check', '', seen, 10, 20, flow=True, limit=60, extra='numbers')
    groups_of('sym', 6, SYMBOLS, 5, 18)
    for i in range(2):
        add(f'sym.sent.{i + 1}', 6, 'sentences', f'lines with symbols, {i + 1} of 2', '', seen, 8, 18, flow=True, size=130, extra='symbols')
    add('sym.check', 6, 'check', 'symbols, the check', '', seen, 8, 18, flow=True, limit=60, extra='symbols')
    groups_of('sign', 7, SIGNS, 5, 18)
    for i in range(2):
        add(f'sign.sent.{i + 1}', 7, 'sentences', f'lines with signs, {i + 1} of 2', '', seen, 8, 18, flow=True, size=130, extra='signs')
    add('sign.check', 7, 'check', 'more symbols, the check', '', seen, 8, 18, flow=True, limit=60, extra='signs')
    # 9: speed, 5 wpm at a time, and code after every 10 from 40 to 80
    for band in BANDS:
        low, n = band - 10, len(BANDS)
        i = (band - BANDS[0]) // 5
        size = 200 + i * 16
        for j in range(3):
            add(f'speed.{band}.passage.{j + 1}', 8, 'passage', f'{band} wpm, passage {j + 1} of 3', '', seen, low, band, flow=True, size=size, extra=(i, n, j))
        add(f'speed.{band}.patterns', 8, 'patterns', f'{band} wpm, patterns', '', seen, low, band, flow=True, size=150, extra=(i * 6 + 6) % 60)
        add(f'speed.{band}.pacer', 8, 'pacer', f'{band} wpm, beat the pacer', '', seen, low, band, flow=True, size=size, extra=(i, n, 3))
        add(f'speed.{band}.check', 8, 'check', f'{band} wpm, the check', '', seen, low, band, flow=True, limit=60)
        if band in CODE_AFTER:
            lang = CODE_AFTER[band]
            for j in range(6):
                goal = round(band * 0.8)
                add(f'code.{lang}.{j + 1}', 8, 'code', f'{lang}, {j + 1} of 6', '', seen, goal - 10, goal, flow=True, size=180, extra=lang)
    return out


LESSONS = build()
BY_ID = {les.id: i for i, les in enumerate(LESSONS)}


def stage_counts():
    counts = [0] * len(STAGE_NAMES)
    for les in LESSONS:
        counts[les.stage] += 1
    return counts


# ── the words ────────────────────────────────────────────────────────────────
_words = None
_patterns = None
_passages = None
_sentences = None
_code = None


def words():
    global _words
    if _words is None:
        with open(os.path.join(HERE, 'words.txt')) as f:
            _words = f.read().split()
    return _words


def patterns():
    global _patterns
    if _patterns is None:
        with open(os.path.join(HERE, 'patterns.txt')) as f:
            _patterns = [(p.split('\t')[0], p.rstrip('\n').split('\t')[1].split()) for p in f]
    return _patterns


def passages():
    global _passages
    if _passages is None:
        with open(os.path.join(HERE, 'passages.txt')) as f:
            _passages = [line.rstrip('\n').split('\t', 1)[1] for line in f]
    return _passages


def sentences():
    global _sentences
    if _sentences is None:
        _sentences = {}
        with open(os.path.join(HERE, 'sentences.txt')) as f:
            for line in f:
                if not line.startswith('#') and '\t' in line:
                    k, t = line.rstrip('\n').split('\t', 1)
                    _sentences.setdefault(k, []).append(t)
    return _sentences


def code_blocks():
    global _code
    if _code is None:
        _code = {}
        with open(os.path.join(HERE, 'code.txt')) as f:
            lang = None
            for block in re.split(r'\n\s*\n', f.read()):
                lines = [ln for ln in block.split('\n') if not ln.startswith('#') or lang in ('c', 'bash', 'python', 'rust', 'git')]
                if lines and lines[0].startswith('[') and lines[0].endswith(']') and len(lines[0]) < 10:
                    lang = lines[0][1:-1]
                    lines = lines[1:]
                if lang and lines:
                    _code.setdefault(lang, []).append('\n'.join(lines))
    return _code


def pick_words(allowed, rng, must='', count=40, weight=None):
    """count real words of the allowed letters, the common ones likelier; at least half hold a letter of must;
    pseudo-words join in while there are fewer than 15 real ones"""
    allowed_set = set(allowed)
    pool = [w for w in words()[:1500] if set(w) <= allowed_set and len(w) > 1] or [w for w in words() if set(w) <= allowed_set]
    holds = [w for w in pool if not must or set(w) & set(must)]
    if len(holds) < 15:
        holds = holds + pseudo_words(allowed, must, rng, 15 - len(holds))
    if len(pool) < 15:
        pool = holds
    out = []
    for i in range(count):
        src = holds if i % 2 == 0 or not pool else pool
        n = len(src)
        # (rank-weighted: the top of the list is drawn most)
        w = src[min(int(n * rng.random() ** 1.5), n - 1)]
        if weight:
            # (twice more, and the word that holds most of the weakest keys wins)
            for _ in range(2):
                other = src[min(int(n * rng.random() ** 1.5), n - 1)]
                if sum(weight.get(c, 1) for c in other) / len(other) > sum(weight.get(c, 1) for c in w) / len(w):
                    w = other
        out.append(w)
    return out


def pseudo_words(allowed, must, rng, count):
    vowels = [c for c in allowed if c in 'aeiou']
    cons = [c for c in allowed if c.isalpha() and c not in 'aeiou'] or vowels
    out = []
    for _ in range(max(count, 0)):
        if vowels:
            w = ''
            for i in range(rng.randint(2, 4)):
                w += rng.choice(cons if i % 2 == 0 else vowels)
            if must:
                letters = [c for c in must if c.isalpha()]
                if letters and not set(w) & set(letters):
                    w = rng.choice(letters) + w[1:]
        else:
            w = ''.join(rng.choice(cons) for _ in range(rng.randint(2, 4)))
        out.append(w)
    return out


def chunks(letters, rng, size, new='', spaces=True):
    """a drill: little groups of the keys, the new ones most"""
    letters = [c for c in letters if c != ' ']
    out, n = [], 0
    while n < size:
        k = rng.randint(2, 5)
        g = ''.join(rng.choice(new) if new and rng.random() < 0.7 else rng.choice(letters) for _ in range(k))
        out.append(g)
        n += k + 1
    return ' '.join(out)


def fill(items, size, rng, sep=' '):
    """items joined until the text reaches size, its end whole"""
    out, n = [], 0
    while n < size and items:
        x = items[rng.randrange(len(items))]
        out.append(x)
        n += len(x) + len(sep)
    return sep.join(out)


def meet(keys, rng):
    a = list(keys)
    out = []
    for c in a:
        out.append(c * 3)
    out.append(''.join(a))
    out.append(''.join(reversed(a)))
    for c in a:
        out.append(c * 2)
    mixed = ''.join(a)
    out.append(''.join(rng.choice(mixed) for _ in range(4)))
    out.append(''.join(rng.choice(mixed) for _ in range(3)))
    return ' '.join(out)


def habit(sign, rng, pool):
    t = HABITS.get(sign, sign)
    out = ''
    for c in t:
        if c == 'W':
            out += pool[rng.randrange(min(len(pool), 300))]
        elif c == 'N':
            out += str(rng.randint(2, 99))
        else:
            out += c
    return out


def weakness(keys_stats, band_ms=None):
    """each key's weight for the adaptive lessons: slower and less sure than the others, more of it"""
    stats = {k: v for k, v in keys_stats.items() if v[0] >= 5 and v[2] > 0}
    if not stats:
        return {}
    mean = sum(v[2] for v in stats.values()) / len(stats)
    return {k: (v[2] / mean) ** 2 * (1 + 12 * v[1] / max(v[0], 1)) for k, v in stats.items()}


def text_for(lesson, rng, stats=None):
    """the characters this attempt types"""
    k, size, known = lesson.kind, lesson.size, lesson.known
    letters = ''.join(c for c in known if c.isalpha() and c.islower())
    weak = weakness(stats or {})
    if k == 'meet':
        if lesson.stage >= 4 and lesson.keys[0].isupper():
            # (a capital with its own small letter: the shift is the new thing)
            out = []
            for c in lesson.keys:
                out += [c + c.lower() + c, c * 2] if c.isalpha() else [c * 3]
            return ' '.join(out)
        return meet(lesson.keys, rng)
    if k == 'drill':
        if lesson.keys.isdigit():     # (numbers among numbers)
            return chunks(''.join(c for c in known if c.isdigit()), rng, size, lesson.keys)
        return chunks(lesson.keys + letters[-6:], rng, size, lesson.keys)
    if k == 'mix':
        if len({*letters} & set('aeiou')) >= 1 and len([w for w in words() if set(w) <= set(letters)]) >= 15:
            return ' '.join(pick_words(letters, rng, lesson.keys.replace(',', '').replace('.', '').replace(';', '').replace('/', ''), max(size // 6, 8)))[:size + 8].rsplit(' ', 1)[0]
        return chunks(known.replace(' ', ''), rng, size, lesson.keys)
    if k == 'words':
        must = ''.join(c for c in lesson.keys if c.isalpha())
        pool = [w for w in words() if set(w) <= set(letters)]
        if len(pool) < 15 and not set(letters) & set('aeiou'):
            return chunks(known.replace(' ', ''), rng, size, lesson.keys)
        marks = [c for c in lesson.keys if not c.isalpha()]
        ws = pick_words(letters, rng, must, max(size // 5, 10), weak)
        if marks:
            ws = [w + (rng.choice(marks) if rng.random() < 0.35 else '') for w in ws]
        return ' '.join(ws)[:size + 8].rsplit(' ', 1)[0]
    if k == 'anchor':
        return chunks(known or letters, rng, size, ''.join(c for c in lesson.keys if c in known))
    if k == 'travel':
        out = []
        while sum(map(len, out)) + len(out) < size:
            out.extend(' '.join(lesson.extra).split())
        return ' '.join(out)
    if k in ('review', 'check') and lesson.extra is None:
        ws = pick_words(letters, rng, '', (lesson.limit or 0) * 5 + max(size // 4, 12), weak if k == 'review' else None)
        return ' '.join(ws)
    if k == 'check':          # (capitals, numbers, symbols: its lines, as many as a minute could take)
        return fill(sentences()[lesson.extra], 1200, rng)
    if k == 'sentences':
        return fill(sentences()[lesson.extra], size, rng)
    if k == 'patterns':
        return pattern_text(lesson, rng, size)
    if k == 'habits':
        pool = [w for w in words() if set(w) <= set(letters)]
        out, n = [], 0
        signs = list(lesson.keys)
        while n < size:
            c = rng.choice(signs)
            if c.isalpha():
                starts = [w for w in pool[:1500] if w[0] == c.lower()] or [c.lower()]
                t = c + starts[rng.randrange(len(starts))][1:]
            elif c.isdigit():
                t = ''.join(rng.choice(lesson.keys) for _ in range(rng.randint(2, 4)))
            else:
                t = habit(c, rng, pool)
            out.append(t)
            n += len(t) + 1
        return ' '.join(out)
    if k in ('passage', 'pacer'):
        return passage(lesson, rng)
    if k == 'code':
        blocks = code_blocks()[lesson.extra]
        out, n = [], 0
        start = rng.randrange(len(blocks))
        while n < size:
            b = blocks[(start + len(out)) % len(blocks)]
            out.append(b)
            n += len(b) + 1
        return '\n'.join(out)
    return ' '.join(pick_words(letters or 'asdfjkl', rng, '', 20))


def pattern_text(lesson, rng, size):
    all_patterns = patterns()
    base = lesson.extra if isinstance(lesson.extra, int) else 0
    out, n, i = [], 0, 0
    while n < size:
        gram, hold = all_patterns[(base + i) % len(all_patterns)]
        part = [gram, gram] + rng.sample(hold, min(3, len(hold)))
        out += part
        n += sum(map(len, part)) + len(part)
        i += 1
    return ' '.join(out)


def passage(lesson, rng):
    """from the books, hard as the band: the pool's easy end first, its hard end by the last band"""
    i, n, j = lesson.extra
    ps = passages()
    lo = int(len(ps) * (i / n) * 0.8)
    hi = max(lo + 30, int(len(ps) * ((i + 1) / n) * 0.8) + 40)
    pool = [p for p in ps[lo:hi] if len(p) >= lesson.size * 0.7] or ps[lo:hi]
    return pool[rng.randrange(len(pool))]


def plain_words(rng, count=400, weak=None):
    return ' '.join(pick_words('abcdefghijklmnopqrstuvwxyz', rng, '', count, weak))


def fresh(seed=None):
    return random.Random(seed)
