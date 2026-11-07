---
id: nvim-never-stuck
title: Never stuck in the editor
part: 2
minutes: 15
needs: [git-remote]
---
## idea
Neovim has modes. In normal mode the keys are commands, not letters. Press i and you are in insert mode, where keys type text. Esc always brings you back to normal. When lost, press Esc twice: you are in normal mode, and every way out starts there.

Three ways out, all typed in normal mode: the colon opens a command line. :w saves, :q leaves, :q! leaves and throws your changes away. Your config adds one key: Ctrl+S saves from any mode and returns you to normal.

Space is your menu. Press it and wait a third of a second: a list shows what each next key does.

## exercise
Make the folder ~/dojo/nv. In nvim, write a file called notes.txt with three lines: one, two, three. Press i to type, Esc to stop, Ctrl+S to save. Then type :q and Enter to leave. Open it again to see the lines are there, and leave with :q.

## check
```check
run: cat notes.txt
in: nv
expect: one
expect: two
expect: three
```

## answer
The file has exactly three lines, nothing more.

```file notes.txt
one
two
three
```
