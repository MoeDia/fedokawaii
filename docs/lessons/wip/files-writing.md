---
id: files-writing
title: Writing something down
part: 2
minutes: 12
needs: [files-reading]
---
## idea
Open a file with "w" to write it. This makes the file, or empties it if it exists, so be careful. "a" adds to the end instead. write() puts exactly the text you give it, so add your own newline. A program that writes a file and a program that reads it can be different programs: the file is how they talk across time.

```python
with open("log.txt", "w") as f:
    f.write("first\n")
```

## exercise
In ~/dojo/py write save.py. Open squares.txt for writing and, for n from 1 to 5, write a line with n and its square, like 3 9. Then, still in save.py, open it again for reading and print the file whole with read().

## check
```check
run: python3 save.py
in: py
expect: 1 1
expect: 2 4
expect: 3 9
expect: 4 16
expect: 5 25
```

## answer
Close the writing block before reading, so everything is on disk first.

```file save.py
with open("squares.txt", "w") as f:
    for n in range(1, 6):
        f.write(f"{n} {n * n}\n")

with open("squares.txt") as f:
    print(f.read())
```
