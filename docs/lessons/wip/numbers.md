---
id: numbers
title: Numbers share work by a rule
part: 2
minutes: 13
needs: [variables]
---
## idea
A number has no quotes. Python does arithmetic with + for adding, - for taking away, * for times and / for divided by. Two more are worth knowing: // gives the whole part of a division, and % gives what is left over. Seven shared among two is 3 whole, with 1 left over: 7 // 2 is 3 and 7 % 2 is 1.

```python
apples = 7
print(apples // 2)
print(apples % 2)
```

A number kept in a variable works the same as a number typed in place. The rule is the same one every time, whatever the numbers are.

## exercise
In ~/dojo/py write sharing.py. Put the number 17 in a variable called sweets and the number 5 in a variable called friends. Print how many sweets each friend gets, then how many are left over. Run it. Then change sweets to 20 and run it again, and see how only one line of your code had to change.

## check
```check
run: python3 sharing.py
in: py
expect: 3
expect: 2
```

## answer
17 shared among 5 is 3 whole sweets each, and 2 are left over.

```file sharing.py
sweets = 17
friends = 5
print(sweets // friends)
print(sweets % friends)
```
