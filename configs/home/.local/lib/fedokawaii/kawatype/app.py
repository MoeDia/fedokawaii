"""app.py — kawa-typing's screens: the three tabs (course, practice, progress), a lesson, its result. Text is
foot's own cells in the palette's numbers, so it follows a theme switch by itself; the keyboard and the hands
are pictures (canvas.py) repainted as the theme changes. docs/design-system.md §7 is the grammar of all of it.
"""
import json
import math
import os
import re
import signal
import sys
import time
import traceback

from . import art, canvas, course, keys, metrics, store, term
from .term import Flags, Focus, Key, Mood, Mouse, Pasted, Resize

# the palette's numbers (screen.sh): foot holds them for both moods
ACCENT, ON_ACCENT, EDGE, EDGE2, ACCENT_TEXT, MUTED, FAINT, STRONG, SELECT, ON_SELECT = 16, 17, 18, 19, 20, 21, 22, 23, 24, 25
OFF = '\x1b[0m'
DAY_MINUTES = 20
TEXT_LINES = 5          # (the text in view at most: the line just typed, the one under way, three to come)
FEED_RATE, FEED_SECONDS = 42.0, 0.16   # (the paper feeding a line: a spring with no overshoot)
ANSWER_STEP = 0.07      # (the hands' answer to a result: a pose each)
CALENDAR_WEEKS = 43     # (at the keyboard's width on 8 px cells: its 600 px whole, a seal 12 px, 2 of air)
SEAL_ON, SEAL_OFF = '●', '○'
TABS = ('course', 'practice', 'progress')
TAB_ICONS = {'course': 'MORTARBOARD', 'practice': 'BRUSH', 'progress': 'USAGE'}
STAGE_ICONS = ('KEYBOARD', 'KEYBOARD', 'KEYBOARD', 'NOTE', 'PEN', 'CALC', 'EQUALS', 'CODE', 'LANTERN')
MILESTONES = (50, 75, 90, 100, 120)
MODIFIERS = ('lshift', 'rshift', 'lctrl', 'rctrl', 'lalt', 'ralt', 'lsuper', 'rsuper')
MILESTONE_WORDS = {50: 'past 50: the average typist, of 168,000 measured.', 75: 'past 75: a trained typist of the old studies.',
                   90: 'past 90: the fast group\'s average.', 100: 'past 100. that was the goal.', 120: 'past 120: the fastest of that study.'}


def fg(n):
    return f'\x1b[38;5;{n}m'


def bg(n):
    return f'\x1b[48;5;{n}m'


def load_icons():
    path = os.path.join(os.environ.get('XDG_CONFIG_HOME') or os.path.expanduser('~/.config'), 'fedokawaii', 'icons.sh')
    out = {}
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            for m in re.finditer(r"^ICON_([A-Z_0-9]+)=\$'((?:\\x[0-9a-f]{2})+)'", f.read(), re.M):
                out[m[1]] = bytes.fromhex(m[2].replace('\\x', '')).decode()
    except OSError:
        pass
    return out


def percent(acc):
    """a tenth of a percent, down: 96.97 is under 97, and must read so"""
    return f'{math.floor(acc * 10) / 10:.1f}'


def clock(seconds):
    return f'{int(seconds) // 60}:{int(seconds) % 60:02d}'


def seals_text(n):
    gold = n >= 6
    n = min(n, 5)
    return (fg(ACCENT_TEXT if not gold else STRONG) + SEAL_ON * n + fg(EDGE2) + SEAL_OFF * (5 - n) + OFF)


def seals_for(wpm, acc, low, goal):
    """the table of docs/learn/typing/curriculum.md: 0 not passed, 1–5, 6 the gold seal"""
    if acc < 97 or wpm < low:
        return 0
    if wpm >= goal * 1.5 and acc >= 100:
        return 6
    if wpm >= goal:
        return 5 if acc >= 99 else 4
    span = goal - low
    return 3 if wpm >= low + span * 2 / 3 else 2 if wpm >= low + span / 3 else 1


def plain(s):
    return re.sub(r'\x1b\[[0-9;:<=>?]*[A-Za-z]', '', s)


def width(s):
    """cells of a line (an icon is drawn across two, but takes one: it overflows into the space after it)"""
    return len(plain(s))


def meter(app, done, total):
    """a quantity in a row (§7): ten segments, done solid, to do hollow; complete: muted; nothing yet: nothing"""
    if not done:
        return ''
    on, off = app.icon('READ'), app.icon('READ_OFF')
    n = max(1, done * 10 // total) if done < total else 10
    return fg(MUTED if done >= total else ACCENT_TEXT) + on * n + fg(EDGE2) + off * (10 - n) + OFF


def fit_power(tests):
    """the power law of practice through (day, wpm): the day it reaches 100, or None. Two weeks of data at least"""
    pts = sorted((r['d'], r['w']) for r in tests if r['w'] > 0)
    if len(pts) < 8 or pts[-1][0] - pts[0][0] < 14 * 86400:
        return None
    t0 = pts[0][0]
    xs = [math.log((t - t0) / 86400 + 1) for t, _ in pts]
    ys = [math.log(w) for _, w in pts]
    n = len(xs)
    mx, my = sum(xs) / n, sum(ys) / n
    den = sum((x - mx) ** 2 for x in xs)
    if not den:
        return None
    b = sum((x - mx) * (y - my) for x, y in zip(xs, ys, strict=True)) / den
    if b <= 0.01:
        return None
    a = my - b * mx
    try:
        days = math.exp((math.log(100) - a) / b) - 1
    except OverflowError:
        return None
    return None if days > 3650 else t0 + days * 86400


def plan(app):
    """what comes next: a run left under way; the first minute; the day's warm-up; a lesson; the day's test"""
    st = app.store
    d = st.load_resume()
    if d.get('run') and d['run'].get('pos') if isinstance(d.get('run'), dict) else False:
        return 'resume', str(d.get('title') or 'go on'), d
    if st.progress['baseline'] is None:
        return 'baseline', 'one minute, the way you type now', None
    day = st.day()
    if not day['warm'] and sum(v[0] for v in st.keys['keys'].values()) >= 300:
        return 'warmup', 'warm up, your weakest keys', None
    if st.minutes_today() >= DAY_MINUTES and not day['test']:
        return 'test', 'the day\'s test, one minute', None
    have = st.progress['lessons']
    for i, les in enumerate(course.LESSONS):
        got = have.get(les.id)
        if not got or (les.goal and got['seals'] < 1):
            return 'lesson', les.title, i
    return 'practice', 'your weakest keys', None


def start(app, what):
    """the screen plan() named"""
    kind, _, arg = what
    if kind == 'resume':
        return resumed(app, arg) or Home(app)
    if kind == 'lesson':
        return open_lesson(app, arg)
    if kind == 'baseline':
        return LessonScreen.free(app, 'baseline')
    if kind == 'warmup':
        return LessonScreen.free(app, 'warmup')
    if kind == 'test':
        return LessonScreen.free(app, 'test', 60, day_test=True)
    return LessonScreen.free(app, 'weak')


def resumed(app, d):
    """the lesson a kill, a reboot or Esc left; None if what was kept cannot be used. (Only a course's lesson is kept: a
    practice run or a test is a thing of the moment, and a kept one would be measured over a lie)"""
    try:
        run = metrics.Run.restored(d['run'])
        i = d['index']
        if type(i) is int and 0 <= i < len(course.LESSONS) and course.LESSONS[i].id == d.get('lesson'):
            return LessonScreen(app, i, resume=run)
    except (KeyError, TypeError, ValueError, AttributeError, IndexError, OverflowError):
        pass
    app.store.clear_resume()
    return None


def open_lesson(app, i):
    """a lesson: where it was left, if it was; else from its start"""
    d = app.store.load_resume()
    if d.get('index') == i and d.get('lesson') == course.LESSONS[i].id:
        screen = resumed(app, d)
        if screen:
            return screen
    return LessonScreen(app, i)


def at_word(s, w):
    """s in w cells: cut at a word, never an ellipsis (docs/design-system.md §2); a single word too long loses its end"""
    if len(s) <= w:
        return s
    return s[:w + 1].rsplit(' ', 1)[0][:w] if w > 0 else ''


def key_heat(stats):
    """each key's ink on the progress page's keyboard, by how sure of it you are"""
    out = {}
    for c, w in course.weakness(stats).items():
        if c in keys.CHARS:
            out[keys.CHARS[c][0]] = 'accent' if w > 1.5 else 'flame' if w > 1.15 else 'asagi'
    return out


def streak(history):
    """days practised in a row, up to today (or yesterday: today is not over)"""
    days = {time.strftime('%Y-%m-%d', time.localtime(r['d'])) for r in history}
    t = time.time()
    if time.strftime('%Y-%m-%d', time.localtime(t)) not in days:
        t -= 86400
    n = 0
    while time.strftime('%Y-%m-%d', time.localtime(t)) in days:
        n += 1
        t -= 86400
    return n


def wrap(text, w):
    """the text's lines at w columns, at words: [(start, end)], '\\n' ending its line; a word too long is cut"""
    lines = []
    i, n = 0, len(text)
    w = max(w, 4)
    while i < n:
        end = min(i + w, n)
        nl = text.find('\n', i, end + 1)
        if nl >= 0:
            lines.append((i, nl + 1))
            i = nl + 1
            continue
        if end >= n:
            lines.append((i, n))
            break
        sp = text.rfind(' ', i, end + 1)
        if sp > i:
            lines.append((i, sp + 1))
            i = sp + 1
        else:
            lines.append((i, end))
            i = end
    return lines or [(0, 0)]


class App:
    def __init__(self, tty, args):
        self.t = tty
        self.args = args
        self.store = store.Store()
        self.icons = load_icons()
        self.dark = self._read_mood()
        self.releases = False            # (the terminal tells releases: rollover, anchors)
        self.focused = True
        self.screen = None
        self.size = (80, 24, 8, 20)
        self.seed = args.get('seed')
        self.attempt = 0
        self.alive = True

    def icon(self, name):
        return self.icons.get(name, '·')

    @staticmethod
    def _read_mood():
        path = os.path.join(os.environ.get('XDG_CONFIG_HOME') or os.path.expanduser('~/.config'), 'fedokawaii', 'current', 'colors.sh')
        try:
            with open(path) as f:
                return 'THEME=light' not in f.read(200)
        except OSError:
            return True

    def rng(self):
        self.attempt += 1
        return course.fresh(None if self.seed is None else self.seed + self.attempt)

    # ── the loop ─────────────────────────────────────────────────────────────
    def run(self, first):
        self.t.start()
        self.size = self.t.size()
        self.go(first)
        while self.alive:
            timeout = self.screen.wait()
            for ev in self.t.read(timeout):
                self.event(ev)
                if not self.alive:
                    break
            self.screen.tick(time.monotonic())
            self.t.flush()

    def go(self, screen):
        self.screen = screen
        self.t.write('\x1b[0m\x1b[2J')
        self.t.mouse_on(screen.wants_mouse)
        screen.layout()
        screen.draw()
        self.t.flush()

    def event(self, ev):
        if isinstance(ev, Resize):
            self.size = self.t.size()
            self.t.write('\x1b[0m\x1b[2J')
            self.screen.layout()
            self.screen.draw()
        elif isinstance(ev, Mood):
            if ev.dark != self.dark:
                self.dark = ev.dark
                self.screen.remood()
        elif isinstance(ev, Focus):
            self.focused = ev.on
            self.screen.focus(ev.on)
        elif isinstance(ev, Key):
            if ev.kind == 'release':
                self.releases = True
            self.screen.key(ev)
        elif isinstance(ev, Mouse):
            self.screen.mouse(ev)
        elif isinstance(ev, Pasted):
            self.screen.pasted()
        elif isinstance(ev, Flags):
            self.releases = bool(ev.value & 2)

    def quit(self):
        self.alive = False


class Screen:
    wants_mouse = False

    def __init__(self, app):
        self.app = app
        self.t = app.t

    def wait(self):
        return None

    def tick(self, now):
        pass

    def layout(self):
        pass

    def draw(self):
        pass

    def remood(self):
        self.t.write('\x1b[2J')
        self.layout()
        self.draw()

    def focus(self, on):
        pass

    def key(self, ev):
        pass

    def mouse(self, ev):
        pass

    def pasted(self):
        pass

    # the grammar's parts ------------------------------------------------------
    def at(self, row, col, s=''):
        """row and col from 0"""
        self.t.write(f'\x1b[{row + 1};{col + 1}H{s}')

    def heading(self, row, icon, name, x0, w, tail='', done=None):
        """a heading (§7): the icon, two columns, the name, the rule to the last column; done: how much of
        the rule is burnt, 0–1 (a lesson's progress); tail: words at the rule's right end"""
        if len(name) > w - 4:        # (never an ellipsis: cut at a word, or the name's end goes)
            name = name[:max(w - 3, 0)].rsplit(' ', 1)[0][:max(w - 4, 0)]
        s = fg(ACCENT_TEXT) + icon + OFF + '  ' + fg(STRONG) + name + OFF + ' '
        used = width(s)
        room = w - used
        tail_w = width(tail)
        if tail and room >= tail_w + 8:
            room -= tail_w + 1
        else:
            tail = ''
        room = max(room, 0)
        burnt = 0 if done is None else round(room * max(min(done, 1), 0))
        s += fg(ACCENT_TEXT) + '─' * burnt + fg(EDGE2) + '─' * (room - burnt) + OFF
        if tail:
            s += ' ' + tail + OFF
        self.at(row, x0, s)


# ── every screen's one place ─────────────────────────────────────────────────
class Stage:
    """Where things stand, on every screen: one column, as wide as the keyboard; the keyboard and the hands at its foot; over
    them a row of words; over that, what the screen is about. So a lesson opens with the keyboard where it was, and its
    result leaves it there. (A window too small for the hands, or for the keyboard: without them.)"""
    ABOVE = 18      # (the rows over the keyboard, with room: air, the tabs and their line, air, eleven rows of list, air, the words, air)
    WIDEST = 60     # (the column's width where the keyboard does not set it)

    def __init__(self, app, list_rows=0):
        """list_rows: what must stay over the keyboard, on a screen that lists: in a small window the list goes first"""
        self.app = app
        cols, rows, self.cw, self.ch = app.size
        room = max(cols - 4, 1)
        self.scale, self.with_hands, self.pic_rows = 0, False, 0
        for k, hands in ((3, True), (2, True), (1, True), (1, False)):
            n = math.ceil((art.KEY_H + (art.HANDS_H if hands else 0)) * k / self.ch)
            over = max(3 + math.ceil(60 * min(k, 2) / self.ch), list_rows)  # (air, the heading, air, three lines; then the words)
            if art.KEY_W * k <= room * self.cw and over + 1 + n + 1 <= rows:
                self.scale, self.with_hands, self.pic_rows = k, hands, n
                over_words = over
                break
        self.pic_w = math.ceil(art.KEY_W * self.scale / self.cw)
        self.W = max(self.pic_w, min(room, self.WIDEST))
        self.x = (cols - self.W) // 2
        self.pic_x = (cols - self.pic_w) // 2
        spare = rows - 1 - self.pic_rows - self.ABOVE
        self.pic_y = self.ABOVE + spare // 2 if spare > 0 else rows - 1 - self.pic_rows
        self.words_y = (self.pic_y - 2 if self.pic_y - 2 >= over_words else self.pic_y - 1) if self.scale else rows - 1
        self.key_rows = math.ceil(art.KEY_H * self.scale / self.ch)   # (the keyboard's alone: where the hands begin)

    def picture(self, hands=True):
        """the keyboard and the hands at rest, painted, not yet sent → (Picture, Keyboard, Hands or None)"""
        k, dark = self.scale, self.app.dark
        hands = hands and self.with_hands
        pic = canvas.Picture(art.KEY_W * k, (art.KEY_H + (art.HANDS_H if hands else 0)) * k, (self.cw, self.ch))
        kb = art.Keyboard(dark)
        kb.paint(pic, k)
        drawn = art.Hands(dark) if hands else None
        if drawn:
            drawn.paint(pic, k, 0, art.KEY_H * k)
        return pic, kb, drawn

    def send(self, pic):
        return pic.send(self.pic_x + 1, self.pic_y + 1, art.PALETTE[self.app.dark])


# ── the tabs ─────────────────────────────────────────────────────────────────
class Row:
    __slots__ = ('icon', 'name', 'value', 'act', 'tell')

    def __init__(self, icon, name, value='', act=None, tell=None):
        self.icon, self.name, self.value, self.act, self.tell = icon, name, value, act, tell


class Home(Screen):
    wants_mouse = True

    def __init__(self, app, tab='course', stage=None):
        super().__init__(app)
        self.tab = tab
        self.stage = stage         # a stage opened: its lessons
        self.cursor = 0
        self.top = 0
        self.rows = []
        self.pic = self.kb = self.hands = None
        self.tab_spans = []
        self.plan = plan(app)
        self.drum_at = time.monotonic() + 2.5     # (the hands drum their fingers, now and then: alive, even at rest)
        self.drum_i = -1

    def wait(self):
        if self.pic and self.hands and self.app.focused:
            return max(self.drum_at - time.monotonic(), 0.005)
        return None

    def tick(self, now):
        """a finger lifted at a time, little to index, on both hands, every few seconds"""
        if not (self.pic and self.hands) or now < self.drum_at or not self.app.focused:
            return
        self.drum_i += 1
        order = ((0, 9), (1, 8), (2, 7), (3, 6))
        if self.drum_i >= len(order):
            self.hands.pose = {}
            self.drum_i = -1
            self.drum_at = now + 3.5
        else:
            self.hands.pose = {f: (0, 2) for f in order[self.drum_i]}
            self.drum_at = now + 0.07
        self.hands.paint(self.pic, self.place.scale, 0, art.KEY_H * self.place.scale)
        self.t.write(self.place.send(self.pic))

    # ── what each tab lists ──────────────────────────────────────────────────
    def build(self):
        if self.tab == 'course':
            self.rows = self.stage_rows() if self.stage is not None else self.course_rows()
        elif self.tab == 'practice':
            self.rows = self.practice_rows()
        else:
            self.rows = []
        self.cursor = min(self.cursor, max(len(self.rows) - 1, 0))

    def lessons_done(self, stage=None):
        have = self.app.store.progress['lessons']
        return sum(1 for les in course.LESSONS if (stage is None or les.stage == stage) and les.id in have and (have[les.id]['seals'] >= 1 or not les.goal))

    def course_rows(self):
        a = self.app
        out = []
        kind, title, arg = self.plan
        total = len(course.LESSONS)
        value = f'{arg + 1} of {total}' if kind == 'lesson' else ''
        tell = ('lesson', course.LESSONS[arg]) if kind == 'lesson' else ('plan', kind)
        out.append(Row(a.icon('CHEVRON_RIGHT'), title, fg(MUTED) + value + OFF, lambda: a.go(start(a, self.plan)), tell))
        counts = course.stage_counts()
        for s, name in enumerate(course.STAGE_NAMES):
            done = self.lessons_done(s)
            out.append(Row(a.icon(STAGE_ICONS[s]), name, meter(a, done, counts[s]), lambda s=s: self.open_stage(s), ('stage', s)))
        return out

    def stage_rows(self):
        have = self.app.store.progress['lessons']
        out = []
        icons = {'check': 'HOURGLASS', 'passage': 'BOOK', 'pacer': 'LANTERN', 'code': 'CODE', 'sentences': 'NOTE', 'patterns': 'SPIRAL'}
        for i, les in enumerate(course.LESSONS):
            if les.stage == self.stage:
                d = have.get(les.id)
                if not les.goal:
                    v = fg(ACCENT_TEXT) + '✓' + OFF if d else ''
                else:
                    v = seals_text(d['seals']) if d else fg(EDGE2) + SEAL_OFF * 5 + OFF
                out.append(Row(self.app.icon(icons.get(les.kind, 'KEYBOARD')), les.title, v, lambda i=i: self.app.go(open_lesson(self.app, i)), ('lesson', les)))
        return out

    def practice_rows(self):
        a = self.app

        def go(*args):
            return lambda: a.go(LessonScreen.free(a, *args))
        out = [Row(a.icon('KEYBOARD'), 'your weakest keys', act=go('weak'), tell=('weak', 'the letters you are slowest and least sure on.')),
               Row(a.icon('NOTE'), 'plain words', act=go('words'), tell=('words', 'the 200 commonest words, drawn at random.')),
               Row(a.icon('BOOK'), 'a passage', act=go('passage'), tell=('words', 'Okakura, Hearn or Nitobe, as printed.'))]
        for lang in ('bash', 'git', 'python', 'rust', 'c'):
            out.append(Row(a.icon('CODE'), lang, act=go('code', lang), tell=('words', 'real code. a line\'s indent is the editor\'s work.')))
        for secs in (15, 30, 60):
            out.append(Row(a.icon('HOURGLASS'), f'test, {secs} seconds', act=go('test', secs), tell=('words', 'plain words. it starts with your first key.')))
        return out

    def open_stage(self, s):
        self.stage = s
        self.cursor = self.top = 0
        have = self.app.store.progress['lessons']
        for i, les in enumerate(x for x in course.LESSONS if x.stage == s):
            if les.id not in have:
                self.cursor = i
                break
        self.t.write('\x1b[2J')
        self.layout()
        self.draw()

    # ── its place on the screen ──────────────────────────────────────────────
    def layout(self):
        self.build()
        rows = self.app.size[1]
        self.first = 4                          # (a row of air, the tabs, their line, a row of air)
        pl = self.place = Stage(self.app, self.first + 7)
        self.x0, self.W = pl.x, pl.W
        self.visible = max((pl.words_y - 1 if pl.scale else rows - 1) - self.first, 1)
        self.list_w = self.W
        self.pic = self.kb = self.hands = None
        if self.tab == 'progress':
            self.progress_layout()
        elif pl.scale:
            self.pic, self.kb, self.hands = pl.picture()

    # ── drawing ──────────────────────────────────────────────────────────────
    def draw_tabs(self):
        self.tab_spans = []
        if self.stage is not None:             # (inside a stage: where you are, and how far along)
            done, n = self.lessons_done(self.stage), course.stage_counts()[self.stage]
            self.heading(1, self.app.icon(STAGE_ICONS[self.stage]), course.STAGE_NAMES[self.stage], self.x0, self.W, fg(MUTED) + f'{done} of {n}' + OFF, done / n)
            return
        x = self.x0
        s = ''
        under = None
        for name in TABS:
            icon = self.app.icon(TAB_ICONS[name])
            if name == self.tab:
                s += fg(ACCENT_TEXT) + icon + OFF + '  ' + fg(STRONG) + name + OFF + '   '
                under = (x + 3, len(name))
                w = 3 + len(name)
            else:
                s += fg(MUTED) + icon + OFF + '    '
                w = 2
            self.tab_spans.append((x, x + w, name))
            x += w + 3
        self.at(1, self.x0, s)
        if under:
            self.at(2, under[0], fg(ACCENT) + '▔' * under[1] + OFF)
        if self.tab != 'progress':
            tail = self.today_words()
            if x + width(tail) <= self.x0 + self.W:
                self.at(1, self.x0 + self.W - width(tail), tail)

    def draw_row(self, i):
        row = self.first + i - self.top
        if not 0 <= i - self.top < self.visible or i >= len(self.rows):
            return
        r = self.rows[i]
        w = self.list_w
        value, vw = r.value, width(r.value)
        name = at_word(r.name, max(w - 4 - (vw + 2 if vw else 0), 0))
        pad = ' ' * max(w - 4 - len(name) - vw, 0)
        if i == self.cursor:
            s = bg(SELECT) + fg(ON_SELECT) + '  ' + r.icon + '  ' + name + pad + plain(value) + ' ' + OFF
        else:
            s = '  ' + fg(MUTED) + r.icon + OFF + '  ' + name + pad + value + OFF + ' '
        self.at(row, self.x0 - 1, s)

    def draw_list(self):
        if self.cursor < self.top:
            self.top = self.cursor
        if self.cursor >= self.top + self.visible:
            self.top = self.cursor - self.visible + 1
        for i in range(self.top, min(self.top + self.visible, len(self.rows))):
            self.draw_row(i)

    def today_words(self):
        m = self.app.store.minutes_today()
        if m >= DAY_MINUTES:
            return fg(STRONG) + 'enough for today' + OFF
        return fg(MUTED) + f'today  {int(m)} of {DAY_MINUTES} min' + OFF

    def told(self, tell):
        """about the row under the cursor → (its words, the keys it is about, the keys to warm)"""
        lit, heat = {}, {}
        kind, what = tell if tell else ('', None)
        words = ''
        if kind == 'lesson':
            words = fg(MUTED) + 'no score: only the fingers' + OFF
            if what.goal:
                words = fg(MUTED) + 'goal ' + OFF + f'{what.goal} wpm' + fg(MUTED) + ', 97 % or more' + OFF
                d = self.app.store.progress['lessons'].get(what.id)
                if d and d['best']:
                    words += fg(MUTED) + '   best ' + OFF + f'{d["best"]:.0f} wpm'
            for c in what.keys or '':
                for name, f in keys.needs(c):
                    lit[name] = f
        elif kind == 'stage':
            words = fg(MUTED) + f'{self.lessons_done(what)} of {course.stage_counts()[what]} lessons' + OFF
            for les in course.LESSONS:
                if les.stage == what:
                    for c in les.keys or '':
                        for name, f in keys.needs(c):
                            lit.setdefault(name, f)
        elif kind == 'plan':
            words = {'baseline': 'how fast you are today, however you type: touch typing will pass it.',
                     'resume': 'it goes on where it stopped.',
                     'warmup': 'a minute on what you own, before anything new.',
                     'test': 'the same test every day: the line you will watch rise.',
                     'practice': 'the course is done. this is what keeps it.'}.get(what, '')
        elif kind in ('words', 'weak'):
            words = what
            if kind == 'weak':
                heat = key_heat(self.app.store.keys)
        return words, lit, heat

    def draw_tell(self):
        pl = self.place
        tell = self.rows[self.cursor].tell if self.rows else None
        words, lit, heat = self.told(tell)
        place = ''
        if len(self.rows) > self.visible:     # (a list longer than its rows says where you are in it)
            place = f'{self.cursor + 1} of {len(self.rows)}'
        room = self.W - (len(place) + 2 if place else 0)
        if width(words) > room:
            words = at_word(plain(words), room)
        self.at(pl.words_y, self.x0, '\x1b[0m\x1b[K' + fg(MUTED) + words + OFF)
        if place:
            self.at(pl.words_y, self.x0 + self.W - len(place), fg(MUTED) + place + OFF)
        if not self.pic:
            return
        kb, k = self.kb, pl.scale
        changed = set(lit) | set(kb.lit) | set(heat) | set(kb.heat)
        shift = 'lshift' in lit or 'rshift' in lit
        if shift != kb.shift:
            kb.shift = shift
            changed |= {name for name, p in keys.PLACE.items() if p[4] != p[5]}
        kb.lit, kb.heat = lit, heat
        for name in changed:
            kb.paint_key(self.pic, name, k)
        fingers = set(lit.values())
        if self.hands and fingers != self.hands.lit:
            self.hands.lit = fingers
            self.hands.paint(self.pic, k, 0, art.KEY_H * k)
        self.t.write(pl.send(self.pic))

    def draw(self):
        self.t.write('\x1b[?25l')
        self.draw_tabs()
        if self.tab == 'progress':
            self.draw_progress()
        else:
            self.draw_list()
            if self.pic:
                self.pic.touch_all()
            self.draw_tell()
        if self.app.store.failed:
            self.at(self.app.size[1] - 1, self.x0, fg(ACCENT_TEXT) + self.app.icon('CROSS') + OFF + '  the disk would not take your progress')

    def move(self, to):
        if not self.rows:
            return
        to = max(0, min(to, len(self.rows) - 1))
        if to == self.cursor:
            return
        old, self.cursor = self.cursor, to
        if self.cursor < self.top or self.cursor >= self.top + self.visible:
            self.draw_list()
        else:
            self.draw_row(old)
            self.draw_row(to)
        self.draw_tell()

    def switch(self, tab):
        self.tab, self.stage, self.cursor, self.top = tab, None, 0, 0
        self.plan = plan(self.app)
        self.t.write('\x1b[2J')
        self.layout()
        self.draw()

    # ── input ────────────────────────────────────────────────────────────────
    def key(self, ev):
        if ev.kind == 'release':
            return
        n = ev.name
        ctrl = ev.mods & term.CTRL
        if ctrl and n == 'c':
            self.app.quit()
            return
        if ev.mods & (term.SUPER | term.ALT) or (ctrl and n != 'tab'):
            return
        if n in ('tab', 'right', 'left'):
            back = n == 'left' or (n == 'tab' and ev.mods & term.SHIFT)
            self.switch(TABS[(TABS.index(self.tab) + (-1 if back else 1)) % len(TABS)])
        elif n in ('down', 'j'):
            self.move(self.cursor + 1)
        elif n in ('up', 'k'):
            self.move(self.cursor - 1)
        elif n == 'pagedown':
            self.move(self.cursor + self.visible)
        elif n == 'pageup':
            self.move(self.cursor - self.visible)
        elif n == 'home':
            self.move(0)
        elif n == 'end':
            self.move(len(self.rows) - 1)
        elif n == 'enter':
            if ev.kind == 'press' and self.rows and self.rows[self.cursor].act:
                self.rows[self.cursor].act()
        elif n in ('escape', 'q') and ev.kind == 'press':
            if self.stage is not None:
                self.stage = None
                self.cursor = self.top = 0
                self.t.write('\x1b[2J')
                self.layout()
                self.draw()
            else:
                self.app.quit()

    def mouse(self, ev):
        col, row = ev.col - 1, ev.row - 1
        if ev.kind == 'wheel':
            self.move(self.cursor + ev.button)
            return
        if row == 1 and ev.kind == 'press':
            for a, b, name in self.tab_spans:
                if a <= col < b and name != self.tab:
                    self.switch(name)
                    return
        i = row - self.first + self.top
        inside = self.first <= row < self.first + self.visible and 0 <= i < len(self.rows) and self.x0 - 1 <= col <= self.x0 + self.list_w
        if ev.kind == 'move' and inside:
            self.move(i)
        elif ev.kind == 'press' and inside and ev.button == 0:
            self.move(i)
            if self.rows[i].act:
                self.rows[i].act()

    # ── the progress tab ─────────────────────────────────────────────────────
    def progress_layout(self):
        """the facts where the list stands, the speed beside them, each key's sureness on the keyboard; under it, where
        the hands stand elsewhere, every day practised"""
        pl = self.place
        cols, rows, cw, ch = self.app.size
        self.chart = self.cal = None
        foot = pl.words_y + 1 if pl.scale else rows - 1
        self.foot = foot
        self.chart_x = self.x0 + min(36, self.W // 2)
        wide = self.x0 + self.W - self.chart_x
        self.chart_rows = min(foot - self.first, 12)
        if wide * cw >= 200 and self.chart_rows >= 5:
            self.chart = canvas.Picture(wide * cw, self.chart_rows * ch, (cw, ch))
        if pl.scale:
            self.pic, self.kb, _ = pl.picture(hands=False)
            self.kb.heat = key_heat(self.app.store.keys)
            self.kb.paint(self.pic, pl.scale)
            self.cal_y = pl.pic_y + pl.key_rows
            self.cal_rows = pl.pic_rows - pl.key_rows if pl.with_hands else 0
            px = art.KEY_W * pl.scale
            pitch = max((px + 2) // CALENDAR_WEEKS, 9)
            self.cal_tall = math.ceil(7 * pitch / ch)
            if self.cal_rows >= self.cal_tall + 1:
                self.cal = canvas.Picture(px, self.cal_tall * ch, (cw, ch))
                self.cal_pitch = pitch

    def draw_progress(self):
        a = self.app
        st = a.store
        h = st.history()
        x = self.x0
        cols, rows, cw, ch = a.size
        tests = [r for r in h if r.get('k') in ('test', 'check')]
        best = max((r['w'] for r in tests), default=None)
        last = tests[-1] if tests else None
        base = st.progress['baseline']
        total = sum(r.get('s', 0) for r in h)
        facts = [('lessons', f'{self.lessons_done()} of {len(course.LESSONS)}'),
                 ('last test', f'{last["w"]:.0f} wpm, {last["a"]:.1f} %' if last else 'none yet'),
                 ('best test', f'{best:.0f} wpm' if best is not None else 'none yet')]
        if base:
            passed = best is not None and best > base
            facts.append(('your old way', f'{base:.0f} wpm' + (', passed' if passed else '')))
        when = fit_power(tests)
        if when:
            facts.append(('100 wpm', 'around ' + time.strftime('%B %Y', time.localtime(when)).lower()))
        facts += [('in all', f'{int(total // 3600)} h {int(total % 3600 // 60)} min'),
                  ('days', str(len({time.strftime("%Y-%m-%d", time.localtime(r["d"])) for r in h})))]
        rolls = [r['o'] for r in h[-40:] if 'o' in r]
        if rolls:
            facts.append(('rollover', f'{sum(rolls) / len(rolls):.0f} %'))
        slow = sorted((k for k in course.weakness(st.keys) if len(k) == 2), key=course.weakness(st.keys).get, reverse=True)[:4]
        if slow:
            facts.append(('slowest pairs', ' '.join(slow)))
        pad = max(len(k) for k, _ in facts)
        for i, (k, v) in enumerate(facts):
            if self.first + i < self.foot:
                self.at(self.first + i, x + 3, fg(MUTED) + k.ljust(pad + 2) + OFF + at_word(v, max(self.chart_x - x - 3 - pad - 3, 4) if self.chart else 40))
        pal = art.PALETTE[a.dark]
        if self.chart:
            self.heading(1, a.icon('USAGE'), 'speed', self.chart_x, x + self.W - self.chart_x)
            self.paint_chart(tests, base)
            self.t.write(self.chart.send(self.chart_x + 1, self.first + 1, pal))
        if self.pic:
            self.pic.touch_all()
            self.t.write(self.place.send(self.pic))
        if self.cal:
            run = streak(h)
            self.heading(self.cal_y, a.icon('CALENDAR'), 'days', x, self.W, fg(MUTED) + f'{run} in a row' + OFF if run > 1 else '')
            self.paint_calendar(h)
            self.t.write(self.cal.send(self.place.pic_x + 1, self.cal_y + (2 if self.cal_rows >= self.cal_tall + 2 else 1) + 1, pal))

    def paint_chart(self, tests, base):
        p = self.chart
        p.clear()
        ink = art.INK
        wpms = [r['w'] for r in tests][-200:]
        top = max([110] + wpms) * 1.05
        H, W = p.h - 3, p.w - 24

        def y(v):
            return H - int(v / top * H) + 1
        label_y = None
        for m in reversed(MILESTONES):        # (a row of dots each; its figure at the left, where it has room)
            if m <= top:
                if label_y is None or y(m) - label_y >= 15:
                    art.paint_word(p, 0, y(m) - 7, str(m), ink['faint'], 1)
                    label_y = y(m)
                for xx in range(24, p.w, 6):
                    p.fill(xx, y(m), 1, 1, ink['edge2'])
        if base:
            for xx in range(24, p.w, 3):
                p.fill(xx, y(base), 1, 1, ink['muted'])
        if wpms:
            step = W / max(len(wpms) - 1, 1)
            prev = None
            for i, v in enumerate(wpms):
                xx, yy = 24 + int(i * step), y(v)
                if prev:
                    dx, dy = xx - prev[0], yy - prev[1]
                    n = max(abs(dx), abs(dy), 1)
                    for t in range(n + 1):
                        p.fill(prev[0] + dx * t // n, prev[1] + dy * t // n, 2, 2, ink['asagi'])
                prev = (xx, yy)
            p.fill(prev[0] - 2, prev[1] - 2, 5, 5, ink['accent'])

    def paint_calendar(self, history):
        """the months behind you, a seal for every day practised (the handbook's "calendar full of green squares"), today at the right end"""
        p = self.cal
        p.clear()
        ink = art.INK
        pitch = self.cal_pitch
        days = {time.strftime('%Y-%m-%d', time.localtime(r['d'])) for r in history}
        now = time.time()
        weeks = min(53, (p.w + 2) // pitch)
        back = time.localtime(now).tm_wday + (weeks - 1) * 7
        left = p.w + 2 - weeks * pitch
        size = pitch - 2
        for i in range(back + 1):
            lt = time.localtime(now - (back - i) * 86400)
            on = time.strftime('%Y-%m-%d', lt) in days
            x, y = left + i // 7 * pitch, lt.tm_wday * pitch
            p.fill(x + 1, y, size - 2, size, ink['accent'] if on else ink['edge'])
            p.fill(x, y + 1, size, size - 2, ink['accent'] if on else ink['edge'])


# ── a lesson ─────────────────────────────────────────────────────────────────
class LessonScreen(Screen):
    wants_mouse = False

    def __init__(self, app, index=None, *, lesson=None, text=None, resume=None, day_test=False):
        super().__init__(app)
        self.day_test = day_test
        self.index = index
        self.lesson = lesson if lesson is not None else course.LESSONS[index]
        les = self.lesson
        st = app.store
        if resume is not None:
            self.run = resume
        else:
            body = text if text is not None else course.text_for(les, app.rng(), st.keys)
            self.run = metrics.Run(body, les.flow, les.limit)
        self.held = {}             # keys down now → when
        self.prev_key = None
        self.notice = ''
        self.notice_until = 0.0
        self.wrong_until = 0.0
        self.thumb = 5             # (the space bar's, this time: the other hand's than the last letter)
        self.saved_at = 0.0
        self.finished = False
        self.pacer_cell = None
        self.caps = False          # (caps lock on: every key tells it)
        self.watched = self.lesson.kind in ('sentences', 'passage') and not self.lesson.limit
        self.eye_next = 0.0        # (when the eye opens next: at random, every 40–60 s of a text)
        self.eye_open = 0.0        # (when it opened; 0: it is shut)
        self.dimmed = False        # (it was not answered: the text waits)
        self.paused_shown = False
        self.drawn_line = -1
        self.feed = None
        self.spans = []
        self.kb = self.hands = self.pic = None
        self.caret_on = True
        self.blink_at = 0.0
        self.last_key = 0.0
        self.stale = False         # (something changed since the last frame: tick draws it, once, however many keys came)
        self.touched = set()       # (the letters to paint again)
        self.want_save = False
        self.painted_wrong = set()
        self.news = ''             # (a mark passed for the first time: the result says it)
        self.clean = 0             # (keys since the last slip)
        self.motes = None
        self.motes_at = 0.0
        self.save_resume()

    @classmethod
    def free(cls, app, what, arg=None, day_test=False, title=None):
        """from the practice tab, or a file: no lesson's seals, measured all the same"""
        rng = app.rng()
        st = app.store
        limit = None
        kind = what
        known = 'abcdefghijklmnopqrstuvwxyz'
        title = title or {'weak': 'your weakest keys', 'words': 'plain words', 'passage': 'a passage', 'warmup': 'warm up, your weakest keys'}.get(what, what)
        if what == 'weak':
            text = ' '.join(course.pick_words(known, rng, '', 60, course.weakness(st.keys)))
        elif what == 'warmup':
            done = [les for les in course.LESSONS if les.id in st.progress['lessons']]
            known = ''.join(c for c in (done[-1].known if done else known) if c.isalpha() and c.islower()) or known
            text = ' '.join(course.pick_words(known, rng, '', 45, course.weakness(st.keys)))
        elif what == 'words':
            top = course.words()[:200]
            text = course.fill(top, 300, rng)
        elif what == 'passage':
            text = course.passages()[rng.randrange(len(course.passages()))]
        elif what == 'code':
            blocks = course.code_blocks()[arg]
            start = rng.randrange(len(blocks))
            text = '\n'.join(blocks[(start + i) % len(blocks)] for i in range(3))
            title = arg
        elif what == 'test':
            limit = arg
            top = course.words()[:300]
            text = course.fill(top, arg * 30 + 100, rng)
            title = f'test, {arg} seconds'
        elif what == 'baseline':
            limit = 60
            top = course.words()[:200]
            text = course.fill(top, 1500, rng)
            title = 'one minute, the way you type now'
        else:          # a file of your own
            text = arg
        lesson = course.Lesson(f'free.{what}', 8, kind, title, '', '', 0, 0, True, len(text), limit, None)
        return cls(app, None, lesson=lesson, text=text, day_test=day_test)

    # ── its place on the screen ──────────────────────────────────────────────
    def layout(self):
        cols, rows, cw, ch = self.app.size
        self.rows_n = rows
        pl = self.place = Stage(self.app)
        self.x0, self.W = pl.x, pl.W
        self.scale, self.show_hands = pl.scale, pl.with_hands
        self.letters = art.Letters(min(self.scale, 2) or 1)
        # (the text and the keyboard one column, one left edge; with no keyboard, up to 76 letters)
        self.tw_px = art.KEY_W * self.scale if self.scale else min(self.W * cw, 76 * self.letters.w)
        self.chars = max(self.tw_px // self.letters.w, 1)
        self.lines_n = max(min((pl.words_y - 3) * ch // self.letters.h, TEXT_LINES), 1)
        self.back = 1 if self.lines_n >= 3 else 0      # (the line just typed stays in view, above the one under way)
        self.text_y = max(pl.words_y - math.ceil(self.lines_n * self.letters.h / ch), 0)
        self.text_x = pl.pic_x if self.scale else self.x0
        self.notice_y = pl.words_y
        self.notice_w = self.W - (self.text_x - self.x0) - 3
        self.tp = canvas.Picture(max(self.tw_px, self.letters.w), self.lines_n * self.letters.h, (cw, ch))
        self.spans = wrap(self.run.text, max(self.chars - 1, 1))     # (its last space or Enter has a whole letter's room)
        self.drawn_line = -1
        self.feed = None
        self.pic = self.kb = self.hands = self.motes = None
        self.hand_state = None
        if self.scale:
            self.pic, self.kb, self.hands = pl.picture()
            self.pic_x, self.pic_y = pl.pic_x, pl.pic_y
            self.painted_wrong = set()
            self.motes = art.Motes(self.app.dark, course.fresh(self.app.seed)) if self.hands else None
            self.apply_keys(send=False)

    def line_of(self, pos):
        lo, hi = 0, len(self.spans) - 1
        while lo < hi:
            mid = (lo + hi) // 2
            if pos >= self.spans[mid][1]:
                lo = mid + 1
            else:
                hi = mid
        return lo

    # ── the words ────────────────────────────────────────────────────────────
    def paint_letter(self, i, place=None):
        """the character at position i as it stands now: typed faint, a wrong one on vermilion, the next one
        under the caret (the terminal's own: a vermilion block, Sumi Term's §1); the lines far ahead a step quieter"""
        place = place or self.place_of(i)
        if not place:
            return
        r = self.run
        c = r.text[i]
        shown = '↵' if c == '\n' else c
        ink = art.INK
        if self.dimmed:
            cell = self.letters.cell(shown, ink['edge2'])
        elif i == r.pos and self.caret_on and self.app.focused:
            cell = self.letters.cell(shown if c != ' ' else ' ', ink['text_on_accent'], ink['accent'])
        elif i < r.pos:
            got = r.got.get(i)
            if got is None or got == c:
                cell = self.letters.cell(shown, ink['faint'])
            else:
                cell = self.letters.cell('·' if c == ' ' else shown, ink['text_on_select'], ink['select'])
        elif i == self.pacer_cell:
            cell = self.letters.cell(shown, ink['text'], ink['edge2'])
        elif c == '\n':
            cell = self.letters.cell(shown, ink['faint'])
        else:
            far = place[1] // self.letters.h - self.back >= 2
            cell = self.letters.cell(shown, ink['muted' if far else 'text'])
        self.tp.spans(place[0], place[1], cell)

    def place_of(self, pos):
        """where position pos lies on the text's picture"""
        line = self.line_of(pos)
        k = line - self.drawn_line + self.back
        if not 0 <= k < self.lines_n:
            return None
        return (pos - self.spans[line][0]) * self.letters.w, k * self.letters.h

    def draw_text(self, force=False):
        r = self.run
        line = self.line_of(min(r.pos, len(r.text) - 1))
        if line != self.drawn_line or force:
            if self.drawn_line >= 0 and line == self.drawn_line + 1 and self.lines_n > 1:
                self.feed = ([bytes(row) for row in self.tp.rows], time.monotonic())   # (the paper feeds: what it was, and since when)
            self.drawn_line = line
            self.tp.clear()
            for k in range(self.lines_n):
                n = line + k - self.back
                if 0 <= n < len(self.spans):
                    a, b = self.spans[n]
                    for i in range(a, b):
                        self.paint_letter(i, ((i - a) * self.letters.w, k * self.letters.h))

    def send_text(self):
        """the text, or on its way up a line: a spring, no overshoot, whole pixels, the old page leaving over the top"""
        tp = self.tp
        pal = art.PALETTE[self.app.dark]
        final = None
        if self.feed:
            old, t0 = self.feed
            t = time.monotonic() - t0
            left = round(self.letters.h * (1 + FEED_RATE * t) * math.exp(-FEED_RATE * t))
            if left <= 0 or t >= FEED_SECONDS:
                self.feed = None
                tp.touch_tiles()
            else:
                final = tp.rows
                h = self.letters.h
                tp.rows = [old[y + h - left] if y < left else final[y - left] for y in range(len(final))]
                tp.touch_tiles()
        self.t.write(tp.send(self.text_x + 1, self.text_y + 1, pal))
        if final is not None:
            tp.rows = final

    def render(self, now):
        """what the keys since the last frame changed, drawn once: a burst of keys is one frame, never a queue of them"""
        if not self.stale:
            return
        self.stale = False
        r = self.run
        self.draw_text()
        for i in self.touched:
            if i < len(r.text):
                self.paint_letter(i)
        self.touched.clear()
        if not r.done:
            self.paint_letter(r.pos)
        self.apply_keys()
        self.draw_heading(now)
        if not self.notice and (not self.pic or r.correct + r.wrong <= 1):
            self.draw_notice()
        self.send_text()

    # ── the keyboard and the hands ───────────────────────────────────────────
    def wanted(self):
        """the keys the next character takes: [(key, finger)]"""
        r = self.run
        if r.done:
            return []
        if self.caps:
            return [('caps', 0)]
        if self.eye_open:
            return [('tab', 0)]
        anchor = self.anchor()
        if anchor and anchor not in self.held:
            return [(anchor, keys.PLACE[anchor][3])]
        return keys.needs(r.text[r.pos], self.thumb)

    def anchor(self):
        """the key this lesson has held down, once the terminal tells releases"""
        return self.lesson.extra if self.lesson.kind == 'anchor' and self.app.releases else None

    def apply_keys(self, send=True):
        """the keyboard's lights and the hands' pose, as the next key and the held ones want them"""
        if not self.pic:
            return
        kb, hands = self.kb, self.hands
        quiet = self.app.store.progress['quiet']
        want = [] if quiet else self.wanted()
        lit = dict(want)
        # (the legends a shifted key would show: what is held, or what the next key will take)
        shift = any(k in self.held or k in lit for k in ('lshift', 'rshift'))
        changed = set(lit) ^ set(kb.lit) | {k for k in lit if kb.lit.get(k) != lit[k]}
        new_down = {k for k in self.held if k in keys.PLACE}
        changed |= new_down ^ kb.down
        changed |= kb.wrong ^ self.painted_wrong
        self.painted_wrong = set(kb.wrong)
        if shift != kb.shift:
            kb.shift = shift
            changed |= {name for name, p in keys.PLACE.items() if p[4] != p[5]}
        kb.lit, kb.down = lit, new_down
        for name in changed:
            kb.paint_key(self.pic, name, self.scale)
        if hands:
            pose = {}
            lit_f = set()
            for name, f in want:
                lit_f.add(f)
                home = keys.HOME.get(f)
                if home and name != home:
                    hx, hy = keys.centre(home)
                    kx, ky = keys.centre(name)
                    pose[f] = ((kx - hx) // 2, (hy - ky) // 3 + 3)
                else:
                    pose[f] = (0, 3)
            pressed = {keys.PLACE[k][3] if k != 'space' else self.thumb for k in new_down if k in keys.PLACE}
            wrong_f = {keys.PLACE[k][3] for k in kb.wrong if k in keys.PLACE}
            state = (pose, lit_f, pressed, wrong_f)
            if state != self.hand_state or (self.motes and self.motes.live):
                self.hand_state = state
                hands.pose, hands.lit, hands.pressed, hands.wrong = pose, lit_f, pressed, wrong_f
                hands.paint(self.pic, self.scale, 0, art.KEY_H * self.scale)
                if self.motes:
                    self.motes.paint(self.pic, self.scale, 0, art.KEY_H * self.scale)
        if send:
            self.t.write(self.pic.send(self.pic_x + 1, self.pic_y + 1, art.PALETTE[self.app.dark]))

    # ── drawing ──────────────────────────────────────────────────────────────
    def stats(self, now=None):
        r = self.run
        if r.correct + r.wrong == 0:
            return ''
        wpm, acc = r.net(now), r.accuracy()
        s = fg(MUTED) + f'{wpm:.0f} wpm  {math.floor(acc)} %' + OFF
        if self.paused_shown:
            s = fg(STRONG) + 'paused' + OFF + '  ' + s
        if r.limit:
            left = max(r.limit - r.active(now), 0)
            s = fg(STRONG) + clock(math.ceil(left)) + OFF + '  ' + s
        return s

    def draw_heading(self, now=None):
        r = self.run
        if r.limit:
            done = r.active(now) / r.limit
        else:
            done = r.pos / max(len(r.text), 1)
        self.at(1, 0, '\x1b[K')
        self.heading(1, self.app.icon('KEYBOARD'), self.lesson.title, self.x0, self.W, self.stats(now), done)

    def plain_words(self):
        """what the row under the text says when nothing is wrong: a meet names its fingers until the first key; a
        window too small for the keyboard always names the next finger"""
        r = self.run
        if self.lesson.kind == 'meet' and r.pos == 0 and r.correct + r.wrong == 0:
            named = [f'{c} {keys.NAMES[keys.needs(c)[0][1]]}' for c in self.lesson.keys if keys.needs(c)]
            home = 'feel the bumps on f and j.  ' if self.lesson.id == 'home.fj.meet' else ''
            return home + '   '.join(named)
        if not self.pic and not r.done:
            need = keys.needs(r.text[r.pos], self.thumb)
            if need:
                return keys.NAMES[need[0][1]] + (' and ' + keys.NAMES[need[1][1]] if len(need) > 1 else '')
        return ''

    def draw_notice(self):
        if self.notice_y >= self.rows_n:
            return
        self.at(self.notice_y, self.x0, '\x1b[0m' + ' ' * self.W)
        if self.eye_open:             # (the eye before anything else that wants this row: it must be seen)
            self.draw_eye()
        elif self.notice:
            self.at(self.notice_y, self.text_x, fg(ACCENT_TEXT) + self.app.icon('CROSS') + OFF + '  ' + at_word(self.notice, max(self.notice_w, 0)))
        else:
            self.at(self.notice_y, self.text_x, fg(MUTED) + at_word(self.plain_words(), max(self.notice_w + 3, 0)) + OFF)

    def say(self, words, now, secs=2.0):
        if words != self.notice:
            self.notice = words
            self.draw_notice()
        self.notice_until = now + secs

    def draw(self):
        self.t.write('\x1b[?25l')
        self.draw_heading()
        self.draw_notice()
        if self.pic:
            self.pic.touch_all()
            self.t.write(self.pic.send(self.pic_x + 1, self.pic_y + 1, art.PALETTE[self.app.dark]))
        self.drawn_line = -1
        self.draw_text()
        self.tp.touch_all()
        self.send_text()

    # ── time ─────────────────────────────────────────────────────────────────
    def wait(self):
        if self.feed:
            return 0.012
        if self.motes and (self.motes.live or self.motes.wanted) and self.app.focused:
            return min(art.Motes.STEP, 0.08)
        if self.notice or self.wrong_until or self.lesson.kind == 'pacer' and self.run.first is not None:
            return 0.08
        if self.run.limit and self.run.first is not None:
            return 0.25
        return 0.25 if self.app.focused else None     # (the caret's blink)

    def tick(self, now):
        if self.finished:
            return
        if self.notice and now >= self.notice_until:
            self.notice = ''
            self.draw_notice()
        if self.wrong_until and now >= self.wrong_until:
            self.wrong_until = 0.0
            if self.kb and self.kb.wrong:
                if not self.app.releases:      # (no release will ever come for it)
                    for name in self.kb.wrong:
                        self.held.pop(name, None)
                self.kb.wrong = set()
                self.stale = True
        r = self.run
        if r.limit and r.first is not None:
            if r.expired(now):
                self.finish(now)
                return
            self.stale = True
        if self.app.focused and now - self.last_key > 0.6 and now >= self.blink_at and not self.dimmed:
            self.blink_at = now + 0.5
            self.caret_on = not self.caret_on
            self.stale = True
        if self.lesson.kind == 'pacer' and r.first is not None:
            self.draw_pacer(now)
        if r.first is not None and not r.done:
            stopped = r.hold or now - r.last > metrics.PAUSE
            if stopped != self.paused_shown:
                self.paused_shown = stopped
                self.stale = True
        if self.watched:
            self.tick_eye(now)
        if self.feed:
            self.stale = True
        if self.motes and now >= self.motes_at and self.app.focused and (self.motes.live or self.motes.wanted):
            self.motes_at = now + art.Motes.STEP
            self.motes.wanted = 0 if r.done or now - self.last_key > 2 else min(self.clean // art.Motes.EVERY, art.Motes.MOST)
            was = bool(self.motes.live)
            if self.motes.step() or was:
                self.hand_state = None       # (the strip is painted again, with them on it)
                self.stale = True
        self.render(now)
        if self.want_save:
            self.want_save = False
            self.t.flush()           # (the key's frame first: the disk never holds it up)
            self.save_resume(now)

    def tick_eye(self, now):
        """Yechiam 2003's signal: open at random; answered by its key within 2 s, or the text waits, dimmed"""
        if not self.eye_next:
            if self.run.first is not None:
                self.eye_next = now + self.eye_gap()
            return
        if not self.eye_open and now >= self.eye_next and not self.paused_shown and self.notice_y < self.rows_n:
            self.eye_open = now
            self.draw_notice()
            self.stale = True
        elif self.eye_open and not self.dimmed and now - self.eye_open > 2:
            self.dimmed = True
            self.run.pause()
            self.redraw_text()

    def eye_gap(self):
        return self.app.args.get('eye') or self.app.rng().uniform(40, 60)

    def draw_eye(self):
        """on the row between the text and the keyboard, where looking down at the keys misses it"""
        cw, ch = self.app.size[2:]
        pic = canvas.Picture(40, ch, (cw, ch))
        art.paint_eye(pic, 0, max((ch - 18) // 2, 0), 2, self.app.dark)
        self.t.write(pic.send(self.text_x + 1, self.notice_y + 1, art.PALETTE[self.app.dark]))
        self.at(self.notice_y, self.text_x + math.ceil(40 / cw) + 1, fg(STRONG) + 'tab' + OFF)

    def redraw_text(self):
        self.drawn_line = -1
        self.stale = True

    def draw_pacer(self, now):
        goal = self.lesson.goal or 40
        at = min(int(goal * 5 / 60 * self.run.active(now)), len(self.run.text) - 1)
        if at == self.pacer_cell:
            return
        old, self.pacer_cell = self.pacer_cell, at
        if old is not None:
            self.touched.add(old)
        self.touched.add(at)
        self.stale = True

    def focus(self, on):
        if not on:
            self.run.pause()
            self.held.clear()
            if self.kb:
                self.kb.wrong = set()
            self.want_save = True
        self.caret_on = True
        self.stale = True

    # ── input ────────────────────────────────────────────────────────────────
    def key(self, ev):
        now = ev.t
        name = ev.name
        if name == 'caps':                 # (the key itself turns it, before its own report says so)
            if ev.kind == 'press':
                self.caps = not self.caps
                self.stale = True
        elif bool(ev.mods & term.CAPS) != self.caps:
            self.caps = bool(ev.mods & term.CAPS)
            self.stale = True
        if ev.kind == 'release':
            self.held.pop(name, None)
            self.app.releases = True
            self.run.releases = True
            if self.kb:
                self.kb.wrong.discard(name)
            self.stale = True
            return
        if ev.mods & (term.CTRL | term.ALT | term.SUPER) and name not in MODIFIERS:
            if ev.mods & term.CTRL and name == 'c':
                self.leave()
                self.app.quit()
            elif ev.mods & term.CTRL and name == 'k' and ev.kind == 'press':
                p = self.app.store.progress
                p['quiet'] = not p['quiet']
                self.stale = True
            return
        if name == 'escape':
            self.leave()
            self.app.go(Home(self.app))
            return
        if ev.kind == 'repeat':
            if name == 'backspace':
                self.erase(now)
            return
        if name in MODIFIERS or name == 'caps':
            self.held[name] = now
            self.stale = True
            return
        if name in ('up', 'down', 'left', 'right', 'home', 'end', 'pageup', 'pagedown', 'insert', 'delete', 'other'):
            return
        if name == 'backspace':
            self.erase(now)
            return
        if name == 'tab':
            if self.eye_open:
                self.eye_open = 0.0
                self.eye_next = now + self.eye_gap()
                self.draw_notice()
                if self.dimmed:
                    self.dimmed = False
                    self.redraw_text()
                self.stale = True
            return
        if self.dimmed:
            return
        anchor = self.anchor()
        if anchor:
            if name == anchor:
                self.held[name] = now
                self.stale = True
                return
            if anchor not in self.held:
                self.say(f'hold {anchor} down with the other hand', now)
                return
        ch = '\n' if name == 'enter' else ev.text
        if not ch:
            return
        if ev.mods & term.CAPS:
            self.say('caps lock is on', now)
            return
        if not ch[0].isascii():
            self.say('the keyboard is not in english: alt + shift', now)
            return
        self.typed(ch[0], name, now)

    def typed(self, ch, name, now):
        r = self.run
        if r.expired(now):       # (past the clock: the test is over, this key is not part of it)
            self.finish(now)
            return
        self.touched.add(r.pos)
        rolled = bool(self.prev_key) and self.prev_key in self.held
        self.last_key = now
        self.caret_on = True
        ok = r.press(ch, now, rolled)
        self.prev_key = name
        self.held[name] = now
        self.clean = self.clean + 1 if ok else 0
        if self.motes:
            self.motes.wanted = min(self.clean // art.Motes.EVERY, art.Motes.MOST)
            if not ok and self.motes.live:   # (a slip: they are gone)
                self.motes.live.clear()
                self.hand_state = None
        want_shift = next((k for k, _ in keys.needs(ch) if k in ('lshift', 'rshift')), None)
        if ok and want_shift and want_shift not in self.held and any(s in self.held for s in ('lshift', 'rshift')):
            r.shift_slips += 1
            self.say(f'the {"right" if want_shift == "rshift" else "left"} shift for that one', now)
        if ok and name in keys.PLACE and keys.PLACE[name][3] != 5:
            self.thumb = 5 if keys.PLACE[name][3] < 5 else 4
        if not ok and self.kb is not None and name in keys.PLACE:
            self.kb.wrong.add(name)
            self.wrong_until = now + 0.18
        if not self.app.releases:
            self.held.pop(name, None)
        if r.flow and not r.done and r.text[r.pos - 1] == '\n':
            r.skip_indent()
        if r.done:
            self.finish(now)
            return
        self.stale = True
        if now - self.saved_at > 2.0 or r.text[r.pos - 1] == ' ':
            self.want_save = True

    def erase(self, now):
        r = self.run
        at = r.pos
        if r.backspace(now):
            self.touched.add(at)
            self.stale = True

    def pasted(self):
        self.say('pasted text is not typed', time.monotonic())

    # ── kept, finished, left ─────────────────────────────────────────────────
    def landmark(self, wpm, acc):
        """a test or a check that passed a mark for the first time: said once. The first is the crossover: touch
        typing past his old way (Yechiam 2003: until there, people go back to it)"""
        p = self.app.store.progress
        if self.lesson.kind not in ('test', 'check') or acc < 97:
            return ''
        base, news = p['baseline'], ''
        if base and wpm > base and not p['crossed']:
            p['crossed'] = True
            news = f'past your old way, {base:.0f} wpm. from here on it is only faster.'
        for m in MILESTONES:
            if wpm > m > p['mark']:
                p['mark'] = m
                news = MILESTONE_WORDS[m] if not news else news
        return news

    def save_resume(self, now=None):
        """a course's lesson under way, kept (from its first key: opening another lesson takes nothing away). --trace, for
        its tests: any run, as it stands, in a file of theirs"""
        self.saved_at = now if now is not None else time.monotonic()
        snap = {'lesson': self.lesson.id, 'index': self.index, 'title': self.lesson.title, 'kind': self.lesson.kind, 'run': self.run.snapshot()}
        if self.index is not None and self.run.pos:
            self.app.store.save_resume(snap)
        trace = self.app.args.get('trace')
        if trace:
            with open(trace + '.tmp', 'w') as f:
                json.dump(snap, f)
            os.replace(trace + '.tmp', trace)

    def leave(self):
        """Esc: a lesson is kept, to go on from later; a practice run ends here"""
        self.save_resume()

    def finish(self, now):
        self.finished = True
        st = self.app.store
        r = self.run
        les = self.lesson
        wpm, raw, acc = r.net(now), r.raw(now), r.accuracy()
        secs = r.minutes(now) * 60
        st.learn(r.samples)
        st.add_time(secs)
        seals = seals_for(wpm, acc, les.low, les.goal) if les.goal else 0
        best = 0
        if self.index is not None:
            d = st.progress['lessons'].setdefault(les.id, {'seals': 0, 'best': 0.0, 'tries': 0})
            d['tries'] += 1
            best = d['best']
            d['seals'] = max(d['seals'], seals if les.goal else 0)
            d['best'] = max(d['best'], wpm)
        day = st.day()
        if les.kind == 'baseline':
            st.progress['baseline'] = round(wpm, 1)
        elif les.kind == 'warmup':
            day['warm'] = True
        elif self.day_test:
            day['test'] = True
        cons = r.consistency()
        roll = r.rollover()
        self.news = self.landmark(wpm, acc)
        rec = {'d': int(time.time()), 'l': les.id, 'k': les.kind, 'w': round(wpm, 2), 'r': round(raw, 2), 'a': round(acc, 2), 's': round(secs, 2)}
        if cons is not None:
            rec['c'] = round(cons, 1)
        if roll is not None:
            rec['o'] = round(roll, 1)
        st.append_history(rec)
        if self.index is not None:
            st.clear_resume()
        st.save()
        if les.kind == 'meet' and self.index is not None:   # (no score: on to its drill, without a stop)
            self.app.go(start(self.app, plan(self.app)))
            return
        self.app.go(Result(self.app, self, wpm, raw, acc, secs, cons, roll, seals, best))


# ── a result ─────────────────────────────────────────────────────────────────
def key_word(c):
    return {' ': 'space', '\n': 'enter'}.get(c, c)


def slow_keys(run):
    """the keys this run took clearly longer over than the rest of it: at most three, each pressed three times or more"""
    times = {}
    for c, ms, ok in run.samples:
        if ms is not None and ok and c in keys.CHARS:
            times.setdefault(c, []).append(ms)
    every = [m for v in times.values() for m in v]
    if not every:
        return []
    mean = sum(every) / len(every)
    slow = {c: sum(v) / len(v) for c, v in times.items() if len(v) >= 3 and sum(v) / len(v) > 1.4 * mean}
    return sorted(slow, key=slow.get, reverse=True)[:3]


class Result(Screen):
    """the seals stamped one after another (§11), the speed in display size, the facts, how it stands against the runs before
    it; the keyboard where it was, with what slipped on it, and the hands answering; Enter goes on, r again"""

    def __init__(self, app, lesson_screen, wpm, raw, acc, secs, cons, roll, seals, best):
        super().__init__(app)
        self.ls = lesson_screen
        self.les = lesson_screen.lesson
        self.index = lesson_screen.index
        self.wpm, self.raw, self.acc, self.secs, self.cons, self.roll = wpm, raw, acc, secs, cons, roll
        self.seals = seals
        self.best = best
        self.passed = not self.les.goal or seals > 0
        self.top_pic = self.bars = self.pic = self.kb = self.hands = None
        self.began = None
        self.stamped = 0
        self.opened = time.monotonic()
        self.slow = slow_keys(lesson_screen.run)
        self.family_name, self.family_runs = self.family()
        self.answer = self.hands_answer()    # (the hands' poses still to come, one each ANSWER_STEP)
        self.answer_at = 0.0

    def family(self):
        """the runs this one is measured against: every test and check; a course's lesson, those of its stage; a practice
        run, those of its kind. A key's first meeting has no speed to compare"""
        h = self.app.store.history()
        les = self.les
        if les.kind in ('test', 'check'):
            return 'your tests', [r for r in h if r['k'] in ('test', 'check')]
        if self.index is not None:
            ids = {x.id for x in course.LESSONS if x.stage == les.stage and x.goal}
            return course.STAGE_NAMES[les.stage], [r for r in h if r.get('l') in ids]
        return les.title, [r for r in h if r['k'] == les.kind and r.get('l') == les.id]

    def hands_answer(self):
        """passed: a wave, little to index on both hands (the gold seal: twice); not passed: they sink a little, and stay"""
        if not self.les.goal:
            return []
        if not self.passed:
            return [{f: (0, -3) for f in (0, 1, 2, 3, 6, 7, 8, 9)}]
        wave = [{f: (0, 4) for f in pair} for pair in ((0, 9), (1, 8), (2, 7), (3, 6))] + [{}]
        return wave * 2 if self.seals >= 6 else wave

    def layout(self):
        cols, rows, cw, ch = self.app.size
        pl = self.place = Stage(self.app)
        self.x0, self.W = pl.x, pl.W
        self.pic = self.kb = self.hands = self.top_pic = self.bars = None
        if pl.scale:
            self.pic, self.kb, self.hands = pl.picture()
            for c in self.slow:
                self.kb.heat[keys.needs(c)[0][0]] = 'flame'
            # (what slipped: the worst three in vermilion, the others a step quieter)
            for i, c in enumerate(sorted(self.ls.run.slips, key=self.ls.run.slips.get, reverse=True)):
                n = keys.needs(c)
                if n:
                    if i < 3:
                        self.kb.wrong.add(n[0][0])
                    else:
                        self.kb.heat[n[0][0]] = 'flame'
            self.kb.paint(self.pic, pl.scale)
        self.foot = pl.words_y if pl.scale else rows - 2     # (the verdict's row)
        room = self.foot - 3
        self.tall = 5 if self.les.goal else 3
        if room >= self.tall + len(self.facts()) and self.W * cw >= 192:
            self.top_pic = canvas.Picture(min(self.W * cw, 320), self.tall * ch, (cw, ch))
            self.bars_x = self.x0 + min(self.W // 2 + 4, 44)
            wide = self.x0 + self.W - self.bars_x
            self.bars_rows = min(room - 3, 7)
            if len(self.family_runs) >= 2 and wide * cw >= 120 and self.bars_rows >= 3:
                self.bars = canvas.Picture(wide * cw, self.bars_rows * ch, (cw, ch))

    def seal_state(self, i):
        if i >= min(self.seals, 5) or i >= self.stamped:
            return 'off'
        return 'gold' if self.seals >= 6 else 'on'

    def paint_top(self):
        p = self.top_pic
        if not p:
            return
        ink = art.INK
        if self.les.goal:
            for i in range(5):
                art.paint_seal(p, i * 40 + 2, 2, 32, self.app.dark, self.seal_state(i))
        y = 44 if self.les.goal else 4
        word = f'{self.wpm:.0f}'
        art.paint_word(p, 0, y, word, ink['strong'], 3)
        art.paint_word(p, (len(word) * 7 + 2) * 3, y + 20, 'wpm', ink['muted'], 1)

    def paint_bars(self):
        """the runs before this one, a bar each (the meter's rhythm: 6 px, 2 of air), this one at the right end"""
        p = self.bars
        ink = art.INK
        p.clear()
        runs = [r['w'] for r in self.family_runs][-(p.w // 8):]
        top = max(runs) or 1
        for i, v in enumerate(runs):
            h = max(round(v / top * (p.h - 1)), 2)
            p.fill(p.w - (len(runs) - i) * 8 + 2, p.h - h, 6, h, ink['accent'] if i == len(runs) - 1 else ink['faint'])

    def facts(self):
        les, r = self.les, self.ls.run
        out = [('accuracy', percent(self.acc) + ' %' + (', 97 at least' if les.goal else ''))]
        if les.goal:
            out.append(('goal', f'{les.goal} wpm'))
        prior = self.best if self.index is not None else max((x['w'] for x in self.family_runs[:-1]), default=0)
        if prior:
            out.append(('best', 'this one' if self.wpm > prior else f'{prior:.0f} wpm'))
        out.append(('time', clock(self.secs)))
        if self.cons is not None:
            out.append(('consistency', f'{self.cons:.0f} %'))
        if self.roll is not None and (les.stage >= 8):
            out.append(('rollover', f'{self.roll:.0f} %'))
        if r.shift_slips:
            out.append(('wrong shift', str(r.shift_slips)))
        return out

    def verdict(self):
        """one line: what to do about it"""
        les, r = self.les, self.ls.run
        slips = sorted(r.slips.items(), key=lambda kv: -kv[1])
        words = ''
        if slips:
            words = 'slipped on ' + ', '.join(key_word(c) for c, _ in slips[:3])
        elif self.slow:
            words = 'slowest on ' + ', '.join(key_word(c) for c in self.slow)
        if self.les.kind == 'baseline':
            return 'that is your old way. touch typing will pass it.'
        if self.ls.news:
            return self.ls.news
        if self.ls.day_test:
            return 'that is enough for today.'
        if not self.passed:
            if self.acc < 97:
                return 'slower, then: 97 % opens the next one.' + (' ' + words + '.' if words else '')
            return f'held your accuracy; {max(les.low - self.wpm, 1):.0f} wpm more opens the next one.'
        return words + '.' if words else ''

    def draw(self):
        a = self.app
        les = self.les
        rows = a.size[1]
        self.t.write('\x1b[?25l')
        place = ''
        if self.index is not None:
            place = fg(MUTED) + f'{self.index + 1} of {len(course.LESSONS)}' + OFF
        self.heading(1, a.icon('CHECK' if self.passed else 'CROSS'), les.title, self.x0, self.W, place)
        pal = art.PALETTE[a.dark]
        row = 3
        if self.top_pic:
            self.paint_top()
            self.top_pic.touch_all()
            self.t.write(self.top_pic.send(self.x0 + 1, row + 1, pal))
            row += self.tall + (self.foot - 3 > self.tall + len(self.facts()))
        else:
            speed = f'{self.wpm:.0f} wpm'
            self.at(row, self.x0, seals_text(self.seals) + '  ' + speed if les.goal else speed)
            row += 2
        if self.bars:
            self.heading(3, a.icon('USAGE'), self.family_name, self.bars_x, self.x0 + self.W - self.bars_x)
            self.paint_bars()
            self.t.write(self.bars.send(self.bars_x + 1, 5 + 1, pal))
        facts = self.facts()
        pad = max(len(k) for k, _ in facts)
        for k, v in facts:
            if row < self.foot:
                self.at(row, self.x0 + 3, fg(MUTED) + k.ljust(pad + 2) + OFF + v)
                row += 1
        words = self.verdict()
        if words and self.foot > 3:
            self.at(self.foot, self.x0, at_word(words, self.W))
        if self.pic:
            self.pic.touch_all()
            self.t.write(self.place.send(self.pic))
        if rows >= 8:
            go = 'next' if self.passed else 'again'
            again = '    r  ' + fg(MUTED) + 'again' + OFF if self.index is not None and self.passed else ''
            self.at(rows - 1, self.x0, 'enter  ' + fg(MUTED) + go + OFF + again)
        self.began = None

    def stamping(self):
        return self.top_pic is not None and self.stamped < min(self.seals, 5)

    def wait(self):
        return 0.03 if self.stamping() or (self.hands and self.answer) else None

    def tick(self, now):
        if self.stamping():
            if self.began is None:
                self.began = now + 0.08
                return
            # (each stamp: down for 60 ms, lit and a pixel larger; then as it stays. 140 ms apart)
            i = self.stamped
            at = now - self.began - i * 0.14
            if at >= 0:
                p = self.top_pic
                down = at < 0.06
                state = 'down' if down else ('gold' if self.seals >= 6 else 'on')
                art.paint_seal(p, i * 40 + 2, 2, 32, self.app.dark, state)
                if not down:
                    self.stamped += 1
                self.t.write(p.send(self.x0 + 1, 4, art.PALETTE[self.app.dark]))
            return
        if self.hands and self.answer and now >= self.answer_at:      # (when the stamps are down, the hands answer)
            self.answer_at = now + ANSWER_STEP
            self.hands.pose = self.answer.pop(0)
            self.hands.paint(self.pic, self.place.scale, 0, art.KEY_H * self.place.scale)
            self.t.write(self.place.send(self.pic))

    def key(self, ev):
        if ev.kind != 'press':
            return
        n = ev.name
        if ev.mods & term.CTRL and n == 'c':
            self.app.quit()
        elif ev.t - self.opened < 0.35:     # (the fingers still going, a key past the end: it asks for nothing)
            return
        elif n == 'enter':
            self.next()
        elif n == 'r' and not ev.mods & (term.CTRL | term.ALT | term.SUPER):
            self.again()
        elif n in ('escape', 'q'):
            self.app.go(Home(self.app, 'course' if self.index is not None else 'practice'))

    def next(self):
        if not self.passed:
            self.again()
        elif self.ls.day_test:               # (the day is done: back to the tabs, no further lesson pressed on him)
            self.app.go(Home(self.app))
        elif self.index is None and self.les.kind not in ('baseline', 'warmup'):
            self.app.go(Home(self.app, 'practice'))
        else:
            self.app.go(start(self.app, plan(self.app)))

    def again(self):
        if self.index is None:
            self.app.go(Home(self.app, 'practice'))
        else:
            self.app.go(LessonScreen(self.app, self.index))


def status_lines():
    st = store.Store()
    have = st.progress['lessons']
    done = sum(1 for les in course.LESSONS if les.id in have and (have[les.id]['seals'] >= 1 or not les.goal))
    out = [f'lesson {done + 1} of {len(course.LESSONS)}' if done < len(course.LESSONS) else 'the course is done']
    tests = [r for r in st.history() if r.get('k') in ('test', 'check')]
    if tests:
        out.append(f'last test {tests[-1]["w"]:.0f} wpm, {tests[-1]["a"]:.0f} %')
    return out


HELP = """kawa-typing — touch typing, finger by finger, to 100 words a minute and past it: a terminal program, the keyboard
and the hands drawn in the terminal itself (Super+U, learning → typing).

    kawa-typing            the course: it goes on where you stopped
    kawa-typing FILE       types a file of your own (code, notes, anything)
    kawa-typing --course   the lessons, as a table

In a lesson: Esc leaves it (it is kept), Ctrl+K quiets the next key's light, Backspace corrects (from the sentences on).
On the tabs: Tab or the arrows change tab, Enter goes, Esc goes back or closes.
Everything it keeps: ~/.local/state/fedokawaii/typing. The method and its sources: docs/learn/typing/."""


def main(argv):
    args = {}
    path = None
    it = iter(argv)
    for a in it:
        if a in ('-h', '--help'):
            print(HELP)
            return 0
        if a == '--status':       # (for Super+U's pane: where you are, in a line or two)
            for line in status_lines():
                print(line)
            return 0
        if a == '--course':
            for i, les in enumerate(course.LESSONS):
                print(f'{i + 1:3}  {course.STAGE_NAMES[les.stage]:16} {les.kind:10} {les.low:3} {les.goal:3}  {les.title}')
            return 0
        if a == '--trace':                    # (for its tests: the run under way, kept in this file)
            args['trace'] = next(it, '')
        elif a == '--seed' or a == '--eye':   # (for its tests: the words drawn; the eye's opening, in seconds)
            try:
                args[a[2:]] = int(next(it))
            except (StopIteration, ValueError):
                print(f'kawa-typing: {a} N', file=sys.stderr)
                return 2
        elif a == '--lesson':
            try:
                args['lesson'] = course.BY_ID[next(it)]
            except (StopIteration, KeyError):
                print('kawa-typing: --lesson ID (kawa-typing --course lists them, ids in course.py)', file=sys.stderr)
                return 2
        elif a.startswith('-'):
            print(f'kawa-typing: no option {a}', file=sys.stderr)
            return 2
        else:
            path = a
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        print('kawa-typing: a terminal program: run it in one', file=sys.stderr)
        return 1
    if not os.environ.get('TERM', '').startswith('foot'):
        print('kawa-typing: it draws in the desktop\'s terminal (foot): the keyboard and the words are pictures', file=sys.stderr)
        return 1
    tty = term.Term()
    app = App(tty, args)

    def leave(*_):     # (the window closed, or asked to end: what is kept is kept)
        app.alive = False
        tty.poke()
    signal.signal(signal.SIGTERM, leave)
    signal.signal(signal.SIGHUP, leave)
    for sig in (signal.SIGINT, signal.SIGQUIT, signal.SIGTSTP):   # (those keys are keys here, even as raw mode comes and goes)
        signal.signal(sig, signal.SIG_IGN)
    text = None
    if path:
        try:
            with open(path, encoding='utf-8', errors='replace') as f:
                text = f.read(20000)
        except OSError as e:
            print(f'kawa-typing: {path}: {e.strerror}', file=sys.stderr)
            return 1
        text = ''.join(c for c in text.replace('\r\n', '\n').replace('\t', '    ') if c == '\n' or (c.isascii() and c.isprintable())).strip()
        if not text:
            print(f'kawa-typing: {path}: nothing in it to type', file=sys.stderr)
            return 1
    if not app.store.first_only():
        print('kawa-typing: it is open in another window', file=sys.stderr)
        time.sleep(2)      # (long enough to be read, in a window of its own)
        return 1
    rc = 0
    try:
        if path:
            first = LessonScreen.free(app, 'file', text, title=os.path.basename(path))
        elif 'lesson' in args:
            first = open_lesson(app, args['lesson'])
        else:
            first = Home(app)
        app.run(first)
        app.store.save()
    except EOFError:
        app.store.save()
    except Exception:   # (the terminal goes back as it was, whatever happened; what happened goes to a file)
        tty.stop()
        try:
            with open(os.path.join(app.store.dir, 'crash.log'), 'a') as f:
                f.write(time.strftime('%F %T\n') + traceback.format_exc() + '\n')
        except OSError:
            pass
        print('kawa-typing: it broke: the details are in ' + os.path.join(app.store.dir, 'crash.log'), file=sys.stderr)
        rc = 1
    finally:
        tty.stop()
    return rc
