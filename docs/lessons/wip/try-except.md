---
id: try-except
title: Try one step, and catch its failure
part: 2
minutes: 12
needs: [errors-exceptions]
---
## idea
try runs a block. If an exception of the kind named in except happens, Python jumps to the except block instead of stopping. Catch the specific name you expect, never a bare except, or you will hide mistakes you did not expect. Use it where failure is normal: a file that may not exist, text that may not be a number.

```python
try:
    n = int("abc")
except ValueError:
    n = 0
print(n)
```

That prints 0. Lines after the failing one in the try block are skipped.

## exercise
In ~/dojo/py write safe.py. Define a function load that takes a path, tries to open it and returns its text, and when FileNotFoundError happens returns the word missing. Print load("notes.txt"), then load("nothing.txt"). Use the first line of notes.txt only: return f.readline().strip().

## check
```check
run: python3 safe.py
in: py
expect: one
expect: missing
```

## answer
notes.txt comes from day 18. If it is not there, make it again with printf.

```do
printf 'one\ntwo\nthree\n' > notes.txt
```

```file safe.py
def load(path):
    try:
        with open(path) as f:
            return f.readline().strip()
    except FileNotFoundError:
        return "missing"

print(load("notes.txt"))
print(load("nothing.txt"))
```
