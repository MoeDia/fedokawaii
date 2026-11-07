"""lib/review.py — the daily review (sb03, inbox S19/S20): retrieval practice, spaced out.

A card is one question of a lesson's quiz (and its remember warm-up): id "LESSON#N". A card is born on
the day its lesson is done. It is due 1, 3, 7 and then every 14 days after its last right answer; a wrong
answer brings it back the next day, one step down. A concept (a lesson) is learned after 3 right answers
on different days, new before its lesson is done, practising between.

The record: ~/.local/state/fedokawaii/reviews, a line YYYY-MM-DD<TAB>CARD<TAB>right|wrong, only ever
added to; a line it cannot read is passed over. Nothing here nags: a day missed costs nothing, the streak
is only a number in a corner of the page.

Run alone, `python3 lib/review.py FOLDER RECORD TODAY` prints the day's cards (a test's and a page's way in).
"""
import datetime
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lessons  # noqa: E402

STEPS = (1, 3, 7, 14)   # days after the last right answer; the last repeats
LEARNED = 3             # right answers on different days
SESSION = 5             # cards in a review: five minutes
RANKS = ((0, "white belt"), (10, "yellow belt"), (40, "orange belt"), (100, "green belt"),
         (200, "blue belt"), (400, "brown belt"), (800, "black belt"))
CARD = re.compile(lessons.ID.pattern + r"#[1-9]\d*")


def day(iso):
    return datetime.date.fromisoformat(iso)


def cards(course):
    """{card id: (question, answer, lesson id)} for every lesson of the course"""
    out = {}
    for lid, le in course["lessons"].items():
        for n, (q, a) in enumerate(le.get("remember", []) + le.get("quiz", []), 1):
            out[f"{lid}#{n}"] = (q, a, lid)
    return out


def read_reviews(path):
    """[(date, card, True for right)], in file order; unreadable lines passed over"""
    rows = []
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for row in f:
                c = row.rstrip("\n").split("\t")
                if len(c) == 3 and lessons.DATE.fullmatch(c[0]) and CARD.fullmatch(c[1]) and c[2] in ("right", "wrong"):
                    rows.append((c[0], c[1], c[2] == "right"))
    except OSError:
        pass
    return rows


def add_review(path, card, right, date):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "a", encoding="utf-8") as f:
        f.write(f"{date}\t{card}\t{'right' if right else 'wrong'}\n")


def states(deck, done, reviews):
    """{card: {"step", "last", "due"}} for the cards whose lesson is done; step 0 is just born"""
    out = {}
    for card, (_, _, lid) in deck.items():
        if lid in done:
            out[card] = {"step": 0, "last": done[lid]}
    for date, card, right in sorted(reviews):
        s = out.get(card)
        if s is None or date < s["last"]:
            continue
        if right and date > s["last"]:
            s["step"] += 1
        elif not right:
            s["step"] = max(0, s["step"] - 1)
            s["last"] = date
            s["wrong"] = True
            continue
        s["last"] = date
        s.pop("wrong", None)
    for s in out.values():
        gap = 1 if s.get("wrong") else STEPS[min(s["step"], len(STEPS) - 1)]
        s["due"] = (day(s["last"]) + datetime.timedelta(days=gap)).isoformat()
    return out


def due(deck, done, reviews, today, limit=SESSION):
    """the day's review: due cards, the longest overdue first, taken in turn from different lessons
    (interleaving), at most limit; a card answered today waits for another day"""
    st = states(deck, done, reviews)
    answered = {c for d, c, _ in reviews if d == today}
    late = sorted((s["due"], card) for card, s in st.items() if s["due"] <= today and card not in answered)
    by_lesson = {}
    for _, card in late:
        by_lesson.setdefault(deck[card][2], []).append(card)
    pick = []
    while len(pick) < limit and any(by_lesson.values()):
        for lid in list(by_lesson):
            if by_lesson[lid] and len(pick) < limit:
                pick.append(by_lesson[lid].pop(0))
    return pick


def concepts(deck, done, reviews):
    """{lesson id: "new" | "practising" | "learned"}: learned after LEARNED right answers on different days"""
    days = {}
    for date, card, right in reviews:
        if right and card in deck:
            days.setdefault(deck[card][2], set()).add(date)
    out = {}
    for lid in {v[2] for v in deck.values()}:
        out[lid] = "new" if lid not in done else "learned" if len(days.get(lid, ())) >= LEARNED else "practising"
    return out


def streak(done, reviews, today):
    """days in a row with any lesson or review, up to today (or up to yesterday: today is not lost yet)"""
    active = set(done.values()) | {d for d, _, _ in reviews}
    d = day(today)
    if d.isoformat() not in active:
        d -= datetime.timedelta(days=1)
    n = 0
    while d.isoformat() in active:
        n += 1
        d -= datetime.timedelta(days=1)
    return n


def rank(done, reviews):
    """(belt name, points): a lesson 5 points, a right answer 1; quiet, it only ever grows"""
    points = 5 * len(done) + sum(1 for _, _, r in reviews if r)
    return [name for floor, name in RANKS if points >= floor][-1], points


def look_back(done, reviews, today):
    """the week ending today: {"lessons", "right", "wrong", "days"}"""
    first = (day(today) - datetime.timedelta(days=6)).isoformat()
    week = [r for r in reviews if first <= r[0] <= today]
    mine = {d for d in done.values() if first <= d <= today} | {r[0] for r in week}
    return {"lessons": sum(1 for d in done.values() if first <= d <= today),
            "right": sum(1 for r in week if r[2]), "wrong": sum(1 for r in week if not r[2]), "days": len(mine)}


if __name__ == "__main__":
    folder, record, today = sys.argv[1:4]
    deck = cards(lessons.load(folder))
    done = lessons.read_record(os.path.join(os.path.dirname(record), "days"))
    for card in due(deck, done, read_reviews(record), today):
        print(card, deck[card][0], sep="\t")
