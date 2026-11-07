---
id: comparisons
title: True and False
part: 2
minutes: 13
needs: [if-else]
---
## idea
Every condition is really a value: True or False. You can print a comparison to see it. The signs are == equal, != not equal, < less, > greater, <= and >=. A single = stores a value and a double == asks a question; mixing them up is the most common first mistake. Conditions join with and, or and not: and needs both true, or needs one, not turns one around.

```python
print(3 > 2)
print(3 == 4)
print(3 > 2 and 3 == 4)
```

That prints True, False, False. Strings compare too, in alphabet order: "a" < "b" is True.

## exercise
In ~/dojo/py write truth.py. Put 7 in a variable n. Print four comparisons, one per line: n equal to 7, n not equal to 7, n greater than 5 and less than 10, and n less than 5 or greater than 10. Guess the four answers first, then run it and see if you were right.

## check
```check
run: python3 truth.py
in: py
expect: True
expect: False
expect: True
expect: False
```

## answer
The last one is False because 7 is neither under 5 nor over 10.

```file truth.py
n = 7
print(n == 7)
print(n != 7)
print(n > 5 and n < 10)
print(n < 5 or n > 10)
```
