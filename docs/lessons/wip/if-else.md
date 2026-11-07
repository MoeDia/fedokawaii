---
id: if-else
title: A program that chooses
part: 2
minutes: 13
needs: [input]
---
## idea
Until now every line ran, every time. if makes a line run only when a condition is true, and else says what to do otherwise. The line with if ends in a colon, and the lines that belong to it are indented by four spaces. The indent is not decoration: it is how Python knows which lines belong to the choice. A menu offers choices; if chooses.

```python
age = 15
if age >= 18:
    print("adult")
else:
    print("young")
```

Only one of the two prints runs. The condition age >= 18 asks a question and the answer is yes or no.

## exercise
In ~/dojo/py write door.py. Read a number with input() and int, the way ask.py did. If it is 18 or more, print open; otherwise print closed. Run it three times by hand with 5, 18 and 40, and say aloud which answer you expect before each run.

## check
```check
run: printf '18\n' | python3 door.py
in: py
expect: open
```

## answer
18 or more is open, so 18 itself counts: the sign is >=, not >.

```file door.py
age = int(input())
if age >= 18:
    print("open")
else:
    print("closed")
```
