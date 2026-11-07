---
id: errors-exceptions
title: A failure has a name
part: 2
minutes: 12
needs: [paths-in-code]
---
## idea
An error in Python is an exception, and each has a name: NameError, ValueError when a value is wrong, FileNotFoundError, ZeroDivisionError and more. The name tells you what class of mistake it is. Your own code can raise one when it sees something wrong, instead of carrying on with bad data. Stopping early with a clear message is kind to whoever reads it next.

```python
def set_age(n):
    if n < 0:
        raise ValueError("age below zero")
    return n
```

## exercise
In ~/dojo/py write age.py. Define set_age as above, print set_age(30), then call set_age(-1) without catching it. Run python3 age.py 2>&1 | tail -1 and read the name and the message.

## check
```check
run: python3 age.py 2>&1 | tail -1
in: py
expect: ValueError: age below zero
```

## answer
The program printed 30, then stopped at the raise. Only the last line is kept here.

```file age.py
def set_age(n):
    if n < 0:
        raise ValueError("age below zero")
    return n

print(set_age(30))
print(set_age(-1))
```
