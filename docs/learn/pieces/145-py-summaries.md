---
id: py-summaries
title: summaries: statistics
part: python
chapter: 40
minutes: 3
needs: [py-load]
optional: no
---

## 40.3 summaries: statistics

```python
import statistics as st
from load import load

rows, _ = load("sales.csv")
amounts = [r["amount"] for r in rows]
print("count ", len(amounts))
print("total ", sum(amounts))
print("mean  ", round(st.mean(amounts), 2))
print("median", st.median(amounts))
print("stdev ", round(st.stdev(amounts), 2))
print("min/max", min(amounts), max(amounts))
print("quartiles", st.quantiles(amounts, n=4))
```

*You should see:*

```text
count  9
total  146.0
mean   16.22
median 12.5
stdev  10.17
min/max 6.0 37.5
quartiles [8.125, 12.5, 23.375]
```

> **Word — mean, median.** The *mean* is the sum divided by the count; the *median* the middle
> value once sorted. One huge sale pulls the mean up but barely moves the median — compare both.
