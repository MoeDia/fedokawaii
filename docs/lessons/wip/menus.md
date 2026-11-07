---
id: menus
title: Menus: panels, power, help
part: 1
minutes: 13
---
## idea
Quick settings is a panel from the bar's right end: two sliders for brightness and sound, then tiles for the theme, network, do not disturb and more. A click on a switch changes it and the panel stays open. The keys work too: an arrow or Tab puts the cursor, Enter chooses, and Esc closes it, as does a click outside or its own key again. The power menu is Super+Shift+E: lock, sleep, log out, restart, shut down. Help is Super+/.

## exercise
Open quick settings with Super+X, press the right arrow, then move the cursor with arrows to a tile and press Enter on it; press Enter again to undo. Esc. Open the power menu with Super+Shift+E, read the end of its heading, which says how long the machine has been up, and press Esc.

## check
```check
ask: Which key chord opens the power menu?
answer: Super+Shift+E
proof: grep -Eq 'MODKEY\|SHIFT, +XKB_KEY_e, +spawn, +SHCMD\("kawa-power"\)' src/dwl/config.h
```
