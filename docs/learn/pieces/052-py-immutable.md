---
id: py-immutable
title: strings never change; text and numbers
part: python
chapter: 26
minutes: 5
needs: [py-methods]
optional: no
---

## 26.4 strings never change

A string is **immutable**: once made, it cannot be changed. Every method gives back a *new*
string and leaves the old one alone:

```text
>>> s = "tea"
>>> s.upper()
'TEA'
>>> s
'tea'
>>> s = s.upper()
>>> s
'TEA'
```

*(to keep the change, point the name at the new string: `s = s.upper()`)*

```python
word = "cat"
word[0] = "b"
```

*Python says:*

```text
Traceback (most recent call last):
  File "example.py", line 2, in <module>
    word[0] = "b"
    ~~~~^^^
TypeError: 'str' object does not support item assignment
```

To change a letter, build a new string from pieces:

```text
>>> word = "cat"
>>> "b" + word[1:]
'bat'
```

## 26.5 text and numbers together

An f-string is the easy way. `str()` and `int()` change one into the other:

```python
count = 3
print("I have " + str(count) + " cats")
print(f"I have {count} cats")
year = "2026"
print(int(year) + 1)
```

*You should see:*

```text
I have 3 cats
I have 3 cats
2027
```

`ord` and `chr` go between a character and its number (its Unicode *code point*) — every
character has one, Arabic and kanji too:

```text
>>> ord("A")
65
>>> chr(66)
'B'
>>> ord("é")
233
>>> chr(0x732B)
'猫'
```
