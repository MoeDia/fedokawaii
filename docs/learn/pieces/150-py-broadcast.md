---
id: py-broadcast
title: broadcasting, dot products
part: python
chapter: 41
minutes: 6
needs: [py-slicing]
optional: no
---

## 41.5 broadcasting

When two arrays of different shapes meet, NumPy stretches the smaller one along the missing
axis — without copying it. This is **broadcasting**:

```text
>>> import numpy as np
>>> m = np.array([[1, 2, 3], [4, 5, 6]])
>>> m + 10
array([[11, 12, 13],
       [14, 15, 16]])
>>> m + np.array([100, 200, 300])
array([[101, 202, 303],
       [104, 205, 306]])
>>> m - m.mean(axis=0)
array([[-1.5, -1.5, -1.5],
       [ 1.5,  1.5,  1.5]])
>>> m / m.sum(axis=1, keepdims=True)
array([[0.16666667, 0.33333333, 0.5       ],
       [0.26666667, 0.33333333, 0.4       ]])
```

The rule: compare shapes from the right; each pair must be equal, or one of them 1. `(2, 3)`
and `(3,)` fit (the row is repeated down); `(2, 3)` and `(2, 1)` fit (the column across);
`(2, 3)` and `(2,)` do not:

```text
>>> import numpy as np
>>> m = np.ones((2, 3))
>>> m + np.array([1, 2])
Traceback (most recent call last):
  File "<python-input-2>", line 1, in <module>
ValueError: operands could not be broadcast together with shapes (2,3) (2,)
```

## 41.6 dot products and matrices

Machine learning is mostly one operation: multiply and add — the **dot product**, and its big
brother the **matrix product** `@`:

```text
>>> import numpy as np
>>> w = np.array([0.5, -1.0, 2.0])
>>> x = np.array([4.0, 1.0, 0.5])
>>> w @ x
np.float64(2.0)
>>> (w * x).sum()
np.float64(2.0)
>>> X = np.array([[1, 2], [3, 4], [5, 6]])
>>> W = np.array([[1, 0, 1], [0, 1, 1]])
>>> (X @ W).shape
(3, 3)
>>> X @ W
array([[ 1,  2,  3],
       [ 3,  4,  7],
       [ 5,  6, 11]])
```

A matrix product `(3, 2) @ (2, 3)` gives `(3, 3)`: the inner sizes must match, and each element
is a row of the left times a column of the right. A neural network layer is exactly
`inputs @ weights + bias` (chapter 43).
