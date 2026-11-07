---
id: the-panel
title: the panel
part: 1
minutes: 10
---
## idea
Everything the system can tell you is **one key** away: `Super+U` opens the panel. Nothing you need is hidden in a menu of menus.

| key | what |
|---|---|
| `Super+U` | the panel, on its first section and a very long sentence that has to wrap in a narrow tile |
| `Esc` | closes it |

## exercise
Open the panel, walk its sections with the arrows, close it.

## check
```check
ask: Which key opens the panel?
answer: Super+U
proof: grep -q panel config.h
```
