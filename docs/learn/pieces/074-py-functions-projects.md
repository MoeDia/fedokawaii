---
id: py-functions-projects
title: projects
part: python
chapter: 28
minutes: 180
needs: [py-functions-practice]
optional: yes
---

**28.7 ★★★ Power without **.** Write `power(base, exp)` with a loop (exp a whole number ≥ 0), then again with recursion.
Assert both against `**`.

<!-- solution 28.7 -->
```python
def power_loop(base, exp):
    result = 1
    for _ in range(exp):
        result *= base
    return result

def power_rec(base, exp):
    if exp == 0:
        return 1
    return base * power_rec(base, exp - 1)

for b, e in [(2, 10), (3, 0), (5, 3)]:
    assert power_loop(b, e) == b ** e == power_rec(b, e)
print(power_loop(2, 10), power_rec(5, 3))
```

*You should see:*

```text
1024 125
```
<!-- /solution -->

**28.8 ★★★ Grade.** `grade(score)` returns A (90+), B (75+), C (60+) or F, and refuses scores outside 0–100 with
`assert 0 <= score <= 100`.

<!-- solution 28.8 -->
```python
def grade(score):
    assert 0 <= score <= 100, "score must be 0-100"
    if score >= 90:
        return "A"
    if score >= 75:
        return "B"
    if score >= 60:
        return "C"
    return "F"

print([grade(s) for s in (95, 80, 61, 12)])
```

*You should see:*

```text
['A', 'B', 'C', 'F']
```
<!-- /solution -->

**28.9 ★★★★ Fibonacci, two ways.** `fib(n)`: 0, 1, 1, 2, 3, 5, 8 … (each the sum of the two before). Write it with recursion,
then with a loop, and print `fib(30)` with each. Which is slower, and why? (The recursive one
works out the same values again and again: over a million calls for 30.)

<!-- solution 28.9 -->
```python
import time

def fib_rec(n):
    if n < 2:
        return n
    return fib_rec(n - 1) + fib_rec(n - 2)

def fib_loop(n):
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    return a

print(fib_loop(30), fib_rec(30))
t = time.perf_counter(); fib_rec(25); slow = time.perf_counter() - t
t = time.perf_counter(); fib_loop(25); fast = time.perf_counter() - t
print("the loop is faster:", fast < slow)
```

*You should see:*

```text
832040 832040
the loop is faster: True
```
<!-- /solution -->
