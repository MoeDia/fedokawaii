---
id: notices-dnd
title: Notices, and do not disturb
part: 1
minutes: 13
---
## idea
A notice is a card at the top right. An ordinary one stays five seconds; a critical one has a vermilion border and stays until you click it. A left click closes a notice and a right click closes them all, as does Super+Shift+N. Do not disturb stops notices from showing, and the bar wears the seal 静 while it is on. Critical notices and the level display still show, because you would want them. While a screen is shared the same rule holds by itself.

## exercise
In a terminal send two notices: notify-send Hello one, then notify-send -u critical Hello two. Click the second to close it. Turn dnd on in quick settings and send the first again: nothing shows. Send the critical one: it does. Turn dnd off.

## check
```check
ask: Which key chord dismisses every notice on screen?
answer: Super+Shift+N
proof: grep -Eq 'MODKEY\|SHIFT, +XKB_KEY_n, +spawn, +SHCMD\("makoctl dismiss -a"\)' src/dwl/config.h
```
