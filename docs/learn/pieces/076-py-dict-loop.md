---
id: py-dict-loop
title: looping, counting and grouping
part: python
chapter: 30
minutes: 6
needs: [py-dict]
optional: no
---

## 30.4 looping over a dictionary

A loop over a dictionary gives its keys. `.items()` gives key and value together:

```python
ages = {"Sara": 31, "Omar": 28, "Lina": 35}
for name in ages:
    print(name)
for name, age in ages.items():
    print(f"{name} is {age}")
print(list(ages.values()), sum(ages.values()))
```

*You should see:*

```text
Sara
Omar
Lina
Sara is 31
Omar is 28
Lina is 35
[31, 28, 35] 94
```

*(a dictionary remembers the order keys were added in)*

Sorted by value — `key=` again, here a small `lambda` function that gives the age:

```python
ages = {"Sara": 31, "Omar": 28, "Lina": 35}
for name, age in sorted(ages.items(), key=lambda pair: pair[1]):
    print(name, age)
```

*You should see:*

```text
Omar 28
Sara 31
Lina 35
```

> **Word — lambda.** A tiny function without a name, written in one line:
> `lambda pair: pair[1]` is the same as `def f(pair): return pair[1]`.

## 30.5 counting and grouping

The job dictionaries do most: count how often each thing appears.

```python
text = "the cat and the dog and the bird"
counts = {}
for word in text.split():
    counts[word] = counts.get(word, 0) + 1
print(counts)
```

*You should see:*

```text
{'the': 3, 'cat': 1, 'and': 2, 'dog': 1, 'bird': 1}
```

The standard library's `Counter` does the same, and finds the most common:

```python
from collections import Counter

counts = Counter("the cat and the dog and the bird".split())
print(counts.most_common(2))
print(Counter("mississippi"))
```

*You should see:*

```text
[('the', 3), ('and', 2)]
Counter({'i': 4, 's': 4, 'p': 2, 'm': 1})
```

Grouping: a dictionary of lists.

```python
words = ["apple", "avocado", "banana", "blueberry", "cherry"]
by_letter = {}
for w in words:
    by_letter.setdefault(w[0], []).append(w)
print(by_letter)
```

*You should see:*

```text
{'a': ['apple', 'avocado'], 'b': ['banana', 'blueberry'], 'c': ['cherry']}
```

*(`setdefault(key, [])` gives the list for that key, making an empty one first if needed)*
