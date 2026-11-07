---
id: lists
title: One name for many things
part: 2
minutes: 13
needs: [comparisons]
---
## idea
A list keeps several values under one name, in order, between square brackets. You reach one by its place, counting from zero: the first is [0], the second [1], and [-1] is the last. len gives how many there are, .append adds one at the end, and in asks whether something is inside, which answers True or False, as in the last lesson.

```python
desks = ["code", "web", "games"]
desks.append("music")
print(desks[0], len(desks))
print("web" in desks)
```

That prints code 4 and then True. Nine desks, one name.

## exercise
In ~/dojo/py write shelf.py. Make a list called books with three titles of your choice. Add a fourth with append. Print the last one using [-1], then print how many there are, then print whether "Dune" is in the list. Run it. Change one title to Dune and run it again to see the last line turn True.

## check
```check
run: python3 shelf.py
in: py
expect: Emma
expect: 4
expect: False
```

## answer
Four titles, none of them Dune, so the last line is False.

```file shelf.py
books = ["Kokoro", "Snow Country", "Sanshiro"]
books.append("Emma")
print(books[-1])
print(len(books))
print("Dune" in books)
```
