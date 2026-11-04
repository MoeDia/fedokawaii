---
id: py-while-for
title: while and for
part: python
chapter: 27
minutes: 8
needs: [py-if]
optional: no
---

## 27.3 while: repeat while true

`while` repeats its block as long as its question stays true:

```python
n = 1
while n <= 5:
    print(n)
    n += 1
print("done")
```

*You should see:*

```text
1
2
3
4
5
done
```

> **Careful.** If the question never becomes false, the loop runs forever. **Ctrl+C** stops a
> running program in the terminal.

A loop that asks until the answer is good:

```python
answer = input("A number? ")
while not answer.isdigit():
    print("that is not a number")
    answer = input("A number? ")
print("thanks:", int(answer))
```

*You should see:*

```text
A number? abc
that is not a number
A number? 42
thanks: 42
```

## 27.4 for: once for each thing

`for` takes each item of a collection in turn — the characters of a string, the items of a
list:

```python
for ch in "tea":
    print(ch)
for city in ["Sharjah", "Dubai", "Kyoto"]:
    print("I like", city)
```

*You should see:*

```text
t
e
a
I like Sharjah
I like Dubai
I like Kyoto
```

`range` gives numbers to loop over:

```text
>>> list(range(5))
[0, 1, 2, 3, 4]
>>> list(range(2, 6))
[2, 3, 4, 5]
>>> list(range(0, 20, 5))
[0, 5, 10, 15]
>>> list(range(5, 0, -1))
[5, 4, 3, 2, 1]
```

*(like slices: `range(2, 6)` stops before 6)*

```python
total = 0
for n in range(1, 101):
    total += n
print(total)
```

*You should see:*

```text
5050
```

*(the sum of 1 to 100. Gauss did it in his head as a boy: 50 pairs of 101)*

A loop inside a loop — a times table:

```python
for row in range(1, 4):
    for col in range(1, 4):
        print(f"{row * col:3}", end="")
    print()
```

*You should see:*

```text
  1  2  3
  2  4  6
  3  6  9
```
