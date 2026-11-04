---
id: py-generators-projects
title: projects
part: python
chapter: 37
minutes: 210
needs: [py-generators-practice]
optional: yes
---

**37.7 ★★★ Primes forever.** A generator of all prime numbers; print the first 15 with `islice`.

<!-- solution 37.7 -->
```python
from itertools import count, islice

def primes():
    found = []
    for n in count(2):
        if all(n % p for p in found if p * p <= n):
            found.append(n)
            yield n

print(list(islice(primes(), 15)))
```

*You should see:*

```text
[2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47]
```
<!-- /solution -->

**37.8 ★★★ A decorator that counts.** `@counted` adds a `.calls` counter to any function.

<!-- solution 37.8 -->
```python
from functools import wraps

def counted(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        wrapper.calls += 1
        return f(*args, **kwargs)
    wrapper.calls = 0
    return wrapper

@counted
def hello():
    return "hi"

for _ in range(3):
    hello()
print(hello.calls)
```

*You should see:*

```text
3
```
<!-- /solution -->

**37.9 ★★★ Words in a big file.** Without reading the whole file into memory, count how many lines of a file contain a word —
with a generator expression inside `sum`.

<!-- solution 37.9 -->
```python
from pathlib import Path

Path("big.txt").write_text("".join(f"line {i} {'rice' if i % 7 == 0 else 'tea'}\n" for i in range(1000)))
with open("big.txt", encoding="utf-8") as f:
    print(sum(1 for line in f if "rice" in line))
```

*You should see:*

```text
143
```
<!-- /solution -->

**37.10 ★★★★ Memoise by hand.** Write your own `memo` decorator (a dictionary from arguments to results) and show it makes
`fib(35)` fast. Compare with `functools.cache`.

<!-- solution 37.10 -->
```python
import time
from functools import wraps

def memo(f):
    seen = {}
    @wraps(f)
    def wrapper(*args):
        if args not in seen:
            seen[args] = f(*args)
        return seen[args]
    return wrapper

@memo
def fib(n):
    return n if n < 2 else fib(n - 1) + fib(n - 2)

t = time.perf_counter()
print(fib(35), time.perf_counter() - t < 0.05)
```

*You should see:*

```text
9227465 True
```
<!-- /solution -->
