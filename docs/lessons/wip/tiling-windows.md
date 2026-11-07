---
id: tiling-windows
title: Windows share the screen by a rule
part: 1
minutes: 13
---
## idea
No window floats over another. Each new window takes a share of the screen, and the shares follow a rule, the spiral: the first window is the largest, on the left, and each later one takes a smaller place, winding inward. The focused window, the one that receives your typing, wears a vermilion frame. Super+J and Super+K move the focus to the next and previous window. The largest place is a seat you can give away: the focused window goes there with Super+Shift+Return.

## exercise
Open a terminal with Super+Return, then two more. Press Super+J until the focus reaches the last, and see its frame turn vermilion. Press Super+Shift+Return and watch it take the largest place. Close all three but one with Super+Q.

## check
```check
ask: Which key chord moves the focused window into the first, largest place?
answer: Super+Shift+Return
proof: grep -Eq 'MODKEY\|SHIFT, +XKB_KEY_Return, +zoom' src/dwl/config.h
```
