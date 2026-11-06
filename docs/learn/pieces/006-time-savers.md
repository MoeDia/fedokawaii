---
id: time-savers
title: the keys that save the most time, and help
part: zero
chapter: 2
minutes: 9
needs: [open-it]
optional: no
---

## 2.3 the keys that save the most time

| Keys | Does |
|---|---|
| **Tab** | completes a name: type `cd dow` then Tab, it becomes `cd downloads/` |
| **Up** · **Down** | earlier commands; type the start first (`git`) and Up finds only those |
| **Ctrl+R** | search every command you ever ran (fzf): type a few letters, Enter |
| **→** or **End** | take the grey suggestion the shell offers as you type |
| **Ctrl+C** | stop the running command (it does *not* copy here) |
| **Ctrl+Shift+C** · **Ctrl+Shift+V** | copy · paste in the terminal |
| **Ctrl+L** | clear the screen |
| **Ctrl+Shift+N** | a new terminal, in this same folder |

## 2.4 help is always one command away

| You want | Type |
|---|---|
| the five most useful examples of a command | `tldr tar` |
| its whole manual | `man tar` (`/word` searches, `n` the next match, `q` quits) |
| a short list of its options | `tar --help` |
| the desktop's keys | **Super+/** |

```text
$ tldr mkdir
  Create directories and set their permissions.
  - Create specific directories:
    mkdir path/to/directory1 path/to/directory2 ...
  - Create specific directories and their parents if needed:
    mkdir -p path/to/directory1 path/to/directory2 ...
```

*(for example; shortened)*

### exercises

**2.1 ★ A small tree.** Make `~/dojo/practice/a/b/c` in one command (`mkdir -p`), then go into `c`
using Tab to complete each name.

*Expected:* the prompt ends in `c`; `pwd` prints `/home/you/dojo/practice/a/b/c`.

**2.2 ★ History.** Press **Ctrl+R**, type `mkdir`, and run the command you typed in 2.1 again.

*Expected:* no error (`-p` does not mind that the folders exist).

**2.3 ★★ Count.** `ls ~/captures | wc -l` counts your screenshots. Take one with
**Print** (drag a box), then count again.

*Expected:* one more than before. `|` sends what `ls` prints into `wc -l`, which counts lines.
