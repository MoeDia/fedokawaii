---
id: tiling-windows
title: Windows share the screen by a rule
part: 1
minutes: 13
needs: [six-keys]
standard: 2
---
## remember
```quiz
q: Which chord opens a terminal?
a: Super+Return
```

## example
Three terminals, one after the other:

```keys
Super+Return   one terminal fills the screen
Super+Return   the first moves to the left, the new one takes the right
Super+Return   the right side splits: the new one goes under the second
```
```output
no window covers another, and no gap is left empty
```

## idea
No window floats over another here. Each new window takes a share of the screen, and the shares follow one rule: the spiral.

```term spiral
the layout here: the first window on the left, each later one splitting what is left, inward
```

The first window keeps the largest place, on the left. It is about six tenths of the width. Each later window splits what is left, turning inward while there is room.

```term focus
the window that gets your typing; a vermilion frame shows it
```

[[Super+J]] moves the focus to the next window, [[Super+K]] to the one before. The largest place is a seat you can give away. [[Super+Shift+Return]] moves the focused window into it.

## exercise
Warm-up: Press [[Super+Return]] three times. Watch each new terminal find its place.

Real: Press [[Super+J]] slowly, and follow the vermilion frame from window to window. Stop on the bottom-right window. Press [[Super+Shift+Return]]. It moves into the largest place, and the old first window moves to the top right. Type ls (it lists the files in a folder) and press [[Enter]], to be sure where your typing goes.

Stretch: Predict first. You have three windows. You open a fourth. Sketch on paper where you think it will go. Then press [[Super+Return]] and compare. Close all but one with [[Super+Q]].

```hint
Follow the frame: the vermilion one is the window your keys go to.
```
```hint
Move the frame to the window you want with Super and J, then give it the big seat with Super, Shift and Return.
```

## check
```check
ask: Which key chord moves the focused window into the first, largest place?
answer: Super+Shift+Return
proof: grep -Eq 'MODKEY\|SHIFT, +XKB_KEY_Return, +zoom' src/dwl/config.h
```

## behind
dwl keeps the windows in a list. The first in the list gets the largest place. When a window opens or closes, dwl works out every place again from the list. [[Super+Shift+Return]] moves the focused window to the top of the list. So it gets the first place, and the others shift down. No window is made smaller than 600 by 336 pixels. A fourth turn would be too narrow here, so the right side becomes three equal rows instead.

```picture
<svg viewBox="0 0 400 140" role="img" aria-label="the spiral: one window, then two side by side, then the right side split in two">
<g data-step="1"><rect class="line" x="8" y="8" width="112" height="124" rx="2"/><text class="ink" x="64" y="75" text-anchor="middle">1</text></g>
<g data-step="2"><rect class="line" x="140" y="8" width="70" height="124" rx="2"/><text class="ink" x="175" y="75" text-anchor="middle">1</text><rect class="line" x="214" y="8" width="38" height="124" rx="2"/><text class="ink" x="233" y="75" text-anchor="middle">2</text></g>
<g data-step="3"><rect class="line" x="272" y="8" width="70" height="124" rx="2"/><text class="ink" x="307" y="75" text-anchor="middle">1</text><rect class="line" x="346" y="8" width="38" height="60" rx="2"/><text class="ink" x="365" y="43" text-anchor="middle">2</text><rect class="mark" x="346" y="72" width="38" height="60" rx="2"/><text class="mark" x="365" y="107" text-anchor="middle">3</text></g>
</svg>
```

Peek at the rule's line in dwl's table:

```peek
grep -n 'spiral },' ~/.local/src/dwl/config.h
```

## mistakes
- Typing into the wrong window: look for the vermilion frame before you type.
- Looking for a maximise button: there is none. The largest place is given with [[Super+Shift+Return]].

## quiz
```quiz
q: Which chord moves the focus to the next window?
a: Super+J
q: What colour is the focused window's frame?
a: vermilion
q: Which chord gives the focused window the largest place?
a: Super+Shift+Return
```

## next
Next: nine desks, so each task gets a screen of its own.

## checked
- The fedokawaii Guide, r28: https://github.com/MoeDia/fedokawaii/blob/main/docs/fedokawaii-guide.md
- fedokawaii's dwl patch, r28: https://github.com/MoeDia/fedokawaii/blob/main/src/dwl/dwl.patch
- dwl config.def.h, v0.9: https://codeberg.org/dwl/dwl/src/tag/v0.9/config.def.h
