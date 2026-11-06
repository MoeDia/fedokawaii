---
id: py-chart
title: your writing, as a chart
part: python
chapter: 42
minutes: 8
needs: [py-cli-practice]
optional: no
---

> **In this chapter**
>
> - four programs you will actually use, each with tests that run in a blink

Each project is one file and one test file, in a project of its own (`uv init`, `uv add --dev
pytest`). Watch the test file (**Space t w**) before you write the first line.

## 42.1 your writing, as a chart

How much did you write in your notes each day? The notes file has a heading per day
(`## 2026-10-16 · Fri`): count the lines under each.

```python
"""notestats — how much you wrote in your notes, day by day"""
import re
import sys
from collections import Counter
from pathlib import Path

HEADING = re.compile(r"^## (\d{4}-\d{2}-\d{2})")

def lines_per_day(text: str) -> Counter:
    """count the non-empty lines under each day's heading"""
    counts = Counter()
    day = None
    for line in text.splitlines():
        if m := HEADING.match(line):
            day = m.group(1)
        elif day and line.strip():
            counts[day] += 1
    return counts

def bar(n: int, most: int, width: int = 30) -> str:
    return "█" * max(1, round(n / most * width))

def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "notes" / "notes.md"
    counts = lines_per_day(path.read_text(encoding="utf-8"))
    if not counts:
        print("no dated notes yet")
        return
    most = max(counts.values())
    for day, n in sorted(counts.items())[-14:]:
        print(f"{day}  {n:3}  {bar(n, most)}")

if __name__ == "__main__":
    main()
```

```python
from notestats import bar, lines_per_day

NOTES = """## 2026-10-15 · Thu

buy rice
call the bank

## 2026-10-16 · Fri

- [ ] chapter 37
"""

def test_counts_lines_under_each_day():
    assert lines_per_day(NOTES) == {"2026-10-15": 2, "2026-10-16": 1}

def test_lines_before_any_heading_are_ignored():
    assert lines_per_day("hello\n## 2026-10-15 · Thu\nx\n") == {"2026-10-15": 1}

def test_bar_is_never_empty():
    assert bar(1, 100) == "█"
```

```text
$ uv run notestats.py
2026-10-15    2  ██████████████████████████████
2026-10-16    1  ███████████████
```

*(for example)* New here: a **regular expression** (`re`) finds the headings; `Counter` is a
dictionary that counts; `:=` gives a name to a value inside a condition.

**Extend it:** the weekday you write most (`datetime.date.fromisoformat(day).strftime("%A")`).
