---
id: snapshots
title: An undo for the whole system
part: 1
minutes: 13
---
## idea
A snapshot is a frozen copy of the system's files at one moment. It is made in an instant and takes room only for what changes after it, so the desktop makes them freely: one every hour, one before each update, one around every package change, and the first one, the baseline. If a change goes wrong, you go back to the state before it. Snapshots cover the system and your home, but not ~/downloads. They live on the same disk they protect, so they undo mistakes; they do not survive a dead disk (that is the next lesson).

## exercise
Open a terminal and type snaps. Read the list: the number, the type (single, or a pre and post pair around one package change) and the description saying why each was taken. Find the line that says baseline, and the newest line. Then press Super+U and move to snapshots to see the same list in the menu. Only look; restoring is for a real bad update, and the menu asks twice before it does anything.

## check
```check
ask: What do you type in a terminal to list the snapshots of the system?
answer: snaps
proof: grep -q 'snaps` is the desktop' docs/fedokawaii-guide.md
```
