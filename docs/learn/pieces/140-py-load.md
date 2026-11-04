---
id: py-load
title: the data: load and clean
part: python
chapter: 40
minutes: 6
needs: [py-cli-practice]
optional: no
---

> **In this chapter**
>
> - load, clean, group and summarise a table with nothing but Python itself
> - `statistics`, `collections`, `datetime`: the analyst's standard tools
> - a text chart in the terminal

Level 6 turns everything you know toward data and, from chapter 43, machine learning. Before any
library, do the whole job once by hand: it is the only way to understand what pandas or NumPy
then do for you, and many small jobs need nothing more.

## 40.1 the data

A small CSV of sales — the kind of file a spreadsheet exports. Note the problems real data
has: a blank amount, a typo'd city, an extra space.

`sales.csv`:

```text
date,city,product,amount
2026-10-01,Sharjah,tea,12.5
2026-10-01,Dubai,rice,7.25
2026-10-02,Sharjah,rice,14.5
2026-10-02,dubai,tea,25
2026-10-03,Sharjah,tea,
2026-10-03,Abu Dhabi,milk,6
2026-10-04, Dubai,tea,12.5
2026-10-04,Sharjah,milk,9
2026-10-05,Abu Dhabi,tea,37.5
2026-10-05,Dubai,rice,21.75
```

## 40.2 load and clean

Clean as you load: trim spaces, fix the case, change types, and set aside rows that cannot be
used — counting them, never silently dropping them:

`load.py`:

```python
import csv
from datetime import date

def load(path):
    good, bad = [], []
    with open(path, encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            try:
                good.append({
                    "date": date.fromisoformat(row["date"].strip()),
                    "city": row["city"].strip().title(),
                    "product": row["product"].strip().lower(),
                    "amount": float(row["amount"]),
                })
            except ValueError:
                bad.append(row)
    return good, bad

if __name__ == "__main__":
    rows, bad = load("sales.csv")
    print(len(rows), "rows,", len(bad), "set aside:", bad)
    print(rows[0])
```

```text
$ uv run load.py
9 rows, 1 set aside: [{'date': '2026-10-03', 'city': 'Sharjah', 'product': 'tea', 'amount': ''}]
{'date': datetime.date(2026, 10, 1), 'city': 'Sharjah', 'product': 'tea', 'amount': 12.5}
```
