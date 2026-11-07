---
id: asobi-review
title: A month of play
part: 1
minutes: 11
---
## idea
After a month, check the play world like a house. Look at its disk use: games are large and come again from Steam, so a full world is the first thing to trim. Take a snapshot now before anything big, such as a new Windows program in Bottles. Remember the walls: no password, no shell, no sudo, and no view of your home but the drop folder. If something odd happens in there, a reset to clean ends it, and the before-reset snapshot is the way back from a reset.

## exercise
Super+U, system, asobi, disk use: read how much the world holds and what is free. Choose snapshot now and read the name it gives. Then open reset to a snapshot and read the list, but Esc out without choosing one.

## check
```check
ask: Which snapshot of the play world is the world as it was installed?
answer: clean
proof: grep -q 'The snapshot called \*\*clean\*\*' docs/learn/pieces/040-asobi-moves.md
```
