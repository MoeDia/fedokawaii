---
id: py-numbers-mistakes
title: common mistakes
part: python
chapter: 25
minutes: 4
needs: [py-print-input]
optional: no
---

## 25.7 common mistakes

**1. Adding text and a number.** `input` gives text; text and a number cannot be added.

```python
age = input("Age? ")
print(age + 1)
```

*Python says:*

```text
Age? 30
Traceback (most recent call last):
  File "example.py", line 2, in <module>
    print(age + 1)
          ~~~~^~~
TypeError: can only concatenate str (not "int") to str
```

Python names the problem in the last line: `can only concatenate str (not "int") to str`.
Fix: `int(age) + 1`. (This version was fed `30` as the answer.)

**2. A name used before it exists.**

```python
print(total)
```

*Python says:*

```text
Traceback (most recent call last):
  File "example.py", line 1, in <module>
    print(total)
          ^^^^^
NameError: name 'total' is not defined
```

**3. A typo in a name.** Python does not guess: `Price` and `price` are different names.

```python
price = 5
print(Price * 2)
```

*Python says:*

```text
Traceback (most recent call last):
  File "example.py", line 2, in <module>
    print(Price * 2)
          ^^^^^
NameError: name 'Price' is not defined. Did you mean: 'price'?
```

*(Python 3.14 even suggests the right name: `Did you mean: 'price'?`)*

**4. A missing bracket or quote.** The error is a `SyntaxError`, and it points near — often
just after — the real mistake:

```python
print("hello"
```

*Python says:*

```text
  File "example.py", line 1
    print("hello"
         ^
SyntaxError: '(' was never closed
```

> **Checkpoint.** Without running it, say what this prints; then run it and check:
> `x = 7`, `x = x // 2 + x % 2`, `print(x * 2)`. *(It prints 8.)*
