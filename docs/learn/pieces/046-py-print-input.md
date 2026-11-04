---
id: py-print-input
title: print and input
part: python
chapter: 25
minutes: 6
needs: [py-variables]
optional: no
---

## 25.5 print: show something

In a file, nothing appears unless you `print` it. `print` takes any number of values,
separated by commas, and puts a space between them:

```python
name = "Mona"
age = 31
print("Hello")
print(name, age)
print("Next year", name, "will be", age + 1)
```

*You should see:*

```text
Hello
Mona 31
Next year Mona will be 32
```

The best way to put values into text is an **f-string**: an `f` before the quote, and names
or expressions inside `{ }`:

```python
item = "tea"
price = 8.5
count = 3
print(f"{count} × {item} cost {price * count} dirhams")
print(f"{price:.2f}")
print(f"{1234567:,}")
print(f"[{item:>6}]")
```

*You should see:*

```text
3 × tea cost 25.5 dirhams
8.50
1,234,567
[   tea]
```

| Inside `{ }` | Means | `x = 3.14159` gives |
|---|---|---|
| `{x}` | the value | `3.14159` |
| `{x:.2f}` | 2 digits after the point | `3.14` |
| `{x:8.2f}` | the same, 8 characters wide | `    3.14` |
| `{n:,}` | thousands with commas (`n = 1234567`) | `1,234,567` |
| `{s:>6}` | right-aligned in 6 characters | `   tea` for `s = "tea"` |

`print` has two useful settings: `sep` (what goes between the values) and `end` (what goes
at the end, normally a new line):

```python
print(2026, 10, 21, sep="-")
print("no new line here", end="")
print(" — continued")
```

*You should see:*

```text
2026-10-21
no new line here — continued
```

## 25.6 input: ask a question

`input("question ")` shows the question, waits for the person to type a line and press Enter,
and gives back what they typed — **always as text**:

```python
name = input("Your name? ")
print(f"Hello, {name}!")
```

*You should see:*

```text
Your name? Sara
Hello, Sara!
```

*(in these examples the typed answer is shown after the question, as you would see it)*

To use a typed number, change its type first:

```python
year = int(input("Born in? "))
print("This year you turn", 2026 - year)
```

*You should see:*

```text
Born in? 1990
This year you turn 36
```
