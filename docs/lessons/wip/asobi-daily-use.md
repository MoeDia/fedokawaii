---
id: asobi-daily-use
title: Playing, saving, undoing
part: 1
minutes: 13
---
## idea
Everything about the world but the games is one small window: Super+U, then system, then asobi. Its rows are enter, bottles (for other Windows programs), close (Steam ends properly and its saves go to its cloud), snapshot now, reset to a snapshot, disk use and drop folder. The snapshot called clean is the world as it was installed and it never goes: whatever a program did in there, a reset ends it. The one folder you share with the world is ~/Drop. These snapshots are not the system's and not your backups; games come again from Steam.

## exercise
Press Super+U and open system, then asobi. Read the seven rows. Choose disk use to see what the world holds, then Esc. Put any small text file in ~/Drop with the terminal: touch ~/Drop/hello.txt. That file is the only thing of yours the world can reach.

## check
```check
ask: What is the name of the one folder in your home that the play world can also read?
answer: Drop
proof: grep -q 'the one folder you share' docs/learn/pieces/040-asobi-moves.md
```
