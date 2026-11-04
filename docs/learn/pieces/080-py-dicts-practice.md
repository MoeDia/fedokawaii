---
id: py-dicts-practice
title: practice
part: python
chapter: 30
minutes: 18
needs: [py-contacts]
optional: no
---

**30.1 ★ Capitals.** Make a dictionary of four countries and their capitals and print each as `UAE → Abu Dhabi`.

<!-- solution 30.1 -->
```python
capitals = {"UAE": "Abu Dhabi", "Japan": "Tokyo", "Egypt": "Cairo", "France": "Paris"}
for country, capital in capitals.items():
    print(f"{country} → {capital}")
```

*You should see:*

```text
UAE → Abu Dhabi
Japan → Tokyo
Egypt → Cairo
France → Paris
```
<!-- /solution -->

**30.2 ★ Letter count.** Count each letter of `"banana"` with a dictionary and `.get`.
*Expected:* `{'b': 1, 'a': 3, 'n': 2}`.

<!-- solution 30.2 -->
```python
counts = {}
for ch in "banana":
    counts[ch] = counts.get(ch, 0) + 1
print(counts)
```

*You should see:*

```text
{'b': 1, 'a': 3, 'n': 2}
```
<!-- /solution -->

**30.3 ★ Unique visitors.** Given a list of names with repeats, print how many different people came, with a set.

<!-- solution 30.3 -->
```python
visits = ["sara", "omar", "sara", "lina", "omar", "sara"]
print(len(set(visits)))
```

*You should see:*

```text
3
```
<!-- /solution -->

**30.4 ★★ Price list total.** `prices = {"rice": 7.25, "tea": 12.5}`, `basket = {"rice": 3, "tea": 2}`: print the total.
*Expected:* `46.75`.

<!-- solution 30.4 -->
```python
prices = {"rice": 7.25, "tea": 12.5}
basket = {"rice": 3, "tea": 2}
total = 0
for item, n in basket.items():
    total += prices[item] * n
print(total)
```

*You should see:*

```text
46.75
```
<!-- /solution -->

**30.5 ★★ Invert a dictionary.** Turn `{"a": 1, "b": 2}` into `{1: "a", 2: "b"}`.

<!-- solution 30.5 -->
```python
d = {"a": 1, "b": 2}
inv = {}
for k, v in d.items():
    inv[v] = k
print(inv)
```

*You should see:*

```text
{1: 'a', 2: 'b'}
```
<!-- /solution -->

**30.6 ★★ Common friends.** Two people's friends as sets: print the friends they share, and those only the first has,
both sorted.

<!-- solution 30.6 -->
```python
sara = {"omar", "lina", "noor", "ali"}
omar = {"lina", "ali", "zaid"}
print(sorted(sara & omar))
print(sorted(sara - omar))
```

*You should see:*

```text
['ali', 'lina']
['noor', 'omar']
```
<!-- /solution -->
