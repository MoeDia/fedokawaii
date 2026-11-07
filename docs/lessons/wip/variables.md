---
id: variables
title: A name for a value
part: 2
minutes: 13
needs: [first-print]
---
## idea
Yesterday's print said a fixed word. A variable is a name that holds a value, so the program can say what the name holds. You make one with a single equals sign: the name on the left, the value on the right. Then you use the name where the value would go, without quotes. Quotes mean the words themselves; no quotes means the name.

```python
city = "Tokyo"
print(city)
```

A name can be given a new value later, and the next print shows the new one. Keys are names for actions; a variable is a name for a value.

## exercise
In ~/dojo/py write vars.py. Put your first name in a variable called name and print it. Below it, give name a different value and print it again. Run it: you see two lines, the old value first and then the new one. Notice that the first print does not change after the fact.

## check
```check
run: python3 vars.py
in: py
expect: Dia
expect: Moe
```

## answer
The program gives the name a value, prints, gives it another, and prints again.

```file vars.py
name = "Dia"
print(name)
name = "Moe"
print(name)
```
