---
id: py-errors-practice
title: practice
part: python
chapter: 32
minutes: 13
needs: [py-catch]
optional: no
---

**32.1 ★ Safe int.** `to_int(text, default=0)` returns the number, or `default` if the text is not one.

<!-- solution 32.1 -->
```python
def to_int(text, default=0):
    try:
        return int(text)
    except ValueError:
        return default

print(to_int("42"), to_int("x"), to_int("", default=-1))
```

*You should see:*

```text
42 0 -1
```
<!-- /solution -->

**32.2 ★ Read or say so.** Read `notes.txt`; if it is missing, print `no notes yet` instead of a traceback.

<!-- solution 32.2 -->
```python
from pathlib import Path

try:
    print(Path("notes-missing.txt").read_text(encoding="utf-8"))
except FileNotFoundError:
    print("no notes yet")
```

*You should see:*

```text
no notes yet
```
<!-- /solution -->

**32.3 ★ Which error?.** At the prompt, find the exception each raises: `[1, 2][9]`, `{"a": 1}["b"]`, `"a" * "b"`,
`int("1.5")`, `None.upper()`.

<!-- solution 32.3 -->
```python
tests = ['[1, 2][9]', '{"a": 1}["b"]', '"a" * "b"', 'int("1.5")', 'None.upper()']
for t in tests:
    try:
        eval(t)
    except Exception as e:
        print(f"{t:<15} {type(e).__name__}")
```

*You should see:*

```text
[1, 2][9]       IndexError
{"a": 1}["b"]   KeyError
"a" * "b"       TypeError
int("1.5")      ValueError
None.upper()    AttributeError
```
<!-- /solution -->

**32.4 ★★ Age check.** `check_age(age)` raises `ValueError` with a clear message for a negative age or one over 150;
call it in a `try` with three values.

<!-- solution 32.4 -->
```python
def check_age(age):
    if age < 0 or age > 150:
        raise ValueError(f"age must be 0-150, got {age}")
    return age

for a in (30, -2, 200):
    try:
        print("ok", check_age(a))
    except ValueError as e:
        print("refused:", e)
```

*You should see:*

```text
ok 30
refused: age must be 0-150, got -2
refused: age must be 0-150, got 200
```
<!-- /solution -->

**32.5 ★★ Average of good lines.** A list of strings, some numbers and some not: average only the numbers, and count the bad ones.
*Expected:* `["3", "x", "5", "", "10"]` → `average 6.0, 2 bad`.

<!-- solution 32.5 -->
```python
lines = ["3", "x", "5", "", "10"]
good, bad = [], 0
for s in lines:
    try:
        good.append(float(s))
    except ValueError:
        bad += 1
print(f"average {sum(good) / len(good)}, {bad} bad")
```

*You should see:*

```text
average 6.0, 2 bad
```
<!-- /solution -->
