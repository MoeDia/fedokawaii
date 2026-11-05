---
id: py-functools
title: functools
part: python
chapter: 37
minutes: 6
needs: [py-tools]
optional: no
---

## 37.7 functools: tools for functions

`functools.cache` remembers a function's answers: the second call with the same arguments is
instant. It turns chapter 28's slow recursive Fibonacci fast:

```python
from functools import cache, reduce, partial
import time

@cache
def fib(n):
    return n if n < 2 else fib(n - 1) + fib(n - 2)

t = time.perf_counter()
print(fib(200))
print("fast:", time.perf_counter() - t < 0.1)

print(reduce(lambda a, b: a * b, [1, 2, 3, 4, 5]))
base2 = partial(int, base=2)
print(base2("1010"))
```

*You should see:*

```text
280571172992510140037611932413038677189525
fast: True
120
10
```

> **Word — decorator.** `@cache` above a `def` is a **decorator**: a function that takes your
> function and gives back an improved one. `@dataclass` (chapter 34) and `@pytest.fixture`
> (chapter 35) are decorators too.

A decorator of your own — one that times any function:

```python
import time
from functools import wraps

def timed(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = f(*args, **kwargs)
        print(f"{f.__name__} took {time.perf_counter() - start:.1f} s")
        return result
    return wrapper

@timed
def slow_sum(n):
    return sum(range(n))

print(slow_sum(1_000_000))
```

*You should see:*

```text
slow_sum took 0.0 s
499999500000
```

*(`*args` and `**kwargs` catch any positional and keyword arguments and pass them on, so the
wrapper fits any function)*

## 37.8 common mistakes

**1. Using an iterator twice.** The second pass finds it empty (see `list(it)` above). If you
need the values twice, make a list: `values = list(gen)`.

**2. A comprehension for its side effects.** `[print(x) for x in xs]` builds a list of `None`s
for nothing. Use a plain `for` loop for doing; comprehensions for building.

**3. `return` in a generator.** It ends the generator; the value is not handed out. Use
`yield`.
