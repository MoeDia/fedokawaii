---
id: function-arguments
title: Arguments give a function something to use
part: 2
minutes: 12
needs: [functions]
---
## idea
A function that always does the same thing is limited. Put a name between its brackets and the caller hands it a value. That name is a parameter inside the function, and the value you pass is the argument. Think of the commands you know: mkdir is a verb and the folder name is its noun.

```python
def hello(name):
    print("hello", name)

hello("Aiko")
hello("Ren")
```

A function may take several parameters, separated by commas. The arguments are matched in order.

## exercise
In ~/dojo/py write repeat.py. Define a function shout that takes text and times, and prints the text times times, each on its own line, using a for loop. Call shout("go", 3) and then shout("stop", 1).

## check
```check
run: python3 repeat.py
in: py
expect: go
expect: go
expect: go
expect: stop
```

## answer
The first argument goes to text, the second to times.

```file repeat.py
def shout(text, times):
    for i in range(times):
        print(text)

shout("go", 3)
shout("stop", 1)
```
