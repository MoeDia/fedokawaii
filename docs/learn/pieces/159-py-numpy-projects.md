---
id: py-numpy-projects
title: projects
part: python
chapter: 41
minutes: 180
needs: [py-numpy-practice]
optional: yes
---

**41.7 ★★★ Matrix product by hand.** Write `matmul(A, B)` with three Python loops, and check it equals `A @ B` for random (3, 4) and
(4, 2) matrices (`np.allclose`).

<!-- solution 41.7 -->
```python
import numpy as np

def matmul(A, B):
    n, k = A.shape
    k2, m = B.shape
    assert k == k2
    C = np.zeros((n, m))
    for i in range(n):
        for j in range(m):
            for t in range(k):
                C[i, j] += A[i, t] * B[t, j]
    return C

rng = np.random.default_rng(2)
A, B = rng.normal(size=(3, 4)), rng.normal(size=(4, 2))
print(np.allclose(matmul(A, B), A @ B))
```

*You should see:*

```text
True
```
<!-- /solution -->

**41.8 ★★★ Least squares.** Fit a line `y = a·x + b` to noisy points (`x = np.linspace(0, 10, 50)`, `y = 3x + 2 + noise`) with
`np.polyfit(x, y, 1)`; then with the normal equations `np.linalg.solve(X.T @ X, X.T @ y)`.

<!-- solution 41.8 -->
```python
import numpy as np

rng = np.random.default_rng(3)
x = np.linspace(0, 10, 50)
y = 3 * x + 2 + rng.normal(0, 1, 50)
print(np.round(np.polyfit(x, y, 1), 2))
X = np.column_stack([x, np.ones_like(x)])
print(np.round(np.linalg.solve(X.T @ X, X.T @ y), 2))
```

*You should see:*

```text
[3.03 1.85]
[3.03 1.85]
```
<!-- /solution -->

**41.9 ★★★★ Game of Life, vectorised.** Write one step of Conway's Game of Life on a (n, n) array of 0/1 without Python loops: count
neighbours by adding the eight shifted copies (`np.roll`), then apply the rules with masks. Check
that a *blinker* (three in a row) flips between horizontal and vertical.

<!-- solution 41.9 -->
```python
import numpy as np

def step(b):
    n = sum(np.roll(np.roll(b, dy, 0), dx, 1)
            for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dy, dx) != (0, 0))
    return ((n == 3) | ((b == 1) & (n == 2))).astype(int)

b = np.zeros((5, 5), dtype=int)
b[2, 1:4] = 1
print(b[1:4, 1:4]); b = step(b); print(b[1:4, 1:4]); b = step(b); print(b[1:4, 1:4])
```

*You should see:*

```text
[[0 0 0]
 [1 1 1]
 [0 0 0]]
[[0 1 0]
 [0 1 0]
 [0 1 0]]
[[0 0 0]
 [1 1 1]
 [0 0 0]]
```
<!-- /solution -->
