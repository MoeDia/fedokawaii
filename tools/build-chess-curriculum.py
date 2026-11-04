#!/usr/bin/env python3
"""tools/build-chess-curriculum.py — docs/learn/chess/curriculum.md, written from the syllabus the app itself reads
(syllabus.py) and the lessons' heads (lessons.txt), so the two cannot differ: the 52 weeks, 365 days, 730 games.

  python3 -I -B tools/build-chess-curriculum.py [OUT]
"""
import pathlib
import re
import sys

sys.dont_write_bytecode = True
ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "configs/home/.local/lib/fedokawaii/kawa-chess"))
import syllabus as SY  # noqa: E402


def lessons():
    text = (ROOT / "configs/home/.local/share/fedokawaii/chess/lessons.txt").read_text(encoding="utf-8")
    out = {}
    for block in re.split(r"(?m)^=== ", text)[1:]:
        slug, _, body = block.partition("\n")
        meta = dict(re.findall(r"(?m)^(title|source|minutes): (.+)$", body.split("\n\n", 1)[0]))
        out[slug.strip()] = meta
    return out


def start_word(g):
    if "pos" in g:
        return g["pos"]
    if "line" in g:
        return "after " + SY.LINES[g["line"]]
    if "bank" in g:
        return "puzzle bank: " + g["bank"]
    if "odds" in g:
        return "they have no " + {"q": "queen", "r": "rook", "n": "knight"}[g["odds"]]
    return "the start"


def main(argv):
    out = pathlib.Path(argv[1]) if len(argv) > 1 else ROOT / "docs/learn/chess/curriculum.md"
    meta = lessons()
    themes = dict(SY.THEME_NAMES)
    w = out.write_text
    lines = ["# The year: 52 weeks, 365 days, 730 games",
             "",
             "Written by tools/build-chess-curriculum.py from what kawa-chess itself reads. Why it is built this way, and what the",
             "evidence does and does not support: `.claude/notes/chess-research.md`; sources: SOURCES.md; the levels: ladder.md.",
             "",
             "A day, in order: its lesson (if it has one), the deep game, its review, ten minutes of puzzles, the light game, its review.",
             "The week's last day adds a report; every fourth week adds an exam: twenty puzzles, sixteen to pass (Steps Method's 80 %),",
             "tried again on another day if not. A game's level is your own plus its offset, kept inside the week's band.",
             "Levels are this program's ladder, measured engine against engine; they are not chess.com ratings.",
             ""]
    no = 0
    for i, wk in enumerate(SY.WEEKS, 1):
        first = (i - 1) * 7 + 1
        last = first + 6 if i < 52 else 365
        lines += [f"## Week {i}: {wk['title']} (days {first}–{last})", "",
                  f"Level band {wk['band'][0]}–{wk['band'][1]}."]
        if wk.get("milestone"):
            m = wk["milestone"]
            lines[-1] += f" Milestone by its end: level {m['level']}, puzzle rating {m['puzzle']}."
        if wk.get("exam"):
            names = ", ".join(themes.get(t, t or "mixed") for t in wk["exam"]["themes"])
            lines[-1] += f" Exam: {names}, around {wk['exam']['rating']}."
        lines += ["", "| day | lesson | its source | puzzles |", "|---|---|---|---|"]
        for d in range(first, last + 1):
            dow = (d - 1) % 7 if d < 365 else 7
            slug = wk["lessons"][dow] if dow < len(wk.get("lessons", [])) else None
            m = meta.get(slug, {}) if slug else {}
            th = wk["themes"][dow % len(wk["themes"])]
            lines.append(f"| {d} | {m.get('title', '—')} | {m.get('source', '—')} | {themes.get(th, th or 'mixed')} |")
        lines += ["", "| game | kind | start | you | clock | goal | measured by |", "|---|---|---|---|---|---|---|"]
        for d in range(first, last + 1):
            for k in range(2):
                no += 1
                g = wk["games"][(no - 1) % 14]
                kind = "light" if g.get("light") else "deep"
                you = {0: "white", 1: "black"}.get(SY.POS[g["pos"]][1] if "pos" in g else g.get("you"), "by turns")
                clock = g.get("clock")
                clock = f"{clock[0]}+{clock[1]}" if clock else "as the stage"
                lines.append(f"| {no} | {kind} | {start_word(g)} | {you} | {clock} | {g['goal']} | {g.get('check', '—')} |")
        lines.append("")
    w("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{no} games, {sum(1 for x in meta)} lessons", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
