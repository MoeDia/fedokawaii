---
id: py-data-projects
title: projects
part: python
chapter: 40
minutes: 180
needs: [py-data-practice]
optional: yes
---

**40.5 ★★★ Outliers.** Flag amounts more than 1.5 × the interquartile range above the third quartile
(`statistics.quantiles`).

<!-- solution 40.5 -->
```python
import statistics as st
from load import load

rows, _ = load("sales.csv")
amounts = [r["amount"] for r in rows]
q1, _, q3 = st.quantiles(amounts, n=4)
limit = q3 + 1.5 * (q3 - q1)
print(round(limit, 2), [a for a in amounts if a > limit])
```

*You should see:*

```text
46.25 []
```
<!-- /solution -->

**40.6 ★★★ Day-on-day change.** For each day, the total and its change from the day before (`itertools.pairwise`).

<!-- solution 40.6 -->
```python
from collections import defaultdict
from itertools import pairwise
from load import load

rows, _ = load("sales.csv")
d = defaultdict(float)
for r in rows:
    d[r["date"]] += r["amount"]
days = sorted(d.items())
for (d0, t0), (d1, t1) in pairwise(days):
    print(f"{d1:%m-%d} {t1:>6.2f} {t1 - t0:+.2f}")
```

*You should see:*

```text
10-02  39.50 +19.75
10-03   6.00 -33.50
10-04  21.50 +15.50
10-05  59.25 +37.75
```
<!-- /solution -->

**40.7 ★★★★ Your own bank statement.** Export a statement from your bank as CSV (or make one), and write `spend.py` that loads and
cleans it, sets aside bad rows, totals spending per category and per month, prints a terminal bar
chart of the months, and writes `summary.json`. Test `load` and the grouping with pytest.

<!-- solution 40.7 -->
Use this chapter's pieces in order: `load` (with your bank's column names and date format —
`datetime.strptime(text, "%d/%m/%Y")` reads `21/10/2026`), a `defaultdict(float)` keyed by
`(month, category)` with `month = d.strftime("%Y-%m")`, the bar chart of 40.6, and `json.dump`
with `default=str`. Test `load` on a three-line CSV written into `tmp_path`, one row of it bad.
<!-- /solution -->
