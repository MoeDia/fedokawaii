---
id: first-print
title: a program that says hello
part: 2
minutes: 15
needs: [the-panel]
---
## idea
A program is a file of orders. `print` is the first: it writes its words.

```python
print("hello")
```

## exercise
In `~/dojo/hello`, write `hello.py` so that it prints hello, and run it.

## check
```check
run: python3 hello.py
in: hello
expect: hello
```

## answer
Make the folder, then the file:

```do
mkdir -p ~/dojo/hello
```

```file hello.py
print("hello")
```
