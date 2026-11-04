---
id: py-generators
title: generators
part: python
chapter: 37
minutes: 8
needs: [py-for-really]
optional: no
---

## 37.4 generators: values on demand

A function with `yield` instead of `return` is a **generator**. Calling it runs nothing yet;
it gives an iterator. Each `next` runs the body up to the next `yield`, hands out that value,
and *pauses* there until asked again:

```python
def count_up(limit):
    n = 1
    while n <= limit:
        print(f"  (making {n})")
        yield n
        n += 1

gen = count_up(3)
print("made the generator; nothing has run")
for value in gen:
    print("got", value)
```

*You should see:*

```text
made the generator; nothing has run
  (making 1)
got 1
  (making 2)
got 2
  (making 3)
got 3
```

Why it matters: a generator holds **one** value at a time, not all of them. It can walk a file
of a billion lines, or even go on forever, in almost no memory:

```python
import itertools

def fibonacci():
    a, b = 0, 1
    while True:
        yield a
        a, b = b, a + b

print(list(itertools.islice(fibonacci(), 12)))
```

*You should see:*

```text
[0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89]
```

*(`islice(it, 12)` takes the first 12 values and stops asking: the infinite generator is never
run to its end)*

A pipeline of generators, each passing values to the next — reading a log, keeping the errors,
taking their messages — with only one line in memory at a time:

```python
from pathlib import Path

Path("app.log").write_text("INFO start\nERROR disk full\nINFO retry\nERROR no network\n")

def lines(path):
    with open(path, encoding="utf-8") as f:
        for line in f:
            yield line.rstrip("\n")

def errors(rows):
    for row in rows:
        if row.startswith("ERROR"):
            yield row

def messages(rows):
    for row in rows:
        yield row.split(" ", 1)[1]

for m in messages(errors(lines("app.log"))):
    print(m)
```

*You should see:*

```text
disk full
no network
```
