---
id: py-csv
title: CSV: tables in text
part: python
chapter: 31
minutes: 3
needs: [py-lines]
optional: no
---

## 31.5 CSV: tables in text

A **CSV** file is a table: one row per line, values separated by commas. Spreadsheets save and
open it. The `csv` module reads it properly — quotes, commas inside values and all:

```python
import csv
from pathlib import Path

Path("people.csv").write_text("name,city,age\nSara,Sharjah,31\nOmar,Dubai,28\n", encoding="utf-8")
with open("people.csv", encoding="utf-8", newline="") as f:
    for row in csv.DictReader(f):
        print(row["name"], "lives in", row["city"], "and is", int(row["age"]))
```

*You should see:*

```text
Sara lives in Sharjah and is 31
Omar lives in Dubai and is 28
```

*(`DictReader` gives each row as a dictionary keyed by the first line's names. Every value
comes as text: change numbers with `int` or `float`)*

Writing one:

```python
import csv

rows = [{"item": "tea", "price": 8.5}, {"item": "rice", "price": 7.25}]
with open("prices.csv", "w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["item", "price"])
    w.writeheader()
    w.writerows(rows)
print(open("prices.csv", encoding="utf-8").read())
```

*You should see:*

```text
item,price
tea,8.5
rice,7.25
```
