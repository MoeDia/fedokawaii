---
id: py-dates
title: dates, a chart in the terminal
part: python
chapter: 40
minutes: 4
needs: [py-group]
optional: no
---

## 40.5 dates

`datetime` reads, compares and steps dates; group by week or weekday with its methods:

```python
from collections import Counter
from datetime import date, timedelta
from load import load

rows, _ = load("sales.csv")
print(rows[0]["date"].strftime("%A %d %B %Y"))
print(Counter(r["date"].strftime("%a") for r in rows))
first = min(r["date"] for r in rows)
last = max(r["date"] for r in rows)
print((last - first).days + 1, "days;", "a week later:", first + timedelta(weeks=1))
```

*You should see:*

```text
Thursday 01 October 2026
Counter({'Thu': 2, 'Fri': 2, 'Sun': 2, 'Mon': 2, 'Sat': 1})
5 days; a week later: 2026-10-08
```

## 40.6 a chart in the terminal

No library needed for a quick look: a bar of `█` per value, scaled to the largest:

```python
from collections import defaultdict
from load import load

rows, _ = load("sales.csv")
per_day = defaultdict(float)
for r in rows:
    per_day[r["date"]] += r["amount"]
top = max(per_day.values())
for day, total in sorted(per_day.items()):
    bar = "█" * round(total / top * 30)
    print(f"{day:%m-%d} {bar} {total:.2f}")
```

*You should see:*

```text
10-01 ██████████ 19.75
10-02 ████████████████████ 39.50
10-03 ███ 6.00
10-04 ███████████ 21.50
10-05 ██████████████████████████████ 59.25
```
