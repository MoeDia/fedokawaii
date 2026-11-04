---
id: moving-moves
title: moving and reading
part: programs
chapter: 11
minutes: 8
needs: [time-savers]
optional: no
---

> **In this chapter**
>
> - jump to any folder by one word
> - list folders with sizes, dates and git state
> - read a file with colours

**Best at:** the small daily moves. `cd` here is **zoxide**: it remembers the folders you visit
and jumps by a word. `ls`, `ll` and `lt` are **eza**. `cat` is **bat**.

## 11.1 the moves

| Command | Does |
|---|---|
| `cd proj` | jump to the folder you use most whose name matches *proj*, from anywhere |
| `cdi` | the folders zoxide knows, in fzf |
| `ll` | everything, with sizes, dates and git state (`N` new, `M` modified) |
| `lt` · `eza -T -L 3` | a tree, two levels · three |
| `ll -s size -r` · `ll -s modified` | biggest first · newest last |
| `bat file.py` | the file with line numbers and syntax colours |
| `tldr ffmpeg` | the five commands you actually wanted |
| `gdu ~` | what fills the disk, folder by folder, with a delete key |

### exercises

**11.1 ★ Teach zoxide.** `cd ~/Documents`, `cd /`, then `cd doc`.

*Expected:* you are back in `~/Documents`.

**11.2 ★ A tree.** `lt ~/repos` once you have a project (chapter 24).

**11.3 ★★ Clean-up hunt.** `gdu ~`: find the biggest folder in your home and decide whether it
should stay. **q** quits.
