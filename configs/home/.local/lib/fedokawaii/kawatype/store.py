"""store.py — what is kept between runs, in ~/.local/state/fedokawaii/typing:

    progress.json   the lessons' seals, your first speed, today's minutes, the choices made
    keys.json       each key's and pair's smoothed time and errors (the adaptive lessons read this)
    history.jsonl   one line for every run finished
    resume.json     the run under way, written as it goes: a kill or a reboot costs at most a word

A file that cannot be read (cut short, written by something else) is set aside as NAME.bad and the app goes
on without it: never a traceback, never a refusal to start. A disk that cannot be written is said once.
"""
import fcntl
import json
import math
import os
import time

ALPHA = 0.1        # the smoothing of a key's time (keybr's)


def state_dir():
    base = os.environ.get('XDG_STATE_HOME') or os.path.expanduser('~/.local/state')
    return os.path.join(base, 'fedokawaii', 'typing')


def _number(v, default=0.0):
    return v if isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v) else default


class Store:
    def __init__(self, where=None):
        self.dir = where or state_dir()
        self.failed = False            # (a write failed: the home screen says so)
        self.lock = None
        try:
            os.makedirs(self.dir, exist_ok=True)
        except OSError:
            self.failed = True
        self.progress = self._progress(self._load('progress.json'))
        self.keys = self._keys(self._load('keys.json'))

    def first_only(self):
        """False when another window has the course open (two would overwrite each other)"""
        try:
            self.lock = open(os.path.join(self.dir, 'lock'), 'w')
            fcntl.flock(self.lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return False
        except OSError:             # (a home that takes nothing: nothing to protect)
            pass
        return True

    # ── reading ──────────────────────────────────────────────────────────────
    def _path(self, name):
        return os.path.join(self.dir, name)

    def _set_aside(self, name):
        try:
            os.replace(self._path(name), self._path(name + '.bad'))
        except OSError:
            pass

    def _load(self, name):
        try:
            with open(self._path(name), encoding='utf-8') as f:
                data = json.load(f)
            if isinstance(data, dict):
                return data
        except FileNotFoundError:
            return {}
        except (OSError, ValueError, RecursionError):
            pass
        self._set_aside(name)
        return {}

    @staticmethod
    def _progress(d):
        """what was read, every value of the kind it must be"""
        out = {'lessons': {}, 'baseline': None, 'quiet': False, 'crossed': False, 'mark': 0, 'day': {'date': '', 'seconds': 0.0, 'warm': False, 'test': False}}
        for k, v in (d.get('lessons') or {}).items() if isinstance(d.get('lessons'), dict) else ():
            if isinstance(k, str) and isinstance(v, dict):
                out['lessons'][k] = {'seals': int(_number(v.get('seals'))) % 7, 'best': _number(v.get('best')),
                                     'tries': int(_number(v.get('tries')))}
        b = d.get('baseline')
        out['baseline'] = b if isinstance(b, (int, float)) and not isinstance(b, bool) and math.isfinite(b) else None
        out['quiet'] = d.get('quiet') is True
        out['crossed'] = d.get('crossed') is True
        out['mark'] = int(_number(d.get('mark')))
        day = d.get('day')
        if isinstance(day, dict) and isinstance(day.get('date'), str):
            out['day'] = {'date': day['date'], 'seconds': _number(day.get('seconds')), 'warm': day.get('warm') is True, 'test': day.get('test') is True}
        return out

    @staticmethod
    def _keys(d):
        out = {'keys': {}, 'pairs': {}}
        for part in out:
            src = d.get(part)
            if not isinstance(src, dict):
                continue
            for k, v in src.items():
                if isinstance(k, str) and isinstance(v, list) and len(v) == 4 and all(isinstance(x, (int, float)) for x in v):
                    out[part][k] = [_number(x) for x in v]
        return out

    # ── writing ──────────────────────────────────────────────────────────────
    def _write(self, name, text, sync=False):
        tmp = self._path(name + '.tmp')
        try:
            with open(tmp, 'w', encoding='utf-8') as f:
                f.write(text)
                if sync:
                    f.flush()
                    os.fsync(f.fileno())
            os.replace(tmp, self._path(name))
            self.failed = False
        except OSError:
            self.failed = True
            try:
                os.unlink(tmp)
            except OSError:
                pass

    def save(self):
        self._write('progress.json', json.dumps(self.progress, separators=(',', ':')), sync=True)
        self._write('keys.json', json.dumps(self.keys, separators=(',', ':')), sync=True)

    def save_resume(self, data):
        self._write('resume.json', json.dumps(data, separators=(',', ':')))

    def load_resume(self):
        return self._load('resume.json')

    def clear_resume(self):
        try:
            os.unlink(self._path('resume.json'))
        except OSError:
            pass

    def append_history(self, rec):
        try:
            with open(self._path('history.jsonl'), 'a', encoding='utf-8') as f:
                f.write(json.dumps(rec, separators=(',', ':')) + '\n')
        except OSError:
            self.failed = True

    def history(self):
        """the runs finished, oldest first; a line that cannot be read is passed over"""
        out = []
        try:
            with open(self._path('history.jsonl'), encoding='utf-8') as f:
                for line in f:
                    try:
                        r = json.loads(line)
                    except ValueError:
                        continue
                    if (isinstance(r, dict) and isinstance(r.get('k'), str)
                            and all(isinstance(r.get(k), (int, float)) and math.isfinite(r[k]) for k in ('d', 'w', 'a'))
                            and 0 <= r['w'] < 1000 and 0 < r['d'] < 1e11):
                        for k in ('s', 'o'):
                            if not (isinstance(r.get(k), (int, float)) and math.isfinite(r[k])):
                                r.pop(k, None)
                        out.append(r)
        except (OSError, UnicodeDecodeError):
            pass
        return out

    # ── what a run leaves behind ─────────────────────────────────────────────
    def learn(self, samples):
        """every key's and pair's smoothed time and errors, from a run's presses"""
        keys, pairs = self.keys['keys'], self.keys['pairs']
        prev = None
        for ch, ms, ok in samples:
            k = keys.setdefault(ch, [0, 0, 0.0, 0.0])     # presses, errors, smoothed ms, best smoothed ms
            k[0] += 1
            k[1] += not ok
            if ms is not None and ok:
                k[2] = ms if not k[2] else k[2] + ALPHA * (ms - k[2])
                k[3] = k[2] if not k[3] else min(k[3], k[2])
                if prev and ch not in ' \n' and prev not in ' \n':
                    p = pairs.setdefault(prev + ch, [0, 0, 0.0, 0.0])
                    p[0] += 1
                    p[2] = ms if not p[2] else p[2] + ALPHA * (ms - p[2])
            prev = ch if ok else None
        if len(pairs) > 600:                 # (the pairs not typed for long go first)
            for name, _ in sorted(pairs.items(), key=lambda kv: kv[1][0])[:len(pairs) - 500]:
                del pairs[name]

    def today(self):
        return time.strftime('%Y-%m-%d')

    def day(self):
        """today's minutes and what is done of its plan; a new day starts afresh"""
        day = self.progress['day']
        if day.get('date') != self.today():
            day.update(date=self.today(), seconds=0.0, warm=False, test=False)
        return day

    def add_time(self, seconds):
        self.day()['seconds'] += max(seconds, 0.0)

    def minutes_today(self):
        return self.day()['seconds'] / 60
