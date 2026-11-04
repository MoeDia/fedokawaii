---
id: py-try
title: try, except, else, finally
part: python
chapter: 32
minutes: 6
needs: [py-exception]
optional: no
---

## 32.2 try and except

When you *expect* a problem — a person typing letters where you wanted a number, a file that
may be missing — catch it with `try` / `except` and do something sensible:

```python
while True:
    text = input("How many? ")
    try:
        n = int(text)
        break
    except ValueError:
        print(f"{text!r} is not a whole number, try again")
print("ok:", n)
```

*You should see:*

```text
How many? twelve
'twelve' is not a whole number, try again
How many? 12
ok: 12
```

*(`{text!r}` shows the value with quotes, so an empty answer is visible as `''`)*

Several kinds, each its own answer; `as e` names the exception so you can show its message:

```python
def safe_divide(a, b):
    try:
        return a / b
    except ZeroDivisionError:
        return None
    except TypeError as e:
        print("type problem:", e)
        return None

print(safe_divide(10, 4))
print(safe_divide(1, 0))
print(safe_divide("1", 2))
```

*You should see:*

```text
2.5
None
type problem: unsupported operand type(s) for /: 'str' and 'int'
None
```

## 32.3 else and finally

`else` runs only if nothing went wrong; `finally` runs **always** — for clean-up:

```python
def read_number(text):
    try:
        n = float(text)
    except ValueError:
        print("  not a number:", text)
    else:
        print("  got", n)
    finally:
        print("  (checked", repr(text) + ")")

read_number("3.5")
read_number("abc")
```

*You should see:*

```text
  got 3.5
  (checked '3.5')
  not a number: abc
  (checked 'abc')
```
