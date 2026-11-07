---
id: text
title: Text is a value too
part: 2
minutes: 13
needs: [numbers]
---
## idea
Words between quotes are called a string. A string is a value like a number, with its own tools. len gives its length, .upper() makes it capital letters, and + joins two strings into one. A number cannot be joined to a string directly, so str turns it into text first. The easiest way to put values into a sentence is an f-string: an f before the quote, and any name inside curly braces is replaced by its value.

```python
desk = 4
print(f"desk {desk} is for {'games'.upper()}")
```

Each desk has one thing; a string has one meaning. Together they make a sentence.

## exercise
In ~/dojo/py write say.py. Make two variables: word with the value "moon" and count with the number 3. Print word in capital letters. On the next line use an f-string to print the sentence: 3 moon. Then, on a third line, print the length of word. Run it and compare each line with what you expected.

## check
```check
run: python3 say.py
in: py
expect: MOON
expect: 3 moon
expect: 4
```

## answer
The f-string puts both values into one line, and len counts the four letters.

```file say.py
word = "moon"
count = 3
print(word.upper())
print(f"{count} {word}")
print(len(word))
```
