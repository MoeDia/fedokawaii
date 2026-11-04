---
id: undo-and-copies
title: snapshots and backups: two different things
part: desktop
chapter: 8
minutes: 1
needs: [update-button]
optional: no
---

## 8.5 snapshots and backups: two different things

A **snapshot** is an undo on this disk. A **backup** is a copy on another drive. A snapshot is no
help when the disk dies; a backup is what is left then.

| What happened | Use |
|---|---|
| an update or a change broke the system | snapshots → go back |
| you deleted or spoiled a file an hour ago | snapshots → a file, back |
| the disk died, or the machine is gone | backups → restore, on the new one |

**When the desktop will not start**, the login's console says so and names two commands:
`fedokawaii repair` (finds what broke and fixes it) and `fedokawaii snapshots` (the same *go back*).

**When nothing starts at all**, hold Shift at power-on for the boot menu: *snapshots* lists the
latest ones. One started from there runs as it was, on a layer in memory, and nothing it does stays.
If it works, Super+U → snapshots → go back makes it the system.

Your files are never part of the system's snapshots: going back leaves `/home` as it is. Going back
is itself undone with *old*.
