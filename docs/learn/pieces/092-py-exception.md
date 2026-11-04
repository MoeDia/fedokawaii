---
id: py-exception
title: what an exception is
part: python
chapter: 32
minutes: 3
needs: [py-files-practice]
optional: no
---

> **In this chapter**
>
> - read a traceback from the bottom up
> - catch an error you expect with `try` / `except`
> - raise your own errors, with a message that helps
> - `else`, `finally`, and why not to catch everything

## 32.1 what an exception is

When Python cannot do what a line asks, it **raises an exception**: it stops and prints a
**traceback** — where it was, and what went wrong. Read it from the bottom: the last line
names the kind of error and the reason; the lines above say where.

```python
def average(nums):
    return sum(nums) / len(nums)

print(average([3, 4]))
print(average([]))
```

*Python says:*

```text
3.5
Traceback (most recent call last):
  File "example.py", line 5, in <module>
    print(average([]))
          ~~~~~~~^^^^
  File "example.py", line 2, in average
    return sum(nums) / len(nums)
           ~~~~~~~~~~^~~~~~~~~~~
ZeroDivisionError: division by zero
```

*(read up from the bottom: a `ZeroDivisionError`, in `average`, line 2, called from line 5 with
an empty list)*

| Exception | Means | Example |
|---|---|---|
| `NameError` | no such name | a typo |
| `TypeError` | the wrong kind of value | `"3" + 4` |
| `ValueError` | the right kind, a wrong value | `int("abc")` |
| `IndexError` · `KeyError` | no such index · key | `[1][5]`, `{}["a"]` |
| `ZeroDivisionError` | divided by zero | `1 / 0` |
| `FileNotFoundError` | no such file | `open("nope")` |
| `AttributeError` | no such method or field | `"a".push()` |
