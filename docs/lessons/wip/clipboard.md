---
id: clipboard
title: What you copied does not vanish
part: 1
minutes: 13
---
## idea
Every copy goes into a history, newest first, and a copy outlives the program it came from: closing the program does not empty the clipboard. Super+V opens the history in a small window. Type to search, move with the arrows, Enter pastes the one you pick. Pictures are kept as well as text. Copies a password manager marks as secret are never kept. In the terminal, copy with Ctrl+Shift+C and paste with Ctrl+Shift+V.

## exercise
Select a word in a terminal, which copies it, then select another. Press Super+V and find both, the newest first. Type the first letters of the older one to filter, and press Enter to paste it back in the terminal. Esc closes the list.

## check
```check
ask: Which key chord opens the clipboard history?
answer: Super+V
proof: grep -Eq 'MODKEY, +XKB_KEY_v, +warm, +\{\.v = "clip"\}' src/dwl/config.h
```
