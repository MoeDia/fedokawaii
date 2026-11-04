---
id: py-functions-practice
title: practice
part: python
chapter: 28
minutes: 18
needs: [py-functions-mistakes]
optional: no
---

**28.1 ★ Square.** Write `square(n)` returning `n * n`; assert it for 0, 3 and -4.

<!-- solution 28.1 -->
```python
def square(n):
    return n * n

assert square(0) == 0
assert square(3) == 9
assert square(-4) == 16
print("ok")
```

*You should see:*

```text
ok
```
<!-- /solution -->

**28.2 ★ Greeting.** Write `greeting(name, hour)` returning `Good morning, NAME` before 12 and `Good evening, NAME`
from 12 on.

<!-- solution 28.2 -->
```python
def greeting(name, hour):
    if hour < 12:
        return f"Good morning, {name}"
    return f"Good evening, {name}"

print(greeting("Sara", 9))
print(greeting("Sara", 20))
```

*You should see:*

```text
Good morning, Sara
Good evening, Sara
```
<!-- /solution -->

**28.3 ★ Is even.** Write `is_even(n)` returning `True` or `False`, in one line of body.

<!-- solution 28.3 -->
```python
def is_even(n):
    return n % 2 == 0

print(is_even(4), is_even(7))
```

*You should see:*

```text
True False
```
<!-- /solution -->

**28.4 ★★ Pay with overtime.** `pay(hours, rate)`: hours over 40 are paid 1.5 × the rate. Assert three cases.
*Expected:* rate 10: 30 h → `300`, 40 h → `400`, 45 h → `475.0`.

<!-- solution 28.4 -->
```python
def pay(hours, rate):
    if hours <= 40:
        return hours * rate
    return 40 * rate + (hours - 40) * rate * 1.5

assert pay(30, 10) == 300
assert pay(40, 10) == 400
assert pay(45, 10) == 475
print(pay(30, 10), pay(40, 10), pay(45, 10))
```

*You should see:*

```text
300 400 475.0
```
<!-- /solution -->

**28.5 ★★ Clamp.** `clamp(x, low=0, high=100)` returns `x`, but never below `low` or above `high`.

<!-- solution 28.5 -->
```python
def clamp(x, low=0, high=100):
    if x < low:
        return low
    if x > high:
        return high
    return x

print(clamp(150), clamp(-5), clamp(42), clamp(7, high=5))
```

*You should see:*

```text
100 0 42 5
```
<!-- /solution -->

**28.6 ★★ Reverse words.** `reverse_words("one two three")` returns `"three two one"`.

<!-- solution 28.6 -->
```python
def reverse_words(text):
    return " ".join(text.split()[::-1])

assert reverse_words("one two three") == "three two one"
print(reverse_words("one two three"))
```

*You should see:*

```text
three two one
```
<!-- /solution -->
