---
id: py-results
title: writing results; common mistakes
part: python
chapter: 40
minutes: 3
needs: [py-dates]
optional: no
---

## 40.7 writing results

Results go back out as CSV (for a spreadsheet) or JSON (for a program):

```python
import csv, json
from collections import defaultdict
from load import load

rows, _ = load("sales.csv")
by_city = defaultdict(float)
for r in rows:
    by_city[r["city"]] += r["amount"]
with open("by_city.csv", "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f)
    w.writerow(["city", "total"])
    w.writerows(sorted(by_city.items()))
print(open("by_city.csv", encoding="utf-8").read(), end="")
print(json.dumps(rows[0], default=str))
```

*You should see:*

```text
city,total
Abu Dhabi,43.5
Dubai,66.5
Sharjah,36.0
{"date": "2026-10-01", "city": "Sharjah", "product": "tea", "amount": 12.5}
```

*(`default=str` tells `json` to write a `date` — which JSON has no type for — as its text)*

## 40.8 common mistakes

**1. Forgetting to clean keys.** `"Dubai"`, `"dubai"` and `" Dubai"` are three different keys
until you `strip().title()` them — three cities in your report instead of one.

**2. Dropping bad rows silently.** Count and show them: a report that quietly ignored half the
file is worse than one that crashed.

**3. Summing floats for money** and printing all the digits. Round when you *show*
(`:.2f`); or count in fils as ints.
