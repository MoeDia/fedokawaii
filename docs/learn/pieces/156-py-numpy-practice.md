---
id: py-numpy-practice
title: practice
part: python
chapter: 41
minutes: 18
needs: [py-random]
optional: no
---

**41.1 ★ First array.** Make `np.arange(1, 11)` and print its sum, mean, and the squares of its even numbers.

<!-- solution 41.1 -->
```python
import numpy as np

a = np.arange(1, 11)
print(a.sum(), a.mean(), a[a % 2 == 0] ** 2)
```

*You should see:*

```text
55 5.5 [  4  16  36  64 100]
```
<!-- /solution -->

**41.2 ★ Celsius, all at once.** Convert `[20, 25, 31, 40]` to Fahrenheit with one array expression.

<!-- solution 41.2 -->
```python
import numpy as np

print(np.array([20, 25, 31, 40]) * 9 / 5 + 32)
```

*You should see:*

```text
[ 68.   77.   87.8 104. ]
```
<!-- /solution -->

**41.3 ★ Shapes.** Make a 4 × 5 array of 0…19; print its last column, its second row, and its shape after `.T`.

<!-- solution 41.3 -->
```python
import numpy as np

m = np.arange(20).reshape(4, 5)
print(m[:, -1], m[1], m.T.shape)
```

*You should see:*

```text
[ 4  9 14 19] [5 6 7 8 9] (5, 4)
```
<!-- /solution -->

**41.4 ★★ Normalise.** Scale each column of a 5 × 3 random array (seed 0) to mean 0 and standard deviation 1; check
with `.mean(axis=0)` and `.std(axis=0)`.

<!-- solution 41.4 -->
```python
import numpy as np

rng = np.random.default_rng(0)
x = rng.normal(5, 2, size=(5, 3))
z = (x - x.mean(axis=0)) / x.std(axis=0)
print(np.round(z.mean(axis=0), 6) + 0.0, np.round(z.std(axis=0), 6))
```

*You should see:*

```text
[0. 0. 0.] [1. 1. 1.]
```
<!-- /solution -->

**41.5 ★★ Distances.** Given 5 points as a (5, 2) array, the distance of each from (0, 0) without a loop
(`np.sqrt((p ** 2).sum(axis=1))`), and the nearest.

<!-- solution 41.5 -->
```python
import numpy as np

p = np.array([[3, 4], [1, 1], [-2, 0], [6, 8], [0, -1]])
d = np.sqrt((p ** 2).sum(axis=1))
print(np.round(d, 3), p[d.argmin()])
```

*You should see:*

```text
[ 5.     1.414  2.    10.     1.   ] [ 0 -1]
```
<!-- /solution -->

**41.6 ★★ Dice statistics.** Roll two dice 100 000 times (`rng.integers(1, 7, size=(100_000, 2))`), sum each pair, and count
how often each total 2–12 comes (`np.bincount`). Which is most common?

<!-- solution 41.6 -->
```python
import numpy as np

rng = np.random.default_rng(1)
totals = rng.integers(1, 7, size=(100_000, 2)).sum(axis=1)
counts = np.bincount(totals)[2:]
print(counts, "most common:", counts.argmax() + 2)
```

*You should see:*

```text
[ 2747  5634  8577 10999 13718 16619 13974 11198  8165  5622  2747] most common: 7
```
<!-- /solution -->
