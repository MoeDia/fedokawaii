---
id: py-expenses
title: checkpoint: an expense tracker
part: python
chapter: 33
minutes: 40
needs: [py-modules-mistakes]
optional: no
---

## 33.7 checkpoint project — an expense tracker

Level 3 in one program: files (a CSV that survives between runs), errors (bad input, a missing
file), and a module of functions kept apart from the part that talks to the person.

`ledger.py`:

```python
"""Expenses kept in a CSV file: date, category, amount."""
import csv
from pathlib import Path

FIELDS = ["date", "category", "amount"]

def load(path):
    p = Path(path)
    if not p.exists():
        return []
    with open(p, encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    for r in rows:
        r["amount"] = float(r["amount"])
    return rows

def save(path, rows):
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        w.writerows(rows)

def parse(line):
    """'2026-10-21 food 32.5' -> a row; ValueError if it is not one."""
    parts = line.split()
    if len(parts) != 3:
        raise ValueError("write: DATE CATEGORY AMOUNT")
    date, category, amount = parts
    return {"date": date, "category": category, "amount": float(amount)}

def totals(rows):
    out = {}
    for r in rows:
        out[r["category"]] = out.get(r["category"], 0) + r["amount"]
    return out
```

`track.py`:

```python
from ledger import load, parse, save, totals

PATH = "expenses.csv"
rows = load(PATH)
while True:
    line = input("expense (or 'report', 'quit')? ").strip()
    if line == "quit":
        break
    if line == "report":
        for cat, amount in sorted(totals(rows).items()):
            print(f"  {cat:<10}{amount:>8.2f}")
        continue
    try:
        rows.append(parse(line))
    except ValueError as e:
        print("  ", e)
        continue
    save(PATH, rows)
    print(f"  saved ({len(rows)} expenses)")
```

```text
$ uv run track.py
expense (or 'report', 'quit')? 2026-10-21 food 32.5
  saved (1 expenses)
expense (or 'report', 'quit')? 2026-10-21 taxi 18
  saved (2 expenses)
expense (or 'report', 'quit')? lunch
   write: DATE CATEGORY AMOUNT
expense (or 'report', 'quit')? 2026-10-22 food 12.25
  saved (3 expenses)
expense (or 'report', 'quit')? report
  food         44.75
  taxi         18.00
expense (or 'report', 'quit')? quit
```

```text
$ cat expenses.csv
date,category,amount
2026-10-21,food,32.5
2026-10-21,taxi,18.0
2026-10-22,food,12.25
```

*(run it again: the three expenses are loaded from the file, and the next one is added to them)*

> **Checkpoint.** Add (1) `report MONTH` (`report 2026-10`) to total one month only; (2) a
> refusal of negative amounts and of dates not shaped `YYYY-MM-DD` (`datetime.date.fromisoformat`
> raises `ValueError` for you); (3) an `assert` for `parse` and `totals` in a `__main__` block of
> `ledger.py`. Level 3 done.
