---
id: py-types-projects
title: projects
part: python
chapter: 36
minutes: 180
needs: [py-types-practice]
optional: yes
---

**36.6 ★★★ A generic helper.** `def chunks[T](items: list[T], n: int) -> list[list[T]]` splits a list into pieces of `n`.
Test it with ints and with strings.

<!-- solution 36.6 -->
```python
def chunks[T](items: list[T], n: int) -> list[list[T]]:
    return [items[i:i + n] for i in range(0, len(items), n)]

print(chunks([1, 2, 3, 4, 5], 2))
print(chunks(list("abcdef"), 3))
```

*You should see:*

```text
[[1, 2], [3, 4], [5]]
[['a', 'b', 'c'], ['d', 'e', 'f']]
```
<!-- /solution -->

**36.7 ★★★ Literal states.** A traffic light: `State = Literal["red", "green", "amber"]` and `def next_state(s: State) -> State`.
Show that mypy flags `next_state("blue")`.

<!-- solution 36.7 -->
```python
from typing import Literal

State = Literal["red", "green", "amber"]

def next_state(s: State) -> State:
    return {"red": "green", "green": "amber", "amber": "red"}[s]

s: State = "red"
for _ in range(4):
    print(s, end=" → ")
    s = next_state(s)
print(s)
```

*You should see:*

```text
red → green → amber → red → green
```
<!-- /solution -->

**36.8 ★★★★ Type the expense tracker.** Add full hints to level 3's `ledger.py` — a `Row` as a `TypedDict` (`from typing import TypedDict`:
date: str, category: str, amount: float) — and make `mypy --strict ledger.py` clean.

<!-- solution 36.8 -->
```python
from typing import TypedDict

class Row(TypedDict):
    date: str
    category: str
    amount: float

def load(path: str | Path) -> list[Row]: ...
def save(path: str | Path, rows: list[Row]) -> None: ...
def parse(line: str) -> Row: ...
def totals(rows: list[Row]) -> dict[str, float]: ...
```
*(inside `load`, build each `Row` explicitly — `Row(date=r["date"], category=r["category"],
amount=float(r["amount"]))` — since `csv.DictReader` gives `dict[str, str]`; then `mypy --strict`
reports `Success`)*
<!-- /solution -->
