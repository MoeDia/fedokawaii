---
id: py-sorting
title: sorting, looping over lists
part: python
chapter: 29
minutes: 6
needs: [py-list]
optional: no
---

## 29.3 sorting

`.sort()` sorts the list itself; `sorted(list)` makes a new sorted list and leaves the old
one alone:

```text
>>> nums = [5, 2, 9, 1]
>>> sorted(nums)
[1, 2, 5, 9]
>>> nums
[5, 2, 9, 1]
>>> nums.sort(reverse=True)
>>> nums
[9, 5, 2, 1]
>>> words = ["banana", "Apple", "cherry"]
>>> sorted(words)
['Apple', 'banana', 'cherry']
>>> sorted(words, key=str.lower)
['Apple', 'banana', 'cherry']
>>> sorted(words, key=len)
['Apple', 'banana', 'cherry']
```

*(capitals sort before small letters; `key=` says what to sort by: here, the word in small
letters, or its length)*

## 29.4 looping over lists

```python
prices = [3.5, 12.0, 7.25]
total = 0
for p in prices:
    total += p
print("total", total)
```

*You should see:*

```text
total 22.75
```

`enumerate` gives the index and the item together; `zip` walks two lists side by side:

```python
names = ["Sara", "Omar", "Lina"]
scores = [88, 92, 79]
for i, name in enumerate(names, start=1):
    print(i, name)
for name, score in zip(names, scores):
    print(f"{name:<5} {score}")
```

*You should see:*

```text
1 Sara
2 Omar
3 Lina
Sara  88
Omar  92
Lina  79
```

Building a new list from an old one, the long way (chapter 37 shows the short way):

```python
celsius = [20, 25, 31, 40]
fahrenheit = []
for c in celsius:
    fahrenheit.append(c * 9 / 5 + 32)
print(fahrenheit)
```

*You should see:*

```text
[68.0, 77.0, 87.8, 104.0]
```
