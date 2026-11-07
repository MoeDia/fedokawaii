---
id: screenshots-recordings
title: Capture what happened
part: 1
minutes: 13
---
## idea
Print takes a region: drag a box, Esc gives up. Shift+Print takes the whole screen. Both save the picture in ~/captures and put it on the clipboard, so a notice says screenshot copied. Super+Print takes a region and opens it to mark up: Enter copies it, Ctrl+S saves it. Super+Shift+Print reads the text in a region and copies it. A keyboard without a Print key uses Super+Shift+S, F, A and X for the same four. Super+Shift+R opens the recorder's menu; the same key stops it.

## exercise
Press Print and drag a box round the clock; read the notice. In a terminal, run ls ~/captures and find the file named after the moment you took it. Start a recording with Super+Shift+R, pick the whole screen without sound, count to five, and stop it with the same key.

## check
```check
ask: Which key chord starts and stops a screen recording?
answer: Super+Shift+R
proof: grep -Eq 'MODKEY\|SHIFT, +XKB_KEY_r, +spawn, +SHCMD\("kawa-record"\)' src/dwl/config.h
```
