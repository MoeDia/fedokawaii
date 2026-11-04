---
id: py-tools
title: generator expressions, zip and friends
part: python
chapter: 37
minutes: 5
needs: [py-generators]
optional: no
---

## 37.5 generator expressions

A comprehension in `( )` is a generator: nothing is built; values are made as `sum`, `max` or a
loop asks for them. Use it when you only need to pass over the values once:

```python
import sys

big_list = [n * n for n in range(1_000_000)]
lazy = (n * n for n in range(1_000_000))
print(sum(lazy))
print(sys.getsizeof(big_list) > 1_000_000, sys.getsizeof(lazy) < 1_000)
print(any(n > 5 for n in [1, 7, 3]), all(n > 0 for n in [1, 7, 3]))
```

*You should see:*

```text
333332833333500000
True True
True True
```

*(inside a call, the extra brackets can go: `sum(n * n for n in …)`)*

## 37.6 tools: zip, enumerate, sorted, itertools

```python
import itertools

names = ["Sara", "Omar", "Lina"]
scores = [88, 92, 79]
print(dict(zip(names, scores)))
print(max(zip(scores, names)))
print(list(itertools.pairwise([1, 4, 9, 16])))
print(list(itertools.batched("abcdefg", 3)))
print(list(itertools.combinations("ABC", 2)))
print(list(itertools.accumulate([1, 2, 3, 4])))
groups = itertools.groupby(sorted(["apple", "avocado", "banana"]), key=lambda w: w[0])
print({k: list(v) for k, v in groups})
```

*You should see:*

```text
{'Sara': 88, 'Omar': 92, 'Lina': 79}
(92, 'Omar')
[(1, 4), (4, 9), (9, 16)]
[('a', 'b', 'c'), ('d', 'e', 'f'), ('g',)]
[('A', 'B'), ('A', 'C'), ('B', 'C')]
[1, 3, 6, 10]
{'a': ['apple', 'avocado'], 'b': ['banana']}
```

| Tool | Gives |
|---|---|
| `zip(a, b)` | pairs, side by side |
| `enumerate(xs)` | (index, item) |
| `itertools.pairwise(xs)` | each item with the next |
| `itertools.batched(xs, n)` | pieces of `n` |
| `itertools.combinations(xs, k)` · `permutations` · `product` | choices, orders, every pairing |
| `itertools.accumulate(xs)` | running totals |
| `itertools.groupby(sorted_xs, key)` | runs of items with the same key |
| `itertools.chain(a, b)` | one after the other |
