---
id: py-methods
title: what a string can do
part: python
chapter: 26
minutes: 5
needs: [py-strings]
optional: no
---

## 26.3 methods: what a string can do

A **method** is a function that belongs to a value, called with a dot: `value.method()`.

```text
>>> s = "  Hello, World  "
>>> s.strip()
'Hello, World'
>>> s.lower()
'  hello, world  '
>>> s.upper()
'  HELLO, WORLD  '
>>> s.strip().replace("World", "Sharjah")
'Hello, Sharjah'
>>> "hello world".title()
'Hello World'
```

Asking questions about text:

```text
>>> name = "fedokawaii"
>>> name.startswith("fedo")
True
>>> name.endswith(".py")
False
>>> "kawa" in name
True
>>> name.count("a")
2
>>> name.find("kawa")
4
>>> "2026".isdigit()
True
```

Cutting text into pieces and gluing them back:

```text
>>> "rice,tea,milk".split(",")
['rice', 'tea', 'milk']
>>> "one two  three".split()
['one', 'two', 'three']
>>> "-".join(["2026", "10", "21"])
'2026-10-21'
>>> ", ".join(["rice", "tea"])
'rice, tea'
```

| Method | Does | `"a,b".…` |
|---|---|---|
| `.strip()` | removes spaces and new lines at both ends | |
| `.lower()` / `.upper()` | all small / all capital | |
| `.replace(a, b)` | every `a` replaced by `b` | `.replace(",", ";")` → `'a;b'` |
| `.split(sep)` | a list of the pieces between `sep` | `.split(",")` → `['a', 'b']` |
| `sep.join(list)` | the pieces glued with `sep` between | |
| `.startswith(x)` / `.endswith(x)` | `True` or `False` | |
| `.find(x)` | the index of `x`, or `-1` | `.find("b")` → `2` |
| `.count(x)` | how many times `x` appears | |
