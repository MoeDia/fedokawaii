---
id: desks-session
title: workspaces and the session
part: desktop
chapter: 4
minutes: 8
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
