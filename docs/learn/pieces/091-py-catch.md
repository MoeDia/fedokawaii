---
id: py-catch
title: when to catch; common mistakes
part: python
chapter: 32
minutes: 3
needs: [py-raise]
optional: no
---

## 32.5 when to catch, and when not

The rule: **catch only what you expect, and only where you can do something useful about it**.
Everything else should stop the program with its traceback — that traceback is how you find
the bug.

```python
data = {"a": 1}
try:
    print(data["b"])
except Exception:
    pass
print("the bug is hidden: nothing told you key 'b' was missing")
```

*You should see:*

```text
the bug is hidden: nothing told you key 'b' was missing
```

*(never write `except: pass` — it swallows every error, typos included, and the program goes
on with wrong values)*

## 32.6 common mistakes

**1. Too much inside `try`.** Put only the line that can fail there; the rest after it, or in
`else`. Otherwise a bug in another line is caught by mistake.

**2. Catching the wrong kind.** `int("x")` raises `ValueError`, not `TypeError`. Run it once
at the prompt to see which.

```python
try:
    int("x")
except TypeError:
    print("caught")
```

*Python says:*

```text
Traceback (most recent call last):
  File "example.py", line 2, in <module>
    int("x")
    ~~~^^^^^
ValueError: invalid literal for int() with base 10: 'x'
```

**3. Losing the message.** `except ValueError as e: print("error")` throws away what went
wrong; print `e` too.
