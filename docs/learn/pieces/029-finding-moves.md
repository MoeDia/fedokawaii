---
id: finding-moves
title: finding anything
part: programs
chapter: 10
minutes: 14
needs: [bash-moves]
optional: no
---

> **In this chapter**
>
> - find any file by a few letters of its name
> - find any word inside any file, in a second
> - pick anything from a list by typing

**Best at:** the question you ask a computer most — *where is it?* `fd` finds files by name,
`rg` (ripgrep) finds text inside files, `fzf` turns any list into a searchable menu.

## 10.1 the moves

| Command | Does |
|---|---|
| `fd notes` | files whose name contains *notes*, below here |
| `fd -e pdf . ~` | every PDF in your home |
| `fd -t d conf` | folders only |
| `fd -S +500m . ~` | files over 500 MB |
| `rg "rice" ~/notes` | every line holding *rice*, with file and line number |
| `rg -i -t py "todo"` | ignore case, only Python files |
| `rg -l word` · `rg -C 2 word` | file names only · two lines of context around each match |
| `nvim "$(fzf)"` | pick a file by typing, edit it |
| **Ctrl+T** · **Alt+C** · **Ctrl+R** | insert a path · go into a folder · find an old command — all fzf |

In every fzf list: words in any order narrow it; `'word` exact; `^start` and `end$`; `!not`.

## 10.2 use cases

- `rg -i "invoice" ~/notes -l` — which files mention invoices
- `fd -e mkv . ~/downloads -x du -h` — every film and its size
- in a code project, `rg "def train"` finds where a function is defined in a second

### exercises

**10.1 ★ Every PDF you own.** `fd -e pdf . ~`

*Expected:* a list of paths; nothing if you have no PDFs yet (try `-e png`).

**10.2 ★ Grep your notes.** `rg -i` a word you wrote in your notes.

*Expected:* `~/notes/notes.md`, then the line number and the line.

**10.3 ★★ Pick and edit.** In your home, `nvim "$(fd -e md | fzf)"`.

*Expected:* a list of Markdown files only; Enter opens the one you chose.

**10.4 ★★ The big ones.** List the five largest files in your home:
`fd -t f -S +100m . ~ -x du -h | sort -h | tail -5`.
