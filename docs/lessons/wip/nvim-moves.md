---
id: nvim-moves
title: The editor's moves
part: 2
minutes: 20
needs: [nvim-his-config]
---
## idea
In normal mode you move and change text by saying a small sentence. h j k l are left, down, up, right. w jumps a word forward, b back. 0 goes to the line's start, $ to its end. gg is the top of the file, G the bottom.

Your line numbers show the distance to the others, so 5j goes down exactly five lines.

The changing keys: x deletes a letter. dd deletes a whole line and keeps it, p puts it back below the cursor. yy copies a line. u undoes, Ctrl+R redoes. A number first repeats: 3dd deletes three lines.

dd then p is how you move a line. Do it slowly; u is always there.

## exercise
In ~/dojo/nv write sort.txt with three lines: c, a, b. Now, using only dd and p, put them in the order a, b, c. Hint: c is on top and belongs at the bottom. Save with Ctrl+S, leave with :q.

## check
```check
run: cat sort.txt
in: nv
expect: a
expect: b
expect: c
```

## answer
Put the cursor on c, press dd, go to b with j, press p. Written out, the file ends as this.

```file sort.txt
a
b
c
```
