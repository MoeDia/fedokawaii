---
id: return-values
title: A function can answer
part: 2
minutes: 12
needs: [reading-tracebacks]
---
## idea
print shows something on the screen and is gone. return hands a value back to the caller, who can keep it in a variable, print it, or use it in another calculation. Like a question: the function is asked, and it answers. A function that never reaches a return answers None, which means nothing.

```python
def double(n):
    return n * 2

x = double(4)
print(x)
```

The call double(4) is replaced by its answer, 8. After return the function stops: lines below it do not run.

## exercise
In ~/dojo/py write area.py. Define a function area that takes width and height and returns their product. Store area(3, 4) in a variable and print it. On the next line print area(5, 5) + 1.

## check
```check
run: python3 area.py
in: py
expect: 12
expect: 26
```

## answer
area(5, 5) is 25, and the call can sit inside a sum like any value.

```file area.py
def area(width, height):
    return width * height

x = area(3, 4)
print(x)
print(area(5, 5) + 1)
```
