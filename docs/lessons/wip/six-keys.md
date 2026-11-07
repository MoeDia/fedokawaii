---
id: six-keys
title: Six keys that carry you a long way
part: 1
minutes: 13
needs: [login-and-screen]
standard: 2
---
## remember
```quiz
q: Which key locks the screen?
a: Super+Escape
```

## example
You start a program without the mouse:

```keys
Super+Space    the launcher opens in the middle of the screen
t, e, r        the list narrows to names with those letters
Enter          the first one in the list starts
```
```output
a terminal, open, after five key presses
```

## idea
Super is the key with the Windows logo on it. Held down with another key, it gives an order to the desktop.

```term chord
keys held down together, written with a + between them
```

Six chords open most of what you need. [[Super+Space]] is the launcher. [[Super+Return]] is a terminal. [[Super+B]] is the browser, and [[Super+E]] is your files. [[Super+X]] is quick settings. [[Super+/]] lists every key, and you can search it.

```term launcher
a box where you type a few letters of a program's name to start it
```

Some chords open a window, some a panel. [[Esc]] closes a panel. [[Super+Q]] closes the window you are in.

```term window
a program's own rectangle on the screen; it stays until you close it
```
```term panel
a box over the windows for a moment; Esc closes it
```

## exercise
Warm-up: Press [[Super+Space]]. Look at the launcher, then press [[Esc]] to close it.

Real: Press each of the six chords once, and look at what opens. Close each one again: try [[Esc]] first, and if it stays, [[Super+Q]]. Then open the key list with [[Super+/]] and type lock. Watch the list narrow to the keys about locking.

Stretch: Predict first. On paper, make two columns: window and panel. Put each of the six chords in the column you expect. Then test each chord and correct your columns. Which guess was wrong, and what told you?

```hint
A window stays when you look elsewhere. A panel waits for you, then goes.
```
```hint
Watch what Esc does: a panel goes, a window stays.
```

## check
```check
ask: Which key chord opens the launcher?
answer: Super+Space
proof: grep -Eq 'MODKEY, +XKB_KEY_space, +spawn, +\{\.v = menucmd\}' src/dwl/config.h
```

## behind
The keyboard sends a number for each key to Linux. dwl reads every key first. It looks the chord up in its table of keys, written in a file called config.h. If the chord is in the table, dwl does what is written beside it. If not, the key goes on to the window you are in.

```term dwl
the program that places every window on the screen and reads every key first
```

```picture
<svg viewBox="0 0 400 120" role="img" aria-label="a chord goes to dwl, which finds it in its table and starts the launcher">
<g data-step="1"><rect class="line" x="8" y="40" width="96" height="40" rx="4"/><text class="ink" x="56" y="65" text-anchor="middle">Super+Space</text></g>
<g data-step="2"><path class="soft" d="M106 60h30"/><rect class="line" x="138" y="40" width="96" height="40" rx="4"/><text class="ink" x="186" y="65" text-anchor="middle">dwl's table</text></g>
<g data-step="3"><path class="soft" d="M236 60h30"/><rect class="line" x="268" y="40" width="124" height="40" rx="4"/><text class="mark" x="330" y="65" text-anchor="middle">the launcher</text></g>
</svg>
```

Peek at the table's line for the launcher:

```peek
grep -n 'menucmd}' ~/.local/src/dwl/config.h
```

## mistakes
- Letter first, then Super: nothing happens. Hold Super down first, then tap the letter.
- [[Esc]] on a window: it does not close. A window closes with [[Super+Q]].

## quiz
```quiz
q: Which chord opens a terminal?
a: Super+Return
q: Which key closes a panel?
a: Esc
q: Which chord lists every key?
a: Super+/
```

## next
Next: what happens when several windows are open at once.

## checked
- The fedokawaii Guide, r28: https://github.com/MoeDia/fedokawaii/blob/main/docs/fedokawaii-guide.md
- fedokawaii's dwl config.h, r28: https://github.com/MoeDia/fedokawaii/blob/main/src/dwl/config.h
- dwl config.def.h, v0.9: https://codeberg.org/dwl/dwl/src/tag/v0.9/config.def.h
