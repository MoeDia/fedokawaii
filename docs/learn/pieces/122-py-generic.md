---
id: py-generic
title: generic functions, how much to type
part: python
chapter: 36
minutes: 3
needs: [py-optional]
optional: no
---

## 36.6 generic functions

A function that works for any type, keeping it: `T` stands for "whatever type comes in":

```python
def first[T](items: list[T]) -> T:
    return items[0]

def pairs[K, V](d: dict[K, V]) -> list[tuple[K, V]]:
    return sorted(d.items())

n = first([3, 1, 2])
s = first(["b", "a"])
print(n + 1, s.upper())
print(pairs({"b": 2, "a": 1}))
```

*You should see:*

```text
4 B
[('a', 1), ('b', 2)]
```

*(the checker knows `n` is an `int` and `s` a `str`. The `[T]` after the name is Python 3.12's
short way to declare it)*

## 36.7 how much to type

| Where | Advice |
|---|---|
| function parameters and returns | always: it is where mistakes cross from one piece of code to another |
| class fields | always (dataclasses need them anyway) |
| local variables | rarely: the checker works them out (`x = 3` is an `int`) |
| quick scripts at the prompt | not needed |

## 36.8 common mistakes

**1. Expecting Python to enforce them.** It does not: `area("3", 4)` runs. Hints help only if
something checks them — your editor, `mypy`, or `basedpyright`.

**2. `list` instead of `list[int]`.** A bare `list` says "a list of anything": the checker
learns nothing about the items.

**3. Forgetting `| None`.** If a function can return `None`, say so in its return type;
otherwise every caller believes it never does.
