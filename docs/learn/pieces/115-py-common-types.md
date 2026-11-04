---
id: py-common-types
title: the common types
part: python
chapter: 36
minutes: 3
needs: [py-hint]
optional: no
---

## 36.3 the common types

| Hint | Means | Example |
|---|---|---|
| `int` `float` `str` `bool` | the basic types | `n: int = 3` |
| `list[int]` | a list of ints | `[1, 2, 3]` |
| `dict[str, float]` | keys str, values float | `{"tea": 8.5}` |
| `tuple[int, int]` | exactly two ints | `(3, 4)` |
| `set[str]` | a set of strings | `{"a"}` |
| `int \| None` | an int, or `None` | `.get()` results |
| `float \| str` | either | |
| `Callable[[int], int]` | a function taking an int, giving one | `lambda n: n * 2` |
| `Any` | anything — the checker gives up here | |

(`int` is accepted where `float` is asked: every int is a fine float.)

```python
from collections.abc import Callable

def apply_twice(f: Callable[[int], int], x: int) -> int:
    return f(f(x))

def find(names: list[str], prefix: str) -> str | None:
    for n in names:
        if n.startswith(prefix):
            return n
    return None

print(apply_twice(lambda n: n * 3, 2))
print(find(["sara", "omar"], "om"), find(["sara"], "x"))
```

*You should see:*

```text
18
omar None
```
