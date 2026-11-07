---
id: workspaces
title: Nine desks, each one thing
part: 1
minutes: 13
---
## idea
A workspace is a separate screenful of windows. There are nine, and the screen shows one at a time; the others wait untouched. Super and a number goes to a workspace. Super+Shift and a number sends the focused window there. Super+Tab goes back to the workspace you were on before, and again to return. Give each kind of work its own number, the same every day, and your hands learn where things are: 1 the browser, 2 terminals, 3 files.

## exercise
Press Super+2 and open a terminal; in the bar, 二 is stamped with the vermilion seal. Press Super+3 and open files with Super+E. Press Super+Tab twice to go back and forth. On workspace 3, send the files window to 2 with Super+Shift+2.

## check
```check
ask: Which key chord sends the focused window to workspace 3?
answer: Super+Shift+3
proof: grep -Eq 'MODKEY\|SHIFT, +KEY, +tag,' src/dwl/config.h
```
