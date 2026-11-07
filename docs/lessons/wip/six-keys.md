---
id: six-keys
title: Six keys that carry you a long way
part: 1
minutes: 13
---
## idea
Super is the Windows key. Six keys open most of what you need. Super+Space is the launcher: type a few letters of a program's name, then Enter. Super+Return is a terminal. Super+B is the browser and Super+E the files. Super+X is quick settings, and Super+/ lists every key, searchable. Super+V shows what you copied. Each opens a window or a panel; Esc closes a panel, and Super+Q closes a window.

## exercise
Press each of the six once and look at what opens. Close each: Esc for the launcher, quick settings, help and the clipboard; Super+Q for the terminal. In help, type lock and watch the list narrow.

## check
```check
ask: Which key chord opens the launcher?
answer: Super+Space
proof: grep -Eq 'MODKEY, +XKB_KEY_space, +spawn, +\{\.v = menucmd\}' src/dwl/config.h
```
