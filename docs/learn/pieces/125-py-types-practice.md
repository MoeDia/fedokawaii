---
id: py-types-practice
title: practice
part: python
chapter: 36
minutes: 13
needs: [py-library]
optional: no
---

**36.1 ★ Hint it.** Add type hints to `def pay(hours, rate)` and `def greeting(name, hour)` from chapter 28.

<!-- solution 36.1 -->
```python
def pay(hours: float, rate: float) -> float:
    if hours <= 40:
        return hours * rate
    return 40 * rate + (hours - 40) * rate * 1.5

def greeting(name: str, hour: int) -> str:
    return f"Good {'morning' if hour < 12 else 'evening'}, {name}"

print(pay(45, 10), greeting("Sara", 9))
```

*You should see:*

```text
475.0 Good morning, Sara
```
<!-- /solution -->

**36.2 ★ Read the hints.** Without running: what does `def f(xs: list[str]) -> dict[str, int]` take and give? Write a body
that fits: each string's length.

<!-- solution 36.2 -->
```python
def f(xs: list[str]) -> dict[str, int]:
    return {x: len(x) for x in xs}

print(f(["tea", "rice"]))
```

*You should see:*

```text
{'tea': 3, 'rice': 4}
```
<!-- /solution -->

**36.3 ★ Find the bug by checking.** Run `mypy` on a file where `def half(n: int) -> int: return n / 2`. What does it say, and why?

<!-- solution 36.3 -->
mypy says `Incompatible return value type (got "float", expected "int")`: `/` always gives a
float. Use `n // 2`, or change the return type to `float`.
<!-- /solution -->

**36.4 ★★ Optional.** `def price_of(item: str, prices: dict[str, float]) -> float | None` returns the price or `None`;
then `def total(...)` that skips unknown items — with a check `if p is not None`.

<!-- solution 36.4 -->
```python
def price_of(item: str, prices: dict[str, float]) -> float | None:
    return prices.get(item)

def total(items: list[str], prices: dict[str, float]) -> float:
    s = 0.0
    for it in items:
        p = price_of(it, prices)
        if p is not None:
            s += p
    return s

print(total(["tea", "cake", "rice"], {"tea": 12.5, "rice": 7.25}))
```

*You should see:*

```text
19.75
```
<!-- /solution -->

**36.5 ★★ Typed dataclass.** A `Book` dataclass (title: str, year: int, tags: list[str]) and a function
`by_tag(books: list[Book], tag: str) -> list[str]` returning titles.

<!-- solution 36.5 -->
```python
from dataclasses import dataclass, field

@dataclass
class Book:
    title: str
    year: int
    tags: list[str] = field(default_factory=list)

def by_tag(books: list[Book], tag: str) -> list[str]:
    return [b.title for b in books if tag in b.tags]

shelf = [Book("Dune", 1965, ["sf"]), Book("Emma", 1815, ["classic"]), Book("Solaris", 1961, ["sf"])]
print(by_tag(shelf, "sf"))
```

*You should see:*

```text
['Dune', 'Solaris']
```
<!-- /solution -->
