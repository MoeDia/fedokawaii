---
id: py-scope
title: scope, docstrings and assert
part: python
chapter: 28
minutes: 7
needs: [py-return]
optional: no
---

## 28.5 scope: where a name lives

A variable made inside a function exists only inside it, and only while it runs. This is
good: two functions can each have their own `total` without touching each other.

```python
def make_total():
    total = 42
    return total

make_total()
print(total)
```

*Python says:*

```text
Traceback (most recent call last):
  File "example.py", line 6, in <module>
    print(total)
          ^^^^^
NameError: name 'total' is not defined
```

A function can **read** a name from outside, but should not change it. Pass values in and
return results out — then each function can be understood on its own:

```python
VAT = 0.05

def with_vat(price):
    return price * (1 + VAT)

print(with_vat(200))
```

*You should see:*

```text
210.0
```

*(names in CAPITALS are, by habit, constants: values the program never changes)*

## 28.6 docstrings and assert: say it, then check it

A **docstring** — a string as the first line of the body — says what the function does.
`help()` shows it, and so does neovim's `K`:

```python
def bmi(weight_kg, height_m):
    """Body mass index: weight divided by height squared."""
    return weight_kg / height_m ** 2

print(round(bmi(70, 1.75), 1))
print(bmi.__doc__)
```

*You should see:*

```text
22.9
Body mass index: weight divided by height squared.
```

`assert` checks something you believe is true. If it is, nothing happens; if not, the program
stops and tells you. It is the smallest possible test (chapter 35 grows them into pytest):

```python
def double(n):
    return n * 2

assert double(4) == 8
assert double(0) == 0
assert double(-3) == -6
print("all good")
```

*You should see:*

```text
all good
```

```python
def half(n):
    return n // 2

assert half(7) == 3.5, "half of 7 should be 3.5"
```

*Python says:*

```text
Traceback (most recent call last):
  File "example.py", line 4, in <module>
    assert half(7) == 3.5, "half of 7 should be 3.5"
           ^^^^^^^^^^^^^^
AssertionError: half of 7 should be 3.5
```

*(the message after the comma says what you expected; `//` dropped the .5 — the fix is `/`)*
