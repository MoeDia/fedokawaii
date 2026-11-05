---
id: py-lists-practice
title: practice
part: python
chapter: 29
minutes: 18
needs: [py-aliases]
optional: no
---

**29.1 ★ The middle.** Print the middle item of `[4, 8, 15, 16, 23]` using `len` and `//`.
*Expected:* `15`.

<!-- solution 29.1 -->
```python
nums = [4, 8, 15, 16, 23]
print(nums[len(nums) // 2])
```

*You should see:*

```text
15
```
<!-- /solution -->

**29.2 ★ Average.** Write `average(nums)` with `sum` and `len`, and print the average of `[72, 95, 61]`.
*Expected:* `76.0`.

<!-- solution 29.2 -->
```python
def average(nums):
    return sum(nums) / len(nums)

print(average([72, 95, 61]))
```

*You should see:*

```text
76.0
```
<!-- /solution -->

**29.3 ★ Shopping list.** Start with an empty list, append three items, remove one, print the list sorted.

<!-- solution 29.3 -->
```python
shop = []
shop.append("tea")
shop.append("rice")
shop.append("milk")
shop.remove("tea")
print(sorted(shop))
```

*You should see:*

```text
['milk', 'rice']
```
<!-- /solution -->

**29.4 ★★ Only the long words.** Given `words = ["a", "kawaii", "dwl", "fedora", "is"]`, build a list of words longer than 3
letters, with a loop.
*Expected:* `['kawaii', 'fedora']`.

<!-- solution 29.4 -->
```python
words = ["a", "kawaii", "dwl", "fedora", "is"]
long_words = []
for w in words:
    if len(w) > 3:
        long_words.append(w)
print(long_words)
```

*You should see:*

```text
['kawaii', 'fedora']
```
<!-- /solution -->

**29.5 ★★ Second largest.** Write `second_largest(nums)` without sorting: one loop, two variables.
*Expected:* `[3, 9, 4, 9, 7]` → `7`: the largest value *different* from the largest.

<!-- solution 29.5 -->
```python
def second_largest(nums):
    first = second = None
    for n in nums:
        if first is None or n > first:
            first, second = n, first
        elif n != first and (second is None or n > second):
            second = n
    return second

print(second_largest([3, 9, 4, 9, 7]))
```

*You should see:*

```text
7
```
<!-- /solution -->

**29.6 ★★ Report card.** With `names` and `scores` lists, print each name with its score and `pass` (60+) or `fail`,
using `zip`.

<!-- solution 29.6 -->
```python
names = ["Sara", "Omar", "Lina"]
scores = [88, 52, 79]
for name, score in zip(names, scores):
    print(f"{name:<5}{score:>4}  {'pass' if score >= 60 else 'fail'}")
```

*You should see:*

```text
Sara   88  pass
Omar   52  fail
Lina   79  pass
```
<!-- /solution -->
