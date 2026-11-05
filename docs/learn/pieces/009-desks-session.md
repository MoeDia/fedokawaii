---
id: desks-session
title: workspaces, the session, how things move
part: desktop
chapter: 4
minutes: 10
needs: [ten-keys]
optional: no
---

## 4.3 workspaces: nine desks

> **Word — workspace.** A separate screen of windows. Only one shows at a time; the others keep
> their windows exactly as you left them. The bar shows them as kanji numerals: 一 二 三 …

A habit that works: **1** for the browser, **2** for code (editor and terminal), **3** for files,
**4** for chat and music, **9** for games. **Super+Tab** jumps back to the workspace you were
on: with two desks, it flips between them. **Super+0** shows all at once.

With two monitors, **Super+,** and **Super+.** move the focus left and right, and
**Super+Shift+,** · **Super+Shift+.** send the window there.

## 4.4 the session

| Keys | Does |
|---|---|
| **Super+Escape** | lock the screen (asleep after 90 s) |
| **Super+Shift+E** | the power menu: lock, sleep, log out, restart, shut down |
| **Super+Shift+N** | dismiss every notice |
| **Alt+Shift** | switch the keyboard layout (us / ar) |
| **Ctrl+Alt+F2…F6** | a text console, should the desktop ever freeze (**Ctrl+Alt+F1** back) |

## 4.5 how things move

Everything here moves on purpose, like water: it starts from rest, flows and settles. Each kind of
movement means one thing, so after a day you read them without thinking:

| You see | It means | Where |
|---|---|---|
| a window rising to its place and settling, or sinking away | a window arriving, or leaving | every window |
| the whole screen sliding sideways, like a fusuma on its track | a place left for another: to a higher number it goes left, to a lower one right | **Super+1** to **Super+9** |
| something unrolling behind a lacquer rod | something opened; it rolls up again as it goes | every menu, **Super+U**, **Super+N**, **Super+V**, a lesson |
| a quiet thing dissolving, in square pixels | a message passing | a notice, the level display |
| a red seal pressed down for a moment | a choice made | the workspace's seal, a lesson stamped |
| ink bleeding across the whole screen | the whole picture changing | a new wallpaper, dark to light (**Super+Shift+W**) |

Nothing ever waits for a movement: a key or a click acts at once on where things are going. Press
**Super+2**, **Super+3**, **Super+1** as fast as you like: you are never held up, and nothing is
lost on the way.

### exercises

**4.1 ★ Three windows.** Open a terminal, then yazi (**Super+E**), then another terminal. Press
**Super+J** five times and watch the vermilion frame move.

*Expected:* the frame visits each window in turn: the focus follows the order of the spiral.

**4.2 ★ Promote.** Focus the smallest window and press **Super+Shift+Return**.

*Expected:* it swaps into the largest place on the left.

**4.3 ★★ A coding desk.** On workspace 2, open neovim in a terminal (`nvim`) and a second
terminal. Switch to columns (**Super+T**), back to the spiral (**Super+S**). Send the second
terminal to workspace 3 (**Super+Shift+3**) and follow it (**Super+3**), then go back
(**Super+Tab**).

*Expected:* the bar's 三 lights while it holds a window; Super+Tab returns you to 二.
