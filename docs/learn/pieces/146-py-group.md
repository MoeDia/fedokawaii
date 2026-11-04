---
id: py-group
title: group by
part: python
chapter: 40
minutes: 5
needs: [py-summaries]
optional: no
---

## 40.4 group by

The analyst's most common question — *the total per city* — is chapter 30's grouping, with a
`defaultdict`:

```python
from collections import defaultdict
from load import load

rows, _ = load("sales.csv")
by_city = defaultdict(float)
by_product = defaultdict(list)
for r in rows:
    by_city[r["city"]] += r["amount"]
    by_product[r["product"]].append(r["amount"])

for city, total in sorted(by_city.items(), key=lambda kv: -kv[1]):
    print(f"{city:<10}{total:>8.2f}")
print({p: len(v) for p, v in by_product.items()})
```

*You should see:*

```text
Dubai        66.50
Abu Dhabi    43.50
Sharjah      36.00
{'tea': 4, 'rice': 3, 'milk': 2}
```

Two keys at once — a tuple as the key gives a pivot table:

```python
from collections import defaultdict
from load import load

rows, _ = load("sales.csv")
pivot = defaultdict(float)
for r in rows:
    pivot[(r["city"], r["product"])] += r["amount"]
cities = sorted({c for c, _ in pivot})
products = sorted({p for _, p in pivot})
print(f"{'':<10}" + "".join(f"{p:>8}" for p in products))
for c in cities:
    print(f"{c:<10}" + "".join(f"{pivot.get((c, p), 0):>8.2f}" for p in products))
```

*You should see:*

```text
              milk    rice     tea
Abu Dhabi     6.00    0.00   37.50
Dubai         0.00   29.00   37.50
Sharjah       9.00   14.50   12.50
```
