---
id: py-slicing
title: indexing, masks
part: python
chapter: 41
minutes: 5
needs: [py-shape]
optional: no
---

## 41.3 indexing and slicing

Like lists, but with one index per axis, separated by commas:

```text
>>> import numpy as np
>>> m = np.arange(12).reshape(3, 4)
>>> m
array([[ 0,  1,  2,  3],
       [ 4,  5,  6,  7],
       [ 8,  9, 10, 11]])
>>> m[1, 2]
np.int64(6)
>>> m[0]
array([0, 1, 2, 3])
>>> m[:, 1]
array([1, 5, 9])
>>> m[1:, 2:]
array([[ 6,  7],
       [10, 11]])
>>> m[::2, ::-1]
array([[ 3,  2,  1,  0],
       [11, 10,  9,  8]])
```

> **Careful.** A slice of an array is a **view**: the same numbers, seen through another
> window. Changing it changes the original. `.copy()` when you need your own.

```text
>>> import numpy as np
>>> a = np.arange(5)
>>> v = a[1:3]
>>> v[0] = 99
>>> a
array([ 0, 99,  2,  3,  4])
```

## 41.4 masks: choosing by condition

A comparison gives an array of `True`/`False` — a **mask** — and a mask chooses elements:

```text
>>> import numpy as np
>>> t = np.array([28, 35, 41, 22, 38])
>>> t > 30
array([False,  True,  True, False,  True])
>>> t[t > 30]
array([35, 41, 38])
>>> (t > 30).sum()
np.int64(3)
>>> np.where(t > 30, "hot", "ok")
array(['ok', 'hot', 'hot', 'ok', 'hot'], dtype='<U3')
>>> t[(t > 25) & (t < 40)]
array([28, 35, 38])
```

*(combine masks with `&` and `|`, in brackets — not `and`/`or`)*
