---
id: py-contacts
title: checkpoint: a contacts book
part: python
chapter: 30
minutes: 30
needs: [py-dicts-mistakes]
optional: no
---

## 30.9 checkpoint project — a contacts book

Level 2 in one program: functions, a list of commands, a dictionary of contacts, a loop
reading commands. Each command is one small function.

```python
def add(book, name, number):
    book[name] = number
    return f"added {name}"

def find(book, part):
    hits = []
    for name in book:
        if part.lower() in name.lower():
            hits.append(f"{name}: {book[name]}")
    return ", ".join(hits) or "nobody"

def show(book):
    lines = []
    for name in sorted(book):
        lines.append(f"{name:<8}{book[name]}")
    return "\n".join(lines) or "(empty)"

def delete(book, name):
    if name in book:
        del book[name]
        return f"deleted {name}"
    return f"no {name}"

book = {}
while True:
    words = input("> ").split()
    if not words:
        continue
    cmd = words[0]
    if cmd == "quit":
        break
    elif cmd == "add" and len(words) == 3:
        print(add(book, words[1], words[2]))
    elif cmd == "find" and len(words) == 2:
        print(find(book, words[1]))
    elif cmd == "list":
        print(show(book))
    elif cmd == "del" and len(words) == 2:
        print(delete(book, words[1]))
    else:
        print("commands: add NAME NUMBER · find TEXT · list · del NAME · quit")
```

*You should see:*

```text
> add Sara 050111
added Sara
> add Omar 055222
added Omar
> find sa
Sara: 050111
> list
Omar    055222
Sara    050111
> del Omar
deleted Omar
> list
Sara    050111
> quit
```

*(`", ".join(hits) or "nobody"` — `or` gives its right side when the left is empty or false:
a short way to say "this, or else that")*

> **Checkpoint.** Extend it: (1) each contact holds a dictionary `{"phone": …, "email": …}`
> instead of one number; (2) `add` refuses a name already there; (3) `count` prints how many
> contacts start with each letter. Write an `assert` for each function before you change it.
