---
id: yazi-moves
title: yazi's moves
part: programs
chapter: 12
minutes: 14
needs: [desks-session]
optional: no
---

Each chapter here is one program, in the same order: what it is best at, the moves that unlock
most of its power, real uses, then exercises. Learn a chapter's moves table by heart and you
have most of the program; the rest is in its manual.

> **In this chapter**
>
> - move through folders with h j k l, preview anything
> - copy, move, rename and delete many files at once
> - jump anywhere by typing

**Best at:** working on many files fast, with a preview of each — pictures, PDFs, videos and
code — without leaving the keyboard. **Super+E** opens it. It is also every program's file
dialog here.

<!-- fig:app-yazi | yazi: the parent folder, this folder, and a preview of the file under the cursor. -->

## 12.1 the moves

| Keys | Does |
|---|---|
| **h** **j** **k** **l** | up a folder · down · up · open |
| **Space** · **v** · **Ctrl+A** | select one · a range · all |
| **y** · **x** · **p** | copy · cut · paste |
| **d** · **D** | to the trash · delete for good |
| **a** | new file (end with `/` for a folder) |
| **r** | rename; several selected: rename them all in neovim |
| **z** · **Z** | jump to anything below here (fzf) · to a folder you use (zoxide) |
| **s** · **S** | search names (fd) · contents (ripgrep) |
| **.** | hidden files on / off |
| **g h** · **g d** · **M** | home · your drives · drives: open or eject |
| **Enter** on a film | it plays in mpv; **W**: watch it together (Syncplay) |
| **Alt+S** | shrink or convert pictures and PDFs |
| **Alt+F** | archives and PDFs: unpack, pack, merge, sign (Super+D's menu) |
| **;** | run a command on the selection: `%s` the selected files |

## 12.2 use cases

- sort a holiday's photos: select by range, cut, paste into a new folder
- rename 30 episode files at once with **r** and neovim's `:%s` (chapter 13)
- clean `~/downloads`: sort by size (**,** then **s**), trash the big ones you watched

### exercises

**12.1 ★ Three moves.** In `~/dojo/practice`, make a folder `pics/` (**a**, `pics/`), copy two
screenshots into it (**y**, then **p** inside it).

**12.2 ★★ Rename many.** Select three files, press **r**: in neovim, change all three names at
once with `:%s/^/2026-/`, then `:wq`.

*Expected:* each name now starts with `2026-`.

**12.3 ★★ Pack them.** Select the files of 12.1, press **;**, type `7z a pics.7z %s`.

*Expected:* `pics.7z` appears in the folder.
