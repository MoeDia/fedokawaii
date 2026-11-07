---
id: loops
title: Do it again, and again
part: 2
minutes: 13
needs: [lists]
---
## idea
for repeats the lines under it, once for each item of a list. On each turn the name after for holds the next item. As with if, the line ends in a colon and the repeated lines are indented. range(n) is a list-like of the numbers 0 up to n minus one, which is how you repeat something n times.

```python
for desk in ["code", "web"]:
    print(desk)
for i in range(3):
    print(i)
```

The first loop prints code and web, the second prints 0, 1 and 2. Paste history again and again; a loop does again and again.

## exercise
In ~/dojo/py write each.py. Take the list books from last time (type three titles again). Write a for loop that prints each title with its length, like Kokoro 6. Run it. Then add a line after the loop, not indented, that prints done, and see that it runs once, because it is outside the loop.

## check
```check
run: python3 each.py
in: py
expect: Kokoro 6
expect: Emma 4
expect: done
```

## answer
The last print has no indent, so it belongs to the file and not to the loop.

```file each.py
books = ["Kokoro", "Emma"]
for title in books:
    print(f"{title} {len(title)}")
print("done")
```
