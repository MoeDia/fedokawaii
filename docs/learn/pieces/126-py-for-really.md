---
id: py-for-really
title: what for really does
part: python
chapter: 37
minutes: 2
needs: [py-comprehensions]
optional: no
---

## 37.3 what for really does

A `for` loop works on anything **iterable**: lists, strings, dictionaries, files, `range`. It asks
the value for an **iterator** with `iter()`, then asks the iterator for one item at a time with
`next()`, until the iterator says *no more* (by raising `StopIteration`):

```text
>>> it = iter(["a", "b"])
>>> next(it)
'a'
>>> next(it)
'b'
>>> next(it)
Traceback (most recent call last):
  File "<python-input-3>", line 1, in <module>
StopIteration
```

That is all a `for` loop is: `iter` once, then `next` until `StopIteration`, which it catches
for you. An iterator is used up once it has given everything:

```text
>>> it = iter([1, 2, 3])
>>> list(it)
[1, 2, 3]
>>> list(it)
[]
```
