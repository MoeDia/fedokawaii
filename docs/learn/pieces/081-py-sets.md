---
id: py-sets
title: nested data, sets
part: python
chapter: 30
minutes: 4
needs: [py-dict-loop]
optional: no
---

## 30.6 nested data

Real data — a JSON file, a web API's answer — is dictionaries and lists inside each other:

```python
user = {
    "name": "Sara",
    "langs": ["Python", "Rust"],
    "address": {"city": "Sharjah", "country": "UAE"},
}
print(user["langs"][1])
print(user["address"]["city"])
user["langs"].append("SQL")
print(len(user["langs"]))
```

*You should see:*

```text
Rust
Sharjah
3
```

## 30.7 sets

A **set** holds values without repeats and without order. It answers *is this in it?* fast,
and does the maths of groups:

```text
>>> colours = {"red", "green", "red", "blue"}
>>> len(colours)
3
>>> "red" in colours
True
>>> set([3, 1, 3, 2, 1]) == {1, 2, 3}
True
>>> a = {"python", "rust", "sql"}
>>> b = {"rust", "go"}
>>> sorted(a | b)
['go', 'python', 'rust', 'sql']
>>> a & b
{'rust'}
>>> sorted(a - b)
['python', 'sql']
```

| Sign | Gives |
|---|---|
| `a \| b` | everything in either (union) |
| `a & b` | what is in both (intersection) |
| `a - b` | what is in `a` but not `b` (difference) |

*(an empty set is `set()`; `{}` is an empty dictionary)*
