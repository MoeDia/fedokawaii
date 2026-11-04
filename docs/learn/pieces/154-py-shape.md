---
id: py-shape
title: shape and dtype
part: python
chapter: 41
minutes: 4
needs: [py-arrays]
optional: no
---

## 41.2 shape and dtype

Every array has a **shape** (its size along each axis) and a **dtype** (the type of every
element):

```text
>>> import numpy as np
>>> m = np.array([[1, 2, 3], [4, 5, 6]])
>>> m.shape
(2, 3)
>>> m.ndim, m.size, m.dtype
(2, 6, dtype('int64'))
>>> m.reshape(3, 2)
array([[1, 2],
       [3, 4],
       [5, 6]])
>>> m.T
array([[1, 4],
       [2, 5],
       [3, 6]])
>>> np.arange(12).reshape(3, 4)
array([[ 0,  1,  2,  3],
       [ 4,  5,  6,  7],
       [ 8,  9, 10, 11]])
```

| Term | `m` above |
|---|---|
| `shape` | `(2, 3)`: 2 rows, 3 columns |
| `ndim` | 2 axes |
| `size` | 6 elements |
| `dtype` | `int64` (whole numbers); `float32`/`float64` for decimals |
| `T` | the transpose: rows become columns |

> **Word — axis.** One direction of an array. In a table, axis 0 runs down the rows, axis 1
> across the columns. `m.sum(axis=0)` sums *down* (one total per column).

```text
>>> import numpy as np
>>> m = np.array([[1, 2, 3], [4, 5, 6]])
>>> m.sum()
np.int64(21)
>>> m.sum(axis=0)
array([5, 7, 9])
>>> m.sum(axis=1)
array([ 6, 15])
>>> m.mean(axis=0)
array([2.5, 3.5, 4.5])
```
