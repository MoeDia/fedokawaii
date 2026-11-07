---
id: loops
title: a loop
part: 2
minutes: 15
---
## idea
`for` does a thing for each.

## exercise
In `~/dojo/hello`, write `loop.py`: it prints 1, then 2.

## check
```check
run: python3 loop.py
in: hello
expect: 1
expect: 2
```

## answer
```file loop.py
for i in (1, 2):
    print(i)
```
