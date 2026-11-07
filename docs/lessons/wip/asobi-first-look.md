---
id: asobi-first-look
title: The play world
part: 1
minutes: 12
---
## idea
Games do not live in your account. ASOBI (遊び, play) is a second user on this machine, on a screen of its own, and every game runs there: Steam, Proton, your saves. Super+G goes in and Super+G in there comes back; the desktop never stopped. While you are away a running game is frozen by the kernel, using no processor and no graphics card, and exactly where you left it. The world cannot see your files, and you do not have to trust a game with them.

## exercise
Open a terminal and type kawa-asobi state: it says off while the world is closed. Press Super+G, wait for Steam's screen, then press Super+G again to come back. Type kawa-asobi state once more: now it says away, because Steam works on behind the desktop. Do not sign in or start a game yet; that is the next lesson.

## check
```check
ask: Which key chord goes into the play world and comes back out of it?
answer: Super+G
proof: grep -Eq 'MODKEY, +XKB_KEY_g, +spawn, +SHCMD\("kawa-asobi enter"\)' src/dwl/config.h
```
