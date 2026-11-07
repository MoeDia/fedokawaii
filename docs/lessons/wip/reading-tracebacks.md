---
id: reading-tracebacks
title: An error is read from its last line
part: 2
minutes: 12
needs: [function-arguments]
---
## idea
When Python fails it prints a traceback: the path the program took, then the error. Read the last line first. It names the kind of error and says what went wrong. The lines above it tell you the file and the line number where it happened. You met the same habit in the shell: the end of an error says what is wrong.

```python
total = 5
print(totl)
```

The last line says NameError: name 'totl' is not defined, and Python even guesses what you meant. A NameError almost always means a typo or a name used before it was made. The line above shows which line to fix.

## exercise
In ~/dojo/py write broken.py with exactly the two lines above, typo included. Run it and read the last line first. Then run python3 broken.py 2>&1 | tail -1 to see only that line.

## check
```check
run: python3 broken.py 2>&1 | tail -1
in: py
expect: NameError: name 'totl' is not defined. Did you mean: 'total'?
```

## answer
The line above the error even points at the word with ^ marks.

```file broken.py
total = 5
print(totl)
```
