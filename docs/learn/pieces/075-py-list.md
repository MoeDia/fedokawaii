---
id: py-list
title: a list, and changing it
part: python
chapter: 29
minutes: 6
needs: [py-functions-practice]
optional: no
---

> **In this chapter**
>
> - lists: many values, in order, that you can change
> - add, remove, sort, search
> - loop over a list with its index (`enumerate`) or with another list (`zip`)
> - tuples: lists that never change

## 29.1 a list

A **list** holds many values in order, inside `[ ]`, separated by commas. It indexes and
slices exactly like a string (chapter 26):

```text
>>> fruits = ["apple", "banana", "cherry"]
>>> len(fruits)
3
>>> fruits[0]
'apple'
>>> fruits[-1]
'cherry'
>>> fruits[1:]
['banana', 'cherry']
>>> "banana" in fruits
True
```

A list can hold any values, even a mix — but one kind per list is easier to work with:

```text
>>> scores = [72, 95, 61]
>>> empty = []
>>> sum(scores), max(scores), min(scores)
(228, 95, 61)
>>> len(empty)
0
```

## 29.2 changing a list

Unlike a string, a list can be changed in place — it is **mutable**:

```text
>>> todo = ["shop", "cook"]
>>> todo.append("clean")
>>> todo
['shop', 'cook', 'clean']
>>> todo.insert(0, "wake up")
>>> todo
['wake up', 'shop', 'cook', 'clean']
>>> todo[1] = "shop for rice"
>>> todo
['wake up', 'shop for rice', 'cook', 'clean']
>>> todo.remove("cook")
>>> todo
['wake up', 'shop for rice', 'clean']
>>> last = todo.pop()
>>> last
'clean'
>>> todo
['wake up', 'shop for rice']
```

| Method | Does |
|---|---|
| `.append(x)` | adds `x` at the end |
| `.insert(i, x)` | puts `x` at index `i`, pushing the rest along |
| `.remove(x)` | removes the first `x` (an error if there is none) |
| `.pop()` · `.pop(i)` | removes and gives back the last item · the one at `i` |
| `.extend(other)` | adds every item of another list |
| `.index(x)` | the index of the first `x` |
| `.count(x)` | how many times `x` is in it |
| `.sort()` · `.reverse()` | sorts · reverses, in place |
