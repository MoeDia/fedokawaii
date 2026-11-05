---
id: py-raise
title: raising your own
part: python
chapter: 32
minutes: 4
needs: [py-try]
optional: no
---

## 32.4 raising your own

When your function receives something it cannot handle, `raise` an exception with a message
that says what was wrong — the person who sees it is often you, next month:

```python
def set_volume(level):
    if not 0 <= level <= 100:
        raise ValueError(f"volume must be 0-100, got {level}")
    print("volume", level)

set_volume(40)
set_volume(140)
```

*Python says:*

```text
volume 40
Traceback (most recent call last):
  File "example.py", line 7, in <module>
    set_volume(140)
    ~~~~~~~~~~^^^^^
  File "example.py", line 3, in set_volume
    raise ValueError(f"volume must be 0-100, got {level}")
ValueError: volume must be 0-100, got 140
```

Your own kind of error is a small class (classes come in chapter 34; this is all you need now):

```python
class OutOfStock(Exception):
    pass

stock = {"tea": 0}

def buy(item):
    if stock.get(item, 0) == 0:
        raise OutOfStock(item)
    stock[item] -= 1

try:
    buy("tea")
except OutOfStock as e:
    print("sorry, no", e)
```

*You should see:*

```text
sorry, no tea
```
