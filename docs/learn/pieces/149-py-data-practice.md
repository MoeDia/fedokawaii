---
id: py-data-practice
title: practice
part: python
chapter: 40
minutes: 12
needs: [py-results]
optional: no
---

**40.1 ★ The biggest sale.** Print the row with the largest amount (`max` with `key=`).

<!-- solution 40.1 -->
```python
from load import load

rows, _ = load("sales.csv")
print(max(rows, key=lambda r: r["amount"]))
```

*You should see:*

```text
{'date': datetime.date(2026, 10, 5), 'city': 'Abu Dhabi', 'product': 'tea', 'amount': 37.5}
```
<!-- /solution -->

**40.2 ★ Sharjah only.** Total the Sharjah sales with a generator expression in `sum`.

<!-- solution 40.2 -->
```python
from load import load

rows, _ = load("sales.csv")
print(sum(r["amount"] for r in rows if r["city"] == "Sharjah"))
```

*You should see:*

```text
36.0
```
<!-- /solution -->

**40.3 ★★ Average per product.** The mean amount per product, rounded to 2 places.

<!-- solution 40.3 -->
```python
from collections import defaultdict
from statistics import mean
from load import load

rows, _ = load("sales.csv")
g = defaultdict(list)
for r in rows:
    g[r["product"]].append(r["amount"])
print({p: round(mean(v), 2) for p, v in sorted(g.items())})
```

*You should see:*

```text
{'milk': 7.5, 'rice': 14.5, 'tea': 21.88}
```
<!-- /solution -->

**40.4 ★★ Share of total.** Each city's share of all sales, as a percentage with one decimal; they should add to 100.

<!-- solution 40.4 -->
```python
from collections import Counter
from load import load

rows, _ = load("sales.csv")
c = Counter()
for r in rows:
    c[r["city"]] += r["amount"]
total = sum(c.values())
shares = {k: round(v / total * 100, 1) for k, v in c.items()}
print(shares, round(sum(shares.values())))
```

*You should see:*

```text
{'Sharjah': 24.7, 'Dubai': 45.5, 'Abu Dhabi': 29.8} 100
```
<!-- /solution -->
