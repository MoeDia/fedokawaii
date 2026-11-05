---
id: py-nested
title: lists of lists, tuples
part: python
chapter: 29
minutes: 5
needs: [py-sorting]
optional: no
---

## 29.5 lists of lists

A list can hold lists: a table, a board, a grid.

```python
grid = [
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9],
]
print(grid[1])
print(grid[1][2])
for row in grid:
    print(sum(row))
```

*You should see:*

```text
[4, 5, 6]
6
6
15
24
```

## 29.6 tuples: fixed lists

A **tuple** is like a list in `( )`, but it can never change. Use one for a few values that
belong together: a point, a date, a name and an age.

```text
>>> point = (3, 4)
>>> point[0]
3
>>> x, y = point
>>> x + y
7
>>> date = (2026, 10, 21)
>>> year, month, day = date
>>> month
10
```

*(taking a tuple apart into names is called **unpacking**)*

```python
point = (3, 4)
point[0] = 10
```

*Python says:*

```text
Traceback (most recent call last):
  File "example.py", line 2, in <module>
    point[0] = 10
    ~~~~~^^^
TypeError: 'tuple' object does not support item assignment
```

> **Word — mutable, immutable.** Mutable values can be changed in place: lists, dictionaries,
> sets. Immutable ones cannot: numbers, strings, tuples. "Changing" an immutable value always
> means making a new one.
