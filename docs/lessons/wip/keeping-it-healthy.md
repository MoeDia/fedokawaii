---
id: keeping-it-healthy
title: A month's routine
part: 1
minutes: 13
---
## idea
Keeping the desktop healthy is a short routine, not a chore. Once a season: update with Super+U; check the status in the same menu; look at the space with sudo btrfs filesystem usage on the root, and at what grew with gdu in your home; sort ~/downloads and empty the trash; delete snapshots you made by hand; and back up. A deleted file's space returns only when the last snapshot holding it is cleaned up, so a freed gigabyte can take days to show. The disk is scrubbed monthly by itself, and the journal trims itself.

## exercise
In a terminal run sudo btrfs filesystem usage / and read the used and free lines. Run gdu ~ and find the largest folder; press q to leave without deleting anything. Open ~/downloads in yazi and decide what is a keeper. Then say the routine out loud in order, from update to back up.

## check
```check
ask: Which command walks your home and shows what fills it, largest first?
answer: gdu ~
proof: grep -q 'gdu ~' docs/fedokawaii-guide.md
```
