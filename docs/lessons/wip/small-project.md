---
id: small-project
title: A small project from days 1 to 22
part: 2
minutes: 15
needs: [try-except]
---
## idea
Today you build a small tool with what you have: a function, a file, a dictionary, a loop and a try. The tool counts words in a text file and prints each word with how many times it appears, in the order first seen. Plan it in pieces before you type. One function reads the words, another prints the counts. Run after every piece.

## exercise
In ~/dojo/py make words.txt holding the line: red blue red green blue red. Write count.py. A function count_words(path) opens the file inside a try, returns an empty dictionary on FileNotFoundError, and otherwise returns a dictionary of each word and its count from read().split(). Loop over the dictionary and print each word and count, like red 3. Finally print count_words("none.txt").

## check
```check
run: python3 count.py
in: py
expect: red 3
expect: blue 2
expect: green 1
expect: {}
```

## answer
A dictionary keeps the order its words arrived in, so red, blue, green.

```do
printf 'red blue red green blue red\n' > words.txt
```

```file count.py
def count_words(path):
    counts = {}
    try:
        with open(path) as f:
            for word in f.read().split():
                counts[word] = counts.get(word, 0) + 1
    except FileNotFoundError:
        return {}
    return counts

for word, n in count_words("words.txt").items():
    print(word, n)
print(count_words("none.txt"))
```
