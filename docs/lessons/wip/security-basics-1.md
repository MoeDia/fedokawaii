---
id: security-basics-1
title: Secrets stay out of the code
part: 2
minutes: 15
needs: [deployment-basics]
---
## idea
A secret is a key, a token or a password. Code gets copied, committed and shared, so a secret written in it travels everywhere the code goes, and a pushed secret must be treated as stolen. Keep secrets outside: the program asks the environment for them with os.environ.get("NAME"), and whoever runs it supplies the value. Never print a secret either; logs travel too. Print only what you need, such as its length. Treat all input the same way: text from outside is data, never a command.

## exercise
In ~/dojo/sec write key.py. It imports os and reads DOJO_KEY with os.environ.get. If it is missing it prints no key. Otherwise it prints key of N characters, N being the length. Try it with and without DOJO_KEY=abc123 in front of the command.

## check
```check
run: DOJO_KEY=abc123 python3 key.py
in: sec
expect: key of 6 characters
```

## answer
The value came from outside and only its length was printed.

```file key.py
import os

key = os.environ.get("DOJO_KEY")
if key is None:
    print("no key")
else:
    print("key of", len(key), "characters")
```
