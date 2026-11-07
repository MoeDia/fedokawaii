---
id: files-reading
title: Reading a file
part: 2
minutes: 12
needs: [scope]
---
## idea
Programs mostly deal with files. open gives you the file, and with closes it again when its block ends. read() returns all of the text as one string. Looping over the file gives one line at a time, each with its newline at the end, which strip() removes.

```python
with open("notes.txt") as f:
    for line in f:
        print(line.strip())
```

The name is relative to where you run the program, so run it from the folder that holds the file.

## exercise
In ~/dojo/py make notes.txt with three lines of your own: run printf 'one\ntwo\nthree\n' > notes.txt. Then write read.py: open notes.txt, and for each line print its number from 1 and the stripped line, like 1 one. Use enumerate(f, 1) in the for.

## check
```check
run: python3 read.py
in: py
expect: 1 one
expect: 2 two
expect: 3 three
```

## answer
enumerate pairs each line with a count that starts where you tell it.

```do
printf 'one\ntwo\nthree\n' > notes.txt
```

```file read.py
with open("notes.txt") as f:
    for number, line in enumerate(f, 1):
        print(number, line.strip())
```
