---
id: py-first-test
title: the first test
part: python
chapter: 35
minutes: 3
needs: [py-classes-practice, loop-commit]
optional: no
---

> **In this chapter**
>
> - why tests: change code without fear
> - pytest: test functions, `assert`, running, reading a failure
> - testing errors, many cases at once, and temporary files
> - test first: red, green, tidy

## 35.1 why tests

A **test** is a small program that runs your code and checks the answer. You write it once;
then, every time you change anything, all the tests run in a second and tell you whether
everything still works. Without tests, every change is a risk; with them, you can rebuild a
program boldly.

pytest finds files named `test_*.py`, runs every function in them named `test_*`, and reports.
Inside, a plain `assert` is all you need.

## 35.2 the first test

`shop.py`:

```python
def total(prices, discount=0.0):
    """The sum of the prices, less a discount (0.1 is 10 %)."""
    return round(sum(prices) * (1 - discount), 2)
```

`test_shop.py`:

```python
from shop import total

def test_total():
    assert total([3, 5, 8]) == 16

def test_discount():
    assert total([10, 10], discount=0.1) == 18

def test_empty():
    assert total([]) == 0
```

```text
$ uv run pytest -q
...                                                                      [100%]
3 passed in 0.01s
```

*(each `.` is a test that passed. In a uv project, `uv add --dev pytest` once; in neovim,
**Space t t** runs them, **Space t w** on every save)*
