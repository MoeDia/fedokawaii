---
id: debugging-tools
title: The debugger is a door into the program
part: 2
minutes: 15
needs: [debugging-bisect]
---
## idea
A print shows what you thought to ask for. The debugger, pdb, lets you stop the program on a line and look at anything: p name prints a value, n runs the next line, c continues, q quits. Call breakpoint() where you want to stop. You can also feed it commands in a file or on the input, which is how this lesson checks it.

```python
x = 3
y = x * 2
breakpoint()
print(y)
```

## exercise
In ~/dojo/py write stop.py with the code above. Run it with commands on the input: printf 'p y\nc\n' | python3 stop.py. The p y asks for y while stopped, and c carries on.

## check
```check
run: printf 'p y\nc\n' | python3 stop.py 2>&1 | grep -c '^(Pdb) 6$'
in: py
expect: 2
```

## answer
Two lines show 6: the answer to p y, and the program's own print after c; grep counts them.

```file stop.py
x = 3
y = x * 2
breakpoint()
print(y)
```
