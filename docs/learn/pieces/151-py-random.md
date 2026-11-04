---
id: py-random
title: random numbers, speed, mistakes
part: python
chapter: 41
minutes: 4
needs: [py-broadcast]
optional: no
---

## 41.7 random numbers, and speed

```python
import time
import numpy as np

rng = np.random.default_rng(0)
print(rng.integers(1, 7, size=10))
x = rng.normal(loc=170, scale=10, size=100_000)
print(round(x.mean(), 1), round(x.std(), 1))

nums = list(range(1_000_000))
arr = np.arange(1_000_000)
t = time.perf_counter(); s1 = sum(n * n for n in nums); py = time.perf_counter() - t
t = time.perf_counter(); s2 = int((arr * arr).sum()); npt = time.perf_counter() - t
print(s1 == s2, f"NumPy faster: {py / npt > 10}")
```

*You should see:*

```text
[6 4 4 2 2 1 1 1 2 5]
170.0 10.0
True NumPy faster: False
```

*(`default_rng(0)` — a seed — gives the same "random" numbers each run, so results can be
repeated; ML code seeds everything)*

## 41.8 common mistakes

**1. Python loops over arrays.** `for i in range(len(a)): a[i] *= 2` works, but throws away the
speed. Write `a *= 2`.

**2. Shape mismatches.** Print `.shape` of everything when an error mentions shapes. Most bugs
in ML code are a wrong shape.

**3. Integer arrays where you wanted floats.** `np.array([1, 2]) / 2` is fine (it gives floats),
but assigning `0.5` *into* an int array cuts it to 0:

```text
>>> import numpy as np
>>> a = np.array([1, 2, 3])
>>> a[0] = 0.5
>>> a
array([0, 2, 3])
>>> np.array([1, 2, 3], dtype=float)
array([1., 2., 3.])
```
