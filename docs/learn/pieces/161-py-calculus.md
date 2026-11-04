---
id: py-calculus
title: check the calculus; handwritten digits
part: python
chapter: 43
minutes: 3
needs: [py-40-lines]
optional: no
---

## 43.4 check the calculus

Backward is where mistakes hide. Check any gradient by *nudging*: move one weight by a tiny
`eps` up and down, and see how the loss changes. The two numbers must agree.

```python
import numpy as np
rng = np.random.default_rng(1)
X = rng.normal(size=(5, 3)); y = np.array([0, 2, 1, 2, 0]); W = rng.normal(size=(3, 3))

def loss_and_grad(W):
    z = X @ W; z -= z.max(axis=1, keepdims=True)
    p = np.exp(z); p /= p.sum(axis=1, keepdims=True)
    loss = -np.log(p[np.arange(5), y]).mean()
    d = p.copy(); d[np.arange(5), y] -= 1
    return loss, X.T @ d / 5

loss, G = loss_and_grad(W)
eps = 1e-5
W[1, 2] += eps; up, _ = loss_and_grad(W)
W[1, 2] -= 2 * eps; down, _ = loss_and_grad(W)
print("by calculus", G[1, 2], " by nudging", (up - down) / (2 * eps))
```

```text
by calculus 0.036057134325191066  by nudging 0.03605713432275337
```

*(equal to nine digits: the backward pass is right)*

## 43.5 handwritten digits

scikit-learn ships 1 797 small pictures of handwritten digits, 8 × 8 pixels each:

```python
from sklearn.datasets import load_digits
d = load_digits()
X, y = d.data / 16.0, d.target          # 64 numbers from 0 to 1 per picture; the digit
print(X.shape, y[:10])
```

```text
(1797, 64) [0 1 2 3 4 5 6 7 8 9]
```
