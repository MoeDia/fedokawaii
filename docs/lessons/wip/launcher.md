---
id: launcher
title: One key to anything
part: 1
minutes: 13
---
## idea
The launcher is the quickest way to start a program, open a setting or run a sum. Super+Space opens it, and you type a few letters of a name: bra finds the browser. Enter starts the first match, and the arrows choose another. It also works sums: type 15% of 2400 and the answer shows in its first row; Enter copies it. A program's name typed in full and Enter runs that program. Esc closes it. Learn to type less: three letters are usually enough.

## exercise
Open the launcher and type bra, Enter: Helium opens. Close it with Super+Q. Open the launcher again and type 15% of 2400: the answer shows above any program; press Esc without copying. Now start the files window by its name.

## check
```check
ask: What do you type in the launcher to see the answer to fifteen percent of 2400?
answer: 15% of 2400
proof: grep -q 'type `15% of 2400`' docs/fedokawaii-guide.md
```
