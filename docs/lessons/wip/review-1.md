---
id: review-1
title: Review of days 1 to 11, nothing new
part: 2
minutes: 13
needs: [dictionaries]
---
## idea
Nothing new today. You have met ten tools: print, variables, numbers, strings, input, if and else, comparisons, lists, loops and dictionaries. Real programs are these same tools put side by side. When you are stuck, do it in tiny steps: write one line, run it, see what it says, then write the next. Printing a variable in the middle shows what the program thinks, which is usually not what you thought.

## exercise
In ~/dojo/py write review.py with no help. Make a dictionary of three desks and how many windows each has. Loop over it. For every desk print its name and windows; if it has more than 2 windows, print busy after it on the same line, otherwise quiet. Finish by printing the total number of windows. Build it in steps, running after every line you add.

## check
```check
run: python3 review.py
in: py
expect: code 3 busy
expect: web 1 quiet
expect: games 2 quiet
expect: total 6
```

## answer
A dictionary, a loop, a choice inside the loop, and a running total: four earlier lessons in one file.

```file review.py
desks = {"code": 3, "web": 1, "games": 2}
total = 0
for name, windows in desks.items():
    total = total + windows
    if windows > 2:
        print(f"{name} {windows} busy")
    else:
        print(f"{name} {windows} quiet")
print("total", total)
```
