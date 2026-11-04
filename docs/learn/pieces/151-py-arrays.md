---
id: py-arrays
title: arrays
part: python
chapter: 41
minutes: 5
needs: [py-data-practice]
optional: no
---

> **In this chapter**
>
> - arrays: many numbers, one operation, no loop
> - shapes, indexing, slicing, and masks
> - broadcasting: arrays of different shapes working together
> - the maths of machine learning — sums, means, dot products, matrix products
>
> In a project: `uv add numpy`.

Python lists are flexible, but slow for numbers: each item is a full Python object, and every
operation is a Python loop. A **NumPy array** stores numbers packed side by side, all of one
type, and does each operation in compiled C — often a hundred times faster. Every machine
learning library (PyTorch included) is built on this idea, with the same vocabulary.

## 41.1 arrays

```text
>>> import numpy as np
>>> a = np.array([1, 2, 3, 4])
>>> a
array([1, 2, 3, 4])
>>> a * 10
array([10, 20, 30, 40])
>>> a + a
array([2, 4, 6, 8])
>>> a ** 2
array([ 1,  4,  9, 16])
>>> a.sum(), a.mean(), a.max()
(np.int64(10), np.float64(2.5), np.int64(4))
```

No loop: `a * 10` multiplies every element. Compare a list, where `*` repeats it:

```text
>>> import numpy as np
>>> [1, 2, 3] * 2
[1, 2, 3, 1, 2, 3]
>>> np.array([1, 2, 3]) * 2
array([2, 4, 6])
```

Making arrays:

```text
>>> import numpy as np
>>> np.zeros(3)
array([0., 0., 0.])
>>> np.ones((2, 3))
array([[1., 1., 1.],
       [1., 1., 1.]])
>>> np.arange(0, 10, 2)
array([0, 2, 4, 6, 8])
>>> np.linspace(0, 1, 5)
array([0.  , 0.25, 0.5 , 0.75, 1.  ])
>>> np.eye(3)
array([[1., 0., 0.],
       [0., 1., 0.],
       [0., 0., 1.]])
```
