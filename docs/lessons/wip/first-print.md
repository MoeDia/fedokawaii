---
id: first-print
title: The first thing the machine says for you
part: 2
minutes: 13
---
## idea
A program is a text file of orders the machine follows from top to bottom. The smallest useful order is print: it makes the machine say something. Python is already installed. A file ends in .py, and you run it with python3 and its name. Text goes between quotes, so Python can tell your words from its own.

```python
print("Hello")
```

One line, one order. Nothing happens until you run the file.

## exercise
Make the folder ~/dojo/py and go into it. In nvim, write a file called hello.py with one print order that says Konnichiwa. Save it and run it with python3 hello.py. Then add a second print line below it, with any word, and run it again: the lines come out in the order you wrote them.

## check
```check
run: python3 hello.py
in: py
expect: Konnichiwa
```

## answer
The file holds one order, and nothing else, so its output is exactly one line.

```file hello.py
print("Konnichiwa")
```
