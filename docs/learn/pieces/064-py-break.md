---
id: py-break
title: break, continue, common mistakes
part: python
chapter: 27
minutes: 8
needs: [py-while-for]
optional: no
---

## 27.5 break and continue

`break` leaves the loop at once. `continue` skips the rest of this turn and goes to the next:

```python
for n in range(1, 10):
    if n == 5:
        break
    print(n, end=" ")
print()
for n in range(1, 10):
    if n % 3 == 0:
        continue
    print(n, end=" ")
print()
```

*You should see:*

```text
1 2 3 4 
1 2 4 5 7 8
```

A common shape: loop forever, and `break` when done:

```python
while True:
    item = input("item (q to stop)? ")
    if item == "q":
        break
    print("added", item)
```

*You should see:*

```text
item (q to stop)? tea
added tea
item (q to stop)? rice
added rice
item (q to stop)? q
```

## 27.6 common mistakes

**1. `=` where you meant `==`.**

```python
x = 5
if x = 5:
    print("five")
```

*Python says:*

```text
  File "example.py", line 2
    if x = 5:
       ^^^^^
SyntaxError: invalid syntax. Maybe you meant '==' or ':=' instead of '='?
```

**2. A missing colon, or a missing indent.**

```python
for i in range(3)
    print(i)
```

*Python says:*

```text
  File "example.py", line 1
    for i in range(3)
                     ^
SyntaxError: expected ':'
```

```python
for i in range(3):
print(i)
```

*Python says:*

```text
  File "example.py", line 2
    print(i)
    ^^^^^
IndentationError: expected an indented block after 'for' statement on line 1
```

**3. Changing the wrong variable in a while loop.** This loop would never end, because `i`
never grows — so here it is stopped after three turns with `break`:

```python
i = 0
turns = 0
while i < 3:
    turns += 1
    print("turn", turns, "i is still", i)
    if turns == 3:
        break
```

*You should see:*

```text
turn 1 i is still 0
turn 2 i is still 0
turn 3 i is still 0
```

The fix is `i += 1` inside the loop.

**4. Off by one.** `range(10)` is 0 to 9 — ten numbers, but not 10. If you want 1 to 10,
write `range(1, 11)`.
