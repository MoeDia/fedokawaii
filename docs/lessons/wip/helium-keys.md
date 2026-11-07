---
id: helium-keys
title: Helium without the mouse
part: 1
minutes: 12
---
## idea
Super+B opens Helium, the only browser here. Five keys do most of the work: Ctrl+T a new tab with the cursor already in the address bar, Ctrl+W closes the tab, Ctrl+Shift+T brings the last closed one back, Ctrl+L jumps to the address bar and Ctrl+Tab moves to the next tab. Ctrl+1 to Ctrl+8 go to that tab and Ctrl+9 to the last. Super+Q closes the whole window with every tab, so it is the one to treat with care.

## exercise
Press Super+B. Ctrl+T, type fedoraproject.org and press Enter. Ctrl+T again, type kernel.org, Enter. Press Ctrl+1 and Ctrl+2 to move between them. Close one with Ctrl+W and bring it back with Ctrl+Shift+T. Leave the window open for the next lesson.

## check
```check
ask: Which key chord brings back the tab you just closed?
answer: Ctrl+Shift+T
proof: grep -q 'Ctrl+T · Ctrl+W · Ctrl+Shift+T' docs/fedokawaii-guide.md
```
