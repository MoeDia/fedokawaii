---
id: scope
title: A name lives in a place
part: 2
minutes: 12
needs: [return-values]
---
## idea
A variable made inside a function belongs to that function. When the function ends, the name is gone. This is scope. It keeps functions from disturbing each other: two functions can both use a name like total without clashing. A name made at the top of the file can be read inside a function, but a function should not change it. If you want something out of a function, return it.

```python
def make():
    secret = 42

make()
print(secret)
```

That fails with NameError, because secret lived only inside make.

## exercise
In ~/dojo/py write scope.py. Define a function counted that sets total = 0, adds 1 three times in a loop and returns total. At the top level set total = 100 first, then call counted() and print its answer, then print total. Two different totals live side by side.

## check
```check
run: python3 scope.py
in: py
expect: 3
expect: 100
```

## answer
The total inside counted is a separate name from the one at the top.

```file scope.py
total = 100

def counted():
    total = 0
    for i in range(3):
        total = total + 1
    return total

print(counted())
print(total)
```
