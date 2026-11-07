---
id: login-and-screen
title: Logging in, and what the screen shows
part: 1
minutes: 12
standard: 2
---
## example
You lock the screen, then come back in:

```keys
Super+Escape     the lock screen covers the desktop
your password    one mark appears for each character
Enter            the lock lets go
```
```output
the desktop just as you left it: the bar across the top, and your windows
```

## idea
One person uses this computer. So the login screen asks for no name, only your password. The lock screen is its twin: the same question, the same answer.

```term lock screen
the screen that hides your desktop until your password is typed
```

After a login, the desktop appears a few seconds later. It holds the bar, the wallpaper and your windows. There is no taskbar, no tray, and no title bar on a window. Everything is reached by a key or from the bar.

```term bar
the strip across the top: the desks on the left, the clock in the middle, the state on the right
```
```term desk
a screen of its own for one task; the bar shows each as a numeral: 一, 二, 三 and on
```

## exercise
Warm-up: Press [[Super+Escape]]. The lock screen covers everything. Look at it, but not for long. A lock you asked for puts the computer to sleep after a minute and a half.

Real: Type your password slowly. Watch a mark appear for each character. Only the newest seven show. When the last character is in, press the key that finishes it. If the password was wrong, the marks scatter and the line empties. Then you simply type it again.

Stretch: Back on the desktop, touch nothing yet. Find three things on the bar with your eyes only. The desk numbers are at the left, the clock in the middle, small icons at the right. One desk number looks different from the others. Guess why, and say your guess aloud.

```hint
The key that finishes a line is the same everywhere: in a form, in a chat, here.
```
```hint
It is the big key on the right of the letters, the one that starts a new line.
```

## check
```check
ask: Which key do you press when the last character of your password is in?
answer: Enter
proof: grep -q 'Enter\*\* when done' docs/fedokawaii-guide.md
```

## behind
When you press [[Enter]], the lock hands your password to PAM. PAM scrambles what you typed the same way it scrambled your password when it was set. It compares the two scrambled copies. The password itself is never stored anywhere. The scrambled copy lives in /etc/shadow, a file only root may read. If the two match, the lock lets go of the screen.

```term PAM
the part of Linux that checks a typed password against a scrambled copy of it
```
```term root
the administrator account, allowed to do anything on the system
```

```picture
<svg viewBox="0 0 400 120" role="img" aria-label="your password goes from the lock to PAM, which compares it with the scrambled copy in /etc/shadow">
<g data-step="1"><rect class="line" x="8" y="40" width="88" height="40" rx="4"/><text class="ink" x="52" y="65" text-anchor="middle">lock</text></g>
<g data-step="2"><path class="soft" d="M98 60h50"/><rect class="line" x="150" y="40" width="88" height="40" rx="4"/><text class="ink" x="194" y="65" text-anchor="middle">PAM</text></g>
<g data-step="3"><path class="soft" d="M240 60h50"/><rect class="line" x="292" y="40" width="100" height="40" rx="4"/><text class="ink" x="342" y="65" text-anchor="middle">/etc/shadow</text></g>
<g data-step="4"><text class="mark" x="194" y="28" text-anchor="middle">the two match: the desktop</text></g>
</svg>
```

Peek at the file. Its first ten marks are its permissions. All dashes: no ordinary account may open it, only root.

And the desk number that looked different? It is the desk you are on: it wears a vermilion seal.

```peek
ls -l /etc/shadow
```

## mistakes
- Caps Lock on: the password goes in as capitals and is refused. Press Caps Lock, then type again.
- Waiting on the lock screen: after a minute and a half the computer sleeps. Unlock right away.

## quiz
```quiz
q: Which key locks the screen?
a: Super+Escape
q: What does the login screen ask you for?
a: your password
q: Which part of Linux checks the password?
a: PAM
```

## next
Next: six keys that open nearly everything on this desktop.

## checked
- The fedokawaii Guide, r28: https://github.com/MoeDia/fedokawaii/blob/main/docs/fedokawaii-guide.md
- Linux-PAM, 1.7.2: https://github.com/linux-pam/linux-pam
- shadow(5), shadow-utils-4.19: https://man7.org/linux/man-pages/man5/shadow.5.html
