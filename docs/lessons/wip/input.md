---
id: input
title: Read the user's answer
part: 2
minutes: 13
needs: [text]
---
## idea
So far the program knew everything in advance. input("question ") stops, shows the question, waits for the user to type a line and press Enter, and gives back what they typed. Keep it in a variable, as with any value. What comes back is always a string, even when the user types digits. To count with it, wrap it in int: int("12") is the number 12.

```python
who = input("name? ")
print(f"hello {who}")
```

The bar answers you; here the program asks, and you answer.

## exercise
In ~/dojo/py write ask.py. Ask "name? " and keep the answer. Ask "years? " and turn the answer into a number with int. Print one line: the name, a space, and the years plus one. Run it by hand and type your own answers. The check feeds it two lines for you; the questions print without a newline, so they run together in its output.

## check
```check
run: printf 'Dia\n11\n' | python3 ask.py
in: py
expect: name? years? Dia 12
```

## answer
int turns the typed text into a number, so adding 1 works; without it Python would refuse.

```file ask.py
name = input("name? ")
years = int(input("years? "))
print(f"{name} {years + 1}")
```
