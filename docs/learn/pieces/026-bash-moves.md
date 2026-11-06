---
id: bash-moves
title: the shell's moves
part: programs
chapter: 9
minutes: 8
needs: [time-savers]
optional: no
---

> **In this chapter**
>
> - chain commands with pipes, and save output to files
> - write your own commands: aliases and functions
> - let ble.sh's colours catch mistakes before Enter

**Best at:** gluing programs together. Every program in this book can be run, combined and
repeated from bash; a task you do twice by hand is a one-line command the third time.

## 9.1 the moves

| Move | Example | Does |
|---|---|---|
| pipe `|` | `ls ~/captures | wc -l` | one program's output into the next |
| redirect `>` · `>>` | `date >> ~/log.txt` | output into a file: replace · append |
| `&&` · `||` | `mkdir x && cd x` | the second only if the first worked · only if it failed |
| `$( … )` | `echo "today is $(date +%A)"` | a command's output, in the middle of another |
| a loop | `for f in *.png; do echo "$f"; done` | the same command for each file |
| quotes | `"$f"` | keeps a name with spaces whole — quote every variable |
| `!!` · **Alt+.** | `sudo !!` | the last command · its last argument |
| an alias | `alias gs='git status'` | a short name for a long command |
| a function | `mkcd() { mkdir -p "$1" && cd "$1"; }` | a command of your own, with arguments |
| exit status | `echo $?` | 0 means it worked; anything else, it failed |

As you type, **ble.sh** colours the line: a known command in teal, an unknown one in vermilion,
an existing file underlined. Vermilion before you press Enter is a typo caught for free. The grey
suggestion is an earlier command: **→** takes it, **Ctrl+→** one word.

Your own aliases and functions go in `~/.bashrc.d/local.sh` — yours; the desktop never
touches it. Every new terminal reads it.

## 9.2 use cases

- rename a hundred photos by their date in one loop
- a `backup-notes` function that copies `~/notes` to a USB stick
- `history | rg ffmpeg` to find that clever command from last month

### exercises

**9.1 ★ mkcd.** Add the `mkcd` function above to `~/.bashrc.d/local.sh`, open a new terminal,
and run `mkcd ~/dojo/practice/new`.

*Expected:* the prompt shows `~/dojo/practice/new` at once.

**9.2 ★★ Count by kind.** How many files of each kind are in your pictures?

```sh
fd -t f . ~/captures | sed 's/.*\.//' | sort | uniq -c | sort -rn
```

*Expected:* lines such as `     42 png`, the most common first. Read it as a sentence: list the
files, keep what follows the last dot, sort, count each run, sort by the count.
