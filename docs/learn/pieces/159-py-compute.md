---
id: py-compute
title: what a network computes
part: python
chapter: 43
minutes: 5
needs: [py-numpy-practice]
optional: no
---

> **In this chapter**
>
> - arrays: many numbers worked on at once
> - what a neural network computes: forward, loss, backward, update
> - train one on a spiral and on handwritten digits, with no AI library at all
>
> This chapter is level 6's checkpoint: when your network
> reads digits, the Python course is done.

Before PyTorch does it for you, do it once by hand. Every model in the news — the largest
language models included — learns by the four steps in this chapter, repeated billions of times.

```text
$ uv init nn && cd nn
$ uv add numpy scikit-learn
$ uv add --dev pytest
```

## 43.1 arrays

```text
>>> import numpy as np
>>> a = np.array([1.0, 2.0, 3.0])
>>> a * 10
array([10., 20., 30.])
>>> M = np.array([[1, 2], [3, 4]])
>>> M.shape, M.T
((2, 2), array([[1, 3],
       [2, 4]]))
>>> M @ np.array([1, 1])
array([3, 7])
>>> M.sum(axis=0), M.max(axis=1)
(array([4, 6]), array([2, 4]))
```

*(`@` multiplies matrices: each row of `M` times the vector, summed. `axis=0` works down the
columns, `axis=1` along the rows)*

> **Word — tensor.** An array of any number of dimensions: a number (0), a list (1), a table
> (2), a stack of tables (3) … A batch of 64 colour pictures is a 4-dimensional tensor: 64 ×
> 3 × height × width. Neural networks are made of tensor arithmetic.

**Broadcasting** stretches a smaller array to fit: a table (100 × 3) plus a row (3) adds the
row to every line. It is how one line of NumPy does what a loop would do a hundred times — and
fast, because the loop runs in C.

## 43.2 what a network computes

A two-layer network turns an input `x` (here 2 numbers: a point's position) into a score for
each class (3: which arm of a spiral it is on):

```text
h      = max(0, x @ W1 + b1)     a hidden layer: 64 numbers, negatives cut to 0 (ReLU)
scores = h @ W2 + b2             3 scores, one per class
p      = softmax(scores)         the scores as probabilities that add up to 1
loss   = -log(p[right class])    small when the right class got a high probability
```

Training is four steps, again and again:

| Step | Does |
|---|---|
| **forward** | compute the scores and the loss for the data |
| **backward** | compute how the loss would change if each weight moved a little: its **gradient** |
| **update** | move every weight a small step against its gradient: downhill |
| **repeat** | until the loss stops falling |

> **Word — gradient.** For each weight, the slope of the loss: how much the loss rises when the
> weight rises a little. Step the other way and the loss falls. **Backpropagation** computes all
> the gradients at once with the chain rule, from the loss backwards.
