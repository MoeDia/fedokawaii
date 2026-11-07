---
id: variables
title: A name for a value
part: 2
minutes: 14
needs: [first-print]
standard: 2
---
## remember
```quiz
q: What does print("Hi") write?
a: Hi
```

## example
The book you are reading, then the next one:

```python
book = "Dune"
print(book)
book = "Emma"
print(book)
```
```output
Dune
Emma
```

The same line, print(book), wrote two different words.

## idea
A variable is a name that holds a value. One equals sign gives it a value: the name on the left, the value on the right.

```term variable
a name that holds a value; a new value replaces the old one
```
```term value
a piece of data, such as text in quotes or a number
```
```term assignment
one equals sign: the value on its right goes into the name on its left
```

After that, the name stands for its value. Without quotes, book means the variable. With quotes, "book" is just the word book. Give the name a new value, and the next print shows the new one. The print before it already happened. It does not change.

## exercise
Warm-up: Predict first. Read these three lines. Write down the two lines you expect them to print.

```python
name = "Dia"
print("name")
print(name)
```

Then check. Open a terminal with [[Super+Return]], type cd ~/dojo/py and press [[Enter]]. Then type this line exactly, single quotes too, and press [[Enter]]. It runs the three lines as one, joined by semicolons.

```bash
python3 -c 'name = "Dia"; print("name"); print(name)'
```

Real: In ~/dojo/py, type nvim vars.py and press [[Enter]]. Press i to type. Give a variable called name the value "Dia", and print it. Below, give name the value "Moe", and print it again. Press [[Esc]], type :wq and press [[Enter]]. Run python3 vars.py: Dia comes first, then Moe.

Stretch: Find the bug without running it. This file stops with an error. Which line, and why?

```python
city = "Tokyo"
print(City)
```

```hint
Four lines: give a value, print, give a new value, print.
```
```hint
The first two lines are name = "Dia" and print(name).
```

## check
```check
run: python3 vars.py
in: py
expect: Dia
expect: Moe
```

## answer
The program gives the name a value, prints, gives it another, and prints again.

```file vars.py
name = "Dia"
print(name)
name = "Moe"
print(name)
```

## behind
Python keeps a table of names. An assignment writes a row in it: the name, and an arrow to its value. A new value for the same name moves the arrow. The old value can be thrown away once no name points at it.

```picture
<svg viewBox="0 0 400 120" role="img" aria-label="the name book points at Dune, then its arrow moves to Emma">
<rect class="line" x="8" y="44" width="80" height="32" rx="4"/><text class="ink" x="48" y="65" text-anchor="middle">book</text>
<g data-step="1"><path class="soft" d="M90 60L230 30"/><text class="ink" x="240" y="35">"Dune"</text></g>
<g data-step="2"><path class="mark" d="M90 60L230 90"/><text class="mark" x="240" y="95">"Emma"</text></g>
</svg>
```

Look the name book up in that table yourself:

```peek
python3 -c 'book = "Dune"; print(globals()["book"])'
```

## mistakes
- Quotes around the name: print("book") writes the word book, not the variable.
- Two equals signs: book == "Dune" asks whether they are equal. It puts nothing in book.
- A capital letter: Book and book are two different names.

## quiz
```quiz
q: book = "Dune", then book = "Emma". What does print(book) write?
a: Emma
q: What does print("book") write?
a: book
q: Which side of the equals sign holds the name?
a: the left
```

## next
Next: numbers, and the arithmetic Python does with them.

## checked
- The Python Tutorial, 3.14: https://docs.python.org/3.14/tutorial/introduction.html
- Assignment statements, 3.14: https://docs.python.org/3.14/reference/simple_stmts.html
