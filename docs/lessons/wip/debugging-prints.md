---
id: debugging-prints
title: Make the program say what it does
part: 2
minutes: 15
needs: [debugging-method]
---
## idea
When you cannot see where the values go wrong, make the program tell you. A print placed inside the loop shows each step. Put the name of the value in the print so you can tell your lines from the real output, and take them out once the bug is found.

```python
total = 0
for n in [1, 2, 3]:
    total = n
    print("n", n, "total", total)
print(total)
```

The prints show total being set to n, never added to. The expected 6 is 3.

## exercise
In ~/dojo/py write sumup.py with the code above, run it and read the lines. Then change total = n to total += n and remove the print inside the loop.

## check
```check
run: python3 sumup.py
in: py
expect: 6
```

## answer
total = n throws the old total away on each turn; += keeps it.

```file sumup.py
total = 0
for n in [1, 2, 3]:
    total += n
print(total)
```
