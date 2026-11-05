---
id: py-if
title: True, False, if
part: python
chapter: 27
minutes: 7
needs: [py-numbers-practice, py-text-practice]
optional: no
---

> **In this chapter**
>
> - `True` and `False`, and the comparisons that make them
> - `if`, `elif`, `else`: do something only sometimes
> - `while` and `for`: do something many times
> - `break` and `continue`; `range`
> - the checkpoint for level 1: a guessing game

## 27.1 True and False

A **comparison** asks a question and gets a `bool`: `True` or `False`.

```text
>>> 5 > 3
True
>>> 5 == 3
False
>>> 5 != 3
True
>>> 4 <= 4
True
>>> "apple" < "banana"
True
```

| Sign | Asks |
|---|---|
| `==` | equal? (two signs — one `=` makes a variable) |
| `!=` | not equal? |
| `<` `>` `<=` `>=` | smaller, larger, or equal too |

Combine questions with `and`, `or`, `not`:

```text
>>> age = 20
>>> age >= 18 and age < 65
True
>>> age < 13 or age > 60
False
>>> not age > 18
False
>>> 13 <= age <= 19
False
```

*(the last line is Python's short way to ask "between 13 and 19?")*

## 27.2 if, elif, else

`if` runs its block only when the question is `True`. The block is the **indented** lines
under it — four spaces:

```python
temperature = 38
if temperature > 35:
    print("too hot")
    print("stay inside")
print("this line always runs")
```

*You should see:*

```text
too hot
stay inside
this line always runs
```

`else` is what to do otherwise; `elif` (*else if*) asks another question. Python checks them
from the top and runs **only the first** that is true:

```python
score = 72
if score >= 90:
    grade = "A"
elif score >= 75:
    grade = "B"
elif score >= 60:
    grade = "C"
else:
    grade = "F"
print("grade:", grade)
```

*You should see:*

```text
grade: C
```

**Truthy and falsy.** In an `if`, Python treats `0`, `0.0`, `""` (empty text), and empty
collections as false; everything else as true:

```python
name = ""
if name:
    print("hello", name)
else:
    print("no name given")
```

*You should see:*

```text
no name given
```
