---
id: open-it
title: open it: five commands
part: zero
chapter: 2
minutes: 4
needs: [what-pieces]
optional: no
---

> **In this chapter**
>
> - open a terminal and run your first commands
> - move between folders, make and remove a folder
> - get help on any command

## 2.1 open it

Press **Super+Return** (Super is the key with the Windows logo). A terminal window opens: foot,
the desktop's terminal. It shows a **prompt**, then a blinking cursor.

```text
⛩   ~ ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌ ☾  08:52:07 PM
›
```

*(the top line shows the folder you are in — `~`, your home — and the time; you type after the `›`.
After a command that failed, the top line also shows a vermilion `✗` and a number: chapter 3)*

> **Word — shell.** The program inside the terminal that reads your commands and runs them.
> Here it is **bash**. The terminal is the window; the shell is what talks to you inside it.

## 2.2 five commands, one at a time

Type each line (without the `$`) and press **Enter**. After each one, compare with the answer.

```text
$ pwd
/home/you
```

*(print working directory: where you are)*

```text
$ ls
Books  Documents  Downloads  Music  Notes  Pictures  repos  Videos
```

*(list: what is here; your list may differ)*

```text
$ mkdir practice
$ cd practice
$ pwd
/home/you/practice
```

*(make a folder, change into it, check)*

```text
$ echo "my first file" > first.txt
$ ls
first.txt
$ cat first.txt
my first file
```

*(`>` sends what echo prints into a file; `cat` shows a file)*

```text
$ cd ..
$ pwd
/home/you
```

*(`..` is one folder up)*

> **Checkpoint.** Without looking: make a folder `test2` in your home, go into it, make a file
> `hello.txt` holding `hi`, show it, go back home. Then delete it all: `rm -r ~/test2`.
