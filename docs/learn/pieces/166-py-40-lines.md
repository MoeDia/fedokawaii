---
id: py-40-lines
title: the whole network, in 40 lines
part: python
chapter: 43
minutes: 7
needs: [py-compute]
optional: no
---

## 43.3 the whole network, in 40 lines

```python
# mlp.py — a two-layer neural network in NumPy alone: forward, loss, backward, update
import numpy as np

rng = np.random.default_rng(0)

def spiral(n=100, k=3):
    """n points in each of k arms of a spiral: X is (n*k, 2), y the arm of each point"""
    X, y = [], []
    for c in range(k):
        r = np.linspace(0.0, 1.0, n)
        t = np.linspace(c * 4, (c + 1) * 4, n) + rng.normal(0, 0.2, n)
        X.append(np.c_[r * np.sin(t), r * np.cos(t)])
        y.append(np.full(n, c))
    return np.vstack(X), np.concatenate(y)

X, y = spiral()
N, D, H, K = X.shape[0], 2, 64, 3

W1 = rng.normal(0, 1, (D, H)) * np.sqrt(2 / D); b1 = np.zeros(H)
W2 = rng.normal(0, 1, (H, K)) * np.sqrt(2 / H); b2 = np.zeros(K)
lr = 0.5

for step in range(3001):
    # forward
    h = np.maximum(0, X @ W1 + b1)                  # ReLU
    logits = h @ W2 + b2
    logits -= logits.max(axis=1, keepdims=True)     # (for numerical safety)
    p = np.exp(logits); p /= p.sum(axis=1, keepdims=True)
    loss = -np.log(p[np.arange(N), y]).mean()
    # backward: the gradient of the loss with respect to every number above
    dlogits = p.copy(); dlogits[np.arange(N), y] -= 1; dlogits /= N
    dW2 = h.T @ dlogits; db2 = dlogits.sum(axis=0)
    dh = dlogits @ W2.T; dh[h <= 0] = 0
    dW1 = X.T @ dh; db1 = dh.sum(axis=0)
    # update: a small step downhill
    for P, G in ((W1, dW1), (b1, db1), (W2, dW2), (b2, db2)):
        P -= lr * G
    if step % 500 == 0:
        acc = (p.argmax(axis=1) == y).mean()
        print(f"step {step:4d}  loss {loss:.3f}  accuracy {acc:.2f}")
```

```text
$ uv run mlp.py
step    0  loss 1.033  accuracy 0.29
step  500  loss 0.116  accuracy 0.98
step 1000  loss 0.075  accuracy 0.99
step 1500  loss 0.059  accuracy 0.99
step 2000  loss 0.050  accuracy 0.99
step 2500  loss 0.044  accuracy 0.99
step 3000  loss 0.040  accuracy 0.99
```

At step 0 it guesses (29 %: about one in three); by step 500 it has learnt the spiral.
