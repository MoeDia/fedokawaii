---
id: py-dicts-mistakes
title: common mistakes
part: python
chapter: 30
minutes: 3
needs: [py-sets]
optional: no
---

## 30.8 common mistakes

**1. A list as a key.** Keys must be immutable; use a tuple:

```python
places = {}
places[[25, 55]] = "Dubai"
```

*Python says:*

```text
Traceback (most recent call last):
  File "example.py", line 2, in <module>
    places[[25, 55]] = "Dubai"
    ~~~~~~^^^^^^^^^^
TypeError: cannot use 'list' as a dict key (unhashable type: 'list')
```

```python
places = {}
places[(25.2, 55.3)] = "Dubai"
print(places)
```

*You should see:*

```text
{(25.2, 55.3): 'Dubai'}
```

**2. Expecting a set to keep order.** It does not; sort it when you show it:
`sorted(my_set)`.

**3. Changing a dictionary's size while looping over it.** Loop over `list(d)` instead:

```python
stock = {"rice": 2, "tea": 0, "milk": 0}
for item in list(stock):
    if stock[item] == 0:
        del stock[item]
print(stock)
```

*You should see:*

```text
{'rice': 2}
```
