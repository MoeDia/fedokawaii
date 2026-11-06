---
id: nvim-moves
title: never stuck, and neovim's moves
part: programs
chapter: 13
minutes: 14
needs: [time-savers]
optional: no
---

> **In this chapter**
>
> - edit without getting stuck: modes, save, quit, undo
> - the grammar that makes editing fast: verb + motion
> - the Space menu: files, search, git, code

**Best at:** editing text — notes, settings, code — faster than any mouse, with the same keys
everywhere: your notes window (**Super+N**), man pages and git messages all open in it. Here it
runs a small config of its own: a file finder, language servers, lazygit inside.

<!-- fig:app-nvim | neovim: the file tree, a file, and the status line with the mode. -->

## 13.1 never stuck

| Situation | Do |
|---|---|
| keys do odd things | **Esc**, twice: you are in Normal mode |
| save · save and quit · quit without saving | `:w` · `:wq` · `:q!` (or **Ctrl+S** to save) |
| undo · redo | `u` · **Ctrl+R** |
| *recording @q* at the bottom | press `q` once |
| a message went by too fast | `g<` shows the last ones again |

> **Word — mode.** In *Normal* mode, keys are commands; in *Insert* mode (`i`), keys type text.
> **Esc** always goes back to Normal.

## 13.2 the moves

| Keys | Does |
|---|---|
| `i` · `a` · `o` | type before the cursor · after it · on a new line below |
| `w` · `b` · `0` · `$` · `gg` · `G` | next word · back a word · line start · end · first · last line |
| `dd` · `yy` · `p` | cut · copy a line · paste |
| `ciw` · `ci"` · `dap` | change this word · inside the quotes · delete a paragraph |
| `.` | repeat the last change — the most useful key |
| `/word` · `n` | search · next match |
| `:%s/old/new/g` | replace everywhere in the file |
| **Space Space** · **Space /** | find a file · search text in the whole project |
| **Space e** · **Space g g** | the file tree · lazygit |
| `gd` · `K` · `gra` · `grn` | go to the definition · its documentation · a fix · rename everywhere |

The grammar: a **verb** (`d` delete, `c` change, `y` copy) + a **motion** or **object** (`w` a
word, `ip` a paragraph, `i(` inside brackets). `d3w` deletes three words; `yi"` copies what is
inside the quotes. Learn five verbs and five objects, and you have twenty-five commands.

## 13.3 use cases

- edit any setting: `nvim ~/.bashrc.d/local.sh`
- write code with completion, errors underlined as you type, and your tests a key away (chapter 24)
- change a word everywhere in a project: **Space /**, the word, **Ctrl+Q**, then `:cdo s/old/new/g | update`

### exercises

**13.1 ★ The tutor.** Run `nvim +Tutor` and do lesson 1.

*Expected:* you can move, delete, and quit with `:q!` without thinking.

**13.2 ★★ Fix a list.** Make a file with five lines `tea`, `rice`, `tea`, `milk`, `tea`. Turn
every *tea* into *coffee* with one command, then undo it, then do it with `*`, `ciw`, `n` and
`.` instead.

*Expected:* the same result both ways; the second teaches you the dot.

**13.3 ★★ Project search.** In `~/dojo/fedokawaii`, **Space /**, type `kawa-notes`.

*Expected:* every file that mentions it, with a preview; Enter jumps there.
