"""metrics.py — one run through a text: every press and its verdict, and the measures, exactly as
docs/learn/typing/curriculum.md defines them (net and raw wpm, accuracy, consistency, rollover).

    block   a wrong key does not move on (the first lessons)
    flow    a wrong letter stands, Backspace takes it back; the error still counts (sentences on, every test)
"""
import math

PAUSE = 5.0      # seconds without a key: the clock stops (Dhakal 2018 drops such gaps too)


def kogasa(cov):
    """Monkeytype's consistency: 100 × (1 − tanh(c + c³/3 + c⁵/5)), c = σ ÷ mean"""
    return 100 * (1 - math.tanh(cov + cov ** 3 / 3 + cov ** 5 / 5))


class Run:
    def __init__(self, text, flow=False, limit=None):
        self.text = text
        self.flow = flow
        self.limit = limit         # seconds, for a timed test
        self.pos = 0
        self.got = {}              # position → what was typed there (flow: a wrong one stands)
        self.correct = self.wrong = 0
        self.first = self.last = None
        self.paused = 0.0          # seconds of pauses taken out of the clock
        self.hold = False          # the clock stopped: the next gap does not count
        self.stamps = []           # the active clock at every press
        self.rolled = 0
        self.releases = False      # the terminal reports releases: rollover is known
        self.samples = []          # (char, ms since the last press or None, right)
        self.slips = {}            # expected char → wrong presses on it
        self.shift_slips = 0       # capitals made with the shift of the same hand
        self.counted = (0, 0)      # (standing()'s memo: up to which position, how many stood correct)

    # ── the clock ────────────────────────────────────────────────────────────
    def _tick(self, t):
        gap = None
        if self.first is None:
            self.first = t
        else:
            gap = t - self.last
            if gap > PAUSE or self.hold:
                self.paused += gap
                gap = None
        self.hold = False
        self.last = t
        return gap

    def pause(self):
        """the window lost focus: the clock waits for the next key"""
        self.hold = True

    def active(self, now=None):
        """seconds of typing so far"""
        if self.first is None:
            return 0.0
        end = self.last if now is None or self.hold else now
        if end - self.last > PAUSE:
            end = self.last
        return max(end - self.first - self.paused, 0.0)

    def expired(self, now):
        return self.limit is not None and self.first is not None and self.active(now) >= self.limit

    @property
    def done(self):
        return self.pos >= len(self.text)

    # ── a press ──────────────────────────────────────────────────────────────
    def press(self, ch, t, rolled=False):
        """a character typed: True if it was the one wanted"""
        if self.done:
            return True
        gap = self._tick(t)
        self.stamps.append(self.active())
        self.rolled += rolled
        want = self.text[self.pos]
        ok = ch == want
        self.samples.append((want, None if gap is None else round(gap * 1000), ok))
        if ok:
            self.correct += 1
        else:
            self.wrong += 1
            self.slips[want] = self.slips.get(want, 0) + 1
        if self.flow or ok:
            self.got[self.pos] = ch
            self.pos += 1
        return ok

    def backspace(self):
        """flow: the last letter taken back (it stays counted)"""
        if self.flow and self.pos > 0:
            self.pos -= 1
            self.got.pop(self.pos, None)
            if self.pos < self.counted[0]:
                self.counted = (0, 0)
            return True
        return False

    def skip_indent(self):
        """code: the spaces a line starts with are the editor's work"""
        moved = 0
        while (self.pos < len(self.text) and self.text[self.pos] == ' '
               and (self.pos == 0 or self.text[self.pos - 1] == '\n')) or (
               moved and self.pos < len(self.text) and self.text[self.pos] == ' '):
            self.got[self.pos] = ' '
            self.pos += 1
            moved += 1
        return moved

    # ── the measures ─────────────────────────────────────────────────────────
    def standing(self):
        """the characters standing correct: spaces included; when flowing, those of whole correct words,
        and the correct start of the last one (as Monkeytype counts them)"""
        if not self.flow:
            return self.pos
        i, count = self.counted              # (the words already counted stay counted: asked at every key)
        text, got, end = self.text, self.got, self.pos
        n = len(text)
        while i < end:
            j = i
            while j < n and text[j] not in ' \n':
                j += 1
            word_end = min(j + 1, n)         # (its space with it)
            if end < word_end:               # (the last word, not finished)
                self.counted = (i, count)
                k = i
                while k < end and got.get(k) == text[k]:
                    k += 1
                return count + k - i
            if all(got.get(k) == text[k] for k in range(i, word_end)):
                count += word_end - i
            i = word_end
        self.counted = (i, count)
        return count

    def minutes(self, now=None):
        secs = self.active(now)
        if self.limit is not None:
            secs = min(secs, self.limit)
        return secs / 60

    def net(self, now=None):
        m = self.minutes(now)
        return max(self.standing() - 1, 0) / 5 / m if m > 0 else 0.0

    def raw(self, now=None):
        m = self.minutes(now)
        return max(self.correct + self.wrong - 1, 0) / 5 / m if m > 0 else 0.0

    def accuracy(self):
        n = self.correct + self.wrong
        return self.correct / n * 100 if n else 100.0

    def consistency(self):
        """over the raw speed second by second; a run under two seconds has no such thing"""
        if not self.stamps or self.stamps[-1] < 2:
            return None
        per = [0] * (int(self.stamps[-1]) + 1)
        for s in self.stamps:
            per[int(s)] += 1
        per = per[:-1] or per                # (the last second is not whole)
        mean = sum(per) / len(per)
        if not mean:
            return 0.0
        sd = math.sqrt(sum((p - mean) ** 2 for p in per) / len(per))
        return kogasa(sd / mean)

    def rollover(self):
        """presses made while the last key was still down ÷ all presses; None where releases are not seen"""
        n = self.correct + self.wrong
        return self.rolled / n * 100 if self.releases and n else None

    # ── kept across a kill ───────────────────────────────────────────────────
    def snapshot(self):
        return {'text': self.text, 'flow': self.flow, 'limit': self.limit, 'pos': self.pos,
                'got': [self.got.get(i, '') for i in range(self.pos)], 'correct': self.correct, 'wrong': self.wrong,
                'secs': self.active(), 'rolled': self.rolled, 'releases': self.releases, 'stamps': self.stamps[-4000:],
                'slips': self.slips, 'shift': self.shift_slips}

    @classmethod
    def restored(cls, d):
        """back from a snapshot; raises what a damaged one raises (the caller starts afresh then)"""
        r = cls(d['text'], bool(d['flow']), d.get('limit'))
        if not isinstance(r.text, str) or not r.text:
            raise ValueError('no text')
        r.pos = max(0, min(int(d['pos']), len(r.text)))
        r.got = {i: str(c) for i, c in enumerate(d['got'][:r.pos])}
        r.correct, r.wrong = int(d['correct']), int(d['wrong'])
        r.rolled, r.releases = int(d.get('rolled', 0)), bool(d.get('releases'))
        r.stamps = [float(s) for s in d.get('stamps', [])]
        r.slips = {str(k): int(v) for k, v in d.get('slips', {}).items()}
        r.shift_slips = int(d.get('shift', 0))
        secs = float(d.get('secs', 0))
        if secs > 0:                         # (the clock goes on from where it stood at the next key)
            r.first, r.last, r.hold = 0.0, secs, True
        return r
