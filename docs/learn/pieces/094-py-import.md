---
id: py-import
title: import, and your own module
part: python
chapter: 33
minutes: 5
needs: [py-files-practice, py-errors-practice, loop-commit]
optional: no
---

> **In this chapter**
>
> - `import`: use code from another file, the standard library, or the internet
> - your own module, and `if __name__ == "__main__"`
> - projects with uv: their own Python, their own libraries, a lock file
> - the checkpoint for level 3: an expense tracker

## 33.1 import: code from elsewhere

A **module** is a file of Python code you can use from another. Python comes with hundreds —
the **standard library** — and `import` brings one in:

```python
import math
import random
from datetime import date

print(math.sqrt(16), math.pi)
random.seed(1)
print(random.choice(["tea", "coffee", "water"]))
print(date(2026, 12, 2) - date(2026, 10, 21))
```

*You should see:*

```text
4.0 3.141592653589793
tea
42 days, 0:00:00
```

| Form | Then you write |
|---|---|
| `import math` | `math.sqrt(2)` |
| `from math import sqrt` | `sqrt(2)` |
| `import numpy as np` | `np.array(…)` (a short name, by habit) |

Some standard modules worth knowing by name:

| Module | For |
|---|---|
| `math`, `statistics`, `random` | numbers, averages, chance |
| `datetime`, `time` | dates, times, timing |
| `pathlib`, `shutil`, `os` | files and folders |
| `json`, `csv` | data formats |
| `collections` | `Counter`, `defaultdict`, `deque` |
| `itertools`, `functools` | tools for loops and functions (chapter 37) |
| `argparse` | command-line options (chapter 39) |
| `urllib.request` | the web |
| `sqlite3` | a database in one file |

## 33.2 your own module

Any `.py` file is a module. Put functions in one file and import them from another:

`shapes.py`:

```python
"""Areas of simple shapes."""
import math

def circle(r):
    return math.pi * r ** 2

def square(side):
    return side * side
```

`main.py`:

```python
import shapes
from shapes import square

print(round(shapes.circle(2), 2))
print(square(3))
print(shapes.__doc__)
```

```text
$ uv run main.py
12.57
9
Areas of simple shapes.
```
