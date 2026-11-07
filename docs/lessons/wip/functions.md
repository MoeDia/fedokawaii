---
id: functions
title: A function names a piece of work
part: 2
minutes: 12
needs: [review-1]
---
## idea
A function is a piece of work with a name. You write it once with def, then call it by name as often as you like. The lines inside are indented. Nothing inside runs until you call it. A call is the name followed by brackets.

```python
def hello():
    print("hello")

hello()
hello()
```

The def line ends with a colon, like if and for. Name a function after what it does, in small letters, with underscores between words.

## exercise
In ~/dojo/py write greet.py. Define a function greet that prints Welcome, then prints Have a good day. Call it three times at the bottom of the file. Run it and count the six lines.

## check
```check
run: python3 greet.py
in: py
expect: Welcome
expect: Have a good day
expect: Welcome
expect: Have a good day
expect: Welcome
expect: Have a good day
```

## answer
One definition, three calls. Change the text in one place and all three change.

```file greet.py
def greet():
    print("Welcome")
    print("Have a good day")

greet()
greet()
greet()
```
