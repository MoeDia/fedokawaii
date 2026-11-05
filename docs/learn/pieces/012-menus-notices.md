---
id: menus-notices
title: menus and notices
part: desktop
chapter: 5
minutes: 11
needs: [the-bar]
optional: no
---

## 5.2 the menus

| Menu | Key | Inside |
|---|---|---|
| quick settings | **Super+X** | a dial: the switches on its hours (theme, night light, FreeSync, screensaver, do-not-disturb, network, Bluetooth, drives, backup, record, read text), brightness and sound as beads inside, screenshot, wallpaper, screen off and power in its corners; the one under the cursor shown large in its middle |
| sound panel | **Super+A** | the volume, every output and input, the mixer |
| calendar | **Super+C** | the month; *next*, *today* |
| power | **Super+Shift+E** | lock · sleep · log out · restart · shut down |
| help | **Super+/** | every key; type to filter |
| wallpaper · theme | **Super+W** · **Super+Shift+W** | a picture for this theme · dark ⇄ light |

Every menu works the same: arrows or **j** **k** move, **Enter** chooses, **Esc** closes, and
typing filters a long list. A screen with a key of its own shows it on its last line — the key,
what it does, and its state — and nothing else there: Super+/ has all the rest.

**The wallpaper picker** (**Super+W**) lists the theme's pictures, with the one under the cursor
shown underneath, as the screen will show it, the list in its sections with the old masters near
the top. Hold ↓ to run through them; **Enter** sets one, **Esc** leaves everything as it was. Under
the list are its settings, every value in sight, each with its key (or a click on its row):
**r** *change by itself* — off, every hour, every 4 hours, daily; **o** *order* — in turn or
shuffled; **s** *from* — the old masters, the scenes, or both. They stay as you left them across
logins.

**The one transition.** A theme switch (**Super+Shift+W**) and a new wallpaper share one
transition: the old screen fades away over a third of a second, drawn at every refresh of the
screen. It never holds a click: press **Super+Shift+W** again during
it and it jumps to its end, then switches back.

## 5.3 notices

A notice appears at the top right and fades by itself; a click does what it offers (opens the
download, the drive). **Super+Shift+N** dismisses them all. While you need quiet — a call, an
exam — turn on *dnd* in quick settings: notices wait, and the quiet bell stands in the bar. A
click on the bell chooses how long: *for an hour* or *until the morning* end by themselves.

### exercises

**5.1 ★ Every menu once.** Open each menu of 5.2 by its key, then close it with **Esc**.

*Expected:* six menus, each in the same pixel style, each closed by Esc.

**5.2 ★ Quiet.** Turn on *dnd* (**Super+X**, *dnd*), then run `notify-send hello` in a
terminal. Turn *dnd* off.

*Expected:* no notice while the bell is in the bar; the notice shows once dnd is off.

**5.3 ★★ A 25-minute focus timer.** Click the time in the bar and choose *25 min*.

*Expected:* the time left shows in the timer's heading; a notice when it ends.

**5.4 ★ A new wallpaper every four hours.** **Super+W**, **r** so its last line says *on*,
**Esc**. Then **Super+Shift+W** twice, and watch the wash each time.

*Expected:* it still says *on* when you open the picker again; at each theme switch drops of ink land on
the screen and bleed the old mood away in 1.2 s, the pointer changing as the ink reaches it.
