---
id: py-aliases
title: two names, one list; common mistakes
part: python
chapter: 29
minutes: 5
needs: [py-nested]
optional: no
---

## 29.7 two names, one list

This surprises everyone once. `=` does not copy a list; it gives the same list a second name:

```python
a = [1, 2, 3]
b = a
b.append(4)
print(a)
c = a.copy()
c.append(5)
print(a, c)
```

*You should see:*

```text
[1, 2, 3, 4]
[1, 2, 3, 4] [1, 2, 3, 4, 5]
```

*(`b = a` — one list, two names: change it through `b` and `a` sees it too. `.copy()` (or
`list(a)`, or `a[:]`) makes a second list)*

## 29.8 common mistakes

**1. Index out of range.**

```python
items = ["a", "b", "c"]
print(items[3])
```

*Python says:*

```text
Traceback (most recent call last):
  File "example.py", line 2, in <module>
    print(items[3])
          ~~~~~^^^
IndexError: list index out of range
```

**2. Saving the result of `.sort()`.** It sorts in place and returns `None`:

```python
nums = [3, 1, 2]
result = nums.sort()
print(result, nums)
```

*You should see:*

```text
None [1, 2, 3]
```

**3. Changing a list while looping over it.** Items get skipped. Loop over a copy, or build a
new list:

```python
nums = [1, 2, 2, 3]
for n in nums:
    if n == 2:
        nums.remove(n)
print("wrong:", nums)
nums = [1, 2, 2, 3]
kept = []
for n in nums:
    if n != 2:
        kept.append(n)
print("right:", kept)
```

*You should see:*

```text
wrong: [1, 2, 3]
right: [1, 3]
```
