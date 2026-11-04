---
id: py-failure
title: reading a failure, testing errors
part: python
chapter: 35
minutes: 6
needs: [py-first-test]
optional: no
---

## 35.3 reading a failure

Break `total` on purpose — forget the discount — and run again:

`shop.py`:

```python
def total(prices, discount=0.0):
    return round(sum(prices), 2)
```

```text
$ uv run pytest -q
.F.                                                                      [100%]
=================================== FAILURES ===================================
________________________________ test_discount _________________________________

    def test_discount():
>       assert total([10, 10], discount=0.1) == 18
E       assert 20 == 18
E        +  where 20 = total([10, 10], discount=0.1)

test_shop.py:7: AssertionError
=========================== short test summary info ============================
FAILED test_shop.py::test_discount - assert 20 == 18
1 failed, 2 passed in 0.01s
```

Read it like a traceback, from the bottom: which test failed, and pytest's
`assert 20 == 18` shows *both* sides: the code gave 20, the test wanted 18. Put the discount
back and it is green again.

`shop.py`:

```python
def total(prices, discount=0.0):
    """The sum of the prices, less a discount (0.1 is 10 %)."""
    return round(sum(prices) * (1 - discount), 2)
```

## 35.4 testing errors

`pytest.raises` checks that something *fails* the way it should:

`prices.py`:

```python
def parse_price(text):
    try:
        value = float(text)
    except ValueError:
        raise ValueError(f"not a price: {text!r}") from None
    if value < 0:
        raise ValueError("a price cannot be negative")
    return value
```

`test_prices.py`:

```python
import pytest
from prices import parse_price

def test_number():
    assert parse_price("12.5") == 12.5

def test_words_are_not_prices():
    with pytest.raises(ValueError, match="not a price"):
        parse_price("twelve")

def test_negative():
    with pytest.raises(ValueError, match="negative"):
        parse_price("-3")
```

```text
$ uv run pytest -q test_prices.py
...                                                                      [100%]
3 passed in 0.01s
```
