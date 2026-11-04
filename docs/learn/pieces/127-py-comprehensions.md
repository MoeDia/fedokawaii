---
id: py-comprehensions
title: comprehensions
part: python
chapter: 37
minutes: 5
needs: [py-types-practice]
optional: no
---

> **In this chapter**
>
> - comprehensions: build a list, dictionary or set in one line
> - what `for` really does: iterables and iterators
> - generators: values made one at a time, as they are asked for
> - `itertools` and `functools`: ready-made tools for loops and functions

## 37.1 list comprehensions

You have written this shape many times: an empty list, a loop, an `append`. A **list
comprehension** says the same in one line:

```python
squares = []
for n in range(6):
    squares.append(n * n)
print(squares)

squares = [n * n for n in range(6)]
print(squares)
```

*You should see:*

```text
[0, 1, 4, 9, 16, 25]
[0, 1, 4, 9, 16, 25]
```

Read it as English: *n × n, for each n in range(6)*. Add `if` to keep only some:

```text
>>> [n for n in range(20) if n % 3 == 0]
[0, 3, 6, 9, 12, 15, 18]
>>> [w.upper() for w in ["tea", "rice", "milk"] if len(w) > 3]
['RICE', 'MILK']
>>> [c * 9 / 5 + 32 for c in [20, 25, 31]]
[68.0, 77.0, 87.8]
```

An `if … else` *before* the `for` chooses a value for every item (it does not filter):

```text
>>> ["even" if n % 2 == 0 else "odd" for n in range(4)]
['even', 'odd', 'even', 'odd']
```

| Shape | Does |
|---|---|
| `[f(x) for x in xs]` | change every item |
| `[x for x in xs if test(x)]` | keep some items |
| `[a if test(x) else b for x in xs]` | choose for every item |
| `[(x, y) for x in xs for y in ys]` | every pair (loops in the same order as nested `for`s) |

## 37.2 dictionary and set comprehensions

The same with `{ }`: `key: value` makes a dictionary, a single value makes a set:

```text
>>> words = ["tea", "rice", "milk", "tea"]
>>> {w: len(w) for w in words}
{'tea': 3, 'rice': 4, 'milk': 4}
>>> {len(w) for w in words}
{3, 4}
>>> prices = {"tea": 12.5, "rice": 7.25, "cake": 30}
>>> {k: v for k, v in prices.items() if v < 20}
{'tea': 12.5, 'rice': 7.25}
>>> {v: k for k, v in prices.items()}
{12.5: 'tea', 7.25: 'rice', 30: 'cake'}
```

> **Careful.** A comprehension is for *building* a collection. If the line grows past one
> screen-width, or has two `if`s and two `for`s, write the plain loop: it is easier to read.
