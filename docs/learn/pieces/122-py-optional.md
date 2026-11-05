---
id: py-optional
title: optional values; your own types
part: python
chapter: 36
minutes: 6
needs: [py-common-types]
optional: no
---

## 36.4 optional values: None handled

`str | None` says *maybe nothing*. The checker then insists you handle the `None` before using
the value — the commonest bug in any language, found for free:

`maybe.py`:

```python
def find(names: list[str], prefix: str) -> str | None:
    for n in names:
        if n.startswith(prefix):
            return n
    return None

def shout_first(names: list[str]) -> str:
    hit = find(names, "s")
    return hit.upper()
```

```text
$ uvx mypy maybe.py
maybe.py:9: error: Item "None" of "str | None" has no attribute "upper"  [union-attr]
Found 1 error in 1 file (checked 1 source file)
```

The fix says what happens when nothing was found:

`maybe.py`:

```python
def find(names: list[str], prefix: str) -> str | None:
    for n in names:
        if n.startswith(prefix):
            return n
    return None

def shout_first(names: list[str]) -> str:
    hit = find(names, "s")
    if hit is None:
        return "NOBODY"
    return hit.upper()
```

```text
$ uvx mypy maybe.py
Success: no issues found in 1 source file
```

## 36.5 your own types

Your classes are types too. A dataclass's fields are already typed; a `type` statement names a
longer type once:

```python
from dataclasses import dataclass
from typing import Literal

type Grid = list[list[int]]
Colour = Literal["red", "green", "blue"]

@dataclass
class Pixel:
    x: int
    y: int
    colour: Colour

def size(g: Grid) -> tuple[int, int]:
    return len(g), len(g[0])

print(size([[0, 1, 2], [3, 4, 5]]))
print(Pixel(1, 2, "red"))
```

*You should see:*

```text
(2, 3)
Pixel(x=1, y=2, colour='red')
```

*(`Literal["red", "green", "blue"]` allows only those three strings: a typo like `"rde"` is
flagged)*
