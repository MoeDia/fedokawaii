---
id: dictionaries
title: A small tool of data
part: 2
minutes: 13
needs: [loops-2]
---
## idea
A list finds things by place; a dictionary finds them by name. It holds pairs, a key and its value, between curly braces. You read a value with the key in square brackets, add or change one by assigning to a key, and loop with .items() to get both halves of every pair. Asking for a key that is not there is an error, so .get(key, other) gives other instead.

```python
keys = {"Super+V": "clipboard"}
keys["Super+U"] = "panel"
print(keys["Super+V"])
for key, job in keys.items():
    print(key, job)
```

A dictionary is a small database in one name.

## exercise
In ~/dojo/py write ages.py. Make a dictionary called ages with two people and their ages. Add a third person by assigning. Print one person's age by key. Then loop over .items() and print each as name is age. Finally print ages.get("Nobody", 0) to see the safe lookup.

## check
```check
run: python3 ages.py
in: py
expect: 11
expect: Dia is 11
expect: Moe is 30
expect: Ken is 7
expect: 0
```

## answer
Three pairs in order of insertion, then the safe lookup of a name that is missing.

```file ages.py
ages = {"Dia": 11, "Moe": 30}
ages["Ken"] = 7
print(ages["Dia"])
for name, age in ages.items():
    print(f"{name} is {age}")
print(ages.get("Nobody", 0))
```
