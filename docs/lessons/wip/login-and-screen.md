---
id: login-and-screen
title: Logging in, and what the screen shows
part: 1
minutes: 13
---
## idea
One person uses this computer, so the login screen asks for no name: only the password. Each character you type lights an ember; a wrong one scatters them and shakes the mask, and you simply type again. A few seconds after Enter the desktop appears: the bar across the top, the wallpaper under it, and nothing else. There is no taskbar, no tray, no title bars on windows. Everything is reached by a key or by the bar.

## exercise
Lock the screen with Super+Escape. Look at the lock screen, which is the login screen's twin. Type your password, watching the embers, and press the key that finishes it. Then look at the desktop: find the bar, the clock on its middle, the cat at its right end.

## check
```check
ask: Which key do you press when the last character of your password is in?
answer: Enter
proof: grep -q 'Enter\*\* when done' docs/fedokawaii-guide.md
```
