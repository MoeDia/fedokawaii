---
id: py-errors-projects
title: projects
part: python
chapter: 32
minutes: 180
needs: [py-errors-practice]
optional: yes
---

**32.6 ★★★ Retry.** `ask_int(prompt, low, high)` keeps asking until the answer is a whole number from `low` to `high`,
saying what was wrong each time.

<!-- solution 32.6 -->
```python
def ask_int(prompt, low, high):
    while True:
        text = input(prompt)
        try:
            n = int(text)
        except ValueError:
            print("  a whole number, please")
            continue
        if low <= n <= high:
            return n
        print(f"  between {low} and {high}, please")

print("you chose", ask_int("1-10? ", 1, 10))
```

*You should see:*

```text
1-10? ten
  a whole number, please
1-10? 99
  between 1 and 10, please
1-10? 7
you chose 7
```
<!-- /solution -->

**32.7 ★★★ Your own exception.** Make `InsufficientFunds(Exception)` and `withdraw(balance, amount)` that raises it with the
missing amount in the message.

<!-- solution 32.7 -->
```python
class InsufficientFunds(Exception):
    pass

def withdraw(balance, amount):
    if amount > balance:
        raise InsufficientFunds(f"short by {amount - balance}")
    return balance - amount

print(withdraw(100, 30))
try:
    withdraw(100, 130)
except InsufficientFunds as e:
    print("refused:", e)
```

*You should see:*

```text
70
refused: short by 30
```
<!-- /solution -->

**32.8 ★★★★ A safe calculator.** Read lines like `12 / 4`, `3 * x`, `5 / 0`; print the answer or a clear message for each
problem (a bad number, an unknown sign, dividing by zero, a wrong number of parts) — each
problem caught by its own `except`.

<!-- solution 32.8 -->
```python
def calc(line):
    parts = line.split()
    if len(parts) != 3:
        raise ValueError("write: NUMBER SIGN NUMBER")
    a, op, b = parts
    a, b = float(a), float(b)
    ops = {"+": a + b, "-": a - b, "*": a * b}
    if op == "/":
        return a / b
    if op not in ops:
        raise KeyError(op)
    return ops[op]

for line in ["12 / 4", "3 * x", "5 / 0", "2 ^ 3", "7"]:
    try:
        print(line, "=", calc(line))
    except ZeroDivisionError:
        print(line, ": cannot divide by zero")
    except KeyError as e:
        print(line, ": unknown sign", e)
    except ValueError as e:
        print(line, ":", e)
```

*You should see:*

```text
12 / 4 = 3.0
3 * x : could not convert string to float: 'x'
5 / 0 : cannot divide by zero
2 ^ 3 : unknown sign '^'
7 : write: NUMBER SIGN NUMBER
```
<!-- /solution -->
