---
id: py-strings
title: making strings, indexing, slicing
part: python
chapter: 26
minutes: 7
needs: [py-numbers-practice]
optional: no
---

> **In this chapter**
>
> - strings: making them, joining them, cutting pieces out of them
> - the string methods you will use every day
> - why text cannot be changed in place, and what to do instead

Most data you will ever handle is text: names, files, web pages, messages to a model. Python
calls a piece of text a **string** (`str`): a row of characters, in order.

## 26.1 making strings

Single or double quotes — the same thing. Choose the one that is not inside the text:

```text
>>> 'hello'
'hello'
>>> "it's here"
"it's here"
>>> 'she said "yes"'
'she said "yes"'
>>> len("hello")
5
>>> len("")
0
```

Three quotes make a string that spans lines. `\n` inside a string is a new line, `\t` a tab:

```python
poem = """old pond
a frog jumps in
the sound of water"""
print(poem)
print("one\ntwo\tthree")
```

*You should see:*

```text
old pond
a frog jumps in
the sound of water
one
two	three
```

> **Word — escape.** A `\` with a letter after it, standing for a character you cannot type
> in a string directly: `\n` new line, `\t` tab, `\\` a backslash, `\"` a double quote.

## 26.2 indexing and slicing

Each character has a position, its **index**, counted **from 0**. Negative indexes count from
the end:

```text
 K   y   o   t   o
 0   1   2   3   4
-5  -4  -3  -2  -1
```

```text
>>> city = "Kyoto"
>>> city[0]
'K'
>>> city[4]
'o'
>>> city[-1]
'o'
>>> city[-2]
't'
```

A **slice** `[start:stop]` takes from `start` up to *but not including* `stop`. Leave one out
for "from the beginning" or "to the end":

```text
>>> word = "fedokawaii"
>>> word[0:4]
'fedo'
>>> word[4:]
'kawaii'
>>> word[:4]
'fedo'
>>> word[-3:]
'aii'
>>> word[::2]
'fdkwi'
>>> word[::-1]
'iiawakodef'
```

*(`[::-1]` steps backwards: the string reversed)*

The rule *up to but not including* has a nice result: `word[:4] + word[4:]` is always the
whole word.
