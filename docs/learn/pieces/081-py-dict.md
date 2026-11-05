---
id: py-dict
title: a dictionary, safely
part: python
chapter: 30
minutes: 5
needs: [py-functions-practice, py-lists-practice]
optional: no
---

> **In this chapter**
>
> - dictionaries: look a value up by a key
> - counting and grouping, the two jobs dictionaries do best
> - sets: collections without repeats, and fast `in`
> - the checkpoint for level 2: a contacts book

## 30.1 a dictionary

A **dictionary** (`dict`) maps **keys** to **values**, like a word to its meaning, or a name
to a phone number. Write it in `{ }` with `key: value` pairs:

```text
>>> phone = {"Sara": "050 111", "Omar": "055 222"}
>>> phone["Sara"]
'050 111'
>>> phone["Lina"] = "052 333"
>>> phone
{'Sara': '050 111', 'Omar': '055 222', 'Lina': '052 333'}
>>> len(phone)
3
>>> "Omar" in phone
True
```

Looking up by key is instant, however big the dictionary — no searching through it.

## 30.2 getting values safely

A missing key is an error; `.get` gives a default instead:

```python
stock = {"rice": 2, "tea": 0}
print(stock["milk"])
```

*Python says:*

```text
Traceback (most recent call last):
  File "example.py", line 2, in <module>
    print(stock["milk"])
          ~~~~~^^^^^^^^
KeyError: 'milk'
```

```text
>>> stock = {"rice": 2, "tea": 0}
>>> stock.get("milk")
>>> stock.get("milk", 0)
0
>>> stock.get("rice", 0)
2
```

## 30.3 changing and removing

```text
>>> stock = {"rice": 2, "tea": 0}
>>> stock["tea"] += 5
>>> stock["milk"] = 1
>>> stock
{'rice': 2, 'tea': 5, 'milk': 1}
>>> del stock["rice"]
>>> stock
{'tea': 5, 'milk': 1}
>>> stock.pop("milk")
1
>>> stock
{'tea': 5}
```
