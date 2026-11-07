---
id: loops-2
title: Step through what happened
part: 2
minutes: 13
needs: [loops]
---
## idea
A loop often builds something as it goes: a total that grows, a count that climbs. Make the variable before the loop, change it inside, and use it after. while is the other loop: it repeats as long as its condition stays true, so something inside must eventually make it false, or it never ends (Ctrl+C stops it). To understand a loop, print the variable on each turn and read the steps.

```python
total = 0
for n in range(1, 4):
    total = total + n
    print(n, total)
```

That prints 1 1, then 2 3, then 3 6. The variable remembers what happened so far.

## exercise
In ~/dojo/py write sum.py. Use a for loop over range(1, 6) to add the numbers 1 to 5 into total, printing the number and the running total on every turn, then print the final total after the loop. Run it and read the five steps. Then change 6 to 11 and predict the final total before running.

## check
```check
run: python3 sum.py
in: py
expect: 1 1
expect: 2 3
expect: 3 6
expect: 4 10
expect: 5 15
expect: total 15
```

## answer
range(1, 6) gives 1 to 5, because the end is left out.

```file sum.py
total = 0
for n in range(1, 6):
    total = total + n
    print(n, total)
print("total", total)
```
