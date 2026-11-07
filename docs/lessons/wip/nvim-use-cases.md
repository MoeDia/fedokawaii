---
id: nvim-use-cases
title: Editing real files
part: 2
minutes: 20
needs: [nvim-moves, first-print]
---
## idea
Real work is finding things and changing many at once. Space Space opens a finder for the files of the project: type a few letters, Enter opens one. Space / searches the text of every file. Space , switches between files you have open. Space e shows the project as a tree.

To change a word everywhere in a file, use a command: :%s/old/new/g. The % means every line, g means every match on the line.

In a Python file, Space r f runs the file. gd goes to where a name is defined; Ctrl+O comes back.

Before a big change, let git hold your old version. That is what yesterday's lessons were for.

## exercise
In ~/dojo/py copy hello.py to hi.py with cp. Open hi.py in nvim and change the word Konnichiwa to Hello with :%s/Konnichiwa/Hello/g and Enter. Save with Ctrl+S, leave with :q, and run python3 hi.py.

## check
```check
run: python3 hi.py
in: py
expect: Hello
```

## answer
The copy changes; hello.py stays as it was.

```do
cp hello.py hi.py
sed -i 's/Konnichiwa/Hello/g' hi.py
```
