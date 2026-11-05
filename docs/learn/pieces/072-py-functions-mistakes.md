---
id: py-functions-mistakes
title: common mistakes
part: python
chapter: 28
minutes: 4
needs: [py-calling]
optional: no
---

## 28.8 common mistakes

**1. Forgetting the brackets.** Without `()`, the function is not called — you get the
function itself:

```python
def now():
    return "12:00"

print(now)
print(now())
```

*You should see:*

```text
<function now at 0x7fb08aad3480>
12:00
```

**2. Printing instead of returning.** The value is shown, but the caller gets `None`:

```python
def add(a, b):
    print(a + b)

total = add(2, 3) * 10
```

*Python says:*

```text
5
Traceback (most recent call last):
  File "example.py", line 4, in <module>
    total = add(2, 3) * 10
            ~~~~~~~~~~^~~~
TypeError: unsupported operand type(s) for *: 'NoneType' and 'int'
```

**3. Wrong number of arguments.**

```python
def area(width, height):
    return width * height

area(5)
```

*Python says:*

```text
Traceback (most recent call last):
  File "example.py", line 4, in <module>
    area(5)
    ~~~~^^^
TypeError: area() missing 1 required positional argument: 'height'
```

**4. Code after `return` never runs.** Python stops at `return`; lines below it in the same
block are dead. neovim greys them out.
