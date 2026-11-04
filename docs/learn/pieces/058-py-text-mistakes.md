---
id: py-text-mistakes
title: common mistakes
part: python
chapter: 26
minutes: 3
needs: [py-immutable]
optional: no
---

## 26.6 common mistakes

**1. Forgetting that methods return a new string.**

```python
name = "  sara "
name.strip()
print(f"[{name}]")
```

*You should see:*

```text
[  sara ]
```

The spaces are still there: the stripped string was made and thrown away. Write
`name = name.strip()`.

**2. An index past the end.**

```python
s = "abc"
print(s[3])
```

*Python says:*

```text
Traceback (most recent call last):
  File "example.py", line 2, in <module>
    print(s[3])
          ~^^^
IndexError: string index out of range
```

*(the last index of a 3-letter string is 2; slices never complain: `s[1:99]` is `'bc'`)*

**3. Comparing a typed number with a number.** `"10" == 10` is `False`: text is never equal to
a number. Change the type first.

```text
>>> "10" == 10
False
>>> int("10") == 10
True
```
