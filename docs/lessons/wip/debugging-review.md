---
id: debugging-review
title: A month's bugs, together
part: 2
minutes: 15
needs: [debugging-tools]
---
## idea
Put the habits together on one program. Say what you expected, run it, read the last line of any error first, cut the problem in halves with a print, and fix one thing. The bug here is a word counter that counts "The" and "the" as two words.

```python
text = "The cat saw the dog"
counts = {}
for w in text.split():
    counts[w] = counts.get(w, 0) + 1
print(counts["the"])
```

Expected 2. Python says 1. The prints would show the keys: The and the, apart.

## exercise
In ~/dojo/py write wc.py with the code above and run it. Find the cause, then fix it by making each word lower case before it is counted.

## check
```check
run: python3 wc.py
in: py
expect: 2
```

## answer
w.lower() joins the two spellings into one key.

```file wc.py
text = "The cat saw the dog"
counts = {}
for w in text.split():
    w = w.lower()
    counts[w] = counts.get(w, 0) + 1
print(counts["the"])
```
