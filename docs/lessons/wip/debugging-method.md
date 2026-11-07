---
id: debugging-method
title: A bug is found by method
part: 2
minutes: 15
needs: [reading-tracebacks]
---
## idea
A bug is a gap between what you expected and what happened. Do not guess and change things. Follow four steps: say what you expected, see what really happened, find the smallest place where the two part, change one thing there. If a change does not help, put it back; two guesses stacked on each other hide the cause.

```python
def average(nums):
    return sum(nums) / len(nums) + 1
print(average([2, 4, 6]))
```

You expected 4.0 and the program says 5.0. The gap is exactly 1, so look for a stray 1 before you suspect anything else.

## exercise
In ~/dojo/py write avg.py with the code above. Run it and see 5.0. Say aloud what you expected. Then remove the + 1 and run it again.

## check
```check
run: python3 avg.py
in: py
expect: 4.0
```

## answer
The gap was one constant, so the fix was one deletion.

```file avg.py
def average(nums):
    return sum(nums) / len(nums)
print(average([2, 4, 6]))
```
