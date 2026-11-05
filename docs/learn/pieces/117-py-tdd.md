---
id: py-tdd
title: test first, what to test
part: python
chapter: 35
minutes: 5
needs: [py-many-cases]
optional: no
---

## 35.7 test first: red, green, tidy

The surest way to write a function: write its test **first**, watch it fail (*red*), write
the simplest code that passes (*green*), then improve the code while the test keeps it honest
(*tidy*). The test says what you want before the code says how.

`test_slug.py`:

```python
from slug import slugify

def test_spaces_become_dashes():
    assert slugify("Hello World") == "hello-world"

def test_punctuation_goes():
    assert slugify("Rust, Python & AI!") == "rust-python-ai"

def test_no_double_dashes():
    assert slugify("a  --  b") == "a-b"
```

```text
$ uv run pytest -q test_slug.py
ERROR test_slug.py
!!!!!!!!!!!!!!!!!!!! Interrupted: 1 error during collection !!!!!!!!!!!!!!!!!!!!
1 error in 0.08s
```

Red: there is no `slug` module yet. Now the code:

`slug.py`:

```python
def slugify(title):
    words = "".join(ch if ch.isalnum() else " " for ch in title.lower()).split()
    return "-".join(words)
```

```text
$ uv run pytest -q test_slug.py
...                                                                      [100%]
3 passed in 0.01s
```

## 35.8 what to test

| Test | Example |
|---|---|
| the normal case | `total([3, 5])` |
| the edges | an empty list, zero, one item, the largest allowed |
| wrong input | text where a number belongs: it should raise |
| every bug you fix | write the test that shows the bug first; it stays, so the bug never comes back |

Keep each test small, named for what it checks (`test_empty_basket_costs_nothing`), and
independent of the others.

## 35.9 common mistakes

**1. A test file or function not named `test_…`** — pytest silently skips it. Check the count
of tests it reports.

**2. Comparing floats with `==`.** `0.1 + 0.2 == 0.3` is `False` (chapter 25). Use
`pytest.approx`:

`test_float.py`:

```python
import pytest

def test_float():
    assert 0.1 + 0.2 == pytest.approx(0.3)
```

```text
$ uv run pytest -q test_float.py
.                                                                        [100%]
1 passed in 0.01s
```

**3. Tests that depend on each other**, or on the order they run in, or on today's date. Each
test makes what it needs (`tmp_path` helps), and passes alone.
