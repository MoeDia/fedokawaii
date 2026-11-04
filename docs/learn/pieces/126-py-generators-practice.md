---
id: py-generators-practice
title: practice
part: python
chapter: 37
minutes: 18
needs: [py-functools]
optional: no
---

**37.1 ★ Squares of evens.** With one comprehension, the squares of the even numbers from 1 to 20.

<!-- solution 37.1 -->
```python
print([n * n for n in range(1, 21) if n % 2 == 0])
```

*You should see:*

```text
[4, 16, 36, 64, 100, 144, 196, 256, 324, 400]
```
<!-- /solution -->

**37.2 ★ Lengths.** `{word: len(word)}` for the words of a sentence, as a dictionary comprehension.

<!-- solution 37.2 -->
```python
s = "simple is better than complex"
print({w: len(w) for w in s.split()})
```

*You should see:*

```text
{'simple': 6, 'is': 2, 'better': 6, 'than': 4, 'complex': 7}
```
<!-- /solution -->

**37.3 ★ Flatten.** Turn `[[1, 2], [3], [4, 5, 6]]` into `[1, 2, 3, 4, 5, 6]` with one comprehension (two `for`s).

<!-- solution 37.3 -->
```python
nested = [[1, 2], [3], [4, 5, 6]]
print([x for row in nested for x in row])
```

*You should see:*

```text
[1, 2, 3, 4, 5, 6]
```
<!-- /solution -->

**37.4 ★★ Countdown generator.** `countdown(n)` yields n, n−1, … 1. Use it in a `for`, and with `list()`.

<!-- solution 37.4 -->
```python
def countdown(n):
    while n > 0:
        yield n
        n -= 1

for x in countdown(3):
    print(x, end=" ")
print(list(countdown(5)))
```

*You should see:*

```text
3 2 1 [5, 4, 3, 2, 1]
```
<!-- /solution -->

**37.5 ★★ Matrix transpose.** Transpose `[[1, 2, 3], [4, 5, 6]]` with a comprehension — then with `zip(*m)`.

<!-- solution 37.5 -->
```python
m = [[1, 2, 3], [4, 5, 6]]
print([[row[i] for row in m] for i in range(len(m[0]))])
print([list(col) for col in zip(*m)])
```

*You should see:*

```text
[[1, 4], [2, 5], [3, 6]]
[[1, 4], [2, 5], [3, 6]]
```
<!-- /solution -->

**37.6 ★★ Running average.** A generator `running_avg(nums)` yielding the average so far after each number.
*Expected:* `[2, 4, 6]` → `2.0 3.0 4.0`.

<!-- solution 37.6 -->
```python
def running_avg(nums):
    total = 0
    for i, n in enumerate(nums, 1):
        total += n
        yield total / i

print(*running_avg([2, 4, 6]))
```

*You should see:*

```text
2.0 3.0 4.0
```
<!-- /solution -->
